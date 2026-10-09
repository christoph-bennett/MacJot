import Testing
@testable import JotCore

/// What an empty Note List says: why it's empty, or nothing while it has rows.
struct NoteListPlaceholderTests {
    @Test func aListWithRowsSaysNothing() {
        #expect(NoteListPlaceholder(query: "", rowCount: 3) == nil)
        #expect(NoteListPlaceholder(query: "plan", rowCount: 1) == nil)
    }

    @Test func aSearchWithoutMatchesSaysNoResults() {
        #expect(NoteListPlaceholder(query: "zzz", rowCount: 0) == .noResults(query: "zzz"))
    }

    @Test func noSearchAndNoRowsSaysNoNotes() {
        #expect(NoteListPlaceholder(query: "", rowCount: 0) == .noNotes)
    }

    @Test func aBlankSearchCountsAsNoSearch() {
        #expect(NoteListPlaceholder(query: "  ", rowCount: 0) == .noNotes)
    }

    @Test func theQueryIsShownTrimmed() {
        #expect(NoteListPlaceholder(query: " zzz ", rowCount: 0) == .noResults(query: "zzz"))
    }

    // The open Draft has a row only once it has text (decided 2026-10-09), so an
    // empty folder says "No Notes" until the user types.
    @Test func aBlankDraftHasNoRow() {
        #expect(!NoteSummary.listsDraft("", query: ""))
        #expect(!NoteSummary.listsDraft(" \n\n", query: ""))
    }

    @Test func aDraftWithTextHasARowWhenItMatches() {
        #expect(NoteSummary.listsDraft("# Plan", query: ""))
        #expect(NoteSummary.listsDraft("# Plan", query: "pla"))
        #expect(!NoteSummary.listsDraft("# Plan", query: "zzz"))
    }
}
