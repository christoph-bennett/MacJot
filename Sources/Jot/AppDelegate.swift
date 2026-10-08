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

    func applicationDidFinishLaunching(_ notification: Notification) {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            CapturePanelController.confirmTrashKey: true,
            SettingsWindowController.datePrefixKey: false,
        ])
        let folder: NotesFolder
        do {
            folder = try NotesFolder(url: Self.defaultNotesFolderURL, recoveryURL: Self.recoveryURL,
                                     datePrefix: defaults.bool(forKey: SettingsWindowController.datePrefixKey)) { url in
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            }
        } catch {
            ErrorAlert.show("Jot couldn’t open its Notes Folder.", error: error)
            NSApp.terminate(nil)
            return
        }
        settings.onDatePrefixChange = { [weak folder] in folder?.usesDatePrefix = $0 }
        let panel = CapturePanelController(folder: folder)
        panel.onShowSettings = { [weak self] in self?.showSettings() }
        self.panel = panel
        NSApp.mainMenu = MainMenu.make(newNoteTarget: panel, settingsTarget: self)
        statusItem = makeStatusItem()
        registerHotkeys()
        registerLaunchAtLoginOnFirstRun()
    }

    func applicationWillTerminate(_ notification: Notification) {
        panel?.saveBeforeQuit()
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

    private static var defaultNotesFolderURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Jot", isDirectory: true)
    }
}
