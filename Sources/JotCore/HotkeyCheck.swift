/// Jot's two global hotkeys.
public enum Hotkey: String, CaseIterable, Sendable {
    case capture, search

    public var title: String {
        switch self {
        case .capture: "Capture Hotkey"
        case .search: "Search Hotkey"
        }
    }

    public var other: Hotkey {
        self == .capture ? .search : .capture
    }
}

/// Whether a newly recorded combination may become a hotkey. Checked before it's
/// saved, so a rejected one leaves the previous hotkey active. The recorder
/// itself already warns about combinations macOS uses.
public enum HotkeyCheck {
    /// Why `candidate` can't become `hotkey`'s combination, as a message for the
    /// user; nil if it can. `canRegister` tries a system-wide registration. It
    /// fails only when another app holds the combination exclusively: most apps
    /// don't, and those can't be detected. While the recorder records, Jot's own
    /// hotkeys are paused, so re-recording the current combination is checked too.
    public static func problem<Combination: Equatable>(
        recording candidate: Combination, for hotkey: Hotkey,
        current: (Hotkey) -> Combination?, canRegister: (Combination) -> Bool
    ) -> String? {
        if current(hotkey.other) == candidate {
            return "This combination is already the \(hotkey.other.title)."
        }
        guard canRegister(candidate) else {
            return "Jot can’t use this combination. Another app may be using it."
        }
        return nil
    }
}
