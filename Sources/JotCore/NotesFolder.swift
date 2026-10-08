import Foundation

/// The single facade the app uses for everything Note-related.
///
/// The shell feeds it the editor's text with `update(text:)` and decides when
/// to persist by calling `flush()` (on a debounce) and `leave()` (on close,
/// switching Notes, quit).
///
/// A Draft gets its file in the Notes Folder once its Title is finished (a line
/// break follows it) or when it is left. Until then flushes go to the Recovery
/// Copy, which the next launch turns into a Note if Jot crashed. See ADR 0003.
public final class NotesFolder {
    /// Moves a file to the Trash; injected so tests can observe it.
    public typealias Trash = (URL) throws -> Void

    public let url: URL
    private let recoveryURL: URL
    private let trash: Trash

    /// File of the open Note; `nil` while it is still a Draft or after leaving.
    public private(set) var currentNoteURL: URL?
    /// The slug the open Note's file was named from (its name may carry a `-2` suffix).
    private var currentSlug: String?

    private var isOpen = false
    private var latestText = ""
    /// Text last written, to the Note's file or (while `isInRecovery`) the Recovery Copy.
    private var persistedText = ""
    private var isInRecovery = false

    /// The open Note is a Draft with nothing in it yet: closing it would leave no trace.
    public var isBlankDraft: Bool {
        isOpen && currentNoteURL == nil && Title.isBlank(latestText)
    }

    /// Creates the Notes Folder if needed and turns a Recovery Copy left by a
    /// crash into a Note.
    public init(url: URL, recoveryURL: URL, trash: @escaping Trash) throws {
        self.url = url
        self.recoveryURL = recoveryURL
        self.trash = trash
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: recoveryURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try restoreRecoveryCopy()
    }

    /// Leaves the current Note (saving it) and opens an empty Draft.
    public func startDraft() throws {
        try leave()
        isOpen = true
        latestText = ""
        persistedText = ""
        isInRecovery = false
        currentNoteURL = nil
        currentSlug = nil
    }

    public func update(text: String) {
        guard isOpen else { return }
        latestText = text
    }

    /// Persists the latest text. Returns whether anything was written.
    @discardableResult
    public func flush() throws -> Bool {
        try persist(materialising: false)
    }

    /// Saves and closes the open Note: a Draft with content gets its file, a
    /// retitled Note is renamed, an emptied Note goes to the Trash. If any of
    /// that fails the Note stays open, so its text isn't lost and a retry can follow.
    /// Returns whether anything was written.
    @discardableResult
    public func leave() throws -> Bool {
        var wrote = try persist(materialising: true)
        if let file = currentNoteURL {
            if !Title.isBlank(latestText) {
                wrote = try renameIfNeeded(file) || wrote
            } else if FileManager.default.fileExists(atPath: file.path) {
                // Its last non-blank content goes to the Trash, so it can be restored.
                try trash(file)
                wrote = true
            }
        }
        isOpen = false
        currentNoteURL = nil
        currentSlug = nil
        return wrote
    }

    // MARK: Persisting

    private func persist(materialising: Bool) throws -> Bool {
        guard isOpen else { return false }
        let text = latestText

        if let file = currentNoteURL {
            // Blank text is never written over a Note: leaving trashes it with
            // its last real content instead.
            guard text != persistedText, !Title.isBlank(text) else { return false }
            try Data(text.utf8).write(to: file, options: .atomic)
            persistedText = text
            return true
        }

        guard !Title.isBlank(text) else {
            // The Draft was cleared: nothing left worth recovering.
            try discardRecoveryCopy()
            return false
        }

        if materialising || Title.isFinished(text) {
            let slug = Title.slug(Title.of(text) ?? "")
            currentNoteURL = try create(Data(text.utf8), slug: slug)
            currentSlug = slug
            persistedText = text
            try discardRecoveryCopy()
            return true
        }

        guard !(isInRecovery && text == persistedText) else { return false }
        try Data(text.utf8).write(to: recoveryURL, options: .atomic)
        persistedText = text
        isInRecovery = true
        return true
    }

    // MARK: Recovery Copy

    /// A copy whose text is already a Note (crash between creating the Note's
    /// file and removing the copy) is dropped rather than duplicated. A copy that
    /// exists but can't be read is reported, never silently overwritten.
    private func restoreRecoveryCopy() throws {
        let data: Data
        do {
            data = try Data(contentsOf: recoveryURL)
        } catch CocoaError.fileReadNoSuchFile {
            return
        }
        let text = String(decoding: data, as: UTF8.self)
        if !Title.isBlank(text), try !hasNote(identicalTo: data) {
            _ = try create(data, slug: Title.slug(Title.of(text) ?? ""))
        }
        try removeRecoveryCopy()
    }

    private func hasNote(identicalTo data: Data) throws -> Bool {
        let names = try FileManager.default.contentsOfDirectory(atPath: url.path)
        return names.contains { name in
            name.hasSuffix(".md") && (try? Data(contentsOf: url.appendingPathComponent(name))) == data
        }
    }

    private func discardRecoveryCopy() throws {
        guard isInRecovery else { return }
        try removeRecoveryCopy()
        isInRecovery = false
    }

    private func removeRecoveryCopy() throws {
        do {
            try FileManager.default.removeItem(at: recoveryURL)
        } catch CocoaError.fileNoSuchFile {
            // Already gone.
        }
    }

    // MARK: Naming

    /// Renames the Note's file if its Title's slug changed since the file was named.
    private func renameIfNeeded(_ file: URL) throws -> Bool {
        let slug = Title.slug(Title.of(latestText) ?? "")
        guard slug != currentSlug else { return false }
        currentNoteURL = try place(file, slug: slug)
        currentSlug = slug
        return true
    }

    /// Writes a new Note's file. The text goes to a hidden temporary file first
    /// and is then moved into place, so the Note appears complete or not at all.
    private func create(_ data: Data, slug: String) throws -> URL {
        let temporary = url.appendingPathComponent(".jot-\(UUID().uuidString).tmp")
        try data.write(to: temporary)
        defer { try? FileManager.default.removeItem(at: temporary) }
        return try place(temporary, slug: slug)
    }

    /// Moves `source` to the first free `<slug>.md`, `<slug>-2.md`, … `RENAME_EXCL`
    /// makes each attempt fail rather than replace a file that appeared in the meantime.
    private func place(_ source: URL, slug: String) throws -> URL {
        var suffix = 1
        while true {
            let name = suffix == 1 ? "\(slug).md" : "\(slug)-\(suffix).md"
            let candidate = url.appendingPathComponent(name)
            if renamex_np(source.path, candidate.path, UInt32(RENAME_EXCL)) == 0 {
                return candidate
            }
            guard errno == EEXIST else {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
            suffix += 1
        }
    }
}
