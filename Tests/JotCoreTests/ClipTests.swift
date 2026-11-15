import Foundation
import Testing
@testable import JotCore

/// Seam 2: the pure parts of a Clip (ticket 47): cleaning the text and writing the frontmatter.
struct ClipTextTests {
    @Test(arguments: [
        // (text, cleaned)
        ("Hello\nworld", "Hello\nworld"),
        ("\n\n  Hello\n  world", "Hello\n  world"),                  // leading blanks dropped, first line trimmed only
        ("───────\nHello", "Hello"),                                   // a rule of box characters
        ("***\n---\n\n▌ \nTitle line\nrest", "Title line\nrest"),     // several decoration lines
        ("• \n12 apples", "12 apples"),                                // digits count
        ("Привет мир\nвторая", "Привет мир\nвторая"),                  // Cyrillic is text
        ("🎉\nParty", "Party"),                                         // an emoji-only line is decoration
        ("🎉 Party", "🎉 Party"),                                       // with a word it stays
        ("Hello\n\n───\nworld", "Hello\n\n───\nworld"),                // only leading lines are dropped
        ("Hello\r\nworld", "Hello\nworld"),                            // line endings
        ("\t\tindented", "indented"),
    ])
    func cleaning(_ text: String, _ expected: String) {
        #expect(Clip.body(from: text) == expected)
    }

    @Test(arguments: ["", "   \n\t\n", "───\n***\n", "🎉🎉", "\n\n•\n"])
    func nothingLeftMeansNoClip(_ text: String) {
        #expect(Clip.body(from: text) == nil)
    }
}

struct ClipFrontmatterTests {
    private let when = Date(timeIntervalSince1970: 1_794_000_000)  // 2026-11-06 21:20 UTC
    private let utc = TimeZone(identifier: "UTC")!
    private let berlin = TimeZone(identifier: "Europe/Berlin")!

    @Test func createdOnly() {
        let text = Clip.frontmatter(created: when, source: nil, page: nil, timeZone: utc)
        #expect(text == "---\ncreated: 2026-11-06T21:20:00+00:00\n---\n")
    }

    @Test func localTimeWithOffset() {
        let text = Clip.frontmatter(created: when, source: nil, page: nil, timeZone: berlin)
        #expect(text == "---\ncreated: 2026-11-06T22:20:00+01:00\n---\n")
    }

    @Test func sourceAndPage() {
        let text = Clip.frontmatter(created: when, source: "Safari", page: "Finis — Write your book", timeZone: utc)
        #expect(text == "---\ncreated: 2026-11-06T21:20:00+00:00\nsource: Safari\npage: Finis — Write your book\n---\n")
    }

    @Test(arguments: [
        ("Plain title", "Plain title"),
        ("Re: Plan", "\"Re: Plan\""),                  // colon and space
        ("Say \"hi\"", "Say \"hi\""),                   // inner quotes are fine unquoted
        ("\"Quoted\" start", "\"\\\"Quoted\\\" start\""),
        ("# Heading", "\"# Heading\""),
        ("- item", "\"- item\""),
        ("[draft] notes", "\"[draft] notes\""),
        ("a # b", "\"a # b\""),
        ("yes", "\"yes\""),
        ("true", "\"true\""),
        ("2026", "\"2026\""),
        ("back\\slash start: x", "\"back\\\\slash start: x\""),
        ("ends with colon:", "\"ends with colon:\""),
        (" padded ", "padded"),                           // trimmed first, then plain
        ("two\nlines", "two lines"),                    // newlines become spaces
        ("& amp", "\"& amp\""),
        ("@home", "\"@home\""),
    ])
    func quoting(_ value: String, _ written: String) {
        let text = Clip.frontmatter(created: when, source: nil, page: value, timeZone: utc)
        #expect(text.contains("\npage: \(written)\n"))
    }

    @Test func emptyValuesAreLeftOut() {
        let text = Clip.frontmatter(created: when, source: "  ", page: "", timeZone: utc)
        #expect(!text.contains("source"))
        #expect(!text.contains("page"))
    }
}

/// How long the Clip Confirmation stays (ticket 48): 1 to 5 seconds in half-second steps, 2 by default.
struct ClipConfirmationDurationTests {
    @Test func defaultsToTwoSeconds() {
        #expect(ClipConfirmation.duration(stored: nil) == 2)
        #expect(ClipConfirmation.duration(stored: 0) == 2)       // nothing stored yet
        #expect(ClipConfirmation.duration(stored: .nan) == 2)
    }

    @Test(arguments: [(1.0, 1.0), (1.5, 1.5), (3.0, 3.0), (5.0, 5.0)])
    func validValuesAreKept(_ stored: Double, _ expected: Double) {
        #expect(ClipConfirmation.duration(stored: stored) == expected)
    }

    @Test(arguments: [(0.2, 1.0), (0.9, 1.0), (7.0, 5.0), (2.2, 2.0), (2.3, 2.5), (-1.0, 2.0)])
    func otherValuesAreClampedAndSnappedToHalfSeconds(_ stored: Double, _ expected: Double) {
        #expect(ClipConfirmation.duration(stored: stored) == expected)
    }
}

/// A Clip's `url` line (ticket 49).
struct ClipURLTests {
    private let date = Date(timeIntervalSince1970: 1_700_000_000)
    private let utc = TimeZone(identifier: "UTC")!

    @Test func urlComesAfterPage() {
        let text = Clip.frontmatter(created: date, source: "Google Chrome", page: "Docs",
                                    url: "https://example.com/a", timeZone: utc)
        #expect(text.contains("page: Docs\nurl: https://example.com/a\n---\n"))
    }

    @Test func noUrlNoLine() {
        #expect(!Clip.frontmatter(created: date, source: "Safari", page: "Docs", url: nil, timeZone: utc).contains("url:"))
        #expect(!Clip.frontmatter(created: date, source: "Safari", page: "Docs", url: "  ", timeZone: utc).contains("url:"))
    }

    @Test(arguments: [
        "https://example.com/?a=1&b=2", "https://example.com/page#section", "http://localhost:8080/x",
    ])
    func awkwardAddressesStayOneReadableLine(_ url: String) {
        let text = Clip.frontmatter(created: date, source: nil, page: nil, url: url, timeZone: utc)
        let line = text.split(separator: "\n").first { $0.hasPrefix("url:") }!
        #expect(line == "url: \(url)" || line == "url: \"\(url)\"")
    }

    @Test func aTitleWithSpaceHashIsQuoted() {
        let text = Clip.frontmatter(created: date, source: nil, page: nil, url: "https://a.com/x #y", timeZone: utc)
        #expect(text.contains("url: \"https://a.com/x #y\""))
    }
}
