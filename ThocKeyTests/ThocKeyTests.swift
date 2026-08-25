import AVFoundation
import XCTest
@testable import ThocKey

@MainActor
final class ThocKeyTests: XCTestCase {
    private var rootURL: URL!
    private var defaults: UserDefaults!
    private var store: LocalCatalogStore!
    private var suiteName: String!

    override func setUpWithError() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ThocKeyTests-\(UUID().uuidString)", isDirectory: true)
        store = try LocalCatalogStore(rootURL: rootURL)
        suiteName = "ThocKeyTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        if let rootURL { try? FileManager.default.removeItem(at: rootURL) }
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testBuiltInPacks_HaveStableUniqueIDs() {
        let packs = BuiltInSoundData.builtInPacks
        XCTAssertEqual(Set(packs.map(\.id)).count, packs.count)
        XCTAssertEqual(packs.first?.id, BuiltInSoundData.defaultPackID)
        XCTAssertTrue(packs.allSatisfy { UUID(uuidString: $0.id) != nil })
    }

    func testBuiltInPacks_ContainAllFourDefaultPacks() {
        let packs = BuiltInSoundData.builtInPacks
        let names = packs.map(\.name)
        XCTAssertTrue(names.contains("Thocky (Default)"))
        XCTAssertTrue(names.contains("Creamy"))
        XCTAssertTrue(names.contains("Clicky"))
        XCTAssertTrue(names.contains("Quiet"))
    }

    func testBuiltInSounds_AreUnifiedAndReleaseFallsBackToPress() {
        let sounds = BuiltInSoundData.builtInSounds
        XCTAssertEqual(sounds.count, 4)
        XCTAssertEqual(Set(sounds.map(\.displayName)).count, 4)

        let original = sounds.first { $0.id == "builtin_thock" }
        XCTAssertEqual(original?.pressFileName, "thock_down")
        XCTAssertEqual(original?.releaseFileName, "thock_up")

        let creamy = sounds.first { $0.id == "builtin_creamy" }
        XCTAssertNil(creamy?.releaseFileName)
        XCTAssertEqual(creamy?.fileName(for: .up), creamy?.pressFileName)
    }

    func testSelectPack_SwitchesActivePackSuccessfully() {
        let model = makeModel()
        guard let creamy = BuiltInSoundData.builtInPacks.first(where: { $0.name == "Creamy" }) else {
            XCTFail("Creamy pack should exist")
            return
        }
        model.selectPack(id: creamy.id)
        XCTAssertEqual(model.selectedPackID, creamy.id)
        XCTAssertEqual(model.activePack.name, "Creamy")
        XCTAssertEqual(model.activePack.defaultSoundId, "builtin_creamy")
    }

    func testCatalogStore_SaveAndLoadRoundTrip() throws {
        let pack = SoundPack(name: "Test", defaultSoundId: "builtin_thock")
        let manifest = CatalogManifest(packs: [pack], selectedPackID: pack.id)
        try store.saveCatalog(manifest)
        XCTAssertEqual(try store.loadCatalog(), manifest)
    }

    func testCatalogStore_CorruptPrimaryRecoversBackup() throws {
        let first = CatalogManifest(selectedPackID: BuiltInSoundData.defaultPackID)
        let secondPack = SoundPack(name: "Second", defaultSoundId: "builtin_thock")
        try store.saveCatalog(first)
        try store.saveCatalog(CatalogManifest(packs: [secondPack], selectedPackID: secondPack.id))
        try Data("not-json".utf8).write(to: rootURL.appendingPathComponent("catalog.json"), options: .atomic)
        XCTAssertEqual(try store.loadCatalog(), first)
    }

    func testCatalogStore_CorruptCatalogWithoutBackupReturnsTypedError() throws {
        try Data("not-json".utf8).write(to: rootURL.appendingPathComponent("catalog.json"), options: .atomic)
        XCTAssertThrowsError(try store.loadCatalog()) { error in
            XCTAssertEqual(error as? ThocKeyError, .catalogCorrupted)
        }
    }

    func testDuplicatePackNames_SelectionRemainsIDBased() throws {
        let first = SoundPack(name: "Same Name", defaultSoundId: "builtin_thock")
        let second = SoundPack(name: "Same Name", defaultSoundId: "builtin_clicky")
        try store.saveCatalog(CatalogManifest(packs: [first, second], selectedPackID: second.id))

        let model = makeModel()
        XCTAssertEqual(model.selectedPackID, second.id)
        XCTAssertEqual(model.activePack.defaultSoundId, "builtin_clicky")
    }

