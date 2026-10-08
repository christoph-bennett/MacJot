import Foundation

/// Compact dates for the Note List: "now", "5m", "2h", a weekday for the last
/// six calendar days, else the locale's short date. Keep one instance around:
/// its date formatters are expensive to create.
public final class RelativeDateFormatter {
    private let calendar: Calendar
    private let weekday = DateFormatter()
    private let shortDate = DateFormatter()

    public init(calendar: Calendar = .current, locale: Locale = .current) {
        self.calendar = calendar
        for formatter in [weekday, shortDate] {
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.locale = locale
        }
        weekday.setLocalizedDateFormatFromTemplate("EEE")
        shortDate.dateStyle = .short
        shortDate.timeStyle = .none
    }

    public func string(for date: Date, now: Date = Date()) -> String {
        let seconds = now.timeIntervalSince(date)
        switch seconds {
        case ..<60: return "now"
        case ..<3600: return "\(Int(seconds / 60))m"
        case ..<86_400: return "\(Int(seconds / 3600))h"
        default: break
        }
        // Not 7: the same weekday a week ago would read as today.
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date),
                                           to: calendar.startOfDay(for: now)).day ?? .max
        return days < 7 ? weekday.string(from: date) : shortDate.string(from: date)
    }
}
