import AppKit
import ServiceManagement

/// Opening MacJot at login, read from the system each time rather than from a
/// stored copy, so a change under System Settings > General > Login Items
/// shows up in MacJot's Settings (the approach of sindresorhus/LaunchAtLogin-Modern).
@MainActor
enum LaunchAtLogin {
    enum State {
        case on, off
        /// Registered, but switched off under "Allow in the Background"; only
        /// the user can switch it on again, in System Settings.
        case needsApproval
        /// Not running as an app bundle (e.g. `swift run`): nothing to register.
        case unavailable
    }

    static var state: State {
        guard isAppBundle else { return .unavailable }
        switch SMAppService.mainApp.status {
        case .enabled: return .on
        case .requiresApproval: return .needsApproval
        default: return .off
        }
    }

    /// A failure is logged and reported as false; `state` then still tells the truth.
    @discardableResult
    static func set(_ on: Bool) -> Bool {
        guard isAppBundle else { return false }
        do {
            if on {
                // Already on: nothing to do. (Unregistering to register afresh would
                // lose a working login item if registering then failed.)
                guard SMAppService.mainApp.status != .enabled else { return true }
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            NSLog("MacJot: couldn't turn \(on ? "on" : "off") opening at login: \(error)")
            return false
        }
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private static let didRegisterKey = "didRegisterLoginItem"

    /// On by default: switched on once, then left to the user, so MacJot never
    /// switches it on again after the user turned it off.
    static func turnOnOnFirstRun() {
        let defaults = UserDefaults.standard
        guard isAppBundle, !defaults.bool(forKey: didRegisterKey) else { return }
        if set(true) { defaults.set(true, forKey: didRegisterKey) }
    }

    private static var isAppBundle: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }
}