    func testLegacyNameSelectionAndMapping_MigrateToCatalogIDs() throws {
        defaults.set("Creamy", forKey: "selectedSoundPackName")
        let mapping: [UInt16: String] = [49: "builtin_clicky_down"]
        defaults.set(try JSONEncoder().encode(mapping), forKey: "customMappings_Creamy")

        let model = makeModel()
        XCTAssertEqual(model.activePack.name, "Creamy")
        XCTAssertEqual(model.activePack.keyMappings[49], "builtin_clicky")
        XCTAssertNotNil(try store.loadCatalog())
    }

    func testMapping_PersistsAcrossModelInstances() {
        let first = makeModel()
        first.setMapping(for: 49, soundId: "builtin_clicky")

        let second = makeModel()
        XCTAssertEqual(second.activePack.keyMappings[49], "builtin_clicky")
        second.setMapping(for: 49, soundId: "None")
        XCTAssertNil(second.activePack.keyMappings[49])
    }

    func testDeleteSound_WhenReferencedReturnsPackNames() throws {
        let model = makeModel()
        let sound = try model.importSound(from: bundledSoundURL())
        let pack = SoundPack(name: "Reference Pack", defaultSoundId: sound.id)
        try model.saveCustomPack(pack)

        XCTAssertThrowsError(try model.deleteSound(id: sound.id)) { error in
            XCTAssertEqual(error as? ThocKeyError, .soundInUse(["Reference Pack"]))
        }
    }

    func testImportedSound_AppearsImmediatelyAndGeneratedPackIsReused() throws {
        let model = makeModel()
        let sound = try model.importSound(from: bundledSoundURL(), displayName: "My Switch")

        XCTAssertEqual(model.customSounds.map(\.id), [sound.id])
        XCTAssertEqual(try model.setActiveSound(sound: sound), "My Switch")
        let generatedID = model.selectedPackID
        XCTAssertEqual(model.activePack.sourceSoundId, sound.id)
        XCTAssertEqual(model.activePack.defaultSoundId, sound.id)

        _ = try model.setActiveSound(sound: sound)
        XCTAssertEqual(model.selectedPackID, generatedID)
        XCTAssertEqual(model.customPacks.filter { $0.sourceSoundId == sound.id }.count, 1)
    }

    func testCustomizeCustomSound_ReplacesItemWithoutCreatingDuplicateRows() async throws {
        let model = makeModel()
        let imported = try model.importSound(from: bundledSoundURL(), displayName: "Imported")

        let customized = try await model.saveTrimmedSound(
            sourceSoundId: imported.id,
            newDisplayName: "Refined",
            startTime: 0,
            endTime: 0.02,
            replacingSoundId: imported.id
        )

        XCTAssertEqual(customized.id, imported.id)
        XCTAssertEqual(customized.displayName, "Refined")
        XCTAssertEqual(model.customSounds.count, 1)
        XCTAssertEqual(model.customSounds.first?.id, imported.id)
    }

    func testDeleteSound_RemovesGeneratedPackAndFallsBackToOriginal() throws {
        let model = makeModel()
        let sound = try model.importSound(from: bundledSoundURL())
        _ = try model.setActiveSound(sound: sound)

        try model.deleteSound(id: sound.id)

        XCTAssertNil(model.findSound(byId: sound.id))
        XCTAssertFalse(model.customPacks.contains { $0.sourceSoundId == sound.id })
        XCTAssertEqual(model.selectedPackID, BuiltInSoundData.defaultPackID)
    }

    func testAppearancePreference_PersistsAcrossModels() {
        let first = makeModel()
        first.appearancePreference = .light

        XCTAssertEqual(makeModel().appearancePreference, .light)
    }

    func testCatalogV1Migration_MergesDistinctVariantsAndCustomizedCategory() throws {
        let pressURL = store.soundsDirectoryURL.appendingPathComponent("legacy_down.wav")
        let releaseURL = store.soundsDirectoryURL.appendingPathComponent("legacy_up.wav")
        try FileManager.default.copyItem(at: bundledSoundURL(), to: pressURL)
        try FileManager.default.copyItem(at: bundledSoundURL(), to: releaseURL)
        let packID = UUID().uuidString
        let json = """
        {
          "schemaVersion": 1,
          "sounds": [
            {"id":"legacy_down","displayName":"Legacy (Down)","fileName":"legacy_down.wav","packName":"Customized","category":"Customized","duration":0.09,"isBuiltIn":false},
            {"id":"legacy_up","displayName":"Legacy (Up)","fileName":"legacy_up.wav","packName":"Customized","category":"Customized","duration":0.09,"isBuiltIn":false}
          ],
          "packs": [
            {"id":"\(packID)","name":"Legacy Pack","defaultDownSoundId":"legacy_down","defaultUpSoundId":"legacy_up","keyMappings":[],"isBuiltIn":false}
          ],
          "selectedPackID":"\(packID)",
          "packMappings":{}
        }
        """
        _ = try JSONDecoder().decode(CatalogManifest.self, from: Data(json.utf8))
        try Data(json.utf8).write(to: rootURL.appendingPathComponent("catalog.json"), options: .atomic)

        let model = makeModel()
        let unified = model.findSound(byId: model.activePack.defaultSoundId)

        XCTAssertEqual(model.selectedPackID, packID)
        XCTAssertEqual(unified?.displayName, "Legacy")
        XCTAssertEqual(unified?.pressFileName, "legacy_down.wav")
        XCTAssertEqual(unified?.releaseFileName, "legacy_up.wav")
        XCTAssertEqual(unified?.category, .custom)
        XCTAssertEqual(try store.loadCatalog()?.schemaVersion, 2)
    }

