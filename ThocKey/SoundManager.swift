import AVFoundation
import SwiftUI

public enum KeyEventType {
    case down
    case up
}

public class SoundManager: ObservableObject {
    public static let shared = SoundManager()
    
    // MARK: - Persisted Settings
    @AppStorage("isGlobalSoundEnabled") public var isGlobalSoundEnabled: Bool = true
    @AppStorage("masterVolume") public var masterVolume: Double = 0.8 {
        didSet {
            for player in players {
                player.volume = Float(masterVolume)
            }
        }
    }
    @AppStorage("selectedSoundPackName") public var selectedSoundPackName: String = "Thocky (Default)" {
        didSet {
            updateActivePack()
        }
    }
    
    // MARK: - State
    @Published public var activePack: SoundPack = BuiltInSoundData.builtInPacks[0]
    @Published public var customPacks: [SoundPack] = []
    @Published public var soundLibrary: [SoundItem] = []
    
    public var allPacks: [SoundPack] {
        return BuiltInSoundData.builtInPacks + customPacks
    }
    
    // MARK: - Audio Engine Internals
    private let engine = AVAudioEngine()
    private let eq = AVAudioUnitEQ(numberOfBands: 1)
    private let mixer = AVAudioMixerNode()
    
    // Node Pool for zero-latency overlapping playback
    private var players: [AVAudioPlayerNode] = []
    private let maxNodes = 12
    private var currentPlayerIndex = 0
    
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    
    private init() {
        setupAudio()
        loadSoundLibrary()
        loadCustomPacks()
        preloadAllBuffers()
        updateActivePack()
    }
    
    // MARK: - Directory URLs
    
