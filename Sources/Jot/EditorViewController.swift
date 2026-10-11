import AppKit
import JotCore

/// What a Formatting Toolbar button does.
enum FormatCommand {
    case inline(InlineFormat)
    case line(LineFormat)
    case link
    /// Fences around lines (ticket 35).
    case codeBlock
    /// `---` as its own paragraph (ticket 36).
    case horizontalRule
}

/// The editor side of the Capture Panel: the Formatting Toolbar on top, with a
/// `⋯` button for the open Note's actions on its right, and the text view below;
/// between them, for an Outside File, the read-only bar.
@MainActor
final class EditorViewController: NSViewController {
    /// Items for the `⋯` menu; empty (button disabled) while the Note has no file.
    var menuItems: () -> [NSMenuItem] = { [] }
    /// A Formatting Toolbar control was clicked.
    var onFormat: (FormatCommand) -> Void = { _ in }
    /// The read-only bar's Move to Notes Folder button was clicked (ticket 32).
    var onMoveToNotesFolder: () -> Void = {}

    private let scrollView: NSScrollView
    private let moreButton = NSButton()
    private var formatControls: [NSControl] = []
    private let readOnlyBar = NSBox()
    private let readOnlyLabel = NSTextField(wrappingLabelWithString: "")
    /// The text view's top: below the toolbar, or below the read-only bar.
    private var textBelowToolbar: NSLayoutConstraint?
    private var textBelowBar: NSLayoutConstraint?

    /// Shown in the read-only bar while an Outside File is shown (ticket 31); nil
    /// hides the bar. The Formatting Toolbar is greyed out meanwhile, but stays in
    /// place, so nothing moves when the file becomes editable.
    var readOnlyMessage: String? {
        didSet {
            guard readOnlyMessage != oldValue else { return }
            loadViewIfNeeded()
            readOnlyLabel.stringValue = readOnlyMessage ?? ""
            readOnlyBar.isHidden = readOnlyMessage == nil
            textBelowToolbar?.isActive = readOnlyMessage == nil
            textBelowBar?.isActive = readOnlyMessage != nil
            formatControls.forEach { $0.isEnabled = readOnlyMessage == nil }
        }
    }
    /// Grouped like TextEdit's and Pages' format bars: after the heading menu,
    /// text styles, lists and quote, then code and link.
    private static let headings = [("Heading 1", 1), ("Heading 2", 2), ("Heading 3", 3), ("Plain Text", 0)]
    private static let toolbar: [[(symbol: String, help: String, command: FormatCommand)]] = [
        [
            ("bold", "Bold (⌘B)", .inline(.bold)),
            ("italic", "Italic (⌘I)", .inline(.italic)),
            ("strikethrough", "Strikethrough (⌘⇧X)", .inline(.strikethrough)),
        ],
        [
            ("list.bullet", "Bulleted List", .line(.bullet)),
            ("list.number", "Numbered List", .line(.numbered)),
            ("checklist", "Checklist", .line(.checklist)),
            ("text.quote", "Quote", .line(.quote)),
        ],
        [
            ("chevron.left.forwardslash.chevron.right", "Inline Code", .inline(.code)),
            ("curlybraces.square", "Code Block", .codeBlock),
            ("link", "Link", .link),
        ],
    ]

