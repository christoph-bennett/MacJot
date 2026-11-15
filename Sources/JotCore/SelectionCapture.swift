import Foundation

/// The app in front when the Clip Hotkey is pressed.
public struct FrontmostApp: Equatable {
    public var name: String
    public var windowTitle: String?
    /// MacJot itself: there is nothing to copy from.
    public var isMacJot: Bool
    public init(name: String, windowTitle: String?, isMacJot: Bool = false) {
        self.name = name
        self.windowTitle = windowTitle
        self.isMacJot = isMacJot
    }
}

/// What the Clip Hotkey took from the selection.
public struct CapturedSelection: Equatable {
    public var text: String
    public var source: String
    public var page: String?
    public var url: String?
}

public enum CaptureResult: Equatable {
    case clip(CapturedSelection)
    case permissionMissing
    /// MacJot is in front.
    case ownApp
    /// Nothing selected, a field that blocks copying, a concealed or blank copy.
    case noSelection
}

/// Everything the capture touches outside itself (ticket 49): the pasteboard, the
/// keyboard, the clock and the frontmost app. The app implements it with AppKit;
/// the tests with fakes.
@MainActor
public protocol CaptureEnvironment {
    associatedtype Snapshot
    var isTrusted: Bool { get }
    func frontmostApp() -> FrontmostApp?
    /// Whether any modifier key (⌃ ⌥ ⇧ ⌘) is still held down.
    var modifiersHeld: Bool { get }
    var changeCount: Int { get }
    func snapshot() -> Snapshot
    /// ⌘C with only the Command flag set.
    func sendCopy()
    var hasConcealedItem: Bool { get }
    func plainText() -> String?
    /// The page address, if the copy carries one (`org.chromium.source-url`).
    func sourceURL() -> String?
    /// Puts the snapshot back; `transient` marks it so clipboard managers skip it.
    func restore(_ snapshot: Snapshot, transient: Bool)
    /// Seconds on a monotonic clock.
    var now: Double { get }
    func sleep(_ seconds: Double) async
}

/// Copies the selection of the frontmost app with ⌘C and puts the clipboard back
/// (ADR 0011, ticket 49).
public enum SelectionCapture {
    /// Longest wait for the hotkey's own modifiers to be let go.
    static let modifierTimeout = 3.0
    /// Longest wait for the pasteboard to change after ⌘C: none by then means no selection.
    static let changeTimeout = 0.5
    /// How long the pasteboard has to stay unchanged before it is read.
    static let settleTime = 0.05
    private static let poll = 0.01

    @MainActor
    public static func run<E: CaptureEnvironment>(_ env: E) async -> CaptureResult {
        guard env.isTrusted else { return .permissionMissing }
        guard let app = env.frontmostApp() else { return .noSelection }
        guard !app.isMacJot else { return .ownApp }

        // Held ⌃⌥ would turn the ⌘C into another shortcut (ticket 45).
        let waitStart = env.now
        while env.modifiersHeld && env.now - waitStart < modifierTimeout { await env.sleep(poll) }

        let before = env.changeCount
        let snapshot = env.snapshot()
        env.sendCopy()

        let sent = env.now
        while env.changeCount == before && env.now - sent < changeTimeout { await env.sleep(poll) }
        // Unchanged: no selection. Nothing was written, so nothing is restored.
        guard env.changeCount != before else { return .noSelection }

        var seen = env.changeCount
        var stableSince = env.now
        while env.now - stableSince < settleTime && env.now - sent < 2 {
            await env.sleep(poll)
            if env.changeCount != seen { seen = env.changeCount; stableSince = env.now }
        }

        let text = env.hasConcealedItem ? nil : env.plainText()
        let url = env.hasConcealedItem ? nil : env.sourceURL()
        env.restore(snapshot, transient: true)

        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .noSelection }
        return .clip(CapturedSelection(text: text, source: app.name,
                                       page: PageTitle.page(app: app.name, windowTitle: app.windowTitle),
                                       url: url?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyValue))
    }
}

private extension String {
    var nonEmptyValue: String? { isEmpty ? nil : self }
}
