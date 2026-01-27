import AppKit
import Carbon

final class GlobalHotKeyManager {

    private static let signature: OSType = OSType(0x43424F50) // "CBOP"
    private static let hotKeyId: UInt32 = 1

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    private let onTrigger: () -> Void
    private var lastFire: TimeInterval = 0
    private let cooldown: TimeInterval = 0.18

    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
    }

    deinit {
        stop()
    }

    func start(keyCode: UInt32, modifiers: UInt32) {
        stop()

        var hkId = EventHotKeyID(signature: Self.signature, id: Self.hotKeyId)
        RegisterEventHotKey(keyCode, modifiers, hkId, GetApplicationEventTarget(), 0, &hotKeyRef)

        let eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        let handler: EventHandlerUPP = { _, _, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async {
                manager.fireIfAllowed()
            }
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            [eventType],
            userData,
            &handlerRef
        )
    }

    func stop() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = handlerRef {
            RemoveEventHandler(handler)
            handlerRef = nil
        }
    }

    private func fireIfAllowed() {
        let now = CFAbsoluteTimeGetCurrent()
        if now - lastFire < cooldown { return }
        lastFire = now
        onTrigger()
    }
}
