import AppKit

/// MacJot never shows a menu bar of its own, but the main menu is what routes
/// ⌘N, ⌃⌘S, ⌘C, ⌘V, ⌘Z, ⌘A, ⌘F (Find), ⌘W, ⌘, and ⌘Q to the panel, text view and
/// Settings window (the panel also catches its own, see `CapturePanel`).
@MainActor
enum MainMenu {
    static func make(newNoteTarget: CapturePanelController, settingsTarget: AppDelegate) -> NSMenu {
        let main = NSMenu()

        let app = NSMenu()
        app.addItem(withTitle: "Settings…", action: #selector(AppDelegate.showSettings), keyEquivalent: ",")
            .target = settingsTarget
        app.addItem(.separator())
        app.addItem(withTitle: "Quit MacJot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        main.addItem(submenu: app, title: "MacJot")

        let file = NSMenu(title: "File")
        file.addItem(withTitle: "New Note", action: #selector(CapturePanelController.showNewDraft), keyEquivalent: "n")
            .target = newNoteTarget
        file.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        main.addItem(submenu: file, title: "File")

        let view = NSMenu(title: "View")
        // ⌃⌘S, Apple's "Show Sidebar": unlike ⌘\ it's the same on every keyboard layout.
        let toggleList = view.addItem(withTitle: "Toggle Note List", action: #selector(CapturePanelController.toggleNoteList), keyEquivalent: "s")
        toggleList.keyEquivalentModifierMask = [.control, .command]
        toggleList.target = newNoteTarget
        // ⌥⌘I as in TextEdit and BBEdit; checked while on (`validateMenuItem`).
        let invisibles = view.addItem(withTitle: "Show Invisibles", action: #selector(CapturePanelController.toggleInvisibles),
                                      keyEquivalent: "i")
        invisibles.keyEquivalentModifierMask = [.option, .command]
        invisibles.target = newNoteTarget
        main.addItem(submenu: view, title: "View")

        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        edit.addItem(.separator())
        let find = NSMenu(title: "Find")
        for (title, action, key, modifiers) in [
            ("Find…", NSTextFinder.Action.showFindInterface, "f", NSEvent.ModifierFlags.command),
            ("Find and Replace…", .showReplaceInterface, "f", [.option, .command]),
            ("Find Next", .nextMatch, "g", .command),
            ("Find Previous", .previousMatch, "g", [.shift, .command]),
            ("Use Selection for Find", .setSearchString, "e", .command),
        ] {
            let item = find.addItem(withTitle: title, action: #selector(CapturePanelController.performFind(_:)), keyEquivalent: key)
            item.keyEquivalentModifierMask = modifiers
            item.tag = action.rawValue
            item.target = newNoteTarget
        }
        edit.addItem(submenu: find, title: "Find")
        main.addItem(submenu: edit, title: "Edit")

        return main
    }
}

private extension NSMenu {
    func addItem(submenu: NSMenu, title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        addItem(item)
    }
}
