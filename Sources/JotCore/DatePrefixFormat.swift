import Foundation

/// The Date Prefix Format (GLOSSARY, ticket 38, ADR 0009): the elements a Note's
/// Date Prefix is written from, in order. Nothing is required; an empty format
/// writes no prefix. Stored as JSON.
public struct DatePrefixFormat: Codable, Equatable, Sendable {
    public enum Element: Codable, Equatable, Hashable, Sendable {
        case year(Year)
        case month(Month)
        case day(Day)
        case separator(Separator)
    }

    /// Each element's options; the first case is its default.
    public enum Year: String, Codable, CaseIterable, Sendable { case full, short }
    public enum Month: String, Codable, CaseIterable, Sendable { case number, unpadded, shortName, fullName }
    public enum Day: String, Codable, CaseIterable, Sendable { case number, unpadded }
    public enum Separator: String, Codable, CaseIterable, Sendable {
        case hyphen = "-", underscore = "_", dot = ".", space = " "
    }

    public var elements: [Element]

    public init(_ elements: [Element]) {
        self.elements = elements
    }

    /// `2026-10-09-`: the fixed prefix from before the format could be configured.
    public static let standard = DatePrefixFormat([
        .year(.full), .separator(.hyphen), .month(.number), .separator(.hyphen), .day(.number), .separator(.hyphen),
    ])

    /// The prefix for `date`'s local day. Month names come from `locale`, made
    /// filename-friendly (`monthNames`); where they aren't available, the number.
    public func string(for date: Date, locale: Locale = .current, calendar: Calendar = .current) -> String {
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        let year = day.year ?? 0, month = day.month ?? 1, dayOfMonth = day.day ?? 1
        return elements.map { element -> String in
            switch element {
            case .year(.full): String(format: "%04d", year)
            case .year(.short): String(format: "%02d", year % 100)
            case .month(let style): Self.month(month, style, locale: locale)
            case .day(.number): String(format: "%02d", dayOfMonth)
            case .day(.unpadded): String(dayOfMonth)
            case .separator(let separator): separator.rawValue
            }
        }.joined()
    }

    /// `month` (1–12) in `style`; a name style falls back to the number where
    /// `locale` has no names MacJot can use.
    private static func month(_ month: Int, _ style: Month, locale: Locale) -> String {
        switch style {
        case .number: String(format: "%02d", month)
        case .unpadded: String(month)
        case .shortName, .fullName:
            monthNames(in: locale, short: style == .shortName)?[month - 1] ?? String(format: "%02d", month)
        }
    }

    /// The pattern `month(_:_:locale:)` writes, for recognising a prefix.
    private static func monthPattern(_ style: Month, locale: Locale) -> String {
        switch style {
        case .number: #"\d{2}"#
        case .unpadded: #"\d{1,2}"#
        case .shortName, .fullName:
            monthNames(in: locale, short: style == .shortName)
                .map { "(?:" + $0.map(NSRegularExpression.escapedPattern).joined(separator: "|") + ")" } ?? #"\d{2}"#
        }
    }

    /// Whether `locale` has month names MacJot can put in a filename: Latin
    /// letters once accents are dropped. Not in e.g. Japanese (`10月`).
    public static func monthNamesAvailable(in locale: Locale) -> Bool {
        monthNames(in: locale, short: false) != nil && monthNames(in: locale, short: true) != nil
    }

    /// The twelve names as macOS writes them in `locale` and keeps their case,
    /// with accents dropped and a trailing dot removed (`Okt.` → `Okt`, `févr.` →
    /// `fevr`), as filenames are (ADR 0003). Nil if any isn't plain Latin letters
    /// then. Worked out once per locale.
    static func monthNames(in locale: Locale, short: Bool) -> [String]? {
        let key = "\(locale.identifier)|\(short)"
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cached = namesCache[key] { return cached }
        let formatter = DateFormatter()
        formatter.locale = locale
        let names = (short ? formatter.shortMonthSymbols : formatter.monthSymbols) ?? []
        let cleaned = names.map { name -> String in
            var name = name.folding(options: .diacriticInsensitive, locale: locale)
            while name.hasSuffix(".") { name.removeLast() }
            return name
        }
        let usable = cleaned.count == 12 && cleaned.allSatisfy { !$0.isEmpty && $0.allSatisfy { $0.isASCII && $0.isLetter } }
        namesCache[key] = usable ? cleaned : nil as [String]?
        return usable ? cleaned : nil
    }

    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var namesCache: [String: [String]?] = [:]

    /// The prefix at the start of `stem` in this format (any day), or nil. It
    /// mustn't end inside a word or number (`Mar` of `March-plan`). Only the
    /// fallback for a filename that doesn't plainly end with its Title's name (ADR 0009).
    func prefix(atStartOf stem: String, locale: Locale = .current) -> String? {
        guard !elements.isEmpty else { return nil }
        let pattern = elements.map { element -> String in
            switch element {
            case .year(.full): #"\d{4}"#
            case .year(.short), .day(.number): #"\d{2}"#
            case .day(.unpadded): #"\d{1,2}"#
            case .month(let style): Self.monthPattern(style, locale: locale)
            case .separator(let separator): NSRegularExpression.escapedPattern(for: separator.rawValue)
            }
        }.joined()
        let ns = stem as NSString
        guard let regex = try? NSRegularExpression(pattern: "^" + pattern),
              let match = regex.firstMatch(in: stem, range: NSRange(location: 0, length: ns.length)),
              match.range.length > 0, match.range.length < ns.length
        else { return nil }
        let prefix = ns.substring(with: match.range)
        let next = ns.substring(with: NSRange(location: match.range.length, length: 1)).first
        if let last = prefix.last, let next, (last.isLetter && next.isLetter) || (last.isNumber && next.isNumber) {
            return nil
        }
        return prefix
    }
}
