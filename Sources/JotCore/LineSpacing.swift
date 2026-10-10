import Foundation

/// The space below each line of the editor (Settings > Editor, ticket 33).
/// Stored by its raw value.
public enum LineSpacing: String, CaseIterable, Sendable {
    case tight, normal, relaxed

    public var title: String {
        switch self {
        case .tight: "Tight"
        case .normal: "Normal"
        case .relaxed: "Relaxed"
        }
    }

    /// Normal is the editor's spacing from before the setting existed, 2 pt at
    /// any size; Relaxed grows with the font, as a fixed amount looks lost on large text.
    public func points(fontSize: Double) -> Double {
        switch self {
        case .tight: 0
        case .normal: 2
        case .relaxed: (fontSize * 0.4).rounded()
        }
    }
}
