import Foundation
import Testing
@testable import JotCore

/// The line the editor highlights (ticket 29): the file's line with the cursor,
/// break included, and none while text is selected.
struct CurrentLineTests {
    @Test func theLineWithTheCursorIncludingItsBreak() {
        #expect(CurrentLine.range(in: "one\ntwo\nthree", selection: NSRange(location: 5, length: 0))
                == NSRange(location: 4, length: 4))
    }

    @Test func theCursorAtALinesEndIsStillOnIt() {
        #expect(CurrentLine.range(in: "one\ntwo", selection: NSRange(location: 3, length: 0))
                == NSRange(location: 0, length: 4))
        #expect(CurrentLine.range(in: "one\ntwo", selection: NSRange(location: 7, length: 0))
                == NSRange(location: 4, length: 3))
    }

    // After a final break the cursor is on the empty last line, which has no characters.
    @Test func theEmptyLastLine() {
        #expect(CurrentLine.range(in: "one\n", selection: NSRange(location: 4, length: 0))
                == NSRange(location: 4, length: 0))
        #expect(CurrentLine.range(in: "", selection: NSRange(location: 0, length: 0))
                == NSRange(location: 0, length: 0))
    }

    @Test func noLineWhileTextIsSelected() {
        #expect(CurrentLine.range(in: "one\ntwo", selection: NSRange(location: 1, length: 2)) == nil)
    }
}
