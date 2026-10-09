import AppKit
import JotCore

// Renders Settings panes and the Note List offscreen to PNGs (argv[1] = output dir).
let out = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

@MainActor func pump(_ seconds: Double = 0.3) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }

@MainActor func save(_ view: NSView, _ name: String) {
    view.layoutSubtreeIfNeeded()
    guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
    view.cacheDisplay(in: view.bounds, to: rep)
    try! rep.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent(name + ".png"))
    print(name, view.bounds.size, rep.pixelsWide, "px")
}

// Sample Notes in a temporary folder, so no real titles end up in the audit.
let folderURL = FileManager.default.temporaryDirectory.appendingPathComponent("MacJot Sample Notes")
try? FileManager.default.removeItem(at: folderURL)
try! FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
let samples = [
    ("Meeting with Anna about the Q4 roadmap", "Agenda: budget, hiring, the launch date. Anna wants a decision by Friday."),
    ("Groceries", "- [ ] oat milk\n- [ ] coffee beans\n- [x] bread"),
    ("Ideas for the workshop in Vienna", "Start with a short exercise, then the three case studies."),
    ("Book notes: The Design of Everyday Things", "Affordances and signifiers. Feedback must be immediate."),
    ("Call the plumber", ""),
    ("Packing list for the weekend in the mountains", "Boots, rain jacket, headlamp, map."),
    ("Quote", "Simplicity is the ultimate sophistication."),
    ("Draft: reply to the landlord about the heating", "Dear Mr. Huber, the heating in the living room has been off since Monday."),
    ("Podcast recommendations", "Hard Fork, Decoder, The Vergecast."),
    ("Birthday gift ideas", "A good fountain pen, concert tickets."),
    ("Recipe: lentil soup", "Onion, carrot, celery, red lentils, cumin, lemon."),
    ("Things to try in MacJot", "Search, checkboxes, the Date Prefix."),
]
for (i, (title, body)) in samples.enumerated() {
    let url = folderURL.appendingPathComponent("note-\(i).md")
    try! "# \(title)\n\n\(body)\n".write(to: url, atomically: true, encoding: .utf8)
    let date = Date().addingTimeInterval(-Double(i) * 3600 * 7)
    try! FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
}
let recovery = FileManager.default.temporaryDirectory.appendingPathComponent("macjot-render-recovery.md")
let folder = try! NotesFolder(url: folderURL, recoveryURL: recovery) { _ in }

for (appearance, suffix) in [(NSAppearance.Name.aqua, "light"), (.darkAqua, "dark")] {
    app.appearance = NSAppearance(named: appearance)

    // Settings, each pane, with the title bar.
    let settings = SettingsWindowController()
    settings.notesFolderURL = { folderURL }
    let window = settings.makeWindow()
    for pane in SettingsPane.allCases {
        settings.select(pane, animated: false)
        settings.refresh()
        pump()
        save(window.contentView!.superview!, "settings-\(pane.rawValue)-\(suffix)")
    }

    // The Capture Panel with the Note List open, as in the app (693 × 553 pt).
    let list = NoteListViewController()
    let sidebar = NSSplitViewItem(sidebarWithViewController: list)
    sidebar.minimumThickness = 180
    sidebar.maximumThickness = 320
    let editor = NSViewController()
    editor.view = NSView()
    let split = NSSplitViewController()
    split.addSplitViewItem(sidebar)
    split.addSplitViewItem(NSSplitViewItem(viewController: editor))
    let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 693, height: 525),
                        styleMask: [.titled, .closable, .resizable, .nonactivatingPanel], backing: .buffered, defer: false)
    panel.title = "MacJot"
    panel.contentViewController = split
    panel.setContentSize(NSSize(width: 693, height: 525))
    let notes = try! folder.notes()
    list.show(notes, selecting: notes[1].url)
    pump()
    save(panel.contentView!.superview!, "notelist-\(suffix)")
    list.searchField.stringValue = "zzz"
    list.show(notes, selecting: nil)
    pump()
    save(panel.contentView!.superview!, "notelist-no-results-\(suffix)")
    list.searchField.stringValue = ""
    list.show([], selecting: nil)
    pump()
    save(panel.contentView!.superview!, "notelist-empty-\(suffix)")
}
