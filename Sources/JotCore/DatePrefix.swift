import Foundation

/// The optional `yyyy-mm-dd-` at the start of a Note's filename: the local day
/// the Note was created. See ADR 0003.
public enum DatePrefix {
    /// `2026-10-08-` for any time on that local day.
    public static func string(for date: Date, calendar: Calendar = .current) -> String {
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d-", day.year ?? 0, day.month ?? 0, day.day ?? 0)
    }

    /// The Date Prefix of a Note's filename, if it has one. A leading date that
    /// is just where the Title's own name starts (Title `2026-10-08 meeting`,
    /// file `2026-10-08-meeting.md`) is part of the name, not a prefix.
    static func of(fileName: String, titleSlug: String) -> String? {
        let stem = fileName.hasSuffix(".md") ? String(fileName.dropLast(3)) : fileName
        let prefix = String(stem.prefix(11))
        guard stem.count > 11, day(of: prefix) != nil, !isName(stem, of: titleSlug) else { return nil }
        return prefix
    }

    /// Local midnight of the prefix's day; `nil` if it isn't a valid `yyyy-mm-dd-`.
    static func day(of prefix: String, calendar: Calendar = .current) -> Date? {
        let parts = prefix.split(separator: "-", omittingEmptySubsequences: false)
        guard prefix.count == 11, prefix.hasSuffix("-"), parts.count == 4,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts[0...2].allSatisfy({ $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) }),
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              calendar.dateComponents([.year, .month, .day], from: date) == DateComponents(year: year, month: month, day: day)
        else { return nil }
        return date
    }

    /// `stem` is `slug` or `slug-N`, a name given for that Title without a prefix.
    private static func isName(_ stem: String, of slug: String) -> Bool {
        guard stem.hasPrefix(slug) else { return false }
        let rest = stem.dropFirst(slug.count)
        return rest.isEmpty || (rest.first == "-" && rest.count > 1 && rest.dropFirst().allSatisfy { $0.isASCII && $0.isNumber })
    }
}
