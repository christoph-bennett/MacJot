import AppKit
import JotCore
import SwiftUI

/// The Note List: the Capture Panel's sidebar of Notes, newest first, with a
/// search field on top that filters it live.
@MainActor
final class NoteListViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate,
    NSSearchFieldDelegate {
    /// The user picked a Note (click or arrow keys).
    var onOpen: (URL) -> Void = { _ in }
    /// New Note under "No Notes": start writing (as ⌘N).
    var onNewNote: () -> Void = {}
    /// Return in the search field or the list: go on writing in the selected Note.
    var onReturn: () -> Void = {}
    /// `Esc` in the search field with nothing left to clear.
    var onCancel: () -> Void = {}
    /// Context menu items for a Note.
    var menuItems: (URL) -> [NSMenuItem] = { _ in [] }
    /// The Delete key was pressed on a Note; `next` is the Note to show afterwards.
    var onDelete: (URL) -> Void = { _ in }

    let tableView = NoteTableView()
    let searchField = NSSearchField()
    /// Says why the list is empty (Apple's `ContentUnavailableView`), over it.
    private let placeholder = NSHostingView(rootView: PlaceholderView(kind: nil, onNewNote: {}))
    /// The open Draft, once it has text, is a row of its own on top, so a new Note shows up
    /// in the list straight away rather than once it gets its file.
    private enum Row {
        case draft(title: String)
        case note(NoteSummary)
    }
    private var rows: [Row] = []
    /// Every Note, in display order; `rows` shows those matching the search.
    private var notes: [NoteSummary] = []
    private var draftText: String?
    private var current: URL?
    private var isSelectingProgrammatically = false

    override func loadView() {
        let column = NSTableColumn(identifier: .init("note"))
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.style = .sourceList
        tableView.rowHeight = NoteRowView.height
        tableView.dataSource = self
        tableView.delegate = self
        tableView.onDeleteKey = { [weak self] in self?.deleteSelected() }
        tableView.onReturnKey = { [weak self] in self?.onReturn() }
        tableView.menu = {
            let menu = NSMenu()
            menu.delegate = self
            return menu
        }()

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        searchField.placeholderString = "Search"
        searchField.delegate = self
        // Filters on every keystroke and when the clear button is clicked.
        searchField.sendsSearchStringImmediately = true
        searchField.target = self
        searchField.action = #selector(searchChanged)

        let container = NSView()
        placeholder.isHidden = true
        // Only its natural size: no required minimum while the sidebar collapses to nothing.
        placeholder.sizingOptions = [.intrinsicContentSize]
        for subview in [searchField, scrollView, placeholder] as [NSView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(subview)
        }
        NSLayoutConstraint.activate([
            // Its border on the row highlights' edges, 10 pt in from the sidebar's (HIG audit,
            // ticket 21); the field draws its border 1 pt inside its frame.
            searchField.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor, constant: 10),
            searchField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 9),
            searchField.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -9),
            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 6),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            placeholder.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 10).withPriority(.defaultHigh),
            placeholder.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -10).withPriority(.defaultHigh),
            // Centred, but never over the search field in a short panel.
            placeholder.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor).withPriority(.defaultHigh),
            placeholder.topAnchor.constraint(greaterThanOrEqualTo: scrollView.topAnchor),
        ])
        container.clipsToBounds = true
        view = container
    }

    private func showPlaceholder(_ kind: NoteListPlaceholder?) {
        placeholder.isHidden = kind == nil
        guard placeholder.rootView.kind != kind else { return }
        placeholder.rootView = PlaceholderView(kind: kind) { [weak self] in self?.onNewNote() }
    }

    /// The search field or the list has keyboard focus.
    var hasFocus: Bool {
        guard let responder = view.window?.firstResponder else { return false }
        return responder === tableView || (responder as? NSText).map { $0 === searchField.currentEditor() } ?? false
    }

    private var query: String { searchField.stringValue }

    /// Shows `notes` that match the search, highlighting the open one without
    /// triggering `onOpen`. `keepingOrder` keeps known rows where they were
    /// (Notes new to the list go first), so rows don't jump while the user arrows
    /// through them. `draftText` non-nil adds the open Draft as the selected top
    /// row, if it matches the search.
    func show(_ notes: [NoteSummary], selecting current: URL?, keepingOrder: Bool = false, draftText: String? = nil) {
        if keepingOrder {
            let previous = Dictionary(self.notes.enumerated().map { ($1.url, $0) }, uniquingKeysWith: { a, _ in a })
            self.notes = notes.filter { previous[$0.url] == nil }
                + notes.filter { previous[$0.url] != nil }.sorted { previous[$0.url]! < previous[$1.url]! }
        } else {
            self.notes = notes
        }
        self.current = current
        self.draftText = draftText
        filter()
    }

    /// Rebuilds the rows for the current search and re-selects the open Note.
    private func filter() {
        let query = query
        let draft = draftText.flatMap { NoteSummary.listsDraft($0, query: query) ? $0 : nil }
        rows = (draft.map { [Row.draft(title: Self.draftTitle($0))] } ?? []) + notes.compactMap { $0.matching(query) }.map(Row.note)
        showPlaceholder(NoteListPlaceholder(query: query, rowCount: rows.count))
        isSelectingProgrammatically = true
        defer { isSelectingProgrammatically = false }
        tableView.reloadData()
        let selected = draft != nil ? 0 : current.flatMap { current in
            rows.firstIndex { if case .note(let n) = $0 { n.url.standardizedFileURL == current.standardizedFileURL } else { false } }
        }
        if let selected {
            tableView.selectRowIndexes([selected], byExtendingSelection: false)
            tableView.scrollRowToVisible(selected)
        } else {
            tableView.deselectAll(nil)
        }
    }

    /// The rows' dates; one instance, as its formatters are expensive to create.
    private let dates = RelativeDateFormatter()

    /// The relative dates setting: "2h", "Mon", or the short date and time.
    var showsRelativeDates: Bool {
        get { dates.isRelative }
        set {
            guard newValue != dates.isRelative else { return }
            dates.isRelative = newValue
            tableView.reloadData()
        }
    }

    /// Follows the Draft's Title as it's typed, without reloading the list
    /// (re-filtering it while searching, as the Draft may start or stop matching).
    func updateDraft(_ text: String) {
        draftText = text
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return filter() }
        // Its row comes with the first text and goes when it's blank again.
        guard case .draft = rows.first, NoteSummary.listsDraft(text, query: "") else { return filter() }
        rows[0] = .draft(title: Self.draftTitle(text))
        tableView.reloadData(forRowIndexes: [0], columnIndexes: [0])
    }

    private static func draftTitle(_ text: String) -> String {
        NoteSummary.displayTitle(of: text) ?? "New Note"
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
        case .note(let note): cell.show(note, dates: dates)
        }
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !isSelectingProgrammatically, let note = note(at: tableView.selectedRow) else { return }
        onOpen(note.url)
    }

    /// The Draft row has no file, so there's nothing to delete.
    private func deleteSelected() {
        guard let selected = note(at: tableView.selectedRow) else { return }
        onDelete(selected.url)
    }

    /// The Note to show once `note` is gone, like Mail: the row below it, else
    /// the one above. `nil` if it isn't listed or is the only Note.
    func neighbour(of note: URL) -> URL? {
        guard let row = rows.firstIndex(where: {
            if case .note(let n) = $0 { n.url.standardizedFileURL == note.standardizedFileURL } else { false }
        }) else { return nil }
        return (self.note(at: row + 1) ?? self.note(at: row - 1))?.url
    }

    // MARK: Search field

    @objc private func searchChanged() {
        filter()
    }

    /// Arrow keys move through the results while typing stays in the field.
    /// `Esc` clears the search, or with nothing to clear, closes the panel.
    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.moveDown(_:)): moveSelection(by: 1)
        case #selector(NSResponder.moveUp(_:)): moveSelection(by: -1)
        case #selector(NSResponder.insertNewline(_:)):
            // No results: nothing to go on writing in (the editor's Note isn't one of them).
            guard !rows.isEmpty else { return true }
            if tableView.selectedRow < 0 { moveSelection(by: 1) }  // nothing picked yet: take the first result
            onReturn()
        case #selector(NSResponder.cancelOperation(_:)):
            if !cancelSearch() { onCancel() }
        default:
            return false
        }
        return true
    }

    /// Clears a non-empty search; returns false if there was nothing to clear.
    @discardableResult
    func cancelSearch() -> Bool {
        guard !searchField.stringValue.isEmpty else { return false }
        searchField.stringValue = ""
        filter()
        return true
    }

    /// Selects (and so opens) the next or previous row, starting at the top.
    private func moveSelection(by delta: Int) {
        guard !rows.isEmpty else { return }
        let row = tableView.selectedRow < 0 ? 0 : min(max(tableView.selectedRow + delta, 0), rows.count - 1)
        tableView.selectRowIndexes([row], byExtendingSelection: false)
        tableView.scrollRowToVisible(row)
    }

    // MARK: Context menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        guard let note = note(at: tableView.clickedRow) else { return }
        menuItems(note.url).forEach(menu.addItem)
    }
}

