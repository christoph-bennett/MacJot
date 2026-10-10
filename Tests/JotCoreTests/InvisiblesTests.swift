import Foundation
import Testing
@testable import JotCore

/// Show Invisibles (ticket 34): which symbol each invisible character gets.
struct InvisiblesTests {
    private func symbols(_ text: String) -> String {
        let ns = text as NSString
        var marked = Array(repeating: "", count: ns.length)
        for (location, symbol) in Invisibles.symbols(in: text, range: NSRange(location: 0, length: ns.length)) {
            marked[location] = symbol.rawValue
        }
        return (0..<ns.length).map { marked[$0].isEmpty ? ns.substring(with: NSRange(location: $0, length: 1)) : marked[$0] }
            .joined()
    }

    @Test func spacesAndTabs() {
        #expect(symbols("a b\tc") == "a·b→c")
    }

    // Shift-Return writes one break; Return a paragraph: a break and the gap line (ADR 0004).
    @Test func lineBreaksAndParagraphEnds() {
        #expect(symbols("one\ntwo") == "one¬two")
        #expect(symbols("one\n\ntwo") == "one¶\ntwo")  // the gap's own break stays invisible
    }

    @Test func blankLinesBeyondTheGapAreBreaks() {
        #expect(symbols("one\n\n\ntwo") == "one¶\n¬two")
    }

    @Test func aFinalBreakIsALineBreak() {
        #expect(symbols("one\n") == "one¬")
    }

    @Test func onlyTheRangeAsked() {
        let text = "a b\nc d"
        let found = Invisibles.symbols(in: text, range: NSRange(location: 4, length: 3))
        #expect(found.map(\.location) == [5])
    }
}
