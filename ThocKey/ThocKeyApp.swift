import SwiftUI
import AppKit

@main
struct ThocKeyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("ThocKey Studio", id: "studio") {
            ContentView()
                .frame(minWidth: 620, minHeight: 520)
        }
        
        MenuBarExtra("ThocKey", systemImage: "keyboard") {
            MenuBarOptions()
        }
    }
}

struct MenuBarOptions: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var soundManager = SoundManager.shared
    
    var body: some View {
        Button(soundManager.isGlobalSoundEnabled ? "Mute Sounds" : "Enable Sounds") {
            soundManager.isGlobalSoundEnabled.toggle()
        }
        
        Divider()
        
        Menu("Active Pack: \(soundManager.selectedSoundPackName)") {
            ForEach(soundManager.allPacks) { pack in
                Button(pack.name) {
                    soundManager.selectedSoundPackName = pack.name
                }
            }
        }
        
        Divider()
        
        Button("Open ThocKey Studio...") {
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
        
        // 2️⃣ Global keyboard monitoring (when app is in background)
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 46 { // ⌘ + ⇧ + M
                SoundManager.shared.isGlobalSoundEnabled.toggle()
                return
            }
            SoundManager.shared.playKeyEvent(type: .down, keyCode: event.keyCode)
        }

        NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { event in
            SoundManager.shared.playKeyEvent(type: .up, keyCode: event.keyCode)
        }
        
        // 3️⃣ Local keyboard monitoring (when app is in foreground)
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 46 { // ⌘ + ⇧ + M
                SoundManager.shared.isGlobalSoundEnabled.toggle()
                return nil // consume the event
            }
            SoundManager.shared.playKeyEvent(type: .down, keyCode: event.keyCode)
            return event
        }
        
        NSEvent.addLocalMonitorForEvents(matching: .keyUp) { event in
            SoundManager.shared.playKeyEvent(type: .up, keyCode: event.keyCode)
            return event
        }
    }
    
    // Prevent the app from quitting when the main window is closed
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
