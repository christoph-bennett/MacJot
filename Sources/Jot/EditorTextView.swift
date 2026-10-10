import AppKit
import JotCore

extension NSAttributedString.Key {
    /// On a checklist item's `[ ]` / `[x]`: whether it's checked. Set by
    /// `MarkdownStyler`, drawn by `EditorLayoutManager`, clicked in `EditorTextView`.
    static let checkbox = NSAttributedString.Key("JotCheckbox")
}

/// The editor's text view: a click on a checklist box toggles it instead of
/// placing the cursor. Like a button, the toggle happens when the mouse is
/// released on the box; a press that drags away selects text as usual.
final class EditorTextView: NSTextView {
    /// A box was clicked; the index is its first character (`[`).
    var onCheckboxClick: (Int) -> Void = { _ in }

    /// Overrides the left inset while the line numbers show: the text then
    /// starts just after the gutter's separator (the container's 5 pt line
    /// padding), not a whole inset further. The right inset stays: the container
    /// is narrowed only by the left side's change.
    var leadingInset: CGFloat? {
        didSet {
            guard leadingInset != oldValue else { return }
            let standard = standardInsetWidth ?? textContainerInset.width
            standardInsetWidth = standard
            // NSTextView insets both sides by `width`; the origin override moves the left edge.
            textContainerInset.width = leadingInset.map { (standard + $0) / 2 } ?? standard
            invalidateTextContainerOrigin()
            needsDisplay = true
        }
    }
    private var standardInsetWidth: CGFloat?

    /// Dimmed text on the first line while the Note is blank, e.g. that leaving
    /// it empty trashes it (ticket 25). Drawn, not part of the text.
    var hint: String? {
        didSet { if hint != oldValue { needsDisplay = true } }
    }

    /// A faint band behind the line with the cursor, all its wrapped rows (ticket 29).
    var highlightsCurrentLine = false {
        didSet {
            guard highlightsCurrentLine != oldValue else { return }
            bandRect = currentLineRect()
            needsDisplay = true
        }
    }
    /// Where the band was last drawn, to redraw there when the cursor moves away.
    private var bandRect: NSRect?
    /// Faint enough not to compete with the text or the find highlights. The
    /// label colour, so it follows light and dark; a dark background needs more
    /// of it to show at all.
    private static let bandColor = NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return NSColor.labelColor.withAlphaComponent(isDark ? 0.1 : 0.05)
    }

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting: Bool) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelecting)
        guard highlightsCurrentLine else { return }
        let band = currentLineRect()
        guard band != bandRect else { return }
        if let bandRect { setNeedsDisplay(bandRect) }
        if let band { setNeedsDisplay(band) }
        bandRect = band
    }

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        // Measured afresh: resizing or restyling may have rewrapped the line
        // (and redraws the whole view anyway).
        guard let band = currentLineRect() else { return }
        bandRect = band
        Self.bandColor.setFill()
        band.intersection(rect).fill(using: .sourceOver)
    }

    /// The band: every row of the cursor's line, across the whole width. Nil
    /// while it's off or text is selected.
    private func currentLineRect() -> NSRect? {
        guard highlightsCurrentLine, selectedRanges.count == 1, let layoutManager, let textContainer,
              let line = CurrentLine.range(in: string, selection: selectedRange()) else { return nil }
        var rows: NSRect
        if line.length == 0 {
            // The empty last line after a final break (or of an empty Note) has no glyphs.
            guard layoutManager.extraLineFragmentTextContainer != nil else { return nil }
            rows = layoutManager.extraLineFragmentRect
        } else {
            let glyphs = layoutManager.glyphRange(forCharacterRange: line, actualCharacterRange: nil)
            rows = layoutManager.boundingRect(forGlyphRange: glyphs, in: textContainer)
            layoutManager.enumerateLineFragments(forGlyphRange: glyphs) { rect, _, _, _, _ in
                rows = rows.union(rect)
            }
        }
        return NSRect(x: bounds.minX, y: rows.minY + textContainerOrigin.y, width: bounds.width, height: rows.height)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let hint, let textContainer else { return }
        let padding = textContainer.lineFragmentPadding
        let origin = textContainerOrigin
        let rect = NSRect(x: origin.x + padding, y: origin.y,
                          width: textContainer.size.width - 2 * padding, height: bounds.height - origin.y)
        let font = typingAttributes[.font] as? NSFont ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
        (hint as NSString).draw(in: rect, withAttributes: [.font: font, .foregroundColor: NSColor.placeholderTextColor])
    }

    override var textContainerOrigin: NSPoint {
        var origin = super.textContainerOrigin
        if let leadingInset { origin.x = leadingInset }
        return origin
    }

    override func mouseDown(with event: NSEvent) {
        guard event.modifierFlags.intersection([.shift, .command, .option, .control]).isEmpty,
              let box = checkbox(at: convert(event.locationInWindow, from: nil)) else {
            return super.mouseDown(with: event)
        }
        // A double or triple click on a box: the first click toggled it, the rest
        // shouldn't select text.
        guard event.clickCount == 1 else { return }
        while let next = window?.nextEvent(matching: [.leftMouseUp, .leftMouseDragged]) {
            let point = convert(next.locationInWindow, from: nil)
            if next.type == .leftMouseUp {
                if checkbox(at: point) == box { onCheckboxClick(box) }
                return
            }
            if checkbox(at: point) != box {
                return super.mouseDown(with: event)  // dragged off the box: select text from where it started
            }
        }
    }

    /// The first character of the box under `point`, if there is one.
    private func checkbox(at point: NSPoint) -> Int? {
        guard let layoutManager, let textContainer, let storage = textStorage, storage.length > 0 else { return nil }
        let inContainer = NSPoint(x: point.x - textContainerOrigin.x, y: point.y - textContainerOrigin.y)
        let glyph = layoutManager.glyphIndex(for: inContainer, in: textContainer)
        let index = layoutManager.characterIndexForGlyph(at: glyph)
        guard index < storage.length, let range = storage.checkboxRange(at: index) else { return nil }
        let glyphs = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        let rect = layoutManager.boundingRect(forGlyphRange: glyphs, in: textContainer)
        return rect.contains(inContainer) ? range.location : nil
    }
}

