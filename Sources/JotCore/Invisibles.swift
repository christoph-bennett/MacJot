import Foundation

/// Show Invisibles (ticket 34): the faint symbol drawn for each invisible
/// character. Only drawn, never part of the text. Positions are UTF-16 offsets.
public enum Invisibles {
    public enum Symbol: String, Sendable {
        case space = "·"
        case tab = "→"
        /// A single line break (Shift-Return).
        case lineBreak = "¬"
        /// A paragraph's end: the break before a paragraph gap (ADR 0004). The
        /// gap's own break gets nothing; the gap is drawn without height.
        case paragraphEnd = "¶"
    }

    /// The invisible characters in `range` and their symbols, in order.
    public static func symbols(in text: String, range: NSRange) -> [(location: Int, symbol: Symbol)] {
        let ns = text as NSString
        let blocks = MarkdownStyle.codeBlocks(in: text)
        var found: [(location: Int, symbol: Symbol)] = []
        for location in range.location..<min(NSMaxRange(range), ns.length) {
            switch ns.character(at: location) {
            case 0x20: found.append((location, .space))
            case 0x09: found.append((location, .tab))
            case 0x0A:
                if MarkdownStyle.isParagraphGap(at: location, in: text, codeBlocks: blocks) { continue }  // the gap's own break
                let isBeforeGap = location + 1 < ns.length
                    && MarkdownStyle.isParagraphGap(at: location + 1, in: text, codeBlocks: blocks)
                found.append((location, isBeforeGap ? .paragraphEnd : .lineBreak))
            default: continue
            }
        }
        return found
    }
}
