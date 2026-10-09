import Foundation

/// What an empty Note List says instead of rows: no Notes match the search, or
/// there are no Notes at all. Nil while it has rows (the open Draft counts).
public enum NoteListPlaceholder: Equatable {
    case noResults(query: String)
    case noNotes

    public init?(query: String, rowCount: Int) {
        guard rowCount == 0 else { return nil }
        // Blank searches match everything (`NoteSummary.matches`), so they count as none.
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        self = query.isEmpty ? .noNotes : .noResults(query: query)
    }
}
