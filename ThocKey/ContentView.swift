import SwiftUI

struct ContentView: View {
    @StateObject private var soundManager = SoundManager.shared
    @State private var typingTestText: String = ""
    @State private var isAccessibilityEnabled: Bool = false
    @State private var isShowingPackEditor: Bool = false
    
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
                    
                    Text("Global Mute Shortcut: ⌘ + ⇧ + M (Cmd + Shift + M)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
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
                    HStack {
                        Picker("Active Pack", selection: $soundManager.selectedSoundPackName) {
                            ForEach(soundManager.allPacks) { pack in
                                Text(pack.name).tag(pack.name)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        Spacer()
                        
                        Button("Create Pack") {
                            isShowingPackEditor = true
                        }
                    }
                }
                
                // Section 3: Key Mapping
                Section(header: Text("Key Mappings").font(.headline)) {
                    Text("Customize sounds for specific keys in the current pack.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    KeyMappingRow(title: "Space Bar", keyCode: 49)
                    KeyMappingRow(title: "Enter", keyCode: 36)
                    KeyMappingRow(title: "Backspace", keyCode: 51)
                    KeyMappingRow(title: "Escape", keyCode: 53)
                }
                
                // Section 4: Testing Area
                Section(header: Text("Typing Test Area").font(.headline)) {
                    TextField("Type here to test your sounds...", text: $typingTestText)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                        .padding(.vertical, 4)
                }
                
                // Section 5: Accessibility Status
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
        .sheet(isPresented: $isShowingPackEditor) {
            PackEditorView()
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

struct KeyMappingRow: View {
    let title: String
    let keyCode: UInt16
    @ObservedObject var soundManager = SoundManager.shared
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Picker("", selection: Binding(
                get: { soundManager.activePack.keyMappings[keyCode] ?? "None" },
                set: { soundManager.setMapping(for: keyCode, soundName: $0) }
            )) {
                Text("Default").tag("None")
                ForEach(soundManager.availableSounds, id: \.self) { sound in
                    Text(sound).tag(sound)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 150)
        }
    }
}

import UniformTypeIdentifiers

struct PackEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var soundManager = SoundManager.shared
    
    @State private var packName: String = "My Custom Pack"
    @State private var defaultDown: String = "thock_down"
    @State private var defaultUp: String = "thock_up"
    
    @State private var spaceSound: String = "None"
    @State private var enterSound: String = "None"
    @State private var backspaceSound: String = "None"
    @State private var escapeSound: String = "None"
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Pack Details")) {
                    TextField("Pack Name", text: $packName)
                }
                
                Section(header: Text("Default Sounds")) {
                    SoundPickerRow(title: "Key Down", selection: $defaultDown, includeNone: false)
                    SoundPickerRow(title: "Key Up", selection: $defaultUp, includeNone: false)
                }
                
                Section(header: Text("Special Keys (Optional)")) {
                    SoundPickerRow(title: "Space Bar", selection: $spaceSound, includeNone: true)
                    SoundPickerRow(title: "Enter", selection: $enterSound, includeNone: true)
                    SoundPickerRow(title: "Backspace", selection: $backspaceSound, includeNone: true)
                    SoundPickerRow(title: "Escape", selection: $escapeSound, includeNone: true)
                }
                
                Section {
                    Button(action: importAudioFile) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Import New Audio File (.wav or .mp3)")
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Pack") {
                        savePack()
                        dismiss()
                    }
                    .disabled(packName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .frame(width: 500, height: 600)
    }
    
    private func importAudioFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType.wav, UTType.mp3]
        
        if panel.runModal() == .OK, let url = panel.url {
            if let newSoundName = soundManager.importSound(from: url) {
                print("Imported: \(newSoundName)")
            }
        }
    }
    
    private func savePack() {
        var mappings: [UInt16: String] = [:]
        if spaceSound != "None" { mappings[49] = spaceSound }
        if enterSound != "None" { mappings[36] = enterSound }
        if backspaceSound != "None" { mappings[51] = backspaceSound }
        if escapeSound != "None" { mappings[53] = escapeSound }
        
        let newPack = SoundPack(
            name: packName.trimmingCharacters(in: .whitespaces),
            defaultDown: defaultDown,
            defaultUp: defaultUp,
            keyMappings: mappings
        )
        
        soundManager.saveCustomPack(newPack)
        soundManager.selectedSoundPackName = newPack.name
    }
}

struct SoundPickerRow: View {
    let title: String
    @Binding var selection: String
    let includeNone: Bool
    @ObservedObject var soundManager = SoundManager.shared
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Picker("", selection: $selection) {
                if includeNone {
                    Text("Default").tag("None")
                }
                ForEach(soundManager.availableSounds, id: \.self) { sound in
                    Text(sound).tag(sound)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 200)
        }
    }
}

#Preview {
    ContentView()
}
