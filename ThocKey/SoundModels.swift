import Foundation

public enum SoundCategory: String, Codable, CaseIterable, Identifiable {
    case builtIn = "Built-in"
    case custom = "Custom"
    case trimmed = "Customized"
    
    public var id: String { rawValue }
}

public struct SoundItem: Identifiable, Codable, Hashable {
    public var id: String
    public var displayName: String
    public var fileName: String
    public var packName: String
    public var category: SoundCategory
    public var duration: Double
    public var isBuiltIn: Bool
    
    public init(
        id: String = UUID().uuidString,
        displayName: String,
        fileName: String,
        packName: String = "Custom",
        category: SoundCategory = .custom,
        duration: Double = 0.0,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.fileName = fileName
        self.packName = packName
        self.category = category
        self.duration = duration
        self.isBuiltIn = isBuiltIn
    }
}

public struct SoundPack: Identifiable, Codable, Hashable {
    public var id: String
    public var name: String
    public var defaultDownSoundId: String
    public var defaultUpSoundId: String
    public var keyMappings: [UInt16: String] // keyCode -> soundId
    public var isBuiltIn: Bool
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        defaultDownSoundId: String,
        defaultUpSoundId: String,
        keyMappings: [UInt16: String] = [:],
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.defaultDownSoundId = defaultDownSoundId
        self.defaultUpSoundId = defaultUpSoundId
        self.keyMappings = keyMappings
        self.isBuiltIn = isBuiltIn
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, defaultDownSoundId, defaultUpSoundId, keyMappings, isBuiltIn
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try container.decode(String.self, forKey: .name)
        defaultDownSoundId = try container.decode(String.self, forKey: .defaultDownSoundId)
        defaultUpSoundId = try container.decode(String.self, forKey: .defaultUpSoundId)
        keyMappings = try container.decodeIfPresent([UInt16: String].self, forKey: .keyMappings) ?? [:]
        isBuiltIn = try container.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? false
    }
}

public struct CatalogManifest: Codable, Equatable {
    public static let currentSchemaVersion = 1

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

// Built-in Sound and Pack Constants
public enum BuiltInSoundData {
    public static let defaultPackID = "00000000-0000-4000-8000-000000000001"

    public static let builtInSounds: [SoundItem] = [
        SoundItem(
            id: "builtin_thock_down",
            displayName: "Thock (Down)",
            fileName: "thock_down",
            packName: "Thocky",
            category: .builtIn,
            duration: 0.09,
            isBuiltIn: true
        ),
        SoundItem(
            id: "builtin_thock_up",
            displayName: "Thock (Up)",
            fileName: "thock_up",
            packName: "Thocky",
            category: .builtIn,
            duration: 0.09,
            isBuiltIn: true
        ),
        SoundItem(
            id: "builtin_creamy_down",
            displayName: "Creamy (Down)",
            fileName: "creamy_key",
            packName: "Creamy",
            category: .builtIn,
            duration: 0.06,
            isBuiltIn: true
        ),
        SoundItem(
            id: "builtin_creamy_up",
            displayName: "Creamy (Up)",
            fileName: "creamy_key",
            packName: "Creamy",
            category: .builtIn,
            duration: 0.06,
            isBuiltIn: true
        ),
        SoundItem(
            id: "builtin_clicky_down",
            displayName: "Clicky (Down)",
            fileName: "clicky_key",
            packName: "Clicky",
            category: .builtIn,
            duration: 0.07,
            isBuiltIn: true
        ),
        SoundItem(
            id: "builtin_clicky_up",
            displayName: "Clicky (Up)",
            fileName: "clicky_key",
            packName: "Clicky",
            category: .builtIn,
            duration: 0.07,
            isBuiltIn: true
        ),
        SoundItem(
            id: "builtin_quiet_down",
            displayName: "Quiet (Down)",
            fileName: "quiet_key",
            packName: "Quiet",
            category: .builtIn,
            duration: 0.06,
            isBuiltIn: true
        ),
        SoundItem(
            id: "builtin_quiet_up",
            displayName: "Quiet (Up)",
            fileName: "quiet_key",
            packName: "Quiet",
            category: .builtIn,
            duration: 0.06,
            isBuiltIn: true
        )
    ]
    
    public static let builtInPacks: [SoundPack] = [
        SoundPack(
            id: defaultPackID,
            name: "Thocky (Default)",
            defaultDownSoundId: "builtin_thock_down",
            defaultUpSoundId: "builtin_thock_up",
            keyMappings: [:],
            isBuiltIn: true
        ),
        SoundPack(
            id: "00000000-0000-4000-8000-000000000002",
            name: "Creamy",
            defaultDownSoundId: "builtin_creamy_down",
            defaultUpSoundId: "builtin_creamy_up",
            keyMappings: [:],
            isBuiltIn: true
        ),
        SoundPack(
            id: "00000000-0000-4000-8000-000000000003",
            name: "Clicky",
            defaultDownSoundId: "builtin_clicky_down",
            defaultUpSoundId: "builtin_clicky_up",
            keyMappings: [:],
            isBuiltIn: true
        ),
        SoundPack(
            id: "00000000-0000-4000-8000-000000000004",
            name: "Quiet",
            defaultDownSoundId: "builtin_quiet_down",
            defaultUpSoundId: "builtin_quiet_up",
            keyMappings: [:],
            isBuiltIn: true
        )
    ]
}
