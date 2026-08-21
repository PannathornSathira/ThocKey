import SwiftUI

struct ContentView: View {
    @StateObject private var soundManager = SoundManager.shared
    @State private var typingTestText: String = ""
    @State private var isAccessibilityEnabled: Bool = false
    
    // MVP sound packs
    let availablePacks = ["Thocky (Default)", "Creamy", "Clicky", "Quiet"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header & Privacy Promise
            VStack(alignment: .leading, spacing: 8) {
                Text("ThocKey Studio")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("ThocKey detects key events to play sounds but never records what you type.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            Form {
                // Section 1: Main Controls
                Section(header: Text("Global Settings").font(.headline)) {
                    Toggle("Enable Typing Sounds", isOn: $soundManager.isGlobalSoundEnabled)
                        .toggleStyle(.switch)
                        .padding(.vertical, 4)
                    
                    VStack(alignment: .leading) {
                        Text("Master Volume")
                        Slider(value: $soundManager.masterVolume, in: 0...1) {
                            Text("Volume")
                        } minimumValueLabel: {
                            Image(systemName: "speaker.fill")
                                .foregroundColor(.secondary)
                        } maximumValueLabel: {
                            Image(systemName: "speaker.wave.3.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Section 2: Sound Packs
                Section(header: Text("Sound Pack").font(.headline)) {
                    Picker("Active Pack", selection: $soundManager.selectedSoundPack) {
                        ForEach(availablePacks, id: \.self) { pack in
                            Text(pack).tag(pack)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Section 3: Testing Area
                Section(header: Text("Typing Test Area").font(.headline)) {
                    TextField("Type here to test your sounds...", text: $typingTestText)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                        .padding(.vertical, 4)
                }
                
                // Section 4: Accessibility Status
                Section(header: Text("Permissions").font(.headline)) {
                    HStack {
                        Image(systemName: isAccessibilityEnabled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(isAccessibilityEnabled ? .green : .yellow)
                        
                        Text(isAccessibilityEnabled ? "Accessibility Granted" : "Accessibility Permission Required")
                        
                        Spacer()
                        
                        if !isAccessibilityEnabled {
                            Button("Open Settings") {
                                openSystemSettings()
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    
                    if !isAccessibilityEnabled {
                        Text("ThocKey needs Accessibility permission to hear your keystrokes globally. Go to System Settings > Privacy & Security > Accessibility.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .padding()
        }
        .onAppear {
            checkAccessibility()
            // Poll occasionally just in case user changes it
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                checkAccessibility()
            }
        }
    }
    
    private func checkAccessibility() {
        // Just checking without prompting here
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        isAccessibilityEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    private func openSystemSettings() {
        // Ask macOS to open Privacy & Security -> Accessibility
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    ContentView()
}
