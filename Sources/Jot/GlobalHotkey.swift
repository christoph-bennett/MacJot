import AppKit
import Carbon.HIToolbox

/// A system-wide keystroke registered with the Carbon hot-key API, which needs
/// no Accessibility permission. Unregistered when released.
@MainActor
final class GlobalHotkey {
    struct Combination: Equatable {
        var keyCode: UInt32
        var modifiers: UInt32  // Carbon modifier mask, e.g. `controlKey | optionKey`

        static let defaultCapture = Combination(keyCode: UInt32(kVK_ANSI_N), modifiers: UInt32(controlKey | optionKey))
        static let defaultSearch = Combination(keyCode: UInt32(kVK_ANSI_F), modifiers: UInt32(controlKey | optionKey))

        /// As menus show it, e.g. `⌃⌥N`, with the key as the current keyboard layout labels it.
        var displayString: String {
            let symbols: [(Int, String)] = [(controlKey, "⌃"), (optionKey, "⌥"), (shiftKey, "⇧"), (cmdKey, "⌘")]
            return symbols.filter { modifiers & UInt32($0.0) != 0 }.map(\.1).joined() + keyName
        }

        private var keyName: String {
            guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
                  let data = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
            else { return "?" }
            let layout = Unmanaged<CFData>.fromOpaque(data).takeUnretainedValue()
            var deadKeys: UInt32 = 0
            var characters = [UniChar](repeating: 0, count: 4)
            var length = 0
            let status = CFDataGetBytePtr(layout).withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) {
                UCKeyTranslate($0, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                               OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, characters.count, &length, &characters)
            }
            guard status == noErr, length > 0 else { return "?" }
            return String(utf16CodeUnits: characters, count: length).uppercased()
        }
    }

    enum RegistrationError: Error {
        case eventHandlerNotInstalled(OSStatus)
        case unavailable(OSStatus)
    }

    private static var handlers: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private static var isEventHandlerInstalled = false
    private static let signature: OSType = 0x4A4F5421  // 'JOT!'

    private let id: UInt32
    private var ref: EventHotKeyRef?

    init(_ combination: Combination, handler: @escaping () -> Void) throws(RegistrationError) {
        try Self.installEventHandlerIfNeeded()
        id = Self.nextID
        Self.nextID += 1

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            combination.keyCode, combination.modifiers,
            EventHotKeyID(signature: Self.signature, id: id),
            GetApplicationEventTarget(), 0, &ref
        )
        guard status == noErr, let ref else { throw .unavailable(status) }
        self.ref = ref
        Self.handlers[id] = handler
    }

    isolated deinit {
        if let ref { UnregisterEventHotKey(ref) }
        Self.handlers[id] = nil
    }

    private static func installEventHandlerIfNeeded() throws(RegistrationError) {
        guard !isEventHandlerInstalled else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
            )
            guard status == noErr, hotKeyID.signature == GlobalHotkey.signature else {
                return OSStatus(eventNotHandledErr)
            }
            // Carbon delivers application-target events on the main thread.
            MainActor.assumeIsolated { GlobalHotkey.handlers[hotKeyID.id]?() }
            return noErr
        }, 1, &spec, nil, nil)
        guard status == noErr else { throw .eventHandlerNotInstalled(status) }
        isEventHandlerInstalled = true
    }
}
