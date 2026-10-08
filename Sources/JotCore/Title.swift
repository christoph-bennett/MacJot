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
        let lines = bodyLines(of: text)
        return lines.firstIndex(where: isNonBlank).map { trimmed(lines[$0]) }
    }

    /// Whether the Title line is complete, i.e. a line break follows it.
    static func isFinished(_ text: String) -> Bool {
        let lines = bodyLines(of: text)
        guard let index = lines.firstIndex(where: isNonBlank) else { return false }
        return index < lines.index(before: lines.endIndex)
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

    /// The text's lines after a leading YAML frontmatter block, if there is one.
    /// The last element is the unterminated final line (empty if the text ends
    /// with a line break). While the frontmatter is still open (no closing fence
    /// yet) there are no body lines, so no Title.
    private static func bodyLines(of text: String) -> ArraySlice<Substring> {
        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        guard let first = lines.first, trimmed(first) == "---" else { return lines[...] }
        guard let close = lines.dropFirst().firstIndex(where: { ["---", "..."].contains(trimmed($0)) })
        else { return [] }
        return lines[(close + 1)...]
    }

    private static func isNonBlank(_ line: Substring) -> Bool { !trimmed(line).isEmpty }

    private static func trimmed(_ line: Substring) -> String {
        line.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
