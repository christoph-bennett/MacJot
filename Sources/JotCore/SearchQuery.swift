import Foundation

/// What Search looks for (ticket 37): the words of the query, each found
/// anywhere in a Note, in any order; text in quotes, straight or curly, is one
/// exact phrase. Case, accents and Markdown are ignored by the matching itself.
public enum SearchQuery {
    /// The query's words and phrases, in order; empty ones dropped. An unclosed
    /// quote runs to the end, as the user is still typing the phrase.
    public static func terms(_ query: String) -> [String] {
        let quotes: Set<Character> = ["\"", "“", "”", "„"]
        var terms: [String] = []
        var current = ""
        var inPhrase = false
        func finish() {
            let term = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !term.isEmpty { terms.append(term) }
            current = ""
        }
        for character in query {
            if quotes.contains(character) {
                finish()
                inPhrase.toggle()
            } else if character.isWhitespace, !inPhrase {
                finish()
            } else {
                current.append(character)
            }
        }
        finish()
        return terms
    }
}
