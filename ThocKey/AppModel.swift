import AppKit
import AVFoundation
import Foundation
import OSLog

public enum KeyEventType {
    case down
    case up
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
        didSet { userDefaults.set(isGlobalSoundEnabled, forKey: Keys.soundEnabled) }
    }
    @Published public var masterVolume: Double {
        didSet {
            let clamped = max(0, min(1, masterVolume))
            if clamped != masterVolume { masterVolume = clamped; return }
            userDefaults.set(masterVolume, forKey: Keys.masterVolume)
            playback?.setVolume(masterVolume)
        }
    }
    @Published public private(set) var selectedPackID: String
    @Published public private(set) var activePack: SoundPack = BuiltInSoundData.builtInPacks[0]
    @Published public private(set) var customPacks: [SoundPack] = []
    @Published public private(set) var soundLibrary: [SoundItem] = BuiltInSoundData.builtInSounds
    @Published public private(set) var isAccessibilityEnabled = false
    @Published public var presentedError: ThocKeyError?

    public var allPacks: [SoundPack] { BuiltInSoundData.builtInPacks + customPacks }
    public var selectedSoundPackName: String {
        get { activePack.name }
        set {
            guard let pack = allPacks.first(where: { $0.name == newValue }) else { return }
            selectPack(id: pack.id)
        }
    }

    private enum Keys {
        static let soundEnabled = "isGlobalSoundEnabled"
        static let masterVolume = "masterVolume"
        static let legacySelectedPackName = "selectedSoundPackName"
    }

    private let catalogStore: CatalogStoring
    private let userDefaults: UserDefaults
    private let keyboardMonitor: KeyboardMonitoring
    private var playback: AudioPlaying?
    private var packMappings: [String: [UInt16: String]] = [:]
    private var permissionTimer: Timer?
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
        keyboardMonitor.stop()
    }

    public func refreshAccessibilityStatus() {
        isAccessibilityEnabled = keyboardMonitor.isAccessibilityEnabled
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
        activePack = pack
    }

    public func groupedSoundsByPack() -> [(packName: String, sounds: [SoundItem])] {
        let grouped = Dictionary(grouping: soundLibrary, by: \SoundItem.packName)
        let preferredOrder = ["Thocky", "Creamy", "Clicky", "Quiet", "Custom", "Customized"]
        var result = preferredOrder.compactMap { name -> (String, [SoundItem])? in
            guard let sounds = grouped[name], !sounds.isEmpty else { return nil }
            return (name, sounds.sorted { $0.displayName < $1.displayName })
        }
        result.append(contentsOf: grouped
            .filter { !preferredOrder.contains($0.key) }
            .sorted { $0.key < $1.key }
            .map { ($0.key, $0.value.sorted { $0.displayName < $1.displayName }) })
        return result
    }

    public func findSound(byId id: String) -> SoundItem? {
        soundLibrary.first(where: { $0.id == id })
            ?? soundLibrary.first(where: { $0.fileName == id || $0.displayName == id })
    }

    public func findSoundURL(for sound: SoundItem) -> URL? {
        if sound.isBuiltIn {
            let baseName = (sound.fileName as NSString).deletingPathExtension
            for ext in ["wav", "mp3", "aiff", "m4a"] {
                if let url = Bundle.main.url(forResource: baseName, withExtension: ext) { return url }
            }
        }
        let url = catalogStore.soundsDirectoryURL.appendingPathComponent(sound.fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    public func getAppSupportURL() -> URL? { catalogStore.rootURL }
    public func getSoundsDirectory() -> URL? { catalogStore.soundsDirectoryURL }

    public func importSound(from sourceURL: URL, displayName: String? = nil) throws -> SoundItem {
        let allowedExtensions = ["wav", "mp3", "aiff", "aif", "m4a"]
        let fileExtension = sourceURL.pathExtension.lowercased()
        guard allowedExtensions.contains(fileExtension) else { throw ThocKeyError.unsupportedAudioFormat }
        let values = try sourceURL.resourceValues(forKeys: [.fileSizeKey])
        guard (values.fileSize ?? 0) <= 50 * 1_024 * 1_024 else { throw ThocKeyError.audioFileTooLarge }

        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let uniqueFileName = "\(safeFileName(baseName))_\(UUID().uuidString.prefix(8)).\(fileExtension)"
        let destinationURL = catalogStore.soundsDirectoryURL.appendingPathComponent(uniqueFileName)
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessed { sourceURL.stopAccessingSecurityScopedResource() } }

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            let duration = try validateAudio(at: destinationURL)
            let item = SoundItem(
                displayName: normalizedName(displayName ?? baseName), fileName: uniqueFileName,
                packName: "Custom", category: .custom, duration: duration, isBuiltIn: false
            )
            soundLibrary.append(item)
            do { try persistCatalog() } catch {
                soundLibrary.removeAll { $0.id == item.id }
                try? FileManager.default.removeItem(at: destinationURL)
                throw error
            }
            do { try playback?.preload(soundID: item.id, from: destinationURL) }
            catch { logger.error("Imported sound preload failed: \(error.localizedDescription, privacy: .public)") }
            return item
        } catch {
            try? FileManager.default.removeItem(at: destinationURL)
            throw error
        }
    }

    public func renameSound(id: String, newDisplayName: String) throws {
        guard !newDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ThocKeyError.invalidName }
        let name = normalizedName(newDisplayName)
        guard let index = soundLibrary.firstIndex(where: { $0.id == id }) else { throw ThocKeyError.soundNotFound }
        guard !soundLibrary[index].isBuiltIn else { throw ThocKeyError.builtInContentIsReadOnly }
        let previous = soundLibrary[index].displayName
        soundLibrary[index].displayName = name
        do { try persistCatalog() } catch { soundLibrary[index].displayName = previous; throw error }
    }

    public func deleteSound(id: String) throws {
        guard let index = soundLibrary.firstIndex(where: { $0.id == id }) else { throw ThocKeyError.soundNotFound }
        let sound = soundLibrary[index]
        guard !sound.isBuiltIn else { throw ThocKeyError.builtInContentIsReadOnly }
        let references = allPacks.filter { pack in
            pack.defaultDownSoundId == id || pack.defaultUpSoundId == id || (packMappings[pack.id] ?? pack.keyMappings).values.contains(id)
        }.map(\.name)
        guard references.isEmpty else { throw ThocKeyError.soundInUse(references) }

        let url = catalogStore.soundsDirectoryURL.appendingPathComponent(sound.fileName)
        let stagedURL = catalogStore.soundsDirectoryURL.appendingPathComponent(".deleting-\(UUID().uuidString)-\(sound.fileName)")
        let hasFile = FileManager.default.fileExists(atPath: url.path)
        do {
            if hasFile { try FileManager.default.moveItem(at: url, to: stagedURL) }
            soundLibrary.remove(at: index)
            try persistCatalog()
            playback?.remove(soundID: id)
        } catch {
            if !soundLibrary.contains(where: { $0.id == sound.id }) { soundLibrary.insert(sound, at: index) }
            if hasFile, FileManager.default.fileExists(atPath: stagedURL.path) {
                try? FileManager.default.moveItem(at: stagedURL, to: url)
            }
            throw error
        }
        if hasFile {
            do { try FileManager.default.removeItem(at: stagedURL) }
            catch { logger.error("Could not remove staged sound file: \(error.localizedDescription, privacy: .public)") }
        }
    }

    public func saveTrimmedSound(
        sourceSoundId: String, newDisplayName: String, packName: String = "Customized",
        startTime: Double, endTime: Double, gain: Float = 1, applyFade: Bool = true
    ) async throws -> SoundItem {
        guard endTime > startTime, startTime >= 0 else { throw ThocKeyError.invalidTrimRange }
        guard let source = findSound(byId: sourceSoundId), let sourceURL = findSoundURL(for: source) else { throw ThocKeyError.soundNotFound }
        guard !newDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ThocKeyError.invalidName }
        let name = normalizedName(newDisplayName)
        let outputURL = catalogStore.soundsDirectoryURL.appendingPathComponent("\(safeFileName(name))_\(UUID().uuidString.prefix(8)).wav")
        do {
            try AudioProcessingService.shared.trimAndExportAudio(
                sourceURL: sourceURL, startTime: startTime, endTime: endTime,
                gain: gain, applyMicroFade: applyFade, outputURL: outputURL
            )
            let duration = try validateAudio(at: outputURL)
            let item = SoundItem(displayName: name, fileName: outputURL.lastPathComponent, packName: packName, category: .trimmed, duration: duration)
            soundLibrary.append(item)
            do { try persistCatalog() } catch {
                soundLibrary.removeAll { $0.id == item.id }
                throw error
            }
            do { try playback?.preload(soundID: item.id, from: outputURL) }
            catch { logger.error("Trimmed sound preload failed: \(error.localizedDescription, privacy: .public)") }
            return item
        } catch { try? FileManager.default.removeItem(at: outputURL); throw error }
    }

    public func splitKeystrokeSound(
        sourceSoundId: String, downName: String, upName: String,
        downStart: Double, downEnd: Double, upStart: Double, upEnd: Double,
        gain: Float = 1, applyFade: Bool = true
    ) async throws -> (down: SoundItem, up: SoundItem) {
        let down = try await saveTrimmedSound(
            sourceSoundId: sourceSoundId, newDisplayName: downName,
            startTime: downStart, endTime: downEnd, gain: gain, applyFade: applyFade
        )
        do {
            let up = try await saveTrimmedSound(
                sourceSoundId: sourceSoundId, newDisplayName: upName,
                startTime: upStart, endTime: upEnd, gain: gain, applyFade: applyFade
            )
            return (down, up)
        } catch { try? deleteSound(id: down.id); throw error }
    }

    public func saveCustomPack(_ pack: SoundPack) throws {
        guard !pack.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ThocKeyError.invalidName }
        guard findSound(byId: pack.defaultDownSoundId) != nil, findSound(byId: pack.defaultUpSoundId) != nil else { throw ThocKeyError.soundNotFound }
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
        if sound.isBuiltIn,
           let matching = BuiltInSoundData.builtInPacks.first(where: { $0.defaultDownSoundId == sound.id || $0.name.localizedCaseInsensitiveContains(sound.packName) }) {
            selectPack(id: matching.id)
            return matching.name
        }
        if let existing = customPacks.first(where: { $0.defaultDownSoundId == sound.id && $0.defaultUpSoundId == sound.id }) {
            selectPack(id: existing.id)
            return existing.name
        }
        let pack = SoundPack(name: "\(sound.displayName) Pack", defaultDownSoundId: sound.id, defaultUpSoundId: sound.id)
        try saveCustomPack(pack)
        selectPack(id: pack.id)
        return pack.name
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
        guard let pack = customPacks.first(where: { $0.name == name }) else { return }
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

    public func playPreview(soundId: String) {
        guard let sound = findSound(byId: soundId), let url = findSoundURL(for: sound) else { return }
        do { try playback?.play(soundID: sound.id, from: url) }
        catch { logger.error("Preview failed: \(error.localizedDescription, privacy: .public)") }
    }

    public func playKeyEvent(type: KeyEventType, keyCode: UInt16? = nil, force: Bool = false) {
        guard isGlobalSoundEnabled || force else { return }
        var soundID = type == .down ? activePack.defaultDownSoundId : activePack.defaultUpSoundId
        if type == .down, let keyCode, let mapped = activePack.keyMappings[keyCode] { soundID = mapped }
        guard let sound = findSound(byId: soundID), let url = findSoundURL(for: sound) else { return }
        do { try playback?.play(soundID: sound.id, from: url) }
        catch { logger.error("Keystroke playback failed: \(error.localizedDescription, privacy: .public)") }
    }

    public func present(_ error: Error) {
        presentedError = error as? ThocKeyError ?? .operationFailed(error.localizedDescription)
    }

    private func loadCatalogAndMigrate() {
        do {
            if let catalog = try catalogStore.loadCatalog() {
                soundLibrary = BuiltInSoundData.builtInSounds + catalog.sounds.filter { !$0.isBuiltIn && soundFileExists($0) }
                customPacks = catalog.packs.filter { !$0.isBuiltIn }
                packMappings = catalog.packMappings
                selectedPackID = allPacks.contains(where: { $0.id == catalog.selectedPackID }) ? catalog.selectedPackID : BuiltInSoundData.defaultPackID
            } else {
                let legacy = try catalogStore.loadLegacyCatalog()
                soundLibrary = BuiltInSoundData.builtInSounds + legacy.sounds.filter { !$0.isBuiltIn && soundFileExists($0) }
                customPacks = legacy.packs.map { pack in
                    var migrated = pack
                    migrated.id = UUID().uuidString
                    migrated.isBuiltIn = false
                    return migrated
                }
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

    private func migrateLegacyDefaults() {
        let selectedName = userDefaults.string(forKey: Keys.legacySelectedPackName) ?? BuiltInSoundData.builtInPacks[0].name
        selectedPackID = allPacks.first(where: { $0.name == selectedName })?.id ?? BuiltInSoundData.defaultPackID
        for pack in allPacks {
            if let data = userDefaults.data(forKey: "customMappings_\(pack.name)"),
               let mappings = try? JSONDecoder().decode([UInt16: String].self, from: data) { packMappings[pack.id] = mappings }
            else if !pack.keyMappings.isEmpty { packMappings[pack.id] = pack.keyMappings }
        }
    }

    private func reconcileLooseAudioFiles() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: catalogStore.soundsDirectoryURL, includingPropertiesForKeys: nil) else { return }
        for file in files where ["wav", "mp3", "aiff", "aif", "m4a"].contains(file.pathExtension.lowercased()) {
            guard !soundLibrary.contains(where: { $0.fileName == file.lastPathComponent }), let duration = try? validateAudio(at: file) else { continue }
            soundLibrary.append(SoundItem(displayName: normalizedName(file.deletingPathExtension().lastPathComponent), fileName: file.lastPathComponent, duration: duration))
        }
    }

    private func persistCatalog() throws {
        try catalogStore.saveCatalog(CatalogManifest(
            sounds: soundLibrary.filter { !$0.isBuiltIn }, packs: customPacks,
            selectedPackID: selectedPackID, packMappings: packMappings
        ))
    }

    private func preloadActivePack() {
        let ids = Set([activePack.defaultDownSoundId, activePack.defaultUpSoundId] + Array(activePack.keyMappings.values))
        for id in ids {
            guard let sound = findSound(byId: id), let url = findSoundURL(for: sound) else { continue }
            do { try playback?.preload(soundID: id, from: url) }
            catch { logger.error("Preload failed: \(error.localizedDescription, privacy: .public)") }
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
        FileManager.default.fileExists(atPath: catalogStore.soundsDirectoryURL.appendingPathComponent(sound.fileName).path)
    }

    private func normalizedName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Sound" : trimmed
    }

    private func safeFileName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let mapped = value.lowercased().unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "_" }
        return String(mapped).replacingOccurrences(of: "__", with: "_")
    }
}
