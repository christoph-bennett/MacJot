import AppKit
import Carbon.HIToolbox
import JotCore

/// The Capture Panel: a floating Markdown editor bound to the Notes Folder's open
/// Note, with the Note List as a collapsible sidebar. Saving is invisible: ~0.5 s
/// after typing stops, and when the Note is left (panel closed, another Note opened).
@MainActor
final class CapturePanelController: NSObject, NSWindowDelegate, NSTextViewDelegate {
    private static let autosaveDelay: Duration = .milliseconds(500)
    private static let frameAutosaveName = "CapturePanel"
    private static let defaultSize = NSSize(width: 640, height: 420)
    /// The Note List's width the user dragged to; it opens at the default until then.
    static let noteListWidthKey = "noteListWidth"
    private static let defaultNoteListWidth: CGFloat = 240

    private let folder: NotesFolder
    private let panel: CapturePanel
    private let textView: NSTextView
    private let styler = MarkdownStyler()
    private let noteList = NoteListViewController()
    private let gutter: LineNumberGutter
    private let noteListItem: NSSplitViewItem
    private let split = NSSplitViewController()
    /// A width for the Note List to take the next time it opens (after Reset
    /// Size & Position while it was closed).
    private var pendingNoteListWidth: CGFloat?
    private let cursors = CursorPositions()
    private var autosave: Task<Void, Never>?
    private var watcher: FolderWatcher?
    private var isShowingSaveError = false
    /// ⌘, in the panel.
    var onShowSettings: () -> Void = {}
    /// The Notes Folder was renamed or moved elsewhere and MacJot followed it.
    var onFolderMoved: () -> Void = {}

    init(folder: NotesFolder) {
        self.folder = folder

        let scrollView = Self.makeEditorScrollView()
        textView = scrollView.documentView as! NSTextView
        gutter = LineNumberGutter(textView: textView, scrollView: scrollView)
        scrollView.verticalRulerView = gutter
        scrollView.hasVerticalRuler = true
        noteListItem = NSSplitViewItem(sidebarWithViewController: noteList)
        panel = CapturePanel(
            contentRect: NSRect(origin: .zero, size: Self.defaultSize),
            // Non-activating: the panel takes keyboard focus without activating MacJot,
            // like Spotlight. Activation can be refused on macOS 14+, and the app
            // the user came from regains focus by itself when the panel closes.
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        super.init()

        configure(textView)
        textView.delegate = self
        (textView as? EditorTextView)?.onCheckboxClick = { [weak self] in self?.toggleCheckbox(at: $0) }
        scrollView.contentView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(fitUnwrappedWidth),
                                               name: NSView.frameDidChangeNotification, object: scrollView.contentView)

        let editor = EditorViewController(scrollView: scrollView)
        editor.onFormat = { [weak self] in self?.format($0) }
        editor.menuItems = { [weak self] in
            guard let self, let note = folder.currentNoteURL else { return [] }
            return actions(for: note)
        }
        noteList.onOpen = { [weak self] in self?.open($0) }
        noteList.onDelete = { [weak self] note in self?.confirmTrash(note) { self?.trash(note) } }
        noteList.menuItems = { [weak self] in self?.actions(for: $0) ?? [] }
        noteList.onReturn = { [weak self] in self?.focusEditor() }
        noteList.onCancel = { [weak self] in self?.hide() }
        noteList.onNewNote = { [weak self] in self?.showNewDraft() }
        noteListItem.minimumThickness = 180
        noteListItem.maximumThickness = 320
        noteListItem.isCollapsed = true
        split.addSplitViewItem(noteListItem)
        split.addSplitViewItem(NSSplitViewItem(viewController: editor))

        panel.title = "MacJot"
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
        panel.onCancel = { [weak self] in self?.cancel() }
        panel.onShortcut = { [weak self] in self?.handleShortcut($0) ?? false }
        // Setting the content view controller resized the panel; restore the remembered frame.
        if !panel.setFrameUsingName(Self.frameAutosaveName) {
            panel.setContentSize(Self.defaultSize)
            panel.center()
        }
        panel.setFrameAutosaveName(Self.frameAutosaveName)
        let savedWidth = UserDefaults.standard.double(forKey: Self.noteListWidthKey)
        pendingNoteListWidth = savedWidth > 0 ? savedWidth : Self.defaultNoteListWidth
        watchFolder()
    }

