import AppKit
import JotCore
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panel: CapturePanelController?
    private var captureHotkey: GlobalHotkey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let folder: NotesFolder
        do {
            folder = try NotesFolder(url: Self.defaultNotesFolderURL)
        } catch {
            ErrorAlert.show("Jot couldn't create its Notes Folder.", error: error)
            NSApp.terminate(nil)
            return
        }
        let panel = CapturePanelController(folder: folder)
        self.panel = panel
        NSApp.mainMenu = MainMenu.make(newNoteTarget: panel)
        statusItem = makeStatusItem()
        registerCaptureHotkey()
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
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Jot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        return item
    }

    @objc private func newNote() {
        panel?.showNewDraft()
    }

    // MARK: Hotkeys

    private func registerCaptureHotkey() {
        do {
            captureHotkey = try GlobalHotkey(.defaultCapture) { [weak self] in
                self?.panel?.toggleCapture()
            }
        } catch {
            // Reported in Settings once hotkeys are configurable (ticket 13).
            NSLog("Jot: couldn't register the Capture Hotkey: \(error)")
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

    private static var defaultNotesFolderURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Jot", isDirectory: true)
    }
}
