import AppKit
import JotCore
import SwiftUI

/// The Settings window: one window, brought back to the front if it's already
/// open. A segmented control centred in the title bar switches between panes
/// (the layout of sindresorhus/Settings); switching crossfades and resizes the
/// window, keeping its top edge in place.
@MainActor
final class SettingsWindowController: NSObject, NSToolbarDelegate {
    static let datePrefixKey = "datePrefix"
    static let fontSizeKey = "editorFontSize"
    static let defaultFontSize = 14.0
    static let relativeDatesKey = "relativeDates"
    private static let paneKey = "settingsPane"
    private static let switcherID = NSToolbarItem.Identifier("SettingsPanes")

    /// The Date Prefix toggle changed (on the main thread).
    var onDatePrefixChange: (Bool) -> Void = { _ in }
    /// Settings > Editor changed (on the main thread).
    var onFontSizeChange: (CGFloat) -> Void = { _ in }
    var onRelativeDatesChange: (Bool) -> Void = { _ in }
    /// Reset Size & Position was clicked.
    var onResetPanel: () -> Void = {}
    /// The Notes Folder in use, shown in Settings.
    var notesFolderURL: () -> URL? = { nil }
    /// Switches to a newly chosen Notes Folder; throws if it couldn't, and then
    /// the old one is still in use. Returns false if it already was the Notes Folder.
    var onNotesFolderChange: (URL) throws -> Bool = { _ in false }

    private let state = SettingsState()
    private var window: NSWindow?
    private var hosts: [SettingsPane: NSView] = [:]
    private var current: SettingsPane?
    private lazy var switcher: NSSegmentedControl = {
        let control = NSSegmentedControl(labels: SettingsPane.allCases.map(\.title), trackingMode: .selectOne,
                                         target: self, action: #selector(switchPane(_:)))
        // Equal segments, like the toolbar switchers in Apple's apps.
        let font = control.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let widest = SettingsPane.allCases.map { ($0.title as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
        for index in SettingsPane.allCases.indices { control.setWidth(ceil(widest) + 24, forSegment: index) }
        return control
    }()

    func show() {
        if window == nil {
            window = makeWindow()
        } else {
            refresh()  // e.g. the example name with today's date
        }
        guard let window else { return }
        // Jot is a menu-bar app, never active by itself: without this the window
        // would open behind the app the user is in.
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = SettingsWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: true)
        window.contentView = NSView()
        let toolbar = NSToolbar(identifier: "Settings")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        toolbar.centeredItemIdentifiers = [Self.switcherID]
        window.toolbar = toolbar
        window.toolbarStyle = .unified
        // The switcher takes the title's place; the title (the pane's name) still
        // names the window for VoiceOver and Mission Control.
        window.titleVisibility = .hidden
        // The Capture Panel floats; at the same level, Settings opens on top of it.
        window.level = .floating
        window.isReleasedWhenClosed = false
        // Back from System Settings (Login Items) or Finder: show what's true now.
        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window,
                                               queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        self.window = window
        refresh()  // the first pane is sized with its real content
        let saved = UserDefaults.standard.string(forKey: Self.paneKey).flatMap(SettingsPane.init)
        select(saved ?? .general, animated: false)
        window.center()
        return window
    }

    /// Shows the current values, e.g. after the Notes Folder was moved. Nothing
    /// to do while Settings was never opened.
    func refresh() {
        guard window != nil else { return }
        let folder = notesFolderURL()
        state.notesFolder = folder
        state.notesFolderIcon = folder.map { NSWorkspace.shared.icon(forFile: $0.path) }
        state.today = .now
        // As the current keyboard layout labels the keys.
        state.captureHotkey = GlobalHotkey.Combination.defaultCapture.displayString
        state.searchHotkey = GlobalHotkey.Combination.defaultSearch.displayString
        state.launchAtLogin = LaunchAtLogin.state
        // SwiftUI applies the new values on the next pass; the pane may have grown.
        DispatchQueue.main.async { [weak self] in self?.fitWindowToPane() }
    }

    /// The window's content is the current pane at its natural size, top edge fixed.
    private func fitWindowToPane(animated: Bool = false) {
        guard let window, let pane = current, let host = hosts[pane], let container = window.contentView else { return }
        let size = host.fittingSize
        guard host.frame.size != size else { return }
        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: size))
        frame.origin = NSPoint(x: window.frame.minX, y: window.frame.maxY - frame.height)
        window.setFrame(frame, display: true, animate: animated)
        host.frame = NSRect(x: 0, y: container.bounds.height - size.height, width: size.width, height: size.height)
    }

    // MARK: Panes

    @objc private func switchPane(_ control: NSSegmentedControl) {
        select(SettingsPane.allCases[control.selectedSegment], animated: true)
    }

