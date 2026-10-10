import Foundation

/// The single facade the app uses for everything Note-related.
///
/// The shell feeds it the editor's text with `update(text:)` and decides when
/// to persist by calling `flush()` (on a debounce) and `leave()` (on close,
/// switching Notes, quit).
///
/// A Draft gets its file in the Notes Folder once its Title is finished (a line
/// break follows it) or when it is left. Until then flushes go to the Recovery
/// Copy, which the next launch turns into a Note if MacJot crashed. See ADR 0003.
public final class NotesFolder {
    /// Moves a file to the Trash; injected so tests can observe it.
    public typealias Trash = (URL) throws -> Void

    /// The Notes Folder; changed only by `switchFolder(to:)`.
    public private(set) var url: URL
    private let recoveryURL: URL
    private let moveToTrash: Trash
    private let clock: () -> Date

    /// New Notes' filenames start with their creation day (`2026-10-08-plan.md`).
    /// Affects only Notes created from now on; existing files keep their names.
    public var usesDatePrefix: Bool

    /// File of the open Note; `nil` while it is still a Draft or after leaving.
    public private(set) var currentNoteURL: URL? {
        didSet { rememberFileIdentity() }
    }
    /// The open Note's file on disk (device and inode), to recognise it when it's
    /// renamed elsewhere. Changes with each of MacJot's atomic writes.
    private var currentFileIdentity: [Int]?
    /// Where the Note left last ended up: after a rename, or the file a Draft got
    /// on leaving. `nil` if it left nothing behind (blank Draft, trashed Note).
    public private(set) var lastLeftNoteURL: URL?
    /// Increases each time a Note is actually left, so callers can tell whether an
    /// operation (`open`, `startDraft`) left one.
    public private(set) var leaveCount = 0
    /// The slug the open Note's file was named from (its name may carry a `-2` suffix).
    private var currentSlug: String?
    /// The open Note's Date Prefix, kept when it's renamed; empty if it has none.
    private var currentPrefix = ""
    /// When the open Draft was started: its creation day, for the Date Prefix.
    private var draftStarted: Date

    private var isOpen = false
    private var latestText = ""
    /// Text last written, to the Note's file or (while `isInRecovery`) the Recovery Copy.
    private var persistedText = ""
    private var isInRecovery = false
    /// The longest text the open Note's file has had since it was opened: what
    /// goes to the Trash if the Note is emptied, however slowly (ticket 26).
    private var longestSavedText = ""

    /// The Outside File shown instead of a Note (ticket 31, ADR 0007): read-only,
    /// never written; forgotten when it's left. While it's shown no Note is open.
    public private(set) var outsideFileURL: URL?
    /// Its text as last read, to tell when another app changed it.
    private var outsideText = ""

    /// The open Note is a Draft: it has no file in the Notes Folder yet.
    public var isDraft: Bool {
        isOpen && currentNoteURL == nil
    }

    /// The open Note is a Draft with nothing in it yet: closing it would leave no trace.
    public var isBlankDraft: Bool {
        isOpen && currentNoteURL == nil && Title.isBlank(latestText)
    }

    /// Leaving now would move the open Note to the Trash: it has a file, the user
    /// emptied it, and it wasn't blank when saved (a file blank when opened stays).
    /// The editor shows a hint then (ticket 25).
    public var wouldTrashOnLeave: Bool {
        isOpen && currentNoteURL != nil && Title.isBlank(latestText) && !Title.isBlank(persistedText)
    }

    /// Creates the Notes Folder if needed and turns a Recovery Copy left by a
    /// crash into a Note.
    public init(url: URL, recoveryURL: URL, clock: @escaping () -> Date = Date.init, datePrefix: Bool = false,
                trash: @escaping Trash) throws {
        self.url = url
        self.recoveryURL = recoveryURL
        self.moveToTrash = trash
        self.clock = clock
        self.usesDatePrefix = datePrefix
        draftStarted = clock()
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
        longestSavedText = ""
        isInRecovery = false
        currentNoteURL = nil
        currentSlug = nil
        currentPrefix = ""
        draftStarted = clock()
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
        outsideFileURL = nil
        outsideText = ""
        guard isOpen else { return false }
        var wrote = try persist(materialising: true)
        var left = currentNoteURL
        if let file = currentNoteURL {
            if !Title.isBlank(latestText) {
                wrote = try renameIfNeeded(file) || wrote
                left = currentNoteURL
            } else if wouldTrashOnLeave {
                // Emptied by the user: its longest content since it was opened goes
                // to the Trash, so it can be restored. A file that was blank when
                // opened stays.
                if FileManager.default.fileExists(atPath: file.path) {
                    if longestSavedText != persistedText {
                        try Data(longestSavedText.utf8).write(to: file, options: .atomic)
                    }
                    try moveToTrash(file)
                    wrote = true
                }
                left = nil
            }
        }
        close()
        lastLeftNoteURL = left
        leaveCount += 1
        return wrote
    }

