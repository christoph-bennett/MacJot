import AppKit
import JotCore
import KeyboardShortcuts
import Observation
import SwiftUI

/// The Settings window's panes, in the order the switcher shows them.
enum SettingsPane: String, CaseIterable {
    case general, editor, shortcuts

    var title: String {
        switch self {
        case .general: "General"
        case .editor: "Editor"
        case .shortcuts: "Shortcuts"
        }
    }
}

/// What the panes show that isn't a preference of their own.
@MainActor @Observable
final class SettingsState {
    var notesFolder: URL?
    var notesFolderIcon: NSImage?
    /// For the Date Prefix example; updated each time Settings opens.
    var today = Date.now
    var launchAtLogin = LaunchAtLogin.State.off
    /// See `Hotkey.unavailable`.
    var unavailableHotkeys: Set<Hotkey> = []
}

/// All panes share this width, so the window only changes height between them.
private let paneWidth: CGFloat = 460

/// The classic Mac settings layout: labels in a right-aligned column, controls
/// left-aligned next to them, explanations in small grey text 4 pt below a
/// control. Settings (`Row`s) are 16 pt apart, clearly more than the parts of
/// one setting, and a `Divider` gets the same 16 pt above and below; it spans
/// both columns. A grid rather than a `.columns` form, whose row spacing can't
/// be set (HIG audit, ticket 20).
private struct Pane<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 16) { content }
            .frame(width: paneWidth)
            .padding(.vertical, 20)
            .padding(.horizontal, 30)
            .fixedSize()
    }
}

/// One setting: its label in the right-aligned column, its controls and
/// explanations next to it. Without a label, the label cell stays empty.
private struct Row<Content: View>: View {
    let label: String?
    @ViewBuilder let content: Content

    init(_ label: String? = nil, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        GridRow(alignment: .firstTextBaseline) {
            if let label {
                Text(label)
                    .gridColumnAlignment(.trailing)
                    .accessibilityHidden(true)  // read with the controls instead, as LabeledContent did
            } else {
                Color.clear.frame(width: 0, height: 0)  // fixed: a flexible cell would widen the label column
            }
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(label.map { Text($0) } ?? Text(""))
        }
    }
}

private struct Explanation: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct GeneralPane: View {
    @AppStorage(SettingsWindowController.datePrefixKey) private var datePrefix = false
    @AppStorage(CapturePanelController.confirmTrashKey) private var confirmTrash = true
    let state: SettingsState
    let onChooseNotesFolder: () -> Void
    let onDatePrefixChange: (Bool) -> Void
    let onLaunchAtLoginChange: (Bool) -> Void
    let onResetPanel: () -> Void

    var body: some View {
        Pane {
            Row("Notes Folder:") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if let folder = state.notesFolder, let icon = state.notesFolderIcon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 16, height: 16)
                            Text(folder.lastPathComponent)
                        }
                        Button("Choose…", action: onChooseNotesFolder)
                    }
                    if let folder = state.notesFolder {
                        Text("Currently configured folder: \(SavedNotesFolder.display(folder))")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .truncationMode(.middle)
                            .lineLimit(1)
                            .textSelection(.enabled)
                    }
                    Explanation(text: "Choosing another folder doesn’t move your notes.")
                }
            }
            Divider()
            Row("New Notes:") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Start file names with the creation date", isOn: $datePrefix)
                    // Today's date, so the example matches what the next Note gets.
                    Explanation(text: "Named like “\(DatePrefix.string(for: state.today))plan.md”. "
                                + "Existing files keep their names.")
                }
            }
            Row("Trash:") {
                Toggle("Ask before moving notes to the Trash", isOn: $confirmTrash)
            }
            Divider()
            Row("Startup:") {
                VStack(alignment: .leading, spacing: 4) {
                    // Checked while awaiting approval too: it's registered, and
                    // unchecking it unregisters it.
                    Toggle("Open MacJot at login", isOn: Binding(
                        get: { state.launchAtLogin == .on || state.launchAtLogin == .needsApproval },
                        set: { onLaunchAtLoginChange($0) }))
                    .disabled(state.launchAtLogin == .unavailable)
                    switch state.launchAtLogin {
                    case .needsApproval:
                        Explanation(text: "MacJot isn’t allowed to open at login. Allow it in System Settings, "
                                    + "under Login Items & Extensions.")
                        Button("Open Login Items Settings…", action: LaunchAtLogin.openSystemSettings)
                    case .unavailable:
                        Explanation(text: "Only available when MacJot runs from its app.")
                    case .on, .off:
                        EmptyView()
                    }
                }
            }
            Row("Capture Panel:") {
                VStack(alignment: .leading, spacing: 4) {
                    Button("Reset Size & Position", action: onResetPanel)
                    Explanation(text: "Puts the panel and its note list back to their original size, in the middle of the screen.")
                }
            }
        }
        .onChange(of: datePrefix) { _, on in onDatePrefixChange(on) }
    }
}

