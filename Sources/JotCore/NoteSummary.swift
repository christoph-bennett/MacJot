import Foundation

/// A row of the Note List: what identifies a Note at a glance.
public struct NoteSummary: Equatable {
    public let url: URL
    /// The Title without its Markdown (`# **Plan**` → `Plan`); "Untitled" if there is none.
    public let title: String
    /// The first non-blank line after the Title, without its Markdown. While
    /// searching, the snippet around the match instead. Cut when asked for: a
    /// search can match thousands of Notes, the Note List shows a few (ticket 41).
    public var preview: String {
        guard let found else { return String((content.lines.first ?? "").prefix(Self.previewLength)) }
        let line = content.lines[found.line]
        return Self.snippet(line, around: Self.index(in: line, atFolded: found.offset))
    }
    public let modified: Date
    /// What search looks at, held in memory (the in-memory Search Index).
    private let content: Content
    /// Where in which body line a search found its first term, for the preview;
    /// `nil` outside a search or when only the Title matched.
    private let found: Found?

    private struct Found: Equatable {
        let line: Int
        /// In the line's folded UTF-8.
        let offset: Int
    }

    init(url: URL, text: String, modified: Date) {
        self.url = url
        self.modified = modified
        content = Content(text)
        title = content.title ?? "Untitled"
        found = nil
    }

    private init(_ note: NoteSummary, found: Found) {
        url = note.url
        title = note.title
        modified = note.modified
        content = note.content
        self.found = found
    }

    private static let previewLength = 200

    /// The Title of `text` without its Markdown, as the Note List shows it; `nil`
    /// if there is no Title (yet). For a Draft, which has no summary of its own.
    public static func displayTitle(of text: String) -> String? {
        let ns = text as NSString
        guard let line = NoteStructure(ns).titleLine else { return nil }
        let title = plain(ns, line: line, codeBlocks: MarkdownStyle.codeBlocks(in: text))
        return title.isEmpty ? nil : title
    }

    // MARK: Search

    /// A Note's text as search sees it: the Title and the non-blank lines after
    /// it, without their Markdown. Frontmatter isn't searched.
    private struct Content: Equatable {
        var title: String?
        var lines: [String] = []
        /// The Title and lines folded once (`SearchQuery.fold`), as UTF-8, each
        /// ended by a NUL so no match spans two lines: what each keystroke
        /// searches (ticket 41).
        private var folded: [UInt8] = []
        /// Where each NUL in `folded` is: the Title's first, then each line's.
        private var ends: [Int] = []

        init(_ text: String) {
            let ns = text as NSString
            guard let titleLine = NoteStructure(ns).titleLine else { return }
            let blocks = MarkdownStyle.codeBlocks(in: text)  // once, not for every line
            let title = NoteSummary.plain(ns, line: titleLine, codeBlocks: blocks)
            self.title = title.isEmpty ? nil : title
            let rest = NSRange(location: NSMaxRange(titleLine), length: ns.length - NSMaxRange(titleLine))
            var lines: [String] = []
            ns.enumerateSubstrings(in: rest, options: .byLines) { line, range, _, _ in
                guard let line, !line.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                lines.append(NoteSummary.plain(ns, line: range, codeBlocks: blocks))
            }
            self.lines = lines
            for line in [self.title ?? ""] + lines {
                folded += SearchQuery.fold(line).utf8
                ends.append(folded.count)
                folded.append(0)
            }
        }

        enum Match { case title, line(Int, offset: Int) }

        /// Nil unless every term is in the Title or a body line (ticket 37). Then
        /// the first body line containing the first term found in the body, else
        /// the Title. Body first: a snippet shows why the Note matched, the Title
        /// is on screen anyway.
        func match(_ query: SearchQuery.Folded) -> Match? {
            guard query.folded.allSatisfy({ offset(of: $0, from: 0) != nil }) else { return nil }
            for term in query.folded {
                if let hit = offset(of: term, from: ends[0] + 1) {
                    let line = lineIndex(at: hit)
                    return .line(line, offset: hit - (ends[line] + 1))
                }
            }
            return .title
        }

