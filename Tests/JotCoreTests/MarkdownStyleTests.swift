import Foundation
import Testing
@testable import JotCore

/// Seam 2: the spans the editor styles. Asserted as (kind, covered text) pairs.
struct MarkdownStyleTests {
    private func spans(_ text: String) -> [String] {
        let ns = text as NSString
        return MarkdownStyle.spans(in: text, range: NSRange(location: 0, length: ns.length)).map {
            "\($0.kind):\(ns.substring(with: $0.range))"
        }
    }

    @Test func heading() {
        #expect(spans("## Plan") == ["heading(2):## Plan", "marker:## "])
    }

    @Test func boldItalicStrikethrough() {
        #expect(spans("a **b** c") == ["bold:**b**", "marker:**", "marker:**"])
        #expect(spans("a *b* c") == ["italic:*b*", "marker:*", "marker:*"])
        #expect(spans("a _b_ c") == ["italic:_b_", "marker:_", "marker:_"])
        #expect(spans("a ~~b~~ c") == ["strikethrough:~~b~~", "marker:~~", "marker:~~"])
    }

    @Test func boldItalic() {
        #expect(spans("***both***") == ["bold:***both***", "italic:***both***", "marker:***", "marker:***"])
    }

    @Test func emphasisAndLinksMayContainCode() {
        #expect(spans("**run `make` now**").contains("bold:**run `make` now**"))
        #expect(spans("[`foo`](u)").contains("link:`foo`"))
    }

    @Test func emphasisDelimitersInsideCodeAreLiteral() {
        #expect(!spans("`a **b` c**").contains { $0.hasPrefix("bold") })
    }

    @Test func boldIsNotAlsoReadAsItalic() {
        #expect(!spans("**bold**").contains { $0.hasPrefix("italic") })
    }

    @Test func snakeCaseIsNotItalic() {
        #expect(spans("my_var_name").isEmpty)
    }

    @Test func inlineCodeIsNotParsedFurther() {
        #expect(spans("run `a **b**` now") == ["code:`a **b**`", "marker:`", "marker:`"])
    }

    @Test func link() {
        #expect(spans("see [docs](https://x.y) now") == ["link:docs", "marker:[", "marker:](https://x.y)"])
    }

    @Test func listQuoteAndTaskMarkers() {
        #expect(spans("- item") == ["marker:- "])
        #expect(spans("12. item") == ["marker:12. "])
        #expect(spans("- [x] done") == ["marker:- ", "marker:[x] "])
        #expect(spans("> quoted") == ["quote:> quoted", "marker:> "])
    }

    @Test func blankLineBetweenParagraphs() {
        #expect(spans("a\n\nb") == ["paragraphGap:\n"])
    }

    @Test func spansStayWithinTheRequestedRange() {
        let text = "**one**\n**two**"
        let ns = text as NSString
        let second = ns.lineRange(for: NSRange(location: 9, length: 0))
        let found = MarkdownStyle.spans(in: text, range: second).map { ns.substring(with: $0.range) }
        #expect(found == ["**two**", "**", "**"])
    }

    @Test func tokenizingAFewThousandLinesIsFast() {
        let text = String(repeating: "# Head\nSome **bold** and *italic* with `code` and [l](u).\n\n- item\n", count: 1500)
        let start = ContinuousClock.now
        _ = MarkdownStyle.spans(in: text, range: NSRange(location: 0, length: (text as NSString).length))
        #expect(ContinuousClock.now - start < .seconds(1))
    }
}
