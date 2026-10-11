import Foundation
import Testing
@testable import JotCore

/// The Date Prefix Format (ticket 38, ADR 0009): elements in any order, each
/// with its options; nothing required.
struct DatePrefixFormatTests {
    private let october = DatePrefixFormatTests.date(2026, 10, 9)
    private let february = DatePrefixFormatTests.date(2026, 2, 3)

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func string(_ elements: [DatePrefixFormat.Element], _ date: Date, _ locale: String = "en_US") -> String {
        DatePrefixFormat(elements).string(for: date, locale: Locale(identifier: locale))
    }

    @Test func theDefaultIsTheFormerFixedPrefix() {
        #expect(DatePrefixFormat.standard.string(for: october, locale: Locale(identifier: "en_US")) == "2026-10-09-")
    }

    @Test func numbersWithAndWithoutLeadingZeros() {
        #expect(string([.year(.short), .month(.number), .day(.number)], february) == "260203")
        #expect(string([.day(.unpadded), .separator(.dot), .month(.unpadded), .separator(.dot), .year(.full)], february)
                == "3.2.2026")
    }

    @Test func separators() {
        #expect(string([.year(.full), .separator(.underscore), .separator(.space), .separator(.hyphen), .separator(.dot)],
                       october) == "2026_ -.")
    }

    @Test func monthNamesInTheSystemLanguage() {
        #expect(string([.month(.shortName)], october) == "Oct")
        #expect(string([.month(.fullName)], october) == "October")
        #expect(string([.month(.shortName)], october, "de_DE") == "Okt")     // "Okt." without its dot
        #expect(string([.month(.fullName)], february, "fr_FR") == "fevrier")  // accents dropped
        #expect(string([.month(.shortName)], february, "fr_FR") == "fevr")
    }

    @Test func nonLatinScriptsGetNumbers() {
        #expect(!DatePrefixFormat.monthNamesAvailable(in: Locale(identifier: "ja_JP")))
        #expect(DatePrefixFormat.monthNamesAvailable(in: Locale(identifier: "de_DE")))
        #expect(string([.month(.fullName)], october, "ja_JP") == "10")
    }

    @Test func anythingGoesEvenNothing() {
        #expect(string([], october).isEmpty)
        #expect(string([.year(.full), .year(.short)], october) == "202626")
    }

    @Test func storedAndRestored() throws {
        let format = DatePrefixFormat([.day(.number), .separator(.dot), .month(.fullName), .separator(.space)])
        let data = try JSONEncoder().encode(format)
        #expect(try JSONDecoder().decode(DatePrefixFormat.self, from: data) == format)
    }
}

/// Review findings for ticket 38: finding the prefix by the Title, at its edges.
struct DatePrefixByTitleTests {
    private func prefix(_ fileName: String, _ slug: String, _ formats: [DatePrefixFormat] = [.standard]) -> String? {
        DatePrefix.of(fileName: fileName, titleSlug: slug, formats: formats, locale: Locale(identifier: "en_US"))
    }

    @Test func aNumericTitleIsFoundAtTheEnd() {
        #expect(prefix("2026-10-01-1.md", "1") == "2026-10-01-")
        #expect(prefix("2026-10-08-08.md", "08") == "2026-10-08-")
        #expect(prefix("2026-10-01-1-2.md", "1") == "2026-10-01-")
    }

    @Test func noPrefixEndingInALetter() {
        #expect(prefix("workplan.md", "plan") == nil)
        #expect(prefix("plan.md", "plan") == "")
    }

    @Test func aRecognisedShorterPrefixWins() {
        #expect(prefix("2026-10-08-meeting-notes.md", "notes") == "2026-10-08-")
        #expect(prefix("2026-10-08-2026-01-01-review.md", "2026-01-01-review") == "2026-10-08-")
    }

    @Test func theFallbackDoesntCutWords() {
        let months = DatePrefixFormat([.month(.shortName)])
        #expect(prefix("March-plan.md", "budget", [months]) == nil)
        #expect(prefix("Mar-plan.md", "budget", [months]) == "Mar")
    }
}
