import AppKit
import JotCore
import SwiftUI

/// The Settings window: one window, brought back to the front if it's already open.
@MainActor
final class SettingsWindowController {
    static let datePrefixKey = "datePrefix"

    /// The Date Prefix toggle changed (on the main thread).
    var onDatePrefixChange: (Bool) -> Void = { _ in }
    /// The Notes Folder in use, shown in Settings.
    var notesFolderURL: () -> URL? = { nil }
    /// Switches to a newly chosen Notes Folder; throws if it couldn't, and then
    /// the old one is still in use. Returns false if it already was the Notes Folder.
    var onNotesFolderChange: (URL) throws -> Bool = { _ in false }

    private var window: NSWindow?
    private var host: NSHostingController<SettingsView>?

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        refresh()  // redraws the example name with today's date
        // Jot is a menu-bar app, never active by itself: without this the window
        // would open behind the app the user is in.
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let host = NSHostingController(rootView: makeView())
        self.host = host
        let window = SettingsWindow(contentViewController: host)
        window.title = "Jot Settings"
        window.styleMask = [.titled, .closable]
        // The Capture Panel floats; at the same level, Settings opens on top of it.
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    /// Shows the current values, e.g. after the Notes Folder was moved.
    func refresh() {
        host?.rootView = makeView()
    }

    private func makeView() -> SettingsView {
        let folder = notesFolderURL()
        return SettingsView(notesFolder: folder,
                            notesFolderIcon: folder.map { NSWorkspace.shared.icon(forFile: $0.path) },
                            onChooseNotesFolder: { [weak self] in self?.chooseNotesFolder() },
                            onDatePrefixChange: { [weak self] in self?.onDatePrefixChange($0) })
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
            do {
                guard try onNotesFolderChange(new) else { return }
            } catch {
                ErrorAlert.show("Jot couldn’t switch to “\(new.lastPathComponent)”.", error: error)
                return
            }
            refresh()
            if let old { tellNotesStayed(in: old, newFolder: new, window: window) }
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

private struct SettingsView: View {
    @AppStorage(SettingsWindowController.datePrefixKey) private var datePrefix = false
    let notesFolder: URL?
    let notesFolderIcon: NSImage?
    let onChooseNotesFolder: () -> Void
    let onDatePrefixChange: (Bool) -> Void

    var body: some View {
        Form {
            Section {
                LabeledContent("Notes Folder") {
                    HStack(spacing: 6) {
                        if let notesFolder, let notesFolderIcon {
                            Image(nsImage: notesFolderIcon)
                                .resizable()
                                .frame(width: 16, height: 16)
                            Text(notesFolder.lastPathComponent)
                        }
                        Button("Choose…", action: onChooseNotesFolder)
                    }
                }
            } footer: {
                VStack(alignment: .leading, spacing: 2) {
                    if let notesFolder {
                        Text(SavedNotesFolder.display(notesFolder))
                            .truncationMode(.middle)
                            .lineLimit(1)
                            .textSelection(.enabled)
                    }
                    Text("Choosing another folder doesn’t move your notes.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Section {
                Toggle("Start file names with the creation date", isOn: $datePrefix)
            } footer: {
                VStack(alignment: .leading, spacing: 2) {
                    // Today's date, so the example matches what the next Note gets.
                    Text("New notes are named like “\(DatePrefix.string(for: .now))plan.md”.")
                    Text("Existing files keep their names.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onChange(of: datePrefix) { _, on in onDatePrefixChange(on) }
        .frame(width: 440)
        .fixedSize()
    }
}

/// `Esc` closes Settings, like the Capture Panel.
private final class SettingsWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) {
        close()
    }
}
