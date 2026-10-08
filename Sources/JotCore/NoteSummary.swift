import Foundation

/// A row of the Note List: what identifies a Note at a glance.
public struct NoteSummary: Equatable {
    public let url: URL
    /// The Title without its Markdown (`# **Plan**` → `Plan`); "Untitled" if there is none.
    public let title: String
    /// The first non-blank line after the Title, without its Markdown.
    public let preview: String
    public let modified: Date

    init(url: URL, text: String, modified: Date) {
        self.url = url
        self.modified = modified
        let ns = text as NSString
        guard let titleLine = NoteStructure(ns).titleLine else {
            title = "Untitled"
            preview = ""
            return
        }
        let title = Self.plain(ns, line: titleLine)
        self.title = title.isEmpty ? "Untitled" : title

        var preview = ""
        let rest = NSRange(location: NSMaxRange(titleLine), length: ns.length - NSMaxRange(titleLine))
        ns.enumerateSubstrings(in: rest, options: .byLines) { line, range, _, stop in
            guard let line, !line.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            preview = Self.plain(ns, line: range)
            stop.pointee = true
        }
        self.preview = String(preview.prefix(200))
    }

    /// The line with its Markdown markers removed, as the editor would dim them.
    private static func plain(_ ns: NSString, line: NSRange) -> String {
        let text = ns as String
        let markers = MarkdownStyle.spans(in: text, range: line)
            .filter { $0.kind == .marker }
            .map(\.range)
            .sorted { $0.location > $1.location }
        let plain = NSMutableString(string: ns.substring(with: line))
        for marker in markers where NSLocationInRange(marker.location, line) {
            let local = NSRange(location: marker.location - line.location,
                                length: min(marker.length, NSMaxRange(line) - marker.location))
            plain.replaceCharacters(in: local, with: "")
        }
        return (plain as String).trimmingCharacters(in: .whitespaces)
    }
}
