import Foundation
import Testing
@testable import JotCore

/// Seam 1: the Notes Folder, exercised over a real temporary directory.
final class NotesFolderTests {
    let root: URL
    let support: URL
    var trashed: [String] = []
    /// The injected clock's time.
    var now = day(2026, 10, 8, hour: 12)
    var trashedContents: [String] = []

    init() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("JotCoreTests-\(UUID().uuidString)", isDirectory: true)
        root = base.appendingPathComponent("Notes", isDirectory: true)
        support = base.appendingPathComponent("Support", isDirectory: true)
    }

    deinit {
        let base = root.deletingLastPathComponent()
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
        try? FileManager.default.removeItem(at: base)
    }

    private var recoveryURL: URL { support.appendingPathComponent("recovery.md") }

    /// Records trashed filenames and removes the file, as the system Trash would.
    private func makeFolder(datePrefix: Bool = false) throws -> NotesFolder {
        try NotesFolder(url: root, recoveryURL: recoveryURL, clock: { [unowned self] in now },
                        datePrefix: datePrefix) { [unowned self] url in
            trashed.append(url.lastPathComponent)
            trashedContents.append(try String(contentsOf: url, encoding: .utf8))
            try FileManager.default.removeItem(at: url)
        }
    }

    private func files() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: root.path).sorted()
    }

    private func contents(_ name: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(name), encoding: .utf8)
    }

    private func recoveryContents() -> String? {
        try? String(contentsOf: recoveryURL, encoding: .utf8)
    }

    /// Writes `text` as a new Note and leaves it; returns the resulting filename.
    private func noteName(for text: String) throws -> String? {
        let folder = try makeFolder()
        try folder.startDraft()
        folder.update(text: text)
        try folder.leave()
        return try files().first
    }

    // MARK: Folder

    @Test func createsNotesFolderIfMissing() throws {
        _ = try makeFolder()
        var isDirectory: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory))
        #expect(isDirectory.boolValue)
    }

    // MARK: Draft lifecycle

    @Test func untouchedDraftCreatesNoFile() throws {
        let folder = try makeFolder()
        try folder.startDraft()
        try folder.flush()
        try folder.leave()
        #expect(try files().isEmpty)
        #expect(recoveryContents() == nil)
    }

    @Test func whitespaceOnlyDraftCreatesNoFile() throws {
        let folder = try makeFolder()
        try folder.startDraft()
        folder.update(text: "  \n\t\n ")
        try folder.flush()
        try folder.leave()
        #expect(try files().isEmpty)
    }

    @Test func draftOfOnlyLineBreaksCreatesNoFile() throws {
        let folder = try makeFolder()
        try folder.startDraft()
        folder.update(text: "  \r\n \u{2028} \r\n")
        try folder.leave()
        #expect(try files().isEmpty)
    }

    @Test func finishedTitleMaterialisesFileNamedAfterIt() throws {
        let folder = try makeFolder()
        try folder.startDraft()
        folder.update(text: "Hello World\nsecond line")
        try folder.flush()
        #expect(try files() == ["hello-world.md"])
        #expect(try contents("hello-world.md") == "Hello World\nsecond line")
        #expect(folder.currentNoteURL?.lastPathComponent == "hello-world.md")
    }

    @Test func isBlankDraftOnlyWhileTheDraftHasNoContent() throws {
        let folder = try makeFolder()
        #expect(!folder.isBlankDraft)  // nothing open yet
        try folder.startDraft()
        #expect(folder.isBlankDraft)
        folder.update(text: "  \n")
        #expect(folder.isBlankDraft)
        folder.update(text: "Something")
        #expect(!folder.isBlankDraft)  // has content, even before it's saved
        folder.update(text: "Something\n")
        try folder.flush()
        folder.update(text: "")
        #expect(!folder.isBlankDraft)  // a saved Note emptied is not a Draft
        try folder.leave()
        #expect(!folder.isBlankDraft)
    }

    // MARK: Title-finished creation and the Recovery Copy

    @Test func unfinishedTitleIsKeptInTheRecoveryCopyOnly() throws {
        let folder = try makeFolder()
        try folder.startDraft()
        folder.update(text: "Meeting wi")
        try folder.flush()
        #expect(try files().isEmpty)
        #expect(recoveryContents() == "Meeting wi")
        #expect(folder.currentNoteURL == nil)
    }

    @Test func pausingMidTitleCreatesOnlyTheFinishedName() throws {
        let folder = try makeFolder()
        try folder.startDraft()
        folder.update(text: "Meeting wi")
        try folder.flush()
        folder.update(text: "Meeting with Anna\n")
        try folder.flush()
        #expect(try files() == ["meeting-with-anna.md"])
    }

    @Test func materialisingDeletesTheRecoveryCopy() throws {
        let folder = try makeFolder()
        try folder.startDraft()
        folder.update(text: "Idea")
        try folder.flush()
        #expect(recoveryContents() == "Idea")
        folder.update(text: "Idea\n")
        try folder.flush()
        #expect(recoveryContents() == nil)
    }

    @Test func singleLineDraftIsMaterialisedOnLeave() throws {
        let folder = try makeFolder()
        try folder.startDraft()
        folder.update(text: "Idea")
        try folder.flush()
        try folder.leave()
        #expect(try contents("idea.md") == "Idea")
        #expect(recoveryContents() == nil)
        #expect(folder.currentNoteURL == nil)
    }

    @Test func startingANewDraftMaterialisesThePreviousOne() throws {
        let folder = try makeFolder()
        try folder.startDraft()
        folder.update(text: "First")
        try folder.startDraft()
        #expect(try files() == ["first.md"])
        #expect(folder.currentNoteURL == nil)
    }

    @Test func clearingAnUnfinishedDraftRemovesTheRecoveryCopy() throws {
        let folder = try makeFolder()
        try folder.startDraft()
        folder.update(text: "Oops")
        try folder.flush()
        folder.update(text: "")
        try folder.flush()
        #expect(recoveryContents() == nil)
        try folder.leave()
        #expect(try files().isEmpty)
    }

    @Test func recoveryCopyFromACrashBecomesANote() throws {
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try "Lost thought\nmore".write(to: recoveryURL, atomically: true, encoding: .utf8)
        _ = try makeFolder()
        #expect(try files() == ["lost-thought.md"])
        #expect(try contents("lost-thought.md") == "Lost thought\nmore")
        #expect(recoveryContents() == nil)
    }

    @Test func recoveryCopyMatchingAnExistingNoteIsNotDuplicated() throws {
        // Crash after the Note's file was created but before the copy was removed.
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try "Idea\nbody".write(to: root.appendingPathComponent("idea.md"), atomically: true, encoding: .utf8)
        try "Idea\nbody".write(to: recoveryURL, atomically: true, encoding: .utf8)
        _ = try makeFolder()
        #expect(try files() == ["idea.md"])
        #expect(recoveryContents() == nil)
    }

    @Test func unreadableRecoveryCopyIsReportedNotOverwritten() throws {
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try "Precious".write(to: recoveryURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: recoveryURL.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: recoveryURL.path) }
        #expect(throws: (any Error).self) { _ = try self.makeFolder() }
    }

    @Test func blankRecoveryCopyIsDiscarded() throws {
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try " \n".write(to: recoveryURL, atomically: true, encoding: .utf8)
        _ = try makeFolder()
        #expect(try files().isEmpty)
        #expect(recoveryContents() == nil)
    }

    // MARK: Filenames

    @Test func accentsAreTransliteratedAndHeadingMarkersIgnored() throws {
        #expect(try noteName(for: "# Über Änderungen!\nbody") == "uber-anderungen.md")
    }

    @Test func sharpSIsSpelledOut() throws {
        #expect(try noteName(for: "Straße") == "strasse.md")
    }

    @Test func taskMarkerIsIgnored() throws {
        #expect(try noteName(for: "- [ ] Call Anna") == "call-anna.md")
        try FileManager.default.removeItem(at: root)
        #expect(try noteName(for: "- [x] Call Ben") == "call-ben.md")
    }

    @Test func listAndQuoteMarkersAreIgnored() throws {
        #expect(try noteName(for: "> 1. **Plan** for Q4") == "plan-for-q4.md")
    }

    @Test func titleWithoutUsableCharactersIsUntitled() throws {
        #expect(try noteName(for: "🎉🎉") == "untitled.md")
        try FileManager.default.removeItem(at: root)
        #expect(try noteName(for: "日本語のメモ") == "untitled.md")
    }

    @Test func titleIsFirstNonBlankLine() throws {
        #expect(try noteName(for: "\n   \nShopping List\nmilk") == "shopping-list.md")
    }

    @Test func windowsLineEndingsSeparateTheTitle() throws {
        #expect(try noteName(for: "\r\nHello\r\nWorld\r\n") == "hello.md")
    }

    @Test func longTitlesAreCutAtAWordBoundary() throws {
        let name = try #require(try noteName(for: String(repeating: "lorem ipsum ", count: 30)))
        let stem = String(name.dropLast(3))
        #expect(stem.count <= 60)
        #expect(stem.hasPrefix("lorem-ipsum-lorem"))
        #expect(!stem.hasSuffix("-"))
        #expect(stem.hasSuffix("lorem") || stem.hasSuffix("ipsum"))
    }

    @Test func notesWithTheSameTitleNeverOverwriteEachOther() throws {
        let folder = try makeFolder()
        try folder.startDraft()
        folder.update(text: "Meeting\nA")
        try folder.leave()
        try folder.startDraft()
        folder.update(text: "Meeting\nB")
        try folder.leave()
        #expect(try files() == ["meeting-2.md", "meeting.md"])
        #expect(try contents("meeting.md") == "Meeting\nA")
        #expect(try contents("meeting-2.md") == "Meeting\nB")
    }

    @Test func frontmatterOnlyNoteIsContentNotBlank() throws {
        let folder = try makeFolder()
        try folder.startDraft()
        folder.update(text: "---\ntags: [work]\n---\n")
        #expect(!folder.isBlankDraft)
        try folder.leave()
        #expect(try files() == ["untitled.md"])
    }

    @Test func unclosedFenceEndedByABlankLineIsARule() throws {
        #expect(try noteName(for: "---\n\nAfter a rule\nbody") == "after-a-rule.md")
    }

    @Test func openingFrontmatterFenceIsNotAFinishedTitle() throws {
        let folder = try makeFolder()
        try folder.startDraft()
        folder.update(text: "---\n")
        try folder.flush()
        folder.update(text: "---\ntags: [work]\n")
        try folder.flush()
        #expect(try files().isEmpty)
        folder.update(text: "---\ntags: [work]\n---\nReal Title\n")
        try folder.flush()
        #expect(try files() == ["real-title.md"])
    }

    @Test func frontmatterIsKeptAndSkippedForTheTitle() throws {
        let text = "---\ntags: [work]\n---\n\nReal Title\nbody"
        #expect(try noteName(for: text) == "real-title.md")
        #expect(try contents("real-title.md") == text)
    }

    // MARK: Rename on leave

    @Test func retitlingRenamesOnLeaveNotWhileTyping() throws {
        let folder = try makeFolder()
        try folder.startDraft()
        folder.update(text: "Draft plan\nbody")
        try folder.flush()
        folder.update(text: "Final plan\nbody")
        try folder.flush()
        #expect(try files() == ["draft-plan.md"])
        #expect(try contents("draft-plan.md") == "Final plan\nbody")
        try folder.leave()
        #expect(try files() == ["final-plan.md"])
        #expect(try contents("final-plan.md") == "Final plan\nbody")
    }

    @Test func renameAvoidsExistingNames() throws {
        let folder = try makeFolder()
        try folder.startDraft()
        folder.update(text: "Meeting\nA")
        try folder.leave()
        try folder.startDraft()
        folder.update(text: "Other\nB")
        try folder.flush()
        folder.update(text: "Meeting\nB")
        try folder.leave()
        #expect(try files() == ["meeting-2.md", "meeting.md"])
        #expect(try contents("meeting-2.md") == "Meeting\nB")
    }

    @Test func suffixedNameIsKeptWhenTheTitleIsUnchanged() throws {
        let folder = try makeFolder()
        try folder.startDraft()
        folder.update(text: "Meeting\nA")
        try folder.leave()
        try folder.startDraft()
        folder.update(text: "Meeting\nB")
        try folder.flush()
        folder.update(text: "Meeting\nB edited")
        try folder.leave()
        #expect(try files() == ["meeting-2.md", "meeting.md"])
    }

    @Test func retitlingToAPrefixOfTheOldNameRenames() throws {
        let folder = try makeFolder()
        try folder.startDraft()
        folder.update(text: "Plan 1\nbody")
        try folder.flush()
        folder.update(text: "Plan\nbody")
        try folder.leave()
        #expect(try files() == ["plan.md"])
    }

    @Test func emptiedNoteGoesToTheTrashWithItsLastContent() throws {
        let folder = try makeFolder()
        try folder.startDraft()
        folder.update(text: "Long note\nwith content")
        try folder.flush()
        folder.update(text: "")
        try folder.flush()  // autosave of the emptied text
        try folder.leave()
        #expect(trashed == ["long-note.md"])
        #expect(trashedContents == ["Long note\nwith content"])
    }

    @Test func emptiedNoteWhoseFileIsGoneCanStillBeLeft() throws {
        let folder = try makeFolder()
        try folder.startDraft()
        folder.update(text: "Gone\nsoon")
        try folder.flush()
        folder.update(text: "")
        try folder.flush()
        try FileManager.default.removeItem(at: root.appendingPathComponent("gone.md"))
        try folder.leave()
        try folder.startDraft()
        #expect(trashed.isEmpty)
    }

    @Test func emptiedNoteIsTrashedOnLeave() throws {
        let folder = try makeFolder()
        try folder.startDraft()
        folder.update(text: "Temporary\nthing")
        try folder.flush()
        folder.update(text: " \n")
        try folder.flush()
        try folder.leave()
        #expect(trashed == ["temporary.md"])
        #expect(try files().isEmpty)
    }

    // MARK: Note List

    /// Writes a Note file directly, as another tool would, with a given modification date.
    @discardableResult
    private func writeNote(_ name: String, _ text: String, modified: Date = Date()) throws -> URL {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent(name)
        try text.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
        return url
    }

    @Test func notesAreListedNewestFirst() throws {
        try writeNote("old.md", "Old", modified: Date(timeIntervalSinceNow: -3600))
        try writeNote("new.md", "New", modified: Date())
        try writeNote("mid.md", "Mid", modified: Date(timeIntervalSinceNow: -60))
        let folder = try makeFolder()
        #expect(try folder.notes().map(\.title) == ["New", "Mid", "Old"])
    }

    @Test func summaryShowsTitleWithoutMarkdownAndTheNextLine() throws {
        try writeNote("a.md", "\n# Über **Änderungen**\n\n- [ ] milk and *eggs*\nmore")
        let note = try #require(try makeFolder().notes().first)
        #expect(note.title == "Über Änderungen")
        #expect(note.preview == "milk and eggs")
        #expect(note.url.lastPathComponent == "a.md")
    }

    @Test func noteWithoutTitleIsListedAsUntitled() throws {
        try writeNote("fm.md", "---\ntags: [x]\n---\n")
        let note = try #require(try makeFolder().notes().first)
        #expect(note.title == "Untitled")
        #expect(note.preview == "")
    }

    @Test func onlyVisibleMarkdownFilesAreListed() throws {
        try writeNote("note.md", "Note")
        try writeNote(".hidden.md", "Hidden")
        try writeNote(".jot-1234.tmp", "Temp")
        try writeNote("other.txt", "Text")
        #expect(try makeFolder().notes().map(\.title) == ["Note"])
    }

    @Test func isDraftWhileTheOpenNoteHasNoFileYet() throws {
        let folder = try makeFolder()
        #expect(!folder.isDraft)
        try folder.startDraft()
        #expect(folder.isDraft)
        folder.update(text: "Idea")
        try folder.flush()
        #expect(folder.isDraft)       // only in the Recovery Copy so far
        folder.update(text: "Idea\n")
        try folder.flush()
        #expect(!folder.isDraft)      // has its file now
    }

    @Test func displayTitleOfDraftText() {
        #expect(NoteSummary.displayTitle(of: "# **Plan** for Q4\nbody") == "Plan for Q4")
        #expect(NoteSummary.displayTitle(of: "  \n") == nil)
    }

    // MARK: Opening existing Notes

    @Test func openingAnExistingNoteReturnsItsTextAndSavesToIt() throws {
        let url = try writeNote("plan.md", "Plan\nold")
        let folder = try makeFolder()
        #expect(try folder.open(url) == "Plan\nold")
        #expect(folder.currentNoteURL == url)
        #expect(!folder.isBlankDraft)
        folder.update(text: "Plan\nnew")
        try folder.leave()
        #expect(try contents("plan.md") == "Plan\nnew")
    }

    @Test func openingAndLeavingUnchangedNeverRenames() throws {
        let url = try writeNote("My Note From Elsewhere.md", "Shopping\nmilk")
        let suffixed = try writeNote("meeting-2.md", "Meeting\nB")
        let folder = try makeFolder()
        _ = try folder.open(url)
        _ = try folder.open(suffixed)
        try folder.leave()
        #expect(try files() == ["My Note From Elsewhere.md", "meeting-2.md"])
    }

    @Test func retitlingAnOpenedNoteRenamesItOnLeave() throws {
        let url = try writeNote("My Note From Elsewhere.md", "Shopping\nmilk")
        let folder = try makeFolder()
        _ = try folder.open(url)
        folder.update(text: "Groceries\nmilk")
        try folder.leave()
        #expect(try files() == ["groceries.md"])
    }

    @Test func openingAnotherNoteLeavesTheCurrentDraft() throws {
        let url = try writeNote("other.md", "Other")
        let folder = try makeFolder()
        try folder.startDraft()
        folder.update(text: "Unfinished thought")
        _ = try folder.open(url)
        #expect(try files() == ["other.md", "unfinished-thought.md"])
        #expect(folder.currentNoteURL == url)
    }

    @Test func openingTheOpenNoteKeepsItsUnsavedText() throws {
        let url = try writeNote("plan.md", "Plan")
        let folder = try makeFolder()
        _ = try folder.open(url)
        folder.update(text: "Plan\nunsaved")
        #expect(try folder.open(url) == "Plan\nunsaved")
    }

    @Test func openingAMissingNoteKeepsTheCurrentOneOpen() throws {
        let current = try writeNote("current.md", "Current")
        let folder = try makeFolder()
        _ = try folder.open(current)
        folder.update(text: "Current\nedited")
        #expect(throws: (any Error).self) { _ = try folder.open(self.root.appendingPathComponent("gone.md")) }
        #expect(folder.currentNoteURL == current)
        folder.update(text: "Current\nedited more")
        try folder.leave()
        #expect(try contents("current.md") == "Current\nedited more")
    }

    @Test func openingAnEmptyFileAndLeavingItKeepsIt() throws {
        let url = try writeNote("todo.md", "")
        let folder = try makeFolder()
        _ = try folder.open(url)
        try folder.leave()
        #expect(trashed.isEmpty)
        #expect(try files() == ["todo.md"])
    }

    @Test func leftNoteURLFollowsRenamesAndNewFiles() throws {
        let url = try writeNote("plan.md", "Plan")
        let folder = try makeFolder()
        _ = try folder.open(url)
        folder.update(text: "Roadmap")
        try folder.startDraft()
        #expect(folder.lastLeftNoteURL?.lastPathComponent == "roadmap.md")
        folder.update(text: "Single line idea")
        try folder.leave()
        #expect(folder.lastLeftNoteURL?.lastPathComponent == "single-line-idea.md")
        try folder.startDraft()
        try folder.leave()
        #expect(folder.lastLeftNoteURL == nil)  // a blank Draft leaves no Note behind
    }

    // MARK: Search

    private func search(_ query: String) throws -> [NoteSummary] {
        try makeFolder().notes().compactMap { $0.matching(query) }
    }

    @Test func searchIgnoresCaseAndDiacritics() throws {
        try writeNote("uber.md", "# Über den Plan\n\nText")
        try writeNote("meeting.md", "meeting notes\n\nAgenda")
        try writeNote("other.md", "Shopping\n\nmilk")
        #expect(try search("uber").map(\.title) == ["Über den Plan"])
        #expect(try search("MEETING").map(\.title) == ["meeting notes"])
        #expect(try search("ÜBER").map(\.title) == ["Über den Plan"])
    }

    @Test func emptyQueryListsEveryNoteUnchanged() throws {
        try writeNote("a.md", "Alpha\n\nfirst")
        try writeNote("b.md", "Beta\n\nsecond")
        let notes = try makeFolder().notes()
        #expect(notes.compactMap { $0.matching("  ") } == notes)
    }

    @Test func bodyMatchShowsTheMatchingLineAsPreview() throws {
        try writeNote("trip.md", "Trip\n\nFlights booked\nPack the *passport* and charger")
        let note = try #require(try search("passport").first)
        #expect(note.title == "Trip")
        #expect(note.preview == "Pack the passport and charger")
    }

    @Test func titleOnlyMatchKeepsTheUsualPreview() throws {
        try writeNote("trip.md", "Trip to Vienna\n\nFlights booked")
        #expect(try search("vienna").map(\.preview) == ["Flights booked"])
    }

    @Test func bodyMatchIsPreferredOverTitleMatchForThePreview() throws {
        try writeNote("plan.md", "Plan\n\nFirst line\nThe plan is simple")
        #expect(try search("plan").map(\.preview) == ["The plan is simple"])
    }

    @Test func notesWithoutTheQueryAreLeftOut() throws {
        try writeNote("a.md", "Alpha\n\nfirst")
        #expect(try search("gamma").isEmpty)
    }

    @Test func markdownIsIgnoredWhenMatching() throws {
        try writeNote("a.md", "Notes\n\n- [ ] call **Über** plan")
        #expect(try search("uber plan").map(\.preview) == ["call Über plan"])
        #expect(try search("[ ]").isEmpty)
    }

    @Test func frontmatterIsNotSearched() throws {
        try writeNote("a.md", "---\ntags: [secret]\n---\nTitle\n\nBody")
        #expect(try search("secret").isEmpty)
    }

    @Test func snippetOfALongLineStartsNearTheMatch() throws {
        try writeNote("a.md", "Zoo\n\nThis is a long introduction sentence before the word Zebra and after.")
        #expect(try search("zebra").map(\.preview) == ["…before the word Zebra and after."])
    }

    @Test func draftTextIsMatchedLikeANote() {
        #expect(NoteSummary.matches("idee", text: "Neue Idée\n\nmore"))
        #expect(NoteSummary.matches("more", text: "Neue Idée\n\nmore"))
        #expect(!NoteSummary.matches("plan", text: "Neue Idée\n\nmore"))
        #expect(NoteSummary.matches("", text: ""))
    }

    @Test func untitledPlaceholderIsNotSearched() throws {
        try writeNote("fm.md", "---\ntags: [x]\n---\n")
        #expect(try search("untitled").isEmpty)
        #expect(!NoteSummary.matches("unt", text: ""))
        #expect(!NoteSummary.matches("unt", text: "  \n"))
    }

    @Test func editedNoteIsSearchedWithItsNewText() throws {
        let folder = try makeFolder()
        try writeNote("a.md", "Alpha\n\nold words", modified: Date(timeIntervalSince1970: 1_000))
        #expect(try folder.notes().compactMap { $0.matching("new") }.isEmpty)
        try writeNote("a.md", "Alpha\n\nnew words", modified: Date(timeIntervalSince1970: 2_000))
        #expect(try folder.notes().compactMap { $0.matching("new") }.map(\.preview) == ["new words"])
    }

    // MARK: Trashing from the Note List

    @Test func trashingTheOpenNoteClosesItWithoutSaving() throws {
        let url = try writeNote("plan.md", "Plan")
        let folder = try makeFolder()
        _ = try folder.open(url)
        folder.update(text: "Plan\nedited")
        try folder.trash(url)
        #expect(trashed == ["plan.md"])
        #expect(trashedContents == ["Plan"])
        #expect(folder.currentNoteURL == nil)
        try folder.leave()
        #expect(try files().isEmpty)
    }

    @Test func trashingAnotherNoteKeepsTheOpenOne() throws {
        let open = try writeNote("open.md", "Open")
        let other = try writeNote("other.md", "Other")
        let folder = try makeFolder()
        _ = try folder.open(open)
        try folder.trash(other)
        #expect(trashed == ["other.md"])
        #expect(folder.currentNoteURL == open)
    }

    // MARK: Saving

    @Test func flushReportsWhetherItWrote() throws {
        let folder = try makeFolder()
        try folder.startDraft()
        #expect(try folder.flush() == false)
        folder.update(text: "Written")
        #expect(try folder.flush() == true)
        #expect(try folder.flush() == false)
    }

    @Test func flushPersistsLatestTextToTheSameFile() throws {
        let folder = try makeFolder()
        try folder.startDraft()
        folder.update(text: "Plan\n")
        try folder.flush()
        folder.update(text: "Plan\n- step one")
        try folder.flush()
        #expect(try files() == ["plan.md"])
        #expect(try contents("plan.md") == "Plan\n- step one")
    }

    @Test func savingLeavesNoTemporaryFilesBehind() throws {
        let folder = try makeFolder()
        try folder.startDraft()
        folder.update(text: "Clean\n")
        try folder.flush()
        folder.update(text: "Clean\nmore")
        try folder.leave()
        #expect(try files() == ["clean.md"])
    }

    @Test func failedSaveKeepsTheNoteOpenWithItsText() throws {
        let folder = try makeFolder()
        try folder.startDraft()
        folder.update(text: "Keep me")
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: root.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path) }

        #expect(throws: (any Error).self) { try folder.leave() }

        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
        try folder.leave()
        #expect(try contents("keep-me.md") == "Keep me")
    }

    // MARK: Date Prefix

    /// A Note written in a Draft started at `now` and left.
    private func writeDraft(_ folder: NotesFolder, _ text: String) throws {
        try folder.startDraft()
        folder.update(text: text)
        try folder.leave()
    }

    /// Opens `name`, replaces its text and leaves it.
    private func edit(_ folder: NotesFolder, _ name: String, to text: String) throws {
        _ = try folder.open(root.appendingPathComponent(name))
        folder.update(text: text)
        try folder.leave()
    }

    @Test func datePrefixIsOffByDefault() throws {
        try writeDraft(try makeFolder(), "Plan")
        #expect(try files() == ["plan.md"])
    }

    @Test func datePrefixNamesANewNoteAfterItsCreationDay() throws {
        try writeDraft(try makeFolder(datePrefix: true), "Plan")
        #expect(try files() == ["2026-10-08-plan.md"])
    }

    @Test func datePrefixIsTheDayTheDraftWasStarted() throws {
        let folder = try makeFolder(datePrefix: true)
        now = day(2026, 10, 8, hour: 23, minute: 59)
        try folder.startDraft()
        folder.update(text: "Late idea")
        now = day(2026, 10, 9, hour: 0, minute: 1)
        try folder.leave()
        #expect(try files() == ["2026-10-08-late-idea.md"])
    }

    @Test func retitlingKeepsTheDatePrefix() throws {
        let folder = try makeFolder(datePrefix: true)
        try writeDraft(folder, "Plan")
        now = day(2026, 12, 24)
        try edit(folder, "2026-10-08-plan.md", to: "New plan")
        #expect(try files() == ["2026-10-08-new-plan.md"])
    }

    @Test func prefixedNotesWithTheSameTitleGetSuffixes() throws {
        let folder = try makeFolder(datePrefix: true)
        try writeDraft(folder, "Plan")
        try writeDraft(folder, "Plan")
        #expect(try files() == ["2026-10-08-plan-2.md", "2026-10-08-plan.md"])
        try edit(folder, "2026-10-08-plan-2.md", to: "Other")
        #expect(try files() == ["2026-10-08-other.md", "2026-10-08-plan.md"])
    }

    @Test func switchingThePrefixOnLeavesExistingNotesAlone() throws {
        let folder = try makeFolder()
        try writeDraft(folder, "Plan")
        folder.usesDatePrefix = true
        try edit(folder, "plan.md", to: "Plan\nmore")
        #expect(try files() == ["plan.md"])
        try edit(folder, "plan.md", to: "Renamed")
        #expect(try files() == ["renamed.md"])
        try writeDraft(folder, "Fresh")
        #expect(try files() == ["2026-10-08-fresh.md", "renamed.md"])
    }

    @Test func switchingThePrefixOffKeepsExistingPrefixes() throws {
        let folder = try makeFolder(datePrefix: true)
        try writeDraft(folder, "Plan")
        folder.usesDatePrefix = false
        try edit(folder, "2026-10-08-plan.md", to: "Renamed")
        try writeDraft(folder, "Fresh")
        #expect(try files() == ["2026-10-08-renamed.md", "fresh.md"])
    }

    @Test func aDateInTheTitleIsNotMistakenForAPrefix() throws {
        let folder = try makeFolder()
        try writeDraft(folder, "2026-10-08 meeting")
        #expect(try files() == ["2026-10-08-meeting.md"])
        try edit(folder, "2026-10-08-meeting.md", to: "Standup")
        #expect(try files() == ["standup.md"])
    }

    @Test func prefixedNoteWhoseTitleStartsWithADateKeepsBoth() throws {
        let folder = try makeFolder(datePrefix: true)
        try writeDraft(folder, "2026-01-01 review")
        #expect(try files() == ["2026-10-08-2026-01-01-review.md"])
        try edit(folder, "2026-10-08-2026-01-01-review.md", to: "Review")
        #expect(try files() == ["2026-10-08-review.md"])
    }

    @Test func recoveryCopyRestoredWithThePrefixOnGetsTodaysDate() throws {
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try "Crashed idea".write(to: recoveryURL, atomically: true, encoding: .utf8)
        _ = try makeFolder(datePrefix: true)
        #expect(try files() == ["2026-10-08-crashed-idea.md"])
    }

    @Test func recoveryCopyIsDatedByItsFileNotTheRelaunch() throws {
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try "Late idea".write(to: recoveryURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.creationDate: day(2026, 10, 8, hour: 23, minute: 50)],
                                              ofItemAtPath: recoveryURL.path)
        now = day(2026, 10, 9, hour: 8)
        _ = try makeFolder(datePrefix: true)
        #expect(try files() == ["2026-10-08-late-idea.md"])
    }

    /// A date someone put in front of a filename is never dropped, even when the
    /// name no longer follows the Title (renamed in Finder, or a crash before rename).
    @Test func leadingDateOfANameThatDriftedFromTheTitleIsKept() throws {
        try writeNote("2026-10-08-notes.md", "Plan")
        try edit(try makeFolder(), "2026-10-08-notes.md", to: "Budget")
        #expect(try files() == ["2026-10-08-budget.md"])
    }

    @Test func createdDateComesFromTheDatePrefix() throws {
        try writeNote("2026-10-08-plan.md", "Plan")
        let note = try #require(try makeFolder().notes().first)
        #expect(note.created == day(2026, 10, 8, hour: 0))
    }

    @Test func createdDateWithoutPrefixIsTheFilesCreationDate() throws {
        let url = try writeNote("plan.md", "Plan")
        let created = day(2025, 3, 1, hour: 9)
        try FileManager.default.setAttributes([.creationDate: created], ofItemAtPath: url.path)
        #expect(try makeFolder().notes().first?.created == created)
    }

    @Test func dateInTheTitleIsNotACreatedDate() throws {
        let url = try writeNote("2026-10-08-meeting.md", "2026-10-08 meeting")
        let created = day(2025, 3, 1, hour: 9)
        try FileManager.default.setAttributes([.creationDate: created], ofItemAtPath: url.path)
        #expect(try makeFolder().notes().first?.created == created)
    }
}

/// A local time on a given day, as the clock would report it.
private func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0) -> Date {
    Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}
