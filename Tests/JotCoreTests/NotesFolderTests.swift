import Foundation
import Testing
@testable import JotCore

/// Seam 1: the Notes Folder, exercised over a real temporary directory.
final class NotesFolderTests {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("JotCoreTests-\(UUID().uuidString)", isDirectory: true)
    }

    deinit {
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
        try? FileManager.default.removeItem(at: root)
    }

    private func files() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: root.path).sorted()
    }

    private func contents(_ name: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(name), encoding: .utf8)
    }

    // MARK: Folder

    @Test func createsNotesFolderIfMissing() throws {
        _ = try NotesFolder(url: root)
        var isDirectory: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory))
        #expect(isDirectory.boolValue)
    }

    // MARK: Draft lifecycle

    @Test func untouchedDraftCreatesNoFile() throws {
        let folder = try NotesFolder(url: root)
        try folder.startDraft()
        try folder.flush()
        try folder.leave()
        #expect(try files().isEmpty)
    }

    @Test func whitespaceOnlyDraftCreatesNoFile() throws {
        let folder = try NotesFolder(url: root)
        try folder.startDraft()
        folder.update(text: "  \n\t\n ")
        try folder.flush()
        try folder.leave()
        #expect(try files().isEmpty)
    }

    @Test func firstContentMaterialisesFileNamedAfterTitle() throws {
        let folder = try NotesFolder(url: root)
        try folder.startDraft()
        folder.update(text: "Hello World\nsecond line")
        try folder.flush()
        #expect(try files() == ["hello-world.md"])
        #expect(try contents("hello-world.md") == "Hello World\nsecond line")
        #expect(folder.currentNoteURL?.lastPathComponent == "hello-world.md")
    }

    @Test func titleIsFirstNonBlankLine() throws {
        let folder = try NotesFolder(url: root)
        try folder.startDraft()
        folder.update(text: "\n   \nShopping List\nmilk")
        try folder.flush()
        #expect(try files() == ["shopping-list.md"])
    }

    @Test func titleWithoutUsableCharactersIsUntitled() throws {
        let folder = try NotesFolder(url: root)
        try folder.startDraft()
        folder.update(text: "///")
        try folder.flush()
        #expect(try files() == ["untitled.md"])
    }

    @Test func windowsLineEndingsSeparateTheTitle() throws {
        let folder = try NotesFolder(url: root)
        try folder.startDraft()
        folder.update(text: "\r\nHello\r\nWorld\r\n")
        try folder.flush()
        #expect(try files() == ["hello.md"])
    }

    @Test func draftOfOnlyLineBreaksCreatesNoFile() throws {
        let folder = try NotesFolder(url: root)
        try folder.startDraft()
        folder.update(text: "  \r\n \u{2028} \r\n")
        try folder.leave()
        #expect(try files().isEmpty)
    }

    @Test func longTitlesAreCutAtAWordBoundary() throws {
        let folder = try NotesFolder(url: root)
        try folder.startDraft()
        folder.update(text: String(repeating: "lorem ipsum ", count: 30))
        try folder.flush()
        let name = try #require(try files().first)
        let stem = String(name.dropLast(3))
        #expect(stem.count <= 60)
        #expect(stem.hasPrefix("lorem-ipsum-lorem"))
        #expect(!stem.hasSuffix("-"))
        #expect(stem.hasSuffix("lorem") || stem.hasSuffix("ipsum"))
    }

    @Test func savingLeavesNoTemporaryFilesBehind() throws {
        let folder = try NotesFolder(url: root)
        try folder.startDraft()
        folder.update(text: "Clean")
        try folder.flush()
        folder.update(text: "Clean\nmore")
        try folder.leave()
        #expect(try files() == ["clean.md"])
    }

    // MARK: Saving

    @Test func flushReportsWhetherItWrote() throws {
        let folder = try NotesFolder(url: root)
        try folder.startDraft()
        #expect(try folder.flush() == false)
        folder.update(text: "Written")
        #expect(try folder.flush() == true)
        #expect(try folder.flush() == false)
    }

    @Test func flushPersistsLatestTextToTheSameFile() throws {
        let folder = try NotesFolder(url: root)
        try folder.startDraft()
        folder.update(text: "Plan")
        try folder.flush()
        folder.update(text: "Plan\n- step one")
        try folder.flush()
        #expect(try files() == ["plan.md"])
        #expect(try contents("plan.md") == "Plan\n- step one")
    }

    @Test func leavePersistsUnflushedText() throws {
        let folder = try NotesFolder(url: root)
        try folder.startDraft()
        folder.update(text: "Idea")
        try folder.leave()
        #expect(try contents("idea.md") == "Idea")
        #expect(folder.currentNoteURL == nil)
    }

    @Test func startingANewDraftSavesThePreviousNote() throws {
        let folder = try NotesFolder(url: root)
        try folder.startDraft()
        folder.update(text: "First")
        try folder.startDraft()
        try folder.flush()
        #expect(try files() == ["first.md"])
        #expect(folder.currentNoteURL == nil)
    }

    @Test func notesWithTheSameTitleNeverOverwriteEachOther() throws {
        let folder = try NotesFolder(url: root)
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

    @Test func failedSaveKeepsTheNoteOpenWithItsText() throws {
        let folder = try NotesFolder(url: root)
        try folder.startDraft()
        folder.update(text: "Keep me")
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: root.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path) }

        #expect(throws: (any Error).self) { try folder.leave() }

        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
        try folder.flush()
        #expect(try contents("keep-me.md") == "Keep me")
    }
}