    /// Makes `newURL` the Notes Folder, creating it if needed. The open Note is
    /// saved and left first, so it ends up in the old folder; no files are moved
    /// or copied. If saving fails, the old folder stays in use (the new one may
    /// already have been created). Returns false if `newURL` already is the Notes
    /// Folder, by another path or not.
    @discardableResult
    public func switchFolder(to newURL: URL) throws -> Bool {
        guard !isSameFolder(newURL, url) else { return false }
        guard !isSameFolder(newURL, recoveryURL.deletingLastPathComponent()) else { throw SwitchError.holdsRecoveryCopy }
        try FileManager.default.createDirectory(at: newURL, withIntermediateDirectories: true)
        try leave()
        url = newURL
        summaries = [:]
        return true
    }

    /// The Notes Folder itself was renamed or moved elsewhere: use it at
    /// `newURL`. The open Note moved with it and stays open.
    public func followMove(to newURL: URL) {
        if let current = currentNoteURL { currentNoteURL = newURL.appendingPathComponent(current.lastPathComponent) }
        url = newURL
        summaries = [:]
    }

    public enum SwitchError: LocalizedError, Equatable {
        /// MacJot keeps the Recovery Copy there; as Notes Folder it would list it as a Note.
        case holdsRecoveryCopy

        public var errorDescription: String? {
            "MacJot keeps its own files in this folder. Choose another one."
        }
    }

    /// Same path, or the same folder on disk reached through a symlink or
    /// another letter case.
    private func isSameFolder(_ a: URL, _ b: URL) -> Bool {
        if a.standardizedFileURL.resolvingSymlinksInPath() == b.standardizedFileURL.resolvingSymlinksInPath() { return true }
        guard let identity = Self.identity(of: a) else { return false }
        return identity == Self.identity(of: b)
    }

    // MARK: Note List

