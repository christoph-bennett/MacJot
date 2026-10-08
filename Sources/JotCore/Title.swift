import Foundation

/// The Title is the first non-blank line of a Note, after any frontmatter.
enum Title {
    static let maxSlugLength = 60

    /// Whether the text has no content at all. Frontmatter counts as content,
    /// so a Note can be non-blank yet have no Title.
    static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The first non-blank line after any frontmatter, trimmed; `nil` if there is none.
    static func of(_ text: String) -> String? {
        let ns = text as NSString
        return NoteStructure(ns).titleLine.map { ns.substring(with: $0).trimmingCharacters(in: .whitespaces) }
    }

    /// Whether the Title line is complete, i.e. a line break follows it.
    static func isFinished(_ text: String) -> Bool {
        let ns = text as NSString
        return NoteStructure(ns).titleLine.map { NSMaxRange($0) < ns.length } ?? false
    }

    /// Filename stem derived from a Title: leading Markdown ignored, Latin
    /// accents transliterated (`Ü` → `U`, `ß` → `ss`), other non-ASCII dropped,
    /// lowercase letters and digits joined by single hyphens, cut to
    /// `maxSlugLength` at a word boundary, `untitled` if nothing remains.
    static func slug(_ title: String) -> String {
        let plain = withoutLeadingMarkdown(title).precomposedStringWithCanonicalMapping
        let ascii = plain.applyingTransform(StringTransform("Latin-ASCII"), reverse: false) ?? plain

        var words: [String] = []
        var word = ""
        for scalar in ascii.lowercased().unicodeScalars {
            if scalar.isASCII, CharacterSet.alphanumerics.contains(scalar) {
                word.unicodeScalars.append(scalar)
            } else if !word.isEmpty {
                words.append(word)
                word = ""
            }
        }
        if !word.isEmpty { words.append(word) }

        var slug = ""
        for word in words {
            let next = slug.isEmpty ? word : "\(slug)-\(word)"
            if next.count > maxSlugLength {
                // A single overlong first word is truncated rather than dropped.
                if slug.isEmpty { slug = String(word.prefix(maxSlugLength)) }
                break
            }
            slug = next
        }
        return slug.isEmpty ? "untitled" : slug
    }

    /// Strips block-level prefixes, repeatedly: `> - [ ] # Plan` → `Plan`.
    /// Inline markers (`**`, `_`, `` ` ``) need no special handling: the slug
    /// treats them as separators.
    private static func withoutLeadingMarkdown(_ title: String) -> Substring {
        let prefix = /^\s*(?:>|#{1,6}(?=\s)|[-*+](?=\s)|\d+[.)](?=\s)|\[[ xX]\](?=\s))\s*/
        var rest = Substring(title)
        while let match = rest.prefixMatch(of: prefix), !match.output.isEmpty {
            rest = rest[match.range.upperBound...]
        }
        return rest
    }
}

/// How a Note's text is laid out: its frontmatter and its Title line. The one
/// place these rules live; `Title`, the editing commands and the styler all use it.
/// Ranges are UTF-16, line ranges exclude the line break.
struct NoteStructure {
    enum Frontmatter: Equatable {
        case none
        /// `---` on the first line, no closing fence and no blank line yet: still being typed.
        case open(NSRange)
        /// From the opening fence to the end of the closing `---` (or `...`).
        case closed(NSRange)
    }

    let frontmatter: Frontmatter
    let titleLine: NSRange?

    /// A `---` first line that a blank line ends before any closing fence is a
    /// horizontal rule, not frontmatter; the Title is then sought after that line.
    init(_ ns: NSString) {
        var frontmatter = Frontmatter.none
        var titleLine: NSRange?
        var lineIndex = 0
        var inFence = false
        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length), options: .byLines) { line, range, _, stop in
            defer { lineIndex += 1 }
            let trimmed = (line ?? "").trimmingCharacters(in: .whitespaces)
            if lineIndex == 0, trimmed == "---" {
                inFence = true
                frontmatter = .open(NSRange(location: 0, length: ns.length))
                return
            }
            if inFence {
                if trimmed == "---" || trimmed == "..." {
                    frontmatter = .closed(NSRange(location: 0, length: NSMaxRange(range)))
                    inFence = false
                    titleLine = nil
                } else if trimmed.isEmpty {
                    // A rule after all: the lines after the `---` are the body.
                    frontmatter = .none
                    inFence = false
                } else if titleLine == nil {
                    titleLine = range  // only counts if the block turns out to be a rule
                }
                return
            }
            if !trimmed.isEmpty {
                titleLine = titleLine ?? range
                stop.pointee = true
            }
        }
        if inFence { titleLine = nil }  // still open: no Title yet
        self.frontmatter = frontmatter
        self.titleLine = titleLine
    }
}
