import AppKit
import AVFoundation
import Foundation
import OSLog
import SwiftUI

public enum KeyEventType {
    case down
    case up
}

public enum AppearancePreference: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    public var id: String { rawValue }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

@MainActor
public final class AppModel: ObservableObject {
    public static let shared: AppModel = {
        let environment = ProcessInfo.processInfo.environment
        guard environment["THOCKEY_UI_TEST"] == "1",
              let rootPath = environment["THOCKEY_STORAGE_ROOT"],
              let store = try? LocalCatalogStore(rootURL: URL(fileURLWithPath: rootPath, isDirectory: true)),
              let defaults = UserDefaults(suiteName: "ThocKeyUITests") else {
            return AppModel()
        }
        if environment["THOCKEY_UI_TEST_RESET_DEFAULTS"] == "1" {
            defaults.removePersistentDomain(forName: "ThocKeyUITests")
        }
        return AppModel(catalogStore: store, userDefaults: defaults)
    }()

    @Published public var isGlobalSoundEnabled: Bool {
        didSet {
            userDefaults.set(isGlobalSoundEnabled, forKey: Keys.soundEnabled)
            if !isGlobalSoundEnabled { playback?.stopAll() }
        }
    }
    @Published public var masterVolume: Double {
        didSet {
            let clamped = max(0, min(1, masterVolume))
            if clamped != masterVolume { masterVolume = clamped; return }
            userDefaults.set(masterVolume, forKey: Keys.masterVolume)
            playback?.setVolume(masterVolume)
        }
    }
    @Published public var appearancePreference: AppearancePreference {
        didSet { userDefaults.set(appearancePreference.rawValue, forKey: Keys.appearance) }
    }
    @Published public var selectedTab: StudioTab = .packs
    @Published public var isPaused: Bool = false {
        didSet {
            if isPaused { playback?.stopAll() }
        }
    }
    @Published public var pauseRemainingSeconds: Int = 0
    @Published public private(set) var selectedPackID: String
    @Published public private(set) var activePack: SoundPack = BuiltInSoundData.builtInPacks[0]
    @Published public private(set) var customPacks: [SoundPack] = []
    @Published public private(set) var favoritePackIDs: Set<String> = []
    @Published public private(set) var soundLibrary: [SoundItem] = BuiltInSoundData.builtInSounds
    @Published public private(set) var isAccessibilityEnabled = false
    @Published public var presentedError: ThocKeyError?

    public var allPacks: [SoundPack] { BuiltInSoundData.builtInPacks + customPacks }
    public var selectablePacks: [SoundPack] { BuiltInSoundData.builtInPacks + customPacks.filter { $0.sourceSoundId == nil } }
    public var favoritePacks: [SoundPack] { allPacks.filter { favoritePackIDs.contains($0.id) } }
    public var customSounds: [SoundItem] { soundLibrary.filter { !$0.isBuiltIn }.sorted { $0.displayName < $1.displayName } }
    public var selectedSoundPackName: String {
        get { activePack.sourceSoundId.flatMap(findSound(byId:))?.displayName ?? activePack.name }
        set {
            guard let pack = allPacks.first(where: { $0.name == newValue }) else { return }
            selectPack(id: pack.id)
        }
    }

    private enum Keys {
        static let soundEnabled = "isGlobalSoundEnabled"
        static let masterVolume = "masterVolume"
        static let appearance = "appearancePreference"
        static let legacySelectedPackName = "selectedSoundPackName"
    }

    private let catalogStore: CatalogStoring
    private let userDefaults: UserDefaults
    private let keyboardMonitor: KeyboardMonitoring
    private var playback: AudioPlaying?
    private var packMappings: [String: [UInt16: String]] = [:]
    private var permissionTimer: Timer?
    private var pauseTimer: Timer?
    private var isMonitoring = false
    private let logger = Logger(subsystem: "com.pannathorn.ThocKey", category: "AppModel")

