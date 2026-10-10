import Foundation

/// The line the editor highlights (ticket 29): the file's line the cursor is on,
/// however many rows it wraps onto. Positions are UTF-16 offsets.
public enum CurrentLine {
    /// The cursor's line, its line break included; empty for the empty last line
    /// after a final break (or of an empty Note). Nil while text is selected.
    public static func range(in text: String, selection: NSRange) -> NSRange? {
        guard selection.length == 0 else { return nil }
        let ns = text as NSString
        return ns.lineRange(for: NSRange(location: min(selection.location, ns.length), length: 0))
    }
}
