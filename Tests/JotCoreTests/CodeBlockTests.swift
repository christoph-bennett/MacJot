import Foundation
import Testing
@testable import JotCore

/// Fenced code blocks (ticket 35): where they are, that nothing inside them is
/// Markdown, and the toolbar's Code Block toggle. `|` marks the cursor, `«…»` a selection.
struct CodeBlockTests {
    private func toggle(_ before: String) -> String {
        let ns = before as NSString
        let selection: NSRange
        var text: String
        if ns.range(of: "«").location != NSNotFound {
            let start = ns.range(of: "«").location
            text = ns.replacingOccurrences(of: "«", with: "")
            let end = (text as NSString).range(of: "»").location
            text = (text as NSString).replacingOccurrences(of: "»", with: "")
            selection = NSRange(location: start, length: end - start)
        } else {
            selection = NSRange(location: ns.range(of: "|").location, length: 0)
            text = ns.replacingOccurrences(of: "|", with: "")
        }
        let edit = MarkdownEditing.toggleCodeBlock(in: text, selection: selection)
        let after = (text as NSString).replacingCharacters(in: edit.range, with: edit.replacement) as NSString
        guard edit.selection.length > 0 else { return after.replacingCharacters(in: edit.selection, with: "|") }
        let marked = after.replacingCharacters(in: NSRange(location: NSMaxRange(edit.selection), length: 0), with: "»") as NSString
        return marked.replacingCharacters(in: NSRange(location: edit.selection.location, length: 0), with: "«")
    }

    // MARK: Where blocks are

    @Test func aBlockRunsFromFenceToFence() {
        let text = "Intro\n```\ncode\n```\nAfter"
        #expect(MarkdownStyle.codeBlocks(in: text) == [NSRange(location: 6, length: 13)])
    }

    @Test func anUnclosedFenceRunsToTheEnd() {
        let text = "Intro\n~~~\ncode"
        #expect(MarkdownStyle.codeBlocks(in: text) == [NSRange(location: 6, length: 8)])
    }

    // Return writes blank lines inside code as they are: they aren't paragraph gaps there.
    @Test func blankLinesInCodeAreNoParagraphGaps() {
        let text = "```\nlet a = 1\n\nlet b = 2\n```"
        #expect(!MarkdownStyle.isParagraphGap(at: 14, in: text))
        #expect(LineNumbers(text).count == 5)
        #expect(MarkdownStyle.isParagraphGap(at: 5, in: "Para\n\nNext"))
    }

    @Test func nothingInsideABlockIsFormatted() {
        let text = "```\n# not a heading **nor bold**\n```"
        let spans = MarkdownStyle.spans(in: text, range: NSRange(location: 0, length: (text as NSString).length))
        #expect(spans.allSatisfy { $0.kind == .marker || $0.kind == .codeBlock })
    }

    // MARK: The toggle

    @Test func wrapsTheSelectedLines() {
        #expect(toggle("Intro\n«let a = 1\nlet b»\nAfter") == "Intro\n```\n«let a = 1\nlet b»\n```\nAfter")
    }

    @Test func wrapsTheCursorsLine() {
        #expect(toggle("let| a = 1") == "```\nlet| a = 1\n```")
    }

    @Test func insertsAnEmptyBlockOnAnEmptyLine() {
        #expect(toggle("Intro\n\n|") == "Intro\n\n```\n|\n```")
    }

    @Test func removesTheFencesInsideABlock() {
        #expect(toggle("Intro\n```\nlet| a\n```\nAfter") == "Intro\nlet| a\nAfter")
        #expect(toggle("```\nlet a\nlet| b") == "let a\nlet| b")  // unclosed
    }
}

/// Review findings for ticket 35: fences as in CommonMark, and positions on unwrapping.
struct CodeBlockEdgeTests {
    @Test func onlyAMatchingFenceCloses() {
        let text = "```\na\n~~~\nb\n```\nc"
        #expect(MarkdownStyle.codeBlocks(in: text) == [NSRange(location: 0, length: 16)])
        #expect(MarkdownStyle.codeBlocks(in: "```\na\n```swift\nb").count == 1)  // an info string doesn't close
        #expect(MarkdownStyle.codeBlocks(in: "````\na\n```\nb\n````").first?.length == 17)  // shorter doesn't close
    }

    @Test func anIndentedFenceIsNoFence() {
        #expect(MarkdownStyle.codeBlocks(in: "    ```\ncode").isEmpty)
        #expect(MarkdownStyle.codeBlocks(in: "   ```\ncode").count == 1)
    }

    @Test func theCursorOnTheClosingFenceStaysInTheText() {
        let edit = MarkdownEditing.toggleCodeBlock(in: "```\nab\n```\nAfter", selection: NSRange(location: 10, length: 0))
        #expect(edit.replacement == "ab\n")
        #expect(edit.selection == NSRange(location: 3, length: 0))
    }

    @Test func aSelectionRunningIntoABlockUnwrapsIt() {
        let text = "Intro\n```\ncode\n```\nAfter"
        let edit = MarkdownEditing.toggleCodeBlock(in: text, selection: NSRange(location: 0, length: 12))
        let after = (text as NSString).replacingCharacters(in: edit.range, with: edit.replacement)
        #expect(after == "Intro\ncode\nAfter")
    }

    @Test func aSelectionPastTheBlockIsKept() {
        let text = "```\na\n```\nb"
        let edit = MarkdownEditing.toggleCodeBlock(in: text, selection: NSRange(location: 4, length: 7))  // "a" … "b"
        let after = (text as NSString).replacingCharacters(in: edit.range, with: edit.replacement) as NSString
        #expect(after == "a\nb")
        #expect(after.substring(with: edit.selection) == "a\nb")
    }
}

/// The language after an opening fence is content: Search finds it.
struct CodeBlockSearchTests {
    @Test func theLanguageNameIsSearchable() {
        let text = "Setup\n\n```swift\nlet a = 1\n```\nAfter"
        #expect(NoteSummary.matches("swift", text: text))
        #expect(NoteSummary.matches("let a", text: text))
        #expect(!NoteSummary.matches("```", text: text))  // the fences stay syntax
    }
}
