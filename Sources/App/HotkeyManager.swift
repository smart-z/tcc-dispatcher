import Carbon
import AppKit

// MARK: - 全局热键管理（Carbon RegisterEventHotKey，无第三方依赖）
final class HotkeyManager {
    static let shared = HotkeyManager()

    var onActivate: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    private init() {}

    /// 注册热键 ⌥Space（可替换 keyCode / modifiers）
    func register() {
        // kVK_Space = 49
        let keyCode: UInt32 = 49
        let modifiers: UInt32 = UInt32(optionKey)   // ⌥

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x5443_4350)    // 'TCCP'
        hotKeyID.id = 1

        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind  = OSType(kEventHotKeyPressed)

        // C 回调桥接到 Swift
        let selfPtr = Unmanaged.passRetained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let ptr = userData else { return OSStatus(eventNotHandledErr) }
                let mgr = Unmanaged<HotkeyManager>.fromOpaque(ptr).takeUnretainedValue()
                DispatchQueue.main.async { mgr.onActivate?() }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )

        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }
}
