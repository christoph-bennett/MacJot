import Foundation

enum Title {
    static let maxSlugLength = 60

    /// The first non-blank line of a Note's text, trimmed; `nil` if the text is blank.
    static func of(_ text: String) -> String? {
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }

    /// Filename stem derived from a Title: lowercase ASCII letters and digits,
    /// everything else collapsed to single hyphens, cut to `maxSlugLength` at a
    /// word boundary, `untitled` if nothing remains.
    static func slug(_ title: String) -> String {
        var words: [String] = []
        var word = ""
        for scalar in title.lowercased().unicodeScalars {
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
}