    public init(
        catalogStore: CatalogStoring? = nil,
        playback: AudioPlaying? = nil,
        keyboardMonitor: KeyboardMonitoring? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        self.userDefaults = userDefaults
        self.isGlobalSoundEnabled = userDefaults.object(forKey: Keys.soundEnabled) as? Bool ?? true
        self.masterVolume = userDefaults.object(forKey: Keys.masterVolume) as? Double ?? 0.8
        self.appearancePreference = AppearancePreference(
            rawValue: userDefaults.string(forKey: Keys.appearance) ?? ""
        ) ?? .system
        self.selectedPackID = BuiltInSoundData.defaultPackID
        self.keyboardMonitor = keyboardMonitor ?? KeyboardMonitor()

        if let catalogStore {
            self.catalogStore = catalogStore
        } else if let store = try? LocalCatalogStore() {
            self.catalogStore = store
        } else {
            let fallback = FileManager.default.temporaryDirectory.appendingPathComponent("ThocKey-Recovery", isDirectory: true)
            self.catalogStore = try! LocalCatalogStore(rootURL: fallback)
        }

        if let playback { self.playback = playback } else { self.playback = try? AudioPlaybackEngine() }
        self.playback?.setVolume(masterVolume)

        loadCatalogAndMigrate()
        refreshAccessibilityStatus()
        preloadActivePack()
    }

