import AppKit
import JotCore

/// The Note List: the Capture Panel's sidebar of Notes, newest first.
@MainActor
final class NoteListViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate {
    /// The user picked a Note (click or arrow keys).
    var onOpen: (URL) -> Void = { _ in }
    /// Context menu items for a Note.
    var menuItems: (URL) -> [NSMenuItem] = { _ in [] }

    let tableView = NSTableView()
    private var notes: [NoteSummary] = []
    private var isSelectingProgrammatically = false

    override func loadView() {
        let column = NSTableColumn(identifier: .init("note"))
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.style = .sourceList
        tableView.rowHeight = 44
        tableView.dataSource = self
        tableView.delegate = self
        tableView.menu = {
            let menu = NSMenu()
            menu.delegate = self
            return menu
        }()

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        view = scrollView
    }

    /// Shows `notes`, highlighting the open one without triggering `onOpen`.
    /// `keepingOrder` keeps known rows where they were (Notes new to the list go
    /// first), so rows don't jump while the user arrows through them.
    func show(_ notes: [NoteSummary], selecting current: URL?, keepingOrder: Bool = false) {
        if keepingOrder {
            let previous = Dictionary(self.notes.enumerated().map { ($1.url, $0) }, uniquingKeysWith: { a, _ in a })
            self.notes = notes.filter { previous[$0.url] == nil }
                + notes.filter { previous[$0.url] != nil }.sorted { previous[$0.url]! < previous[$1.url]! }
        } else {
            self.notes = notes
        }
        isSelectingProgrammatically = true
        defer { isSelectingProgrammatically = false }
        tableView.reloadData()
        if let current, let row = notes.firstIndex(where: { $0.url.standardizedFileURL == current.standardizedFileURL }) {
            tableView.selectRowIndexes([row], byExtendingSelection: false)
            tableView.scrollRowToVisible(row)
        } else {
            tableView.deselectAll(nil)
        }
    }

    // MARK: Table

    func numberOfRows(in tableView: NSTableView) -> Int { notes.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: NoteRowView.identifier, owner: self) as? NoteRowView ?? NoteRowView()
        cell.show(notes[row])
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !isSelectingProgrammatically, notes.indices.contains(tableView.selectedRow) else { return }
        onOpen(notes[tableView.selectedRow].url)
    }

    // MARK: Context menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        guard notes.indices.contains(tableView.clickedRow) else { return }
        menuItems(notes[tableView.clickedRow].url).forEach(menu.addItem)
    }
}

/// A Note List row: Title on top, relative date and preview below.
private final class NoteRowView: NSTableCellView {
    static let identifier = NSUserInterfaceItemIdentifier("NoteRow")
    @MainActor private static let dates = RelativeDateFormatter()

    private let title = NSTextField(labelWithString: "")
    private let detail = NSTextField(labelWithString: "")

    init() {
        super.init(frame: .zero)
        identifier = Self.identifier
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        detail.font = .systemFont(ofSize: 11)
        detail.textColor = .secondaryLabelColor
        for field in [title, detail] {
            field.lineBreakMode = .byTruncatingTail
            field.translatesAutoresizingMaskIntoConstraints = false
            addSubview(field)
        }
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            title.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            title.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            detail.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            detail.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            detail.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 2),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used from nibs") }

    func show(_ note: NoteSummary) {
        title.stringValue = note.title
        let date = Self.dates.string(for: note.modified)
        detail.stringValue = note.preview.isEmpty ? date : "\(date)  \(note.preview)"
    }
}
