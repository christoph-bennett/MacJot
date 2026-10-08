import Foundation
import Testing
@testable import JotCore

/// Seam 2: editing commands over (text, selection) → (text, selection).
/// `|` marks the cursor in the case strings.
struct MarkdownEditingTests {
    /// Applies Return (or Shift-Return) at the `|` in `before` and renders the result with `|`.
    private func pressReturn(_ before: String, soft: Bool = false) -> String {
        let cursor = (before as NSString).range(of: "|")
        let text = (before as NSString).replacingCharacters(in: cursor, with: "")
        let edit = MarkdownEditing.newline(in: text, selection: NSRange(location: cursor.location, length: 0), soft: soft)
        let after = (text as NSString).replacingCharacters(in: edit.range, with: edit.replacement)
        return (after as NSString).replacingCharacters(in: edit.selection, with: "|")
    }

    // MARK: Return starts a paragraph (ADR 0004)

    @Test(arguments: [
        ("Biggie Smalls is the illest|", "Biggie Smalls is the illest\n\n|"),
        ("# Heading|", "# Heading\n\n|"),
        ("Title\n\nFirst paragraph|", "Title\n\nFirst paragraph\n\n|"),
        ("one two| three", "one two\n\n|three"),         // no stray space starts the new paragraph
        ("para|\n\nNext", "para\n\n|\n\nNext"),
        ("line1|\nline2", "line1\n\n|\n\nline2"),       // new paragraph isn't glued to a soft-broken line
        ("---\n\nHello|", "---\n\nHello\n\n|"),        // unclosed `---` ended by a blank line is a rule, not frontmatter
    ])
    func returnInsertsAParagraphBreak(before: String, after: String) {
        #expect(pressReturn(before) == after)
    }

    @Test(arguments: [
        ("Line one|", "Line one\n|"),
        ("one| two", "one\n| two"),
    ])
    func shiftReturnInsertsASingleLineBreak(before: String, after: String) {
        #expect(pressReturn(before, soft: true) == after)
    }

    @Test(arguments: [
        ("Para\n\n|", "Para\n\n\n|"),                  // already on a blank line
        ("Para\n|Next", "Para\n\n|Next"),              // at the start of a line
        ("- item|", "- item\n|"),                      // bullet list
        ("1. item|", "1. item\n|"),                    // numbered list
        ("- [ ] task|", "- [ ] task\n|"),              // checklist
        ("> quoted|", "> quoted\n|"),                  // quote
        ("---\ntags: x|\n---\nTitle", "---\ntags: x\n|\n---\nTitle"),  // inside frontmatter
        ("---|", "---\n|"),                            // opening fence of frontmatter
        ("```swift\nlet a = 1|\n```", "```swift\nlet a = 1\n|\n```"),  // fenced code block
        ("    indented code|", "    indented code\n|"),  // indented code block
    ])
    func returnInsertsASingleLineBreakWhereParagraphsDontApply(before: String, after: String) {
        #expect(pressReturn(before) == after)
    }

    @Test func returnInATableRowIsASingleLineBreak() {
        let text = "| a | b |"
        let edit = MarkdownEditing.newline(in: text, selection: NSRange(location: 9, length: 0), soft: false)
        #expect(edit.replacement == "\n")
    }

    @Test func returnReplacesTheSelection() {
        let text = "keep this drop that"
        let edit = MarkdownEditing.newline(in: text, selection: NSRange(location: 10, length: 4), soft: false)
        #expect(edit.range == NSRange(location: 10, length: 5))  // incl. the space after, so "that" starts the paragraph
        #expect(edit.replacement == "\n\n")
        #expect(edit.selection == NSRange(location: 12, length: 0))
    }

    // MARK: Title line and frontmatter

    @Test(arguments: [
        ("Title\nbody", "Title"),
        ("\n  \n# Real Title\nbody", "# Real Title"),
        ("---\ntags: [a]\n---\n\nAfter fm\n", "After fm"),
        ("---\n\nAfter a rule", "After a rule"),
    ])
    func titleLineRangeCoversTheTitleLine(text: String, line: String) throws {
        let range = try #require(MarkdownEditing.titleLineRange(in: text))
        #expect((text as NSString).substring(with: range) == line)
        #expect(Title.of(text) == line.trimmingCharacters(in: .whitespaces))
    }

    @Test func noTitleLineInBlankTextOrOpenFrontmatter() {
        #expect(MarkdownEditing.titleLineRange(in: " \n\n") == nil)
        #expect(MarkdownEditing.titleLineRange(in: "---\ntags: x\n") == nil)
    }

    @Test func frontmatterRangeIncludesBothFences() throws {
        let text = "---\ntags: [a]\n---\nTitle"
        let range = try #require(MarkdownEditing.frontmatterRange(in: text))
        #expect((text as NSString).substring(with: range) == "---\ntags: [a]\n---")
        #expect(MarkdownEditing.frontmatterRange(in: "Title\n---\nx\n---") == nil)
    }
}
