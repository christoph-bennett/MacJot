import Foundation

/// A row of the Note List: what identifies a Note at a glance.
public struct NoteSummary: Equatable {
    public let url: URL
    /// The Title without its Markdown (`# **Plan**` → `Plan`); "Untitled" if there is none.
    public let title: String
    /// The first non-blank line after the Title, without its Markdown. While
    /// searching, the snippet around the match instead.
    public let preview: String
    public let modified: Date
    /// From the Date Prefix if the filename has one, else the file's creation date.
    public let created: Date
    /// What search looks at, held in memory (the in-memory Search Index).
    private let content: Content

    init(url: URL, text: String, modified: Date, created: Date) {
        self.url = url
        self.modified = modified
        self.created = created
        content = Content(text)
        title = content.title ?? "Untitled"
        preview = String((content.lines.first ?? "").prefix(Self.previewLength))
    }

    private init(_ note: NoteSummary, preview: String) {
        url = note.url
        title = note.title
        modified = note.modified
        created = note.created
        content = note.content
        self.preview = preview
    }

    private static let previewLength = 200

    /// The Title of `text` without its Markdown, as the Note List shows it; `nil`
    /// if there is no Title (yet). For a Draft, which has no summary of its own.
    public static func displayTitle(of text: String) -> String? {
        let ns = text as NSString
        guard let line = NoteStructure(ns).titleLine else { return nil }
        let title = plain(ns, line: line)
        return title.isEmpty ? nil : title
    }

    // MARK: Search

    /// A Note's text as search sees it: the Title and the non-blank lines after
    /// it, without their Markdown. Frontmatter isn't searched.
    private struct Content: Equatable {
        var title: String?
        var lines: [String] = []

        init(_ text: String) {
            let ns = text as NSString
            guard let titleLine = NoteStructure(ns).titleLine else { return }
            let title = NoteSummary.plain(ns, line: titleLine)
            self.title = title.isEmpty ? nil : title
            let rest = NSRange(location: NSMaxRange(titleLine), length: ns.length - NSMaxRange(titleLine))
            var lines: [String] = []
            ns.enumerateSubstrings(in: rest, options: .byLines) { line, range, _, _ in
                guard let line, !line.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                lines.append(NoteSummary.plain(ns, line: range))
            }
            self.lines = lines
        }

        enum Match { case title, line(String, Range<String.Index>) }

        /// The first body line containing `query`, else the Title. Body first: a
        /// snippet shows why the Note matched, the Title is on screen anyway.
        func match(_ query: String) -> Match? {
            for line in lines {
                if let range = line.range(of: query, options: NoteSummary.searchOptions) { return .line(line, range) }
            }
            return title?.range(of: query, options: NoteSummary.searchOptions) != nil ? .title : nil
        }
    }

    /// This Note as a search result: `nil` if neither its Title nor its body
    /// contains `query` (ignoring case, diacritics and Markdown). A body match
    /// becomes the preview, so the row shows why the Note matched. A blank query
    /// matches every Note unchanged.
    public func matching(_ query: String) -> NoteSummary? {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return self }
        switch content.match(query) {
        case nil: return nil
        case .title: return self
        case .line(let line, let range): return NoteSummary(self, preview: Self.snippet(line, around: range))
        }
    }

    /// Whether a Draft's `text` matches `query`, as a Note with it would.
    public static func matches(_ query: String, text: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty || Content(text).match(query) != nil
    }

    private static let searchOptions: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

    /// The line, starting a few words before the match if it sits far into the line.
    private static func snippet(_ line: String, around match: Range<String.Index>) -> String {
        let lead = 20
        guard line.distance(from: line.startIndex, to: match.lowerBound) > lead + 10 else {
            return String(line.prefix(previewLength))
        }
        var start = line.index(match.lowerBound, offsetBy: -lead)
        if let space = line[start..<match.lowerBound].firstIndex(of: " ") { start = line.index(after: space) }
        return "…" + line[start...].prefix(previewLength)
    }

    /// The line with its Markdown markers removed, as the editor would dim them.
    private static func plain(_ ns: NSString, line: NSRange) -> String {
        let text = ns as String
        let markers = MarkdownStyle.spans(in: text, range: line)
            .filter(\.isSyntax)
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
