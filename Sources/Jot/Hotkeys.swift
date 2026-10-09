import AppKit
import Carbon.HIToolbox
import JotCore
import KeyboardShortcuts

/// The hotkeys as KeyboardShortcuts stores and registers them (ADR 0005). The
/// initial combinations are stored the first time a name is used, so they carry
/// over for users from before hotkeys could be changed.
extension KeyboardShortcuts.Name {
    static let capture = Self("captureHotkey", initial: .init(.n, modifiers: [.control, .option]))
    static let search = Self("searchHotkey", initial: .init(.f, modifiers: [.control, .option]))
}

@MainActor
extension Hotkey {
    var name: KeyboardShortcuts.Name {
        switch self {
        case .capture: .capture
        case .search: .search
        }
    }

    /// As menus show it, e.g. `⌃⌥N`, with the key as the current keyboard layout
    /// labels it; nil when the user cleared it.
    var displayString: String? {
        KeyboardShortcuts.getShortcut(for: name)?.description
    }

    /// The default, e.g. `⌃⌥N`, as the current keyboard layout labels it.
    var defaultDisplayString: String {
        name.initialShortcut?.description ?? ""
    }

    /// Hotkeys that couldn't be registered because another app holds their
    /// combination; KeyboardShortcuts drops those silently. Shown in Settings
    /// until the user records or restores that hotkey.
    static var unavailable: Set<Hotkey> = []

    /// Why the recorder must reject `shortcut` for this hotkey, or nil.
    func problem(recording shortcut: KeyboardShortcuts.Shortcut) -> String? {
        HotkeyCheck.problem(recording: shortcut, for: self,
                            current: { KeyboardShortcuts.getShortcut(for: $0.name) },
                            canRegister: Self.canRegister)
    }

    /// Before registering at launch: notes a hotkey whose combination another app holds.
    func checkAvailableBeforeRegistering() {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: name), !Self.canRegister(shortcut) else { return }
        Self.unavailable.insert(self)
        NSLog("Jot: couldn't register the \(title) \(shortcut); another app holds it")
    }

    /// Restores the defaults, except one another app holds: that hotkey keeps its
    /// combination. Returns the hotkeys that weren't restored.
    static func restoreDefaults() -> [Hotkey] {
        let held = Set(allCases.compactMap { KeyboardShortcuts.getShortcut(for: $0.name) })
        // Jot's own combinations are registered, so the probe would fail for them.
        let blocked = allCases.filter { hotkey in
            guard let initial = hotkey.name.initialShortcut else { return false }
            return !held.contains(initial) && !canRegister(initial)
        }
        let restored = allCases.filter { !blocked.contains($0) }
        KeyboardShortcuts.reset(restored.map(\.name))
        unavailable.subtract(restored)
        return blocked
    }

    /// Registers `shortcut` for a moment; fails if it's registered already,
    /// in Jot or exclusively by another app.
    private static func canRegister(_ shortcut: KeyboardShortcuts.Shortcut) -> Bool {
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(shortcut.carbonKeyCode), UInt32(shortcut.carbonModifiers),
            EventHotKeyID(signature: 0x4A4F5421, id: 0),  // 'JOT!'
            GetApplicationEventTarget(), 0, &ref
        )
        guard status == noErr, let ref else { return false }
        UnregisterEventHotKey(ref)
        return true
    }
}
