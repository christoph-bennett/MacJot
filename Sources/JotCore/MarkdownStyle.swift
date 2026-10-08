import Foundation

/// What the editor styles: ranges of Markdown constructs and their syntax markers.
/// Everything is line-local, so the editor can restyle just the lines it edited;
/// the Title line and frontmatter are document-level (see `MarkdownEditing`).
public enum MarkdownStyle {
    public struct Span: Equatable {
        public enum Kind: Equatable {
            case heading(Int)
            case quote
            case bold
            case italic
            case strikethrough
            case code
            /// The visible link text; the brackets and `(url)` are markers.
            case link
            /// Syntax characters, shown dimmed.
            case marker
            /// The first blank line after a paragraph, shown as spacing rather than a full line.
            case paragraphGap
        }

        public var range: NSRange
        public var kind: Kind
    }

    /// Spans in the lines touching `range` (expanded to whole lines), in order:
    /// line constructs first, then inline ones, each followed by its markers.
    public static func spans(in text: String, range: NSRange) -> [Span] {
        let ns = text as NSString
        let lines = ns.lineRange(for: range)
        var spans: [Span] = []
        ns.enumerateSubstrings(in: lines, options: [.byLines, .substringNotRequired]) { _, line, _, _ in
            lineSpans(ns, line: line, into: &spans)
        }
        inlineSpans(ns, in: lines, into: &spans)
        return spans
    }

    // MARK: Line constructs

