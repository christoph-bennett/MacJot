import AppKit
import JotCore

/// What a Formatting Toolbar button does.
enum FormatCommand {
    case inline(InlineFormat)
    case link
}

/// The editor side of the Capture Panel: the Formatting Toolbar on top, with a
/// `⋯` button for the open Note's actions on its right, and the text view below.
@MainActor
final class EditorViewController: NSViewController {
    /// Items for the `⋯` menu; empty (button disabled) while the Note has no file.
    var menuItems: () -> [NSMenuItem] = { [] }
    /// A Formatting Toolbar control was clicked.
    var onFormat: (FormatCommand) -> Void = { _ in }

    private let scrollView: NSScrollView
    private let moreButton = NSButton()
    /// Grouped like TextEdit's and Pages' format bars: text styles, then code and link.
    private static let toolbar: [[(symbol: String, help: String, command: FormatCommand)]] = [
        [
            ("bold", "Bold (⌘B)", .inline(.bold)),
            ("italic", "Italic (⌘I)", .inline(.italic)),
            ("strikethrough", "Strikethrough (⌘⇧X)", .inline(.strikethrough)),
        ],
        [
            ("chevron.left.forwardslash.chevron.right", "Inline Code", .inline(.code)),
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
        let toolbar = NSStackView(views: groups)
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

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            toolbar.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            toolbar.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            scrollView.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 4),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            moreButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            moreButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            toolbar.trailingAnchor.constraint(lessThanOrEqualTo: moreButton.leadingAnchor, constant: -8),
        ])
        view = container
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