    // MARK: Showing and hiding

    /// The panel is in "notes" mode while the Note List is open and it or its
    /// search field has focus; otherwise it's in "capture" mode (writing).
    private var isInNotesMode: Bool {
        !noteListItem.isCollapsed && noteList.hasFocus
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
    /// not key → front with search focused; key → hide, or search if writing.
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
        reloadNoteList()  // shows the Draft as the selected top row
        show()
    }

    /// Shows the panel with the Note List expanded and its search field focused
    /// (the query selected, so typing replaces it). From hidden, the editor shows
    /// the most recently modified Note (a Draft if there are none).
    @objc func showNotes() {
        if !panel.isVisible {
            if let recent = (try? folder.notes())?.first { open(recent.url) } else { showNewDraft() }
        }
        reloadNoteList(evenIfCollapsed: true)
        expandNoteList(animated: false)
        show()
        panel.makeFirstResponder(noteList.searchField)
    }

    /// Return in the Note List: go on writing in the Note it shows.
    private func focusEditor() {
        panel.makeFirstResponder(textView)
    }

    /// `Esc` that reached the panel (e.g. from the Note List's table): clears a
    /// search first, then closes.
    private func cancel() {
        if noteListItem.isCollapsed || !noteList.cancelSearch() { hide() }
    }

    /// Formatting shortcuts match the typed character, as menus do. The others
    /// match the physical key: with Control held, the reported characters vary by
    /// keyboard layout. (S, N and the comma sit in the same place on QWERTY and QWERTZ.)
    private func handleShortcut(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        // Not while an input method is composing: the edit would cut through it.
        if panel.firstResponder === textView, !textView.hasMarkedText() {
            switch (modifiers, event.charactersIgnoringModifiers?.lowercased()) {
            case ([.command], "b"): format(.inline(.bold)); return true
            case ([.command], "i"): format(.inline(.italic)); return true
            case ([.command, .shift], "x"): format(.inline(.strikethrough)); return true
            default: break
            }
        }
        switch (modifiers, Int(event.keyCode)) {
        case ([.control, .command], kVK_ANSI_S): toggleNoteList()
        case ([.command], kVK_ANSI_N): showNewDraft()
        case ([.command], kVK_ANSI_Comma): onShowSettings()
        // Find (GLOSSARY: within the open Note), the standard Mac set (ticket 24).
        // Also with focus in the Note List: it always finds in the editor.
        case ([.command], kVK_ANSI_F): find(.showFindInterface)
        case ([.option, .command], kVK_ANSI_F): find(.showReplaceInterface)
        case ([.command], kVK_ANSI_G): find(.nextMatch)
        case ([.shift, .command], kVK_ANSI_G): find(.previousMatch)
        case ([.command], kVK_ANSI_E): find(.setSearchString)
        default: return false
        }
        return true
    }

    /// Edit > Find's items; their tags are `NSTextFinder.Action`s.
    @objc func performFind(_ sender: NSMenuItem) {
        NSTextFinder.Action(rawValue: sender.tag).map(find)
    }

    private func find(_ action: NSTextFinder.Action) {
        // The text view's finder reads the action from the sender's tag.
        let sender = NSMenuItem()
        sender.tag = action.rawValue
        textView.performTextFinderAction(sender)
    }

    @objc func toggleNoteList() {
        let willShow = noteListItem.isCollapsed
        if willShow {
            reloadNoteList(evenIfCollapsed: true)
            expandNoteList(animated: true)
        } else {
            if noteList.hasFocus {
                panel.makeFirstResponder(textView)  // don't leave typing aimed at a hidden list
            }
            saveNoteListWidth()
            noteListItem.animator().isCollapsed = true
        }
    }

    // MARK: Notes

    /// Leaves the current Note and opens `note` where the user last left it.
    private func open(_ note: URL) {
        cancelAutosave()
        let text: String
        do {
            text = try leavingCurrentNote { try folder.open(note) }
        } catch {
            ErrorAlert.show("MacJot couldn't open this note.", error: error)
            reloadNoteList()
            return
        }
        display(text, cursor: cursors.position(for: note))
        // Keep the rows where they are while the user moves through the list.
        reloadNoteList(keepingOrder: true)
    }

