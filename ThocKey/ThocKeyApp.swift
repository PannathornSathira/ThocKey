import SwiftUI
import AppKit

@main
struct ThocKeyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var appModel = AppModel.shared

    var body: some Scene {
        WindowGroup("ThocKey Studio", id: "studio") {
            ContentView()
                .frame(idealWidth: 1100, idealHeight: 760)
                .preferredColorScheme(appModel.appearancePreference.colorScheme)
        }
        .defaultSize(width: 1100, height: 760)
        
        MenuBarExtra("ThocKey", systemImage: "keyboard") {
            MenuBarOptions()
                .preferredColorScheme(appModel.appearancePreference.colorScheme)
        }
    }
}

struct MenuBarOptions: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var appModel = AppModel.shared

    var body: some View {
        Button(appModel.isGlobalSoundEnabled ? "Mute ThocKey" : "Enable ThocKey") {
            appModel.isGlobalSoundEnabled.toggle()
        }

        if appModel.isPaused {
            Button("Resume Sounds (Paused: \(appModel.pauseRemainingFormatted))") {
                appModel.resumeSounds()
            }
        } else {
            Menu("Pause Sounds") {
                Button("Pause for 15 Minutes") {
                    appModel.pauseSounds(for: 15 * 60)
                }
                Button("Pause for 30 Minutes") {
                    appModel.pauseSounds(for: 30 * 60)
                }
                Button("Pause for 1 Hour") {
                    appModel.pauseSounds(for: 60 * 60)
                }
            }
        }

        Menu("Volume: \(Int(appModel.masterVolume * 100))%") {
            ForEach([1.0, 0.75, 0.50, 0.25, 0.0], id: \.self) { level in
                Button {
                    appModel.masterVolume = level
                } label: {
                    let percent = Int(level * 100)
                    let title = level == 0.0 ? "Mute (0%)" : "\(percent)%"
                    if abs(appModel.masterVolume - level) < 0.01 {
                        Label(title, systemImage: "checkmark")
                    } else {
                        Text(title)
                    }
                }
            }
        }

        Button("Preview Active Sound") {
            appModel.playPreview(soundId: appModel.activePack.defaultSoundId)
        }

        Divider()

        if !appModel.favoritePacks.isEmpty {
            Menu("Favorite Packs") {
                ForEach(appModel.favoritePacks) { pack in
                    Button {
                        appModel.selectPack(id: pack.id)
                    } label: {
                        if pack.id == appModel.selectedPackID {
                            Label(pack.name, systemImage: "checkmark")
                        } else {
                            Text(pack.name)
                        }
                    }
                }
            }
        }

        Menu("Active Pack: \(appModel.selectedSoundPackName)") {
            ForEach(appModel.selectablePacks) { pack in
                Button {
                    appModel.selectPack(id: pack.id)
                } label: {
                    if pack.id == appModel.selectedPackID {
                        Label(pack.name, systemImage: "checkmark")
                    } else {
                        Text(pack.name)
                    }
                }
            }
            if !appModel.customSounds.isEmpty {
                Divider()
                ForEach(appModel.customSounds) { sound in
                    Button {
                        do { try appModel.setActiveSound(sound: sound) }
                        catch { appModel.present(error) }
                    } label: {
                        if appModel.activePack.sourceSoundId == sound.id {
                            Label(sound.displayName, systemImage: "checkmark")
                        } else {
                            Text(sound.displayName)
                        }
                    }
                }
            }
        }

        Divider()

        Button("Open ThocKey Studio...") {
            appModel.selectedTab = .packs
            openWindow(id: "studio")
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("Open Settings...") {
            appModel.selectedTab = .settings
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
        
        // Ensure Studio window is foregrounded on launch
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppModel.shared.stopKeyboardMonitoring()
    }
    
    // Prevent the app from quitting when the main window is closed
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
