import AppKit

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
/// an empty square, or a filled one with a checkmark in the accent colour.
final class EditorLayoutManager: NSLayoutManager {
    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
        guard let storage = textStorage, let container = textContainers.first else { return }
        let characters = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        storage.enumerateAttribute(.checkbox, in: characters) { value, part, _ in
            // The whole box, even when only part of it is being redrawn.
            guard let checked = value as? Bool, let range = storage.checkboxRange(at: part.location) else { return }
            let font = storage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
            let glyphs = glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            let bounds = boundingRect(forGlyphRange: glyphs, in: container).offsetBy(dx: origin.x, dy: origin.y)
            drawBox(checked: checked, in: bounds, pointSize: font?.pointSize ?? 14)
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
