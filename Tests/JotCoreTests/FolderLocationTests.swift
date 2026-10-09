import Foundation
import Testing
@testable import JotCore

/// Finding the Notes Folder after it disappeared from its path, over a real temporary directory.
final class FolderLocationTests {
    let base: URL
    let folder: URL

    init() throws {
        base = FileManager.default.temporaryDirectory
            .appendingPathComponent("FolderLocationTests-\(UUID().uuidString)", isDirectory: true)
        folder = base.appendingPathComponent("Notes", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: base)
    }

    private func move(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: folder, to: url)
    }

    /// Where a `.moved` status points; URLs to the same folder can differ in spelling.
    private func movedPath(_ status: FolderLocation.Status) -> String? {
        guard case .moved(let url) = status else { return nil }
        return url.resolvingSymlinksInPath().path
    }

    @Test func folderAtItsPathIsInPlace() {
        #expect(FolderLocation.status(of: folder, bookmark: FolderLocation.bookmark(for: folder)) == .inPlace)
    }

    @Test func renamedFolderIsFound() throws {
        let bookmark = FolderLocation.bookmark(for: folder)
        let renamed = base.appendingPathComponent("Renamed", isDirectory: true)
        try move(to: renamed)
        #expect(movedPath(FolderLocation.status(of: folder, bookmark: bookmark)) == renamed.resolvingSymlinksInPath().path)
    }

    @Test func folderMovedElsewhereIsFound() throws {
        let bookmark = FolderLocation.bookmark(for: folder)
        let moved = base.appendingPathComponent("Archive/Notes", isDirectory: true)
        try move(to: moved)
        #expect(movedPath(FolderLocation.status(of: folder, bookmark: bookmark)) == moved.resolvingSymlinksInPath().path)
    }

    @Test func folderInTheTrashIsNotFollowed() throws {
        let bookmark = FolderLocation.bookmark(for: folder)
        try move(to: base.appendingPathComponent(".Trash/Notes", isDirectory: true))
        #expect(FolderLocation.status(of: folder, bookmark: bookmark) == .trashed)
    }

    @Test func deletedFolderIsGone() throws {
        let bookmark = FolderLocation.bookmark(for: folder)
        try FileManager.default.removeItem(at: folder)
        #expect(FolderLocation.status(of: folder, bookmark: bookmark) == .gone)
    }

    @Test func missingFolderWithoutABookmarkIsMissing() throws {
        try FileManager.default.removeItem(at: folder)
        #expect(FolderLocation.status(of: folder, bookmark: nil) == .missing)
    }

    @Test func aFolderRecreatedAtThePathIsInPlace() throws {
        let bookmark = FolderLocation.bookmark(for: folder)
        try move(to: base.appendingPathComponent("Renamed", isDirectory: true))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        #expect(FolderLocation.status(of: folder, bookmark: bookmark) == .inPlace)
    }
}
