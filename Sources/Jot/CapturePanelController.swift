import AppKit
import JotCore

/// The Capture Panel: a floating Markdown editor bound to the Notes Folder's open
/// Note, with the Note List as a collapsible sidebar. Saving is invisible: ~0.5 s
/// after typing stops, and when the Note is left (panel closed, another Note opened).
@MainActor
final class CapturePanelController: NSObject, NSWindowDelegate, NSTextViewDelegate {
    private static let autosaveDelay: Duration = .milliseconds(500)
    private static let frameAutosaveName = "CapturePanel"
    private static let defaultSize = NSSize(width: 640, height: 420)

    private let folder: NotesFolder
    private let panel: CapturePanel
    private let textView: NSTextView
    private let styler = MarkdownStyler()
    private let noteList = NoteListViewController()
    private let noteListItem: NSSplitViewItem
    private let cursors = CursorPositions()
    private var autosave: Task<Void, Never>?
    private var isShowingSaveError = false

    init(folder: NotesFolder) {
        self.folder = folder

        let scrollView = NSTextView.scrollableTextView()
        textView = scrollView.documentView as! NSTextView
        noteListItem = NSSplitViewItem(sidebarWithViewController: noteList)
        panel = CapturePanel(
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

        let editor = EditorViewController(scrollView: scrollView)
        editor.menuItems = { [weak self] in
            guard let self, let note = folder.currentNoteURL else { return [] }
            return actions(for: note)
        }
        noteList.onOpen = { [weak self] in self?.open($0) }
        noteList.menuItems = { [weak self] in self?.actions(for: $0) ?? [] }
        noteListItem.minimumThickness = 180
        noteListItem.maximumThickness = 320
        noteListItem.isCollapsed = true
        let split = NSSplitViewController()
        split.addSplitViewItem(noteListItem)
        split.addSplitViewItem(NSSplitViewItem(viewController: editor))

        panel.title = "Jot"
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        // Floats above normal windows and follows the user to the active Space,
        // including over full-screen apps.
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.contentViewController = split
        panel.initialFirstResponder = textView
        panel.delegate = self
        panel.onCancel = { [weak self] in self?.hide() }
        // Setting the content view controller resized the panel; restore the remembered frame.
        if !panel.setFrameUsingName(Self.frameAutosaveName) {
            panel.setContentSize(Self.defaultSize)
            panel.center()
        }
        panel.setFrameAutosaveName(Self.frameAutosaveName)
    }

    // MARK: Showing and hiding

    /// The panel is in "notes" mode while the Note List is open and has focus;
    /// otherwise it's in "capture" mode (writing).
    private var isInNotesMode: Bool {
        !noteListItem.isCollapsed && panel.firstResponder === noteList.tableView
    }

    /// Capture Hotkey: hidden → new Draft; visible but not key → front, content
    /// kept; key → hide, or a new Draft if the Note List had focus.
    func toggleCapture() {
        if panel.isKeyWindow {
            if isInNotesMode { showNewDraft() } else { hide() }
        } else if panel.isVisible {
            show()
        } else {
            showNewDraft()
        }
    }

    /// Search Hotkey: hidden → Note List with the most recent Note; visible but
    /// not key → front with the list focused; key → hide, or the list if writing.
    func toggleNotes() {
        if panel.isKeyWindow, isInNotesMode {
            hide()
        } else {
            showNotes()
        }
    }

    /// Leaves the current Note and shows the panel with an empty Draft. Summoned
    /// from hidden, the Note List starts collapsed: capturing is the point.
    @objc func showNewDraft() {
        if !panel.isVisible { noteListItem.isCollapsed = true }
        cancelAutosave()
        do {
            try leavingCurrentNote { try folder.startDraft() }
        } catch {
            // Previous Note couldn't be saved: keep it on screen instead of replacing it.
            reportSaveError(error)
            show()
            return
        }
        isShowingSaveError = false  // the previous Note was saved, so its failure streak is over
        display("", cursor: 0)
        show()
    }

    /// Shows the panel with the Note List expanded and focused. From hidden, the
    /// editor shows the most recently modified Note (a Draft if there are none).
    @objc func showNotes() {
        if !panel.isVisible {
            if let recent = (try? folder.notes())?.first { open(recent.url) } else { showNewDraft() }
        }
        reloadNoteList(evenIfCollapsed: true)
        noteListItem.isCollapsed = false
        show()
        panel.makeFirstResponder(noteList.tableView)
    }

    @objc func toggleNoteList() {
        let willShow = noteListItem.isCollapsed
        if willShow {
            reloadNoteList(evenIfCollapsed: true)
        } else if panel.firstResponder === noteList.tableView {
            panel.makeFirstResponder(textView)  // don't leave typing aimed at a hidden list
        }
        noteListItem.animator().isCollapsed = !willShow
    }

    // MARK: Notes

    /// Leaves the current Note and opens `note` where the user last left it.
    private func open(_ note: URL) {
        cancelAutosave()
        let text: String
        do {
            text = try leavingCurrentNote { try folder.open(note) }
        } catch {
            ErrorAlert.show("Jot couldn't open this note.", error: error)
            reloadNoteList()
            return
        }
        display(text, cursor: cursors.position(for: note))
        // Keep the rows where they are while the user moves through the list.
        reloadNoteList(keepingOrder: true)
    }

    private func trash(_ note: URL) {
        let wasOpen = folder.currentNoteURL?.standardizedFileURL == note.standardizedFileURL
        do {
            try folder.trash(note)
        } catch {
            ErrorAlert.show("Jot couldn't move this note to the Trash.", error: error)
            return
        }
        cursors.forget(note)
        if wasOpen { showNewDraft() }
        reloadNoteList()
    }

    private func actions(for note: URL) -> [NSMenuItem] {
        NoteActions.items(
            for: note,
            prepare: { [weak self] in self?.save { try $0.flush() } },
            trash: { [weak self] in self?.trash($0) }
        )
    }

    /// Skipped while collapsed: autosave calls this, and reading every Note for a
    /// hidden list would be wasted.
    private func reloadNoteList(evenIfCollapsed: Bool = false, keepingOrder: Bool = false) {
        guard evenIfCollapsed || !noteListItem.isCollapsed else { return }
        do {
            noteList.show(try folder.notes(), selecting: folder.currentNoteURL, keepingOrder: keepingOrder)
        } catch {
            NSLog("Jot: couldn't list notes: \(error)")
        }
    }

    /// Replaces the editor's text (no undo across Notes) and places the cursor.
    private func display(_ text: String, cursor: Int) {
        textView.string = text
        if let storage = textView.textStorage { styler.restyleAll(storage) }
        textView.typingAttributes = styler.baseAttributes
        textView.undoManager?.removeAllActions()
        let location = min(cursor, (text as NSString).length)
        textView.setSelectedRange(NSRange(location: location, length: 0))
        textView.scrollRangeToVisible(NSRange(location: location, length: 0))
    }

    /// Runs an operation that may leave the open Note, then remembers the cursor
    /// under the name the Note ended up with (it may have been renamed, or a Draft
    /// may only now have got its file).
    private func leavingCurrentNote<T>(_ operation: () throws -> T) rethrows -> T {
        let cursor = textView.selectedRange().location
        let before = folder.currentNoteURL
        let leaves = folder.leaveCount
        let result = try operation()
        if folder.leaveCount != leaves {
            if let before, before != folder.lastLeftNoteURL { cursors.forget(before) }
            if let left = folder.lastLeftNoteURL { cursors.remember(cursor, for: left) }
        }
        return result
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
        save { folder in try leavingCurrentNote { try folder.leave() } }
    }

    // MARK: Saving

    func textDidChange(_ notification: Notification) {
        folder.update(text: textView.string)
        cancelAutosave()
        autosave = Task { [weak self] in
            try? await Task.sleep(for: Self.autosaveDelay)
            guard !Task.isCancelled, let self else { return }
            // Only a write to a Note's file changes the list, not one to the Recovery Copy.
            if save({ try $0.flush() }), folder.currentNoteURL != nil { reloadNoteList() }
        }
    }

    private func cancelAutosave() {
        autosave?.cancel()
        autosave = nil
    }

    /// Only a save that actually wrote ends a failure streak; a no-op proves nothing.
    /// Returns whether it wrote.
    @discardableResult
    private func save(_ operation: (NotesFolder) throws -> Bool) -> Bool {
        do {
            let wrote = try operation(folder)
            if wrote { isShowingSaveError = false }
            return wrote
        } catch {
            reportSaveError(error)
            return false
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
    /// up front, so it doesn't inherit e.g. a heading's font until the next restyle
    /// (which made the caret oversized after Return).
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

/// Sends `Esc` that no view handled (e.g. in the Note List) to the controller.
final class CapturePanel: NSPanel {
    var onCancel: () -> Void = {}

    override func cancelOperation(_ sender: Any?) {
        onCancel()
    }
}

/// Where the user left the cursor in each Note: an app preference, never in the
/// file. Keeps the most recently used `limit` entries.
@MainActor
final class CursorPositions {
    private static let key = "cursorPositions.v2"
    private static let limit = 500

    /// path → [position, last used (seconds since 1970)]
    private var entries: [String: [Double]] {
        get { UserDefaults.standard.dictionary(forKey: Self.key) as? [String: [Double]] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: Self.key) }
    }

    func position(for note: URL) -> Int {
        entries[note.path].flatMap { $0.first }.map { Int($0) } ?? 0
    }

    func remember(_ position: Int, for note: URL) {
        var entries = entries
        entries[note.path] = [Double(position), Date().timeIntervalSince1970]
        while entries.count > Self.limit,
              let oldest = entries.min(by: { ($0.value.last ?? 0) < ($1.value.last ?? 0) })?.key {
            entries[oldest] = nil
        }
        self.entries = entries
    }

    func forget(_ note: URL) {
        entries[note.path] = nil
    }
}