    private func select(_ pane: SettingsPane, animated: Bool) {
        guard let window, let container = window.contentView, pane != current else { return }
        let old = current.flatMap { hosts[$0] }
        current = pane
        switcher.selectedSegment = SettingsPane.allCases.firstIndex(of: pane) ?? 0
        window.title = pane.title
        UserDefaults.standard.set(pane.rawValue, forKey: Self.paneKey)

        let new = hosts[pane] ?? makeHost(for: pane)
        hosts[pane] = new
        let size = new.fittingSize
        // Pinned to the top while the window resizes around it.
        new.frame = NSRect(x: 0, y: container.bounds.height - size.height, width: size.width, height: size.height)
        new.autoresizingMask = [.minYMargin]
        new.alphaValue = animated ? 0 : 1
        container.addSubview(new)

        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: size))
        frame.origin = NSPoint(x: window.frame.minX, y: window.frame.maxY - frame.height)  // top edge stays
        guard animated, let old else {
            old?.removeFromSuperview()
            window.setFrame(frame, display: true)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            old.animator().alphaValue = 0
            new.animator().alphaValue = 1
            window.animator().setFrame(frame, display: true)
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {  // AppKit calls this on the main thread
                // Switched back to it before the crossfade ended: it's the current pane again.
                guard let self, self.current.flatMap({ self.hosts[$0] }) !== old else { return }
                old.removeFromSuperview()
                old.alphaValue = 1
            }
        }
    }

    private func makeHost(for pane: SettingsPane) -> NSView {
        let view: AnyView
        switch pane {
        case .general:
            view = AnyView(GeneralPane(state: state,
                                       onChooseNotesFolder: { [weak self] in self?.chooseNotesFolder() },
                                       onDatePrefixChange: { [weak self] in self?.onDatePrefixChange($0) },
                                       onLaunchAtLoginChange: { [weak self] on in
                                           LaunchAtLogin.set(on)
                                           self?.state.launchAtLogin = LaunchAtLogin.state  // the real outcome
                                       },
                                       onResetPanel: { [weak self] in self?.onResetPanel() }))
        case .editor:
            view = AnyView(EditorPane(onFontSizeChange: { [weak self] in self?.onFontSizeChange($0) },
                                      onRelativeDatesChange: { [weak self] in self?.onRelativeDatesChange($0) }))
        case .shortcuts:
            view = AnyView(ShortcutsPane(state: state))
        }
        let host = NSHostingView(rootView: view)
        // Reports its size (`fittingSize`); placed with a frame, so it doesn't resize the window.
        host.sizingOptions = [.intrinsicContentSize]
        return host
    }

    // MARK: Toolbar

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.switcherID]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.switcherID]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.view = switcher
        item.label = "Settings"
        return item
    }

    /// A folder chooser as a sheet; after a switch, a dialog says the Notes stayed
    /// in the old folder. Jot never moves them itself.
    private func chooseNotesFolder() {
        guard let window else { return }
        let old = notesFolderURL()
        let chooser = NSOpenPanel()
        chooser.canChooseFiles = false
        chooser.canChooseDirectories = true
        chooser.canCreateDirectories = true
        chooser.allowsMultipleSelection = false
        // Opens next to the current folder, where another one can be chosen.
        chooser.directoryURL = old?.deletingLastPathComponent()
        chooser.message = "Choose the folder Jot keeps your notes in."
        chooser.prompt = "Choose"
        chooser.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .OK, let new = chooser.url else { return }
            guard let service = CloudFolder.service(syncing: new) else {
                return switchFolder(to: new, from: old, window: window)
            }
            warnAboutCloudFolder(new, syncedBy: service, window: window) { [weak self] in
                self?.switchFolder(to: new, from: old, window: window)
            }
        }
    }

    private func switchFolder(to new: URL, from old: URL?, window: NSWindow) {
        do {
            guard try onNotesFolderChange(new) else { return }
        } catch {
            ErrorAlert.show("Jot couldn’t switch to “\(new.lastPathComponent)”.", error: error)
            return
        }
        refresh()
        if let old { tellNotesStayed(in: old, newFolder: new, window: window) }
    }

    /// Possible, but only safe if the folder stays downloaded: the service may
    /// replace Notes with placeholders at any time to free up space.
    private func warnAboutCloudFolder(_ folder: URL, syncedBy service: String, window: NSWindow,
                                      then proceed: @escaping () -> Void) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "“\(folder.lastPathComponent)” is in \(service)"
        let keepDownloaded = service == "iCloud Drive"
            ? "In Finder, Control-click the folder and choose Keep Downloaded."
            : "In Finder or in \(service)’s settings, make the folder available offline."
        alert.informativeText = "\(service) can remove the files on this Mac at any time to free up space, keeping "
            + "only placeholders. Jot then has to wait for a note to download before it can list, search or open it, "
            + "and can’t while you’re offline. Use this folder only if it always stays downloaded. \(keepDownloaded)"
        alert.addButton(withTitle: "Use This Folder")
        alert.addButton(withTitle: "Cancel").keyEquivalent = "\u{1b}"
        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn { proceed() }
        }
    }

    private func tellNotesStayed(in old: URL, newFolder new: URL, window: NSWindow) {
        let alert = NSAlert()
        alert.messageText = "Your existing notes weren’t moved"
        alert.informativeText = "New notes now go to “\(new.lastPathComponent)”. Notes in “\(old.lastPathComponent)” stay "
            + "there and no longer show in Jot. To keep them in Jot, move them to the new folder in Finder."
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Show Old Folder")
        alert.beginSheetModal(for: window) { response in
            if response == .alertSecondButtonReturn {
                // Opens a Finder window with the old folder's contents, ready to move.
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: old.path)
            }
        }
    }
}

/// `Esc` closes Settings, like the Capture Panel.
private final class SettingsWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) {
        close()
    }
}
