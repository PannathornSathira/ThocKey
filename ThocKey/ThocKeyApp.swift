import SwiftUI
import AppKit
import ApplicationServices

@main
struct ThocKeyApp: App {

    // Keep a reference to the status item
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Empty WindowGroup, we don't need a window anymore
        Settings {
            EmptyView()
        }
    }
}

// AppDelegate to handle menu bar & global keyboard
class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        
        // 1️⃣ Accessibility permission prompt
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        print("Accessibility enabled:", accessEnabled)
        
        // 2️⃣ Setup menu bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "ThocKey")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit ThocKey", action: #selector(quit), keyEquivalent: "q"))
        statusItem?.menu = menu

        // 3️⃣ Load sounds
        SoundManager.shared.loadSound(named: "thock_down")
        SoundManager.shared.loadSound(named: "thock_up")

        // 4️⃣ Global keyboard monitoring
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { _ in
            SoundManager.shared.playSound(named: "thock_down")
        }

        NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { _ in
            SoundManager.shared.playSound(named: "thock_up")
        }
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
}
