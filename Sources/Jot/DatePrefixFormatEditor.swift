import AppKit
import JotCore
import SwiftUI

/// Settings > General > Format…: the Date Prefix Format as tokens, in the style
/// of Hazel's renaming patterns (ticket 39). A token field holds the format's
/// elements; a palette below adds them, by click (at the insertion point) or by
/// dragging; each token's ▾ menu has its options. Nothing is required, and the
/// field takes no typed text. Every change is saved at once.
struct DatePrefixFormatEditor: View {
    @Binding var format: DatePrefixFormat
    let today: Date
    let onDone: () -> Void
    // `@StateObject`: in this SDK `@State` is a macro (SwiftUIMacros.StateMacro),
    // and SwiftUI's macro plugin isn't part of the Command Line Tools.
    @StateObject private var field = TokenFieldHandle()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Click or drag elements to build the date at the start of new notes’ file names. "
                 + "Click an element for its options.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            // Two lines: named tokens are wide, and a long format wraps rather than scrolls.
            DatePrefixTokenField(format: $format, today: today, handle: field)
                .frame(height: 50)
            HStack(spacing: 8) {
                ForEach(DatePrefixElements.palette, id: \.self) { element in
                    PaletteToken(element: element) { field.insert(element) }
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Example:")
                    .foregroundStyle(.secondary)
                Text(format.string(for: today) + "groceries.md")
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            HStack {
                Button("Restore Default") { format = .standard }
                Spacer()
                Button("Done", action: onDone)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 480)
    }
}

/// What the editor shows for the elements: names in the palette, today's value
/// on a token, and the options of its ▾ menu.
enum DatePrefixElements {
    /// One of each, with its default option.
    static let palette: [DatePrefixFormat.Element] = [.year(.full), .month(.number), .day(.number), .separator(.hyphen)]

    static func name(_ element: DatePrefixFormat.Element) -> String {
        switch element {
        case .year: "Year"
        case .month: "Month"
        case .day: "Day"
        case .separator: "Separator"
        }
    }

    /// A day that shows every option apart: `09`/`9`, `05`/`5`, and a month
    /// whose short and full names differ (March is `mars` both ways in French).
    private static let sample = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 5, hour: 12)) ?? .now

    /// The token's face, as in Hazel: the element's name, as two numbers side
    /// by side wouldn't say which is the month and which the day. A separator
    /// says which it is, as `-` and `_` are hard to tell apart.
    static func face(_ element: DatePrefixFormat.Element) -> String {
        if case .separator(let separator) = element { return describe(separator) }
        return name(element)
    }

    /// `dash (-)`; a space only by name, as it would be invisible.
    static func describe(_ separator: DatePrefixFormat.Separator) -> String {
        switch separator {
        case .hyphen: "dash (-)"
        case .underscore: "underscore (_)"
        case .dot: "dot (.)"
        case .space: "space"
        }
    }

    /// An option's title in the ▾ menu: the element written for the sample day.
    private static func title(_ option: DatePrefixFormat.Element) -> String {
        if case .separator(let separator) = option { return describe(separator) }
        return DatePrefixFormat([option]).string(for: sample)
    }

    /// The element's options, as its ▾ menu lists them.
    /// Month names only where the system language has usable ones.
    static func options(of element: DatePrefixFormat.Element) -> [(title: String, element: DatePrefixFormat.Element)] {
        let all: [DatePrefixFormat.Element] = switch element {
        case .year: DatePrefixFormat.Year.allCases.map { .year($0) }
        case .month:
            DatePrefixFormat.Month.allCases
                .filter { DatePrefixFormat.monthNamesAvailable(in: .current) || ($0 != .shortName && $0 != .fullName) }
                .map { .month($0) }
        case .day: DatePrefixFormat.Day.allCases.map { .day($0) }
        case .separator: DatePrefixFormat.Separator.allCases.map { .separator($0) }
        }
        return all.map { option in (title(option), option) }
    }

    /// How tokens travel (dragged from the palette, moved within the field,
    /// copied and pasted): a private type, so other apps never see its data;
    /// they get the tokens' faces as text instead.
    static let pasteboardType = NSPasteboard.PasteboardType("com.onethingwell.macjot.date-prefix-elements")

    static func data(_ elements: [DatePrefixFormat.Element]) -> Data {
        (try? JSONEncoder().encode(elements)) ?? Data()
    }

    static func elements(from pasteboard: NSPasteboard) -> [DatePrefixFormat.Element] {
        pasteboard.data(forType: pasteboardType)
            .flatMap { try? JSONDecoder().decode([DatePrefixFormat.Element].self, from: $0) } ?? []
    }
}

