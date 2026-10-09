import AppKit
import JotCore
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panel: CapturePanelController?
    private let settings = SettingsWindowController()
    private var captureHotkey: GlobalHotkey?
    private var searchHotkey: GlobalHotkey?
    private var terminationSignal: DispatchSourceSignal?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            CapturePanelController.confirmTrashKey: true,
            SettingsWindowController.datePrefixKey: false,
        ])
        guard let folder = openNotesFolder() else {
            NSApp.terminate(nil)
            return
        }
        settings.onDatePrefixChange = { [weak folder] in folder?.usesDatePrefix = $0 }
        let panel = CapturePanelController(folder: folder)
        panel.onShowSettings = { [weak self] in self?.showSettings() }
        panel.onFolderMoved = { [weak self] in self?.settings.refresh() }
        settings.notesFolderURL = { [weak folder] in folder?.url }
        settings.onNotesFolderChange = { [weak panel] url in
            guard let panel else { return false }
            let switched = try panel.switchFolder(to: url)
            // Also when it didn't switch: after falling back to the default folder at
            // launch, choosing the default replaces the unreachable saved one.
            SavedNotesFolder.save(url)
            return switched
        }
        self.panel = panel
        NSApp.mainMenu = MainMenu.make(newNoteTarget: panel, settingsTarget: self)
        statusItem = makeStatusItem()
        registerHotkeys()
        registerLaunchAtLoginOnFirstRun()
        quitNormallyOnTerminationSignal()
    }

    /// `kill`/`pkill` (e.g. scripts/install.sh) send SIGTERM, which would end Jot
    /// on the spot; quit normally instead, so the open Note is saved.
    private func quitNormallyOnTerminationSignal() {
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler { NSApp.terminate(nil) }
        source.resume()
        terminationSignal = source
    }

    func applicationWillTerminate(_ notification: Notification) {
        panel?.saveBeforeQuit()
    }

    /// The saved Notes Folder. Followed if it was renamed or moved; if it's in
    /// the Trash or gone, the user decides between a new, empty one and quitting.
    /// If it can't be created (e.g. a drive that isn't connected), the default
    /// folder, after telling the user; the choice stays saved for the next launch.
    private func openNotesFolder() -> NotesFolder? {
        let defaults = UserDefaults.standard
        let make = { (url: URL) in
            try NotesFolder(url: url, recoveryURL: Self.recoveryURL,
                            datePrefix: defaults.bool(forKey: SettingsWindowController.datePrefixKey)) { url in
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            }
        }
        var chosen = SavedNotesFolder.url
        let status = SavedNotesFolder.status
        switch status {
        case .inPlace, .missing:
            break  // .missing: never opened with a bookmark (first launch); created quietly
        case .moved(let found):
            SavedNotesFolder.tellFollowed(from: chosen, to: found)
            chosen = found
        case .trashed, .gone:
            guard SavedNotesFolder.askToRecreate(chosen, trashed: status == .trashed) else { return nil }
        }
        do {
            let folder = try make(chosen)
            SavedNotesFolder.save(chosen)  // a fresh bookmark for the folder in use
            return folder
        } catch {
            let fallback = SavedNotesFolder.defaultURL
            guard chosen.standardizedFileURL != fallback.standardizedFileURL, let folder = try? make(fallback) else {
                ErrorAlert.show("Jot couldn’t open its Notes Folder.", error: error)
                return nil
            }
            ErrorAlert.show("Jot couldn’t open the Notes Folder “\(chosen.path)”. It’s using “\(fallback.path)” for now.",
                            error: error)
            return folder
        }
    }

    // MARK: Menu bar

    private func makeStatusItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Jot")
        item.button?.toolTip = "Jot"

        let menu = NSMenu()
        menu.addItem(withTitle: "New Note", action: #selector(newNote), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Show Notes", action: #selector(showNotes), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Jot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        return item
    }

    @objc private func newNote() {
        panel?.showNewDraft()
    }

    @objc private func showNotes() {
        panel?.showNotes()
    }

    @objc func showSettings() {
        settings.show()
    }

    // MARK: Hotkeys

    private func registerHotkeys() {
        // Failures are reported in Settings once hotkeys are configurable (ticket 13).
        do {
            captureHotkey = try GlobalHotkey(.defaultCapture) { [weak self] in self?.panel?.toggleCapture() }
        } catch {
            NSLog("Jot: couldn't register the Capture Hotkey: \(error)")
        }
        do {
            searchHotkey = try GlobalHotkey(.defaultSearch) { [weak self] in self?.panel?.toggleNotes() }
        } catch {
            NSLog("Jot: couldn't register the Search Hotkey: \(error)")
        }
    }

    // MARK: Launch at login

    private static let didRegisterLoginItemKey = "didRegisterLoginItem"

    /// Launch at login is on by default: register once, then leave it to the user
    /// (the toggle in Settings comes in a later ticket). Only possible from an app bundle.
    private func registerLaunchAtLoginOnFirstRun() {
        let defaults = UserDefaults.standard
        guard Bundle.main.bundleURL.pathExtension == "app",
              !defaults.bool(forKey: Self.didRegisterLoginItemKey) else { return }
        do {
            try SMAppService.mainApp.register()
            defaults.set(true, forKey: Self.didRegisterLoginItemKey)
        } catch {
            NSLog("Jot: couldn't register launch at login: \(error)")
        }
    }

    /// Holds a Draft's text until its Title is finished; outside the Notes Folder on purpose.
    private static var recoveryURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Jot", isDirectory: true)
            .appendingPathComponent("recovery.md")
    }
}
