import Foundation
import Testing
@testable import JotCore

/// Horizontal lines (ticket 36): which lines are drawn as a rule, and inserting one.
struct HorizontalRuleTests {
    private func rules(_ text: String) -> [String] {
        let ns = text as NSString
        return MarkdownStyle.spans(in: text, range: NSRange(location: 0, length: ns.length))
            .filter { $0.kind == .rule }.map { ns.substring(with: $0.range) }
    }

    @Test func dashesStarsAndUnderscoresOnTheirOwnLine() {
        #expect(rules("One\n\n---\n\nTwo") == ["---"])
        #expect(rules("One\n\n* * *\n\nTwo") == ["* * *"])
        #expect(rules("One\n\n___") == ["___"])
    }

    // `---` right under text underlines it as a heading (setext), as in CommonMark.
    @Test func dashesUnderTextAreNoRule() {
        #expect(rules("Title\n---\n\nTwo").isEmpty)
        #expect(rules("Title\n***") == ["***"])
    }

    @Test func notInCode() {
        #expect(rules("```\n---\n```").isEmpty)
    }

    private func insert(_ before: String) -> String {
        let cursor = (before as NSString).range(of: "|")
        let text = (before as NSString).replacingCharacters(in: cursor, with: "")
        let edit = MarkdownEditing.insertHorizontalRule(in: text, selection: NSRange(location: cursor.location, length: 0))
        let after = (text as NSString).replacingCharacters(in: edit.range, with: edit.replacement)
        return (after as NSString).replacingCharacters(in: edit.selection, with: "|")
    }

    @Test(arguments: [
        ("Intro|", "Intro\n\n---\n\n|"),
        ("Intro\n\n|", "Intro\n\n---\n\n|"),
        ("Intro|\n\nNext", "Intro\n\n---\n\n|Next"),
        ("one| two", "one\n\n---\n\n|two"),
        ("Intro\n|", "Intro\n\n---\n\n|"),
    ])
    func insertsItsOwnParagraph(before: String, after: String) {
        #expect(insert(before) == after)
    }
}
