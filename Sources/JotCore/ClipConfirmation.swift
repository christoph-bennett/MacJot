import Foundation

/// The Clip Confirmation's settings (ticket 48): how long the pill stays.
public enum ClipConfirmation {
    public static let defaultDuration = 2.0
    public static let durations = 1.0...5.0
    public static let step = 0.5

    /// The stored number of seconds as a duration: the default when there's none
    /// (or it isn't a sensible number), otherwise kept within 1 to 5 s in half-second steps.
    public static func duration(stored: Double?) -> Double {
        guard let stored, stored.isFinite, stored > 0 else { return defaultDuration }
        let snapped = (stored / step).rounded() * step
        return min(max(snapped, durations.lowerBound), durations.upperBound)
    }
}
