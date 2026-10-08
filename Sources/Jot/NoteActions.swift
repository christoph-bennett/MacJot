import AppKit

/// A menu item that runs a closure, so menus can be built without selectors.
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, symbol: String? = nil, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
        if let symbol { image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("not used from nibs") }

    @objc private func run() { handler() }
}

/// What can be done with a Note from its context menu (Note List) or the editor's `⋯` menu.
@MainActor
enum NoteActions {
    /// `prepare` runs first (e.g. to save the open Note so the file is current).
    static func items(for note: URL, prepare: @escaping () -> Void, trash: @escaping (URL) -> Void) -> [NSMenuItem] {
        [
            ClosureMenuItem("Reveal in Finder", symbol: "folder") {
                prepare()
                NSWorkspace.shared.activateFileViewerSelecting([note])
            },
            ClosureMenuItem("Open in Default App", symbol: "arrow.up.forward.app") {
                prepare()
                NSWorkspace.shared.open(note)
            },
            ClosureMenuItem("Copy as Markdown", symbol: "doc.on.doc") {
                prepare()
                guard let text = try? String(contentsOf: note, encoding: .utf8) else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            },
            .separator(),
            ClosureMenuItem("Move to Trash", symbol: "trash") { trash(note) },
        ]
    }
}
