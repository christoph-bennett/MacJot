import AppKit
import JotCore

let trials = Int(CommandLine.arguments.dropFirst().first ?? "") ?? 100
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
@MainActor func pump(_ s: Double = 0.02) { RunLoop.main.run(until: Date().addingTimeInterval(s)) }

let base = FileManager.default.temporaryDirectory.appendingPathComponent("MacJot Gutter Harness")
try? FileManager.default.removeItem(at: base)
try! FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
let note = "---\nsource: Safari\npage: Example\ncreated: today\n---\nTitle\n\nFirst paragraph\n\n- one\n- two\n\nLast line\n"
try! note.write(to: base.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)
let recovery = FileManager.default.temporaryDirectory.appendingPathComponent("macjot-gutter-recovery.md")
let folder = try! NotesFolder(url: base, recoveryURL: recovery) { _ in }
let controller = CapturePanelController(folder: folder)
controller.setLineNumbers(true)
controller.setWrapsLines(true)
controller.showNotes()
pump(0.4)
let tv = controller.textView

/// What the gutter draws: each row's line number and baseline, as LineNumberGutter.draw finds them.
@MainActor func drawn() -> [(number: Int, y: CGFloat)] {
    guard let lm = tv.layoutManager, let container = tv.textContainer else { return [] }
    let lines = LineNumbers(tv.string)
    lm.ensureLayout(for: container)
    var out: [(Int, CGFloat)] = []
    let glyphs = lm.glyphRange(for: container)
    var index = glyphs.location
    while index < NSMaxRange(glyphs) {
        var row = NSRange()
        let rect = lm.lineFragmentRect(forGlyphAt: index, effectiveRange: &row)
        let ch = lm.characterIndexForGlyph(at: row.location)
        if let n = lines.number(ofLineStartingAt: ch) { out.append((n, rect.minY)) }
        index = NSMaxRange(row)
    }
    return out
}

@MainActor func check(_ step: String) -> String? {
    let rows = drawn()
    for (a, b) in zip(rows, rows.dropFirst()) {
        if b.number != a.number + 1 { return "\(step): numbers \(a.number) then \(b.number)" }
        if b.y - a.y < 8 { return "\(step): numbers \(a.number) and \(b.number) overlap (\(a.y), \(b.y))" }
    }
    return nil
}

var failures: [String] = []
var rng = SystemRandomNumberGenerator()
let words = ["alpha", "created", "x", "---", "- item", "[ ]", "Safari"]
for trial in 1...trials {
    tv.string = note
    controller.perform(#selector(CapturePanelController.showNotes))
    var log = "trial \(trial)"
    for _ in 0..<15 {
        let len = (tv.string as NSString).length
        let loc = Int.random(in: 0...len, using: &rng)
        tv.setSelectedRange(NSRange(location: loc, length: 0))
        let op = Int.random(in: 0..<6, using: &rng)
        switch op {
        case 0: tv.doCommand(by: #selector(NSResponder.insertNewline(_:))); log += " ret"
        case 1: tv.doCommand(by: #selector(NSResponder.deleteBackward(_:))); log += " bs"
        case 2: let w = words.randomElement(using: &rng)!; tv.insertText(w, replacementRange: tv.selectedRange()); log += " type(\(w))"
        case 3, 4: controller.toggleFrontmatter(); log += " toggle"
        default: tv.selectAll(nil); tv.doCommand(by: #selector(NSResponder.deleteBackward(_:))); tv.insertText("x\n\ny", replacementRange: tv.selectedRange()); log += " selall"
        }
        pump()
        if let f = check(log) { failures.append(f); break }
    }
}
let sample = drawn()
print("last state: \(sample.count) numbered rows, 1..\(sample.last?.number ?? 0)")
print("\(trials) trials, \(failures.count) failing")
failures.prefix(5).forEach { print($0) }
exit(failures.isEmpty ? 0 : 1)
