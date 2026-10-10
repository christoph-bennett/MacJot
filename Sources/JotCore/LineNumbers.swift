import Foundation

/// Where each line of a Note's file starts, for the editor's line numbers.
/// Lines are the file's: every line break starts one (a trailing break starts
/// an empty last line); how the editor wraps a line doesn't matter. A paragraph
/// gap, the blank line Return puts between paragraphs (ADR 0004), takes
/// practically no space in the editor, so it gets no number and isn't counted.
/// Positions are UTF-16 offsets, as in `NSString` and the text view.
public struct LineNumbers {
    /// The start of every line, ascending.
    private let starts: [Int]
    /// Each line's number, nil for a paragraph gap.
    private let numbers: [Int?]

    public init(_ text: String) {
        let ns = text as NSString
        var starts = [0]
        var location = 0
        while location < ns.length {
            var end = 0
            ns.getLineStart(nil, end: &end, contentsEnd: nil, for: NSRange(location: location, length: 0))
            guard end > location else { break }
            // `end` is past the line break; after the last line without one it's the text's end.
            if end < ns.length || Self.endsWithBreak(ns) { starts.append(end) }
            location = end
        }
        self.starts = starts
        var next = 1
        let blocks = MarkdownStyle.codeBlocks(in: text)
        numbers = starts.map { start in
            // The empty last line is never a gap: the cursor goes there after Return.
            let line = ns.lineRange(for: NSRange(location: start, length: 0))
            let isGap = start < ns.length
                && ns.substring(with: line).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && MarkdownStyle.isParagraphGap(ns, blankLine: line, codeBlocks: blocks)
            if isGap { return nil }
            defer { next += 1 }
            return next
        }
    }

    /// The highest number shown.
    public var count: Int { numbers.last { $0 != nil }.flatMap { $0 } ?? 0 }

    /// The 1-based number of the line that starts at `offset`, or nil if no
    /// line starts there or it's a paragraph gap.
    public func number(ofLineStartingAt offset: Int) -> Int? {
        var low = 0, high = starts.count - 1
        while low <= high {
            let middle = (low + high) / 2
            if starts[middle] == offset { return numbers[middle] }
            if starts[middle] < offset { low = middle + 1 } else { high = middle - 1 }
        }
        return nil
    }

    private static func endsWithBreak(_ ns: NSString) -> Bool {
        guard ns.length > 0 else { return false }
        var contentsEnd = 0, end = 0
        ns.getLineStart(nil, end: &end, contentsEnd: &contentsEnd, for: NSRange(location: ns.length - 1, length: 0))
        return contentsEnd < end
    }
}
