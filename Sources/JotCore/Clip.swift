import Foundation

/// The pure parts of a Clip (ticket 47, spec 0002): a Note made from text taken
/// from somewhere else. The Notes Folder writes it (`NotesFolder.createClip`).
public enum Clip {
    /// The text as the Note's body, or `nil` if nothing is left. Leading blank lines
    /// and lines without a letter or digit (a terminal's box-drawing rule, a bullet,
    /// an emoji on its own) are dropped, so the Title is the first real line, and that
    /// line loses its leading whitespace. The rest is kept as it is.
    public static func body(from text: String) -> String? {
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
        guard let first = lines.firstIndex(where: hasLetterOrDigit) else { return nil }
        var rest = Array(lines[first...])
        rest[0] = rest[0].drop { $0 == " " || $0 == "\t" }
        return rest.joined(separator: "\n")
    }

    private static func hasLetterOrDigit(_ line: Substring) -> Bool {
        line.unicodeScalars.contains { CharacterSet.alphanumerics.contains($0) }
    }

    /// The YAML frontmatter block, with its fences and a line break after the
    /// closing one: `created` (ISO 8601, local time with offset, seconds), then
    /// `source`, `page` and `url` when given. Unknown values are left out.
    public static func frontmatter(created: Date, source: String?, page: String?, url: String? = nil,
                                   timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssxxx"
        var lines = ["---", "created: \(formatter.string(from: created))"]
        if let source = value(source) { lines.append("source: \(source)") }
        if let page = value(page) { lines.append("page: \(page)") }
        if let url = value(url) { lines.append("url: \(url)") }
        lines.append("---")
        return lines.joined(separator: "\n") + "\n"
    }

    /// A value as YAML needs it written: on one line, trimmed, double-quoted only
    /// if a plain scalar would be read differently; `nil` if nothing is left.
    private static func value(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let value = raw.components(separatedBy: .newlines).joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return nil }
        return needsQuotes(value) ? "\"" + value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"") + "\"" : value
    }

    private static func needsQuotes(_ value: String) -> Bool {
        if "-?:,[]{}#&*!|>'\"%@`".contains(value.first!) { return true }
        if value.hasSuffix(":") || value.contains(": ") || value.contains(" #") { return true }
        if value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) { return true }
        if ["true", "false", "null", "yes", "no", "on", "off", "y", "n", "~"].contains(value.lowercased()) { return true }
        return Double(value) != nil  // would be read as a number
    }
}
