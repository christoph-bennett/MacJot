import AppKit
import JotCore
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
    /// The hotkeys as the current keyboard layout labels them, e.g. `⌃⌥N`.
    var captureHotkey = ""
    var searchHotkey = ""
    var launchAtLogin = LaunchAtLogin.State.off
}

/// All panes share this width, so the window only changes height between them.
private let paneWidth: CGFloat = 460

/// The classic Mac settings layout: labels in a right-aligned column, controls
/// left-aligned next to them, explanations in small grey text below a control.
private struct Pane<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        Form { content }
            .formStyle(.columns)
            .frame(width: paneWidth)
            .padding(.vertical, 20)
            .padding(.horizontal, 30)
            .fixedSize()
    }
}

/// The space of an empty line of small text, between a setting and its explanation.
private let blankLine: CGFloat = 12

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
            LabeledContent("Notes Folder:") {
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
                            .padding(.top, blankLine / 2)
                    }
                    Explanation(text: "Choosing another folder doesn’t move your notes.")
                        .padding(.top, blankLine)
                }
            }
            Divider()
            LabeledContent("New Notes:") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Start file names with the creation date", isOn: $datePrefix)
                    // Today's date, so the example matches what the next Note gets.
                    Explanation(text: "Named like “\(DatePrefix.string(for: state.today))plan.md”. "
                                + "Existing files keep their names.")
                        .padding(.top, blankLine)
                }
            }
            LabeledContent("Trash:") {
                Toggle("Ask before moving notes to the Trash", isOn: $confirmTrash)
            }
            Divider()
            LabeledContent("Startup:") {
                VStack(alignment: .leading, spacing: 4) {
                    // Checked while awaiting approval too: it's registered, and
                    // unchecking it unregisters it.
                    Toggle("Open Jot at login", isOn: Binding(
                        get: { state.launchAtLogin == .on || state.launchAtLogin == .needsApproval },
                        set: { onLaunchAtLoginChange($0) }))
                    .disabled(state.launchAtLogin == .unavailable)
                    switch state.launchAtLogin {
                    case .needsApproval:
                        Explanation(text: "Jot isn’t allowed to open at login. Allow it in System Settings, "
                                    + "under Login Items & Extensions.")
                        Button("Open Login Items Settings…", action: LaunchAtLogin.openSystemSettings)
                    case .unavailable:
                        Explanation(text: "Only available when Jot runs from its app.")
                    case .on, .off:
                        EmptyView()
                    }
                }
            }
            LabeledContent("Capture Panel:") {
                VStack(alignment: .leading, spacing: 4) {
                    Button("Reset Size & Position", action: onResetPanel)
                    Explanation(text: "Puts the panel back in the middle of the screen, at its original size.")
                        .padding(.top, blankLine / 2)
                }
            }
        }
        .onChange(of: datePrefix) { _, on in onDatePrefixChange(on) }
    }
}

struct EditorPane: View {
    @AppStorage(SettingsWindowController.fontSizeKey) private var fontSize = SettingsWindowController.defaultFontSize
    @AppStorage(SettingsWindowController.relativeDatesKey) private var relativeDates = true
    let onFontSizeChange: (CGFloat) -> Void
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
            Picker("Font Size:", selection: $fontSize) {
                // A stored size that isn't in the list (set elsewhere) is shown too.
                ForEach(Array(Set(Self.sizes + [fontSize])).sorted(), id: \.self) { size in
                    Text("\(Int(size)) pt").tag(size)
                }
            }
            .fixedSize()
            Divider()
            LabeledContent("Note List:") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Show relative dates", isOn: $relativeDates)
                    Explanation(text: relativeDates
                                ? "Like “now”, “2h” or “Mon”."
                                : "Like “\(Self.absoluteExample)”.")
                        .padding(.top, blankLine)
                }
            }
        }
        .onChange(of: fontSize) { _, size in onFontSizeChange(size) }
        .onChange(of: relativeDates) { _, on in onRelativeDatesChange(on) }
    }
}

/// Read-only until hotkeys can be recorded (ticket 13).
struct ShortcutsPane: View {
    let state: SettingsState

    var body: some View {
        Pane {
            LabeledContent("Capture:") {
                VStack(alignment: .leading, spacing: 4) {
                    Text(state.captureHotkey)
                    Explanation(text: "Opens Jot with a new note, from any app.")
                }
            }
            Divider()
            LabeledContent("Search:") {
                VStack(alignment: .leading, spacing: 4) {
                    Text(state.searchHotkey)
                    Explanation(text: "Opens Jot with your notes and the search field, from any app.")
                }
            }
        }
    }
}
