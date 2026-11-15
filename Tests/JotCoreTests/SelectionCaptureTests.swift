import Testing
@testable import JotCore

/// Seam 3: the capture sequence against fakes for the pasteboard, the keyboard,
/// the clock and the frontmost app (ticket 49).
@MainActor
final class FakeCapture: CaptureEnvironment {
    var isTrusted = true
    var app: FrontmostApp? = FrontmostApp(name: "Safari", windowTitle: "Personal — A page")
    var heldUntil: Double = 0                      // modifiers held until this time
    var changeCount = 10
    var board: String? = "before"
    var concealed = false
    var url: String?
    var now = 0.0
    var log: [String] = []
    /// What ⌘C does: when the pasteboard changes (nil: never) and to what; extra changes follow.
    var copyChangesAfter: Double? = 0.03
    var copiedText: String? = "selected"
    var extraChangesAt: [Double] = []
    private var sentAt: Double?
    var restoredTransient: Bool?
    var restoredBoard: String??
    var modifiersHeldWhenSent: Bool?

    var modifiersHeld: Bool { now < heldUntil }
    func frontmostApp() -> FrontmostApp? { app }
    func snapshot() -> String? { log.append("snapshot"); return board }
    func sendCopy() {
        log.append("copy")
        sentAt = now
        modifiersHeldWhenSent = modifiersHeld
    }
    var hasConcealedItem: Bool { concealed }
    func plainText() -> String? { log.append("read"); return board }
    func sourceURL() -> String? { url }
    func restore(_ snapshot: String?, transient: Bool) {
        log.append("restore")
        restoredTransient = transient
        restoredBoard = .some(snapshot)
        board = snapshot
    }
    func sleep(_ seconds: Double) async {
        now += seconds
        guard let sent = sentAt else { return }
        let elapsed = now - sent
        if let after = copyChangesAfter, elapsed >= after, !didCopy {
            didCopy = true
            board = copiedText
            changeCount += 1
        }
        for t in extraChangesAt where elapsed >= t && !fired.contains(t) {
            fired.insert(t)
            board = (board ?? "") + "+"
            changeCount += 1
        }
    }
    private var didCopy = false
    private var fired: Set<Double> = []
}

struct SelectionCaptureTests {
    @MainActor
    @Test func copiesTheSelectionAndRestoresTheClipboard() async {
        let env = FakeCapture()
        let result = await SelectionCapture.run(env)
        #expect(result == .clip(CapturedSelection(text: "selected", source: "Safari", page: "A page", url: nil)))
        #expect(env.board == "before")
        #expect(env.restoredTransient == true)
        #expect(env.log == ["snapshot", "copy", "read", "restore"])
    }

    @MainActor
    @Test func noChangeInTimeMeansNoSelectionAndTheClipboardIsLeftAlone() async {
        let env = FakeCapture()
        env.copyChangesAfter = nil
        #expect(await SelectionCapture.run(env) == .noSelection)
        #expect(!env.log.contains("restore"))
        #expect(!env.log.contains("read"))
        #expect(env.board == "before")
    }

    @MainActor
    @Test func aSlowAppStillCountsWithinTheWait() async {
        let env = FakeCapture()
        env.copyChangesAfter = 0.4
        if case .clip = await SelectionCapture.run(env) {} else { Issue.record("expected a clip") }
    }

    @MainActor
    @Test func anAppSlowerThanTheWaitIsNoSelection() async {
        let env = FakeCapture()
        env.copyChangesAfter = 0.8
        #expect(await SelectionCapture.run(env) == .noSelection)
    }

    @MainActor
    @Test func macJotInFrontFailsWithItsOwnReasonAndTouchesNothing() async {
        let env = FakeCapture()
        env.app = FrontmostApp(name: "MacJot", windowTitle: nil, isMacJot: true)
        #expect(await SelectionCapture.run(env) == .ownApp)
        #expect(env.log.isEmpty)
    }

    @MainActor
    @Test func withoutThePermissionNothingHappens() async {
        let env = FakeCapture()
        env.isTrusted = false
        #expect(await SelectionCapture.run(env) == .permissionMissing)
        #expect(env.log.isEmpty)
    }

    @MainActor
    @Test func theCopyWaitsForTheModifiersToBeReleased() async {
        let env = FakeCapture()
        env.heldUntil = 0.3
        _ = await SelectionCapture.run(env)
        #expect(env.modifiersHeldWhenSent == false)
    }

    @MainActor
    @Test func modifiersHeldForeverDoNotHangTheCapture() async {
        let env = FakeCapture()
        env.heldUntil = .infinity
        _ = await SelectionCapture.run(env)
        #expect(env.log.contains("copy"))
    }

    @MainActor
    @Test func aPasteboardStillChangingIsReadOnlyAfterItSettles() async {
        let env = FakeCapture()
        env.extraChangesAt = [0.08, 0.12]
        let result = await SelectionCapture.run(env)
        #expect(result == .clip(CapturedSelection(text: "selected++", source: "Safari", page: "A page", url: nil)))
    }

    @MainActor
    @Test func concealedItemsAreNeverReadButTheClipboardComesBack() async {
        let env = FakeCapture()
        env.concealed = true
        #expect(await SelectionCapture.run(env) == .noSelection)
        #expect(!env.log.contains("read"))
        #expect(env.board == "before")
    }

    @MainActor
    @Test func aWhitespaceOnlySelectionIsEmptyAndRestored() async {
        let env = FakeCapture()
        env.copiedText = " \n\t "
        #expect(await SelectionCapture.run(env) == .noSelection)
        #expect(env.board == "before")
    }

    @MainActor
    @Test func aPageAddressOnThePasteboardComesAlong() async {
        let env = FakeCapture()
        env.app = FrontmostApp(name: "Google Chrome", windowTitle: "Docs - Google Chrome")
        env.url = "https://example.com/a"
        let result = await SelectionCapture.run(env)
        #expect(result == .clip(CapturedSelection(text: "selected", source: "Google Chrome", page: "Docs",
                                                  url: "https://example.com/a")))
    }

    @MainActor
    @Test func terminalGetsNoPage() async {
        let env = FakeCapture()
        env.app = FrontmostApp(name: "Terminal", windowTitle: "mac-notes — zsh — 80×24")
        let result = await SelectionCapture.run(env)
        #expect(result == .clip(CapturedSelection(text: "selected", source: "Terminal", page: nil, url: nil)))
    }
}