    private static let heading = regex(#"^(#{1,6})[ \t]+"#)
    private static let rule = regex(#"^[ \t]*([-*_])(?:[ \t]*\1){2,}[ \t]*$"#)
    private static let quote = regex(#"^[ \t]*>[ \t]?"#)
    private static let listItem = regex(#"^[ \t]*(?:[-*+]|\d+[.)])[ \t]+"#)
    private static let task = regex(#"\G\[[ xX]\][ \t]+"#)

    private static func lineSpans(_ ns: NSString, line: NSRange, into spans: inout [Span]) {
        if line.length == 0 || ns.substring(with: line).trimmingCharacters(in: .whitespaces).isEmpty {
            if isParagraphGap(ns, blankLine: line) {
                spans.append(Span(range: ns.lineRange(for: line), kind: .paragraphGap))
            }
            return
        }
        if rule.firstMatch(in: ns as String, range: line) != nil {
            spans.append(Span(range: line, kind: .marker))  // a horizontal rule: all syntax
            return
        }
        if let match = heading.firstMatch(in: ns as String, range: line) {
            spans.append(Span(range: line, kind: .heading(match.range(at: 1).length)))
            spans.append(Span(range: match.range, kind: .marker))
            return
        }
        if let match = quote.firstMatch(in: ns as String, range: line) {
            spans.append(Span(range: line, kind: .quote))
            spans.append(Span(range: match.range, kind: .marker))
            return
        }
        if let match = listItem.firstMatch(in: ns as String, range: line) {
            spans.append(Span(range: match.range, kind: .marker))
            let rest = NSRange(location: NSMaxRange(match.range), length: NSMaxRange(line) - NSMaxRange(match.range))
            if let box = task.firstMatch(in: ns as String, range: rest) {
                spans.append(Span(range: box.range, kind: .marker))
            }
        }
    }

    /// Whether a cursor at `location` would sit on a paragraph gap: the small
    /// spacer line between two paragraphs, which is no place to type.
    public static func isParagraphGap(at location: Int, in text: String) -> Bool {
        let ns = text as NSString
        guard location < ns.length else { return false }  // the empty last line
        let line = ns.lineRange(for: NSRange(location: location, length: 0))
        let blank = ns.substring(with: line).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return blank && isParagraphGap(ns, blankLine: line)
    }

    /// A blank line directly after a non-blank one. Further blank lines keep
    /// their full height: the user added them on purpose.
    private static func isParagraphGap(_ ns: NSString, blankLine: NSRange) -> Bool {
        guard blankLine.location > 0 else { return false }
        let previous = ns.lineRange(for: NSRange(location: blankLine.location - 1, length: 0))
        return !ns.substring(with: previous).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: Inline constructs

    private static let code = regex(#"(`+)(?!`)(.+?)(?<!`)\1(?!`)"#)
    private static let link = regex(#"\[([^\]\n]+)\]\(([^)\n]*)\)"#)
    private static let boldItalic = regex(#"(\*\*\*|___)(?![\s*_])(.+?)(?<![\s*_])\1"#)
    private static let bold = regex(#"(\*\*|__)(?![\s*_])(.+?)(?<![\s*_])\1"#)
    private static let italic = regex(#"(?<![\w*])\*(?![\s*])(.+?)(?<![\s*])\*(?![\w*])|(?<![\w_])_(?![\s_])(.+?)(?<![\s_])_(?![\w_])"#)
    private static let strikethrough = regex(#"~~(?!\s)(.+?)(?<!\s)~~"#)

    private static func inlineSpans(_ ns: NSString, in range: NSRange, into spans: inout [Span]) {
        let text = ns as String
        // Code is literal: nothing inside it is parsed further.
        var codeRanges: [NSRange] = []
        for match in code.matches(in: text, range: range) {
            let fence = match.range(at: 1).length
            codeRanges.append(match.range)
            spans.append(Span(range: match.range, kind: .code))
            spans.append(Span(range: NSRange(location: match.range.location, length: fence), kind: .marker))
            spans.append(Span(range: NSRange(location: NSMaxRange(match.range) - fence, length: fence), kind: .marker))
        }
        // A construct may contain code, but not start or end inside it.
        func delimitersInCode(_ r: NSRange) -> Bool {
            codeRanges.contains { NSLocationInRange(r.location, $0) || NSLocationInRange(NSMaxRange(r) - 1, $0) }
        }

        for match in link.matches(in: text, range: range) where !delimitersInCode(match.range) {
            let label = match.range(at: 1)
            spans.append(Span(range: label, kind: .link))
            spans.append(Span(range: NSRange(location: match.range.location, length: 1), kind: .marker))
            spans.append(Span(range: NSRange(location: NSMaxRange(label), length: NSMaxRange(match.range) - NSMaxRange(label)), kind: .marker))
        }

        // `***x***` is both; its inner `**`/`*` must not match again on their own.
        var boldItalicRanges: [NSRange] = []
        for match in boldItalic.matches(in: text, range: range) where !delimitersInCode(match.range) {
            boldItalicRanges.append(match.range)
            let fence = match.range(at: 1).length
            spans.append(Span(range: match.range, kind: .bold))
            spans.append(Span(range: match.range, kind: .italic))
            spans.append(Span(range: NSRange(location: match.range.location, length: fence), kind: .marker))
            spans.append(Span(range: NSRange(location: NSMaxRange(match.range) - fence, length: fence), kind: .marker))
        }
        func overlapsBoldItalic(_ r: NSRange) -> Bool {
            boldItalicRanges.contains { NSIntersectionRange($0, r).length > 0 }
        }

        for (pattern, kind) in [(bold, Span.Kind.bold), (italic, .italic), (strikethrough, .strikethrough)] {
            for match in pattern.matches(in: text, range: range)
            where !delimitersInCode(match.range) && (kind == .strikethrough || !overlapsBoldItalic(match.range)) {
                let content = (1..<match.numberOfRanges).map(match.range(at:))
                    .last { $0.location != NSNotFound && $0.length > 0 && $0.length < match.range.length - 1 }
                    ?? match.range
                let open = content.location - match.range.location
                let close = NSMaxRange(match.range) - NSMaxRange(content)
                spans.append(Span(range: match.range, kind: kind))
                spans.append(Span(range: NSRange(location: match.range.location, length: open), kind: .marker))
                spans.append(Span(range: NSRange(location: NSMaxRange(content), length: close), kind: .marker))
            }
        }
    }

    private static func regex(_ pattern: String) -> NSRegularExpression {
        // Patterns are literals; a typo is a programming error caught by the tests.
        try! NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
    }
}
