import AppKit
import JotCore

/// The Notes Folder MacJot uses, kept in the preferences as a path plus a bookmark,
/// so MacJot can tell when the folder was renamed, moved or trashed.
@MainActor
enum SavedNotesFolder {
    static let pathKey = "notesFolder"
    private static let bookmarkKey = "notesFolderBookmark"

    /// The saved folder, or the default one if none was saved yet.
    static var url: URL {
        UserDefaults.standard.string(forKey: pathKey).map { URL(fileURLWithPath: $0, isDirectory: true) } ?? defaultURL
    }

    static var bookmark: Data? {
        UserDefaults.standard.data(forKey: bookmarkKey)
    }

    static var status: FolderLocation.Status {
        FolderLocation.status(of: url, bookmark: bookmark)
    }

    static func save(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: pathKey)
        UserDefaults.standard.set(FolderLocation.bookmark(for: url), forKey: bookmarkKey)
    }

    static var defaultURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MacJot", isDirectory: true)
    }

    // MARK: Alerts

    static func tellFollowed(from old: URL, to new: URL) {
        let alert = NSAlert()
        alert.messageText = "Your Notes Folder was moved"
        alert.informativeText = "“\(old.lastPathComponent)” is now at \(display(new)). MacJot uses it there."
        NSApp.activate()
        alert.runModal()
    }

    /// The folder is in the Trash or can't be found. Returns true to create a new,
    /// empty folder at its path, false to quit (e.g. to put it back first).
    static func askToRecreate(_ folder: URL, trashed: Bool) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        if trashed {
            alert.messageText = "Your Notes Folder is in the Trash"
            alert.informativeText = "To keep using your notes, quit MacJot, put “\(folder.lastPathComponent)” back from "
                + "the Trash and open MacJot again. Or create a new, empty folder at \(display(folder))."
        } else {
            alert.messageText = "MacJot can’t find your Notes Folder"
            alert.informativeText = "“\(folder.lastPathComponent)” is no longer at \(display(folder)). If it’s on a "
                + "drive that isn’t connected, quit MacJot, connect the drive and open MacJot again. Or create a new, empty folder there."
        }
        alert.addButton(withTitle: "Quit MacJot")
        alert.addButton(withTitle: "Create New Folder")
        NSApp.activate()
        return alert.runModal() == .alertSecondButtonReturn
    }

    /// `~/Documents/MacJot`.
    static func display(_ url: URL) -> String {
        (url.path as NSString).abbreviatingWithTildeInPath
    }
}
