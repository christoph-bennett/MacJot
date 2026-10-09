import AppKit
import JotCore

/// The editor's line numbers: a ruler beside the text view, scrolling with it.
/// One number per line of the file, on the baseline of the line's first row;
/// rows a long line wraps onto get none. The look follows ticket 16 (modelled
/// on STTextView's gutter, GPL: design only, our own code).
final class LineNumberGutter: NSRulerView {
    private static let minimumWidth: CGFloat = 35
    private static let leftInset: CGFloat = 4
    /// Between a number and the separator.
    private static let numberGap: CGFloat = 6

    private weak var textView: NSTextView?
    /// The text's lines; recounted after an edit.
    private var lines: LineNumbers?
    private var digits = 1

    /// The editor's text size; the numbers are 2 pt smaller.
    var fontSize: CGFloat = 14 {
        didSet {
            guard fontSize != oldValue else { return }
            numberFont = Self.numberFont(size: fontSize)
            updateWidth(force: true)
            needsDisplay = true
        }
    }
    private var numberFont = LineNumberGutter.numberFont(size: 14)

    init(textView: NSTextView, scrollView: NSScrollView) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        reservedThicknessForMarkers = 0
        reservedThicknessForAccessoryView = 0
        ruleThickness = Self.minimumWidth
        // Views don't clip by default (macOS 14+), and the scroll view asks the
        // ruler to draw areas as wide as the editor: the background would cover the text.
        clipsToBounds = true

        let center = NotificationCenter.default
        // Every edit, also replacing the whole text and restyling.
        center.addObserver(self, selector: #selector(textDidChange),
                           name: NSTextStorage.didProcessEditingNotification, object: textView.textStorage)
        // Resizing rewraps lines; scrolling shows others.
        textView.postsFrameChangedNotifications = true
        center.addObserver(self, selector: #selector(redraw), name: NSView.frameDidChangeNotification, object: textView)
        scrollView.contentView.postsBoundsChangedNotifications = true
        center.addObserver(self, selector: #selector(redraw), name: NSView.boundsDidChangeNotification,
                           object: scrollView.contentView)
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("not used from nibs") }

    override var isFlipped: Bool { true }

    /// Mid-edit (the text storage is still processing it): the width is updated
    /// a moment later, as re-tiling resizes the text view.
    @objc private func textDidChange() {
        lines = nil
        guard scrollView?.rulersVisible == true else { return }  // nothing to show
        needsDisplay = true
        DispatchQueue.main.async { [weak self] in self?.updateWidth(force: false) }
    }

    /// Shown again (Settings): edits while hidden weren't followed.
    func refresh() {
        updateWidth(force: false)
        needsDisplay = true
    }

    @objc private func redraw() {
        needsDisplay = true
    }

    private var currentLines: LineNumbers {
        if let lines { return lines }
        let counted = LineNumbers(textView?.string ?? "")
        lines = counted
        return counted
    }

    /// Wider only when the numbers gain a digit (99 → 100), never per keystroke otherwise.
    private func updateWidth(force: Bool) {
        let digits = String(currentLines.count).count
        guard force || digits != self.digits else { return }
        self.digits = digits
        let widest = (String(repeating: "8", count: digits) as NSString).size(withAttributes: [.font: numberFont]).width
        let width = max(Self.minimumWidth, ceil(Self.leftInset + widest + Self.numberGap + 1))
        if width != ruleThickness {
            ruleThickness = width
            scrollView?.tile()
        }
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {}

    override func draw(_ dirtyRect: NSRect) {
        guard let textView, let layoutManager = textView.layoutManager, let container = textView.textContainer else { return }
        // The text's own background: no separate band.
        textView.backgroundColor.setFill()
        dirtyRect.intersection(bounds).fill()
        // A barely-there hairline at the right edge, on whole points.
        NSColor.separatorColor.withAlphaComponent(0.1).setFill()
        NSRect(x: floor(bounds.maxX) - 1, y: dirtyRect.minY, width: 1, height: dirtyRect.height).fill()

        let lines = currentLines
        let origin = textView.textContainerOrigin
        let visible = textView.visibleRect.offsetBy(dx: -origin.x, dy: -origin.y)
        let glyphs = layoutManager.glyphRange(forBoundingRect: visible, in: container)
        var index = glyphs.location
        while index < NSMaxRange(glyphs) {
            var row = NSRange()
            let rect = layoutManager.lineFragmentRect(forGlyphAt: index, effectiveRange: &row)
            let character = layoutManager.characterIndexForGlyph(at: row.location)
            if let number = lines.number(ofLineStartingAt: character) {
                let baseline = rect.minY + layoutManager.location(forGlyphAt: row.location).y
                draw(number, baselineInText: baseline + origin.y, in: textView)
            }
            index = NSMaxRange(row)
        }
        // The empty last line after a final line break (or of an empty Note) has no glyphs.
        if layoutManager.extraLineFragmentTextContainer != nil,
           let number = lines.number(ofLineStartingAt: textView.textStorage?.length ?? 0) {
            let rect = layoutManager.extraLineFragmentRect
            // Laid out with the typing attributes, which are always the editor's plain ones.
            let font = NSFont.systemFont(ofSize: fontSize)
            let baseline = rect.minY + layoutManager.defaultBaselineOffset(for: font)
            draw(number, baselineInText: baseline + origin.y, in: textView)
        }
    }

    /// Right-aligned towards the text, its baseline level with the line's.
    private func draw(_ number: Int, baselineInText baseline: CGFloat, in textView: NSTextView) {
        let y = convert(NSPoint(x: 0, y: baseline), from: textView).y
        let string = String(number) as NSString
        let attributes: [NSAttributedString.Key: Any] = [.font: numberFont, .foregroundColor: NSColor.secondaryLabelColor]
        let width = string.size(withAttributes: attributes).width
        // On whole pixels, so numbers of the same width line up exactly.
        let scale = window?.backingScaleFactor ?? 2
        let x = ((floor(bounds.maxX) - 1 - Self.numberGap - width) * scale).rounded() / scale
        let top = ((y - numberFont.ascender) * scale).rounded() / scale
        string.draw(at: NSPoint(x: x, y: top), withAttributes: attributes)
    }

    /// SF Mono, as in Xcode: every digit the same width (the condensed system
    /// font, tried first, let numbers drift a pixel or two against each other).
    private static func numberFont(size: CGFloat) -> NSFont {
        .monospacedSystemFont(ofSize: max(9, size - 2), weight: .regular)
    }
}