    /// Files opened with MacJot from Finder (ticket 30): the first of them that's
    /// a Note opens as if picked in the Note List; any others get one alert, as
    /// MacJot doesn't edit files outside the Notes Folder.
    func openFromFinder(_ files: [URL]) {
        if let note = files.first(where: folder.isNote) {
            open(note)
            show()
        }
        let outside = files.filter { !folder.isNote($0) }
        guard !outside.isEmpty else { return }
        let alert = NSAlert()
        let path = (folder.url.path as NSString).abbreviatingWithTildeInPath
        alert.messageText = "MacJot only opens notes in your Notes Folder (\(path))."
        alert.informativeText = outside.count == 1
            ? "“\(outside[0].lastPathComponent)” wasn’t opened."
            : "\(outside.count) files weren’t opened."
        NSApp.activate()
        alert.runModal()
    }

    /// Asks first unless the user turned that off (Settings, ticket 14).
    private func confirmTrash(_ note: URL, then proceed: @escaping () -> Void) {
        guard UserDefaults.standard.bool(forKey: Self.confirmTrashKey) else { return proceed() }
        let alert = NSAlert()
        alert.messageText = "Move “\(note.lastPathComponent)” to the Trash?"
        alert.informativeText = "You can restore it from the Trash in Finder."
        alert.addButton(withTitle: "Move to Trash").hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel").keyEquivalent = "\u{1b}"
        alert.beginSheetModal(for: panel) { response in
            if response == .alertFirstButtonReturn { proceed() }
        }
    }

    static let confirmTrashKey = "confirmBeforeMovingToTrash"

    /// Trashes `note`. If it was open, the editor moves on to its neighbour in the
    /// list (or the most recent Note), like Mail, rather than to a blank Draft;
    /// a Draft only when no Notes are left. Focus stays where it was, so the
    /// Delete key keeps working in the list.
    private func trash(_ note: URL) {
        let wasOpen = folder.currentNoteURL?.standardizedFileURL == note.standardizedFileURL
        let next = noteListItem.isCollapsed ? nil : noteList.neighbour(of: note)
        let listHadFocus = noteList.hasFocus
        do {
            try folder.trash(note)
        } catch {
            ErrorAlert.show("MacJot couldn't move this note to the Trash.", error: error)
            return
        }
        cursors.forget(note)
        if wasOpen { openNextOrDraft(next) }
        reloadNoteList()
        if listHadFocus { panel.makeFirstResponder(noteList.tableView) }
    }

    /// After the open Note went away: `preferred`, else the most recent Note,
    /// else a new Draft.
    private func openNextOrDraft(_ preferred: URL?) {
        if let next = preferred ?? (try? folder.notes())?.first?.url {
            open(next)
        } else {
            try? folder.startDraft()
            display("", cursor: 0)
        }
    }

    private func actions(for note: URL) -> [NSMenuItem] {
        NoteActions.items(
            for: note,
            prepare: { [weak self] in self?.save { try $0.flush() } },
            trash: { [weak self] note in self?.confirmTrash(note) { self?.trash(note) } }
        )
    }

    /// Something in the Notes Folder changed, here or elsewhere: bring the open
    /// Note and the Note List up to date.
    /// Also how the list catches up with MacJot's own saves and renames.
    private func folderDidChange() {
        let before = folder.currentNoteURL
        do {
            switch try folder.reconcileOpenNote() {
            case .reloaded(let text):
                cancelAutosave()
                display(text, cursor: textView.selectedRange().location)  // clamped to the new text
            case .deleted:
                // Its file is gone (e.g. moved to the Trash in Finder): move on, as when trashed in MacJot.
                if let before { cursors.forget(before) }
                openNextOrDraft(before.flatMap(noteList.neighbour))
            case .renamed(let note):
                if let before {
                    cursors.remember(cursors.position(for: before), for: note)
                    cursors.forget(before)
                }
            case .unchanged, .keptLocal:
                break  // the editor already shows the right text
            }
        } catch {
            NSLog("MacJot: couldn't check the open note against its file: \(error)")
        }
        // While the user moves through the list, rows stay put (as when opening a Note).
        reloadNoteList(keepingOrder: noteList.hasFocus)
    }