/// A palette entry: looks like a token, adds its element when clicked, and can
/// be dragged into the field.
private struct PaletteToken: View {
    let element: DatePrefixFormat.Element
    let add: () -> Void

    var body: some View {
        Button(action: add) {
            Text(DatePrefixElements.name(element))
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Color.accentColor.opacity(0.2), in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .onDrag {
            // Plain text too: while the field is being edited its field editor takes
            // the drop, and accepts text; the token field then reads the private data.
            let provider = NSItemProvider(object: DatePrefixFormat([element]).string(for: .now) as NSString)
            provider.registerDataRepresentation(forTypeIdentifier: DatePrefixElements.pasteboardType.rawValue,
                                                visibility: .ownProcess) { done in
                done(DatePrefixElements.data([element]), nil)
                return nil
            }
            return provider
        }
        .help("Click or drag to add the \(DatePrefixElements.name(element).lowercased())")
    }
}

/// Lets the palette insert into the token field it doesn't own.
final class TokenFieldHandle: ObservableObject {
    weak var field: DatePrefixTokenFieldView?
    var insertElement: (DatePrefixFormat.Element, Int) -> Void = { _, _ in }

    /// At the insertion point while the field is being edited, else at the end.
    func insert(_ element: DatePrefixFormat.Element) {
        let count = (field?.objectValue as? [Any])?.count ?? 0
        let index = field?.currentEditor().map { min($0.selectedRange.location, count) } ?? count
        insertElement(element, index)
    }
}

/// The editor's token field; it takes only tokens (see `Coordinator.dropTypedText`).
/// It also takes palette drops while it isn't being edited: then no field
/// editor is there to receive them.
final class DatePrefixTokenFieldView: NSTokenField {
    var onDropElements: ([DatePrefixFormat.Element]) -> Void = { _ in }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        registerForDraggedTypes([DatePrefixElements.pasteboardType])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard currentEditor() == nil else { return super.draggingEntered(sender) }
        return DatePrefixElements.elements(from: sender.draggingPasteboard).isEmpty ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard currentEditor() == nil else { return super.performDragOperation(sender) }
        let elements = DatePrefixElements.elements(from: sender.draggingPasteboard)
        guard !elements.isEmpty else { return false }
        onDropElements(elements)
        return true
    }
}

/// A token: a box, so a menu can change the element of exactly this one.
private final class ElementToken: NSObject {
    var element: DatePrefixFormat.Element
    init(_ element: DatePrefixFormat.Element) { self.element = element }
}

struct DatePrefixTokenField: NSViewRepresentable {
    @Binding var format: DatePrefixFormat
    let today: Date
    let handle: TokenFieldHandle

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> DatePrefixTokenFieldView {
        let field = DatePrefixTokenFieldView()
        field.delegate = context.coordinator
        field.tokenizingCharacterSet = CharacterSet()  // nothing typed becomes a token
        field.completionDelay = .infinity
        field.cell?.isScrollable = false
        field.cell?.wraps = true
        field.setContentHuggingPriority(.defaultLow, for: .vertical)  // fill the two lines it's given
        field.objectValue = format.elements.map(ElementToken.init)
        handle.field = field
        handle.insertElement = { [weak coordinator = context.coordinator] in coordinator?.insert([$0], at: $1) }
        field.onDropElements = { [weak coordinator = context.coordinator, weak field] elements in
            coordinator?.insert(elements, at: (field?.objectValue as? [Any])?.count ?? 0)
        }
        return field
    }

    func updateNSView(_ field: DatePrefixTokenFieldView, context: Context) {
        context.coordinator.parent = self
        // Restore Default, for instance: the field follows the format.
        if context.coordinator.elements(of: field) != format.elements {
            field.objectValue = format.elements.map(ElementToken.init)
        }
    }

    final class Coordinator: NSObject, NSTokenFieldDelegate {
        var parent: DatePrefixTokenField

        init(_ parent: DatePrefixTokenField) { self.parent = parent }

        func elements(of field: NSTokenField) -> [DatePrefixFormat.Element] {
            ((field.objectValue as? [Any]) ?? []).compactMap { ($0 as? ElementToken)?.element }
        }

