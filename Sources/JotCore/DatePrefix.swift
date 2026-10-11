import Foundation

/// The Date Prefix of a Note's filename: the day the Note was created, written
/// in the Date Prefix Format (`DatePrefixFormat`). Never parsed back into a
/// date (ADR 0009).
public enum DatePrefix {
    /// The prefix of a Note's filename: whatever precedes the Title's own name
    /// (its slug, or slug-`N`), in whatever format it was written; `""` if the
    /// filename is just that name, also when the Title itself starts with a date
    /// (`2026-10-08 meeting` → `2026-10-08-meeting.md`). A prefix found that way
    /// mustn't end in a letter (`workplan.md` for "Plan" has none), and where
    /// one of `formats` recognises a shorter prefix at the start, that one wins
    /// (`2026-10-08-meeting-notes.md` whose Title became "Notes" elsewhere). If
    /// the name doesn't end with the Title's, the prefix `formats` recognise;
    /// nil if they recognise none: MacJot can't tell.
    static func of(fileName: String, titleSlug: String, formats: [DatePrefixFormat], locale: Locale = .current) -> String? {
        let stem = (fileName.lowercased().hasSuffix(".md") ? String(fileName.dropLast(3)) : fileName) as NSString
        let recognised = formats.lazy.compactMap { $0.prefix(atStartOf: stem as String, locale: locale) }.first
        if let nameStart = nameStart(in: stem, slug: titleSlug) {
            let byTitle = stem.substring(to: nameStart)
            if byTitle.isEmpty { return "" }
            if !(byTitle.last?.isLetter ?? false) {
                if let recognised, recognised.count < byTitle.count, byTitle.hasPrefix(recognised) { return recognised }
                return byTitle
            }
        }
        return recognised
    }

    /// Where `slug` or `slug-N` starts at the very end of `stem`, if it ends with one.
    private static func nameStart(in stem: NSString, slug: String) -> Int? {
        guard !slug.isEmpty else { return nil }
        var end = stem.length
        if !(stem as String).hasSuffix(slug), let collision = stem.range(of: #"-\d+$"#, options: .regularExpression).nonEmpty {
            end = collision.location  // `plan-2`: the name before the collision suffix
        }
        let name = stem.substring(to: end)
        guard name.hasSuffix(slug) else { return nil }
        return end - (slug as NSString).length
    }
}

private extension NSRange {
    var nonEmpty: NSRange? { location == NSNotFound || length == 0 ? nil : self }
}
