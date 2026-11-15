import Foundation

/// A Clip's `page` (ticket 49): the front window's title as the Accessibility API
/// gives it, without what the app adds around the page's own title (ticket 45's findings).
public enum PageTitle {
    /// Apps whose window title is no page: a folder, a process and a window size.
    private static let terminals = ["terminal", "iterm", "iterm2"]

    private static let browserSuffix = try! NSRegularExpression(
        pattern: #"(^|\s+)[-–—]\s+(Google Chrome|Microsoft Edge|Brave Browser|Brave|Chromium|Vivaldi|Opera|Arc|Mozilla Firefox|Firefox)(\s+[-–—]\s+[^-–—]+)?$"#)

    /// `nil` when the title says nothing about a page (none, blank, or a terminal's).
    public static func page(app: String, windowTitle: String?) -> String? {
        guard !terminals.contains(app.lowercased()),
              var title = windowTitle?.trimmingCharacters(in: .whitespaces), !title.isEmpty else { return nil }
        let whole = NSRange(title.startIndex..., in: title)
        if let match = browserSuffix.firstMatch(in: title, range: whole), let range = Range(match.range, in: title) {
            title.removeSubrange(range)
        } else if app == "Safari", let separator = title.range(of: " — ") {
            // Safari puts the profile's name in front, even for the default one.
            title = String(title[separator.upperBound...])
        }
        title = title.trimmingCharacters(in: .whitespaces)
        return title.isEmpty ? nil : title
    }
}
