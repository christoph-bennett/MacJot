import AppKit
import JotCore
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panel: CapturePanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.make()

        let folder: NotesFolder
        do {
            folder = try NotesFolder(url: Self.defaultNotesFolderURL)
        } catch {
            ErrorAlert.show("Jot couldn't create its Notes Folder.", error: error)
            NSApp.terminate(nil)
            return
        }
        panel = CapturePanelController(folder: folder)
        statusItem = makeStatusItem()
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
