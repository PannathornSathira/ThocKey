import SwiftUI
import UniformTypeIdentifiers

public struct PackEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var appModel = AppModel.shared

    @State private var packName = "My Custom Pack"
    @State private var defaultDownSoundID = "builtin_thock_down"
    @State private var defaultUpSoundID = "builtin_thock_up"
    @State private var spaceSoundID = "None"
    @State private var enterSoundID = "None"
    @State private var backspaceSoundID = "None"
    @State private var escapeSoundID = "None"

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Create Sound Pack")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(StudioTheme.espresso)
                    Text("Choose default sounds and optional special-key overrides.")
                        .font(.system(size: 12))
                        .foregroundStyle(StudioTheme.secondaryText)
                }
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(SecondaryButtonStyle())
                Button("Save Pack") { savePack() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(packName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(StudioTheme.Spacing.large)

            Divider().overlay(StudioTheme.separator)

            ScrollView {
                VStack(alignment: .leading, spacing: StudioTheme.Spacing.large) {
                    EditorSection(title: "Pack details") {
                        TextField("Pack name", text: $packName)
                            .textFieldStyle(.roundedBorder)
                    }

                    EditorSection(title: "Default sounds") {
                        VStack(spacing: StudioTheme.Spacing.medium) {
                            SoundPickerView(title: "Key Down", selectionSoundId: $defaultDownSoundID, includeDefaultOption: false)
                            Divider().overlay(StudioTheme.separator)
                            SoundPickerView(title: "Key Up", selectionSoundId: $defaultUpSoundID, includeDefaultOption: false)
                        }
                    }

                    EditorSection(title: "Special keys") {
                        VStack(spacing: StudioTheme.Spacing.medium) {
                            SoundPickerView(title: "Space Bar", selectionSoundId: $spaceSoundID, includeDefaultOption: true)
                            Divider().overlay(StudioTheme.separator)
                            SoundPickerView(title: "Enter", selectionSoundId: $enterSoundID, includeDefaultOption: true)
                            Divider().overlay(StudioTheme.separator)
                            SoundPickerView(title: "Backspace", selectionSoundId: $backspaceSoundID, includeDefaultOption: true)
                            Divider().overlay(StudioTheme.separator)
                            SoundPickerView(title: "Escape", selectionSoundId: $escapeSoundID, includeDefaultOption: true)
                        }
                    }

                    Button(action: importAudioFile) {
                        Label("Import audio for this pack", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding(StudioTheme.Spacing.large)
            }
        }
        .frame(minWidth: 560, minHeight: 620)
        .background(StudioTheme.canvas)
    }

    private func importAudioFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.wav, .mp3, .aiff, .mpeg4Audio]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { defaultDownSoundID = try appModel.importSound(from: url).id }
        catch { appModel.present(error) }
    }

    private func savePack() {
        var mappings: [UInt16: String] = [:]
        if spaceSoundID != "None" { mappings[49] = spaceSoundID }
        if enterSoundID != "None" { mappings[36] = enterSoundID }
        if backspaceSoundID != "None" { mappings[51] = backspaceSoundID }
        if escapeSoundID != "None" { mappings[53] = escapeSoundID }
        let pack = SoundPack(
            name: packName,
            defaultDownSoundId: defaultDownSoundID,
            defaultUpSoundId: defaultUpSoundID,
            keyMappings: mappings
        )
        do {
            try appModel.saveCustomPack(pack)
            appModel.selectPack(id: pack.id)
            dismiss()
        } catch { appModel.present(error) }
    }
}

private struct EditorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: StudioTheme.Spacing.small) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.7)
                .foregroundStyle(StudioTheme.walnut)
            StudioSurface { content() }
        }
    }
}
