import SwiftUI

public struct SoundPickerView: View {
    public let title: String
    @Binding public var selectionSoundId: String
    public let includeDefaultOption: Bool
    public var defaultOptionTitle: String = "Default"
    
    @ObservedObject private var appModel = AppModel.shared
    
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
        if let sound = appModel.findSound(byId: selectionSoundId) {
            return sound.displayName
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
                    appModel.playPreview(soundId: selectionSoundId)
                }) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.caption)
                        .foregroundStyle(StudioTheme.walnut)
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
                
                let grouped = appModel.groupedSoundsByCategory()
                ForEach(grouped, id: \.category) { group in
                    Section(header: Text(group.category.rawValue)) {
                        ForEach(group.sounds) { sound in
                            Button(action: {
                                selectionSoundId = sound.id
                                appModel.playPreview(soundId: sound.id)
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
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(StudioTheme.espresso)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(StudioTheme.secondaryText)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(StudioTheme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(StudioTheme.separator, lineWidth: 1)
                )
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .frame(minWidth: 160, maxWidth: 220)
        }
    }
}
