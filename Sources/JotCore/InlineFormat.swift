import Foundation

/// The Formatting Toolbar's inline formats.
public enum InlineFormat: CaseIterable, Sendable {
    case bold, italic, strikethrough, code

    var marker: String {
        switch self {
        case .bold: "**"
        case .italic: "*"
        case .strikethrough: "~~"
        case .code: "`"
        }
    }

    /// Whether `count` marker characters in a row, on each side, carry this
    /// format: `***` is both bold and italic, `**` is bold but not italic.
    func isApplied(run count: Int) -> Bool {
        switch self {
        case .bold: count == 2 || count == 3
        case .italic: count == 1 || count == 3
        case .strikethrough: count >= 2
        case .code: count >= 1
        }
    }
}

extension MarkdownEditing {
    /// Applies `format` around the selection, or the word at the cursor when
    /// nothing is selected (an empty pair to type into if there's no word), and
    /// removes it if it's already there: applying twice restores text and selection.
    public static func toggle(_ format: InlineFormat, in text: String, selection: NSRange) -> TextEdit {
        let ns = text as NSString
        let marker = format.marker
        let width = (marker as NSString).length
        let char = marker.utf16.first!
        let target = self.target(ns, selection)
        let isCursor = selection.length == 0

        // Markers selected along with the text: «**word**». Not when the selection
        // starts and ends with two different spans: «*a* and *c*».
        if target.length > 2 * width {
            let left = run(of: char, in: ns, from: target.location, forward: true, limit: NSMaxRange(target))
            let right = run(of: char, in: ns, from: NSMaxRange(target) - 1, forward: false, limit: target.location)
            let inner = NSRange(location: target.location + left, length: target.length - left - right)
            if inner.length > 0, format.isApplied(run: left), format.isApplied(run: right),
               !runs(of: char, in: ns, range: inner).contains(where: { format.isApplied(run: $0.length) }) {
                let kept = NSRange(location: target.location + width, length: target.length - 2 * width)
                return TextEdit(range: target, replacement: ns.substring(with: kept),
                                selection: NSRange(location: target.location, length: kept.length))
            }
        }

        // An empty pair to type into: **|**.
        if target.length == 0 {
            let left = run(of: char, in: ns, from: target.location - 1, forward: false, limit: -1)
            let right = run(of: char, in: ns, from: target.location, forward: true, limit: ns.length)
            if format.isApplied(run: left), format.isApplied(run: right) {
                return TextEdit(range: NSRange(location: target.location - width, length: 2 * width), replacement: "",
                                selection: NSRange(location: target.location - width, length: 0))
            }
        }

        // Inside a formatted span, anywhere in it: **two wo|rds**.
        if target.length > 0, let content = span(format, containing: target, in: ns) {
            let range = NSRange(location: content.location - width, length: content.length + 2 * width)
            let selection = isCursor
                ? NSRange(location: selection.location - width, length: 0)
                : NSRange(location: target.location - width, length: target.length)
            return TextEdit(range: range, replacement: ns.substring(with: content), selection: selection)
        }

        let selected = isCursor
            ? NSRange(location: selection.location + width, length: 0)
            : NSRange(location: target.location + width, length: target.length)
        return TextEdit(range: target, replacement: marker + ns.substring(with: target) + marker, selection: selected)
    }

    /// Turns the selection (or the word at the cursor) into `[text](url)` with
    /// the URL placeholder selected for typing. Inside a link, unlinks it,
    /// keeping its text selected.
    public static func toggleLink(in text: String, selection: NSRange) -> TextEdit {
        let ns = text as NSString
        let line = ns.lineRange(for: selection)
        for match in linkPattern.matches(in: text, range: line) where contains(match.range, selection) {
            let label = match.range(at: 1)
            return TextEdit(range: match.range, replacement: ns.substring(with: label),
                            selection: NSRange(location: match.range.location, length: label.length))
        }
        let target = self.target(ns, selection)
        let label = ns.substring(with: target)
        let placeholder = "url"
        return TextEdit(range: target, replacement: "[\(label)](\(placeholder))",
                        selection: NSRange(location: target.location + target.length + 3,
                                           length: (placeholder as NSString).length))
    }

