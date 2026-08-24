import Foundation

public enum SoundCategory: String, Codable, CaseIterable, Identifiable {
    case builtIn = "Built-in"
    case custom = "Custom"

    public var id: String { rawValue }

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = value == "Built-in" ? .builtIn : .custom
    }
}

public struct SoundItem: Identifiable, Codable, Hashable {
    public var id: String
    public var displayName: String
    public var pressFileName: String
    public var releaseFileName: String?
    public var pressDuration: Double
    public var releaseDuration: Double?
    public var category: SoundCategory
    public var isBuiltIn: Bool

    public init(
        id: String = UUID().uuidString,
        displayName: String,
        pressFileName: String,
        releaseFileName: String? = nil,
        pressDuration: Double = 0,
        releaseDuration: Double? = nil,
        category: SoundCategory = .custom,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.pressFileName = pressFileName
        self.releaseFileName = releaseFileName
        self.pressDuration = pressDuration
        self.releaseDuration = releaseDuration
        self.category = category
        self.isBuiltIn = isBuiltIn
    }

    public func fileName(for event: KeyEventType) -> String {
        event == .up ? (releaseFileName ?? pressFileName) : pressFileName
    }

    public func duration(for event: KeyEventType) -> Double {
        event == .up ? (releaseDuration ?? pressDuration) : pressDuration
    }

    private enum CodingKeys: String, CodingKey {
        case id, displayName, pressFileName, releaseFileName, pressDuration, releaseDuration
        case category, isBuiltIn
        case fileName, duration
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        displayName = try container.decode(String.self, forKey: .displayName)
        pressFileName = try container.decodeIfPresent(String.self, forKey: .pressFileName)
            ?? container.decode(String.self, forKey: .fileName)
        releaseFileName = try container.decodeIfPresent(String.self, forKey: .releaseFileName)
        pressDuration = try container.decodeIfPresent(Double.self, forKey: .pressDuration)
            ?? container.decodeIfPresent(Double.self, forKey: .duration) ?? 0
        releaseDuration = try container.decodeIfPresent(Double.self, forKey: .releaseDuration)
        category = try container.decodeIfPresent(SoundCategory.self, forKey: .category) ?? .custom
        isBuiltIn = try container.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(pressFileName, forKey: .pressFileName)
        try container.encodeIfPresent(releaseFileName, forKey: .releaseFileName)
        try container.encode(pressDuration, forKey: .pressDuration)
        try container.encodeIfPresent(releaseDuration, forKey: .releaseDuration)
        try container.encode(category, forKey: .category)
        try container.encode(isBuiltIn, forKey: .isBuiltIn)
    }
}

public struct SoundPack: Identifiable, Codable, Hashable {
    public var id: String
    public var name: String
    public var defaultSoundId: String
    public var keyMappings: [UInt16: String]
    public var isBuiltIn: Bool
    public var sourceSoundId: String?

    var legacyDefaultUpSoundId: String?

    public init(
        id: String = UUID().uuidString,
        name: String,
        defaultSoundId: String,
        keyMappings: [UInt16: String] = [:],
        isBuiltIn: Bool = false,
        sourceSoundId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.defaultSoundId = defaultSoundId
        self.keyMappings = keyMappings
        self.isBuiltIn = isBuiltIn
        self.sourceSoundId = sourceSoundId
        self.legacyDefaultUpSoundId = nil
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, defaultSoundId, keyMappings, isBuiltIn, sourceSoundId
        case defaultDownSoundId, defaultUpSoundId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try container.decode(String.self, forKey: .name)
        if let currentID = try container.decodeIfPresent(String.self, forKey: .defaultSoundId) {
            defaultSoundId = currentID
            legacyDefaultUpSoundId = nil
        } else {
            defaultSoundId = try container.decode(String.self, forKey: .defaultDownSoundId)
            legacyDefaultUpSoundId = try container.decodeIfPresent(String.self, forKey: .defaultUpSoundId)
        }
        keyMappings = try container.decodeIfPresent([UInt16: String].self, forKey: .keyMappings) ?? [:]
        isBuiltIn = try container.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? false
        sourceSoundId = try container.decodeIfPresent(String.self, forKey: .sourceSoundId)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(defaultSoundId, forKey: .defaultSoundId)
        try container.encode(keyMappings, forKey: .keyMappings)
        try container.encode(isBuiltIn, forKey: .isBuiltIn)
        try container.encodeIfPresent(sourceSoundId, forKey: .sourceSoundId)
    }
}

