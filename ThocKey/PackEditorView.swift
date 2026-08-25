import SwiftUI
import UniformTypeIdentifiers

public struct PackEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var appModel = AppModel.shared

    @State private var packName = "My Custom Pack"
    @State private var defaultSoundID = "builtin_thock"
    @State private var spaceSoundID = "None"
    @State private var enterSoundID = "None"
    @State private var backspaceSoundID = "None"
    @State private var escapeSoundID = "None"
    @State private var tabSoundID = "None"
    @State private var commandSoundID = "None"
    @State private var shiftSoundID = "None"
    @State private var optionSoundID = "None"
    @State private var controlSoundID = "None"

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
                        SoundPickerView(title: "Default Sound", selectionSoundId: $defaultSoundID, includeDefaultOption: false)
                            .accessibilityIdentifier("default-sound-picker")
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
                            Divider().overlay(StudioTheme.separator)
                            SoundPickerView(title: "Tab", selectionSoundId: $tabSoundID, includeDefaultOption: true)
                        }
                    }

                    EditorSection(title: "Modifier keys") {
                        VStack(spacing: StudioTheme.Spacing.medium) {
                            SoundPickerView(title: "Command (⌘)", selectionSoundId: $commandSoundID, includeDefaultOption: true)
                            Divider().overlay(StudioTheme.separator)
                            SoundPickerView(title: "Shift (⇧)", selectionSoundId: $shiftSoundID, includeDefaultOption: true)
                            Divider().overlay(StudioTheme.separator)
                            SoundPickerView(title: "Option / Alt (⌥)", selectionSoundId: $optionSoundID, includeDefaultOption: true)
                            Divider().overlay(StudioTheme.separator)
                            SoundPickerView(title: "Control (⌃)", selectionSoundId: $controlSoundID, includeDefaultOption: true)
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
        do { defaultSoundID = try appModel.importSound(from: url).id }
        catch { appModel.present(error) }
    }

    private func savePack() {
        var mappings: [UInt16: String] = [:]
        if spaceSoundID != "None" { mappings[49] = spaceSoundID }
        if enterSoundID != "None" { mappings[36] = enterSoundID }
        if backspaceSoundID != "None" { mappings[51] = backspaceSoundID }
        if escapeSoundID != "None" { mappings[53] = escapeSoundID }
        if tabSoundID != "None" { mappings[48] = tabSoundID }
        if commandSoundID != "None" { mappings[55] = commandSoundID; mappings[54] = commandSoundID }
        if shiftSoundID != "None" { mappings[56] = shiftSoundID; mappings[60] = shiftSoundID }
        if optionSoundID != "None" { mappings[58] = optionSoundID; mappings[61] = optionSoundID }
        if controlSoundID != "None" { mappings[59] = controlSoundID; mappings[62] = controlSoundID }
        let pack = SoundPack(
            name: packName,
            defaultSoundId: defaultSoundID,
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
