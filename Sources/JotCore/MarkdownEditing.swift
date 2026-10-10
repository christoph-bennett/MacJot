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
    /// In a list item Return continues the list (next number, unchecked box), and
    /// on an empty item it removes the marker, ending the list.
    public static func newline(in text: String, selection: NSRange, soft: Bool) -> TextEdit {
        let ns = text as NSString
        let line = ns.lineRange(for: NSRange(location: selection.location, length: 0))
        let beforeCursor = ns.substring(with: NSRange(location: line.location, length: selection.location - line.location))

        let inCodeOrFrontmatter = isInFrontmatter(ns, location: selection.location) || isInCodeFence(ns, throughLine: line)
        let lineText = ns.substring(with: NSRange(location: line.location, length: lineContentEnd(ns, line) - line.location))
        let prefix = LinePrefix(lineText)
        let isListItem = prefix.continuation != nil && !isIndentedCode(ns, line: line, prefix: prefix)

        // In a list item (with the cursor past its marker), Return continues the
        // list; on an empty item it ends it.
        if !soft, !inCodeOrFrontmatter, isListItem, selection.location - line.location >= prefix.length,
           let continuation = prefix.continuation {
            let item = (lineText as NSString).substring(from: prefix.length)
            if item.trimmingCharacters(in: .whitespaces).isEmpty, selection.length == 0 {
                return TextEdit(range: NSRange(location: line.location, length: (lineText as NSString).length),
                                replacement: "", selection: NSRange(location: line.location, length: 0))
            }
            return TextEdit(range: selection, replacement: "\n" + continuation,
                            selection: NSRange(location: selection.location + 1 + (continuation as NSString).length, length: 0))
        }

        let single = soft
            || beforeCursor.trimmingCharacters(in: .whitespaces).isEmpty
            || isListItem
            || beforeCursor.prefixMatch(of: /^\s*(?:>|\|)/) != nil  // quote, table
            || beforeCursor.hasPrefix("    ") || beforeCursor.hasPrefix("\t")         // indented code
            || inCodeOrFrontmatter
        if single {
            // On an empty line right after text, one break would turn that line
            // into a paragraph gap, which has no height (ticket 23): nothing would
            // seem to happen. A second break makes the empty line appear.
            let result = ns.replacingCharacters(in: selection, with: "\n")
            let breaks = !inCodeOrFrontmatter && MarkdownStyle.isParagraphGap(at: selection.location, in: result)
                ? "\n\n" : "\n"
            return TextEdit(range: selection, replacement: breaks,
                            selection: NSRange(location: selection.location + (breaks as NSString).length, length: 0))
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

    /// Backspace right after a paragraph break (ADR 0004) removes the whole break,
    /// so Return then Backspace leaves the text as it was, and Backspace at the
    /// start of a paragraph joins it to the one above. `nil` where the text view's
    /// own deletion applies: a selection, single line breaks, further blank lines,
    /// code and frontmatter.
    public static func deleteBackward(in text: String, selection: NSRange) -> TextEdit? {
        let ns = text as NSString
        let location = selection.location
        guard selection.length == 0, location >= 3,
              ns.character(at: location - 1) == 0x0A, ns.character(at: location - 2) == 0x0A,
              ns.character(at: location - 3) != 0x0A,
              !isInFrontmatter(ns, location: location),
              !isInCodeFence(ns, throughLine: ns.lineRange(for: NSRange(location: location, length: 0)))
        else { return nil }
        let above = ns.lineRange(for: NSRange(location: location - 2, length: 0))
        guard !ns.substring(with: above).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return TextEdit(range: NSRange(location: location - 2, length: 2), replacement: "",
                        selection: NSRange(location: location - 2, length: 0))
    }

    /// Ticks or unticks the checklist box at `location` (any of its `[`, mark or
    /// `]`): `[ ]` ↔ `[x]`. The selection is passed through unchanged, so a click
    /// doesn't move the cursor. `nil` if there's no box there: boxes are exactly
    /// where the editor draws them (`MarkdownStyle`'s checkbox spans).
    public static func toggleCheckbox(in text: String, at location: Int, selection: NSRange) -> TextEdit? {
        let ns = text as NSString
        guard location < ns.length else { return nil }
        let line = ns.lineRange(for: NSRange(location: location, length: 0))
        guard !isInCodeFence(ns, throughLine: line) else { return nil }  // code is literal
        for span in MarkdownStyle.spans(in: text, range: line) {
            guard case .checkbox(let checked) = span.kind, NSLocationInRange(location, span.range) else { continue }
            return TextEdit(range: NSRange(location: span.range.location + 1, length: 1),
                            replacement: checked ? " " : "x", selection: selection)
        }
        return nil
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

    /// A line indented by a tab or four spaces is code, unless it continues a
    /// list on the line above (a nested item).
    private static func isIndentedCode(_ ns: NSString, line: NSRange, prefix: LinePrefix) -> Bool {
        guard prefix.indent.hasPrefix("\t") || prefix.indent.hasPrefix("    ") else { return false }
        guard line.location > 0 else { return true }
        let above = ns.lineRange(for: NSRange(location: line.location - 1, length: 0))
        let aboveText = ns.substring(with: NSRange(location: above.location, length: lineContentEnd(ns, above) - above.location))
        return LinePrefix(aboveText).continuation == nil
    }

    private static func isInFrontmatter(_ ns: NSString, location: Int) -> Bool {
        switch NoteStructure(ns).frontmatter {
        case .none: false
        case .open: true
        case .closed(let range): location <= NSMaxRange(range)  // incl. right after the closing fence
        }
    }

    /// The Formatting Toolbar's Code Block (ticket 35): if the selection's lines
    /// touch a fenced block, removes its fences; on an empty line, inserts an
    /// empty block with the cursor in it; otherwise wraps the selection's lines
    /// (or the cursor's) in fences. The selection stays on the same text.
    public static func toggleCodeBlock(in text: String, selection: NSRange) -> TextEdit {
        let ns = text as NSString
        var lines = ns.lineRange(for: selection)
        if selection.length > 0, NSMaxRange(selection) == NSMaxRange(lines), NSMaxRange(selection) < ns.length {
            // A selection ending at a line's start doesn't take that line.
            lines = ns.lineRange(for: NSRange(location: selection.location, length: selection.length - 1))
        }
        if let block = MarkdownStyle.codeBlocks(in: text).first(where: {
            NSIntersectionRange($0, lines).length > 0 || (selection.location == ns.length && NSMaxRange($0) == ns.length)
        }) {
            return unwrap(block, in: ns, selection: selection)
        }
        let contentEnd = lineContentEnd(ns, ns.lineRange(for: NSRange(location: max(NSMaxRange(lines) - 1, lines.location), length: 0)))
        let content = NSRange(location: lines.location, length: max(contentEnd - lines.location, 0))
        let body = ns.substring(with: content)
        if selection.length == 0, body.trimmingCharacters(in: .whitespaces).isEmpty {
            return TextEdit(range: content, replacement: "```\n\n```",
                            selection: NSRange(location: content.location + 4, length: 0))
        }
        return TextEdit(range: content, replacement: "```\n" + body + "\n```",
                        selection: NSRange(location: selection.location + 4, length: selection.length))
    }

    /// `block` without its fence lines; positions in the fences end up at the
    /// nearest edge of what's left, positions after the block move up with it.
    private static func unwrap(_ block: NSRange, in ns: NSString, selection: NSRange) -> TextEdit {
        let fences = MarkdownStyle.fenceLines(ns, in: block)
        let opening = ns.lineRange(for: NSRange(location: block.location, length: 0))
        let innerEnd = fences.count > 1 ? fences[1].location : NSMaxRange(block)
        var inner = ns.substring(with: NSRange(location: NSMaxRange(opening), length: max(innerEnd - NSMaxRange(opening), 0)))
        // The closing fence was the text's last line: the break before it goes with it.
        if fences.count > 1, NSMaxRange(block) == ns.length, !ns.substring(with: block).hasSuffix("\n"), inner.hasSuffix("\n") {
            inner.removeLast()
        }
        let innerLength = (inner as NSString).length
        func map(_ position: Int) -> Int {
            if position <= block.location { return position }
            if position >= NSMaxRange(block) { return position + innerLength - block.length }
            return min(max(position - opening.length, block.location), block.location + innerLength)
        }
        let start = map(selection.location), end = map(NSMaxRange(selection))
        return TextEdit(range: block, replacement: inner, selection: NSRange(location: start, length: max(end - start, 0)))
    }

    /// Inside a fenced code block (`MarkdownStyle.codeBlocks`): its opening fence
    /// line counts as inside, its closing one not, as Return after it starts
    /// normal text again.
    private static func isInCodeFence(_ ns: NSString, throughLine line: NSRange) -> Bool {
        guard let block = MarkdownStyle.codeBlocks(in: ns as String).first(where: { NSLocationInRange(line.location, $0) })
        else { return false }
        let fences = MarkdownStyle.fenceLines(ns, in: block)
        return !(fences.count > 1 && fences[1].location == line.location)
    }

    /// End of the line's text, before its line break.
    private static func lineContentEnd(_ ns: NSString, _ line: NSRange) -> Int {
        var contents = 0
        var end = 0
        ns.getLineStart(nil, end: &end, contentsEnd: &contents, for: NSRange(location: line.location, length: 0))
        return contents
    }
}
