import AppKit

@MainActor
enum ErrorAlert {
    static func show(_ message: String, error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.informativeText = error.localizedDescription
        NSApp.activate()
        alert.runModal()
    }
}
