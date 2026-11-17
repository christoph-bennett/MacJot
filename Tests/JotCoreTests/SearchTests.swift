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

    // MARK: Note metadata (ticket 53)

    private let clip = "---\nsource: Safari\ncreated: 2026-11-17 09:00\npage: https://example.com/9runzr\n---\nZebra facts\n\nStripes are unique."

    @Test func aWordOnlyInTheFrontmatterIsAResult() {
        #expect(summary(clip).matching("9runzr") != nil)
        #expect(summary(clip).matching("safari") != nil)
        #expect(summary("Zebra facts\n\nStripes").matching("safari") == nil)  // a Note without it is not
        #expect(summary(clip).matching("giraffe") == nil)
    }

    @Test func theMatchingMetadataLineIsThePreview() {
        #expect(summary(clip).matching("safari")?.preview == "source: Safari")
        #expect(summary(clip).matching("9runzr")?.preview == "page: https://example.com/9runzr")
    }

    @Test func aBodyMatchWinsOverMetadata() {
        #expect(summary(clip).matching("stripes safari")?.preview == "Stripes are unique.")
        let both = "---\nsource: Zebra\n---\nTitle\n\nA zebra line"
        #expect(summary(both).matching("zebra")?.preview == "A zebra line")
    }

    @Test func aTitleWordDoesNotHideAMetadataOnlyWord() {
        #expect(summary(clip).matching("zebra safari")?.preview == "source: Safari")
        #expect(summary(clip).matching("zebra")?.preview == summary(clip).preview)  // Title only: unchanged
    }

    @Test func wordsMatchAcrossTitleBodyAndMetadata() {
        #expect(NoteSummary.matches("zebra unique safari", text: clip))
        #expect(!NoteSummary.matches("zebra unique chrome", text: clip))
    }

    @Test func keysAreNotSearchedOnlyValues() {
        #expect(summary(clip).matching("created") == nil)  // every Clip has it
        #expect(summary(clip).matching("2026-11-17") != nil)
    }

    @Test func aFenceIsNotMetadataAndUnclosedFrontmatterIsNotFrontmatter() {
        #expect(summary("Title\n\nBody\n\n---\nsource: Safari\n---\n").matching("safari")?.preview == "source: Safari")  // body, as today
        #expect(summary(clip).matching("---") == nil)
    }

    @Test func listItemsAndUrlsWithoutAKeyAreSearchedWhole() {
        let note = "---\ntags:\n  - https://example.com/x\n  - Zürich\n---\nTitle\n\nBody"
        #expect(summary(note).matching("https")?.preview == "- https://example.com/x")  // trimmed, whole line
        #expect(summary(note).matching("zurich")?.preview == "- Zürich")
        #expect(summary(note).matching("tags") == nil)
    }

    @Test func aClipWithFrontmatterAndNoTitleIsStillSearchable() {
        #expect(summary("---\nsource: Safari\n---\n").matching("safari")?.preview == "source: Safari")
        #expect(summary("---\n---\nTitle").matching("title") != nil)
    }

    @Test func controlBytesAreNotTerms() {
        #expect(summary(clip).matching("\u{1}") != nil)  // folds to no term: a blank query matches all
        #expect(summary(clip).matching("zebra \u{1}")?.preview == summary(clip).preview)
    }
}
