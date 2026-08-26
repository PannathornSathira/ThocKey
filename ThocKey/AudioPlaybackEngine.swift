import AVFoundation
import OSLog

@MainActor
public protocol AudioPlaying: AnyObject {
    func setVolume(_ volume: Double)
    func preload(soundID: String, from url: URL) throws
    func play(soundID: String, from url: URL) throws
    func stopAll()
    func remove(soundID: String)
    func clearCache()
}

@MainActor
public final class AudioPlaybackEngine: AudioPlaying {
    private struct CacheEntry {
        let buffer: AVAudioPCMBuffer
        var lastAccess: UInt64
    }

    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    private var players: [AVAudioPlayerNode] = []
    private var cache: [String: CacheEntry] = [:]
    private var accessCounter: UInt64 = 0
    private var currentPlayerIndex = 0
    private let maxPlayers: Int
    private let maxCachedBuffers: Int
    private let logger = Logger(subsystem: "com.pannathorn.ThocKey", category: "Audio")
    var cachedBufferCount: Int { cache.count }

    public init(maxPlayers: Int = 12, maxCachedBuffers: Int = 32) throws {
        self.maxPlayers = maxPlayers
        self.maxCachedBuffers = maxCachedBuffers
        engine.attach(mixer)
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)

        for _ in 0..<maxPlayers {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: mixer, format: nil)
            players.append(player)
        }

        do {
            try engine.start()
        } catch {
            throw ThocKeyError.operationFailed("The audio engine could not start: \(error.localizedDescription)")
        }
    }

    public func setVolume(_ volume: Double) {
        players.forEach { $0.volume = Float(max(0, min(1, volume))) }
    }

    public func preload(soundID: String, from url: URL) throws {
        _ = try buffer(soundID: soundID, url: url)
    }

    public func play(soundID: String, from url: URL) throws {
        guard !players.isEmpty else { return }
        if !engine.isRunning {
            try? engine.start()
        }
        let pcmBuffer = try buffer(soundID: soundID, url: url)
        let player = players[currentPlayerIndex]
        if player.isPlaying { player.stop() }
        engine.disconnectNodeOutput(player)
        engine.connect(player, to: mixer, format: pcmBuffer.format)
        player.scheduleBuffer(pcmBuffer, at: nil, options: .interrupts)
        player.play()
        currentPlayerIndex = (currentPlayerIndex + 1) % maxPlayers
    }

    public func stopAll() {
        players.forEach { if $0.isPlaying { $0.stop() } }
    }

    public func remove(soundID: String) {
        cache.removeValue(forKey: soundID)
    }

    public func clearCache() {
        players.forEach { $0.stop() }
        cache.removeAll()
    }

    private func buffer(soundID: String, url: URL) throws -> AVAudioPCMBuffer {
        accessCounter &+= 1
        if var entry = cache[soundID] {
            entry.lastAccess = accessCounter
            cache[soundID] = entry
            return entry.buffer
        }

        do {
            let file = try AVAudioFile(forReading: url)
            guard file.length > 0,
                  file.length <= AVAudioFramePosition(UInt32.max),
                  let buffer = AVAudioPCMBuffer(
                    pcmFormat: file.processingFormat,
                    frameCapacity: AVAudioFrameCount(file.length)
                  ) else {
                throw ThocKeyError.invalidAudio
            }
            try file.read(into: buffer)
            cache[soundID] = CacheEntry(buffer: buffer, lastAccess: accessCounter)
            evictIfNeeded(protecting: soundID)
            return buffer
        } catch let error as ThocKeyError {
            throw error
        } catch {
            logger.error("Buffer load failed: \(error.localizedDescription, privacy: .public)")
            throw ThocKeyError.invalidAudio
        }
    }

    private func evictIfNeeded(protecting soundID: String) {
        while cache.count > maxCachedBuffers,
              let oldest = cache
                .filter({ $0.key != soundID })
                .min(by: { $0.value.lastAccess < $1.value.lastAccess })?.key {
            cache.removeValue(forKey: oldest)
        }
    }
}
