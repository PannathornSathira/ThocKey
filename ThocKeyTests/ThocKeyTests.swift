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

    func testSelectPack_SwitchesActivePackSuccessfully() {
        let model = makeModel()
        guard let creamy = BuiltInSoundData.builtInPacks.first(where: { $0.name == "Creamy" }) else {
            XCTFail("Creamy pack should exist")
            return
        }
        model.selectPack(id: creamy.id)
        XCTAssertEqual(model.selectedPackID, creamy.id)
        XCTAssertEqual(model.activePack.name, "Creamy")
        XCTAssertEqual(model.activePack.defaultDownSoundId, "builtin_creamy_down")
    }

    func testCatalogStore_SaveAndLoadRoundTrip() throws {
        let pack = SoundPack(name: "Test", defaultDownSoundId: "builtin_thock_down", defaultUpSoundId: "builtin_thock_up")
        let manifest = CatalogManifest(packs: [pack], selectedPackID: pack.id)
        try store.saveCatalog(manifest)
        XCTAssertEqual(try store.loadCatalog(), manifest)
    }

    func testCatalogStore_CorruptPrimaryRecoversBackup() throws {
        let first = CatalogManifest(selectedPackID: BuiltInSoundData.defaultPackID)
        let secondPack = SoundPack(name: "Second", defaultDownSoundId: "builtin_thock_down", defaultUpSoundId: "builtin_thock_up")
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
        let first = SoundPack(name: "Same Name", defaultDownSoundId: "builtin_thock_down", defaultUpSoundId: "builtin_thock_up")
        let second = SoundPack(name: "Same Name", defaultDownSoundId: "builtin_clicky_down", defaultUpSoundId: "builtin_clicky_up")
        try store.saveCatalog(CatalogManifest(packs: [first, second], selectedPackID: second.id))

        let model = makeModel()
        XCTAssertEqual(model.selectedPackID, second.id)
        XCTAssertEqual(model.activePack.defaultDownSoundId, "builtin_clicky_down")
    }

    func testLegacyNameSelectionAndMapping_MigrateToCatalogIDs() throws {
        defaults.set("Creamy", forKey: "selectedSoundPackName")
        let mapping: [UInt16: String] = [49: "builtin_clicky_down"]
        defaults.set(try JSONEncoder().encode(mapping), forKey: "customMappings_Creamy")

        let model = makeModel()
        XCTAssertEqual(model.activePack.name, "Creamy")
        XCTAssertEqual(model.activePack.keyMappings[49], "builtin_clicky_down")
        XCTAssertNotNil(try store.loadCatalog())
    }

    func testMapping_PersistsAcrossModelInstances() {
        let first = makeModel()
        first.setMapping(for: 49, soundId: "builtin_clicky_down")

        let second = makeModel()
        XCTAssertEqual(second.activePack.keyMappings[49], "builtin_clicky_down")
        second.setMapping(for: 49, soundId: "None")
        XCTAssertNil(second.activePack.keyMappings[49])
    }

    func testDeleteSound_WhenReferencedReturnsPackNames() throws {
        let model = makeModel()
        let sound = try model.importSound(from: bundledSoundURL())
        let pack = SoundPack(name: "Reference Pack", defaultDownSoundId: sound.id, defaultUpSoundId: sound.id)
        try model.saveCustomPack(pack)

        XCTAssertThrowsError(try model.deleteSound(id: sound.id)) { error in
            XCTAssertEqual(error as? ThocKeyError, .soundInUse(["Reference Pack"]))
        }
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
        let sound = SoundItem(displayName: "Missing", fileName: "missing.wav")
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
                sourceSoundId: "builtin_thock_down", newDisplayName: "   ",
                startTime: 0, endTime: 0.02
            )
        ) { error in
            XCTAssertEqual(error as? ThocKeyError, .invalidName)
        }
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
    func setVolume(_ volume: Double) {}
    func preload(soundID: String, from url: URL) throws {}
    func play(soundID: String, from url: URL) throws {}
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