    /// `[label](url)`; the URL may contain one level of parentheses, as Wikipedia's do.
    private static let linkPattern = try! NSRegularExpression(
        pattern: #"\[([^\]\n]*)\]\(((?:[^()\n]|\([^()\n]*\))*)\)"#)

    /// A cursor right before or after the link isn't in it; a selection may cover all of it.
    private static func contains(_ link: NSRange, _ selection: NSRange) -> Bool {
        selection.length == 0
            ? selection.location > link.location && selection.location < NSMaxRange(link)
            : selection.location >= link.location && NSMaxRange(selection) <= NSMaxRange(link)
    }

    // MARK: Helpers

    /// What a command applies to: the selection without surrounding whitespace
    /// (Markdown doesn't allow `**word **`), or with nothing selected, the word
    /// at the cursor, or the cursor itself.
    private static func target(_ ns: NSString, _ selection: NSRange) -> NSRange {
        guard selection.length == 0 else {
            var start = selection.location, end = NSMaxRange(selection)
            while start < end, isSpace(ns.character(at: start)) { start += 1 }
            while end > start, isSpace(ns.character(at: end - 1)) { end -= 1 }
            return NSRange(location: start, length: end - start)
        }
        var start = selection.location, end = selection.location
        while start > 0, isWordCharacter(ns.character(at: start - 1)) { start -= 1 }
        while end < ns.length, isWordCharacter(ns.character(at: end)) { end += 1 }
        return NSRange(location: start, length: end - start)
    }

    /// How many `char`s in a row start at `index`, going forwards or backwards,
    /// not reaching `limit`.
    private static func run(of char: unichar, in ns: NSString, from index: Int, forward: Bool, limit: Int) -> Int {
        var count = 0, i = index
        while forward ? i < limit : i > limit, i >= 0, i < ns.length, ns.character(at: i) == char {
            count += 1
            i += forward ? 1 : -1
        }
        return count
    }

    /// The content of the `format` span on `target`'s line that contains it. A
    /// run of markers opens a span if text follows it and closes one if text
    /// precedes it, so a `* ` list bullet opens nothing.
    private static func span(_ format: InlineFormat, containing target: NSRange, in ns: NSString) -> NSRange? {
        let char = format.marker.utf16.first!
        let line = ns.lineRange(for: target)
        var opener: NSRange?
        for run in runs(of: char, in: ns, range: line) where format.isApplied(run: run.length) {
            let canOpen = NSMaxRange(run) < NSMaxRange(line) && !isSpace(ns.character(at: NSMaxRange(run)))
            let canClose = run.location > line.location && !isSpace(ns.character(at: run.location - 1))
            if let open = opener, canClose {
                let content = NSRange(location: NSMaxRange(open), length: run.location - NSMaxRange(open))
                if target.location >= content.location, NSMaxRange(target) <= NSMaxRange(content) { return content }
                opener = nil
            } else if canOpen {
                opener = run
            }
        }
        return nil
    }

    /// The runs of `char` in `range`.
    private static func runs(of char: unichar, in ns: NSString, range: NSRange) -> [NSRange] {
        var runs: [NSRange] = []
        var i = range.location
        while i < NSMaxRange(range) {
            guard ns.character(at: i) == char else { i += 1; continue }
            let start = i
            while i < NSMaxRange(range), ns.character(at: i) == char { i += 1 }
            runs.append(NSRange(location: start, length: i - start))
        }
        return runs
    }

    private static func isSpace(_ unit: unichar) -> Bool {
        Unicode.Scalar(unit).map { CharacterSet.whitespacesAndNewlines.contains($0) } ?? false
    }

    private static func isWordCharacter(_ unit: unichar) -> Bool {
        Unicode.Scalar(unit).map { CharacterSet.alphanumerics.contains($0) } ?? false
    }
}
