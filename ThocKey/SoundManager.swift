import AVFoundation
import SwiftUI

enum KeyEventType {
    case down
    case up
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
    @AppStorage("selectedSoundPack") var selectedSoundPack: String = "Thocky (Default)"
    
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
    }
    
    private func setupAudio() {
        let band = eq.bands[0]
        band.filterType = .lowPass
        band.frequency = 1500   // adjust this if needed
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
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "wav") else { return }
        
        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let frameCount = AVAudioFrameCount(file.length)
            
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
            try file.read(into: buffer)
            
            buffers[fileName] = buffer
        } catch {
            print(error)
        }
    }
    
    func playKeyEvent(type: KeyEventType, force: Bool = false) {
        if !isGlobalSoundEnabled && !force { return }
        
        var soundName = ""
        switch selectedSoundPack {
        case "Creamy":
            soundName = "creamy_key"
        case "Clicky":
            soundName = "clicky_key"
        case "Quiet":
            soundName = "quiet_key"
        default:
            soundName = type == .down ? "thock_down" : "thock_up"
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
