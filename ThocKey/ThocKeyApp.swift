import SwiftUI
import AppKit

@main
struct ThocKeyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("ThocKey Studio", id: "studio") {
            ContentView()
                .frame(idealWidth: 1100, idealHeight: 760)
        }
        .defaultSize(width: 1100, height: 760)
        
        MenuBarExtra("ThocKey", systemImage: "keyboard") {
            MenuBarOptions()
        }
    }
}

struct MenuBarOptions: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var soundManager = SoundManager.shared
    
    var body: some View {
        Button(soundManager.isGlobalSoundEnabled ? "Mute ThocKey" : "Enable ThocKey") {
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
        let isUITesting = ProcessInfo.processInfo.environment["THOCKEY_UI_TEST"] == "1"
        AppModel.shared.startKeyboardMonitoring(requestPermission: !isUITesting)
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppModel.shared.stopKeyboardMonitoring()
    }
    
    // Prevent the app from quitting when the main window is closed
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
