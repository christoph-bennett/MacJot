import Foundation
import Testing
@testable import JotCore

/// The file's lines, as the gutter numbers them: wrapping doesn't matter here,
/// every line break starts a line; paragraph gaps start one but get no number.
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

    // The blank line Return puts between paragraphs (ADR 0004) is drawn as
    // spacing, not as a line, so it gets no number (decided 2026-10-09).
    @Test func paragraphGapsAreNotNumbered() {
        let lines = LineNumbers("# Title\n\nBody")
        #expect(lines.count == 2)
        #expect(lines.number(ofLineStartingAt: 8) == nil)
        #expect(lines.number(ofLineStartingAt: 9) == 2)
    }

    @Test func afterReturnTheNewParagraphIsLineTwo() {
        let lines = LineNumbers("Title\n\n")  // Return after the first line
        #expect(lines.number(ofLineStartingAt: 6) == nil)
        #expect(lines.number(ofLineStartingAt: 7) == 2)
        #expect(lines.count == 2)
    }

    @Test func furtherBlankLinesAreNumbered() {
        // Only the first blank line after a paragraph is a gap; more are on purpose.
        let lines = LineNumbers("one\n\n\n\ntwo")
        #expect(lines.number(ofLineStartingAt: 4) == nil)
        #expect(lines.number(ofLineStartingAt: 5) == 2)
        #expect(lines.number(ofLineStartingAt: 6) == 3)
        #expect(lines.number(ofLineStartingAt: 7) == 4)
    }

    @Test func aBlankFirstLineIsNumbered() {
        let lines = LineNumbers("\none")
        #expect(lines.number(ofLineStartingAt: 0) == 1)
        #expect(lines.number(ofLineStartingAt: 1) == 2)
    }

    @Test func singleLineBreaksAreAllNumbered() {
        let lines = LineNumbers("one\ntwo\nthree")  // Shift-Return
        #expect(lines.count == 3)
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
