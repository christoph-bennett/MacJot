import Foundation

/// The Formatting Toolbar's line formats: a prefix at the start of each line.
public enum LineFormat: Equatable, Sendable {
    /// `#` to `###`; level 0 is plain text (removes heading markers only).
    case heading(Int)
    case bullet, numbered, checklist, quote
}

/// The Markdown prefix a line starts with, if any: indentation plus one marker.
struct LinePrefix {
    enum Kind: Equatable {
        case heading(Int)
        case bullet(Character)
        case numbered(Int, Character)
        case checklist
        case quote
    }

    let kind: Kind?
    /// Leading spaces or tabs.
    let indent: String
    /// Indentation and marker, with the spaces after it (UTF-16).
    let length: Int

    private static let pattern = try! NSRegularExpression(pattern: #"""
        ^([ \t]*)(?:(#{1,6})(?:[ \t]+|$)|([-*+])[ \t]+\[[ xX]\](?:[ \t]+|$)|([-*+])[ \t]+|(\d{1,9})([.)])[ \t]+|>[ \t]?)
        """#)

    /// `* * *`, `- - -`, `___`: a horizontal rule, not a list item.
    private static let thematicBreak = try! NSRegularExpression(pattern: #"^[ \t]*([-*_])(?:[ \t]*\1){2,}[ \t]*$"#)

    /// The prefix of `line` (its text, without the line break).
    init(_ line: String) {
        let ns = line as NSString
        let whole = NSRange(location: 0, length: ns.length)
        guard Self.thematicBreak.firstMatch(in: line, range: whole) == nil,
              let match = Self.pattern.firstMatch(in: line, range: whole) else {
            let indent = line.prefix { $0 == " " || $0 == "\t" }
            self.init(kind: nil, indent: String(indent), length: (String(indent) as NSString).length)
            return
        }
        func group(_ i: Int) -> String? {
            let range = match.range(at: i)
            return range.location == NSNotFound ? nil : ns.substring(with: range)
        }
        let kind: Kind = if let hashes = group(2) {
            .heading(hashes.count)
        } else if group(3) != nil {
            .checklist
        } else if let bullet = group(4) {
            .bullet(Character(bullet))
        } else if let number = group(5), let delimiter = group(6) {
            .numbered(Int(number) ?? 1, Character(delimiter))
        } else {
            .quote
        }
        self.init(kind: kind, indent: group(1) ?? "", length: match.range.length)
    }

    private init(kind: Kind?, indent: String, length: Int) {
        self.kind = kind
        self.indent = indent
        self.length = length
    }

    /// The marker that continues this list on the next line, with its
    /// indentation; `nil` if this isn't a list item.
    var continuation: String? {
        switch kind {
        case .bullet(let char): "\(indent)\(char) "
        case .numbered(let number, let delimiter): "\(indent)\(number + 1)\(delimiter) "
        case .checklist: "\(indent)- [ ] "
        case .heading, .quote, nil: nil
        }
    }

    func has(_ format: LineFormat) -> Bool {
        switch (format, kind) {
        case (.heading(let level), .heading(let existing)): level == existing
        case (.bullet, .bullet), (.numbered, .numbered), (.checklist, .checklist), (.quote, .quote): true
        default: false
        }
    }
}

extension MarkdownEditing {
    /// Applies a line format to every line the selection touches, replacing any
    /// other prefix rather than stacking (a heading on `- item` gives `# item`).
    /// If every non-blank line already has it, it's removed instead. Plain text
    /// (`.heading(0)`) only removes heading markers.
    ///
    /// Lists are tight: making one drops the blank lines between the selected
    /// paragraphs, and removing one makes its items separate paragraphs again
    /// (ADR 0004), so switching a list off and on gives the same list back.
    public static func toggle(_ format: LineFormat, in text: String, selection: NSRange) -> TextEdit {
        let ns = text as NSString
        let block = ns.lineRange(for: selection)
        var lines: [(range: NSRange, text: String)] = []
        ns.enumerateSubstrings(in: block, options: .byLines) { line, range, _, _ in
            lines.append((range, line ?? ""))
        }
        if lines.isEmpty { lines = [(NSRange(location: block.location, length: 0), "")] }  // an empty last line

        let prefixes = lines.map { LinePrefix($0.text) }
        let isBlank = lines.map { $0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        let allBlank = !isBlank.contains(false)
        let targets = Set(lines.indices.filter { allBlank || !isBlank[$0] })
        let remove = targets.allSatisfy { prefixes[$0].has(format) }

        let isList = format == .bullet || format == .numbered || format == .checklist
        let content = lines.indices.filter { !isBlank[$0] }
        let dropped = Set(isList && !remove && content.count > 1
            ? lines.indices.filter { isBlank[$0] && $0 > content.first! && $0 < content.last! } : [])

        // Rebuild the touched lines; remember each one's old and new prefix length
        // to map the selection through.
        var replacement = ""
        var mapped: [(old: NSRange, newStart: Int, oldPrefix: Int, newPrefix: Int)] = []
        var number = 0
        func newPrefix(for index: Int) -> String {
            let line = lines[index], prefix = prefixes[index]
            let existing = (line.text as NSString).substring(to: prefix.length)
            guard targets.contains(index) else { return existing }
            if format == .heading(0) {
                if case .heading = prefix.kind { return "" }
                return existing
            }
            if remove { return format.isHeading ? "" : prefix.indent }
            number += 1
            return format.prefix(indent: format.isHeading ? "" : prefix.indent, number: number)
        }
        var previous: Int?
        for (index, (line, prefix)) in zip(lines, prefixes).enumerated() {
            if dropped.contains(index) {
                mapped.append((line.range, block.location + (replacement as NSString).length, 0, 0))
                continue
            }
            if let previous {
                replacement += "\n"
                // Removing a list: its items become paragraphs again.
                if isList, remove, previous == index - 1, targets.contains(previous), targets.contains(index) {
                    replacement += "\n"
                }
            }
            let newStart = block.location + (replacement as NSString).length
            let body = (line.text as NSString).substring(from: prefix.length)
            let newPrefix = newPrefix(for: index)
            replacement += newPrefix + body
            mapped.append((line.range, newStart, prefix.length, (newPrefix as NSString).length))
            previous = index
        }
        let lastEnd = NSMaxRange(lines[lines.count - 1].range)
        replacement += ns.substring(with: NSRange(location: lastEnd, length: NSMaxRange(block) - lastEnd))

        func map(_ position: Int, isStart: Bool) -> Int {
            guard let line = mapped.last(where: { $0.old.location <= position }) else { return position }
            let offset = position - line.old.location
            if offset > line.oldPrefix { return line.newStart + offset - line.oldPrefix + line.newPrefix }
            // At the line start of a selection, keep the whole line (prefix included) selected.
            if isStart, offset == 0, selection.length > 0 { return line.newStart }
            return line.newStart + line.newPrefix
        }
        let start = map(selection.location, isStart: true)
        let end = selection.length == 0 ? start : map(NSMaxRange(selection), isStart: false)
        return TextEdit(range: block, replacement: replacement, selection: NSRange(location: start, length: end - start))
    }
}

private extension LineFormat {
    var isHeading: Bool {
        if case .heading = self { true } else { false }
    }

    func prefix(indent: String, number: Int) -> String {
        switch self {
        case .heading(let level): level > 0 ? String(repeating: "#", count: level) + " " : ""
        case .bullet: indent + "- "
        case .numbered: indent + "\(number). "
        case .checklist: indent + "- [ ] "
        case .quote: indent + "> "
        }
    }
}
