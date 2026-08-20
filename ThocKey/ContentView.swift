import SwiftUI

struct ContentView: View {
    @State private var text: String = ""
    
    var body: some View {
        
        Text("Press and release any key to play a sound.")
            .font(.largeTitle)
            .padding()
        TextField("Type here...", text: $text)
            .font(.largeTitle)
            .padding()
            .onAppear {
                // preload sounds ONCE
                SoundManager.shared.loadSound(named: "thock_down")
                SoundManager.shared.loadSound(named: "thock_up")
                
                // 🔥 FORCE macOS to ask for permission
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
                print("Accessibility enabled:", accessEnabled)
                
                // ✅ LOCAL (keep this so you know it still works)
                NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    print("LOCAL DOWN")
                    SoundManager.shared.playSound(named: "thock_down")
                    return event
                }
                NSEvent.addLocalMonitorForEvents(matching: .keyUp) { event in
                    print("LOCAL UP")
                    SoundManager.shared.playSound(named: "thock_up")
                    return event
                }
                
                // ✅ GLOBAL (this is what you want)
                NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { _ in
                    print("GLOBAL DOWN")
                    SoundManager.shared.playSound(named: "thock_down")
                }
                
                NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { _ in
                    print("GLOBAL UP")
                    SoundManager.shared.playSound(named: "thock_up")
                }
            }
    }
}
