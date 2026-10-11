import Foundation
import JotCore

// Times loading and searching generated Notes (ticket 40) with JotCore's own
// code: `NotesFolder.notes()` as the Note List loads, `NoteSummary.matching`
// as it filters on every keystroke. Run through scripts/benchmark-search.sh,
// which provides the temporary folder and removes it, also after an error or Ctrl-C.

let loadLimit = Duration.seconds(1)
let searchLimit = Duration.milliseconds(50)
let arguments = Array(CommandLine.arguments.dropFirst())
let counts = arguments.compactMap { Int($0) }.filter { $0 > 0 }
guard counts.count == arguments.count else {
    FileHandle.standardError.write(Data("usage: benchmark-search.sh [number of Notes …]\n".utf8))
    exit(64)
}
/// Ascending: each size adds Notes to the previous one's folder.
let sizes = Set(counts.isEmpty ? [1_000, 5_000, 10_000] : counts).sorted()

/// The same Notes on every run, so runs can be compared.
struct SplitMix {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func below(_ n: Int) -> Int { Int(next() % UInt64(n)) }
    mutating func pick<T>(_ items: [T]) -> T { items[below(items.count)] }
}

let english = """
    the a of to and in for with on project meeting plan idea call email note list review draft client team \
    week today tomorrow budget design write check follow ask send update notes book read buy price order \
    time date question answer reason result change start finish open close travel trip home office
    """.split(separator: " ").map(String.init)
let german = """
    der die das und zu mit für auf im ein eine nicht Termin Besprechung Kunde Angebot Projekt Woche heute \
    morgen Frage Antwort Liste Entwurf prüfen schreiben senden fertig offen Einkauf Preis Reise Büro Zeit \
    Ergebnis Änderung Grund Bestellung Buch lesen Idee Plan Notiz Aufgabe Straße größer Übersicht
    """.split(separator: " ").map(String.init)
let code = ["let total = items.reduce(0, +)", "for file in files { print(file) }", "git log --oneline -5",
            "SELECT * FROM notes;", "if done { return }"]

/// Words the queries look for, planted in a known share of the Notes; the
/// generated text never contains them otherwise.
enum Plant {
    static let word = "quarterly"          // one word, in a body line
    static let pair = ["Kowalski", "invoice"]  // several words, in different lines
    static let phrase = "oat milk friday"  // an exact phrase
}

struct Planted { var word = 0, pair = 0, phrase = 0 }

/// One Note: a Title, paragraphs, some headings, lists and a fenced code
/// block; 200 B to 20 KB, most around 2 KB (log-normal).
func makeNote(_ rng: inout SplitMix, _ index: Int, _ planted: inout Planted) -> String {
    let words = rng.unit() < 0.4 ? german : english
    func sentence(_ n: Int) -> String {
        var s = (0..<n).map { _ in rng.pick(words) }.joined(separator: " ")
        s = s.prefix(1).uppercased() + s.dropFirst()
        return s + "."
    }
    let gaussian = sqrt(-2 * log(max(rng.unit(), 1e-12))) * cos(2 * .pi * rng.unit())
    let target = min(20_000, max(200, Int(2_000 * exp(0.8 * gaussian))))

    var lines = ["# " + sentence(3 + rng.below(4)).dropLast() + " \(index)", ""]
    var extras: [String] = []
    if rng.unit() < 0.10 { extras.append("Prepare the \(Plant.word) report."); planted.word += 1 }
    if rng.unit() < 0.05 {
        extras.append("Call \(Plant.pair[0]) back.")
        extras.append("The \(Plant.pair[1]) is still open.")
        planted.pair += 1
    }
    if rng.unit() < 0.05 { extras.append("Remember \(Plant.phrase) at the market."); planted.phrase += 1 }

    var length = lines.joined(separator: "\n").utf8.count
    while length < target {
        let block: [String]
        switch rng.below(10) {
        case 0: block = ["## " + sentence(2 + rng.below(3)).dropLast()]
        case 1, 2: block = (0..<(2 + rng.below(4))).map { _ in "- " + sentence(3 + rng.below(6)) }
        case 3 where rng.unit() < 0.3: block = ["```"] + (0..<(1 + rng.below(4))).map { _ in rng.pick(code) } + ["```"]
        default: block = [(0..<(1 + rng.below(4))).map { _ in sentence(6 + rng.below(12)) }.joined(separator: " ")]
        }
        lines += block + [""]
        if let extra = extras.popLast() { lines += [extra, ""] }
        length += block.joined(separator: "\n").utf8.count + 2
    }
    lines += extras  // short Notes still get theirs
    return lines.joined(separator: "\n") + "\n"
}