struct EditorPane: View {
    @AppStorage(SettingsWindowController.fontSizeKey) private var fontSize = SettingsWindowController.defaultFontSize
    @AppStorage(SettingsWindowController.relativeDatesKey) private var relativeDates = true
    @AppStorage(SettingsWindowController.lineNumbersKey) private var lineNumbers = true
    let onFontSizeChange: (CGFloat) -> Void
    let onLineNumbersChange: (Bool) -> Void
    let onRelativeDatesChange: (Bool) -> Void

    private static let sizes: [Double] = [11, 12, 13, 14, 15, 16, 18, 20, 22, 24]
    /// A sample date for the explanation, in the format the switch would show.
    private static let absoluteExample: String = {
        let formatter = RelativeDateFormatter()
        formatter.isRelative = false
        return formatter.string(for: .now)
    }()

    var body: some View {
        Pane {
            Row("Font Size:") {
                Picker("Font Size", selection: $fontSize) {
                    // A stored size that isn't in the list (set elsewhere) is shown too.
                    ForEach(Array(Set(Self.sizes + [fontSize])).sorted(), id: \.self) { size in
                        Text("\(Int(size)) pt").tag(size)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
            Row("Line Numbers:") {
                Toggle("Show line numbers", isOn: $lineNumbers)
            }
            Divider()
            Row("Note List:") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Show relative dates", isOn: $relativeDates)
                    Explanation(text: relativeDates
                                ? "Like “now”, “2h” or “Mon”."
                                : "Like “\(Self.absoluteExample)”.")
                }
            }
        }
        .onChange(of: fontSize) { _, size in onFontSizeChange(size) }
        .onChange(of: relativeDates) { _, on in onRelativeDatesChange(on) }
        .onChange(of: lineNumbers) { _, on in onLineNumbersChange(on) }
    }
}

/// A recorder per hotkey (KeyboardShortcuts, ADR 0005). It warns about
/// combinations macOS uses and blocks ones in MacJot's menus; `HotkeyCheck` adds
/// "already the other hotkey" and "another app has it". A rejected combination
/// isn't saved, so the previous hotkey stays active. Clearing one turns it off.
struct ShortcutsPane: View {
    let state: SettingsState
    let onRestoreDefaults: () -> Void

    var body: some View {
        Pane {
            Row("Capture:") {
                VStack(alignment: .leading, spacing: 4) {
                    recorder(for: .capture)
                    unavailableNote(for: .capture)
                    Explanation(text: "Opens MacJot with a new note, from any app.")
                }
            }
            Divider()
            Row("Search:") {
                VStack(alignment: .leading, spacing: 4) {
                    recorder(for: .search)
                    unavailableNote(for: .search)
                    Explanation(text: "Opens MacJot with your notes and the search field, from any app.")
                }
            }
            Divider()
            Row {
                VStack(alignment: .leading, spacing: 4) {
                    Button("Restore Defaults", action: onRestoreDefaults)
                    Explanation(text: "Sets the hotkeys back to \(Hotkey.capture.defaultDisplayString) "
                                + "and \(Hotkey.search.defaultDisplayString).")
                }
            }
        }
    }

    @ViewBuilder
    private func unavailableNote(for hotkey: Hotkey) -> some View {
        if state.unavailableHotkeys.contains(hotkey) {
            Text("Another app is using this combination, so it doesn’t work in MacJot. Record a different one.")
                .font(.callout)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func recorder(for hotkey: Hotkey) -> some View {
        KeyboardShortcuts.Recorder(for: hotkey.name) { _ in
            // Saved only after passing the check below, so it's registered now.
            Hotkey.unavailable.remove(hotkey)
            state.unavailableHotkeys = Hotkey.unavailable
        }
        .shortcutValidation { shortcut in
                hotkey.problem(recording: shortcut).map { .disallow(reason: $0) } ?? .allow
            }
    }
}
