import Foundation
import Testing
@testable import JotCore

struct RelativeDateTests {
    private let now = Date(timeIntervalSince1970: 1_791_446_400)  // Thursday 2026-10-08, 08:00 UTC

    private func format(_ secondsAgo: TimeInterval, locale: String = "en_US", relative: Bool = true) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let formatter = RelativeDateFormatter(calendar: calendar, locale: Locale(identifier: locale))
        formatter.isRelative = relative
        return formatter.string(for: now.addingTimeInterval(-secondsAgo), now: now)
    }

    @Test func justNow() { #expect(format(20) == "now") }
    @Test func minutes() { #expect(format(5 * 60) == "5m") }
    @Test func hours() { #expect(format(2 * 3600) == "2h") }
    @Test func weekdayWithinTheLastSixDays() { #expect(format(3 * 86400) == "Mon") }
    @Test func sameWeekdayLastWeekIsADateNotTodaysName() {
        // Last Thursday 18:00, ~6.6 days ago: "Thu" would read as today.
        #expect(format(6 * 86400 + 14 * 3600, locale: "de_DE") == "01.10.26")
    }
    @Test func shortDateWhenOlder() { #expect(format(30 * 86400, locale: "de_DE") == "08.09.26") }
    @Test func futureDatesFromClockSkewCountAsNow() { #expect(format(-120) == "now") }

    // Relative dates off: the system's short date and time, however recent.
    @Test func absoluteDateAndTime() { #expect(format(45 * 60, locale: "de_DE", relative: false) == "08.10.26, 07:15") }
    @Test func absoluteEvenForJustNow() { #expect(format(20, locale: "de_DE", relative: false) == "08.10.26, 07:59") }
    @Test func absoluteFollowsTheLocale() {
        // Only the parts that don't vary between macOS versions (the space before "AM" does).
        let string = format(30 * 86400, locale: "en_US", relative: false)
        #expect(string.hasPrefix("9/8/26, 8:00"))
        #expect(string.hasSuffix("AM"))
    }
}