    /// Makes `url` the Notes Folder (Settings). The open Note is saved to the old
    /// folder first; if that fails, the old folder stays and the error is thrown.
    /// A visible panel moves on to the new folder's most recent Note, or a Draft.
    /// Returns false if `url` already was the Notes Folder.
    func switchFolder(to url: URL) throws -> Bool {
        cancelAutosave()
        guard try leavingCurrentNote({ try folder.switchFolder(to: url) }) else { return false }
        isShowingSaveError = false
        watchFolder()
        noteList.cancelSearch()
        if panel.isVisible {
            openNextOrDraft(nil)
        } else {
            display("", cursor: 0)  // nothing of the old folder's Note left behind; any summon replaces it
        }
        reloadNoteList()
        return true
    }

    private var isHandlingRootChange = false
    /// Finds the folder in use after it disappears from its path. Not the saved
    /// bookmark: after a fallback at launch, that's another folder's.
    private var folderBookmark: Data?

    private func watchFolder() {
        folderBookmark = FolderLocation.bookmark(for: folder.url)
        watcher = nil  // stop watching the old folder before the new watcher starts
        watcher = FolderWatcher(folder.url, onChange: { [weak self] in self?.folderDidChange() },
                                onRootChange: { [weak self] in self?.folderRootDidChange() })
    }

