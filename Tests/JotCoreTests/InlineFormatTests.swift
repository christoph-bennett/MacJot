import Foundation
import Testing
@testable import JotCore

/// Seam 2: the Formatting Toolbar's inline commands over (text, selection).
/// `|` marks the cursor and `«…»` a selection in the case strings.
struct InlineFormatTests {
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

    private func toggle(_ format: InlineFormat, _ marked: String) -> String {
        let (text, selection) = parse(marked)
        return render(text, MarkdownEditing.toggle(format, in: text, selection: selection))
    }

    private func link(_ marked: String) -> String {
        let (text, selection) = parse(marked)
        return render(text, MarkdownEditing.toggleLink(in: text, selection: selection))
    }

    // MARK: Applying

    @Test(arguments: [
        (InlineFormat.bold, "a «word» b", "a **«word»** b"),
        (.italic, "a «word» b", "a *«word»* b"),
        (.strikethrough, "a «word» b", "a ~~«word»~~ b"),
        (.code, "a «word» b", "a `«word»` b"),
        (.bold, "a «two words» b", "a **«two words»** b"),
        (.bold, "a wo|rd b", "a **wo|rd** b"),            // no selection: the word at the cursor
        (.bold, "a word| b", "a **word|** b"),            // cursor right after a word
        (.bold, "a |word b", "a **|word** b"),            // cursor right before a word
        (.bold, "a | b", "a **|** b"),                    // no word: an empty pair to type into
        (.bold, "|", "**|**"),
        (.italic, "Über|", "*Über|*"),
        (.bold, "«line\n»", "**«line»**\n"),              // surrounding whitespace stays outside
        (.italic, "a **«word»** b", "a ***«word»*** b"),  // italic inside bold
        (.bold, "a *«word»* b", "a ***«word»*** b"),      // bold around italic
        (.italic, "**wo|rd**", "***wo|rd***"),
    ])
    func applies(format: InlineFormat, before: String, after: String) {
        #expect(toggle(format, before) == after)
    }

    // MARK: Removing

    @Test(arguments: [
        (InlineFormat.bold, "a **«word»** b", "a «word» b"),
        (.bold, "a «**word**» b", "a «word» b"),          // markers inside the selection
        (.italic, "a *«word»* b", "a «word» b"),
        (.strikethrough, "a «~~word~~» b", "a «word» b"),
        (.code, "a `«word»` b", "a «word» b"),
        (.bold, "a **wo|rd** b", "a wo|rd b"),
        (.bold, "a **|** b", "a | b"),
        (.bold, "a ***«word»*** b", "a *«word»* b"),      // keeps the italic
        (.italic, "a ***«word»*** b", "a **«word»** b"),  // keeps the bold
        (.bold, "**two wo|rds**", "two wo|rds"),          // cursor anywhere in a formatted phrase
        (.bold, "x **two «words»** y", "x two «words» y"),
    ])
    func removes(format: InlineFormat, before: String, after: String) {
        #expect(toggle(format, before) == after)
    }

    // MARK: Separate spans stay separate

    @Test(arguments: [
        (InlineFormat.italic, "«*a* and *c*»", "*«*a* and *c*»*"),         // two spans selected: wrap, don't strip
        (.bold, "«**a** and **b**»", "**«**a** and **b**»**"),
        (.bold, "**a** wo|rd **b**", "**a** **wo|rd** **b**"),           // between two bold spans
        (.italic, "* it|em", "* *it|em*"),                                // a list bullet isn't italic
    ])
    func separateSpans(format: InlineFormat, before: String, after: String) {
        #expect(toggle(format, before) == after)
    }

    // MARK: Each command is its own inverse

    @Test(arguments: InlineFormat.allCases, [
        "a «word» b", "a wo|rd b", "a word| b", "a | b", "|", "«two words»", "x *«word»* y", "x **«word»** y",
        "x ***wo|rd*** y", "Ünïcödé|",
    ])
    func applyingTwiceRestoresTextAndSelection(format: InlineFormat, marked: String) {
        let (text, selection) = parse(marked)
        let once = MarkdownEditing.toggle(format, in: text, selection: selection)
        let middle = (text as NSString).replacingCharacters(in: once.range, with: once.replacement)
        let twice = MarkdownEditing.toggle(format, in: middle, selection: once.selection)
        #expect(render(middle, twice) == marked)
    }

    // MARK: Link

    @Test(arguments: [
        ("a «word» b", "a [word](«url») b"),             // the URL placeholder is selected for typing
        ("a wo|rd b", "a [word](«url») b"),
        ("a | b", "a [](«url») b"),
        ("a [word](«url») b", "a «word» b"),             // inside a link: unlink, keeping its text
        ("a [wo|rd](https://x.org) b", "a «word» b"),
        ("a «[word](https://x.org)» b", "a «word» b"),
        ("a [](«url») b", "a | b"),
        ("see [x](y)|", "see [x](y)[](«url»)"),          // right after a link isn't inside it
        ("|[x](y)", "[](«url»)[x](y)"),
        ("[F|oo](https://w.org/Foo_(bar))", "«Foo»"),     // parentheses in the URL
    ])
    func link(before: String, after: String) {
        #expect(link(before) == after)
    }

    @Test(arguments: ["a «word» b", "a | b", "a «two words» b"])
    func linkingTwiceRestoresTextAndSelection(marked: String) {
        let (text, selection) = parse(marked)
        let once = MarkdownEditing.toggleLink(in: text, selection: selection)
        let middle = (text as NSString).replacingCharacters(in: once.range, with: once.replacement)
        #expect(render(middle, MarkdownEditing.toggleLink(in: middle, selection: once.selection)) == marked)
    }
}