    public func getAppSupportURL() -> URL? {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        guard let appSupport = paths.first else { return nil }
        let appDir = appSupport.appendingPathComponent("ThocKey", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: appDir.path) {
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        return appDir
    }
    
    public func getSoundsDirectory() -> URL? {
        guard let appDir = getAppSupportURL() else { return nil }
        let soundsDir = appDir.appendingPathComponent("Sounds", isDirectory: true)
        if !FileManager.default.fileExists(atPath: soundsDir.path) {
            try? FileManager.default.createDirectory(at: soundsDir, withIntermediateDirectories: true)
        }
        return soundsDir
    }
    
    private func getSoundsMetadataURL() -> URL? {
        return getAppSupportURL()?.appendingPathComponent("soundsMetadata.json")
    }
    
    private func getPacksURL() -> URL? {
        return getAppSupportURL()?.appendingPathComponent("customPacks.json")
    }
    
    // MARK: - Sound Library & Metadata Management
    
    public func loadSoundLibrary() {
        var library = BuiltInSoundData.builtInSounds
        
        if let url = getSoundsMetadataURL(),
           let data = try? Data(contentsOf: url),
           let customSounds = try? JSONDecoder().decode([SoundItem].self, from: data) {
            // Filter out any custom sounds whose files are missing
            if let soundsDir = getSoundsDirectory() {
                let validCustom = customSounds.filter { item in
                    let filePath = soundsDir.appendingPathComponent(item.fileName).path
                    return FileManager.default.fileExists(atPath: filePath)
                }
                library.append(contentsOf: validCustom)
            }
        }
        
        // Also check if any loose sound files in soundsDir are unindexed
        if let soundsDir = getSoundsDirectory(),
           let files = try? FileManager.default.contentsOfDirectory(at: soundsDir, includingPropertiesForKeys: nil) {
            for file in files {
                let fileName = file.lastPathComponent
                let nameWithoutExt = (fileName as NSString).deletingPathExtension
                let ext = file.pathExtension.lowercased()
                if ["wav", "mp3", "aiff", "m4a"].contains(ext) {
                    if !library.contains(where: { $0.fileName == fileName || $0.fileName == nameWithoutExt }) {
                        let duration = AudioProcessingService.shared.getAudioDuration(from: file)
                        let newSound = SoundItem(
                            id: UUID().uuidString,
                            displayName: formatDisplayName(from: nameWithoutExt),
                            fileName: fileName,
                            packName: "Custom",
                            category: .custom,
                            duration: duration,
                            isBuiltIn: false
                        )
                        library.append(newSound)
                    }
                }
            }
        }
        
        self.soundLibrary = library
        saveSoundLibraryMetadata()
    }
    
    public func saveSoundLibraryMetadata() {
        let customSounds = soundLibrary.filter { !$0.isBuiltIn }
        if let url = getSoundsMetadataURL(),
           let data = try? JSONEncoder().encode(customSounds) {
            try? data.write(to: url)
        }
    }
    
    public func groupedSoundsByPack() -> [(packName: String, sounds: [SoundItem])] {
        let grouped = Dictionary(grouping: soundLibrary, by: { $0.packName })
        
        // Ordered packs: Built-in packs first, then custom
        var result: [(packName: String, sounds: [SoundItem])] = []
        let packOrder = ["Thocky", "Creamy", "Clicky", "Quiet", "Custom", "Customized"]
        
        for pack in packOrder {
            if let sounds = grouped[pack], !sounds.isEmpty {
                result.append((packName: pack, sounds: sounds.sorted(by: { $0.displayName < $1.displayName })))
            }
        }
        
        for (pack, sounds) in grouped where !packOrder.contains(pack) {
            result.append((packName: pack, sounds: sounds.sorted(by: { $0.displayName < $1.displayName })))
        }
        
        return result
    }
    
    public func findSound(byId id: String) -> SoundItem? {
        if let found = soundLibrary.first(where: { $0.id == id }) {
            return found
        }
        // Fallback matching for legacy name references
        return soundLibrary.first(where: { $0.fileName == id || $0.displayName == id })
    }
    
    public func findSoundURL(for sound: SoundItem) -> URL? {
        if sound.isBuiltIn {
            let baseName = (sound.fileName as NSString).deletingPathExtension
            if let url = Bundle.main.url(forResource: baseName, withExtension: "wav") { return url }
            if let url = Bundle.main.url(forResource: baseName, withExtension: "mp3") { return url }
        }
        
        if let soundsDir = getSoundsDirectory() {
            let fullPath = soundsDir.appendingPathComponent(sound.fileName)
            if FileManager.default.fileExists(atPath: fullPath.path) { return fullPath }
            
            let withWav = soundsDir.appendingPathComponent("\(sound.fileName).wav")
            if FileManager.default.fileExists(atPath: withWav.path) { return withWav }
            
            let withMp3 = soundsDir.appendingPathComponent("\(sound.fileName).mp3")
            if FileManager.default.fileExists(atPath: withMp3.path) { return withMp3 }
        }
        
        return nil
    }
    
    // MARK: - Sound CRUD Operations
    
    public func renameSound(id: String, newDisplayName: String) {
        let trimmed = newDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        if let idx = soundLibrary.firstIndex(where: { $0.id == id }) {
            guard !soundLibrary[idx].isBuiltIn else { return } // cannot rename built-ins
            soundLibrary[idx].displayName = trimmed
            saveSoundLibraryMetadata()
        }
    }
    
    public func deleteSound(id: String) -> Bool {
        guard let idx = soundLibrary.firstIndex(where: { $0.id == id }), !soundLibrary[idx].isBuiltIn else {
            return false
        }
        let sound = soundLibrary[idx]
        soundLibrary.remove(at: idx)
        
        // Remove file from disk
        if let soundsDir = getSoundsDirectory() {
            let fileURL = soundsDir.appendingPathComponent(sound.fileName)
            try? FileManager.default.removeItem(at: fileURL)
        }
        
        // Remove from buffers
        buffers.removeValue(forKey: sound.id)
        buffers.removeValue(forKey: sound.fileName)
        
        saveSoundLibraryMetadata()
        return true
    }
    
    public func importSound(from sourceURL: URL, displayName: String? = nil) -> SoundItem? {
        guard let soundsDir = getSoundsDirectory() else { return nil }
        
        let rawFileName = sourceURL.lastPathComponent
        let nameWithoutExt = (rawFileName as NSString).deletingPathExtension
        let ext = sourceURL.pathExtension.isEmpty ? "wav" : sourceURL.pathExtension
        let uniqueFileName = "\(nameWithoutExt)_\(UUID().uuidString.prefix(6)).\(ext)"
        let destinationURL = soundsDir.appendingPathComponent(uniqueFileName)
        
        do {
            let accessed = sourceURL.startAccessingSecurityScopedResource()
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            if accessed {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        } catch {
            print("Failed to copy imported sound: \(error)")
            return nil
        }
        
        let duration = AudioProcessingService.shared.getAudioDuration(from: destinationURL)
        let officialName = displayName ?? formatDisplayName(from: nameWithoutExt)
        
        let newItem = SoundItem(
            id: UUID().uuidString,
            displayName: officialName,
            fileName: uniqueFileName,
            packName: "Custom",
            category: .custom,
            duration: duration,
            isBuiltIn: false
        )
        
        soundLibrary.append(newItem)
        saveSoundLibraryMetadata()
        preloadBuffer(for: newItem)
        return newItem
    }
    
    public func saveTrimmedSound(
        sourceSoundId: String,
        newDisplayName: String,
        packName: String = "Customized",
        startTime: Double,
        endTime: Double,
        gain: Float = 1.0,
        applyFade: Bool = true
    ) async throws -> SoundItem {
        guard let sourceSound = findSound(byId: sourceSoundId),
              let sourceURL = findSoundURL(for: sourceSound),
              let soundsDir = getSoundsDirectory() else {
            throw NSError(domain: "SoundManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Source sound not found"])
        }
        
        let safeName = newDisplayName.replacingOccurrences(of: " ", with: "_").lowercased()
        let uniqueFileName = "\(safeName)_\(UUID().uuidString.prefix(6)).wav"
        let outputURL = soundsDir.appendingPathComponent(uniqueFileName)
        
        try AudioProcessingService.shared.trimAndExportAudio(
            sourceURL: sourceURL,
            startTime: startTime,
            endTime: endTime,
            gain: gain,
            applyMicroFade: applyFade,
            outputURL: outputURL
        )
        
        let duration = AudioProcessingService.shared.getAudioDuration(from: outputURL)
        let newItem = SoundItem(
            id: UUID().uuidString,
            displayName: newDisplayName.trimmingCharacters(in: .whitespacesAndNewlines),
            fileName: uniqueFileName,
            packName: packName,
            category: .trimmed,
            duration: duration,
            isBuiltIn: false
        )
        
        await MainActor.run {
            self.soundLibrary.append(newItem)
            self.saveSoundLibraryMetadata()
            self.preloadBuffer(for: newItem)
        }
        
        return newItem
    }
    
    public func splitKeystrokeSound(
        sourceSoundId: String,
        downName: String,
        upName: String,
        downStart: Double,
        downEnd: Double,
        upStart: Double,
        upEnd: Double,
        gain: Float = 1.0,
        applyFade: Bool = true
    ) async throws -> (down: SoundItem, up: SoundItem) {
        let downItem = try await saveTrimmedSound(
            sourceSoundId: sourceSoundId,
            newDisplayName: downName,
            packName: "Customized",
            startTime: downStart,
            endTime: downEnd,
            gain: gain,
            applyFade: applyFade
        )
        
        let upItem = try await saveTrimmedSound(
            sourceSoundId: sourceSoundId,
            newDisplayName: upName,
            packName: "Customized",
            startTime: upStart,
            endTime: upEnd,
            gain: gain,
            applyFade: applyFade
        )
        
        return (down: downItem, up: upItem)
    }
    
    // MARK: - Custom Packs Logic
    
    public func loadCustomPacks() {
        guard let url = getPacksURL(),
              let data = try? Data(contentsOf: url),
              let packs = try? JSONDecoder().decode([SoundPack].self, from: data) else {
            return
        }
        self.customPacks = packs
    }
    
    public func saveCustomPack(_ pack: SoundPack) {
        if let index = customPacks.firstIndex(where: { $0.name == pack.name }) {
            customPacks[index] = pack
        } else {
            customPacks.append(pack)
        }
        
        if let url = getPacksURL(), let data = try? JSONEncoder().encode(customPacks) {
            try? data.write(to: url)
        }
        
        if selectedSoundPackName == pack.name {
            updateActivePack()
        }
    }
    
    @discardableResult
    public func setActiveSound(sound: SoundItem) -> String {
        // If it's a built-in pack sound, switch directly to the matching built-in pack
        if sound.isBuiltIn {
            if let matchingPack = BuiltInSoundData.builtInPacks.first(where: { $0.defaultDownSoundId == sound.id || $0.name.localizedCaseInsensitiveContains(sound.packName) }) {
                self.selectedSoundPackName = matchingPack.name
                return matchingPack.name
            }
        }
        
        // Check if a custom pack already uses this sound as default
        let targetPackName = "\(sound.displayName) Pack"
        if let existing = customPacks.first(where: { $0.name == targetPackName }) {
            self.selectedSoundPackName = existing.name
            return existing.name
        }
        
        // Otherwise create a custom pack for this sound and activate it immediately
        let newPack = SoundPack(
            name: targetPackName,
            defaultDownSoundId: sound.id,
            defaultUpSoundId: sound.id,
            keyMappings: [:],
            isBuiltIn: false
        )
        saveCustomPack(newPack)
        self.selectedSoundPackName = newPack.name
        return newPack.name
    }
    
    public func deleteCustomPack(named name: String) {
        customPacks.removeAll(where: { $0.name == name })
        if let url = getPacksURL(), let data = try? JSONEncoder().encode(customPacks) {
            try? data.write(to: url)
        }
        if selectedSoundPackName == name {
            selectedSoundPackName = BuiltInSoundData.builtInPacks[0].name
        }
    }
    
    public func updateActivePack() {
        if let basePack = allPacks.first(where: { $0.name == selectedSoundPackName }) {
            var pack = basePack
            // Load custom overrides from UserDefaults
            if let data = UserDefaults.standard.data(forKey: "customMappings_\(pack.name)"),
               let savedMappings = try? JSONDecoder().decode([UInt16: String].self, from: data) {
                pack.keyMappings = savedMappings
            }
            activePack = pack
        }
    }
    
    public func setMapping(for keyCode: UInt16, soundId: String?) {
        if let soundId = soundId, soundId != "None" {
            activePack.keyMappings[keyCode] = soundId
        } else {
            activePack.keyMappings.removeValue(forKey: keyCode)
        }
        
        // Save to UserDefaults
        if let data = try? JSONEncoder().encode(activePack.keyMappings) {
            UserDefaults.standard.set(data, forKey: "customMappings_\(activePack.name)")
        }
    }
    
    // MARK: - Audio Engine Setup & Playback
    
    private func setupAudio() {
        let band = eq.bands[0]
        band.filterType = .lowPass
        band.frequency = 1800
        band.bandwidth = 0.5
        band.gain = 24
        band.bypass = true
        
        engine.attach(mixer)
        engine.attach(eq)
        
        engine.connect(mixer, to: eq, format: nil)
        engine.connect(eq, to: engine.mainMixerNode, format: nil)
        
        for _ in 0..<maxNodes {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: mixer, format: nil)
            player.volume = Float(masterVolume)
            players.append(player)
        }
        
        try? engine.start()
    }
    