        /// Where `term` first is in `folded`, at or after `start`.
        private func offset(of term: [UInt8], from start: Int) -> Int? {
            folded.withUnsafeBytes { text in
                term.withUnsafeBytes { term in
                    guard start < text.count, let base = text.baseAddress,
                          let hit = memmem(base + start, text.count - start, term.baseAddress, term.count)
                    else { return nil }
                    return base.distance(to: UnsafeRawPointer(hit))
                }
            }
        }

        /// The body line (index into `lines`) that `offset` in `folded` falls in.
        private func lineIndex(at offset: Int) -> Int {
            var low = 1, high = ends.count - 1  // ends[0] is the Title's
            while low < high {
                let mid = (low + high) / 2
                if ends[mid] < offset { low = mid + 1 } else { high = mid }
            }
            return low - 1
        }
    }

    /// This Note as a search result: `nil` unless every word or "phrase" of
    /// `query` is in its Title or body (`SearchQuery`; ignoring case, diacritics
    /// and Markdown). A body match
    /// becomes the preview, so the row shows why the Note matched. A blank query
    /// matches every Note unchanged.
    public func matching(_ query: String) -> NoteSummary? {
        matching(SearchQuery.Folded(query))
    }

    /// The same, with the query folded once for all Notes, as the Note List does
    /// on each keystroke.
    public func matching(_ query: SearchQuery.Folded) -> NoteSummary? {
        guard !query.terms.isEmpty else { return self }
        switch content.match(query) {
        case nil: return nil
        case .title: return self
        case .line(let line, let offset): return NoteSummary(self, found: Found(line: line, offset: offset))
        }
    }

    /// Whether a Draft's `text` matches `query`, as a Note with it would.
    /// Whether the open Draft gets a row in the Note List: once it has text
    /// (a blank one would hide "No Notes"), and while it matches the search.
    public static func listsDraft(_ text: String, query: String) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && matches(query, text: text)
    }

    public static func matches(_ query: String, text: String) -> Bool {
        let query = SearchQuery.Folded(query)
        return query.terms.isEmpty || Content(text).match(query) != nil
    }

    fileprivate static let searchOptions: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

    /// The line, starting a few words before the match if it sits far into the line.
    private static func snippet(_ line: String, around match: String.Index) -> String {
        let lead = 20
        guard line.distance(from: line.startIndex, to: match) > lead + 10 else {
            return String(line.prefix(previewLength))
        }
        var start = line.index(match, offsetBy: -lead)
        if let space = line[start..<match].firstIndex(of: " ") { start = line.index(after: space) }
        return "…" + line[start...].prefix(previewLength)
    }

    /// The character of `line` that byte `offset` of its folded form came from.
    private static func index(in line: String, atFolded offset: Int) -> String.Index {
        var folded = 0
        for index in line.indices {
            folded += SearchQuery.fold(String(line[index])).utf8.count
            if folded > offset { return index }
        }
        return line.endIndex
    }

    /// The line with its Markdown markers removed, as the editor would dim them.
    private static func plain(_ ns: NSString, line: NSRange, codeBlocks: [NSRange]) -> String {
        let text = ns as String
        let markers = MarkdownStyle.spans(in: text, range: line, codeBlocks: codeBlocks)
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

extension SearchQuery {
    /// A query's terms, also folded, ready to be searched for in every Note.
    public struct Folded {
        let terms: [String]
        /// As UTF-8, to compare with each Note's folded text.
        let folded: [[UInt8]]

        public init(_ query: String) {
            // A term that folds to nothing (a lone accent) would match everything.
            let pairs = SearchQuery.terms(query).map { ($0, Array(SearchQuery.fold($0).utf8)) }.filter { !$0.1.isEmpty }
            terms = pairs.map(\.0)
            folded = pairs.map(\.1)
        }
    }

    /// Text as search compares it: case and accents removed (`ß` becomes `ss`,
    /// `ü` and `u` with a separate accent both `u`, `ﬁ` becomes `fi`), so a plain
    /// byte comparison matches what a case- and accent-blind one would.
    static func fold(_ text: String) -> String {
        text.folding(options: NoteSummary.searchOptions, locale: nil)
    }
}
