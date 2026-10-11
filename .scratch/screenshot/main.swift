import AppKit
import JotCore

// Renders the README screenshot (argv[1] = output dir): the Capture Panel as
// the Search Hotkey shows it, with sample Notes in a temporary folder.
let out = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

@MainActor func pump(_ seconds: Double = 0.4) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }

/// The window as macOS draws it on screen: rounded corners and a shadow, on a
/// transparent margin (cacheDisplay gives the square content only).
@MainActor func save(_ view: NSView, _ name: String) {
    view.layoutSubtreeIfNeeded()
    guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
    view.cacheDisplay(in: view.bounds, to: rep)
    let window = rep.cgImage!
    let scale = CGFloat(rep.pixelsWide) / view.bounds.width
    let margin = 40 * scale, corner = 16 * scale
    let width = CGFloat(window.width) + 2 * margin, height = CGFloat(window.height) + 2 * margin
    let context = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let frame = CGRect(x: margin, y: margin, width: CGFloat(window.width), height: CGFloat(window.height))
    let shape = CGPath(roundedRect: frame, cornerWidth: corner, cornerHeight: corner, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10 * scale), blur: 30 * scale, color: CGColor(gray: 0, alpha: 0.35))
    context.addPath(shape)
    context.setFillColor(CGColor(gray: 0.5, alpha: 1))
    context.fillPath()
    context.restoreGState()
    context.addPath(shape)
    context.clip()
    context.draw(window, in: frame)
    let png = NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!
    try! png.write(to: out.appendingPathComponent(name + ".png"))
    print(name, view.bounds.size, Int(width), "px")
}

let folderURL = FileManager.default.temporaryDirectory.appendingPathComponent("MacJot Screenshot Notes")
try? FileManager.default.removeItem(at: folderURL)
try! FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
// Oldest first; the last one is the most recent and opens in the editor.
let samples = [
    "# Recipe: lentil soup\n\nOnion, carrot, celery, red lentils, cumin, lemon.",
    "# Podcast recommendations\n\nHard Fork, Decoder, The Vergecast.",
    "# Book notes: The Design of Everyday Things\n\nAffordances and signifiers. Feedback must be immediate.",
    "# Packing list for the weekend\n\nBoots, rain jacket, headlamp, map.",
    "# Ideas for the workshop in Vienna\n\nStart with a short exercise, then the case studies.",
    "# Groceries\n\n- [ ] oat milk\n- [ ] coffee beans\n- [x] bread",
    """
    # Plan for the product launch

    The launch moves to **Thursday, 14 November**. Anna confirmed the date in this morning's call.

    ## Before Friday

    - [x] Send the press kit to the agency
    - [ ] Finish the *pricing page*
    - [ ] Book the room for the demo

    ## Open questions

    1. Do we announce the beta at the same time?
    2. Who writes the `release-notes.md`?

    > Ship it when it's ready, not when it's perfect.
    """,
]
for (i, text) in samples.enumerated() {
    let url = folderURL.appendingPathComponent("note-\(i).md")
    try! (text + "\n").write(to: url, atomically: true, encoding: .utf8)
    let date = Date().addingTimeInterval(-Double(samples.count - i) * 3600 * 5)
    try! FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
}
let recovery = FileManager.default.temporaryDirectory.appendingPathComponent("macjot-screenshot-recovery.md")
let folder = try! NotesFolder(url: folderURL, recoveryURL: recovery) { _ in }

for (appearance, suffix) in [(NSAppearance.Name.aqua, "light"), (.darkAqua, "dark")] {
    app.appearance = NSAppearance(named: appearance)
    let controller = CapturePanelController(folder: folder)
    // The app's defaults (AppDelegate), as a fresh install shows them.
    controller.setFontSize(SettingsWindowController.defaultFontSize)
    controller.setRelativeDates(true)
    controller.setLineNumbers(true)
    controller.setHighlightsCurrentLine(true)
    controller.setWrapsLines(true)
    controller.showNotes()
    pump()
    save(controller.panel.contentView!.superview!, "screenshot-\(suffix)")
    controller.panel.orderOut(nil)
}
