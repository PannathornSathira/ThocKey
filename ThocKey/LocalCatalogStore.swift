import Foundation
import OSLog

public enum ThocKeyError: LocalizedError, Equatable {
    case storageUnavailable
    case catalogCorrupted
    case unsupportedCatalogVersion(Int)
    case invalidName
    case soundNotFound
    case packNotFound
    case builtInContentIsReadOnly
    case soundInUse([String])
    case unsupportedAudioFormat
    case audioFileTooLarge
    case audioTooLong
    case invalidAudio
    case invalidTrimRange
    case operationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .storageUnavailable:
            return "ThocKey could not access its local storage folder."
        case .catalogCorrupted:
            return "The sound catalog is damaged and could not be recovered."
        case .unsupportedCatalogVersion(let version):
            return "This catalog was created by a newer ThocKey version (schema \(version))."
        case .invalidName:
            return "Enter a non-empty name."
        case .soundNotFound:
            return "The selected sound could not be found."
        case .packNotFound:
            return "The selected sound pack could not be found."
        case .builtInContentIsReadOnly:
            return "Built-in sounds and packs cannot be changed or deleted."
        case .soundInUse(let packs):
            return "This sound is used by: \(packs.joined(separator: ", ")). Change those packs before deleting it."
        case .unsupportedAudioFormat:
            return "Choose a WAV, MP3, AIFF, or M4A audio file."
        case .audioFileTooLarge:
            return "Audio files must be 50 MB or smaller."
        case .audioTooLong:
            return "Audio files must be 60 seconds or shorter."
        case .invalidAudio:
            return "The selected file is not readable audio."
        case .invalidTrimRange:
            return "The selected audio region is invalid."
        case .operationFailed(let message):
            return message
        }
    }
}

public protocol CatalogStoring {
    var rootURL: URL { get }
    var soundsDirectoryURL: URL { get }
    func loadCatalog() throws -> CatalogManifest?
    func saveCatalog(_ catalog: CatalogManifest) throws
    func loadLegacyCatalog() throws -> (sounds: [SoundItem], packs: [SoundPack])
}

public final class LocalCatalogStore: CatalogStoring {
    public let rootURL: URL
    public let soundsDirectoryURL: URL

    private let fileManager: FileManager
    private let logger = Logger(subsystem: "com.pannathorn.ThocKey", category: "Catalog")
    private var catalogURL: URL { rootURL.appendingPathComponent("catalog.json") }
    private var backupURL: URL { rootURL.appendingPathComponent("catalog.backup.json") }
    private var legacySoundsURL: URL { rootURL.appendingPathComponent("soundsMetadata.json") }
    private var legacyPacksURL: URL { rootURL.appendingPathComponent("customPacks.json") }

    public convenience init(fileManager: FileManager = .default) throws {
        guard let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw ThocKeyError.storageUnavailable
        }
        try self.init(rootURL: applicationSupport.appendingPathComponent("ThocKey", isDirectory: true), fileManager: fileManager)
    }

    public init(rootURL: URL, fileManager: FileManager = .default) throws {
        self.rootURL = rootURL
        self.soundsDirectoryURL = rootURL.appendingPathComponent("Sounds", isDirectory: true)
        self.fileManager = fileManager
        do {
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: soundsDirectoryURL, withIntermediateDirectories: true)
        } catch {
            throw ThocKeyError.operationFailed("ThocKey could not create its storage folders: \(error.localizedDescription)")
        }
    }

    public func loadCatalog() throws -> CatalogManifest? {
        guard fileManager.fileExists(atPath: catalogURL.path) else { return nil }

        do {
            return try decodeCatalog(at: catalogURL)
        } catch {
            logger.error("Catalog decode failed; trying backup: \(error.localizedDescription, privacy: .public)")
            guard fileManager.fileExists(atPath: backupURL.path) else {
                throw ThocKeyError.catalogCorrupted
            }
            do { return try decodeCatalog(at: backupURL) }
            catch let error as ThocKeyError { throw error }
            catch { throw ThocKeyError.catalogCorrupted }
        }
    }

    public func saveCatalog(_ catalog: CatalogManifest) throws {
        guard catalog.schemaVersion <= CatalogManifest.currentSchemaVersion else {
            throw ThocKeyError.unsupportedCatalogVersion(catalog.schemaVersion)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(catalog)

        do {
            if fileManager.fileExists(atPath: catalogURL.path) {
                if fileManager.fileExists(atPath: backupURL.path) {
                    try fileManager.removeItem(at: backupURL)
                }
                try fileManager.copyItem(at: catalogURL, to: backupURL)
            }
            try data.write(to: catalogURL, options: [.atomic])
        } catch {
            throw ThocKeyError.operationFailed("ThocKey could not save the sound catalog: \(error.localizedDescription)")
        }
    }

    public func loadLegacyCatalog() throws -> (sounds: [SoundItem], packs: [SoundPack]) {
        let decoder = JSONDecoder()
        var sounds: [SoundItem] = []
        var packs: [SoundPack] = []

        if fileManager.fileExists(atPath: legacySoundsURL.path) {
            sounds = try decoder.decode([SoundItem].self, from: Data(contentsOf: legacySoundsURL))
        }
        if fileManager.fileExists(atPath: legacyPacksURL.path) {
            packs = try decoder.decode([SoundPack].self, from: Data(contentsOf: legacyPacksURL))
        }
        return (sounds, packs)
    }

    private func decodeCatalog(at url: URL) throws -> CatalogManifest {
        let catalog = try JSONDecoder().decode(CatalogManifest.self, from: Data(contentsOf: url))
        guard catalog.schemaVersion <= CatalogManifest.currentSchemaVersion else {
            throw ThocKeyError.unsupportedCatalogVersion(catalog.schemaVersion)
        }
        return catalog
    }
}
