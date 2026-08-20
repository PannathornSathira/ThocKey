import AVFoundation

class SoundManager {
    static let shared = SoundManager()
    
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let eq = AVAudioUnitEQ(numberOfBands: 1)
    
    private var buffer: AVAudioPCMBuffer?
    
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
        
        try? engine.start()
    }
    
    // 🔥 Call this once (e.g. on app start)
    private var buffers: [String: AVAudioPCMBuffer] = [:]

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

    func playSound(named fileName: String) {
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