    /// All Notes in the folder (visible `.md` files), most recently modified first.
    /// Files unchanged since the last call aren't read again: the list reloads on
    /// every autosave, and summarising every line of every Note each time adds up.
    public func notes() throws -> [NoteSummary] {
        let files = try FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey], options: [.skipsHiddenFiles])
        let notes = files
            .filter { $0.pathExtension.lowercased() == "md" }
            .compactMap { file -> NoteSummary? in
                let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                    ?? .distantPast
                if let cached = summaries[file], cached.modified == modified { return cached }
                guard let text = try? String(contentsOf: file, encoding: .utf8) else { return nil }
                return NoteSummary(url: file, text: text, modified: modified, created: created(file, text: text))
            }
            .sorted { $0.modified > $1.modified }
        summaries = Dictionary(notes.map { ($0.url, $0) }, uniquingKeysWith: { a, _ in a })
        return notes
    }

    /// From the Date Prefix if the file has one, else the file system's creation date.
    private func created(_ file: URL, text: String) -> Date {
        let slug = Title.slug(Title.of(text) ?? "")
        if let prefix = DatePrefix.of(fileName: file.lastPathComponent, titleSlug: slug),
           let day = DatePrefix.day(of: prefix) { return day }
        return (try? file.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
    }

    /// Where a file opened from Finder sits relative to the Notes Folder
    /// (tickets 30 and 31). Only a Note can be edited; the rest open read-only.
    public enum Placement: Equatable {
        /// One of the folder's Notes, as `notes()` lists them: a visible `.md`
        /// file directly in the folder.
        case note
        /// Directly in the folder, but not a Note (e.g. `.markdown`, hidden).
        case topLevel
        /// Somewhere below a subfolder: not a Note, as Notes are top-level files.
        case subfolder
        case elsewhere
    }

    public func placement(of file: URL) -> Placement {
        // Only the folders are resolved: a Note may itself be a symlink to a file elsewhere.
        let file = file.standardizedFileURL
        let folder = url.standardizedFileURL.resolvingSymlinksInPath().path
        let parent = file.deletingLastPathComponent().resolvingSymlinksInPath().path
        if parent == folder {
            let isNote = file.pathExtension.lowercased() == "md" && !file.lastPathComponent.hasPrefix(".")
            return isNote ? .note : .topLevel
        }
        return parent.hasPrefix(folder + "/") ? .subfolder : .elsewhere
    }

    public func isNote(_ file: URL) -> Bool {
        placement(of: file) == .note
    }

    /// The last `notes()`, by file.
    private var summaries: [URL: NoteSummary] = [:]

    /// Leaves the current Note and opens an existing one, returning its text.
    /// Its name is taken as matching its Title, so leaving it unchanged never
    /// renames it, whatever the file is called; changing the Title does.
    public func open(_ note: URL) throws -> String {
        if isOpen, let current = currentNoteURL, current.standardizedFileURL == note.standardizedFileURL {
            return latestText
        }
        // Read first: if the file is gone or unreadable, the current Note stays open.
        let text = try String(contentsOf: note, encoding: .utf8)
        try leave()
        isOpen = true
        latestText = text
        persistedText = text
        longestSavedText = text
        isInRecovery = false
        currentNoteURL = note
        let slug = Title.slug(Title.of(text) ?? "")
        currentSlug = slug
        currentPrefix = DatePrefix.of(fileName: note.lastPathComponent, titleSlug: slug) ?? ""
        return text
    }

    /// Leaves the current Note and shows `file`, a Markdown file that isn't a
    /// Note, read-only; returns its text. Read first: if it can't be read, the
    /// current Note stays open.
    public func openOutside(_ file: URL) throws -> String {
        if outsideFileURL?.standardizedFileURL == file.standardizedFileURL { return outsideText }
        let text: String
        do {
            text = try String(contentsOf: file, encoding: .utf8)
        } catch {
            throw OutsideFileError.unreadable(error)
        }
        try leave()
        outsideFileURL = file
        outsideText = text
        return text
    }

    /// The Outside File couldn't be read, as opposed to the open Note not saving.
    public enum OutsideFileError: LocalizedError {
        case unreadable(Error)

        public var errorDescription: String? {
            switch self { case .unreadable(let error): error.localizedDescription }
        }
    }

    /// What `reconcileOutsideFile()` found.
    public enum OutsideFileChange: Equatable {
        case unchanged
        /// Changed by another app: show this text instead.
        case reloaded(String)
        /// Deleted or moved away: it's forgotten.
        case deleted
    }

    /// Brings the shown Outside File in line with its file on disk. There are
    /// never local edits, so a change elsewhere always wins.
    public func reconcileOutsideFile() -> OutsideFileChange {
        guard let file = outsideFileURL else { return .unchanged }
        guard FileManager.default.fileExists(atPath: file.path) else {
            outsideFileURL = nil
            return .deleted
        }
        guard let text = try? String(contentsOf: file, encoding: .utf8), text != outsideText else { return .unchanged }
        outsideText = text
        return .reloaded(text)
    }

    /// Moves a Note to the Trash. If it's the open Note, it's closed without saving.
    public func trash(_ note: URL) throws {
        try moveToTrash(note)
        if let current = currentNoteURL, current.standardizedFileURL == note.standardizedFileURL {
            close()
        }
    }

    /// Forgets the open Note, without saving.
    private func close() {
        isOpen = false
        currentNoteURL = nil
        currentSlug = nil
        currentPrefix = ""
    }

    // MARK: External changes

    /// What `reconcileOpenNote()` did with the open Note.
    public enum OpenNoteChange: Equatable {
        /// Nothing to do: no change, MacJot's own write, or the open Note is a Draft.
        case unchanged
        /// Changed elsewhere with no local edits: show this text instead.
        case reloaded(String)
        /// Changed or deleted elsewhere, but the local edits win; the next flush
        /// writes them.
        case keptLocal
        /// Moved or renamed elsewhere; the Note now lives at this URL.
        case renamed(URL)
        /// Deleted elsewhere with no local edits: the Note is closed.
        case deleted
    }

    /// Brings the open Note in line with its file after something changed in the
    /// folder (the shell's file-system watcher calls this). MacJot's own writes match
    /// what it last wrote, so they never cause a reload.
    public func reconcileOpenNote() throws -> OpenNoteChange {
        guard isOpen, let file = currentNoteURL else { return .unchanged }
        let hasLocalEdits = latestText != persistedText

        guard FileManager.default.fileExists(atPath: file.path) else {
            if let moved = try sameFileElsewhere() {
                currentNoteURL = moved
                currentPrefix = DatePrefix.of(fileName: moved.lastPathComponent, titleSlug: currentSlug ?? "") ?? ""
                return .renamed(moved)
            }
            if hasLocalEdits { return .keptLocal }
            close()
            return .deleted
        }

        guard let text = try? String(contentsOf: file, encoding: .utf8), text != persistedText else {
            return .unchanged
        }
        persistedText = text  // what's on disk now, so a flush writes local edits over it
        rememberSaved(text)
        rememberFileIdentity()
        if hasLocalEdits { return latestText == text ? .unchanged : .keptLocal }
        latestText = text
        let slug = Title.slug(Title.of(text) ?? "")
        currentSlug = slug  // like opening it: its name is taken as matching its Title
        currentPrefix = DatePrefix.of(fileName: file.lastPathComponent, titleSlug: slug) ?? currentPrefix
        return .reloaded(text)
    }

    /// The open Note's file under another name: same device and inode. A copy
    /// with the same text is a different file, so it isn't mistaken for it.
    private func sameFileElsewhere() throws -> URL? {
        guard let identity = currentFileIdentity else { return nil }
        return try noteFiles().first { Self.identity(of: $0) == identity }
    }

    private func rememberFileIdentity() {
        currentFileIdentity = currentNoteURL.flatMap(Self.identity)
    }

    private static func identity(of file: URL) -> [Int]? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
              let device = attributes[.systemNumber] as? Int, let inode = attributes[.systemFileNumber] as? Int
        else { return nil }
        return [device, inode]
    }

    /// The visible `.md` files, spelled like the folder's own URL (a listing may
    /// resolve `/var` to `/private/var`).
    private func noteFiles() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(atPath: url.path)
            .filter { !$0.hasPrefix(".") && ($0 as NSString).pathExtension.lowercased() == "md" }
            .map { url.appendingPathComponent($0) }
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
            rememberSaved(text)
            rememberFileIdentity()
            return true
        }

        guard !Title.isBlank(text) else {
            // The Draft was cleared: nothing left worth recovering.
            try discardRecoveryCopy()
            return false
        }

        if materialising || Title.isFinished(text) {
            let slug = Title.slug(Title.of(text) ?? "")
            let prefix = newPrefix(createdAt: draftStarted)
            currentNoteURL = try create(Data(text.utf8), name: prefix + slug)
            currentSlug = slug
            currentPrefix = prefix
            persistedText = text
            rememberSaved(text)
            try discardRecoveryCopy()
            return true
        }

        guard !(isInRecovery && text == persistedText) else { return false }
        try Data(text.utf8).write(to: recoveryURL, options: .atomic)
        persistedText = text
        isInRecovery = true
        return true
    }

    private func rememberSaved(_ text: String) {
        if text.utf16.count > longestSavedText.utf16.count { longestSavedText = text }
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
            // Dated by the copy's last write, close to when the Draft was written, not by the relaunch.
            let written = (try? recoveryURL.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? clock()
            _ = try create(data, name: newPrefix(createdAt: written) + Title.slug(Title.of(text) ?? ""))
        }
        try removeRecoveryCopy()
    }

    private func hasNote(identicalTo data: Data) throws -> Bool {
        try noteFiles().contains { (try? Data(contentsOf: $0)) == data }
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
        currentNoteURL = try place(file, name: currentPrefix + slug)
        currentSlug = slug
        return true
    }

    /// Writes a new Note's file. The text goes to a hidden temporary file first
    /// and is then moved into place, so the Note appears complete or not at all.
    private func create(_ data: Data, name: String) throws -> URL {
        let temporary = url.appendingPathComponent(".jot-\(UUID().uuidString).tmp")
        try data.write(to: temporary)
        defer { try? FileManager.default.removeItem(at: temporary) }
        return try place(temporary, name: name)
    }

    /// The Date Prefix for a Note created now, if they're on.
    private func newPrefix(createdAt date: Date) -> String {
        usesDatePrefix ? DatePrefix.string(for: date) : ""
    }

    /// Moves `source` to the first free `<name>.md`, `<name>-2.md`, … `RENAME_EXCL`
    /// makes each attempt fail rather than replace a file that appeared in the meantime.
    private func place(_ source: URL, name: String) throws -> URL {
        var suffix = 1
        while true {
            let file = suffix == 1 ? "\(name).md" : "\(name)-\(suffix).md"
            let candidate = url.appendingPathComponent(file)
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
