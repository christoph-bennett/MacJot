import Foundation
import Testing
@testable import JotCore

/// The file's lines, as the gutter numbers them: wrapping doesn't matter here,
/// every line break starts a line, blank lines included.
struct LineNumbersTests {
    @Test func emptyTextHasOneLine() {
        let lines = LineNumbers("")
        #expect(lines.count == 1)
        #expect(lines.number(ofLineStartingAt: 0) == 1)
    }

    @Test func linesStartAfterEachBreak() {
        let lines = LineNumbers("one\ntwo\nthree")
        #expect(lines.count == 3)
        #expect(lines.number(ofLineStartingAt: 0) == 1)
        #expect(lines.number(ofLineStartingAt: 4) == 2)
        #expect(lines.number(ofLineStartingAt: 8) == 3)
    }

    @Test func positionsInsideALineStartNoLine() {
        let lines = LineNumbers("one\ntwo")
        #expect(lines.number(ofLineStartingAt: 1) == nil)
        #expect(lines.number(ofLineStartingAt: 3) == nil)  // the break itself
    }

    @Test func blankLinesBetweenParagraphsAreNumbered() {
        let lines = LineNumbers("# Title\n\nBody")
        #expect(lines.count == 3)
        #expect(lines.number(ofLineStartingAt: 8) == 2)
        #expect(lines.number(ofLineStartingAt: 9) == 3)
    }

    @Test func aTrailingBreakStartsAnEmptyLastLine() {
        let lines = LineNumbers("one\n")
        #expect(lines.count == 2)
        #expect(lines.number(ofLineStartingAt: 4) == 2)
    }

    @Test func windowsLineBreaksCountOnce() {
        let lines = LineNumbers("one\r\ntwo")
        #expect(lines.count == 2)
        #expect(lines.number(ofLineStartingAt: 5) == 2)
    }

    @Test func positionsAreUTF16LikeTheTextView() {
        let lines = LineNumbers("🎉\nnext")  // the emoji is two UTF-16 units
        #expect(lines.number(ofLineStartingAt: 3) == 2)
    }

    @Test func outOfRangePositionsStartNoLine() {
        let lines = LineNumbers("one")
        #expect(lines.number(ofLineStartingAt: -1) == nil)
        #expect(lines.number(ofLineStartingAt: 99) == nil)
    }
}