        private func publish(_ field: NSTokenField) {
            let elements = elements(of: field)
            guard elements != parent.format.elements else { return }
            parent.format = DatePrefixFormat(elements)
        }

        /// Setting the field's tokens resets its field editor's selection: the
        /// caret goes back to just after the inserted tokens, for the next click.
        func insert(_ elements: [DatePrefixFormat.Element], at index: Int) {
            guard let field = parent.handle.field else { return }
            var objects = (field.objectValue as? [Any]) ?? []
            let at = min(index, objects.count)
            objects.insert(contentsOf: elements.map(ElementToken.init), at: at)
            field.objectValue = objects
            field.currentEditor()?.selectedRange = NSRange(location: at + elements.count, length: 0)
            publish(field)
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTokenField else { return }
            dropTypedText(in: field)
            publish(field)
        }

        /// Typing adds nothing: any character that isn't a token (an attachment)
        /// is taken out again as it's typed, with a beep. Deleting, dropping and
        /// pasting tokens are unaffected. (A subclass can't refuse it earlier:
        /// the field editor's delegate methods aren't overridable.)
        private func dropTypedText(in field: NSTokenField) {
            guard let editor = field.currentEditor() as? NSTextView, let storage = editor.textStorage,
                  !editor.hasMarkedText()  // an input method or dead key is composing: not yet
            else { return }
            let text = storage.string as NSString
            var typed: [NSRange] = []
            for index in 0..<text.length where text.character(at: index) != 0xFFFC {
                typed.append(NSRange(location: index, length: 1))
            }
            guard !typed.isEmpty else { return }
            NSSound.beep()
            let cursor = editor.selectedRange().location
            for range in typed.reversed() { storage.replaceCharacters(in: range, with: "") }
            editor.setSelectedRange(NSRange(location: max(0, cursor - typed.count), length: 0))
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let field = notification.object as? NSTokenField else { return }
            // Anything that slipped in that isn't an element goes.
            field.objectValue = elements(of: field).map(ElementToken.init)
            publish(field)
        }

        func tokenField(_ tokenField: NSTokenField, displayStringForRepresentedObject representedObject: Any) -> String? {
            guard let token = representedObject as? ElementToken else { return nil }
            return DatePrefixElements.face(token.element)
        }

        func tokenField(_ tokenField: NSTokenField, editingStringForRepresentedObject representedObject: Any) -> String? {
            nil  // tokens aren't edited as text
        }

        func tokenField(_ tokenField: NSTokenField, shouldAdd tokens: [Any], at index: Int) -> [Any] {
            tokens.filter { $0 is ElementToken }  // typed text never becomes a token
        }

        func tokenField(_ tokenField: NSTokenField, writeRepresentedObjects objects: [Any], to pboard: NSPasteboard) -> Bool {
            let elements = objects.compactMap { ($0 as? ElementToken)?.element }
            guard !elements.isEmpty else { return false }
            pboard.declareTypes([DatePrefixElements.pasteboardType, .string], owner: nil)
            pboard.setData(DatePrefixElements.data(elements), forType: DatePrefixElements.pasteboardType)
            pboard.setString(DatePrefixFormat(elements).string(for: parent.today), forType: .string)
            return true
        }

        func tokenField(_ tokenField: NSTokenField, readFrom pboard: NSPasteboard) -> [Any]? {
            let tokens = DatePrefixElements.elements(from: pboard).map(ElementToken.init)
            return tokens.isEmpty ? nil : tokens
        }

        func tokenField(_ tokenField: NSTokenField, hasMenuForRepresentedObject representedObject: Any) -> Bool {
            representedObject is ElementToken
        }

        func tokenField(_ tokenField: NSTokenField, menuForRepresentedObject representedObject: Any) -> NSMenu? {
            guard let token = representedObject as? ElementToken else { return nil }
            let menu = NSMenu()
            for option in DatePrefixElements.options(of: token.element) {
                let item = ClosureMenuItem(option.title) { [weak self, weak tokenField, token] in
                    guard let self, let tokenField else { return }
                    token.element = option.element
                    tokenField.objectValue = tokenField.objectValue  // redraw the token's face
                    publish(tokenField)
                }
                item.state = option.element == token.element ? .on : .off
                menu.addItem(item)
            }
            return menu
        }
    }
}
