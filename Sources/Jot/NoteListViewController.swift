import AppKit
import JotCore

/// The Note List: the Capture Panel's sidebar of Notes, newest first.
@MainActor
final class NoteListViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate {
    /// The user picked a Note (click or arrow keys).
    var onOpen: (URL) -> Void = { _ in }
    /// Context menu items for a Note.
    var menuItems: (URL) -> [NSMenuItem] = { _ in [] }
    /// The Delete key was pressed on a Note; `next` is the Note to show afterwards.
    var onDelete: (_ note: URL, _ next: URL?) -> Void = { _, _ in }

    let tableView = NoteTableView()
    /// The open Draft, if any, is a row of its own on top, so a new Note shows up
    /// in the list straight away rather than once it gets its file.
    private enum Row {
        case draft(title: String)
        case note(NoteSummary)
    }
    private var rows: [Row] = []
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
        tableView.onDeleteKey = { [weak self] in self?.deleteSelected() }
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
    /// `draftTitle` non-nil adds the open Draft as the selected top row.
    func show(_ notes: [NoteSummary], selecting current: URL?, keepingOrder: Bool = false, draftTitle: String? = nil) {
        if keepingOrder {
            let previous = Dictionary(self.notes.enumerated().map { ($1.url, $0) }, uniquingKeysWith: { a, _ in a })
            self.notes = notes.filter { previous[$0.url] == nil }
                + notes.filter { previous[$0.url] != nil }.sorted { previous[$0.url]! < previous[$1.url]! }
        } else {
            self.notes = notes
        }
        rows = (draftTitle.map { [Row.draft(title: $0)] } ?? []) + self.notes.map(Row.note)
        isSelectingProgrammatically = true
        defer { isSelectingProgrammatically = false }
        tableView.reloadData()
        let selected = draftTitle != nil ? 0 : current.flatMap { current in
            rows.firstIndex { if case .note(let n) = $0 { n.url.standardizedFileURL == current.standardizedFileURL } else { false } }
        }
        if let selected {
            tableView.selectRowIndexes([selected], byExtendingSelection: false)
            tableView.scrollRowToVisible(selected)
        } else {
            tableView.deselectAll(nil)
        }
    }

    /// Follows the Draft's Title as it's typed, without reloading the list.
    func updateDraftTitle(_ title: String) {
        guard case .draft = rows.first else { return }
        rows[0] = .draft(title: title)
        tableView.reloadData(forRowIndexes: [0], columnIndexes: [0])
    }

    private func note(at row: Int) -> NoteSummary? {
        guard rows.indices.contains(row), case .note(let note) = rows[row] else { return nil }
        return note
    }

    // MARK: Table

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: NoteRowView.identifier, owner: self) as? NoteRowView ?? NoteRowView()
        switch rows[row] {
        case .draft(let title): cell.showDraft(title: title)
        case .note(let note): cell.show(note)
        }
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !isSelectingProgrammatically, let note = note(at: tableView.selectedRow) else { return }
        onOpen(note.url)
    }

    /// The Draft row has no file, so there's nothing to delete.
    private func deleteSelected() {
        let row = tableView.selectedRow
        guard let selected = note(at: row) else { return }
        onDelete(selected.url, (note(at: row + 1) ?? note(at: row - 1))?.url)
    }

    // MARK: Context menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        guard let note = note(at: tableView.clickedRow) else { return }
        menuItems(note.url).forEach(menu.addItem)
    }
}

/// Sends ⌫ (Delete), ⌦ (fn-Delete, Forward Delete) and ⌘⌫ (Finder's Move to
/// Trash) to `onDeleteKey`.
final class NoteTableView: NSTableView {
    var onDeleteKey: () -> Void = {}

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        let isDelete = event.keyCode == 51 || event.keyCode == 117  // kVK_Delete, kVK_ForwardDelete
        if isDelete, modifiers.isEmpty || modifiers == .command {
            onDeleteKey()
        } else {
            super.keyDown(with: event)
        }
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

    func showDraft(title: String) {
        self.title.stringValue = title
        detail.stringValue = "New note"
    }

    func show(_ note: NoteSummary) {
        title.stringValue = note.title
        let date = Self.dates.string(for: note.modified)
        detail.stringValue = note.preview.isEmpty ? date : "\(date)  \(note.preview)"
    }
}
