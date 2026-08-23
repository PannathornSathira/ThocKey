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

        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { event in
            if Self.isMuteShortcut(event) { onToggleMute() } else { onKeyDown(event.keyCode) }
        }) { globalMonitors.append(monitor) }

        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyUp, handler: { event in
            onKeyUp(event.keyCode)
        }) { globalMonitors.append(monitor) }

        if let localDown = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { event in
            if Self.isMuteShortcut(event) {
                onToggleMute()
                return nil
            }
            onKeyDown(event.keyCode)
            return event
        }) { localMonitors.append(localDown) }

        if let localUp = NSEvent.addLocalMonitorForEvents(matching: .keyUp, handler: { event in
            onKeyUp(event.keyCode)
            return event
        }) { localMonitors.append(localUp) }
    }

    public func stop() {
        globalMonitors.forEach(NSEvent.removeMonitor)
        localMonitors.forEach(NSEvent.removeMonitor)
        globalMonitors.removeAll()
        localMonitors.removeAll()
    }

    private static func isMuteShortcut(_ event: NSEvent) -> Bool {
        event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains([.command, .shift]) && event.keyCode == 46
    }
}
