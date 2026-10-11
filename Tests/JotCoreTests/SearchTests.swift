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

    @Test func aPhrasesPreviewIsItsLine() {
        #expect(summary(note).matching(#""oat milk" müller"#)?.preview == "Buy oat milk to buy")
    }

    // Ticket 41 folds the text once; these pin what case- and accent-blind matching did before.

    @Test func sharpSMatchesDoubleS() {
        #expect(NoteSummary.matches("strasse", text: "Plan\n\nHauptstraße 5"))
        #expect(NoteSummary.matches("straße", text: "Plan\n\nHauptstrasse 5"))
    }

    @Test func anAccentTypedSeparatelyIsIgnoredToo() {
        #expect(NoteSummary.matches("müller", text: "Plan\n\nCall Mu\u{308}ller"))
        #expect(NoteSummary.matches("mu\u{308}ller", text: "Plan\n\nCall Müller"))
        #expect(summary("Plan\n\nCall Mu\u{308}ller").matching("muller")?.preview == "Call Mu\u{308}ller")
    }

    /// Folded, `ß` is `ss`, so a word typed up to its first `s` still finds it (ticket 41;
    /// before, the Note dropped out at "stras" and came back at "strass").
    @Test func partOfAFoldedLetterMatches() {
        #expect(NoteSummary.matches("stras", text: "Plan\n\nHauptstraße 5"))
        let long = String(repeating: "word ", count: 50) + "Hauptstraße 5"
        #expect(summary("Plan\n\n" + long).matching("stras")?.preview == "…word word Hauptstraße 5")
    }

    @Test func ligaturesMatchTheirLetters() {
        #expect(NoteSummary.matches("file", text: "Plan\n\nThe ﬁle is here"))
    }

    @Test func lettersThatOnlyLookAlikeDontMatch() {
        #expect(!NoteSummary.matches("aesop", text: "Plan\n\nÆsop"))
        #expect(!NoteSummary.matches("1/2", text: "Plan\n\n½ cup"))
    }

    /// Coarse, in the debug build; scripts/benchmark-search.sh measures precisely (ticket 40).
    @Test func searchingAThousandNotesIsFast() {
        let words = ["plan", "Termin", "meeting", "Büro", "draft", "Straße", "review", "Woche", "call", "größer"]
        let notes = (0..<1_000).map { i in
            let lines = (0..<40).map { l in (0..<10).map { w in words[(i + l * 3 + w * 7) % words.count] }.joined(separator: " ") }
            return summary("# Note \(i)\n\n" + lines.joined(separator: "\n\n"))
        }
        let start = ContinuousClock.now
        let query = SearchQuery.Folded("zqxvbn")  // once, as the Note List does
        let found = notes.compactMap { $0.matching(query) }
        #expect(ContinuousClock.now - start < .milliseconds(200))  // about 960 ms before ticket 41
        #expect(found.isEmpty)
    }
}
