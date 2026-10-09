import Foundation

/// Recognises a folder that a cloud service syncs. Such services can remove
/// the local copies of files at any time to free up space, keeping only a
/// placeholder; Notes in it may then have to download before Jot can read them.
public enum CloudFolder {
    /// The service that syncs `folder` ("iCloud Drive", "Dropbox", "Google Drive", …),
    /// or nil for a local folder. iCloud Drive keeps its folders in
    /// `~/Library/Mobile Documents`, File Provider services (Dropbox, Google
    /// Drive, OneDrive, Box, …) in `~/Library/CloudStorage/<Service>-<account>`.
    /// Desktop and Documents synced by iCloud are recognised by asking the system.
    public static func service(syncing folder: URL, home: URL = FileManager.default.homeDirectoryForCurrentUser) -> String? {
        let path = folder.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        let library = home.standardizedFileURL.resolvingSymlinksInPath().pathComponents + ["Library"]
        if path.count > library.count + 1, Array(path.prefix(library.count)) == library {
            switch path[library.count] {
            case "Mobile Documents":
                return "iCloud Drive"
            case "CloudStorage":
                return displayName(ofCloudStorageFolder: path[library.count + 1])
            default:
                break
            }
        }
        let isICloud = (try? folder.resourceValues(forKeys: [.isUbiquitousItemKey]))?.isUbiquitousItem ?? false
        return isICloud ? "iCloud Drive" : nil
    }

    /// `GoogleDrive-someone@gmail.com` → "Google Drive", `Dropbox` → "Dropbox".
    private static func displayName(ofCloudStorageFolder name: String) -> String {
        let service = String(name.prefix { $0 != "-" })
        let known = ["GoogleDrive": "Google Drive", "iCloudDrive": "iCloud Drive", "OneDrive": "OneDrive",
                     "Dropbox": "Dropbox", "Box": "Box"]
        return known[service] ?? service
    }
}
