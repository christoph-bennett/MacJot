import AppKit
import JotCore
import KeyboardShortcuts
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private var panel: CapturePanelController?
    private let settings = SettingsWindowController()
    private var terminationSignal: DispatchSourceSignal?
    private var firstLaunchHint: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            CapturePanelController.confirmTrashKey: true,
            SettingsWindowController.datePrefixKey: false,
            SettingsWindowController.fontSizeKey: SettingsWindowController.defaultFontSize,
            SettingsWindowController.relativeDatesKey: true,
            SettingsWindowController.lineNumbersKey: true,
        ])
        // No preferences yet: opening the Notes Folder below saves the first one.
        let isFirstLaunch = defaults.object(forKey: SavedNotesFolder.pathKey) == nil
        guard let folder = openNotesFolder() else {
            NSApp.terminate(nil)
            return
        }
        settings.onDatePrefixChange = { [weak folder] in folder?.usesDatePrefix = $0 }
        let panel = CapturePanelController(folder: folder)
        panel.onShowSettings = { [weak self] in self?.showSettings() }
        panel.onFolderMoved = { [weak self] in self?.settings.refresh() }
        panel.setFontSize(defaults.double(forKey: SettingsWindowController.fontSizeKey))
        panel.setRelativeDates(defaults.bool(forKey: SettingsWindowController.relativeDatesKey))
        panel.setLineNumbers(defaults.bool(forKey: SettingsWindowController.lineNumbersKey))
        settings.onLineNumbersChange = { [weak panel] in panel?.setLineNumbers($0) }
        settings.onFontSizeChange = { [weak panel] in panel?.setFontSize($0) }
        settings.onRelativeDatesChange = { [weak panel] in panel?.setRelativeDates($0) }
        settings.onResetPanel = { [weak panel] in panel?.resetFrame() }
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
        LaunchAtLogin.turnOnOnFirstRun()
        quitNormallyOnTerminationSignal()
        if isFirstLaunch {
            showFirstLaunchHint()
            panel.showNewDraft()  // after the hint, so typing goes to the Draft
        }
    }

    /// No onboarding: on first launch a popover at the menu bar icon names both
    /// hotkeys, next to a new Draft that's ready to type into. It closes when
    /// the user clicks anywhere else.
    func popoverDidClose(_ notification: Notification) {
        firstLaunchHint = nil
    }

    private func showFirstLaunchHint() {
        guard let button = statusItem?.button else { return }
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: FirstLaunchHint(
            capture: Hotkey.capture.displayString, search: Hotkey.search.displayString))
        popover.delegate = self
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        firstLaunchHint = popover
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

    /// KeyboardShortcuts re-registers a hotkey when Settings records a new combination.
    private func registerHotkeys() {
        for hotkey in Hotkey.allCases { hotkey.checkAvailableBeforeRegistering() }
        KeyboardShortcuts.onKeyDown(for: Hotkey.capture.name) { [weak self] in self?.panel?.toggleCapture() }
        KeyboardShortcuts.onKeyDown(for: Hotkey.search.name) { [weak self] in self?.panel?.toggleNotes() }
    }

    /// Holds a Draft's text until its Title is finished; outside the Notes Folder on purpose.
    private static var recoveryURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Jot", isDirectory: true)
            .appendingPathComponent("recovery.md")
    }
}

private struct FirstLaunchHint: View {
    /// Nil if the user turned it off before (a reinstall keeps the hotkeys).
    let capture: String?
    let search: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Jot lives here in the menu bar.")
                .font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                if let capture {
                    GridRow {
                        Text(capture).monospaced()
                        Text("Write a new note, from any app")
                    }
                }
                if let search {
                    GridRow {
                        Text(search).monospaced()
                        Text("Find a note")
                    }
                }
            }
            if capture == nil && search == nil {
                Text("Set hotkeys for writing and finding notes in Settings, under Shortcuts.")
            }
            Text("Settings are in this icon’s menu.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .fixedSize()
    }
}
