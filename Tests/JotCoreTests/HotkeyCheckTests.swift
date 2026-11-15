import Testing
@testable import JotCore

/// Whether a newly recorded combination may become a hotkey. A rejected one
/// isn't saved, so the previous hotkey stays active.
struct HotkeyCheckTests {
    private let current: [Hotkey: String] = [.capture: "⌃⌥N", .search: "⌃⌥F", .clip: "⌃⌥C"]

    private func problem(_ candidate: String, for hotkey: Hotkey, registrable: Bool = true) -> String? {
        HotkeyCheck.problem(recording: candidate, for: hotkey, current: { current[$0] },
                            canRegister: { _ in registrable })
    }

    @Test func aFreeCombinationIsAllowed() {
        #expect(problem("⌃⌥J", for: .capture) == nil)
    }

    @Test func theOtherHotkeysCombinationIsRejected() {
        #expect(problem("⌃⌥F", for: .capture) == "This combination is already the Search Hotkey.")
        #expect(problem("⌃⌥N", for: .search) == "This combination is already the Capture Hotkey.")
    }

    @Test func theClipHotkeyIsCheckedAgainstBothOthers() {
        #expect(problem("⌃⌥N", for: .clip) == "This combination is already the Capture Hotkey.")
        #expect(problem("⌃⌥F", for: .clip) == "This combination is already the Search Hotkey.")
        #expect(problem("⌃⌥C", for: .capture) == "This combination is already the Clip Hotkey.")
        #expect(problem("⌃⌥C", for: .search) == "This combination is already the Clip Hotkey.")
        #expect(problem("⌃⌥C", for: .clip) == nil)  // its own combination again
    }

    @Test func aCombinationThatCantBeRegisteredIsRejected() {
        #expect(problem("⌃⌥J", for: .capture, registrable: false)
                == "MacJot can’t use this combination. Another app may be using it.")
    }

    @Test func reRecordingTheSameCombinationIsCheckedToo() {
        // MacJot's hotkeys are paused while recording; another app may have taken it since.
        #expect(problem("⌃⌥N", for: .capture, registrable: false) != nil)
        #expect(problem("⌃⌥N", for: .capture) == nil)
    }

    @Test func anyCombinationIsAllowedWhenTheOtherHotkeyIsOff() {
        let none = HotkeyCheck.problem(recording: "⌃⌥F", for: .capture,
                                       current: { $0 == .capture ? "⌃⌥N" : nil }, canRegister: { _ in true })
        #expect(none == nil)
    }

    @Test func eachHotkeyHasATitleAndTheOthers() {
        #expect(Hotkey.capture.title == "Capture Hotkey")
        #expect(Hotkey.clip.title == "Clip Hotkey")
        #expect(Hotkey.search.others == [.capture, .clip])
        #expect(Hotkey.clip.others == [.capture, .search])
    }
}