/// Sends ⌫ (Delete), ⌦ (fn-Delete, Forward Delete) and ⌘⌫ (Finder's Move to
/// Trash) to `onDeleteKey`, and Return to `onReturnKey`.
final class NoteTableView: NSTableView {
    var onDeleteKey: () -> Void = {}
    var onReturnKey: () -> Void = {}

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        let isDelete = event.keyCode == 51 || event.keyCode == 117  // kVK_Delete, kVK_ForwardDelete
        let isReturn = event.keyCode == 36 || event.keyCode == 76  // kVK_Return, kVK_ANSI_KeypadEnter
        if isDelete, modifiers.isEmpty || modifiers == .command {
            onDeleteKey()
        } else if isReturn, modifiers.isEmpty {
            onReturnKey()
        } else {
            super.keyDown(with: event)
        }
    }
}

/// A Note List row: Title on top, relative date and preview below, in the HIG's
/// Headline and Subheadline text styles, 10 pt from the row's top and bottom.
private final class NoteRowView: NSTableCellView {
    static let identifier = NSUserInterfaceItemIdentifier("NoteRow")

    private let title = NSTextField(labelWithString: "")
    private let detail = NSTextField(labelWithString: "")
    private static let titleFont = NSFont.preferredFont(forTextStyle: .headline)
    private static let detailFont = NSFont.preferredFont(forTextStyle: .subheadline)
    private static let padding: CGFloat = 10
    private static let lineGap: CGFloat = 3
    /// 53 pt with the system's fonts: both lines, the gap between them, and the padding.
    static var height: CGFloat {
        func lineHeight(_ font: NSFont) -> CGFloat {
            let label = NSTextField(labelWithString: "Ag")
            label.font = font
            return ceil(label.intrinsicContentSize.height)
        }
        return padding + lineHeight(titleFont) + lineGap + lineHeight(detailFont) + padding
    }

