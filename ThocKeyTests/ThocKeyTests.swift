import XCTest
import AVFoundation
@testable import ThocKey

final class ThocKeyTests: XCTestCase {

    override func setUpWithError() throws {
        super.setUp()
    }

    override func tearDownWithError() throws {
        super.tearDown()
    }

    // MARK: - Model Tests
    
    func testBuiltInSounds_HaveOfficialDisplayNames() {
        let sounds = BuiltInSoundData.builtInSounds
        XCTAssertGreaterThanOrEqual(sounds.count, 4, "Should bundle at least 4 core sound types")
        
        let displayNames = sounds.map { $0.displayName }
        XCTAssertTrue(displayNames.contains("Thock (Down)"), "Display name should be official format")
        XCTAssertTrue(displayNames.contains("Creamy (Down)"))
        XCTAssertTrue(displayNames.contains("Clicky (Down)"))
        XCTAssertTrue(displayNames.contains("Quiet (Down)"))
    }
    
    func testBuiltInPacks_ContainExpectedPacks() {
        let packs = BuiltInSoundData.builtInPacks
        let packNames = packs.map { $0.name }
        
        XCTAssertTrue(packNames.contains("Thocky (Default)"))
        XCTAssertTrue(packNames.contains("Creamy"))
        XCTAssertTrue(packNames.contains("Clicky"))
        XCTAssertTrue(packNames.contains("Quiet"))
    }
    
    // MARK: - SoundManager Tests
    
    func testGroupedSoundsByPack_ReturnsGroupedCategories() {
        let manager = SoundManager.shared
        let grouped = manager.groupedSoundsByPack()
        
        XCTAssertFalse(grouped.isEmpty, "Grouped sounds should not be empty")
        let packNames = grouped.map { $0.packName }
        XCTAssertTrue(packNames.contains("Thocky"))
        XCTAssertTrue(packNames.contains("Creamy"))
        XCTAssertTrue(packNames.contains("Clicky"))
        XCTAssertTrue(packNames.contains("Quiet"))
    }
    
    func testKeyMapping_SetsAndClearsCorrectly() {
        let manager = SoundManager.shared
        let spaceKeyCode: UInt16 = 49
        
        // Set custom mapping
        manager.setMapping(for: spaceKeyCode, soundId: "builtin_clicky_down")
        XCTAssertEqual(manager.activePack.keyMappings[spaceKeyCode], "builtin_clicky_down")
        
        // Clear mapping
        manager.setMapping(for: spaceKeyCode, soundId: "None")
        XCTAssertNil(manager.activePack.keyMappings[spaceKeyCode])
    }
    
    func testRenameSound_UpdatesDisplayName() {
        let manager = SoundManager.shared
        let testSound = SoundItem(
            id: "test_custom_sound_id",
            displayName: "Old Name",
            fileName: "test_sound.wav",
            packName: "Custom",
            category: .custom,
            duration: 0.1,
            isBuiltIn: false
        )
        
        manager.soundLibrary.append(testSound)
        manager.renameSound(id: "test_custom_sound_id", newDisplayName: "New Official Sound")
        
        let updated = manager.findSound(byId: "test_custom_sound_id")
        XCTAssertEqual(updated?.displayName, "New Official Sound")
        
        // Clean up
        _ = manager.deleteSound(id: "test_custom_sound_id")
    }
    
    func testDeleteSound_BuiltInCannotBeDeleted() {
        let manager = SoundManager.shared
        let deleted = manager.deleteSound(id: "builtin_thock_down")
        XCTAssertFalse(deleted, "Built-in sound should be protected from deletion")
    }
    
    func testSetActiveSound_SwitchesPackAndCreatesCustomPack() {
        let manager = SoundManager.shared
        
        // 1. Built-in sound activation
        if let creamySound = manager.findSound(byId: "builtin_creamy_down") {
            let activePackName = manager.setActiveSound(sound: creamySound)
            XCTAssertEqual(activePackName, "Creamy")
            XCTAssertEqual(manager.selectedSoundPackName, "Creamy")
        }
        
        // 2. Custom sound activation
        let customSound = SoundItem(
            id: "test_custom_active_id",
            displayName: "Bespoke Thock",
            fileName: "bespoke_thock.wav",
            packName: "Custom",
            category: .custom,
            duration: 0.1,
            isBuiltIn: false
        )
        let customPackName = manager.setActiveSound(sound: customSound)
        XCTAssertEqual(customPackName, "Bespoke Thock Pack")
        XCTAssertEqual(manager.selectedSoundPackName, "Bespoke Thock Pack")
        
        // Clean up
        manager.deleteCustomPack(named: "Bespoke Thock Pack")
    }
    
    // MARK: - Audio Processing Tests
    
    func testWaveformExtraction_ReturnsNormalizedSamples() async throws {
        // Find a bundled WAV file
        guard let url = Bundle.main.url(forResource: "thock_down", withExtension: "wav") ??
                        Bundle(for: ThocKeyTests.self).url(forResource: "thock_down", withExtension: "wav") else {
            return // Skip if resource not in test bundle
        }
        
        let samples = await AudioProcessingService.shared.extractWaveform(from: url, sampleCount: 50)
        XCTAssertEqual(samples.count, 50)
        for s in samples {
            XCTAssertGreaterThanOrEqual(s, 0.0)
            XCTAssertLessThanOrEqual(s, 1.0)
        }
    }
    
    func testAudioTrimmer_GeneratesValidWAVFile() throws {
        guard let url = Bundle.main.url(forResource: "thock_down", withExtension: "wav") ??
                        Bundle(for: ThocKeyTests.self).url(forResource: "thock_down", withExtension: "wav") else {
            return
        }
        
        let tempOut = FileManager.default.temporaryDirectory.appendingPathComponent("unit_test_trimmed.wav")
        try AudioProcessingService.shared.trimAndExportAudio(
            sourceURL: url,
            startTime: 0.0,
            endTime: 0.05,
            gain: 1.2,
            applyMicroFade: true,
            outputURL: tempOut
        )
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempOut.path))
        let duration = AudioProcessingService.shared.getAudioDuration(from: tempOut)
        XCTAssertGreaterThan(duration, 0.0)
        XCTAssertLessThanOrEqual(duration, 0.06)
        
        // Clean up
        try? FileManager.default.removeItem(at: tempOut)
    }
}
