import AppKit
import JotCore

/// Styles the editor's text as Markdown without changing a character: markers
/// stay visible but dimmed. Restyles only the lines an edit touched (plus the
/// next one), the frontmatter block, and everything when frontmatter appears
/// or disappears. The Title line gets no special look: only `#` makes a heading.
///
/// Colours are dynamic system colours, so light/dark switching needs no code.
final class MarkdownStyler: NSObject, NSTextStorageDelegate {
    var baseSize: CGFloat = 14
    /// Settings > Editor > Line Spacing (ticket 33).
    var lineSpacing = LineSpacing.normal

    private var lastFrontmatter: NSRange?

    var baseAttributes: [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing.points(fontSize: baseSize)
        return [.font: NSFont.systemFont(ofSize: baseSize), .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph]
    }

    func textStorage(
        _ storage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions,
        range editedRange: NSRange, changeInLength delta: Int
    ) {
        guard editedMask.contains(.editedCharacters) else { return }
        let text = storage.string
        let length = (text as NSString).length
        let frontmatter = MarkdownEditing.frontmatterRange(in: text)

        var target = editedRange
        if (frontmatter == nil) != (lastFrontmatter == nil) {
            // A block appeared or disappeared: every line's role may have changed.
            target = NSRange(location: 0, length: length)
        } else if let frontmatter {
            target = NSUnionRange(target, frontmatter)
        }
        lastFrontmatter = frontmatter
        style(storage, range: clamp(target, to: length), frontmatter: frontmatter)
    }

    /// Restyles everything, e.g. after the font size changed.
    func restyleAll(_ storage: NSTextStorage) {
        lastFrontmatter = MarkdownEditing.frontmatterRange(in: storage.string)
        style(storage, range: NSRange(location: 0, length: storage.length), frontmatter: lastFrontmatter)
    }

    // MARK: Styling

    private func style(_ storage: NSTextStorage, range: NSRange, frontmatter: NSRange?) {
        let ns = storage.string as NSString
        var lines = ns.lineRange(for: range)
        // A blank line's gap styling depends on the line before it, so the line
        // after an edit is restyled too.
        if NSMaxRange(lines) < ns.length {
            lines = NSUnionRange(lines, ns.lineRange(for: NSRange(location: NSMaxRange(lines), length: 0)))
        }
        guard lines.length > 0 else { return }
        storage.setAttributes(baseAttributes, range: lines)

        let isInFrontmatter = { (r: NSRange) in frontmatter.map { NSIntersectionRange($0, r).length > 0 } ?? false }
        let spans = MarkdownStyle.spans(in: storage.string, range: lines).filter { !isInFrontmatter($0.range) }

        // Line size first (headings), then traits, then markers on top.
        for span in spans {
            if case .heading(let level) = span.kind {
                storage.addAttribute(.font, value: NSFont.systemFont(ofSize: headingSize(level), weight: .bold), range: span.range)
            }
        }
        for span in spans {
            switch span.kind {
            case .quote:
                storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: span.range)
            case .bold:
                addTraits(.bold, to: storage, range: span.range)
            case .italic:
                addTraits(.italic, to: storage, range: span.range)
            case .strikethrough, .completedTask:
                storage.addAttributes([.strikethroughStyle: NSUnderlineStyle.single.rawValue,
                                       .foregroundColor: NSColor.secondaryLabelColor], range: span.range)
            case .code:
                setMonospaced(storage, range: span.range)
                storage.addAttribute(.backgroundColor, value: NSColor.quaternarySystemFill, range: span.range)
            case .link:
                storage.addAttribute(.foregroundColor, value: NSColor.linkColor, range: span.range)
            case .paragraphGap:
                // No height: the next paragraph sits right below, exactly as after
                // Shift-Return (decided 2026-10-09, ticket 23). Neither the font
                // (size 0 would mean the default size) nor the editor's 2 pt line
                // spacing may add any.
                let gap = NSMutableParagraphStyle()
                gap.lineSpacing = 0
                gap.maximumLineHeight = 0.01
                storage.addAttributes([.font: NSFont.systemFont(ofSize: 1), .paragraphStyle: gap], range: span.range)
            case .checkbox(let checked):
                // The characters stay (they're the file's text) but are invisible:
                // `EditorLayoutManager` draws a box over them.
                setMonospaced(storage, range: span.range)
                storage.addAttributes([.foregroundColor: NSColor.clear, .checkbox: checked], range: span.range)
            case .heading, .marker:
                break
            }
        }
        for span in spans where span.kind == .marker {
            // The space after `##` or `-` stays proportional; a monospaced one looks too wide.
            let marker = (ns.substring(with: span.range) as NSString)
                .trimmingCharacters(in: .whitespaces) as NSString
            setMonospaced(storage, range: NSRange(location: span.range.location, length: marker.length))
            storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: span.range)
        }
        if let frontmatter, NSIntersectionRange(frontmatter, lines).length > 0 {
            let range = NSIntersectionRange(frontmatter, lines)
            setMonospaced(storage, range: range)
            storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: range)
        }
    }

    private func headingSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: baseSize * 1.6
        case 2: baseSize * 1.35
        case 3: baseSize * 1.15
        default: baseSize
        }
    }

    private func addTraits(_ traits: NSFontDescriptor.SymbolicTraits, to storage: NSTextStorage, range: NSRange) {
        storage.enumerateAttribute(.font, in: range) { value, subrange, _ in
            guard let font = value as? NSFont else { return }
            let descriptor = font.fontDescriptor.withSymbolicTraits(font.fontDescriptor.symbolicTraits.union(traits))
            storage.addAttribute(.font, value: NSFont(descriptor: descriptor, size: font.pointSize) ?? font, range: subrange)
        }
    }

    /// SF Mono at the size the text already has (so markers in a heading stay heading-sized).
    private func setMonospaced(_ storage: NSTextStorage, range: NSRange) {
        storage.enumerateAttribute(.font, in: range) { value, subrange, _ in
            let size = (value as? NSFont)?.pointSize ?? baseSize
            storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: size, weight: .regular), range: subrange)
        }
    }

    private func clamp(_ range: NSRange, to length: Int) -> NSRange {
        let location = min(max(range.location, 0), length)
        return NSRange(location: location, length: min(range.length, length - location))
    }
}
