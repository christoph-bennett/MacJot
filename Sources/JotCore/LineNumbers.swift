import Foundation

/// Where each line of a Note's file starts, for the editor's line numbers.
/// Lines are the file's: every line break starts one (so the blank lines
/// between paragraphs count, and a trailing break starts an empty last line);
/// how the editor wraps a line doesn't matter. Positions are UTF-16 offsets,
/// as in `NSString` and the text view.
public struct LineNumbers {
    /// The start of every line, ascending.
    private let starts: [Int]

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
    }

    public var count: Int { starts.count }

    /// The 1-based number of the line that starts at `offset`, or nil if no
    /// line starts there.
    public func number(ofLineStartingAt offset: Int) -> Int? {
        var low = 0, high = starts.count - 1
        while low <= high {
            let middle = (low + high) / 2
            if starts[middle] == offset { return middle + 1 }
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