    init() {
        super.init(frame: .zero)
        identifier = Self.identifier
        title.font = Self.titleFont
        detail.font = Self.detailFont
        detail.textColor = .secondaryLabelColor
        for field in [title, detail] {
            field.lineBreakMode = .byTruncatingTail
            field.translatesAutoresizingMaskIntoConstraints = false
            addSubview(field)
        }
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            title.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            title.topAnchor.constraint(equalTo: topAnchor, constant: Self.padding),
            detail.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            detail.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            detail.topAnchor.constraint(equalTo: title.bottomAnchor, constant: Self.lineGap),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used from nibs") }

    func showDraft(title: String) {
        self.title.stringValue = title
        detail.stringValue = "New note"
    }

    func show(_ note: NoteSummary, dates: RelativeDateFormatter) {
        title.stringValue = note.title
        let date = dates.string(for: note.modified)
        detail.stringValue = note.preview.isEmpty ? date : "\(date)  \(note.preview)"
    }
}

/// Why the Note List is empty, in Apple's standard look. With no Notes at all,
/// a button starts one: the search field has the focus there, not the editor.
private struct PlaceholderView: View {
    let kind: NoteListPlaceholder?
    let onNewNote: () -> Void

    var body: some View {
        switch kind {
        case .noResults(let query):
            ContentUnavailableView.search(text: query)
        case .noNotes:
            ContentUnavailableView {
                Label("No Notes", systemImage: "note.text")
            } actions: {
                Button("New Note", action: onNewNote)
                    .help("Start writing a new note (⌘N)")
            }
        case nil:
            EmptyView()
        }
    }
}

private extension NSLayoutConstraint {
    func withPriority(_ priority: NSLayoutConstraint.Priority) -> NSLayoutConstraint {
        self.priority = priority
        return self
    }
}
