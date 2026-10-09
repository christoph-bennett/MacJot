import AppKit
import JotCore
import Observation
import SwiftUI

/// The Settings window's panes, in the order the switcher shows them.
enum SettingsPane: String, CaseIterable {
    case general, shortcuts

    var title: String {
        switch self {
        case .general: "General"
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
    let state: SettingsState
    let onChooseNotesFolder: () -> Void
    let onDatePrefixChange: (Bool) -> Void

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
        }
        .onChange(of: datePrefix) { _, on in onDatePrefixChange(on) }
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