    private func preloadAllBuffers() {
        for sound in soundLibrary {
            preloadBuffer(for: sound)
        }
    }
    
    public func preloadBuffer(for sound: SoundItem) {
        guard let url = findSoundURL(for: sound) else { return }
        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let frameCount = AVAudioFrameCount(file.length)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
            try file.read(into: buffer)
            
            buffers[sound.id] = buffer
            buffers[sound.fileName] = buffer
        } catch {
            print("Failed to preload sound \(sound.displayName): \(error)")
        }
    }
    
    public func playPreview(soundId: String) {
        guard let sound = findSound(byId: soundId) else { return }
        playBuffer(soundId: sound.id, fileName: sound.fileName)
    }
    
    public func playKeyEvent(type: KeyEventType, keyCode: UInt16? = nil, force: Bool = false) {
        if !isGlobalSoundEnabled && !force { return }
        
        var targetSoundId = type == .down ? activePack.defaultDownSoundId : activePack.defaultUpSoundId
        
        // Key override for key down
        if let keyCode = keyCode, type == .down {
            if let customSoundId = activePack.keyMappings[keyCode] {
                targetSoundId = customSoundId
            }
        }
        
        let sound = findSound(byId: targetSoundId)
        playBuffer(soundId: targetSoundId, fileName: sound?.fileName ?? targetSoundId)
    }
    
    private func playBuffer(soundId: String, fileName: String) {
        var buffer = buffers[soundId] ?? buffers[fileName]
        
        if buffer == nil {
            if let sound = findSound(byId: soundId) {
                preloadBuffer(for: sound)
                buffer = buffers[sound.id]
            }
        }
        
        guard let pcmBuffer = buffer else {
            print("Audio buffer not ready for: \(soundId)")
            return
        }
        
        let player = players[currentPlayerIndex]
        if player.isPlaying {
            player.stop()
        }
        player.scheduleBuffer(pcmBuffer, at: nil, options: .interrupts)
        player.play()
        
        currentPlayerIndex = (currentPlayerIndex + 1) % maxNodes
    }
    
    // MARK: - Helpers
    
    private func formatDisplayName(from filename: String) -> String {
        return filename
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }
}
