import AppKit
import JotCore
import SwiftUI

/// The Settings window: one window, brought back to the front if it's already open.
@MainActor
final class SettingsWindowController {
    static let datePrefixKey = "datePrefix"

    /// The Date Prefix toggle changed (on the main thread).
    var onDatePrefixChange: (Bool) -> Void = { _ in }

    private var window: NSWindow?
    private var host: NSHostingController<SettingsView>?

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        host?.rootView = makeView()  // redraws the example name with today's date
        // Jot is a menu-bar app, never active by itself: without this the window
        // would open behind the app the user is in.
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let host = NSHostingController(rootView: makeView())
        self.host = host
        let window = SettingsWindow(contentViewController: host)
        window.title = "Jot Settings"
        window.styleMask = [.titled, .closable]
        // The Capture Panel floats; at the same level, Settings opens on top of it.
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    private func makeView() -> SettingsView {
        SettingsView { [weak self] in self?.onDatePrefixChange($0) }
    }
}

private struct SettingsView: View {
    @AppStorage(SettingsWindowController.datePrefixKey) private var datePrefix = false
    let onDatePrefixChange: (Bool) -> Void

    var body: some View {
        Form {
            Section {
                Toggle("Start file names with the creation date", isOn: $datePrefix)
            } footer: {
                VStack(alignment: .leading, spacing: 2) {
                    // Today's date, so the example matches what the next Note gets.
                    Text("New notes are named like “\(DatePrefix.string(for: .now))plan.md”.")
                    Text("Existing files keep their names.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onChange(of: datePrefix) { _, on in onDatePrefixChange(on) }
        .frame(width: 440)
        .fixedSize()
    }
}

/// `Esc` closes Settings, like the Capture Panel.
private final class SettingsWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) {
        close()
    }
}
