import SwiftUI
import AppKit

@main
struct ThocKeyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("ThocKey Studio", id: "studio") {
            ContentView()
                // Force window to have a minimum size
                .frame(minWidth: 400, minHeight: 300)
        }
        
        MenuBarExtra("ThocKey", systemImage: "keyboard") {
            MenuBarOptions()
        }
    }
}

struct MenuBarOptions: View {
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        Button("Open ThocKey Studio") {
            openWindow(id: "studio")
            NSApp.activate(ignoringOtherApps: true)
        }
        Divider()
        Button("Quit ThocKey") {
            NSApplication.shared.terminate(nil)
        }
    }
}

// AppDelegate handles global keyboard monitoring setup
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        
        // 1️⃣ Accessibility permission prompt
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        print("Accessibility enabled:", accessEnabled)
        
        // 2️⃣ Load sounds
        SoundManager.shared.loadSound(named: "thock_down")
        SoundManager.shared.loadSound(named: "thock_up")
        SoundManager.shared.loadSound(named: "creamy_key")
        SoundManager.shared.loadSound(named: "clicky_key")
        SoundManager.shared.loadSound(named: "quiet_key")

        // 3️⃣ Global keyboard monitoring (when app is in background)
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { _ in
            SoundManager.shared.playKeyEvent(type: .down)
        }

        NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { _ in
            SoundManager.shared.playKeyEvent(type: .up)
        }
        
        // 4️⃣ Local keyboard monitoring (when app is in foreground)
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            SoundManager.shared.playKeyEvent(type: .down)
            return event
        }
        
        NSEvent.addLocalMonitorForEvents(matching: .keyUp) { event in
            SoundManager.shared.playKeyEvent(type: .up)
            return event
        }
    }
    
    // Prevent the app from quitting when the main window is closed
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
