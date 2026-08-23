import SwiftUI

public struct SoundPickerView: View {
    public let title: String
    @Binding public var selectionSoundId: String
    public let includeDefaultOption: Bool
    public var defaultOptionTitle: String = "Default"
    
    @ObservedObject private var soundManager = SoundManager.shared
    
    public init(
        title: String = "",
        selectionSoundId: Binding<String>,
        includeDefaultOption: Bool = true,
        defaultOptionTitle: String = "Default"
    ) {
        self.title = title
        self._selectionSoundId = selectionSoundId
        self.includeDefaultOption = includeDefaultOption
        self.defaultOptionTitle = defaultOptionTitle
    }
    
    private var selectedDisplayName: String {
        if selectionSoundId == "None" || selectionSoundId.isEmpty {
            return defaultOptionTitle
        }
        if let sound = soundManager.findSound(byId: selectionSoundId) {
            return "\(sound.displayName) (\(sound.packName))"
        }
        return selectionSoundId
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(.body)
                Spacer()
            }
            
            // Audio preview button for the currently selected sound
            if selectionSoundId != "None" && !selectionSoundId.isEmpty {
                Button(action: {
                    soundManager.playPreview(soundId: selectionSoundId)
                }) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("Preview this sound")
            }
            
            Menu {
                if includeDefaultOption {
                    Button(action: {
                        selectionSoundId = "None"
                    }) {
                        HStack {
                            Text(defaultOptionTitle)
                            if selectionSoundId == "None" || selectionSoundId.isEmpty {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    Divider()
                }
                
                let grouped = soundManager.groupedSoundsByPack()
                ForEach(grouped, id: \.packName) { group in
                    Section(header: Text("\(group.packName) Pack")) {
                        ForEach(group.sounds) { sound in
                            Button(action: {
                                selectionSoundId = sound.id
                                soundManager.playPreview(soundId: sound.id)
                            }) {
                                HStack {
                                    Text(sound.displayName)
                                    if selectionSoundId == sound.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(selectedDisplayName)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(StudioTheme.surfaceMuted)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            }
            .frame(minWidth: 160, maxWidth: 220)
        }
    }
}
