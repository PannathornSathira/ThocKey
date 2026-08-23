import SwiftUI
import UniformTypeIdentifiers

public struct PackEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var soundManager = SoundManager.shared
    
    @State private var packName: String = "My Custom Pack"
    @State private var defaultDownSoundId: String = "builtin_thock_down"
    @State private var defaultUpSoundId: String = "builtin_thock_up"
    
    @State private var spaceSoundId: String = "None"
    @State private var enterSoundId: String = "None"
    @State private var backspaceSoundId: String = "None"
    @State private var escapeSoundId: String = "None"
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Pack Details")) {
                    TextField("Pack Name", text: $packName)
                }
                
                Section(header: Text("Default Sounds")) {
                    SoundPickerView(
                        title: "Key Down",
                        selectionSoundId: $defaultDownSoundId,
                        includeDefaultOption: false
                    )
                    
                    SoundPickerView(
                        title: "Key Up",
                        selectionSoundId: $defaultUpSoundId,
                        includeDefaultOption: false
                    )
                }
                
                Section(header: Text("Special Keys (Optional)")) {
                    SoundPickerView(
                        title: "Space Bar",
                        selectionSoundId: $spaceSoundId,
                        includeDefaultOption: true
                    )
                    
                    SoundPickerView(
                        title: "Enter",
                        selectionSoundId: $enterSoundId,
                        includeDefaultOption: true
                    )
                    
                    SoundPickerView(
                        title: "Backspace",
                        selectionSoundId: $backspaceSoundId,
                        includeDefaultOption: true
                    )
                    
                    SoundPickerView(
                        title: "Escape",
                        selectionSoundId: $escapeSoundId,
                        includeDefaultOption: true
                    )
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
            .navigationTitle("Create Sound Pack")
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
        .frame(minWidth: 500, minHeight: 550)
    }
    
    private func importAudioFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType.wav, UTType.mp3, UTType.aiff]
        
        if panel.runModal() == .OK, let url = panel.url {
            if let newSound = soundManager.importSound(from: url) {
                defaultDownSoundId = newSound.id
            }
        }
    }
    
    private func savePack() {
        var mappings: [UInt16: String] = [:]
        if spaceSoundId != "None" && !spaceSoundId.isEmpty { mappings[49] = spaceSoundId }
        if enterSoundId != "None" && !enterSoundId.isEmpty { mappings[36] = enterSoundId }
        if backspaceSoundId != "None" && !backspaceSoundId.isEmpty { mappings[51] = backspaceSoundId }
        if escapeSoundId != "None" && !escapeSoundId.isEmpty { mappings[53] = escapeSoundId }
        
        let newPack = SoundPack(
            name: packName.trimmingCharacters(in: .whitespaces),
            defaultDownSoundId: defaultDownSoundId,
            defaultUpSoundId: defaultUpSoundId,
            keyMappings: mappings,
            isBuiltIn: false
        )
        
        soundManager.saveCustomPack(newPack)
        soundManager.selectedSoundPackName = newPack.name
    }
}