func time(_ work: () throws -> Void) rethrows -> Duration {
    let clock = ContinuousClock()
    let start = clock.now
    try work()
    return clock.now - start
}

func ms(_ d: Duration) -> String {
    let c = d.components
    return String(format: "%.1f ms", Double(c.seconds) * 1_000 + Double(c.attoseconds) / 1e15)
}

func median(_ ds: [Duration]) -> Duration { ds.sorted()[ds.count / 2] }

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("benchmark-search: \(message)\n".utf8))
    exit(1)
}

var allPass = true
@MainActor func verdict(_ d: Duration, _ limit: Duration) -> String {
    if d > limit { allPass = false; return "FAIL" }
    return "ok"
}

guard let work = ProcessInfo.processInfo.environment["JOT_BENCHMARK_DIR"] else {
    fail("run it through scripts/benchmark-search.sh, which provides the temporary folder")
}
let base = URL(fileURLWithPath: work)
let folder = base.appendingPathComponent("Notes")
do {
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
} catch { fail("can't create \(folder.path): \(error)") }

// One seed for all sizes: each size is the previous one plus more Notes.
var rng = SplitMix(state: 40)
var planted = Planted()
var bytes = 0
var written = 0

for count in sizes {
    while written < count {
        written += 1
        let text = makeNote(&rng, written, &planted)
        bytes += text.utf8.count
        do {
            try Data(text.utf8).write(to: folder.appendingPathComponent("note-\(written).md"))
        } catch { fail("can't write a Note: \(error)") }
    }

    func openFolder() throws -> NotesFolder {
        try NotesFolder(url: folder, recoveryURL: base.appendingPathComponent("recovery.md"), trash: { _ in })
    }

    // Load: a fresh NotesFolder reads and summarises every file, as at launch or
    // after the Notes Folder changed. The files are in the disk cache by now;
    // a real first launch after a restart may be slower.
    var notes: [NoteSummary] = []
    var loads: [Duration] = []
    var reloads: [Duration] = []
    do {
        for _ in 0..<3 {
            let notesFolder = try openFolder()
            loads.append(try time { notes = try notesFolder.notes() })
            // Reload: what follows every autosave; unchanged files aren't read again.
            reloads.append(try time { _ = try notesFolder.notes() })
        }
    } catch { fail("loading failed: \(error)") }
    guard notes.count == count else { fail("listed \(notes.count) Notes, expected \(count)") }

    // Search: the Note List's filter, as on each keystroke. Only the matching;
    // the Note List's own work (rows, reloading the table) comes on top.
    let queries: [(name: String, query: String, expected: Int?)] = [
        ("one word", Plant.word, planted.word),
        ("several words", Plant.pair.joined(separator: " "), planted.pair),
        ("phrase", "\"\(Plant.phrase)\"", planted.phrase),
        ("no match", "zqxvbn", 0),
        ("common word", "plan", nil),
    ]
    print("\n\(count) Notes, \(bytes / count) B on average, \(bytes / 1_000_000) MB in all")
    let load = median(loads)
    print("  load            \(ms(load).padding(toLength: 10, withPad: " ", startingAt: 0)) median of 3, limit 1 s: \(verdict(load, loadLimit))")
    print("  reload          \(ms(median(reloads)).padding(toLength: 10, withPad: " ", startingAt: 0)) median of 3 (after each autosave; no limit set)")
    for q in queries {
        var found = 0
        let search = { time { let query = SearchQuery.Folded(q.query); found = notes.compactMap { $0.matching(query) }.count } }
        var runs = [search()]
        // Far over the limit, a few runs tell enough.
        let repeats = runs[0] > searchLimit * 10 ? 3 : 15
        while runs.count < repeats { runs.append(search()) }
        if let expected = q.expected, found != expected {
            fail("\(q.name) found \(found) Notes, expected \(expected)")
        }
        let m = median(runs)
        let label = "  \(q.name)".padding(toLength: 18, withPad: " ", startingAt: 0)
        print("\(label)\(ms(m).padding(toLength: 10, withPad: " ", startingAt: 0)) median of \(runs.count), max \(ms(runs.max()!)), \(found) found, limit 50 ms: \(verdict(m, searchLimit))")
    }
}

print(allPass ? "\nAll within the limits." : "\nSome results are over the limits.")
exit(allPass ? 0 : 2)
