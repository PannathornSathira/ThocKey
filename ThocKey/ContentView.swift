import AppKit
import SwiftUI

public struct ContentView: View {
    @ObservedObject private var appModel = AppModel.shared
    @State private var selectedTab: StudioTab = .packs
    @State private var isShowingPackEditor = false

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            StudioSidebar(selection: $selectedTab, isAccessibilityEnabled: appModel.isAccessibilityEnabled)
            Divider().overlay(StudioTheme.separator)
            Group {
                switch selectedTab {
                case .packs:
                    PacksStudioView(isShowingPackEditor: $isShowingPackEditor)
                case .keyMapping:
                    KeyMappingsStudioView()
                case .library:
                    SoundLibraryView()
                case .settings:
                    SettingsStudioView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(StudioTheme.canvas)
        }
        .frame(minWidth: 880, minHeight: 640)
        .sheet(isPresented: $isShowingPackEditor) { PackEditorView() }
        .alert("ThocKey couldn’t complete that action", isPresented: errorBinding) {
            Button("OK", role: .cancel) { appModel.presentedError = nil }
        } message: {
            Text(appModel.presentedError?.localizedDescription ?? "Please try again.")
        }
        .onAppear { appModel.refreshAccessibilityStatus() }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { appModel.presentedError != nil },
            set: { if !$0 { appModel.presentedError = nil } }
        )
    }
}

private struct PacksStudioView: View {
    @ObservedObject private var appModel = AppModel.shared
    @Binding var isShowingPackEditor: Bool
    @State private var typingTestText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: StudioTheme.Spacing.large) {
                StudioSectionHeader(
                    title: "Sounds & Packs",
                    subtitle: "Choose and test your active sound pack."
                ) {
                    HStack(spacing: StudioTheme.Spacing.regular) {
                        Toggle("Sound Active", isOn: $appModel.isGlobalSoundEnabled)
                            .toggleStyle(.switch)
                            .tint(StudioTheme.moss)
                            .accessibilityIdentifier("sound-active-toggle")
                        Button { isShowingPackEditor = true } label: {
                            Label("New Pack", systemImage: "plus")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityIdentifier("new-pack-button")
                    }
                }

                // Active Pack Card & Breakdown
                StudioSurface {
                    VStack(alignment: .leading, spacing: StudioTheme.Spacing.regular) {
                        HStack {
                            Text("ACTIVE SOUND PACK")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(0.8)
                                .foregroundStyle(StudioTheme.walnut)
                            Spacer()
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(StudioTheme.moss)
                                    .frame(width: 8, height: 8)
                                Text("Active")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(StudioTheme.moss)
                            }
                        }

                        // Active Pack Picker Card
                        Menu {
                            ForEach(appModel.allPacks) { pack in
                                Button {
                                    appModel.selectPack(id: pack.id)
                                } label: {
                                    if pack.id == appModel.selectedPackID {
                                        Label(pack.name, systemImage: "checkmark")
                                    } else {
                                        Text(pack.name)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: StudioTheme.Spacing.medium) {
                                Circle()
                                    .fill(StudioTheme.moss)
                                    .frame(width: 12, height: 12)
                                    .overlay(Circle().fill(Color.white).frame(width: 4, height: 4))
                                Text(appModel.activePack.name)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(StudioTheme.espresso)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(StudioTheme.secondaryText)
                            }
                            .padding(.horizontal, StudioTheme.Spacing.regular)
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .background(StudioTheme.canvas)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(StudioTheme.separator, lineWidth: 1)
                            }
                            .contentShape(Rectangle())
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .accessibilityLabel("Active Pack")
                        .accessibilityValue(appModel.activePack.name)
                        .accessibilityIdentifier("active-pack-picker")

                        Divider().overlay(StudioTheme.separator)

                        ActiveSoundRow(
                            title: "Press Sound",
                            icon: "arrow.down",
                            sound: appModel.findSound(byId: appModel.activePack.defaultDownSoundId)
                        )
                        Divider().overlay(StudioTheme.separator.opacity(0.7))
                        ActiveSoundRow(
                            title: "Release Sound",
                            icon: "arrow.up",
                            sound: appModel.findSound(byId: appModel.activePack.defaultUpSoundId)
                        )
                    }
                }

                // Master Volume Slider
                HStack(spacing: StudioTheme.Spacing.regular) {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(StudioTheme.walnut)
                    Text("Master Volume")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(StudioTheme.espresso)
                    Slider(value: $appModel.masterVolume, in: 0...1)
                        .tint(StudioTheme.walnut)
                        .accessibilityIdentifier("master-volume-slider")
                    Text("\(Int(appModel.masterVolume * 100))%")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(StudioTheme.secondaryText)
                        .frame(width: 42, alignment: .trailing)
                }
                .padding(.horizontal, StudioTheme.Spacing.xSmall)

                // Interactive Typing Test Pad
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(StudioTheme.surface.opacity(0.72))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(StudioTheme.separator, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        }

                    TextEditor(text: $typingTestText)
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(StudioTheme.espresso)
                        .scrollContentBackground(.hidden)
                        .padding(StudioTheme.Spacing.regular)
                        .background(Color.clear)
                        .accessibilityLabel("Typing test")
                        .accessibilityIdentifier("typing-test-field")
                        .onChange(of: typingTestText) { _ in
                            appModel.playKeyEvent(type: .down, force: true)
                        }

                    if typingTestText.isEmpty {
                        Text("Type here to test \(displayPackName)…")
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                            .foregroundStyle(StudioTheme.secondaryText)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(StudioTheme.Spacing.large)
                            .allowsHitTesting(false)

                        VStack(spacing: StudioTheme.Spacing.small) {
                            Image(systemName: "keyboard")
                                .font(.system(size: 25, weight: .regular))
                            Text("Press any key to begin")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(StudioTheme.secondaryText.opacity(0.8))
                        .allowsHitTesting(false)
                    }
                }
                .frame(minHeight: 140)

                // Available Sound Packs Grid
                VStack(alignment: .leading, spacing: StudioTheme.Spacing.medium) {
                    Text("ALL SOUND PACKS")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(StudioTheme.walnut)
                        .padding(.horizontal, StudioTheme.Spacing.xSmall)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: StudioTheme.Spacing.medium) {
                        ForEach(appModel.allPacks) { pack in
                            let isSelected = pack.id == appModel.selectedPackID
                            SoundPackSelectionCard(
                                pack: pack,
                                isSelected: isSelected,
                                onSelect: {
                                    appModel.selectPack(id: pack.id)
                                },
                                onPreview: {
                                    if let sound = appModel.findSound(byId: pack.defaultDownSoundId) {
                                        appModel.playPreview(soundId: sound.id)
                                    }
                                }
                            )
                        }
                    }
                }
            }
            .padding(StudioTheme.Spacing.xLarge)
        }
    }

    private var displayPackName: String {
        appModel.activePack.name.replacingOccurrences(of: " (Default)", with: "")
    }
}

