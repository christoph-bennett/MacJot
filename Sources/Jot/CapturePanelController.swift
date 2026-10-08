import AppKit
import JotCore

/// The Capture Panel: a floating plain text editor bound to the Notes Folder's open Note.
/// Saving is invisible: ~0.5 s after typing stops, and when the panel closes.
@MainActor
final class CapturePanelController: NSObject, NSWindowDelegate, NSTextViewDelegate {
    private static let autosaveDelay: Duration = .milliseconds(500)
    private static let frameAutosaveName = "CapturePanel"
    private static let defaultSize = NSSize(width: 480, height: 360)

    private let folder: NotesFolder
    private let panel: NSPanel
    private let textView: NSTextView
    private let styler = MarkdownStyler()
    private var autosave: Task<Void, Never>?
    private var isShowingSaveError = false

    init(folder: NotesFolder) {
        self.folder = folder

        let scrollView = NSTextView.scrollableTextView()
        textView = scrollView.documentView as! NSTextView
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.defaultSize),
            // Non-activating: the panel takes keyboard focus without activating Jot,
            // like Spotlight. Activation can be refused on macOS 14+, and the app
            // the user came from regains focus by itself when the panel closes.
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        super.init()

        configure(textView)
        textView.delegate = self

        panel.title = "Jot"
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        // Floats above normal windows and follows the user to the active Space,
        // including over full-screen apps.
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.contentView = scrollView
        panel.initialFirstResponder = textView
        panel.delegate = self
        if !panel.setFrameUsingName(Self.frameAutosaveName) {
            panel.center()
        }
        panel.setFrameAutosaveName(Self.frameAutosaveName)
    }

    // MARK: Showing and hiding

    /// Capture Hotkey: hidden → new Draft; visible but not key → front, content kept; key → hide.
    func toggleCapture() {
        if panel.isKeyWindow {
            hide()
        } else if panel.isVisible {
            show()
        } else {
            showNewDraft()
        }
    }

    /// Leaves the current Note and shows the panel with an empty Draft.
    @objc func showNewDraft() {
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
        textView.typingAttributes = styler.baseAttributes
        textView.undoManager?.removeAllActions()
        show()
    }

    func saveBeforeQuit() {
        cancelAutosave()
        do { try folder.leave() } catch { NSLog("Jot: couldn't save on quit: \(error)") }
    }

    private func show() {
        if !panel.isVisible { keepOnScreen() }
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(textView)
    }

    /// Closes the panel, which saves; being non-activating, focus returns to the previous app.
    private func hide() {
        panel.close()
    }

    /// The remembered frame may be on a screen that's no longer connected. If its
    /// title bar isn't on any screen, centre it on the screen under the mouse.
    private func keepOnScreen() {
        let frame = panel.frame
        let titleBar = NSPoint(x: frame.midX, y: frame.maxY - 10)
        guard !NSScreen.screens.contains(where: { $0.visibleFrame.contains(titleBar) }) else { return }
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = NSSize(width: min(frame.width, visible.width), height: min(frame.height, visible.height))
        panel.setFrame(NSRect(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2,
                              width: size.width, height: size.height), display: false)
    }

    /// An untouched Draft shouldn't linger after an accidental summon. Checked one
    /// run-loop turn later, outside AppKit's key-change callback, and only if focus
    /// went to another app rather than to one of Jot's own windows (e.g. an alert).
    func windowDidResignKey(_ notification: Notification) {
        Task { [weak self] in
            guard let self, panel.isVisible, NSApp.keyWindow == nil, folder.isBlankDraft else { return }
            panel.close()
        }
    }

    func windowWillClose(_ notification: Notification) {
        cancelAutosave()
        save { try $0.leave() }
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

    func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.cancelOperation(_:)):
            // `Esc` closes the panel. NSTextView would otherwise treat it as "complete word".
            hide()
        case #selector(NSResponder.insertNewline(_:)):
            // Return starts a paragraph; Shift-Return is a single line break (ADR 0004).
            let soft = NSApp.currentEvent?.modifierFlags.contains(.shift) ?? false
            apply(MarkdownEditing.newline(in: textView.string, selection: textView.selectedRange(), soft: soft))
        case #selector(NSResponder.insertLineBreak(_:)), #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)):
            apply(MarkdownEditing.newline(in: textView.string, selection: textView.selectedRange(), soft: true))
        default:
            return false
        }
        return true
    }

    /// Typing always starts plain; the styler restyles right after. Otherwise the
    /// attributes of the character before the caret leak in (e.g. a paragraph
    /// gap's small font makes the caret tiny on a new paragraph).
    func textView(
        _ textView: NSTextView, shouldChangeTypingAttributes oldTypingAttributes: [String: Any],
        toAttributes newTypingAttributes: [NSAttributedString.Key: Any]
    ) -> [NSAttributedString.Key: Any] {
        styler.baseAttributes
    }

    /// Undoable and autosaved like typing. The new text gets the plain attributes
    /// up front, so it doesn't inherit the Title's font until the next restyle
    /// (which made the caret oversized after Return on the Title line).
    private func apply(_ edit: TextEdit) {
        guard textView.shouldChangeText(in: edit.range, replacementString: edit.replacement),
              let storage = textView.textStorage else { return }
        storage.replaceCharacters(in: edit.range, with: NSAttributedString(string: edit.replacement, attributes: styler.baseAttributes))
        textView.didChangeText()
        textView.setSelectedRange(edit.selection)
        textView.typingAttributes = styler.baseAttributes
    }

    private func configure(_ textView: NSTextView) {
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFontPanel = false
        textView.textStorage?.delegate = styler
        textView.typingAttributes = styler.baseAttributes
        textView.textContainerInset = NSSize(width: 12, height: 12)
        // Markdown is plain text: no smart quotes, dashes or replacements.
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        // Inline predictions and completion insert text themselves: with one showing,
        // Return bypassed the paragraph handling above and wrote a single line break.
        textView.inlinePredictionType = .no
        textView.isAutomaticTextCompletionEnabled = false
    }
}