    public func startKeyboardMonitoring(requestPermission: Bool = true) {
        guard !isMonitoring else { return }
        isMonitoring = true
        if requestPermission { keyboardMonitor.requestAccessibilityPermission() }
        keyboardMonitor.start(
            onKeyDown: { [weak self] keyCode in self?.playKeyEvent(type: .down, keyCode: keyCode) },
            onKeyUp: { [weak self] keyCode in self?.playKeyEvent(type: .up, keyCode: keyCode) },
            onToggleMute: { [weak self] in self?.isGlobalSoundEnabled.toggle() }
        )
        refreshAccessibilityStatus()
        guard permissionTimer == nil else { return }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshAccessibilityStatus() }
        }
    }

    public func stopKeyboardMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        permissionTimer?.invalidate()
        permissionTimer = nil
        pauseTimer?.invalidate()
        pauseTimer = nil
        keyboardMonitor.stop()
    }

    public func pauseSounds(for durationSeconds: Int = 900) {
        isPaused = true
        pauseRemainingSeconds = durationSeconds
        pauseTimer?.invalidate()
        pauseTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.pauseRemainingSeconds > 1 {
                    self.pauseRemainingSeconds -= 1
                } else {
                    self.resumeSounds()
                }
            }
        }
    }

    public func resumeSounds() {
        isPaused = false
        pauseRemainingSeconds = 0
        pauseTimer?.invalidate()
        pauseTimer = nil
    }

    public var pauseRemainingFormatted: String {
        let minutes = pauseRemainingSeconds / 60
        let seconds = pauseRemainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    public func isFavorite(packID: String) -> Bool {
        favoritePackIDs.contains(packID)
    }

    public func toggleFavorite(packID: String) {
        if favoritePackIDs.contains(packID) {
            favoritePackIDs.remove(packID)
        } else {
            favoritePackIDs.insert(packID)
        }
        do { try persistCatalog() }
        catch { present(error) }
    }

    public func refreshAccessibilityStatus() {
        let previouslyEnabled = isAccessibilityEnabled
        isAccessibilityEnabled = keyboardMonitor.isAccessibilityEnabled
        if !previouslyEnabled && isAccessibilityEnabled && isMonitoring {
            keyboardMonitor.stop()
            keyboardMonitor.start(
                onKeyDown: { [weak self] keyCode in self?.playKeyEvent(type: .down, keyCode: keyCode) },
                onKeyUp: { [weak self] keyCode in self?.playKeyEvent(type: .up, keyCode: keyCode) },
                onToggleMute: { [weak self] in self?.isGlobalSoundEnabled.toggle() }
            )
        }
    }

    public func selectPack(id: String) {
        guard allPacks.contains(where: { $0.id == id }) else { present(ThocKeyError.packNotFound); return }
        let previousID = selectedPackID
        selectedPackID = id
        updateActivePack()
        do {
            try persistCatalog()
        } catch {
            selectedPackID = previousID
            updateActivePack()
            present(error)
            return
        }
        preloadActivePack()
    }

    public func updateActivePack() {
        guard var pack = allPacks.first(where: { $0.id == selectedPackID }) else {
            selectedPackID = BuiltInSoundData.defaultPackID
            activePack = BuiltInSoundData.builtInPacks[0]
            return
        }
        pack.keyMappings = packMappings[pack.id] ?? pack.keyMappings
        if let sourceID = pack.sourceSoundId, let sound = findSound(byId: sourceID) {
            pack.name = sound.displayName
            pack.defaultSoundId = sound.id
        }
        activePack = pack
    }

    public func groupedSoundsByCategory() -> [(category: SoundCategory, sounds: [SoundItem])] {
        SoundCategory.allCases.compactMap { category in
            let sounds = soundLibrary.filter { $0.category == category }.sorted { $0.displayName < $1.displayName }
            return sounds.isEmpty ? nil : (category, sounds)
        }
    }

    public func findSound(byId id: String) -> SoundItem? {
        soundLibrary.first(where: { $0.id == id })
            ?? soundLibrary.first(where: {
                $0.pressFileName == id || $0.releaseFileName == id || $0.displayName == id
            })
    }

    public func findSoundURL(for sound: SoundItem, event: KeyEventType = .down) -> URL? {
        let fileName = sound.fileName(for: event)
        if sound.isBuiltIn {
            let baseName = (fileName as NSString).deletingPathExtension
            for ext in ["wav", "mp3", "aiff", "m4a"] {
                if let url = Bundle.main.url(forResource: baseName, withExtension: ext) { return url }
            }
        }
        let url = catalogStore.soundsDirectoryURL.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    public func getAppSupportURL() -> URL? { catalogStore.rootURL }
    public func getSoundsDirectory() -> URL? { catalogStore.soundsDirectoryURL }

    public func importSound(from sourceURL: URL, displayName: String? = nil) throws -> SoundItem {
        let imported = try copyAudioToLibrary(from: sourceURL)
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let item = SoundItem(
            displayName: normalizedName(displayName ?? baseName),
            pressFileName: imported.fileName,
            pressDuration: imported.duration
        )
        soundLibrary.append(item)
        do { try persistCatalog() } catch {
            soundLibrary.removeAll { $0.id == item.id }
            try? FileManager.default.removeItem(at: catalogStore.soundsDirectoryURL.appendingPathComponent(imported.fileName))
            throw error
        }
        preload(sound: item, event: .down)
        return item
    }

    public func renameSound(id: String, newDisplayName: String) throws {
        guard !newDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ThocKeyError.invalidName }
        guard let index = soundLibrary.firstIndex(where: { $0.id == id }) else { throw ThocKeyError.soundNotFound }
        guard !soundLibrary[index].isBuiltIn else { throw ThocKeyError.builtInContentIsReadOnly }
        let oldSounds = soundLibrary
        let oldPacks = customPacks
        let name = normalizedName(newDisplayName)
        soundLibrary[index].displayName = name
        for packIndex in customPacks.indices where customPacks[packIndex].sourceSoundId == id {
            customPacks[packIndex].name = name
        }
        updateActivePack()
        do { try persistCatalog() } catch {
            soundLibrary = oldSounds
            customPacks = oldPacks
            updateActivePack()
            throw error
        }
    }

    public func deleteSound(id: String) throws {
        guard let index = soundLibrary.firstIndex(where: { $0.id == id }) else { throw ThocKeyError.soundNotFound }
        let sound = soundLibrary[index]
        guard !sound.isBuiltIn else { throw ThocKeyError.builtInContentIsReadOnly }

        let oldSounds = soundLibrary
        let oldPacks = customPacks
        let oldMappings = packMappings
        let oldSelectedID = selectedPackID

        let generatedIDs = Set(customPacks.filter { $0.sourceSoundId == id }.map(\.id))
        customPacks.removeAll { generatedIDs.contains($0.id) }
        generatedIDs.forEach { packMappings.removeValue(forKey: $0) }

        for packIndex in customPacks.indices where customPacks[packIndex].defaultSoundId == id {
            customPacks[packIndex].defaultSoundId = BuiltInSoundData.builtInSounds[0].id
        }

        for packID in packMappings.keys {
            packMappings[packID] = packMappings[packID]?.filter { $0.value != id }
        }
        for packIndex in customPacks.indices {
            customPacks[packIndex].keyMappings = customPacks[packIndex].keyMappings.filter { $0.value != id }
        }

        if generatedIDs.contains(selectedPackID) { selectedPackID = BuiltInSoundData.defaultPackID }
        soundLibrary.remove(at: index)
        updateActivePack()

        let remainingFiles = Set(soundLibrary.flatMap { [$0.pressFileName, $0.releaseFileName].compactMap { $0 } })
        let removableFiles = Set([sound.pressFileName, sound.releaseFileName].compactMap { $0 }).subtracting(remainingFiles)
        var staged: [(original: URL, staged: URL)] = []
        do {
            for fileName in removableFiles {
                let original = catalogStore.soundsDirectoryURL.appendingPathComponent(fileName)
                guard FileManager.default.fileExists(atPath: original.path) else { continue }
                let stagedURL = catalogStore.soundsDirectoryURL.appendingPathComponent(".deleting-\(UUID().uuidString)-\(fileName)")
                try FileManager.default.moveItem(at: original, to: stagedURL)
                staged.append((original, stagedURL))
            }
            try persistCatalog()
        } catch {
            soundLibrary = oldSounds
            customPacks = oldPacks
            packMappings = oldMappings
            selectedPackID = oldSelectedID
            updateActivePack()
            for file in staged { try? FileManager.default.moveItem(at: file.staged, to: file.original) }
            throw error
        }
        playback?.remove(soundID: playbackID(sound.id, .down))
        playback?.remove(soundID: playbackID(sound.id, .up))
        for file in staged {
            do { try FileManager.default.removeItem(at: file.staged) }
            catch { logger.error("Could not remove staged sound file: \(error.localizedDescription, privacy: .public)") }
        }
    }

    public func saveTrimmedSound(
        sourceSoundId: String, newDisplayName: String,
        startTime: Double, endTime: Double, gain: Float = 1, applyFade: Bool = true,
        replacingSoundId: String? = nil
    ) async throws -> SoundItem {
        guard endTime > startTime, startTime >= 0 else { throw ThocKeyError.invalidTrimRange }
        guard let source = findSound(byId: sourceSoundId),
              let sourceURL = findSoundURL(for: source) else { throw ThocKeyError.soundNotFound }
        let name = try validatedName(newDisplayName)
        let outputURL = makeOutputURL(name: name, suffix: "press")
        do {
            try AudioProcessingService.shared.trimAndExportAudio(
                sourceURL: sourceURL, startTime: startTime, endTime: endTime,
                gain: gain, applyMicroFade: applyFade, outputURL: outputURL
            )
            var item = SoundItem(
                displayName: name, pressFileName: outputURL.lastPathComponent,
                pressDuration: try validateAudio(at: outputURL),
                category: .customized
            )
            item = try storeProcessedSound(item, replacingSoundId: replacingSoundId)
            preload(sound: item, event: .down)
            return item
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            throw error
        }
    }

    public func saveSplitSound(
        sourceSoundId: String, displayName: String,
        pressStart: Double, pressEnd: Double, releaseStart: Double, releaseEnd: Double,
        gain: Float = 1, applyFade: Bool = true, replacingSoundId: String? = nil
    ) async throws -> SoundItem {
        guard pressEnd > pressStart, releaseEnd > releaseStart else { throw ThocKeyError.invalidTrimRange }
        guard let source = findSound(byId: sourceSoundId),
              let sourceURL = findSoundURL(for: source) else { throw ThocKeyError.soundNotFound }
        let name = try validatedName(displayName)
        let pressURL = makeOutputURL(name: name, suffix: "press")
        let releaseURL = makeOutputURL(name: name, suffix: "release")
        do {
            try AudioProcessingService.shared.trimAndExportAudio(
                sourceURL: sourceURL, startTime: pressStart, endTime: pressEnd,
                gain: gain, applyMicroFade: applyFade, outputURL: pressURL
            )
            try AudioProcessingService.shared.trimAndExportAudio(
                sourceURL: sourceURL, startTime: releaseStart, endTime: releaseEnd,
                gain: gain, applyMicroFade: applyFade, outputURL: releaseURL
            )
            var item = SoundItem(
                displayName: name,
                pressFileName: pressURL.lastPathComponent,
                releaseFileName: releaseURL.lastPathComponent,
                pressDuration: try validateAudio(at: pressURL),
                releaseDuration: try validateAudio(at: releaseURL),
                category: .customized
            )
            item = try storeProcessedSound(item, replacingSoundId: replacingSoundId)
            preload(sound: item, event: .down)
            preload(sound: item, event: .up)
            return item
        } catch {
            try? FileManager.default.removeItem(at: pressURL)
            try? FileManager.default.removeItem(at: releaseURL)
            throw error
        }
    }

    public func attachReleaseAudio(to soundID: String, from sourceURL: URL) throws -> SoundItem {
        guard let index = soundLibrary.firstIndex(where: { $0.id == soundID }) else { throw ThocKeyError.soundNotFound }
        guard !soundLibrary[index].isBuiltIn else { throw ThocKeyError.builtInContentIsReadOnly }
        let imported = try copyAudioToLibrary(from: sourceURL)
        let previous = soundLibrary[index]
        soundLibrary[index].releaseFileName = imported.fileName
        soundLibrary[index].releaseDuration = imported.duration
        do { try persistCatalog() } catch {
            soundLibrary[index] = previous
            try? FileManager.default.removeItem(at: catalogStore.soundsDirectoryURL.appendingPathComponent(imported.fileName))
            throw error
        }
        let updated = soundLibrary[index]
        preload(sound: updated, event: .up)
        return updated
    }

    public func cleanupUnreferencedAudioFiles() {
        let referenced = Set(soundLibrary.flatMap { [$0.pressFileName, $0.releaseFileName].compactMap { $0 } })
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: catalogStore.soundsDirectoryURL, includingPropertiesForKeys: nil
        ) else { return }
        for url in files where !url.lastPathComponent.hasPrefix(".") && !referenced.contains(url.lastPathComponent) {
            do { try FileManager.default.removeItem(at: url) }
            catch { logger.error("Could not remove unused sound file: \(error.localizedDescription, privacy: .public)") }
        }
    }

    public func saveCustomPack(_ pack: SoundPack) throws {
        guard !pack.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ThocKeyError.invalidName }
        guard findSound(byId: pack.defaultSoundId) != nil else { throw ThocKeyError.soundNotFound }
        var savedPack = pack
        savedPack.name = normalizedName(pack.name)
        savedPack.isBuiltIn = false
        let previousPacks = customPacks
        let previousMappings = packMappings
        packMappings[savedPack.id] = savedPack.keyMappings
        if let index = customPacks.firstIndex(where: { $0.id == savedPack.id }) { customPacks[index] = savedPack }
        else { customPacks.append(savedPack) }
        do { try persistCatalog() } catch {
            customPacks = previousPacks
            packMappings = previousMappings
            throw error
        }
        if selectedPackID == savedPack.id { updateActivePack() }
    }

    @discardableResult
    public func setActiveSound(sound: SoundItem) throws -> String {
        if let matching = BuiltInSoundData.builtInPacks.first(where: { $0.defaultSoundId == sound.id }) {
            selectPack(id: matching.id)
            return matching.name
        }
        if let existing = customPacks.first(where: { $0.sourceSoundId == sound.id }) {
            selectPack(id: existing.id)
            return sound.displayName
        }
        let pack = SoundPack(
            name: sound.displayName, defaultSoundId: sound.id, sourceSoundId: sound.id
        )
        try saveCustomPack(pack)
        selectPack(id: pack.id)
        return sound.displayName
    }

    public func deleteCustomPack(id: String) throws {
        guard let index = customPacks.firstIndex(where: { $0.id == id }) else { throw ThocKeyError.packNotFound }
        let removed = customPacks.remove(at: index)
        let removedMappings = packMappings.removeValue(forKey: id)
        let previousSelectedID = selectedPackID
        if selectedPackID == id { selectedPackID = BuiltInSoundData.defaultPackID; updateActivePack() }
        do { try persistCatalog() } catch {
            customPacks.insert(removed, at: index)
            if let removedMappings { packMappings[id] = removedMappings }
            selectedPackID = previousSelectedID
            updateActivePack()
            throw error
        }
    }

    public func deleteCustomPack(named name: String) {
        guard let pack = customPacks.first(where: { $0.name == name && $0.sourceSoundId == nil }) else { return }
        do { try deleteCustomPack(id: pack.id) } catch { present(error) }
    }

    public func setMapping(for keyCode: UInt16, soundId: String?) {
        let previousMappings = packMappings
        let previousPacks = customPacks
        var mappings = packMappings[activePack.id] ?? activePack.keyMappings
        if let soundId, soundId != "None" { mappings[keyCode] = soundId } else { mappings.removeValue(forKey: keyCode) }
        packMappings[activePack.id] = mappings
        if let index = customPacks.firstIndex(where: { $0.id == activePack.id }) { customPacks[index].keyMappings = mappings }
        updateActivePack()
        do { try persistCatalog() } catch {
            packMappings = previousMappings
            customPacks = previousPacks
            updateActivePack()
            present(error)
        }
    }

    public func resetMappings() {
        let previousMappings = packMappings
        let previousPacks = customPacks
        packMappings[activePack.id] = [:]
        if let index = customPacks.firstIndex(where: { $0.id == activePack.id }) { customPacks[index].keyMappings = [:] }
        updateActivePack()
        do { try persistCatalog() } catch {
            packMappings = previousMappings
            customPacks = previousPacks
            updateActivePack()
            present(error)
        }
    }

    public func playPreview(soundId: String, event: KeyEventType = .down) {
        guard let sound = findSound(byId: soundId), let url = findSoundURL(for: sound, event: event) else { return }
        do { try playback?.play(soundID: playbackID(sound.id, event), from: url) }
        catch { logger.error("Preview failed: \(error.localizedDescription, privacy: .public)") }
    }

    public func playKeyEvent(type: KeyEventType, keyCode: UInt16? = nil, force: Bool = false) {
        guard (isGlobalSoundEnabled && !isPaused) || force else { return }
        let soundID: String = {
            guard let keyCode else { return activePack.defaultSoundId }
            if let mapped = activePack.keyMappings[keyCode] { return mapped }
            switch keyCode {
            case 54: return activePack.keyMappings[55] ?? activePack.defaultSoundId
            case 55: return activePack.keyMappings[54] ?? activePack.defaultSoundId
            case 60: return activePack.keyMappings[56] ?? activePack.defaultSoundId
            case 56: return activePack.keyMappings[60] ?? activePack.defaultSoundId
            case 61: return activePack.keyMappings[58] ?? activePack.defaultSoundId
            case 58: return activePack.keyMappings[61] ?? activePack.defaultSoundId
            case 62: return activePack.keyMappings[59] ?? activePack.defaultSoundId
            case 59: return activePack.keyMappings[62] ?? activePack.defaultSoundId
            default: return activePack.defaultSoundId
            }
        }()
        guard let sound = findSound(byId: soundID), let url = findSoundURL(for: sound, event: type) else { return }
        do { try playback?.play(soundID: playbackID(sound.id, type), from: url) }
        catch { logger.error("Keystroke playback failed: \(error.localizedDescription, privacy: .public)") }
    }

    public func present(_ error: Error) {
        presentedError = error as? ThocKeyError ?? .operationFailed(error.localizedDescription)
    }

    private func loadCatalogAndMigrate() {
        do {
            if let loaded = try catalogStore.loadCatalog() {
                let catalog = loaded.schemaVersion < CatalogManifest.currentSchemaVersion ? migrateV1Catalog(loaded) : loaded
                apply(catalog)
                if loaded.schemaVersion < CatalogManifest.currentSchemaVersion { try persistCatalog() }
            } else {
                let legacy = try catalogStore.loadLegacyCatalog()
                let catalog = migrateV1Catalog(CatalogManifest(
                    schemaVersion: 1, sounds: legacy.sounds, packs: legacy.packs,
                    selectedPackID: BuiltInSoundData.defaultPackID
                ))
                apply(catalog)
                migrateLegacyDefaults()
                reconcileLooseAudioFiles()
                try persistCatalog()
            }
            updateActivePack()
        } catch {
            logger.error("Catalog startup failed: \(error.localizedDescription, privacy: .public)")
            presentedError = error as? ThocKeyError ?? .operationFailed(error.localizedDescription)
            soundLibrary = BuiltInSoundData.builtInSounds
            customPacks = []
            selectedPackID = BuiltInSoundData.defaultPackID
            updateActivePack()
        }
    }

    private func apply(_ catalog: CatalogManifest) {
        var loadedSounds = catalog.sounds.filter { !$0.isBuiltIn && soundFileExists($0) }
        for index in loadedSounds.indices {
            if loadedSounds[index].displayName == "Fah Meme (Custom) (Custom)" || loadedSounds[index].displayName == "Fah" {
                loadedSounds[index].displayName = "Fah (Meme)"
            }
        }
        var loadedPacks = catalog.packs.filter { !$0.isBuiltIn }
        for index in loadedPacks.indices {
            if loadedPacks[index].name == "Fah Meme (Custom) (Custom)" || loadedPacks[index].name == "Fah" {
                loadedPacks[index].name = "Fah (Meme)"
            }
        }
        soundLibrary = BuiltInSoundData.builtInSounds + loadedSounds
        customPacks = loadedPacks
        packMappings = catalog.packMappings.mapValues { mapping in
            mapping.mapValues(BuiltInSoundData.unifiedID(forLegacyID:))
        }
        selectedPackID = allPacks.contains(where: { $0.id == catalog.selectedPackID })
            ? catalog.selectedPackID : BuiltInSoundData.defaultPackID
        favoritePackIDs = catalog.favoritePackIDs
    }

    private func migrateV1Catalog(_ catalog: CatalogManifest) -> CatalogManifest {
        let legacySounds = catalog.sounds.filter { !$0.isBuiltIn }
        let byID = Dictionary(uniqueKeysWithValues: legacySounds.map { ($0.id, $0) })
        var migratedPacks: [SoundPack] = []
        var combinedSounds: [SoundItem] = []
        var combinedIDsByPair: [String: String] = [:]
        var consumedIDs = Set<String>()
        var independentlyReferencedIDs = Set(catalog.packMappings.values.flatMap(\.values))

        for var pack in catalog.packs where !pack.isBuiltIn {
            let rawPressID = pack.defaultSoundId
            let rawReleaseID = pack.legacyDefaultUpSoundId ?? rawPressID
            let pressID = BuiltInSoundData.unifiedID(forLegacyID: rawPressID)
            let releaseID = BuiltInSoundData.unifiedID(forLegacyID: rawReleaseID)

            if pressID == releaseID {
                pack.defaultSoundId = pressID
                independentlyReferencedIDs.insert(rawPressID)
            } else if let press = byID[rawPressID], let release = byID[rawReleaseID] {
                let pairKey = "\(rawPressID)|\(rawReleaseID)"
                let combinedID: String
                if let existing = combinedIDsByPair[pairKey] {
                    combinedID = existing
                } else {
                    combinedID = UUID().uuidString
                    combinedIDsByPair[pairKey] = combinedID
                    combinedSounds.append(SoundItem(
                        id: combinedID,
                        displayName: legacyPairName(press: press, release: release, fallback: pack.name),
                        pressFileName: press.pressFileName,
                        releaseFileName: release.pressFileName,
                        pressDuration: press.pressDuration,
                        releaseDuration: release.pressDuration
                    ))
                }
                pack.defaultSoundId = combinedID
                consumedIDs.formUnion([rawPressID, rawReleaseID])
            } else {
                pack.defaultSoundId = pressID
                independentlyReferencedIDs.insert(rawPressID)
            }
            pack.keyMappings = pack.keyMappings.mapValues(BuiltInSoundData.unifiedID(forLegacyID:))
            pack.legacyDefaultUpSoundId = nil
            migratedPacks.append(pack)
        }

        let preservedSounds = legacySounds.filter {
            !consumedIDs.contains($0.id) || independentlyReferencedIDs.contains($0.id)
        }
        let mappings = catalog.packMappings.mapValues { mapping in
            mapping.mapValues(BuiltInSoundData.unifiedID(forLegacyID:))
        }
        return CatalogManifest(
            sounds: preservedSounds + combinedSounds,
            packs: migratedPacks,
            selectedPackID: catalog.selectedPackID,
            packMappings: mappings
        )
    }

    private func legacyPairName(press: SoundItem, release: SoundItem, fallback: String) -> String {
        let pattern = #"\s*\((Down|Up)\)$"#
        let pressBase = press.displayName.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        let releaseBase = release.displayName.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        if !pressBase.isEmpty, pressBase.caseInsensitiveCompare(releaseBase) == .orderedSame { return pressBase }
        return normalizedName(fallback.replacingOccurrences(of: " Pack", with: ""))
    }

    private func migrateLegacyDefaults() {
        let selectedName = userDefaults.string(forKey: Keys.legacySelectedPackName) ?? BuiltInSoundData.builtInPacks[0].name
        selectedPackID = allPacks.first(where: { $0.name == selectedName })?.id ?? BuiltInSoundData.defaultPackID
        for pack in allPacks {
            if let data = userDefaults.data(forKey: "customMappings_\(pack.name)"),
               let mappings = try? JSONDecoder().decode([UInt16: String].self, from: data) {
                packMappings[pack.id] = mappings.mapValues(BuiltInSoundData.unifiedID(forLegacyID:))
            } else if !pack.keyMappings.isEmpty {
                packMappings[pack.id] = pack.keyMappings
            }
        }
    }

    private func reconcileLooseAudioFiles() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: catalogStore.soundsDirectoryURL, includingPropertiesForKeys: nil
        ) else { return }
        let referencedFiles = Set(soundLibrary.flatMap { [$0.pressFileName, $0.releaseFileName].compactMap { $0 } })
        for file in files where ["wav", "mp3", "aiff", "aif", "m4a"].contains(file.pathExtension.lowercased()) {
            guard !referencedFiles.contains(file.lastPathComponent), let duration = try? validateAudio(at: file) else { continue }
            soundLibrary.append(SoundItem(
                displayName: normalizedName(file.deletingPathExtension().lastPathComponent),
                pressFileName: file.lastPathComponent,
                pressDuration: duration
            ))
        }
    }

    private func persistCatalog() throws {
        try catalogStore.saveCatalog(CatalogManifest(
            sounds: soundLibrary.filter { !$0.isBuiltIn }, packs: customPacks,
            selectedPackID: selectedPackID, packMappings: packMappings,
            favoritePackIDs: favoritePackIDs
        ))
    }

    private func storeProcessedSound(_ newSound: SoundItem, replacingSoundId: String?) throws -> SoundItem {
        guard let replacingSoundId,
              let index = soundLibrary.firstIndex(where: { $0.id == replacingSoundId }),
              !soundLibrary[index].isBuiltIn else {
            soundLibrary.append(newSound)
            do { try persistCatalog() } catch {
                soundLibrary.removeAll { $0.id == newSound.id }
                throw error
            }
            return newSound
        }

        let previousSound = soundLibrary[index]
        let previousPacks = customPacks
        var replacement = newSound
        replacement.id = previousSound.id
        soundLibrary[index] = replacement
        for packIndex in customPacks.indices where customPacks[packIndex].sourceSoundId == replacement.id {
            customPacks[packIndex].name = replacement.displayName
        }
        updateActivePack()
        do { try persistCatalog() } catch {
            soundLibrary[index] = previousSound
            customPacks = previousPacks
            updateActivePack()
            throw error
        }
        return replacement
    }

    private func preloadActivePack() {
        let ids = Set([activePack.defaultSoundId] + Array(activePack.keyMappings.values))
        for id in ids {
            guard let sound = findSound(byId: id) else { continue }
            preload(sound: sound, event: .down)
            preload(sound: sound, event: .up)
        }
    }

    private func preload(sound: SoundItem, event: KeyEventType) {
        guard let url = findSoundURL(for: sound, event: event) else { return }
        do { try playback?.preload(soundID: playbackID(sound.id, event), from: url) }
        catch { logger.error("Preload failed: \(error.localizedDescription, privacy: .public)") }
    }

    private func playbackID(_ soundID: String, _ event: KeyEventType) -> String {
        "\(soundID):\(event == .down ? "press" : "release")"
    }

    private func copyAudioToLibrary(from sourceURL: URL) throws -> (fileName: String, duration: Double) {
        let allowedExtensions = ["wav", "mp3", "aiff", "aif", "m4a"]
        let fileExtension = sourceURL.pathExtension.lowercased()
        guard allowedExtensions.contains(fileExtension) else { throw ThocKeyError.unsupportedAudioFormat }
        let values = try sourceURL.resourceValues(forKeys: [.fileSizeKey])
        guard (values.fileSize ?? 0) <= 50 * 1_024 * 1_024 else { throw ThocKeyError.audioFileTooLarge }
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let fileName = "\(safeFileName(baseName))_\(UUID().uuidString.prefix(8)).\(fileExtension)"
        let destinationURL = catalogStore.soundsDirectoryURL.appendingPathComponent(fileName)
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessed { sourceURL.stopAccessingSecurityScopedResource() } }
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return (fileName, try validateAudio(at: destinationURL))
        } catch {
            try? FileManager.default.removeItem(at: destinationURL)
            throw error
        }
    }

    private func validateAudio(at url: URL) throws -> Double {
        do {
            let file = try AVAudioFile(forReading: url)
            let sampleRate = file.processingFormat.sampleRate
            guard sampleRate > 0, file.length > 0 else { throw ThocKeyError.invalidAudio }
            let duration = Double(file.length) / sampleRate
            guard duration <= 60 else { throw ThocKeyError.audioTooLong }
            return duration
        } catch let error as ThocKeyError { throw error }
        catch { throw ThocKeyError.invalidAudio }
    }

    private func soundFileExists(_ sound: SoundItem) -> Bool {
        let pressExists = FileManager.default.fileExists(
            atPath: catalogStore.soundsDirectoryURL.appendingPathComponent(sound.pressFileName).path
        )
        guard pressExists else { return false }
        guard let releaseFileName = sound.releaseFileName else { return true }
        return FileManager.default.fileExists(
            atPath: catalogStore.soundsDirectoryURL.appendingPathComponent(releaseFileName).path
        )
    }

    private func validatedName(_ value: String) throws -> String {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ThocKeyError.invalidName }
        return normalizedName(value)
    }

    private func normalizedName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Sound" : trimmed
    }

    private func makeOutputURL(name: String, suffix: String) -> URL {
        catalogStore.soundsDirectoryURL.appendingPathComponent(
            "\(safeFileName(name))_\(suffix)_\(UUID().uuidString.prefix(8)).wav"
        )
    }

    private func safeFileName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let mapped = value.lowercased().unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "_" }
        return String(mapped).replacingOccurrences(of: "__", with: "_")
    }
}