private struct SoundPackSelectionCard: View {
    let pack: SoundPack
    let isSelected: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void

    private var descriptionText: String {
        switch pack.name {
        case "Thocky (Default)", "Thocky":
            return "Deep, satisfying acoustic mechanical thock"
        case "Creamy":
            return "Smooth, lubricated linear switch feel"
        case "Clicky":
            return "Crisp, tactile Cherry MX Blue click"
        case "Quiet":
            return "Muted, office-friendly dampened stroke"
        default:
            return pack.isBuiltIn ? "Built-in sound pack" : "Custom user-crafted sound pack"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(isSelected ? StudioTheme.moss : Color.clear)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(isSelected ? StudioTheme.moss : StudioTheme.separator, lineWidth: 2))
                    
                    Text(pack.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(StudioTheme.espresso)
                }

                Spacer()

                Button(action: onPreview) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(StudioTheme.espresso)
                        .frame(width: 28, height: 28)
                        .background(StudioTheme.surfaceMuted)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Preview \(pack.name)")
            }

            Text(descriptionText)
                .font(.system(size: 12))
                .foregroundStyle(StudioTheme.secondaryText)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                if isSelected {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Active")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(StudioTheme.moss)
                } else {
                    Button("Select Pack") {
                        onSelect()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                Spacer()
            }
        }
        .padding(StudioTheme.Spacing.regular)
        .background(isSelected ? StudioTheme.surface : StudioTheme.surface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? StudioTheme.moss : StudioTheme.separator.opacity(0.8), lineWidth: isSelected ? 2 : 1)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}

private struct ActiveSoundRow: View {
    @ObservedObject private var appModel = AppModel.shared
    let title: String
    let icon: String
    let sound: SoundItem?

