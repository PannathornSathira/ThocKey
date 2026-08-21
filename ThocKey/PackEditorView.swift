import SwiftUI
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
