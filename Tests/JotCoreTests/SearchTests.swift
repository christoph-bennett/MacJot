import Foundation
import Testing
@testable import JotCore

/// Search by several words (ticket 37): every word, in any order, anywhere in
/// the Note; "quotes" for an exact phrase.
struct SearchTests {
    private let note = "Friday\n\nBuy oat milk to buy\nCall Müller"

    private func summary(_ text: String) -> NoteSummary {
        NoteSummary(url: URL(fileURLWithPath: "/n.md"), text: text, modified: .distantPast)
    }

    @Test func splitsWordsAndQuotedPhrases() {
        #expect(SearchQuery.terms("milk  friday") == ["milk", "friday"])
        #expect(SearchQuery.terms(#""buy milk" friday"#) == ["buy milk", "friday"])
        #expect(SearchQuery.terms("“oat milk” call") == ["oat milk", "call"])  // curly quotes too
        #expect(SearchQuery.terms(#"say "unfinished phrase"#) == ["say", "unfinished phrase"])
        #expect(SearchQuery.terms(#"a "" b"#) == ["a", "b"])
    }

    @Test func everyWordAnywhereInAnyOrder() {
        #expect(NoteSummary.matches("milk friday", text: note))   // Title and a line
        #expect(NoteSummary.matches("muller oat", text: note))    // accents and case ignored
        #expect(!NoteSummary.matches("milk saturday", text: note))
    }

    @Test func partsOfWordsStillMatch() {
        #expect(NoteSummary.matches("rida ülle", text: note))
    }

    @Test func aPhraseMustAppearAsIs() {
        #expect(NoteSummary.matches(#""oat milk""#, text: note))
        #expect(!NoteSummary.matches(#""milk oat""#, text: note))
        #expect(NoteSummary.matches("milk oat", text: note))
    }

    @Test func thePreviewShowsTheFirstWordsLine() {
        #expect(summary(note).matching("call milk")?.preview == "Call Müller")
        #expect(summary(note).matching("friday")?.preview == summary(note).preview)  // Title only: unchanged
    }
}