    func testKeyMapping_UsesMappedSoundForPressAndRelease() {
        let player = MockAudioPlayer()
        let model = AppModel(
            catalogStore: store, playback: player,
            keyboardMonitor: MockKeyboardMonitor(), userDefaults: defaults
        )
        model.setMapping(for: 49, soundId: "builtin_thock")

        model.playKeyEvent(type: .down, keyCode: 49, force: true)
        model.playKeyEvent(type: .up, keyCode: 49, force: true)

        XCTAssertEqual(player.playedSoundIDs.suffix(2), ["builtin_thock:press", "builtin_thock:release"])
    }

    func testImportSound_RejectsUnsupportedExtension() throws {
        let url = rootURL.appendingPathComponent("invalid.txt")
        try Data("audio?".utf8).write(to: url)
        XCTAssertThrowsError(try makeModel().importSound(from: url)) { error in
            XCTAssertEqual(error as? ThocKeyError, .unsupportedAudioFormat)
        }
    }

    func testImportSound_RejectsFilesOverFiftyMegabytes() throws {
        let url = rootURL.appendingPathComponent("oversized.wav")
        XCTAssertTrue(FileManager.default.createFile(atPath: url.path, contents: nil))
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: 50 * 1_024 * 1_024 + 1)
        try handle.close()

