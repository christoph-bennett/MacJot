import Foundation

/// Finds the Notes Folder again after it disappeared from its path. Jot keeps
/// a bookmark next to the path; the bookmark follows the folder when it's
/// renamed or moved, but a folder in the Trash is never followed.
public enum FolderLocation {
    public enum Status: Equatable {
        /// A folder is at the path.
        case inPlace
        /// Renamed or moved; it's now here.
        case moved(URL)
        /// Moved to the Trash.
        case trashed
        /// Not at its path, and the bookmark finds nothing: deleted, or on a
        /// drive that isn't connected.
        case gone
        /// Not at its path, and there's no bookmark to follow.
        case missing
    }

    public static func bookmark(for folder: URL) -> Data? {
        try? folder.bookmarkData()
    }

    public static func status(of folder: URL, bookmark: Data?) -> Status {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return .inPlace
        }
        guard let bookmark else { return .missing }
        var isStale = false
        guard let found = try? URL(resolvingBookmarkData: bookmark, options: [.withoutUI, .withoutMounting],
                                   bookmarkDataIsStale: &isStale),
              FileManager.default.fileExists(atPath: found.path, isDirectory: &isDirectory), isDirectory.boolValue
        else { return .gone }
        // The user's Trash is `~/.Trash`, other volumes' are `.Trashes`.
        if found.pathComponents.contains(where: { $0 == ".Trash" || $0 == ".Trashes" }) { return .trashed }
        return .moved(found)
    }
}
