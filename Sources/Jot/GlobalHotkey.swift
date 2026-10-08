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
