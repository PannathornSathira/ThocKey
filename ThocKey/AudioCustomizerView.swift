import SwiftUI
import AVFoundation

public struct AudioCustomizerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var soundManager = SoundManager.shared
    
    public let initialSound: SoundItem?
    public let initialFileURL: URL?
    
    // Waveform & Timing State (Normalized 0.0 ... 1.0)
    @State private var waveformSamples: [Float] = Array(repeating: 0.15, count: 80)
    @State private var totalDuration: Double = 0.3
    @State private var startRatio: Double = 0.0
    @State private var endRatio: Double = 1.0
    
    // Split Mode
    @State private var isSplitMode: Bool = false
    @State private var splitRatio: Double = 0.5
    @State private var downSoundName: String = ""
    @State private var upSoundName: String = ""
    
    // Audio Tweaks
    @State private var customDisplayName: String = ""
    @State private var gain: Float = 1.0
    @State private var applyFade: Bool = true
    @State private var shouldAutoActivate: Bool = true
    
    // Live Test Area
    @State private var testTypingText: String = ""
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String? = nil
    
    // Temporary test audio engine player
    @State private var tempPlayer: AVAudioPlayer?
    
    public init(sound: SoundItem? = nil, fileURL: URL? = nil) {
        self.initialSound = sound
        self.initialFileURL = fileURL
    }
    
    private var activeSoundURL: URL? {
        if let fileURL = initialFileURL {
            return fileURL
        }
        if let sound = initialSound {
            return soundManager.findSoundURL(for: sound)
        }
        return nil
    }
    
    private var trimStartSeconds: Double {
        return startRatio * totalDuration
    }
    
    private var trimEndSeconds: Double {
        return max(trimStartSeconds + 0.005, endRatio * totalDuration)
    }
    
    private var splitPointSeconds: Double {
        return max(trimStartSeconds + 0.002, min(trimEndSeconds - 0.002, splitRatio * totalDuration))
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // Header Details
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(initialSound?.displayName ?? (initialFileURL?.lastPathComponent ?? "Audio Customizer"))
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            if let cat = initialSound?.category {
                                Text(cat.rawValue)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(StudioTheme.walnut.opacity(0.15))
                                    .foregroundStyle(StudioTheme.walnut)
                                    .cornerRadius(12)
                            }
                        }
                        
                        Text("Trim, adjust gain, and eliminate silent gaps to craft the perfect keystroke sound.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Waveform Display Card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Audio Waveform")
                                .font(.headline)
                            Spacer()
                            Text(String(format: "Total: %.0f ms | Selection: %.0f ms", totalDuration * 1000, max(0, trimEndSeconds - trimStartSeconds) * 1000))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Waveform Visualizer
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(StudioTheme.surfaceMuted)
                                .frame(height: 100)
                            
                            // Waveform bars
                            HStack(alignment: .center, spacing: 3) {
                                ForEach(0..<waveformSamples.count, id: \.self) { idx in
                                    let sample = waveformSamples[idx]
                                    let progress = Double(idx) / Double(max(1, waveformSamples.count))
                                    let isSelected = progress >= startRatio && progress <= endRatio
                                    
                                    RoundedRectangle(cornerRadius: 2)
                                    .fill(isSelected ? StudioTheme.walnut : StudioTheme.secondaryText.opacity(0.3))
                                        .frame(height: CGFloat(max(6, sample * 80)))
                                }
                            }
                            .padding(.horizontal, 12)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                        
                        // Safe Sliders for Start & End
                        VStack(spacing: 8) {
                            HStack {
                                Text("Start:")
                                    .font(.caption)
                                    .frame(width: 45, alignment: .leading)
                                
                                Button("-5ms") { adjustStart(by: -0.005) }
                                    .buttonStyle(.plain)
                                    .font(.caption2)
                                    .padding(.horizontal, 4)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(4)
                                
                                Slider(value: $startRatio, in: 0.0...0.95)
                                    .onChange(of: startRatio) { _, newStart in
                                        if newStart >= endRatio {
                                            endRatio = min(1.0, newStart + 0.05)
                                        }
                                    }
                                
                                Button("+5ms") { adjustStart(by: 0.005) }
                                    .buttonStyle(.plain)
                                    .font(.caption2)
                                    .padding(.horizontal, 4)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(4)
                                
                                Text(String(format: "%.0f ms", trimStartSeconds * 1000))
                                    .font(.caption)
                                    .frame(width: 55, alignment: .trailing)
                            }
                            
                            HStack {
                                Text("End:")
                                    .font(.caption)
                                    .frame(width: 45, alignment: .leading)
                                
                                Button("-5ms") { adjustEnd(by: -0.005) }
                                    .buttonStyle(.plain)
                                    .font(.caption2)
                                    .padding(.horizontal, 4)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(4)
                                
                                Slider(value: $endRatio, in: 0.05...1.0)
                                    .onChange(of: endRatio) { _, newEnd in
                                        if newEnd <= startRatio {
                                            startRatio = max(0.0, newEnd - 0.05)
                                        }
                                    }
                                
                                Button("+5ms") { adjustEnd(by: 0.005) }
                                    .buttonStyle(.plain)
                                    .font(.caption2)
                                    .padding(.horizontal, 4)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(4)
                                
                                Text(String(format: "%.0f ms", trimEndSeconds * 1000))
                                    .font(.caption)
                                    .frame(width: 55, alignment: .trailing)
                            }
                        }
                    }
                    .padding()
                    .background(StudioTheme.surface)
                    .cornerRadius(10)
                    
                    // Split Mode Toggle
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Keystroke Splitter (Split Down / Up)", isOn: $isSplitMode)
                            .font(.headline)
                        
                        if isSplitMode {
                            Text("Split this recording into two separate sounds: Key Down (press) and Key Up (release).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text("Split:")
                                    .font(.caption)
                                    .frame(width: 45, alignment: .leading)
                                Slider(value: $splitRatio, in: 0.0...1.0)
                                Text(String(format: "%.0f ms", splitPointSeconds * 1000))
                                    .font(.caption)
                                    .frame(width: 55, alignment: .trailing)
                            }
                            
                            HStack(spacing: 12) {
                                TextField("Key Down Name", text: $downSoundName)
                                    .textFieldStyle(.roundedBorder)
                                TextField("Key Up Name", text: $upSoundName)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                    }
                    .padding()
                    .background(StudioTheme.surface)
                    .cornerRadius(10)
                    
                    // Audio Tweaks
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Audio Tweaks")
                            .font(.headline)
                        
                        HStack {
                            Text("Gain / Volume Boost:")
                                .font(.subheadline)
                            Slider(value: $gain, in: 0.5...2.5)
                            Text(String(format: "%.1fx", gain))
                                .font(.caption)
                                .frame(width: 40, alignment: .trailing)
                        }
                        
                        Toggle("Apply Anti-Click Micro-Fade (5ms fade-in / fade-out)", isOn: $applyFade)
                            .font(.subheadline)
                        
                        Toggle("Set as Active Sound Pack immediately upon saving", isOn: $shouldAutoActivate)
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                    }
                    .padding()
                    .background(StudioTheme.surface)
                    .cornerRadius(10)
                    
                    // Live Keystroke Test Area & Preview
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Test Before Saving")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            Button(action: previewTrimmedAudio) {
                                Label("Play Region", systemImage: "play.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Spacer()
                        }
                        
                        TextField("Type here to test trimmed sound with keyboard rhythm...", text: $testTypingText)
                            .textFieldStyle(.roundedBorder)
                            .padding(.top, 2)
                            .onChange(of: testTypingText) {
                                previewTrimmedAudio()
                            }
                    }
                    .padding()
                    .background(StudioTheme.surface)
                    .cornerRadius(10)
                    
                    // Output Sound Name
                    if !isSplitMode {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Official Sound Display Name")
                                .font(.headline)
                            
                            TextField("e.g. My Custom Thock", text: $customDisplayName)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding()
                        .background(StudioTheme.surface)
                        .cornerRadius(10)
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding()
            }
            .navigationTitle("Audio Customizer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save to Library") {
                        saveSound()
                    }
                    .disabled(isSaveDisabled)
                }
            }
        }
        .frame(minWidth: 620, minHeight: 560)
        .background(StudioTheme.canvas)
        .onAppear {
            setupInitialState()
        }
    }
    
    private var isSaveDisabled: Bool {
        if isProcessing { return true }
        if isSplitMode {
            return downSoundName.trimmingCharacters(in: .whitespaces).isEmpty ||
                   upSoundName.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return customDisplayName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private func adjustStart(by seconds: Double) {
        guard totalDuration > 0 else { return }
        let deltaRatio = seconds / totalDuration
        startRatio = max(0.0, min(endRatio - 0.02, startRatio + deltaRatio))
    }
    
    private func adjustEnd(by seconds: Double) {
        guard totalDuration > 0 else { return }
        let deltaRatio = seconds / totalDuration
        endRatio = max(startRatio + 0.02, min(1.0, endRatio + deltaRatio))
    }
    
    private func setupInitialState() {
        let baseName = initialSound?.displayName ?? (initialFileURL?.deletingPathExtension().lastPathComponent ?? "Custom Sound")
        customDisplayName = "\(baseName) (Custom)"
        downSoundName = "\(baseName) (Down)"
        upSoundName = "\(baseName) (Up)"
        
        guard let url = activeSoundURL else { return }
        totalDuration = max(0.05, AudioProcessingService.shared.getAudioDuration(from: url))
        
        startRatio = 0.0
        endRatio = 1.0
        splitRatio = 0.5
        
        Task {
            let samples = await AudioProcessingService.shared.extractWaveform(from: url, sampleCount: 80)
            await MainActor.run {
                self.waveformSamples = samples
            }
        }
    }
    
    private func previewTrimmedAudio() {
        guard let url = activeSoundURL else { return }
        
        let startSec = trimStartSeconds
        let endSec = isSplitMode ? splitPointSeconds : trimEndSeconds
        
        // Export to a temporary test file and play immediately
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_trim.wav")
        do {
            try AudioProcessingService.shared.trimAndExportAudio(
                sourceURL: url,
                startTime: startSec,
                endTime: endSec,
                gain: gain,
                applyMicroFade: applyFade,
                outputURL: tempURL
            )
            tempPlayer = try AVAudioPlayer(contentsOf: tempURL)
            tempPlayer?.volume = Float(soundManager.masterVolume)
            tempPlayer?.play()
        } catch {
            print("Preview failed: \(error)")
        }
    }
    
    private func saveSound() {
        let soundId: String
        if let existingID = initialSound?.id {
            soundId = existingID
        } else if let fileURL = initialFileURL {
            do { soundId = try soundManager.importSound(from: fileURL).id }
            catch { errorMessage = error.localizedDescription; return }
        } else {
            errorMessage = "Could not resolve sound source"
            return
        }
        
        isProcessing = true
        errorMessage = nil
        
        let startSec = trimStartSeconds
        let endSec = trimEndSeconds
        let splitSec = splitPointSeconds
        
        Task {
            do {
                var savedSound: SoundItem?
                if isSplitMode {
                    let result = try await soundManager.splitKeystrokeSound(
                        sourceSoundId: soundId,
                        downName: downSoundName,
                        upName: upSoundName,
                        downStart: startSec,
                        downEnd: splitSec,
                        upStart: splitSec,
                        upEnd: endSec,
                        gain: gain,
                        applyFade: applyFade
                    )
                    savedSound = result.down
                } else {
                    savedSound = try await soundManager.saveTrimmedSound(
                        sourceSoundId: soundId,
                        newDisplayName: customDisplayName,
                        packName: "Customized",
                        startTime: startSec,
                        endTime: endSec,
                        gain: gain,
                        applyFade: applyFade
                    )
                }
                
                await MainActor.run {
                    if let sound = savedSound, shouldAutoActivate {
                        do { try soundManager.setActiveSound(sound: sound) }
                        catch { soundManager.present(error) }
                    }
                    isProcessing = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to save trimmed sound: \(error.localizedDescription)"
                    self.isProcessing = false
                }
            }
        }
    }
}
