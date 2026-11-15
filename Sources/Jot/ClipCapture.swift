import AppKit
import ApplicationServices
import JotCore

/// The Clip Hotkey's capture against the real system (ticket 49): the general
/// pasteboard, a ⌘C posted to the frontmost app, the Accessibility API.
@MainActor
struct SystemCaptureEnvironment: CaptureEnvironment {
    /// Every item as its types and bytes, taken before the ⌘C. Types that can't
    /// be written back (dynamic `dyn.*` ones) are skipped and lost on restore.
    struct Snapshot {
        var items: [[(type: NSPasteboard.PasteboardType, data: Data)]]
    }

    private let board = NSPasteboard.general
    private static let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    private static let transient = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
    private static let source = NSPasteboard.PasteboardType("org.nspasteboard.source")
    static let chromiumURL = NSPasteboard.PasteboardType("org.chromium.source-url")

    var isTrusted: Bool { ClipPermission.isGranted }

    func frontmostApp() -> FrontmostApp? { frontmostApp(readingTitle: true) }

    func frontmostApp(readingTitle: Bool) -> FrontmostApp? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return Self.describe(app, readingTitle: readingTitle)
    }

    static func describe(_ app: NSRunningApplication, readingTitle: Bool) -> FrontmostApp {
        let isMacJot = app.processIdentifier == ProcessInfo.processInfo.processIdentifier
        return FrontmostApp(name: app.localizedName ?? app.bundleIdentifier ?? "Unknown",
                            windowTitle: isMacJot || !readingTitle ? nil : frontWindowTitle(of: app), isMacJot: isMacJot)
    }

    /// The front window's title as the Accessibility API gives it.
    private static func frontWindowTitle(of app: NSRunningApplication) -> String? {
        let element = AXUIElementCreateApplication(app.processIdentifier)
        var window: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &window) == .success
                || AXUIElementCopyAttributeValue(element, kAXMainWindowAttribute as CFString, &window) == .success,
              let window, CFGetTypeID(window) == AXUIElementGetTypeID() else { return nil }
        var title: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &title) == .success
        else { return nil }
        return title as? String
    }

    var modifiersHeld: Bool {
        !CGEventSource.flagsState(.combinedSessionState)
            .intersection([.maskControl, .maskAlternate, .maskShift, .maskCommand]).isEmpty
    }

    var changeCount: Int { board.changeCount }

    func snapshot() -> Snapshot {
        Snapshot(items: (board.pasteboardItems ?? []).map { item in
            item.types.filter { !$0.rawValue.hasPrefix("dyn.") }.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            }
        })
    }

    /// ⌘C and nothing else: the flags are set explicitly, from a private event source,
    /// so no key still held down leaks in.
    func sendCopy() {
        let source = CGEventSource(stateID: .privateState)
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: down)  // C
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
    }

    var hasConcealedItem: Bool { board.types?.contains(Self.concealed) ?? false }
    func plainText() -> String? { board.string(forType: .string) }
    func sourceURL() -> String? { board.string(forType: Self.chromiumURL) }

    func restore(_ snapshot: Snapshot, transient: Bool) {
        board.clearContents()
        let items = snapshot.items.filter { !$0.isEmpty }.enumerated().map { index, entries in
            let item = NSPasteboardItem()
            for (type, data) in entries { item.setData(data, forType: type) }
            if transient && index == 0 {
                // The convention clipboard managers follow: not a copy the user made.
                item.setData(Data(), forType: Self.transient)
                item.setString(Bundle.main.bundleIdentifier ?? "MacJot", forType: Self.source)
            }
            return item
        }
        if !items.isEmpty { board.writeObjects(items) }
    }

    var now: Double { ProcessInfo.processInfo.systemUptime }
    func sleep(_ seconds: Double) async { try? await Task.sleep(for: .seconds(seconds)) }

    /// The app named by the pasteboard's `org.nspasteboard.source` (a bundle
    /// identifier), for a Clip from Clipboard; `nil` when the marker isn't there.
    static func markedSourceApp(on board: NSPasteboard = .general) -> String? {
        guard let id = board.string(forType: source), !id.isEmpty,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return nil }
        let bundle = Bundle(url: url)
        return (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
    }
}

/// The app that was in front before MacJot: when the Services menu runs MacJot's
/// Service, MacJot is already the frontmost app, so the source is the one before it (ticket 50).
@MainActor
final class FrontAppTracker {
    private(set) var last: NSRunningApplication?
    private var observer: NSObjectProtocol?

    init() {
        let me = ProcessInfo.processInfo.processIdentifier
        last = NSWorkspace.shared.frontmostApplication.flatMap { $0.processIdentifier == me ? nil : $0 }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != me else { return }
            MainActor.assumeIsolated { self?.last = app }
        }
    }
}
