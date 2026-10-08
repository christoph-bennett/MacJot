import Foundation

/// A text change for the editor to apply: replace `range` with `replacement`,
/// then select `selection`. Ranges are UTF-16 offsets, as in `NSTextView`.
public struct TextEdit: Equatable {
    public var range: NSRange
    public var replacement: String
    public var selection: NSRange
}

/// Editing commands: pure functions over (text, selection), no AppKit.
public enum MarkdownEditing {
    /// Return and Shift-Return (ADR 0004). Return starts a new paragraph: a blank
    /// line, so renderers that join single line breaks still show separate lines.
    /// It inserts a single line break instead when `soft` (Shift-Return), when the
    /// cursor is at the start of a line or on a blank line, and where blank lines
    /// would change the meaning: list items, quotes, frontmatter, code, tables.
    public static func newline(in text: String, selection: NSRange, soft: Bool) -> TextEdit {
        let ns = text as NSString
        let line = ns.lineRange(for: NSRange(location: selection.location, length: 0))
        let beforeCursor = ns.substring(with: NSRange(location: line.location, length: selection.location - line.location))

        let single = soft
            || beforeCursor.trimmingCharacters(in: .whitespaces).isEmpty
            || beforeCursor.prefixMatch(of: /^\s*(?:>|[-*+]\s|\d+[.)]\s|\|)/) != nil  // list, quote, table
            || beforeCursor.hasPrefix("    ") || beforeCursor.hasPrefix("\t")         // indented code
            || isInFrontmatter(ns, location: selection.location)
            || isInCodeFence(ns, throughLine: line)
        if single {
            return TextEdit(range: selection, replacement: "\n",
                            selection: NSRange(location: selection.location + 1, length: 0))
        }

        // The new paragraph shouldn't start with the spaces that followed the cursor.
        var range = selection
        while NSMaxRange(range) < ns.length, [0x20, 0x09].contains(ns.character(at: NSMaxRange(range))) {
            range.length += 1
        }
        // At the end of a line that continues on the next one (a soft break), the
        // new paragraph needs a blank line below it too, or it joins that line.
        var replacement = "\n\n"
        if NSMaxRange(range) >= lineContentEnd(ns, line), NSMaxRange(line) < ns.length {
            let next = ns.lineRange(for: NSRange(location: NSMaxRange(line), length: 0))
            if !ns.substring(with: next).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                replacement = "\n\n\n"
            }
        }
        return TextEdit(range: range, replacement: replacement,
                        selection: NSRange(location: range.location + 2, length: 0))
    }

    /// The UTF-16 range of the Title line (without its line break), if there is a Title.
    public static func titleLineRange(in text: String) -> NSRange? {
        NoteStructure(text as NSString).titleLine
    }

    /// The UTF-16 range of a closed leading frontmatter block, both `---` fences included.
    public static func frontmatterRange(in text: String) -> NSRange? {
        guard case .closed(let range) = NoteStructure(text as NSString).frontmatter else { return nil }
        return range
    }

    // MARK: Helpers

    private static func isInFrontmatter(_ ns: NSString, location: Int) -> Bool {
        switch NoteStructure(ns).frontmatter {
        case .none: false
        case .open: true
        case .closed(let range): location <= NSMaxRange(range)  // incl. right after the closing fence
        }
    }

    /// Inside a ``` or ~~~ fenced code block: an odd number of fence lines up to
    /// and including this one (so an opening fence line counts as inside).
    private static func isInCodeFence(_ ns: NSString, throughLine line: NSRange) -> Bool {
        var fences = 0
        ns.enumerateSubstrings(in: NSRange(location: 0, length: NSMaxRange(line)), options: .byLines) { text, _, _, _ in
            let trimmed = (text ?? "").trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") { fences += 1 }
        }
        return fences % 2 == 1
    }

    /// End of the line's text, before its line break.
    private static func lineContentEnd(_ ns: NSString, _ line: NSRange) -> Int {
        var contents = 0
        var end = 0
        ns.getLineStart(nil, end: &end, contentsEnd: &contents, for: NSRange(location: line.location, length: 0))
        return contents
    }
}