    /// The Notes Folder itself was renamed, moved or deleted. A renamed or moved
    /// folder is followed, with the open Note; for one in the Trash or gone the
    /// user decides between a new, empty folder at its path and quitting.
    private func folderRootDidChange() {
        // The alerts below run modally, and the watcher can report again meanwhile.
        guard !isHandlingRootChange else { return }
        isHandlingRootChange = true
        defer { isHandlingRootChange = false }
        let old = folder.url
        let status = FolderLocation.status(of: old, bookmark: folderBookmark)
        switch status {
        case .inPlace:
            folderDidChange()  // e.g. moved back, or another folder took its place
            return
        case .moved(let found):
            folder.followMove(to: found)
            cursors.followFolderMove(from: old, to: found)
            SavedNotesFolder.save(found)
            watchFolder()
            folderDidChange()
            onFolderMoved()
            SavedNotesFolder.tellFollowed(from: old, to: found)
        case .trashed, .gone, .missing:
            guard SavedNotesFolder.askToRecreate(old, trashed: status == .trashed) else {
                NSApp.terminate(nil)
                return
            }
            do {
                try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)
            } catch {
                ErrorAlert.show("MacJot couldn’t create the Notes Folder.", error: error)
                return
            }
            SavedNotesFolder.save(old)
            watchFolder()
            folderDidChange()  // the open Note's file is gone with the folder: move on
        }
    }

    /// Skipped while collapsed: autosave calls this, and reading every Note for a
    /// hidden list would be wasted.
    private func reloadNoteList(evenIfCollapsed: Bool = false, keepingOrder: Bool = false) {
        guard evenIfCollapsed || !noteListItem.isCollapsed else { return }
        do {
            noteList.show(try folder.notes(), selecting: folder.currentNoteURL, keepingOrder: keepingOrder,
                          draftText: folder.isDraft ? textView.string : nil)
        } catch {
            NSLog("MacJot: couldn't list notes: \(error)")
        }
    }

    /// Replaces the editor's text (no undo across Notes) and places the cursor.
    private func updateEmptyNoteHint() {
        (textView as? EditorTextView)?.hint = folder.wouldTrashOnLeave ? "Leave this note empty to move it to the Trash." : nil
    }

    private func display(_ text: String, cursor: Int) {
        // Find is for the Note it was opened on: never matches left from another.
        find(.hideFindInterface)
        textView.string = text
        if let storage = textView.textStorage { styler.restyleAll(storage) }
        textView.typingAttributes = styler.baseAttributes
        textView.undoManager?.removeAllActions()
        let location = min(cursor, (text as NSString).length)
        textView.setSelectedRange(NSRange(location: location, length: 0))
        textView.scrollRangeToVisible(NSRange(location: location, length: 0))
        // All of it: TextKit redraws only what it thinks changed, and after
        // switching to a shorter Note the previous Note's last lines stayed on
        // screen below the new text.
        textView.needsDisplay = true
        updateEmptyNoteHint()
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
        saveNoteListWidth()
        cancelAutosave()
        do { try folder.leave() } catch { NSLog("MacJot: couldn't save on quit: \(error)") }
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

    // MARK: Settings

    /// The editor's text size (Settings > Editor); headings scale with it.
    func setFontSize(_ size: CGFloat) {
        guard size > 0, size != styler.baseSize else { return }
        styler.baseSize = size
        if let storage = textView.textStorage { styler.restyleAll(storage) }
        textView.typingAttributes = styler.baseAttributes
        gutter.fontSize = size
    }

    /// The line numbers beside the text (Settings > Editor).
    func setLineNumbers(_ on: Bool) {
        textView.enclosingScrollView?.rulersVisible = on
        if on { gutter.refresh() }
        (textView as? EditorTextView)?.leadingInset = on ? 0 : nil
    }

    /// A band behind the cursor's line and its number drawn stronger (Settings > Editor).
    func setHighlightsCurrentLine(_ on: Bool) {
        (textView as? EditorTextView)?.highlightsCurrentLine = on
        gutter.highlightsCurrentLine = on
    }

    /// Long lines wrap at the editor's width, or run on and the editor scrolls
    /// sideways (Settings > Editor).
    func setWrapsLines(_ on: Bool) {
        guard let scrollView = textView.enclosingScrollView, let container = textView.textContainer else { return }
        let huge = CGFloat.greatestFiniteMagnitude
        // Shown only while a line is too wide: the scroll view hides it when there's nothing to scroll.
        scrollView.hasHorizontalScroller = !on
        container.widthTracksTextView = on
        textView.isHorizontallyResizable = !on
        // Unwrapped, the text view is as wide as its longest line (`sizeToFit`).
        textView.autoresizingMask = on ? [.width] : []
        if on {
            textView.minSize = NSSize(width: 0, height: 0)
            textView.setFrameSize(NSSize(width: scrollView.contentSize.width, height: textView.frame.height))
            // As tracking the width does: the text view's width less the inset on both sides.
            container.containerSize = NSSize(width: textView.frame.width - 2 * textView.textContainerInset.width, height: huge)
        } else {
            container.containerSize = NSSize(width: huge, height: huge)
            fitUnwrappedWidth()
        }
        textView.scrollRangeToVisible(textView.selectedRange())
    }

    /// Unwrapped, the text view is never narrower than the visible area, so clicks
    /// and the current-line band reach its right edge; called again when the panel resizes.
    @objc private func fitUnwrappedWidth() {
        guard textView.isHorizontallyResizable, let scrollView = textView.enclosingScrollView else { return }
        textView.minSize = NSSize(width: scrollView.contentSize.width, height: 0)
        textView.sizeToFit()
    }

    /// The Note List's dates: "2h", "Mon", or the short date and time.
    func setRelativeDates(_ on: Bool) {
        noteList.showsRelativeDates = on
    }

    /// Settings > General: the default size, centred on the screen the panel is
    /// on (or under the mouse while it's hidden). The next summon uses it too.
    func resetFrame() {
        let mouse = NSEvent.mouseLocation
        let screen = panel.isVisible ? panel.screen : NSScreen.screens.first { $0.frame.contains(mouse) }
        guard let visible = (screen ?? NSScreen.main)?.visibleFrame else { return }
        let frame = panel.frameRect(forContentRect: NSRect(origin: .zero, size: Self.defaultSize))
        panel.setFrame(NSRect(x: visible.midX - frame.width / 2, y: visible.midY - frame.height / 2,
                              width: frame.width, height: frame.height), display: true, animate: panel.isVisible)
        UserDefaults.standard.removeObject(forKey: Self.noteListWidthKey)
        if noteListItem.isCollapsed {
            pendingNoteListWidth = Self.defaultNoteListWidth
        } else {
            split.splitView.setPosition(Self.defaultNoteListWidth, ofDividerAt: 0)
        }
    }

    /// Opens the Note List; at a pending width (the saved one at launch, or the
    /// default after a reset) without animation, as it's set while opening.
    private func expandNoteList(animated: Bool) {
        guard noteListItem.isCollapsed else { return }
        guard let width = pendingNoteListWidth else {
            (animated ? noteListItem.animator() : noteListItem).isCollapsed = false
            return
        }
        pendingNoteListWidth = nil
        noteListItem.isCollapsed = false
        split.splitView.layoutSubtreeIfNeeded()
        split.splitView.setPosition(min(max(width, noteListItem.minimumThickness), noteListItem.maximumThickness),
                                    ofDividerAt: 0)
    }

    /// Saves the open Note List's width for the next launch, when it closes
    /// (toggled, panel closed, quit): the end of any divider drag. Not the split
    /// view's autosave, which would also restore the collapsed state MacJot sets itself.
    private func saveNoteListWidth() {
        guard !noteListItem.isCollapsed else { return }
        let width = Double(noteList.view.frame.width)
        guard width >= noteListItem.minimumThickness else { return }
        // Untouched: keep following the default.
        guard width != Self.defaultNoteListWidth || UserDefaults.standard.object(forKey: Self.noteListWidthKey) != nil
        else { return }
        UserDefaults.standard.set(width, forKey: Self.noteListWidthKey)
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
    /// went to another app rather than to one of MacJot's own windows (e.g. an alert).
    func windowDidResignKey(_ notification: Notification) {
        Task { [weak self] in
            guard let self, panel.isVisible, NSApp.keyWindow == nil, folder.isBlankDraft else { return }
            panel.close()
        }
    }

    /// The next summon starts without a stale search.
    func windowWillClose(_ notification: Notification) {
        saveNoteListWidth()
        noteList.cancelSearch()
        cancelAutosave()
        save { folder in try leavingCurrentNote { try folder.leave() } }
    }

    // MARK: Saving

    func textDidChange(_ notification: Notification) {
        folder.update(text: textView.string)
        updateEmptyNoteHint()
        if folder.isDraft, !noteListItem.isCollapsed { noteList.updateDraft(textView.string) }
        cancelAutosave()
        autosave = Task { [weak self] in
            try? await Task.sleep(for: Self.autosaveDelay)
            guard !Task.isCancelled, let self else { return }
            save { try $0.flush() }  // the folder watcher updates the list
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
        ErrorAlert.show("MacJot couldn't save this note.", error: error)
    }

    // MARK: Editor

    func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.cancelOperation(_:)):
            // `Esc` closes the find bar, if it's open, then the panel. NSTextView
            // would otherwise treat it as "complete word".
            if textView.enclosingScrollView?.isFindBarVisible == true {
                find(.hideFindInterface)
            } else {
                hide()
            }
        case #selector(NSResponder.insertNewline(_:)):
            // Return starts a paragraph; Shift-Return is a single line break (ADR 0004).
            let soft = NSApp.currentEvent?.modifierFlags.contains(.shift) ?? false
            apply(MarkdownEditing.newline(in: textView.string, selection: textView.selectedRange(), soft: soft))
        case #selector(NSResponder.moveUp(_:)), #selector(NSResponder.moveDown(_:)):
            // Over a paragraph gap in one step, keeping the column (consecutive
            // vertical moves remember it).
            // Called directly: `doCommand(by:)` would ask this delegate again.
            let move = { selector == #selector(NSResponder.moveUp(_:)) ? textView.moveUp(nil) : textView.moveDown(nil) }
            isMovingVertically = true
            defer { isMovingVertically = false }
            move()
            if isOnParagraphGap(textView.selectedRange()) { move() }
        case #selector(NSResponder.deleteBackward(_:)):
            guard let edit = MarkdownEditing.deleteBackward(in: textView.string, selection: textView.selectedRange())
            else { return false }
            apply(edit)
        case #selector(NSResponder.insertLineBreak(_:)), #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)):
            apply(MarkdownEditing.newline(in: textView.string, selection: textView.selectedRange(), soft: true))
        default:
            return false
        }
        return true
    }

    /// The cursor never rests on a paragraph gap: that spacer line is drawn half
    /// size, and so would the cursor be. ←/→ and clicks land at the end of the
    /// paragraph above or the start of the one below, by direction.
    func textView(_ textView: NSTextView, willChangeSelectionFromCharacterRange old: NSRange,
                  toCharacterRange new: NSRange) -> NSRange {
        guard new.length == 0 else { return new }
        // Inside a box's hidden `[ ]` or the spaces after it: to the far side, by
        // direction (before the box, or where the item's text starts).
        if let zone = checkboxZone(around: new.location), new.location > zone.box.location, new.location < zone.textStart {
            return NSRange(location: new.location < old.location ? zone.box.location : zone.textStart, length: 0)
        }
        guard !isMovingVertically, isOnParagraphGap(new) else { return new }
        return NSRange(location: new.location < old.location ? new.location - 1 : new.location + 1, length: 0)
    }

    /// The checklist box at or just before `location` (spaces apart), and where
    /// the item's text starts after it.
    private func checkboxZone(around location: Int) -> (box: NSRange, textStart: Int)? {
        guard let storage = textView.textStorage else { return nil }
        let ns = storage.string as NSString
        let isSpace = { (i: Int) in i >= 0 && i < ns.length && [0x20, 0x09].contains(ns.character(at: i)) }
        var before = location - 1
        while isSpace(before) { before -= 1 }
        guard let box = storage.checkboxRange(at: location) ?? storage.checkboxRange(at: before) else { return nil }
        var textStart = NSMaxRange(box)
        while isSpace(textStart) { textStart += 1 }
        return (box, textStart)
    }

    /// ↑/↓ skip the gap themselves, keeping the column; don't redirect them halfway.
    private var isMovingVertically = false

    private func isOnParagraphGap(_ selection: NSRange) -> Bool {
        selection.length == 0 && MarkdownStyle.isParagraphGap(at: selection.location, in: textView.string)
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

    /// A Formatting Toolbar command on the editor's text and selection; the
    /// typing goes on in the editor.
    private func format(_ command: FormatCommand) {
        let text = textView.string, selection = textView.selectedRange()
        textView.breakUndoCoalescing()  // its own undo step, separate from the typing before it
        switch command {
        case .inline(let format): apply(MarkdownEditing.toggle(format, in: text, selection: selection))
        case .line(let format): apply(MarkdownEditing.toggle(format, in: text, selection: selection))
        case .link: apply(MarkdownEditing.toggleLink(in: text, selection: selection))
        }
        panel.makeFirstResponder(textView)
    }

    /// Ticks or unticks a clicked box, autosaved like typing. The cursor and
    /// selection stay where they were, also on undo: rather than the text view's
    /// own undo (which selects the changed text, inside the hidden brackets), undo
    /// toggles the box again, and that registers the redo.
    private func toggleCheckbox(at location: Int) {
        guard let edit = MarkdownEditing.toggleCheckbox(in: textView.string, at: location,
                                                        selection: textView.selectedRange()),
              let storage = textView.textStorage else { return }
        textView.breakUndoCoalescing()
        storage.replaceCharacters(in: edit.range, with: edit.replacement)
        textView.didChangeText()
        textView.setSelectedRange(edit.selection)
        textView.undoManager?.registerUndo(withTarget: self) { $0.toggleCheckbox(at: location) }
        textView.undoManager?.setActionName("Checkbox")
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
        // Typing scrolls by itself; also after Return, e.g. back to the start of the line with wrapping off.
        textView.scrollRangeToVisible(edit.selection)
    }

    /// The editor runs on TextKit 1. TextKit 2 lays out an empty last line as if
    /// the paragraph gap above it had full height, so after Return at the end of
    /// a Note the cursor sat lower than the text typed there would. TextKit 1 also
    /// gives the glyph positions clickable checkboxes and line numbers need.
    private static func makeEditorScrollView() -> NSScrollView {
        let textView = EditorTextView(usingTextLayoutManager: false)
        textView.textContainer?.replaceLayoutManager(EditorLayoutManager())
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView
        return scrollView
    }

    private func configure(_ textView: NSTextView) {
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFontPanel = false
        textView.usesFindBar = true  // ticket 24
        textView.isIncrementalSearchingEnabled = true
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

/// Sends `Esc` that no view handled (e.g. in the Note List) to the controller, and
/// handles the panel's own shortcuts. Neither the main menu nor
/// `performKeyEquivalent` can be relied on for those: the panel is non-activating,
/// and while MacJot isn't the active app macOS hands ⌘-keys straight to the focused
/// view (⌃⌘S typed commas into the editor, ⌘N type-selected in the Note List).
/// So they're caught here, as the panel receives them.
final class CapturePanel: NSPanel {
    var onCancel: () -> Void = {}
    /// Return true if the shortcut was handled.
    var onShortcut: (NSEvent) -> Bool = { _ in false }

    override func cancelOperation(_ sender: Any?) {
        onCancel()
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, event.modifierFlags.contains(.command), onShortcut(event) { return }
        super.sendEvent(event)
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

    /// The Notes Folder was renamed or moved: its Notes keep their positions.
    func followFolderMove(from old: URL, to new: URL) {
        var entries = entries
        for (path, entry) in entries where (path as NSString).deletingLastPathComponent == old.path {
            entries[path] = nil
            entries[new.appendingPathComponent((path as NSString).lastPathComponent).path] = entry
        }
        self.entries = entries
    }
}
