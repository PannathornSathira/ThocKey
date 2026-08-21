import AVFoundation
import SwiftUI

enum KeyEventType {
    case down
    case up
}

struct SoundPack: Codable, Identifiable, Hashable {
    var id: String { name }
    var name: String
    var defaultDown: String
    var defaultUp: String
    var keyMappings: [UInt16: String]
}

class SoundManager: ObservableObject {
    static let shared = SoundManager()
    
    // Persisted settings
    @AppStorage("isGlobalSoundEnabled") var isGlobalSoundEnabled: Bool = true
    @AppStorage("masterVolume") var masterVolume: Double = 0.8 {
        didSet {
            for player in players {
                player.volume = Float(masterVolume)
            }
        }
    }
    @AppStorage("selectedSoundPackName") var selectedSoundPackName: String = "Thocky (Default)" {
        didSet {
            updateActivePack()
        }
    }
    
    @Published var activePack: SoundPack = SoundPack(name: "Default", defaultDown: "", defaultUp: "", keyMappings: [:])
    @Published var customPacks: [SoundPack] = []
    
    // Hardcoded built-in packs
    let builtInPacks: [SoundPack] = [
        SoundPack(name: "Thocky (Default)", defaultDown: "thock_down", defaultUp: "thock_up", keyMappings: [:]),
        SoundPack(name: "Creamy", defaultDown: "creamy_key", defaultUp: "creamy_key", keyMappings: [:]),
        SoundPack(name: "Clicky", defaultDown: "clicky_key", defaultUp: "clicky_key", keyMappings: [:]),
        SoundPack(name: "Quiet", defaultDown: "quiet_key", defaultUp: "quiet_key", keyMappings: [:])
    ]
    
    var allPacks: [SoundPack] {
        return builtInPacks + customPacks
    }
    
    // All available sounds for the picker (built-in + any in App Support)
    @Published var availableSounds = ["thock_down", "thock_up", "creamy_key", "clicky_key", "quiet_key"]
    
    private let engine = AVAudioEngine()
    private let eq = AVAudioUnitEQ(numberOfBands: 1)
    private let mixer = AVAudioMixerNode()
    
    // Node Pool for overlapping sounds
    private var players: [AVAudioPlayerNode] = []
    private let maxNodes = 8
    private var currentPlayerIndex = 0
    
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    
    init() {
        setupAudio()
        loadCustomPacks()
        refreshAvailableSounds()
        updateActivePack()
    }
    
    // MARK: - Custom Packs Logic
    
    private func getAppSupportURL() -> URL? {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        guard let appSupport = paths.first else { return nil }
        let appDir = appSupport.appendingPathComponent("ThocKey", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: appDir.path) {
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        return appDir
    }
    
    private func getPacksURL() -> URL? {
        return getAppSupportURL()?.appendingPathComponent("customPacks.json")
    }
    
    func getSoundsDirectory() -> URL? {
        guard let appDir = getAppSupportURL() else { return nil }
        let soundsDir = appDir.appendingPathComponent("Sounds", isDirectory: true)
        if !FileManager.default.fileExists(atPath: soundsDir.path) {
            try? FileManager.default.createDirectory(at: soundsDir, withIntermediateDirectories: true)
        }
        return soundsDir
    }
    
    func loadCustomPacks() {
        guard let url = getPacksURL(),
              let data = try? Data(contentsOf: url),
              let packs = try? JSONDecoder().decode([SoundPack].self, from: data) else {
            return
        }
        self.customPacks = packs
    }
    
    func saveCustomPack(_ pack: SoundPack) {
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
    
    func importSound(from url: URL) -> String? {
        guard let soundsDir = getSoundsDirectory() else { return nil }
        let fileName = url.lastPathComponent
        let destinationURL = soundsDir.appendingPathComponent(fileName)
        
        if !FileManager.default.fileExists(atPath: destinationURL.path) {
            do {
                // Ensure we have access to the URL (might be security scoped)
                let accessed = url.startAccessingSecurityScopedResource()
                try FileManager.default.copyItem(at: url, to: destinationURL)
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            } catch {
                print("Failed to copy sound: \(error)")
                return nil
            }
        }
        
        let soundName = (fileName as NSString).deletingPathExtension
        if !availableSounds.contains(soundName) {
            availableSounds.append(soundName)
        }
        loadSound(named: soundName)
        return soundName
    }
    
    func refreshAvailableSounds() {
        guard let soundsDir = getSoundsDirectory() else { return }
        if let files = try? FileManager.default.contentsOfDirectory(at: soundsDir, includingPropertiesForKeys: nil) {
            for file in files {
                let name = (file.lastPathComponent as NSString).deletingPathExtension
                if !availableSounds.contains(name) {
                    availableSounds.append(name)
                }
            }
        }
    }
    
    private func updateActivePack() {
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
    
    func setMapping(for keyCode: UInt16, soundName: String?) {
        if let soundName = soundName, soundName != "None" {
            activePack.keyMappings[keyCode] = soundName
        } else {
            activePack.keyMappings.removeValue(forKey: keyCode)
        }
        
        // Save to UserDefaults
        if let data = try? JSONEncoder().encode(activePack.keyMappings) {
            UserDefaults.standard.set(data, forKey: "customMappings_\(activePack.name)")
        }
    }
    
    private func setupAudio() {
        let band = eq.bands[0]
        band.filterType = .lowPass
        band.frequency = 1500
        band.bandwidth = 0.5
        band.gain = 24
        band.bypass = false
        
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
    
    func loadSound(named fileName: String) {
        var url: URL? = Bundle.main.url(forResource: fileName, withExtension: "wav")
        if url == nil {
            url = Bundle.main.url(forResource: fileName, withExtension: "mp3")
        }
        if url == nil, let soundsDir = getSoundsDirectory() {
            let wavPath = soundsDir.appendingPathComponent("\(fileName).wav")
            if FileManager.default.fileExists(atPath: wavPath.path) { url = wavPath }
            
            let mp3Path = soundsDir.appendingPathComponent("\(fileName).mp3")
            if url == nil && FileManager.default.fileExists(atPath: mp3Path.path) { url = mp3Path }
        }
        
        guard let finalUrl = url else { return }
        
        do {
            let file = try AVAudioFile(forReading: finalUrl)
            let format = file.processingFormat
            let frameCount = AVAudioFrameCount(file.length)
            
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
            try file.read(into: buffer)
            
            buffers[fileName] = buffer
        } catch {
            print(error)
        }
    }
    
    func playKeyEvent(type: KeyEventType, keyCode: UInt16? = nil, force: Bool = false) {
        if !isGlobalSoundEnabled && !force { return }
        
        var soundName = type == .down ? activePack.defaultDown : activePack.defaultUp
        
        // Check for specific key mapping override
        if let keyCode = keyCode, type == .down {
            if let customSound = activePack.keyMappings[keyCode] {
                soundName = customSound
            }
        }
        
        // Ensure sound is loaded
        if buffers[soundName] == nil {
            loadSound(named: soundName)
        }
        
        guard let buffer = buffers[soundName] else {
            print("Sound not loaded: \(soundName)")
            return
        }
        
        let player = players[currentPlayerIndex]
        if player.isPlaying {
            player.stop()
        }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        player.play()
        
        currentPlayerIndex = (currentPlayerIndex + 1) % maxNodes
    }
}
