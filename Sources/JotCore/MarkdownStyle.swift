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
            /// A checklist item's `[ ]` or `[x]`, drawn as a clickable box.
            case checkbox(checked: Bool)
            /// A checked item's text (after the box), shown struck through.
            case completedTask
            /// The first blank line after a paragraph, drawn with practically no height.
            case paragraphGap
            /// A fenced code block, fences included (ticket 35): literal, monospaced.
            case codeBlock
            /// The language after an opening fence (```` ```swift ````): dimmed like
            /// the fence, but content, so Search finds it.
            case codeInfo
        }

        public var range: NSRange
        public var kind: Kind

        /// Markdown syntax rather than content: left out of plain-text previews.
        public var isSyntax: Bool {
            switch kind {
            case .marker, .checkbox: true
            default: false
            }
        }
    }

    /// Spans in the lines touching `range` (expanded to whole lines), in order:
    /// line constructs first, then inline ones, each followed by its markers.
    /// Inside a fenced code block nothing is Markdown: it gets one `codeBlock`
    /// span, and its fence lines are markers.
    public static func spans(in text: String, range: NSRange) -> [Span] {
        spans(in: text, range: range, codeBlocks: codeBlocks(in: text))
    }

    /// As above, with the text's `codeBlocks(in:)` already found: callers that
    /// go through a Note line by line find them once.
    public static func spans(in text: String, range: NSRange, codeBlocks blocks: [NSRange]) -> [Span] {
        let ns = text as NSString
        let lines = ns.lineRange(for: range)
        let inBlock = { (r: NSRange) in blocks.contains { NSIntersectionRange($0, r).length > 0 || NSLocationInRange(r.location, $0) } }
        var spans: [Span] = []
        ns.enumerateSubstrings(in: lines, options: [.byLines, .substringNotRequired]) { _, line, _, _ in
            guard !inBlock(line) else { return }
            lineSpans(ns, line: line, codeBlocks: blocks, into: &spans)
        }
        var inline: [Span] = []
        inlineSpans(ns, in: lines, into: &inline)
        spans += inline.filter { !inBlock($0.range) }
        for block in blocks where NSIntersectionRange(block, lines).length > 0 {
            spans.append(Span(range: NSIntersectionRange(block, lines), kind: .codeBlock))
            for (index, fence) in fenceLines(ns, in: block).enumerated() where NSIntersectionRange(fence, lines).length > 0 {
                // Only the backticks or tildes are syntax; an opening fence's language is content.
                let line = ns.substring(with: fence)
                guard index == 0, let opening = Fence(line) else {
                    spans.append(Span(range: fence, kind: .marker))
                    continue
                }
                let run = (line.prefix { $0 == " " }.count) + opening.length
                spans.append(Span(range: NSRange(location: fence.location, length: run), kind: .marker))
                if let info = trimmed(NSRange(location: fence.location + run, length: fence.length - run), in: ns) {
                    spans.append(Span(range: info, kind: .codeInfo))
                }
            }
        }
        return spans
    }

    // MARK: Fenced code blocks

    /// Every fenced code block, from its opening fence line through its closing
    /// one (line breaks included); an unclosed one runs to the end. As in
    /// CommonMark: a fence is three or more ``` ` ``` or `~`, indented at most three
    /// spaces; it's closed only by a fence of the same character, at least as
    /// long, with nothing after it.
    public static func codeBlocks(in text: String) -> [NSRange] {
        let ns = text as NSString
        var blocks: [NSRange] = []
        var opening: (start: Int, fence: Fence)?
        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length), options: .byLines) { line, _, enclosing, _ in
            guard let fence = Fence(line ?? "") else { return }
            if let open = opening {
                guard fence.closes(open.fence) else { return }
                blocks.append(NSRange(location: open.start, length: NSMaxRange(enclosing) - open.start))
                opening = nil
            } else {
                opening = (enclosing.location, fence)
            }
        }
        if let open = opening { blocks.append(NSRange(location: open.start, length: ns.length - open.start)) }
        return blocks
    }

    /// Whether `line` is a fence line, opening or closing.
    public static func isFence(_ line: String) -> Bool { Fence(line) != nil }

    /// A fence line: its character, length, and whether anything follows it.
    struct Fence {
        let character: Character
        let length: Int
        let hasInfo: Bool

        init?(_ line: String) {
            let indent = line.prefix { $0 == " " }.count
            guard indent <= 3 else { return nil }
            let rest = line.dropFirst(indent)
            guard let first = rest.first, first == "`" || first == "~" else { return nil }
            let run = rest.prefix { $0 == first }.count
            guard run >= 3 else { return nil }
            character = first
            length = run
            hasInfo = !rest.dropFirst(run).trimmingCharacters(in: .whitespaces).isEmpty
        }

        func closes(_ opening: Fence) -> Bool {
            character == opening.character && length >= opening.length && !hasInfo
        }
    }

    /// A block's opening fence line, and its closing one if it has one (without line breaks).
    public static func fenceLines(_ ns: NSString, in block: NSRange) -> [NSRange] {
        var contents = 0
        ns.getLineStart(nil, end: nil, contentsEnd: &contents, for: NSRange(location: block.location, length: 0))
        let openingLine = NSRange(location: block.location, length: contents - block.location)
        var fences = [openingLine]
        let last = ns.lineRange(for: NSRange(location: max(NSMaxRange(block) - 1, block.location), length: 0))
        if last.location > block.location, let opening = Fence(ns.substring(with: openingLine)),
           Fence(ns.substring(with: last).trimmingCharacters(in: .newlines))?.closes(opening) == true {
            ns.getLineStart(nil, end: nil, contentsEnd: &contents, for: NSRange(location: last.location, length: 0))
            fences.append(NSRange(location: last.location, length: contents - last.location))
        }
        return fences
    }

    // MARK: Line constructs

    private static let heading = regex(#"^(#{1,6})[ \t]+"#)
    private static let rule = regex(#"^[ \t]*([-*_])(?:[ \t]*\1){2,}[ \t]*$"#)
    private static let quote = regex(#"^[ \t]*>[ \t]?"#)
    private static let listItem = regex(#"^[ \t]*(?:[-*+]|\d+[.)])[ \t]+"#)
    private static let task = regex(#"\G\[([ xX])\](?=[ \t]|$)"#)

    private static func lineSpans(_ ns: NSString, line: NSRange, codeBlocks: [NSRange], into spans: inout [Span]) {
        if line.length == 0 || ns.substring(with: line).trimmingCharacters(in: .whitespaces).isEmpty {
            if isParagraphGap(ns, blankLine: line, codeBlocks: codeBlocks) {
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
            // Bullet items only: `1. [ ]` isn't a checklist for Return or the toolbar either.
            let isBullet = "-*+".contains(ns.substring(with: match.range).trimmingCharacters(in: .whitespaces).prefix(1))
            if isBullet, let box = task.firstMatch(in: ns as String, range: rest) {
                let checked = ns.substring(with: box.range(at: 1)) != " "
                spans.append(Span(range: box.range, kind: .checkbox(checked: checked)))
                if checked, let text = trimmed(NSRange(location: NSMaxRange(box.range),
                                                       length: NSMaxRange(line) - NSMaxRange(box.range)), in: ns) {
                    spans.append(Span(range: text, kind: .completedTask))
                }
            }
        }
    }

    /// `range` without the spaces and tabs at either end; `nil` if nothing is left.
    private static func trimmed(_ range: NSRange, in ns: NSString) -> NSRange? {
        var start = range.location, end = NSMaxRange(range)
        while start < end, [0x20, 0x09].contains(ns.character(at: start)) { start += 1 }
        while end > start, [0x20, 0x09].contains(ns.character(at: end - 1)) { end -= 1 }
        return end > start ? NSRange(location: start, length: end - start) : nil
    }

    /// Whether a cursor at `location` would sit on a paragraph gap: the small
    /// spacer line between two paragraphs, which is no place to type.
    public static func isParagraphGap(at location: Int, in text: String) -> Bool {
        isParagraphGap(at: location, in: text, codeBlocks: codeBlocks(in: text))
    }

    /// As above, with the text's `codeBlocks(in:)` already found.
    public static func isParagraphGap(at location: Int, in text: String, codeBlocks: [NSRange]) -> Bool {
        let ns = text as NSString
        guard location < ns.length else { return false }  // the empty last line
        let line = ns.lineRange(for: NSRange(location: location, length: 0))
        let blank = ns.substring(with: line).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return blank && isParagraphGap(ns, blankLine: line, codeBlocks: codeBlocks)
    }

    /// A blank line directly after a non-blank one, outside code blocks (code is
    /// literal, ticket 35). Further blank lines keep their full height: the user
    /// added them on purpose. Line numbers skip the same lines (`LineNumbers`).
    static func isParagraphGap(_ ns: NSString, blankLine: NSRange, codeBlocks: [NSRange]) -> Bool {
        guard blankLine.location > 0 else { return false }
        guard !codeBlocks.contains(where: { NSLocationInRange(blankLine.location, $0) }) else { return false }
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