extension NSAttributedString {
    /// The whole `[ ]` / `[x]` the character at `index` belongs to, if any.
    func checkboxRange(at index: Int) -> NSRange? {
        guard index >= 0, index < length else { return nil }
        var range = NSRange()
        let value = attribute(.checkbox, at: index, longestEffectiveRange: &range,
                              in: NSRange(location: 0, length: length))
        return value == nil ? nil : range
    }
}

/// Draws a checkbox symbol over each checklist item's (invisible) `[ ]` / `[x]`:
/// an empty square, or a filled one with a checkmark in the accent colour. With
/// `showsInvisibles`, also faint symbols for spaces, tabs and line breaks.
final class EditorLayoutManager: NSLayoutManager {
    /// Settings > Editor / View > Show Invisibles (ticket 34).
    var showsInvisibles = false

    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
        guard let storage = textStorage, let container = textContainers.first else { return }
        let characters = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        if showsInvisibles { drawInvisibles(in: characters, of: storage, at: origin) }
        storage.enumerateAttribute(.checkbox, in: characters) { value, part, _ in
            // The whole box, even when only part of it is being redrawn.
            guard let checked = value as? Bool, let range = storage.checkboxRange(at: part.location) else { return }
            let font = storage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
            let glyphs = glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            let bounds = boundingRect(forGlyphRange: glyphs, in: container).offsetBy(dx: origin.x, dy: origin.y)
            drawBox(checked: checked, in: bounds, pointSize: font?.pointSize ?? 14)
        }
    }

    /// Each symbol in the character's own font, where the character is: centred
    /// over a space or tab, just after the line's text for a break. Not over a
    /// checklist box's hidden `[ ]`, whose space isn't one the user typed.
    private func drawInvisibles(in characters: NSRange, of storage: NSTextStorage, at origin: NSPoint) {
        for (location, symbol) in Invisibles.symbols(in: storage.string, range: characters) {
            guard storage.attribute(.checkbox, at: location, effectiveRange: nil) == nil else { continue }
            let glyph = glyphIndexForCharacter(at: location)
            let fragment = lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            let glyphPoint = self.location(forGlyphAt: glyph)
            let font = storage.attribute(.font, at: location, effectiveRange: nil) as? NSFont
                ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.tertiaryLabelColor]
            let string = symbol.rawValue as NSString
            var x = origin.x + fragment.minX + glyphPoint.x
            if symbol == .space || symbol == .tab {
                let width = boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: textContainers[0]).width
                x += (width - string.size(withAttributes: attributes).width) / 2
            }
            let baseline = origin.y + fragment.minY + glyphPoint.y
            string.draw(at: NSPoint(x: x, y: baseline - font.ascender), withAttributes: attributes)
        }
    }

    /// Symbol images by checked state and point size. Their palette colours are
    /// dynamic, so the cached images still follow light/dark.
    private var images: [String: NSImage] = [:]

    private func drawBox(checked: Bool, in bounds: NSRect, pointSize: CGFloat) {
        let key = "\(checked)-\(pointSize)"
        if images[key] == nil {
            let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
                .applying(checked ? .init(paletteColors: [.white, .controlAccentColor])
                                  : .init(paletteColors: [.secondaryLabelColor]))
            images[key] = NSImage(systemSymbolName: checked ? "checkmark.square.fill" : "square",
                                  accessibilityDescription: checked ? "Checked" : "Unchecked")?
                .withSymbolConfiguration(config)
        }
        guard let image = images[key] else { return }
        let size = image.size
        let rect = NSRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2,
                          width: size.width, height: size.height)
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }
}
