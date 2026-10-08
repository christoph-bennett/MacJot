import Foundation
import Testing
@testable import JotCore

/// Seam 2: the Formatting Toolbar's line commands over (text, selection).
/// `|` marks the cursor and `«…»` a selection in the case strings.
struct LineFormatTests {
    private func parse(_ marked: String) -> (String, NSRange) {
        let ns = marked as NSString
        let cursor = ns.range(of: "|")
        if cursor.location != NSNotFound {
            return (ns.replacingCharacters(in: cursor, with: ""), NSRange(location: cursor.location, length: 0))
        }
        let open = ns.range(of: "«"), close = ns.range(of: "»")
        let text = ns.replacingCharacters(in: close, with: "") as NSString
        return (text.replacingCharacters(in: open, with: ""),
                NSRange(location: open.location, length: close.location - open.location - open.length))
    }

    private func render(_ text: String, _ edit: TextEdit) -> String {
        let after = (text as NSString).replacingCharacters(in: edit.range, with: edit.replacement) as NSString
        guard edit.selection.length > 0 else { return after.replacingCharacters(in: edit.selection, with: "|") }
        let closed = after.replacingCharacters(in: NSRange(location: NSMaxRange(edit.selection), length: 0), with: "»")
        return (closed as NSString).replacingCharacters(in: NSRange(location: edit.selection.location, length: 0), with: "«")
    }

    private func toggle(_ format: LineFormat, _ marked: String) -> String {
        let (text, selection) = parse(marked)
        return render(text, MarkdownEditing.toggle(format, in: text, selection: selection))
    }

    // MARK: Lists and quotes

    @Test(arguments: [
        (LineFormat.bullet, "it|em", "- it|em"),
        (.bullet, "- it|em", "it|em"),
        (.bullet, "|", "- |"),
        (.bullet, "|item", "- |item"),
        (.bullet, "«a\nb»", "«- a\n- b»"),
        (.bullet, "«- a\nb»", "«- a\n- b»"),          // not all lines have it: set on all
        (.bullet, "«- a\n- b»", "«a\n\nb»"),          // all have it: remove; items become paragraphs
        (.bullet, "«a\n\nb»", "«- a\n- b»"),          // paragraphs become a tight list
        (.numbered, "«a\n\nb\n\nc»", "«1. a\n2. b\n3. c»"),
        (.bullet, "«\na\n\nb\n»", "«\n- a\n- b\n»"),  // blank lines around the selection stay
        (.bullet, "x\na «b» c\ny", "x\n- a «b» c\ny"),
        (.bullet, "* it|em", "it|em"),
        (.bullet, "  - x|", "  x|"),                  // indentation is kept
        (.numbered, "«a\nb\nc»", "«1. a\n2. b\n3. c»"),
        (.numbered, "3. fo|o", "fo|o"),
        (.checklist, "x|", "- [ ] x|"),
        (.checklist, "- [x] x|", "x|"),
        (.quote, "x|", "> x|"),
        (.quote, "> x|", "x|"),
        (.quote, "«a\nb»", "«> a\n> b»"),
    ])
    func togglesLists(format: LineFormat, before: String, after: String) {
        #expect(toggle(format, before) == after)
    }

    // MARK: Prefixes are replaced, not stacked

    @Test(arguments: [
        (LineFormat.bullet, "## x|", "- x|"),
        (.bullet, "1. x|", "- x|"),
        (.bullet, "- [ ] x|", "- x|"),
        (.numbered, "- x|", "1. x|"),
        (.checklist, "- x|", "- [ ] x|"),
        (.quote, "- x|", "> x|"),
        (.heading(1), "- item|", "# item|"),
        (.heading(3), "> q|", "### q|"),
        (.heading(1), "  - x|", "# x|"),             // headings aren't indented
        (.heading(2), "- [x] done|", "## done|"),
    ])
    func replacesPrefixes(format: LineFormat, before: String, after: String) {
        #expect(toggle(format, before) == after)
    }

    // MARK: Headings

    @Test(arguments: [
        (1, "x|", "# x|"),
        (2, "# x|", "## x|"),
        (2, "## x|", "x|"),                           // same level again: plain
        (0, "### x|", "x|"),                          // ⌘0: plain
        (0, "x|", "x|"),
        (0, "- x|", "- x|"),                          // plain only removes heading markers
        (1, "«a\nb»", "«# a\n# b»"),
        (2, "#| x", "## |x"),                         // cursor in the prefix moves past it
    ])
    func setsHeadings(level: Int, before: String, after: String) {
        #expect(toggle(.heading(level), before) == after)
    }

    // MARK: Each toggle is its own inverse

    @Test(arguments: [LineFormat.bullet, .numbered, .checklist],
          ["it|em", "|", "|item", "«a\n\nb»", "x\na «b» c\ny"])
    func listTwiceRestoresParagraphs(format: LineFormat, marked: String) {
        applyingTwiceRestoresTextAndSelection(format: format, marked: marked)
    }

    @Test(arguments: [LineFormat.quote, .heading(1), .heading(2), .heading(3)],
          ["it|em", "|", "|item", "«a\nb»", "«a\n\nb»", "x\na «b» c\ny"])
    func applyingTwiceRestoresTextAndSelection(format: LineFormat, marked: String) {
        let (text, selection) = parse(marked)
        let once = MarkdownEditing.toggle(format, in: text, selection: selection)
        let middle = (text as NSString).replacingCharacters(in: once.range, with: once.replacement)
        #expect(render(middle, MarkdownEditing.toggle(format, in: middle, selection: once.selection)) == marked)
    }
}
