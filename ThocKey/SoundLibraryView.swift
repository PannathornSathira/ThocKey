import SwiftUI
import UniformTypeIdentifiers

public struct SoundLibraryView: View {
    @ObservedObject private var soundManager = SoundManager.shared
    
    @State private var searchText: String = ""
    @State private var selectedFilter: SoundCategory? = nil
    
    // Customizer Sheet
    @State private var soundToCustomize: SoundItem? = nil
    @State private var isShowingCustomizer: Bool = false
    
    // Rename State
    @State private var soundToRename: SoundItem? = nil
    @State private var renameText: String = ""
    @State private var isShowingRenameAlert: Bool = false
    
    // Delete Confirmation
    @State private var soundToDelete: SoundItem? = nil
    @State private var isShowingDeleteAlert: Bool = false
    
    // Active Playing Sound ID for UI state
    @State private var currentlyPlayingId: String? = nil
    
    public init() {}
    
    private var filteredSounds: [SoundItem] {
        soundManager.soundLibrary.filter { sound in
            let matchesSearch = searchText.isEmpty ||
                sound.displayName.localizedCaseInsensitiveContains(searchText) ||
                sound.packName.localizedCaseInsensitiveContains(searchText)
            
            let matchesCategory = selectedFilter == nil || sound.category == selectedFilter
            return matchesSearch && matchesCategory
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Top Toolbar
            HStack(spacing: 12) {
                // Search Field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search sounds or packs...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .frame(maxWidth: 240)
                
                // Category Filter Picker
                Picker("Filter", selection: $selectedFilter) {
                    Text("All Sounds").tag(SoundCategory?.none)
                    ForEach(SoundCategory.allCases) { cat in
                        Text(cat.rawValue).tag(SoundCategory?.some(cat))
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
                
                Spacer()
                
                // Import Audio Button
                Button(action: importAudioFile) {
                    Label("Import Audio", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Sound List
            if filteredSounds.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "speaker.slash")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("No sounds found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Import an audio file (.wav, .mp3) or try a different search.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredSounds) { sound in
                        let isCurrentlyActive = soundManager.activePack.defaultDownSoundId == sound.id ||
                                                soundManager.selectedSoundPackName.localizedCaseInsensitiveContains(sound.packName)
                        
                        SoundRowView(
                            sound: sound,
                            isActive: isCurrentlyActive,
                            isPlaying: currentlyPlayingId == sound.id,
                            onPlay: {
                                playSound(sound)
                            },
                            onSetActive: {
                                soundManager.setActiveSound(sound: sound)
                            },
                            onCustomize: {
                                soundToCustomize = sound
                                isShowingCustomizer = true
                            },
                            onRename: {
                                soundToRename = sound
                                renameText = sound.displayName
                                isShowingRenameAlert = true
                            },
                            onDelete: {
                                soundToDelete = sound
                                isShowingDeleteAlert = true
                            }
                        )
                        .padding(.vertical, 3)
                    }
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $isShowingCustomizer) {
            if let sound = soundToCustomize {
                AudioCustomizerView(sound: sound)
            }
        }
        .alert("Rename Sound", isPresented: $isShowingRenameAlert) {
            TextField("Sound Name", text: $renameText)
            Button("Save") {
                if let sound = soundToRename {
                    soundManager.renameSound(id: sound.id, newDisplayName: renameText)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a new official display name for this sound.")
        }
        .alert("Delete Sound", isPresented: $isShowingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let sound = soundToDelete {
                    _ = soundManager.deleteSound(id: sound.id)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete '\(soundToDelete?.displayName ?? "")'? This will permanently remove the audio file.")
        }
    }
    
    private func playSound(_ sound: SoundItem) {
        currentlyPlayingId = sound.id
        soundManager.playPreview(soundId: sound.id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if currentlyPlayingId == sound.id {
                currentlyPlayingId = nil
            }
        }
    }
    
    private func importAudioFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType.wav, UTType.mp3, UTType.aiff]
        
        if panel.runModal() == .OK, let url = panel.url {
            if let newSound = soundManager.importSound(from: url) {
                soundToCustomize = newSound
                isShowingCustomizer = true
            }
        }
    }
}

private struct SoundRowView: View {
    let sound: SoundItem
    let isActive: Bool
    let isPlaying: Bool
    let onPlay: () -> Void
    let onSetActive: () -> Void
    let onCustomize: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Play button
            Button(action: onPlay) {
                Image(systemName: isPlaying ? "speaker.wave.3.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(isPlaying ? .green : .accentColor)
            }
            .buttonStyle(.plain)
            .help("Preview Sound")
            
            // Name & Pack
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(sound.displayName)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    if !sound.isBuiltIn {
                        Button(action: onRename) {
                            Image(systemName: "pencil")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Rename Sound")
                    }
                }
                
                HStack(spacing: 6) {
                    Text(sound.packName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(String(format: "%.0f ms", sound.duration * 1000))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Active Sound Pack Status or Quick Activate Button
            if isActive {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Active Pack")
                }
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.12))
                .cornerRadius(8)
            } else {
                Button(action: onSetActive) {
                    Text("Use as Active")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .help("Set this sound as your active typing pack")
            }
            
            // Category Badge
            Text(sound.category.rawValue)
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(badgeBackground)
                .foregroundColor(badgeForeground)
                .cornerRadius(10)
            
            // Trim / Customize Action
            Button(action: onCustomize) {
                Label("Customize", systemImage: "slider.horizontal.3")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .help("Open in Audio Customizer")
            
            // Delete Action
            if !sound.isBuiltIn {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Delete Sound")
            }
        }
        .padding(.vertical, 3)
    }
    
    private var badgeBackground: Color {
        switch sound.category {
        case .builtIn:
            return Color.blue.opacity(0.12)
        case .custom:
            return Color.green.opacity(0.12)
        case .trimmed:
            return Color.purple.opacity(0.12)
        }
    }
    
    private var badgeForeground: Color {
        switch sound.category {
        case .builtIn:
            return Color.blue
        case .custom:
            return Color.green
        case .trimmed:
            return Color.purple
        }
    }
}
