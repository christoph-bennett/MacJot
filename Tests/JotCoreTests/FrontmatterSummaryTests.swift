import Foundation
import Testing
@testable import JotCore

/// The Frontmatter Section's collapsed header line (ticket 44): `source · page`
/// when either exists, otherwise nothing (the editor words that itself).
struct FrontmatterSummaryTests {
    @Test func noFrontmatterHasNoSummary() {
        #expect(MarkdownEditing.frontmatterSummary(in: "Title\nBody") == nil)
        #expect(MarkdownEditing.frontmatterSummary(in: "---\nsource: Safari") == nil)  // not closed
    }

    @Test func sourceAndPage() {
        let text = "---\ncreated: 2026-11-15T10:00:00+01:00\nsource: Safari\npage: \"Personal — Finis\"\n---\nTitle"
        #expect(MarkdownEditing.frontmatterSummary(in: text) == "Safari · Personal — Finis")
    }

    @Test func oneOfThem() {
        #expect(MarkdownEditing.frontmatterSummary(in: "---\nsource: Safari\n---\nT") == "Safari")
        #expect(MarkdownEditing.frontmatterSummary(in: "---\npage: Docs\n---\nT") == "Docs")
    }

    @Test func neitherHasNoSummary() {
        #expect(MarkdownEditing.frontmatterSummary(in: "---\ntags: [a]\n---\nT") == nil)
        #expect(MarkdownEditing.frontmatterSummary(in: "---\n---\nT") == nil)
    }

    @Test func quotesAndEscapesAreUndone() {
        #expect(MarkdownEditing.frontmatterSummary(in: "---\npage: \"say \\\"hi\\\" \\\\ ok\"\n---\n") == "say \"hi\" \\ ok")
        #expect(MarkdownEditing.frontmatterSummary(in: "---\npage: 'it''s'\n---\n") == "it's")
    }

    @Test func emptyValueIsIgnored() {
        #expect(MarkdownEditing.frontmatterSummary(in: "---\nsource:\npage: Docs\n---\n") == "Docs")
        #expect(MarkdownEditing.frontmatterSummary(in: "---\nsource: \"\"\n---\n") == nil)
    }

    @Test func indentedKeysAndTrailingCommentsAreNotKeys() {
        #expect(MarkdownEditing.frontmatterSummary(in: "---\nmeta:\n  source: Nested\n---\n") == nil)
    }

    @Test func hiddenRangeIncludesTheBreakAfterTheClosingFence() {
        #expect(MarkdownEditing.frontmatterHiddenRange(in: "---\na: b\n---\nTitle") == NSRange(location: 0, length: 13))
        #expect(MarkdownEditing.frontmatterHiddenRange(in: "---\na: b\n---\n") == NSRange(location: 0, length: 13))
    }

    @Test func nothingIsHiddenWithoutABreakAfterTheFence() {
        #expect(MarkdownEditing.frontmatterHiddenRange(in: "---\na: b\n---") == nil)
        #expect(MarkdownEditing.frontmatterHiddenRange(in: "Title") == nil)
    }
}
