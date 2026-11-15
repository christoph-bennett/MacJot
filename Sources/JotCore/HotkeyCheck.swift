/// MacJot's three global hotkeys.
public enum Hotkey: String, CaseIterable, Sendable {
    case capture, search, clip

    public var title: String {
        switch self {
        case .capture: "Capture Hotkey"
        case .search: "Search Hotkey"
        case .clip: "Clip Hotkey"
        }
    }

    /// The other hotkeys, whose combinations this one must not take.
    public var others: [Hotkey] { Hotkey.allCases.filter { $0 != self } }
}

/// Whether a newly recorded combination may become a hotkey. Checked before it's
/// saved, so a rejected one leaves the previous hotkey active. The recorder
/// itself already warns about combinations macOS uses.
public enum HotkeyCheck {
    /// Why `candidate` can't become `hotkey`'s combination, as a message for the
    /// user; nil if it can. `canRegister` tries a system-wide registration. It
    /// fails only when another app holds the combination exclusively: most apps
    /// don't, and those can't be detected. While the recorder records, MacJot's own
    /// hotkeys are paused, so re-recording the current combination is checked too.
    public static func problem<Combination: Equatable>(
        recording candidate: Combination, for hotkey: Hotkey,
        current: (Hotkey) -> Combination?, canRegister: (Combination) -> Bool
    ) -> String? {
        if let taken = hotkey.others.first(where: { current($0) == candidate }) {
            return "This combination is already the \(taken.title)."
        }
        guard canRegister(candidate) else {
            return "MacJot can’t use this combination. Another app may be using it."
        }
        return nil
    }
}
