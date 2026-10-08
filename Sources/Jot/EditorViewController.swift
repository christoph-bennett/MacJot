import AppKit

/// The editor side of the Capture Panel: the text view plus a `⋯` button for
/// the open Note's actions in the top-right corner.
@MainActor
final class EditorViewController: NSViewController {
    /// Items for the `⋯` menu; empty (button disabled) while the Note has no file.
    var menuItems: () -> [NSMenuItem] = { [] }

    private let scrollView: NSScrollView
    private let moreButton = NSButton()

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
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            moreButton.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            moreButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
        ])
        view = container
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
