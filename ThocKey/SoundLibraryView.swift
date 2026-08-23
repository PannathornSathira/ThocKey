import SwiftUI
import UniformTypeIdentifiers

public struct SoundLibraryView: View {
    @ObservedObject private var appModel = AppModel.shared
    @State private var searchText = ""
    @State private var selectedFilter: SoundCategory?
    @State private var soundToCustomize: SoundItem?
    @State private var soundToRename: SoundItem?
    @State private var renameText = ""
    @State private var soundToDelete: SoundItem?
    @State private var currentlyPlayingID: String?

    public init() {}

    private var filteredSounds: [SoundItem] {
        appModel.soundLibrary.filter { sound in
            let matchesSearch = searchText.isEmpty
                || sound.displayName.localizedCaseInsensitiveContains(searchText)
                || sound.packName.localizedCaseInsensitiveContains(searchText)
            return matchesSearch && (selectedFilter == nil || selectedFilter == sound.category)
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StudioSectionHeader(
                title: "Sound Library",
                subtitle: "Preview, organize, and customize your keystroke sounds."
            ) {
                Button(action: importAudioFile) { Label("Import Audio", systemImage: "plus") }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("import-audio-button")
            }
            .padding(.horizontal, StudioTheme.Spacing.xLarge)
            .padding(.top, StudioTheme.Spacing.xLarge)

            HStack(spacing: StudioTheme.Spacing.medium) {
                HStack(spacing: StudioTheme.Spacing.small) {
                    Image(systemName: "magnifyingglass").foregroundStyle(StudioTheme.secondaryText)
                    TextField("Search sounds or packs", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain)
                            .foregroundStyle(StudioTheme.secondaryText)
                    }
                }
                .padding(.horizontal, StudioTheme.Spacing.medium)
                .frame(height: 34)
                .background(StudioTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 8).stroke(StudioTheme.separator) }
                .frame(maxWidth: 320)

                Picker("Category", selection: $selectedFilter) {
                    Text("All").tag(SoundCategory?.none)
                    ForEach(SoundCategory.allCases) { category in Text(category.rawValue).tag(SoundCategory?.some(category)) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 340)
                Spacer()
            }
            .padding(.horizontal, StudioTheme.Spacing.xLarge)
            .padding(.vertical, StudioTheme.Spacing.large)

            if filteredSounds.isEmpty {
                ContentUnavailableView(
                    "No sounds found",
                    systemImage: "waveform.slash",
                    description: Text("Import an audio file or adjust your search.")
                )
                .foregroundStyle(StudioTheme.secondaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(filteredSounds.enumerated()), id: \.element.id) { index, sound in
                            SoundRow(
                                sound: sound,
                                isActive: appModel.activePack.defaultDownSoundId == sound.id || appModel.activePack.defaultUpSoundId == sound.id,
                                isPlaying: currentlyPlayingID == sound.id,
                                onPlay: { play(sound) },
                                onActivate: { activate(sound) },
                                onCustomize: { soundToCustomize = sound },
                                onRename: { soundToRename = sound; renameText = sound.displayName },
                                onDelete: { soundToDelete = sound }
                            )
                            if index < filteredSounds.count - 1 { Divider().overlay(StudioTheme.separator).padding(.leading, 54) }
                        }
                    }
                    .padding(StudioTheme.Spacing.regular)
                    .background(StudioTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 12).stroke(StudioTheme.separator) }
                    .padding(.horizontal, StudioTheme.Spacing.xLarge)
                    .padding(.bottom, StudioTheme.Spacing.xLarge)
                }
            }
        }
        .sheet(item: $soundToCustomize) { AudioCustomizerView(sound: $0) }
        .alert("Rename Sound", isPresented: Binding(get: { soundToRename != nil }, set: { if !$0 { soundToRename = nil } })) {
            TextField("Sound name", text: $renameText)
            Button("Rename") { renameSelectedSound() }
            Button("Cancel", role: .cancel) { soundToRename = nil }
        }
        .alert("Delete Sound?", isPresented: Binding(get: { soundToDelete != nil }, set: { if !$0 { soundToDelete = nil } })) {
            Button("Delete", role: .destructive) { deleteSelectedSound() }
            Button("Cancel", role: .cancel) { soundToDelete = nil }
        } message: {
            Text("The audio file will be permanently removed. Sounds currently used by a pack cannot be deleted.")
        }
    }

    private func play(_ sound: SoundItem) {
        currentlyPlayingID = sound.id
        appModel.playPreview(soundId: sound.id)
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.25, sound.duration)) {
            if currentlyPlayingID == sound.id { currentlyPlayingID = nil }
        }
    }

    private func activate(_ sound: SoundItem) {
        do { try appModel.setActiveSound(sound: sound) } catch { appModel.present(error) }
    }

    private func renameSelectedSound() {
        guard let sound = soundToRename else { return }
        do { try appModel.renameSound(id: sound.id, newDisplayName: renameText) }
        catch { appModel.present(error) }
        soundToRename = nil
    }

    private func deleteSelectedSound() {
        guard let sound = soundToDelete else { return }
        do { try appModel.deleteSound(id: sound.id) } catch { appModel.present(error) }
        soundToDelete = nil
    }

    private func importAudioFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.wav, .mp3, .aiff, .mpeg4Audio]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { soundToCustomize = try appModel.importSound(from: url) }
        catch { appModel.present(error) }
    }
}

public struct SoundRow: View {
    let sound: SoundItem
    let isActive: Bool
    let isPlaying: Bool
    let onPlay: () -> Void
    let onActivate: () -> Void
    let onCustomize: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    public var body: some View {
        HStack(spacing: StudioTheme.Spacing.medium) {
            Button(action: onPlay) {
                Image(systemName: isPlaying ? "speaker.wave.2.fill" : "play.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 34, height: 34)
                    .background(isPlaying ? StudioTheme.moss : StudioTheme.walnut)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Preview \(sound.displayName)")

            VStack(alignment: .leading, spacing: 3) {
                Text(sound.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(StudioTheme.espresso)
                Text("\(sound.packName) · \(String(format: "%.0f ms", sound.duration * 1_000))")
                    .font(.system(size: 11))
                    .foregroundStyle(StudioTheme.secondaryText)
            }
            Spacer()

            if isActive {
                Label("Active", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(StudioTheme.moss)
            } else {
                Button("Use") { onActivate() }.buttonStyle(SecondaryButtonStyle())
            }
            Button { onCustomize() } label: { Image(systemName: "slider.horizontal.3") }
                .buttonStyle(.plain).foregroundStyle(StudioTheme.walnut).help("Customize")
            if !sound.isBuiltIn {
                Button { onRename() } label: { Image(systemName: "pencil") }
                    .buttonStyle(.plain).foregroundStyle(StudioTheme.secondaryText).help("Rename")
                Button { onDelete() } label: { Image(systemName: "trash") }
                    .buttonStyle(.plain).foregroundStyle(StudioTheme.danger).help("Delete")
            }
        }
        .padding(.vertical, StudioTheme.Spacing.medium)
    }
}
