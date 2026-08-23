import SwiftUI

public struct ContentView: View {
    @ObservedObject private var soundManager = SoundManager.shared
    
    @State private var selectedTab: StudioTab = .packs
    @State private var typingTestText: String = ""
    @State private var isAccessibilityEnabled: Bool = false
    @State private var isShowingPackEditor: Bool = false
    
    public enum StudioTab: String, CaseIterable, Identifiable {
        case packs = "Sounds & Packs"
        case keyMapping = "Key Mappings"
        case library = "Sound Library"
        case settings = "Settings"
        
        public var id: String { rawValue }
        
        public var icon: String {
            switch self {
            case .packs: return "square.grid.2x2.fill"
            case .keyMapping: return "keyboard.fill"
            case .library: return "waveform.badge.magnifyingglass"
            case .settings: return "gearshape.fill"
            }
        }
    }
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Studio Header & Tab Bar
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    // App Logo Icon
                    Image("AppLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 44, height: 44)
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text("ThocKey Studio")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("v1.0 MVP")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15))
                                .cornerRadius(6)
                        }
                        
                        Text("Satisfying mechanical keyboard audio with custom sound tuning.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Master Enable Quick Toggle
                    Toggle(isOn: $soundManager.isGlobalSoundEnabled) {
                        Text(soundManager.isGlobalSoundEnabled ? "Sound Active" : "Muted")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .toggleStyle(.switch)
                }
                
                // Segmented Tab Selector
                Picker("Section", selection: $selectedTab) {
                    ForEach(StudioTab.allCases) { tab in
                        Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Tab Content
            switch selectedTab {
            case .packs:
                packsTab
            case .keyMapping:
                keyMappingTab
            case .library:
                SoundLibraryView()
            case .settings:
                settingsTab
            }
        }
        .frame(minWidth: 620, minHeight: 520)
        .onAppear {
            checkAccessibility()
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                checkAccessibility()
            }
        }
        .sheet(isPresented: $isShowingPackEditor) {
            PackEditorView()
        }
    }
    
    // MARK: - Packs Tab
    private var packsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // Pack Selector Box
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Active Sound Pack")
                            .font(.headline)
                        Spacer()
                        Button(action: { isShowingPackEditor = true }) {
                            Label("New Pack", systemImage: "plus")
                        }
                    }
                    
                    Picker("Active Pack", selection: $soundManager.selectedSoundPackName) {
                        ForEach(soundManager.allPacks) { pack in
                            Text(pack.name).tag(pack.name)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    
                    // Pack details
                    HStack(spacing: 16) {
                        let downSound = soundManager.findSound(byId: soundManager.activePack.defaultDownSoundId)
                        let upSound = soundManager.findSound(byId: soundManager.activePack.defaultUpSoundId)
                        
                        Label("Down: \(downSound?.displayName ?? "Default")", systemImage: "arrow.down.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Label("Up: \(upSound?.displayName ?? "Default")", systemImage: "arrow.up.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor))
                .cornerRadius(10)
                
                // Volume & Quick Controls
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sound Controls")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Master Volume")
                                .font(.subheadline)
                            Spacer()
                            Text("\(Int(soundManager.masterVolume * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
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
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor))
                .cornerRadius(10)
                
                // Interactive Typing Test Area
                VStack(alignment: .leading, spacing: 10) {
                    Text("Interactive Typing Test Area")
                        .font(.headline)
                    
                    Text("Test your active sound pack directly in the box below:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("Start typing here to test your mechanical keyboard sounds...", text: $typingTestText)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                        .padding(.vertical, 4)
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor))
                .cornerRadius(10)
            }
            .padding()
        }
    }
    
    // MARK: - Key Mapping Tab
    private var keyMappingTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Custom Key Sounds for: \(soundManager.activePack.name)")
                        .font(.headline)
                    Text("Assign specific sounds from any sound pack to individual keys. Sounds display official names and are grouped by pack.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 8) {
                    KeyMappingItemRow(title: "Space Bar", keyCode: 49)
                    KeyMappingItemRow(title: "Return / Enter", keyCode: 36)
                    KeyMappingItemRow(title: "Backspace / Delete", keyCode: 51)
                    KeyMappingItemRow(title: "Escape", keyCode: 53)
                    KeyMappingItemRow(title: "Tab", keyCode: 48)
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor))
                .cornerRadius(10)
                
                HStack {
                    Spacer()
                    Button("Reset Key Mappings to Default") {
                        soundManager.activePack.keyMappings.removeAll()
                        if let data = try? JSONEncoder().encode(soundManager.activePack.keyMappings) {
                            UserDefaults.standard.set(data, forKey: "customMappings_\(soundManager.activePack.name)")
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Settings Tab
    private var settingsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Permissions Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("macOS Accessibility Permissions")
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: isAccessibilityEnabled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(isAccessibilityEnabled ? .green : .yellow)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isAccessibilityEnabled ? "Accessibility Permission Active" : "Accessibility Permission Required")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Required for detecting global keystrokes across all applications.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if !isAccessibilityEnabled {
                            Button("Open Settings") {
                                openSystemSettings()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor))
                .cornerRadius(10)
                
                // Shortcut Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Global Shortcuts")
                        .font(.headline)
                    
                    HStack {
                        Text("Global Sound Mute / Unmute")
                            .font(.subheadline)
                        Spacer()
                        Text("⌘ + ⇧ + M")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(6)
                    }
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor))
                .cornerRadius(10)
                
                // Privacy Guarantee Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Privacy by Design")
                        .font(.headline)
                    
                    Text("ThocKey processes key event notifications locally in real time solely to trigger sound playback. ThocKey never logs, saves, transmits, or collects what you type.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor))
                .cornerRadius(10)
            }
            .padding()
        }
    }
    
    private func checkAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        isAccessibilityEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    private func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

private struct KeyMappingItemRow: View {
    let title: String
    let keyCode: UInt16
    @ObservedObject private var soundManager = SoundManager.shared
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
            Spacer()
            SoundPickerView(
                title: "",
                selectionSoundId: Binding(
                    get: { soundManager.activePack.keyMappings[keyCode] ?? "None" },
                    set: { soundManager.setMapping(for: keyCode, soundId: $0) }
                ),
                includeDefaultOption: true,
                defaultOptionTitle: "Default Sound"
            )
        }
        .padding(.vertical, 4)
    }
}
