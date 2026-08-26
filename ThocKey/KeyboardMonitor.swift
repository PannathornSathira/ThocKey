import AppKit

@MainActor
public protocol KeyboardMonitoring: AnyObject {
    var isAccessibilityEnabled: Bool { get }
    func requestAccessibilityPermission()
    func start(
        onKeyDown: @escaping (UInt16) -> Void,
        onKeyUp: @escaping (UInt16) -> Void,
        onToggleMute: @escaping () -> Void
    )
    func stop()
}

@MainActor
public final class KeyboardMonitor: KeyboardMonitoring {
    private var globalMonitors: [Any] = []
    private var localMonitors: [Any] = []
    private var lastModifierFlags: NSEvent.ModifierFlags = []
    private var suppressedKeyUpKeyCode: UInt16?
    private var suppressModifierSoundsUntil: Date = .distantPast

    public init() {}

    public var isAccessibilityEnabled: Bool {
        AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false
        ] as CFDictionary)
    }

    public func requestAccessibilityPermission() {
        _ = AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary)
    }

    public func start(
        onKeyDown: @escaping (UInt16) -> Void,
        onKeyUp: @escaping (UInt16) -> Void,
        onToggleMute: @escaping () -> Void
    ) {
        guard globalMonitors.isEmpty, localMonitors.isEmpty else { return }
        lastModifierFlags = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            if Self.isMuteShortcut(event) {
                self?.suppressedKeyUpKeyCode = event.keyCode
                self?.suppressModifierSoundsUntil = Date().addingTimeInterval(0.5)
                onToggleMute()
            } else {
                onKeyDown(event.keyCode)
            }
        }) { globalMonitors.append(monitor) }

        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyUp, handler: { [weak self] event in
            if event.keyCode == self?.suppressedKeyUpKeyCode {
                self?.suppressedKeyUpKeyCode = nil
                return
            }
            onKeyUp(event.keyCode)
        }) { globalMonitors.append(monitor) }

        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
            self?.handleFlagsChanged(event: event, onKeyDown: onKeyDown, onKeyUp: onKeyUp)
        }) { globalMonitors.append(monitor) }

        if let localDown = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            if Self.isMuteShortcut(event) {
                self?.suppressedKeyUpKeyCode = event.keyCode
                self?.suppressModifierSoundsUntil = Date().addingTimeInterval(0.5)
                onToggleMute()
                return nil
            }
            onKeyDown(event.keyCode)
            return event
        }) { localMonitors.append(localDown) }

        if let localUp = NSEvent.addLocalMonitorForEvents(matching: .keyUp, handler: { [weak self] event in
            if event.keyCode == self?.suppressedKeyUpKeyCode {
                self?.suppressedKeyUpKeyCode = nil
                return nil
            }
            onKeyUp(event.keyCode)
            return event
        }) { localMonitors.append(localUp) }

        if let localFlags = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
            self?.handleFlagsChanged(event: event, onKeyDown: onKeyDown, onKeyUp: onKeyUp)
            return event
        }) { localMonitors.append(localFlags) }
    }

    public func stop() {
        globalMonitors.forEach(NSEvent.removeMonitor)
        localMonitors.forEach(NSEvent.removeMonitor)
        globalMonitors.removeAll()
        localMonitors.removeAll()
        lastModifierFlags = []
        suppressedKeyUpKeyCode = nil
        suppressModifierSoundsUntil = .distantPast
    }

    private func handleFlagsChanged(
        event: NSEvent,
        onKeyDown: (UInt16) -> Void,
        onKeyUp: (UInt16) -> Void
    ) {
        let currentFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let keyCode = event.keyCode

        if Date() < suppressModifierSoundsUntil {
            lastModifierFlags = currentFlags
            return
        }

        let flag: NSEvent.ModifierFlags? = {
            switch keyCode {
            case 54, 55: return .command
            case 56, 60: return .shift
            case 58, 61: return .option
            case 59, 62: return .control
            case 57: return .capsLock
            case 63: return .function
            default: return nil
            }
        }()

        if let flag {
            let isNowPressed = currentFlags.contains(flag)
            let wasPressed = lastModifierFlags.contains(flag)
            if isNowPressed && !wasPressed {
                onKeyDown(keyCode)
            } else if !isNowPressed && wasPressed {
                onKeyUp(keyCode)
            }
        }
        lastModifierFlags = currentFlags
    }

    private static func isMuteShortcut(_ event: NSEvent) -> Bool {
        event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains([.command, .shift]) && event.keyCode == 46
    }
}