public struct CatalogManifest: Codable, Equatable {
    public static let currentSchemaVersion = 2

    public var schemaVersion: Int
    public var sounds: [SoundItem]
    public var packs: [SoundPack]
    public var selectedPackID: String
    public var packMappings: [String: [UInt16: String]]

    public init(
        schemaVersion: Int = CatalogManifest.currentSchemaVersion,
        sounds: [SoundItem] = [],
        packs: [SoundPack] = [],
        selectedPackID: String = BuiltInSoundData.defaultPackID,
        packMappings: [String: [UInt16: String]] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.sounds = sounds
        self.packs = packs
        self.selectedPackID = selectedPackID
        self.packMappings = packMappings
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, sounds, packs, selectedPackID, packMappings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        sounds = try container.decodeIfPresent([SoundItem].self, forKey: .sounds) ?? []
        packs = try container.decodeIfPresent([SoundPack].self, forKey: .packs) ?? []
        selectedPackID = try container.decodeIfPresent(String.self, forKey: .selectedPackID) ?? BuiltInSoundData.defaultPackID
        packMappings = try container.decodeIfPresent([String: [UInt16: String]].self, forKey: .packMappings) ?? [:]
    }
}

public enum BuiltInSoundData {
    public static let defaultPackID = "00000000-0000-4000-8000-000000000001"

    public static let builtInSounds: [SoundItem] = [
        SoundItem(
            id: "builtin_thock", displayName: "Thocky (Original)",
            pressFileName: "thock_down", releaseFileName: "thock_up",
            pressDuration: 0.09, releaseDuration: 0.09,
            category: .builtIn, isBuiltIn: true
        ),
        SoundItem(
            id: "builtin_creamy", displayName: "Creamy", pressFileName: "creamy_key",
            pressDuration: 0.06, category: .builtIn, isBuiltIn: true
        ),
        SoundItem(
            id: "builtin_clicky", displayName: "Clicky", pressFileName: "clicky_key",
            pressDuration: 0.07, category: .builtIn, isBuiltIn: true
        ),
        SoundItem(
            id: "builtin_quiet", displayName: "Quiet", pressFileName: "quiet_key",
            pressDuration: 0.06, category: .builtIn, isBuiltIn: true
        )
    ]

    public static let builtInPacks: [SoundPack] = [
        SoundPack(
            id: defaultPackID, name: "Thocky (Default)", defaultSoundId: "builtin_thock",
            isBuiltIn: true
        ),
        SoundPack(
            id: "00000000-0000-4000-8000-000000000002", name: "Creamy",
            defaultSoundId: "builtin_creamy", isBuiltIn: true
        ),
        SoundPack(
            id: "00000000-0000-4000-8000-000000000003", name: "Clicky",
            defaultSoundId: "builtin_clicky", isBuiltIn: true
        ),
        SoundPack(
            id: "00000000-0000-4000-8000-000000000004", name: "Quiet",
            defaultSoundId: "builtin_quiet", isBuiltIn: true
        )
    ]

    public static func unifiedID(forLegacyID id: String) -> String {
        switch id {
        case "builtin_thock_down", "builtin_thock_up", "builtin_thock": "builtin_thock"
        case "builtin_creamy_down", "builtin_creamy_up", "builtin_creamy": "builtin_creamy"
        case "builtin_clicky_down", "builtin_clicky_up", "builtin_clicky": "builtin_clicky"
        case "builtin_quiet_down", "builtin_quiet_up", "builtin_quiet": "builtin_quiet"
        default: id
        }
    }
}
