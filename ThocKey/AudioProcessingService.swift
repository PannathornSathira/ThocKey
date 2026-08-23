import Foundation
import AVFoundation
import Accelerate

public class AudioProcessingService {
    public static let shared = AudioProcessingService()
    
    private init() {}
    
    // MARK: - Waveform Extraction
    
    /// Extracts normalized amplitude points (0.0 ... 1.0) from an audio file for UI waveform rendering.
    public func extractWaveform(from url: URL, sampleCount: Int = 80) async -> [Float] {
        return await Task.detached(priority: .userInitiated) {
            guard let audioFile = try? AVAudioFile(forReading: url) else {
                return Array(repeating: 0.1, count: sampleCount)
            }
            
            let format = audioFile.processingFormat
            let frameCount = AVAudioFrameCount(audioFile.length)
            guard frameCount > 0,
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                return Array(repeating: 0.1, count: sampleCount)
            }
            
            do {
                try audioFile.read(into: buffer)
            } catch {
                return Array(repeating: 0.1, count: sampleCount)
            }
            
            guard let channelData = buffer.floatChannelData?[0] else {
                return Array(repeating: 0.1, count: sampleCount)
            }
            
            let totalFrames = Int(buffer.frameLength)
            guard totalFrames > 0 else {
                return Array(repeating: 0.1, count: sampleCount)
            }
            
            let chunkSize = max(1, totalFrames / sampleCount)
            var samples: [Float] = []
            samples.reserveCapacity(sampleCount)
            
            var maxAmplitude: Float = 0.001
            
            for i in 0..<sampleCount {
                let startIdx = i * chunkSize
                let endIdx = min(startIdx + chunkSize, totalFrames)
                guard startIdx < endIdx else {
                    samples.append(0.05)
                    continue
                }
                
                var sumSquares: Float = 0.0
                let count = endIdx - startIdx
                for j in startIdx..<endIdx {
                    let sample = channelData[j]
                    sumSquares += sample * sample
                }
                
                let rms = sqrt(sumSquares / Float(count))
                samples.append(rms)
                if rms > maxAmplitude {
                    maxAmplitude = rms
                }
            }
            
            // Normalize so peaks are visible and minimum height is 0.08
            return samples.map { sample in
                let normalized = sample / maxAmplitude
                return max(0.08, min(1.0, normalized))
            }
        }.value
    }
    
    /// Gets audio duration in seconds
    public func getAudioDuration(from url: URL) -> Double {
        guard let audioFile = try? AVAudioFile(forReading: url) else { return 0.0 }
        let sampleRate = audioFile.processingFormat.sampleRate
        guard sampleRate > 0 else { return 0.0 }
        return Double(audioFile.length) / sampleRate
    }
    
    // MARK: - Audio Trimming & Export
    
    /// Slices an audio file with gain and anti-click micro-fades, saving as a 16-bit WAV file.
    public func trimAndExportAudio(
        sourceURL: URL,
        startTime: Double,
        endTime: Double,
        gain: Float = 1.0,
        applyMicroFade: Bool = true,
        outputURL: URL
    ) throws {
        let inputFile = try AVAudioFile(forReading: sourceURL)
        let format = inputFile.processingFormat
        let sampleRate = format.sampleRate
        let channelCount = Int(format.channelCount)
        
        let startFrame = max(0, AVAudioFramePosition(startTime * sampleRate))
        let endFrame = min(inputFile.length, AVAudioFramePosition(endTime * sampleRate))
        let targetLength = max(1, AVAudioFrameCount(endFrame - startFrame))
        
        // Read the entire file into buffer
        guard let fullBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(inputFile.length)) else {
            throw NSError(domain: "AudioProcessingService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to allocate audio buffer"])
        }
        try inputFile.read(into: fullBuffer)
        
        // Create sliced buffer
        guard let slicedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: targetLength) else {
            throw NSError(domain: "AudioProcessingService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to allocate sliced buffer"])
        }
        slicedBuffer.frameLength = targetLength
        
        let fadeFrames = applyMicroFade ? min(Int(0.008 * sampleRate), Int(targetLength / 4)) : 0
        
        for ch in 0..<channelCount {
            guard let inChannel = fullBuffer.floatChannelData?[ch],
                  let outChannel = slicedBuffer.floatChannelData?[ch] else { continue }
            
            for i in 0..<Int(targetLength) {
                let sourceIdx = Int(startFrame) + i
                var sample = inChannel[sourceIdx] * gain
                
                // Anti-click micro fade-in
                if fadeFrames > 0 && i < fadeFrames {
                    let fadeMultiplier = Float(i) / Float(fadeFrames)
                    sample *= fadeMultiplier
                }
                
                // Anti-click micro fade-out
                if fadeFrames > 0 && i >= (Int(targetLength) - fadeFrames) {
                    let remaining = Int(targetLength) - 1 - i
                    let fadeMultiplier = Float(remaining) / Float(fadeFrames)
                    sample *= fadeMultiplier
                }
                
                // Clamp to avoid clipping distortion
                outChannel[i] = max(-1.0, min(1.0, sample))
            }
        }
        
        // Remove existing file at destination if present
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        
        // Standard output format: 44.1kHz 16-bit stereo or mono WAV
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channelCount,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        let outputFile = try AVAudioFile(forWriting: outputURL, settings: outputSettings)
        try outputFile.write(from: slicedBuffer)
    }
}
