import Foundation

/// The single facade the app uses for everything Note-related.
///
/// The shell feeds it the editor's text with `update(text:)` and decides when
/// to persist by calling `flush()` (on a debounce) and `leave()` (on close,
/// switching Notes, quit). A Draft has no file until it has content.
public final class NotesFolder {
    public let url: URL

    /// File of the open Note; `nil` while it is still a Draft or after leaving.
    public private(set) var currentNoteURL: URL?

    private var isOpen = false
    private var latestText = ""
    private var persistedText = ""

    public init(url: URL) throws {
        self.url = url
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    /// Leaves the current Note (saving it) and opens an empty Draft.
    public func startDraft() throws {
        try leave()
        isOpen = true
        latestText = ""
        persistedText = ""
        currentNoteURL = nil
    }

    public func update(text: String) {
        guard isOpen else { return }
        latestText = text
    }

    /// Persists the latest text. A Draft whose text is still blank stays without a file.
    /// Returns whether anything was written.
    @discardableResult
    public func flush() throws -> Bool {
        guard isOpen, latestText != persistedText else { return false }
        let text = latestText
        let data = Data(text.utf8)
        if let fileURL = currentNoteURL {
            try data.write(to: fileURL, options: .atomic)
        } else {
            guard let title = Title.of(text) else { return false }
            currentNoteURL = try create(data, slug: Title.slug(title))
        }
        persistedText = text
        return true
    }

    /// Saves and closes the open Note. If saving fails the Note stays open, so
    /// its text isn't lost and a later flush can retry.
    /// Returns whether anything was written.
    @discardableResult
    public func leave() throws -> Bool {
        let wrote = try flush()
        isOpen = false
        currentNoteURL = nil
        return wrote
    }

    /// Writes a new file, claiming the first free `<slug>.md`, `<slug>-2.md`, …
    /// The text goes to a hidden temporary file first and is then renamed into
    /// place with `RENAME_EXCL`, so the new Note appears complete or not at all,
    /// and never replaces a file that appeared in the meantime.
    private func create(_ data: Data, slug: String) throws -> URL {
        let temporary = url.appendingPathComponent(".jot-\(UUID().uuidString).tmp")
        try data.write(to: temporary)
        defer { try? FileManager.default.removeItem(at: temporary) }

        var suffix = 1
        while true {
            let name = suffix == 1 ? "\(slug).md" : "\(slug)-\(suffix).md"
            let candidate = url.appendingPathComponent(name)
            if renamex_np(temporary.path, candidate.path, UInt32(RENAME_EXCL)) == 0 {
                return candidate
            }
            guard errno == EEXIST else {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
            suffix += 1
        }
    }
}
