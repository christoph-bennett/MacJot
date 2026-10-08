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
        ("> quoted|", "> quoted\n|"),                  // quote
        ("---\ntags: x|\n---\nTitle", "---\ntags: x\n|\n---\nTitle"),  // inside frontmatter
        ("---|", "---\n|"),                            // opening fence of frontmatter
        ("```swift\nlet a = 1|\n```", "```swift\nlet a = 1\n|\n```"),  // fenced code block
        ("    indented code|", "    indented code\n|"),  // indented code block
    ])
    func returnInsertsASingleLineBreakWhereParagraphsDontApply(before: String, after: String) {
        #expect(pressReturn(before) == after)
    }

    // MARK: Lists continue on Return

    @Test(arguments: [
        ("- item|", "- item\n- |"),
        ("* item|", "* item\n* |"),
        ("1. item|", "1. item\n2. |"),
        ("3. foo|", "3. foo\n4. |"),                  // the next number
        ("9) x|", "9) x\n10) |"),
        ("- [x] done|", "- [x] done\n- [ ] |"),       // a new item is unchecked
        ("- [ ] task|", "- [ ] task\n- [ ] |"),
        ("  - nested|", "  - nested\n  - |"),          // at the same indentation
        ("- fo|o", "- fo\n- |o"),                     // splits the item
    ])
    func returnContinuesAList(before: String, after: String) {
        #expect(pressReturn(before) == after)
    }

    @Test(arguments: [
        ("- |", "|"),
        ("a\n- |", "a\n|"),
        ("1. |", "|"),
        ("- [ ] |", "|"),
        ("  - |", "|"),
    ])
    func returnOnAnEmptyItemEndsTheList(before: String, after: String) {
        #expect(pressReturn(before) == after)
    }

    @Test(arguments: [
        ("- item|", "- item\n|"),                     // Shift-Return: a line break within the item
        ("> quoted|", "> quoted\n|"),
    ])
    func noContinuation(before: String, after: String) {
        #expect(pressReturn(before, soft: before.hasPrefix("-")) == after)
    }

    @Test(arguments: [
        ("-| item", "-\n| item"),                       // cursor inside the marker: a plain line break
        ("1|. item", "1\n|. item"),
        ("* * *|", "* * *\n\n|"),                       // a horizontal rule isn't a list
        ("***|", "***\n\n|"),
        ("a\n\n***|", "a\n\n***\n\n|"),
        ("- - -|", "- - -\n\n|"),
        ("text\n\n    - x|", "text\n\n    - x\n|"),     // indented code that looks like a list
        ("\t1. step|", "\t1. step\n|"),
        ("- a\n    - nested|", "- a\n    - nested\n    - |"),  // a nested list does continue
    ])
    func returnDoesNotContinueWhatIsNotAListItem(before: String, after: String) {
        #expect(pressReturn(before) == after)
    }

    @Test func returnOnAnEmptyItemWithASelectionReplacesIt() {
        let text = "- \nmore"
        let edit = MarkdownEditing.newline(in: text, selection: NSRange(location: 2, length: 5), soft: false)
        let after = (text as NSString).replacingCharacters(in: edit.range, with: edit.replacement)
        #expect(after == "- \n- ")
    }

    @Test func listsInsideCodeAndFrontmatterDontContinue() {
        #expect(pressReturn("```\n- x|\n```") == "```\n- x\n|\n```")
        #expect(pressReturn("---\ntags:\n- a|\n---\nT") == "---\ntags:\n- a\n|\n---\nT")
    }

    // MARK: Backspace after a paragraph break

    /// Applies Backspace at the `|` in `before`; `nil` if the text view's own deletion applies.
    private func pressBackspace(_ before: String) -> String? {
        let cursor = (before as NSString).range(of: "|")
        let text = (before as NSString).replacingCharacters(in: cursor, with: "")
        guard let edit = MarkdownEditing.deleteBackward(in: text, selection: NSRange(location: cursor.location, length: 0))
        else { return nil }
        let after = (text as NSString).replacingCharacters(in: edit.range, with: edit.replacement)
        return (after as NSString).replacingCharacters(in: edit.selection, with: "|")
    }

    @Test(arguments: [
        ("a\n\n|", "a|"),                    // Return then Backspace: back where you were
        ("a\n\n|b", "a|b"),                  // joins the paragraphs, like a word processor
        ("# Title\n\n|Body", "# Title|Body"),
    ])
    func backspaceRemovesAWholeParagraphBreak(before: String, after: String) {
        #expect(pressBackspace(before) == after)
    }

    @Test(arguments: [
        "a\n|",                              // a single line break
        "a\n\n\n|",                          // after a further blank line, which has full height
        "\n\n|",                             // blank lines only
        "a|b",
        "```\na\n\n|b\n```",                 // blank lines in code are literal
    ])
    func backspaceElsewhereIsTheTextViewsOwn(before: String) {
        #expect(pressBackspace(before) == nil)
    }

    @Test func backspaceWithASelectionIsTheTextViewsOwn() {
        #expect(MarkdownEditing.deleteBackward(in: "a\n\nb", selection: NSRange(location: 1, length: 2)) == nil)
    }

    // MARK: Checkboxes

    /// Clicks the character at `at` in `text`; renders the result, or `nil` if it wasn't a box.
    private func click(_ text: String, at location: Int, selection: NSRange = NSRange(location: 0, length: 0)) -> String? {
        guard let edit = MarkdownEditing.toggleCheckbox(in: text, at: location, selection: selection) else { return nil }
        #expect(edit.selection == selection)  // the cursor and selection stay where they were
        return (text as NSString).replacingCharacters(in: edit.range, with: edit.replacement)
    }

    @Test(arguments: [2, 3, 4])  // `[`, the space, `]`
    func clickingAnUncheckedBoxChecksIt(location: Int) {
        #expect(click("- [ ] milk", at: location) == "- [x] milk")
    }

    @Test func clickingACheckedBoxUnchecksIt() {
        #expect(click("- [x] milk", at: 3, selection: NSRange(location: 7, length: 2)) == "- [ ] milk")
        #expect(click("- [X] milk", at: 3) == "- [ ] milk")
    }

    @Test func boxesAnywhereInTheNote() {
        #expect(click("Shopping\n  * [ ] nested", at: 14) == "Shopping\n  * [x] nested")
        #expect(click("- [ ]", at: 3) == "- [x]")                 // an empty item
    }

    @Test(arguments: [("- [ ] milk", 0), ("- [ ] milk", 6), ("[ ] not a list", 1), ("- item [ ] later", 8), ("", 0),
                      ("1. [ ] numbered", 4),          // checklists are bullet items, as for Return and the toolbar
                      ("```\n- [ ] code\n```", 7)])  // code is literal
    func clickingElsewhereIsNotAToggle(text: String, location: Int) {
        #expect(click(text, at: location) == nil)
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
