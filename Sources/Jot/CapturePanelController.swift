import AppKit
import JotCore

/// The Capture Panel: a plain text editor bound to the Notes Folder's open Note.
/// Saving is invisible: ~0.5 s after typing stops, and when the panel closes.
@MainActor
final class CapturePanelController: NSObject, NSWindowDelegate, NSTextViewDelegate {
    private static let autosaveDelay: Duration = .milliseconds(500)

    private let folder: NotesFolder
    private let panel: NSPanel
    private let textView: NSTextView
    private var autosave: Task<Void, Never>?
    private var isShowingSaveError = false

    init(folder: NotesFolder) {
        self.folder = folder

        let scrollView = NSTextView.scrollableTextView()
        textView = scrollView.documentView as! NSTextView
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: true
        )
        super.init()

        configure(textView)
        textView.delegate = self

        panel.title = "Jot"
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.contentView = scrollView
        panel.initialFirstResponder = textView
        panel.delegate = self
    }

    /// Leaves the current Note and shows the panel with an empty Draft.
    func showNewDraft() {
        cancelAutosave()
        do {
            try folder.startDraft()
        } catch {
            // Previous Note couldn't be saved: keep it on screen instead of replacing it.
            reportSaveError(error)
            show()
            return
        }
        isShowingSaveError = false  // the previous Note was saved, so its failure streak is over
        textView.string = ""
        textView.undoManager?.removeAllActions()
        if !panel.isVisible { panel.center() }
        show()
    }

    func saveBeforeQuit() {
        cancelAutosave()
        do { try folder.leave() } catch { NSLog("Jot: couldn't save on quit: \(error)") }
    }

    private func show() {
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(textView)
    }

    // MARK: Saving

    func textDidChange(_ notification: Notification) {
        folder.update(text: textView.string)
        cancelAutosave()
        autosave = Task { [weak self] in
            try? await Task.sleep(for: Self.autosaveDelay)
            guard !Task.isCancelled else { return }
            self?.save { try $0.flush() }
        }
    }

    func windowWillClose(_ notification: Notification) {
        cancelAutosave()
        save { try $0.leave() }
    }

    private func cancelAutosave() {
        autosave?.cancel()
        autosave = nil
    }

    /// Only a save that actually wrote ends a failure streak; a no-op proves nothing.
    private func save(_ operation: (NotesFolder) throws -> Bool) {
        do {
            if try operation(folder) { isShowingSaveError = false }
        } catch {
            reportSaveError(error)
        }
    }

    /// Alerts once per failure streak, so a failing autosave doesn't nag on every pause.
    private func reportSaveError(_ error: Error) {
        guard !isShowingSaveError else { return }
        isShowingSaveError = true
        ErrorAlert.show("Jot couldn't save this note.", error: error)
    }

    // MARK: Editor

    private func configure(_ textView: NSTextView) {
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = .systemFont(ofSize: 14)
        textView.textContainerInset = NSSize(width: 12, height: 12)
        // Markdown is plain text: no smart quotes, dashes or replacements.
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
    }
}