    init(scrollView: NSScrollView) {
        self.scrollView = scrollView
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used from nibs") }

    override func loadView() {
        let container = NSView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scrollView)

        let groups = Self.toolbar.enumerated().map { index, items in
            let control = NSSegmentedControl(
                images: items.map { NSImage(systemSymbolName: $0.symbol, accessibilityDescription: $0.help)! },
                trackingMode: .momentary, target: self, action: #selector(format(_:)))
            for (segment, item) in items.enumerated() {
                control.setToolTip(item.help, forSegment: segment)
                control.setWidth(30, forSegment: segment)
            }
            control.refusesFirstResponder = true  // typing stays in the editor
            control.tag = index
            return control
        }
        let headingMenu = makeHeadingMenu()
        formatControls = [headingMenu] + groups
        let toolbar = NSStackView(views: [headingMenu] + groups)
        toolbar.spacing = 8
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(toolbar)

        moreButton.image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: "Note actions")
        moreButton.isBordered = false
        moreButton.contentTintColor = .secondaryLabelColor
        moreButton.target = self
        moreButton.action = #selector(showMenu)
        moreButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(moreButton)

        makeReadOnlyBar()
        container.addSubview(readOnlyBar)
        textBelowToolbar = scrollView.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 4)
        textBelowBar = scrollView.topAnchor.constraint(equalTo: readOnlyBar.bottomAnchor)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            toolbar.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            toolbar.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            textBelowToolbar!,
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            readOnlyBar.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 8),
            readOnlyBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            readOnlyBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            moreButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            moreButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            toolbar.trailingAnchor.constraint(lessThanOrEqualTo: moreButton.leadingAnchor, constant: -8),
        ])
        view = container
    }

    /// A full-width strip in a quiet fill, with a lock and the message; separators
    /// above and below set it apart from the toolbar and the text.
    private func makeReadOnlyBar() {
        readOnlyBar.boxType = .custom
        readOnlyBar.borderWidth = 0
        readOnlyBar.fillColor = .quaternarySystemFill
        readOnlyBar.contentViewMargins = .zero
        readOnlyBar.isHidden = true
        readOnlyBar.translatesAutoresizingMaskIntoConstraints = false

        let lock = NSImageView(image: NSImage(systemSymbolName: "lock", accessibilityDescription: "Read-only")!)
        lock.symbolConfiguration = .init(textStyle: .callout)
        lock.contentTintColor = .secondaryLabelColor
        readOnlyLabel.font = .preferredFont(forTextStyle: .callout)
        readOnlyLabel.textColor = .secondaryLabelColor
        let row = NSStackView(views: [lock, readOnlyLabel])
        row.spacing = 6
        row.alignment = .firstBaseline
        // Blue like a default button, but without Return as its key: Return in
        // the text would otherwise move the file.
        let move = NSButton(title: "Move to Notes Folder", target: self, action: #selector(moveToNotesFolder))
        move.bezelColor = .controlAccentColor
        move.controlSize = .small
        move.translatesAutoresizingMaskIntoConstraints = false
        move.setContentCompressionResistancePriority(.required, for: .horizontal)
        readOnlyBar.addSubview(move)
        let top = NSBox(), bottom = NSBox()
        for view in [row, top, bottom] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            readOnlyBar.addSubview(view)
        }
        top.boxType = .separator
        bottom.boxType = .separator
        lock.setContentHuggingPriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            top.topAnchor.constraint(equalTo: readOnlyBar.topAnchor),
            top.leadingAnchor.constraint(equalTo: readOnlyBar.leadingAnchor),
            top.trailingAnchor.constraint(equalTo: readOnlyBar.trailingAnchor),
            bottom.bottomAnchor.constraint(equalTo: readOnlyBar.bottomAnchor),
            bottom.leadingAnchor.constraint(equalTo: readOnlyBar.leadingAnchor),
            bottom.trailingAnchor.constraint(equalTo: readOnlyBar.trailingAnchor),
            row.topAnchor.constraint(equalTo: readOnlyBar.topAnchor, constant: 8),
            row.bottomAnchor.constraint(equalTo: readOnlyBar.bottomAnchor, constant: -8),
            row.leadingAnchor.constraint(equalTo: readOnlyBar.leadingAnchor, constant: 16),
            move.centerYAnchor.constraint(equalTo: readOnlyBar.centerYAnchor),
            move.trailingAnchor.constraint(equalTo: readOnlyBar.trailingAnchor, constant: -12),
            row.trailingAnchor.constraint(lessThanOrEqualTo: move.leadingAnchor, constant: -12),
        ])
    }

    @objc private func moveToNotesFolder() { onMoveToNotesFolder() }

    /// A pull-down of H1–H3 and plain text, with ⌘1–⌘3 and ⌘0 as its key
    /// equivalents. (A panel key equivalent reaches the window's controls before
    /// `CapturePanel.sendEvent`, so the menu, not the panel, handles them.)
    private func makeHeadingMenu() -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: true)
        button.addItem(withTitle: "")  // a pull-down's first item is its face
        button.item(at: 0)?.image = NSImage(systemSymbolName: "textformat.size", accessibilityDescription: "Heading")
        for (title, level) in Self.headings {
            let item = NSMenuItem(title: title, action: #selector(heading(_:)), keyEquivalent: "\(level)")
            item.keyEquivalentModifierMask = .command
            item.tag = level
            item.target = self
            button.menu?.addItem(item)
        }
        // No room in the toolbar for another button (ticket 36).
        button.menu?.addItem(.separator())
        let rule = NSMenuItem(title: "Horizontal Line", action: #selector(horizontalRule), keyEquivalent: "")
        rule.target = self
        button.menu?.addItem(rule)
        button.toolTip = "Heading"
        button.refusesFirstResponder = true
        button.widthAnchor.constraint(equalToConstant: 56).isActive = true
        return button
    }

    @objc private func heading(_ sender: NSMenuItem) {
        // ⌘0–⌘3 arrive here as the menu's key equivalents, before the panel sees
        // them: apply them only while the editor has focus (not, say, in the search
        // field). Choosing an item in the open menu, by mouse or keyboard, always works.
        if let event = NSApp.currentEvent, event.type == .keyDown, event.modifierFlags.contains(.command),
           view.window?.firstResponder !== scrollView.documentView {
            return
        }
        onFormat(.line(.heading(sender.tag)))
    }

    @objc private func horizontalRule() {
        onFormat(.horizontalRule)
    }

    @objc private func format(_ sender: NSSegmentedControl) {
        onFormat(Self.toolbar[sender.tag][sender.selectedSegment].command)
    }

    @objc private func showMenu() {
        let items = menuItems()
        guard !items.isEmpty else { return }
        let menu = NSMenu()
        items.forEach(menu.addItem)
        let below = moreButton.isFlipped ? moreButton.bounds.height + 4 : -4
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: below), in: moreButton)
    }
}