    var body: some View {
        HStack(spacing: StudioTheme.Spacing.medium) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 38, height: 38)
                .background(StudioTheme.walnut)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(StudioTheme.espresso)
                Text(sound?.displayName ?? "Sound unavailable")
                    .font(.system(size: 12))
                    .foregroundStyle(StudioTheme.secondaryText)
            }
            Spacer()
            Button {
                if let sound { appModel.playPreview(soundId: sound.id) }
            } label: {
                Image(systemName: "play.fill")
                    .frame(width: 30, height: 30)
                    .background(StudioTheme.surfaceMuted)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(StudioTheme.espresso)
            .disabled(sound == nil)
            .accessibilityLabel("Preview \(title.lowercased())")
            .accessibilityIdentifier(title == "Press Sound" ? "preview-press-button" : "preview-release-button")
        }
    }
}

private struct KeyMappingsStudioView: View {
    @ObservedObject private var appModel = AppModel.shared
    private let keys: [(String, UInt16, String)] = [
        ("Space Bar", 49, "space"), ("Return / Enter", 36, "return"),
        ("Backspace / Delete", 51, "delete.left"), ("Escape", 53, "escape"), ("Tab", 48, "arrow.right.to.line")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: StudioTheme.Spacing.large) {
                StudioSectionHeader(
                    title: "Key Mappings",
                    subtitle: "Give special keys their own sound in \(appModel.activePack.name)."
                ) {
                    Button("Reset Mappings") { appModel.resetMappings() }
                        .buttonStyle(SecondaryButtonStyle())
                }

                StudioSurface {
                    VStack(spacing: 0) {
                        ForEach(Array(keys.enumerated()), id: \.element.1) { index, key in
                            HStack(spacing: StudioTheme.Spacing.medium) {
                                Image(systemName: key.2)
                                    .foregroundStyle(StudioTheme.walnut)
                                    .frame(width: 28)
                                Text(key.0)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(StudioTheme.espresso)
                                Spacer()
                                SoundPickerView(
                                    title: "",
                                    selectionSoundId: Binding(
                                        get: { appModel.activePack.keyMappings[key.1] ?? "None" },
                                        set: { appModel.setMapping(for: key.1, soundId: $0) }
                                    ),
                                    includeDefaultOption: true,
                                    defaultOptionTitle: "Default Sound"
                                )
                                .frame(width: 260)
                            }
                            .padding(.vertical, StudioTheme.Spacing.medium)
                            if index < keys.count - 1 { Divider().overlay(StudioTheme.separator) }
                        }
                    }
                }
            }
            .padding(StudioTheme.Spacing.xLarge)
        }
    }
}

private struct SettingsStudioView: View {
    @ObservedObject private var appModel = AppModel.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: StudioTheme.Spacing.large) {
                StudioSectionHeader(title: "Settings", subtitle: "Permissions, shortcuts, and privacy.")

                StudioSurface {
                    HStack(spacing: StudioTheme.Spacing.medium) {
                        Image(systemName: appModel.isAccessibilityEnabled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(appModel.isAccessibilityEnabled ? StudioTheme.moss : StudioTheme.caramel)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(appModel.isAccessibilityEnabled ? "Accessibility is active" : "Accessibility permission required")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(StudioTheme.espresso)
                            Text("ThocKey uses this permission only to detect key press notifications and play sound locally.")
                                .font(.system(size: 12))
                                .foregroundStyle(StudioTheme.secondaryText)
                        }
                        Spacer()
                        if !appModel.isAccessibilityEnabled {
                            Button("Open Settings") { openAccessibilitySettings() }
                                .buttonStyle(PrimaryButtonStyle())
                        }
                    }
                }

                StudioSurface {
                    VStack(spacing: StudioTheme.Spacing.regular) {
                        SettingsRow(icon: "command", title: "Mute or unmute", value: "⌘ ⇧ M")
                        Divider().overlay(StudioTheme.separator)
                        SettingsRow(icon: "lock.shield", title: "Privacy by design", value: "No keystroke text is saved")
                        Divider().overlay(StudioTheme.separator)
                        SettingsRow(icon: "internaldrive", title: "Sound storage", value: "Local Application Support")
                    }
                }
            }
            .padding(StudioTheme.Spacing.xLarge)
        }
    }

    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}

private struct SettingsRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: StudioTheme.Spacing.medium) {
            Image(systemName: icon).foregroundStyle(StudioTheme.walnut).frame(width: 24)
            Text(title).font(.system(size: 14, weight: .medium)).foregroundStyle(StudioTheme.espresso)
            Spacer()
            Text(value).font(.system(size: 12)).foregroundStyle(StudioTheme.secondaryText)
        }
    }
}
