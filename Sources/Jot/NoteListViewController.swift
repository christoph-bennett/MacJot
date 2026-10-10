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
    /// Return in the search field or the list: go on writing in the selected Note.
    var onReturn: () -> Void = {}
    /// `Esc` in the search field with nothing left to clear.
    var onCancel: () -> Void = {}
    /// Context menu items for a Note.
    var menuItems: (URL) -> [NSMenuItem] = { _ in [] }
    /// The Delete key was pressed on a Note; `next` is the Note to show afterwards.
    var onDelete: (URL) -> Void = { _ in }
    /// The + next to the search field: start a new Note, as File > New Note does.
    var onNewNote: () -> Void = {}

    let tableView = NoteTableView()
    let searchField = NSSearchField()
    private lazy var newNoteButton: NSButton = {
        let image = NSImage(systemSymbolName: "plus", accessibilityDescription: "New Note")!
        let button = NSButton(image: image, target: self, action: #selector(newNote))
        button.isBordered = false
        button.symbolConfiguration = .init(pointSize: 15, weight: .regular)
        button.contentTintColor = .secondaryLabelColor
        button.toolTip = "New Note (⌘N)"
        return button
    }()
    /// Says why the list is empty (Apple's `ContentUnavailableView`), over it.
    private let placeholder = NSHostingView(rootView: PlaceholderView(kind: nil))
    /// The open Draft, once it has text, is a row of its own on top, so a new Note shows up
    /// in the list straight away rather than once it gets its file.
    private enum Row {
        case draft(title: String)
        case outside(OutsideFile)
        case note(NoteSummary)
    }
    /// The Outside File shown in the editor (ticket 31): the selected top row,
    /// with a lock and its folder; not part of Search.
    struct OutsideFile {
        let url: URL
        let title: String
        let folder: String
    }
    private var outsideFile: OutsideFile?
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
        for subview in [searchField, newNoteButton, scrollView, placeholder] as [NSView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(subview)
        }
        NSLayoutConstraint.activate([
            // Its border on the row highlights' edges, 10 pt in from the sidebar's (HIG audit,
            // ticket 21); the field draws its border 1 pt inside its frame.
            searchField.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor, constant: 10),
            searchField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 9),
            // The + after the field, its symbol's edge on the row highlights' too.
            newNoteButton.leadingAnchor.constraint(equalTo: searchField.trailingAnchor, constant: 6),
            newNoteButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            newNoteButton.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
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

    @objc private func newNote() { onNewNote() }

    private func showPlaceholder(_ kind: NoteListPlaceholder?) {
        placeholder.isHidden = kind == nil
        guard placeholder.rootView.kind != kind else { return }
        placeholder.rootView = PlaceholderView(kind: kind)
    }

    /// The search field or the list has keyboard focus.
    var hasFocus: Bool {
        guard let responder = view.window?.firstResponder else { return false }
        return responder === tableView || (responder as? NSText).map { $0 === searchField.currentEditor() } ?? false
    }

    private var query: String { searchField.stringValue }
    /// Blank searches match everything: the Draft follows its Title live then,
    /// and the Outside File is listed.
    private var isSearchBlank: Bool { query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Shows `notes` that match the search, highlighting the open one without
    /// triggering `onOpen`. `keepingOrder` keeps known rows where they were
    /// (Notes new to the list go first), so rows don't jump while the user arrows
    /// through them. `draftText` non-nil adds the open Draft as the selected top
    /// row, if it matches the search; `outsideFile` does the same for the Outside
    /// File, while the search is blank.
    func show(_ notes: [NoteSummary], selecting current: URL?, keepingOrder: Bool = false, draftText: String? = nil,
              outsideFile: OutsideFile? = nil) {
        if keepingOrder {
            let previous = Dictionary(self.notes.enumerated().map { ($1.url, $0) }, uniquingKeysWith: { a, _ in a })
            self.notes = notes.filter { previous[$0.url] == nil }
                + notes.filter { previous[$0.url] != nil }.sorted { previous[$0.url]! < previous[$1.url]! }
        } else {
            self.notes = notes
        }
        self.current = current
        self.draftText = draftText
        self.outsideFile = outsideFile
        filter()
    }

    /// Rebuilds the rows for the current search and re-selects the open Note.
    private func filter() {
        let query = query
        let draft = draftText.flatMap { NoteSummary.listsDraft($0, query: query) ? $0 : nil }
        let outside = isSearchBlank ? outsideFile : nil
        rows = (draft.map { [Row.draft(title: Self.draftTitle($0))] } ?? []) + (outside.map { [Row.outside($0)] } ?? [])
            + notes.compactMap { $0.matching(query) }.map(Row.note)
        showPlaceholder(NoteListPlaceholder(query: query, rowCount: rows.count))
        isSelectingProgrammatically = true
        defer { isSelectingProgrammatically = false }
        tableView.reloadData()
        let selected = draft != nil || outside != nil ? 0 : current.flatMap { current in
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
        if !isSearchBlank { return filter() }
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
        case .outside(let file): cell.showOutside(title: file.title, folder: file.folder)
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
        let row = tableView.clickedRow
        guard rows.indices.contains(row) else { return }
        switch rows[row] {
        case .note(let note): menuItems(note.url).forEach(menu.addItem)
        case .outside(let file): menuItems(file.url).forEach(menu.addItem)
        case .draft: break
        }
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

    /// Its folder after a lock: an SF Symbol drawn like the text, as the menu bar
    /// icon is (no emoji).
    func showOutside(title: String, folder: String) {
        self.title.stringValue = title
        let lock = NSTextAttachment()
        lock.image = NSImage(systemSymbolName: "lock", accessibilityDescription: "Read-only")?
            .withSymbolConfiguration(.init(textStyle: .subheadline))
        let text = NSMutableAttributedString(attachment: lock)
        text.append(NSAttributedString(string: " \(folder)"))
        text.addAttributes([.font: Self.detailFont, .foregroundColor: NSColor.secondaryLabelColor],
                           range: NSRange(location: 0, length: text.length))
        detail.attributedStringValue = text
    }

    func show(_ note: NoteSummary, dates: RelativeDateFormatter) {
        title.stringValue = note.title
        let date = dates.string(for: note.modified)
        detail.stringValue = note.preview.isEmpty ? date : "\(date)  \(note.preview)"
    }
}

/// Why the Note List is empty, in Apple's standard look. No New Note button:
/// a blank Draft is always open in the editor already (Return gets there).
private struct PlaceholderView: View {
    let kind: NoteListPlaceholder?

    var body: some View {
        switch kind {
        case .noResults(let query): ContentUnavailableView.search(text: query)
        case .noNotes: ContentUnavailableView("No Notes", systemImage: "note.text")
        case nil: EmptyView()
        }
    }
}

private extension NSLayoutConstraint {
    func withPriority(_ priority: NSLayoutConstraint.Priority) -> NSLayoutConstraint {
        self.priority = priority
        return self
    }
}
