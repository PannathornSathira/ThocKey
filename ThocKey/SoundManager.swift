import AVFoundation
import SwiftUI

class SoundManager: ObservableObject {
    static let shared = SoundManager()
    
    // Persisted settings
    @AppStorage("isGlobalSoundEnabled") var isGlobalSoundEnabled: Bool = true
    @AppStorage("masterVolume") var masterVolume: Double = 0.8 {
        didSet {
            player.volume = Float(masterVolume)
        }
    }
    
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let eq = AVAudioUnitEQ(numberOfBands: 1)
    
    private var buffer: AVAudioPCMBuffer?
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
        
        engine.attach(player)
        engine.attach(eq)
        
        engine.connect(player, to: eq, format: nil)
        engine.connect(eq, to: engine.mainMixerNode, format: nil)
        
        player.volume = Float(masterVolume)
        
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

    func playSound(named fileName: String, force: Bool = false) {
        // If sound is globally disabled and this isn't a forced play (like from the UI), don't play.
        if !isGlobalSoundEnabled && !force { return }
        
        guard let buffer = buffers[fileName] else {
            print("Sound not loaded: \(fileName)")
            return
        }
        
        if player.isPlaying {
            player.stop()
        }
        
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        player.play()
    }
}
