import AppKit
import ApplicationServices

/// The permission the Clip Hotkey needs to press ⌘C in another app (ADR 0011).
/// macOS 27 lists it in System Settings > Privacy & Security as "Device Control
/// and Data Access" (formerly "Accessibility"); `AXIsProcessTrusted` still applies.
/// The grant is tied to the app's code signature (`scripts/bundle.sh`).
@MainActor
enum ClipPermission {
    /// The name macOS 27 gives the permission, for what the user reads.
    static let settingsName = "Device Control and Data Access"

    static var isGranted: Bool { AXIsProcessTrusted() }

    /// Posted when the permission changes, by any app, in System Settings.
    static let changedNotification = Notification.Name("com.apple.accessibility.api")

    private static let askedKey = "clipPermissionAsked"

    /// Whether the system's prompt has been shown already.
    static var hasAsked: Bool { UserDefaults.standard.bool(forKey: askedKey) }

    /// Asks the system to show its prompt, once: a second press without the
    /// permission does nothing visible (the Clip itself reports it, ticket 49).
    /// Returns whether it was granted already.
    @discardableResult
    static func requestOnce() -> Bool {
        guard !isGranted else { return true }
        guard !UserDefaults.standard.bool(forKey: askedKey) else { return false }
        UserDefaults.standard.set(true, forKey: askedKey)
        // The literal of kAXTrustedCheckOptionPrompt (a C global, not concurrency-safe to read).
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        return false
    }

    /// Posted just before System Settings opens, so MacJot's floating windows can
    /// step back and not hide it.
    static let willOpenSettings = Notification.Name("MacJotWillOpenSystemSettings")

    /// Opens System Settings at the pane that lists the permission.
    static func openPrivacySettings() {
        NotificationCenter.default.post(name: willOpenSettings, object: nil)
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open(url, configuration: configuration)
        // An already-running System Settings may not come to the front by itself
        // while MacJot (a background app) is the active one.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.systempreferences").first?.activate()
        }
    }
}