        XCTAssertThrowsError(try makeModel().importSound(from: url)) { error in
            XCTAssertEqual(error as? ThocKeyError, .audioFileTooLarge)
        }
    }

    func testMissingCustomSoundFile_IsRemovedDuringLoad() throws {
        let sound = SoundItem(displayName: "Missing", pressFileName: "missing.wav")
        try store.saveCatalog(CatalogManifest(sounds: [sound], selectedPackID: BuiltInSoundData.defaultPackID))
        XCTAssertNil(makeModel().findSound(byId: sound.id))
    }

    func testKeyboardMonitor_StartIsIdempotentAndStops() {
        let monitor = MockKeyboardMonitor()
        let model = AppModel(catalogStore: store, playback: MockAudioPlayer(), keyboardMonitor: monitor, userDefaults: defaults)
        model.startKeyboardMonitoring(requestPermission: false)
        model.startKeyboardMonitoring(requestPermission: false)
        model.stopKeyboardMonitoring()
        XCTAssertEqual(monitor.startCount, 1)
        XCTAssertEqual(monitor.stopCount, 1)
    }

    func testAudioTrimmer_GeneratesValidWAVFile() throws {
        let output = rootURL.appendingPathComponent("trimmed.wav")
        try AudioProcessingService.shared.trimAndExportAudio(
            sourceURL: bundledSoundURL(), startTime: 0, endTime: 0.05,
            gain: 1.2, applyMicroFade: true, outputURL: output
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
        XCTAssertGreaterThan(AudioProcessingService.shared.getAudioDuration(from: output), 0)
    }

    func testAudioPlaybackEngine_EvictsOldestBuffersAtCapacity() throws {
        let engine = try AudioPlaybackEngine(maxPlayers: 1, maxCachedBuffers: 2)
        let soundURL = try bundledSoundURL()
        try engine.preload(soundID: "one", from: soundURL)
        try engine.preload(soundID: "two", from: soundURL)
        try engine.preload(soundID: "three", from: soundURL)
        XCTAssertEqual(engine.cachedBufferCount, 2)
    }

    func testTrim_RejectsEmptyOutputName() async throws {
        let model = makeModel()
        await XCTAssertThrowsErrorAsync(
            try await model.saveTrimmedSound(
                sourceSoundId: "builtin_thock", newDisplayName: "   ",
                startTime: 0, endTime: 0.02
            )
        ) { error in
            XCTAssertEqual(error as? ThocKeyError, .invalidName)
        }
    }

    func testFavoritePacks_ToggleAndPersistCorrectly() {
        let model = makeModel()
        let packID = BuiltInSoundData.defaultPackID
        XCTAssertFalse(model.isFavorite(packID: packID))

        model.toggleFavorite(packID: packID)
        XCTAssertTrue(model.isFavorite(packID: packID))
        XCTAssertTrue(model.favoritePacks.contains(where: { $0.id == packID }))

        // Verify across model instances
        let model2 = makeModel()
        XCTAssertTrue(model2.isFavorite(packID: packID))

        model2.toggleFavorite(packID: packID)
        XCTAssertFalse(model2.isFavorite(packID: packID))
    }

    func testSnooze_PauseAndResumeSuppressesKeystrokes() {
        let player = MockAudioPlayer()
        let model = AppModel(catalogStore: store, playback: player, keyboardMonitor: MockKeyboardMonitor(), userDefaults: defaults)

        XCTAssertFalse(model.isPaused)
        model.pauseSounds(for: 900)
        XCTAssertTrue(model.isPaused)
        XCTAssertEqual(model.pauseRemainingSeconds, 900)
        XCTAssertEqual(model.pauseRemainingFormatted, "15:00")

        model.playKeyEvent(type: .down, keyCode: 49)
        XCTAssertTrue(player.playedSoundIDs.isEmpty, "Keystrokes should be silenced while paused")

        model.resumeSounds()
        XCTAssertFalse(model.isPaused)
        XCTAssertEqual(model.pauseRemainingSeconds, 0)

        model.playKeyEvent(type: .down, keyCode: 49)
        XCTAssertFalse(player.playedSoundIDs.isEmpty, "Keystrokes should play after resuming")
    }

    func testSoundCategory_CustomizedDecodingAndHandling() throws {
        let json = """
        {"id":"test1","displayName":"Trimmed Sound","pressFileName":"press.wav","pressDuration":0.05,"category":"Customized","isBuiltIn":false}
        """
        let item = try JSONDecoder().decode(SoundItem.self, from: Data(json.utf8))
        XCTAssertEqual(item.category, .customized)

        let encoded = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(SoundItem.self, from: encoded)
        XCTAssertEqual(decoded.category, .customized)
    }

    func testModifierKeyMapping_ResolvesLeftAndRightKeyCodes() {
        let player = MockAudioPlayer()
        let model = AppModel(catalogStore: store, playback: player, keyboardMonitor: MockKeyboardMonitor(), userDefaults: defaults)

        // Map Left Command (55) to clicky
        model.setMapping(for: 55, soundId: "builtin_clicky")

        // Pressing Left Command (55)
        model.playKeyEvent(type: .down, keyCode: 55)
        XCTAssertEqual(player.playedSoundIDs.last, "builtin_clicky:press")

        // Pressing Right Command (54) should fallback to Left Command mapping
        model.playKeyEvent(type: .down, keyCode: 54)
        XCTAssertEqual(player.playedSoundIDs.last, "builtin_clicky:press")
    }

    func testStudioTab_SelectionAndRouting() {
        let model = makeModel()
        XCTAssertEqual(model.selectedTab, .packs)

        model.selectedTab = .settings
        XCTAssertEqual(model.selectedTab, .settings)

        model.selectedTab = .keyMapping
        XCTAssertEqual(model.selectedTab, .keyMapping)
    }

    private func makeModel() -> AppModel {
        AppModel(catalogStore: store, playback: MockAudioPlayer(), keyboardMonitor: MockKeyboardMonitor(), userDefaults: defaults)
    }

    private func bundledSoundURL() throws -> URL {
        guard let url = Bundle.main.url(forResource: "thock_down", withExtension: "wav") else {
            throw XCTSkip("Bundled sound unavailable in test host")
        }
        return url
    }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void = { _ in },
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected expression to throw", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}

@MainActor
private final class MockAudioPlayer: AudioPlaying {
    var playedSoundIDs: [String] = []
    func setVolume(_ volume: Double) {}
    func preload(soundID: String, from url: URL) throws {}
    func play(soundID: String, from url: URL) throws { playedSoundIDs.append(soundID) }
    func remove(soundID: String) {}
    func clearCache() {}
}

@MainActor
private final class MockKeyboardMonitor: KeyboardMonitoring {
    var isAccessibilityEnabled = true
    var startCount = 0
    var stopCount = 0
    func requestAccessibilityPermission() {}
    func start(onKeyDown: @escaping (UInt16) -> Void, onKeyUp: @escaping (UInt16) -> Void, onToggleMute: @escaping () -> Void) {
        startCount += 1
    }
    func stop() { stopCount += 1 }
}
