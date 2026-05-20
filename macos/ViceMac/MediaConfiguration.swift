import Foundation

struct ROMImageConfiguration: Codable, Equatable {
    private var paths: [String: String]

    static let standard = ROMImageConfiguration(paths: [:])

    init(paths: [String: String] = [:]) {
        self.paths = paths
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let paths = try container.decodeIfPresent([String: String].self, forKey: .paths) {
            self.paths = paths
            return
        }

        var legacyPaths: [String: String] = [:]
        if let basicPath = try container.decodeIfPresent(String.self, forKey: .basicPath) {
            legacyPaths[MachineROMSlot.c64Basic.id] = basicPath
        }
        if let kernalPath = try container.decodeIfPresent(String.self, forKey: .kernalPath) {
            legacyPaths[MachineROMSlot.c64Kernal.id] = kernalPath
        }
        if let characterPath = try container.decodeIfPresent(String.self, forKey: .characterPath) {
            legacyPaths[MachineROMSlot.c64Character.id] = characterPath
        }
        paths = legacyPaths
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(paths, forKey: .paths)
    }

    func path(for slot: MachineROMSlot) -> String? {
        paths[slot.id]
    }

    func resourceValue(for slot: MachineROMSlot) -> String {
        path(for: slot) ?? slot.defaultFileName
    }

    mutating func setPath(_ path: String?, for slot: MachineROMSlot) {
        let normalizedPath = path?.isEmpty == false ? path : nil
        paths[slot.id] = normalizedPath
    }

    private enum CodingKeys: String, CodingKey {
        case paths
        case basicPath
        case kernalPath
        case characterPath
    }
}

struct CartridgeStatus: Equatable {
    var isAttached: Bool
    var cartridgeID: Int32
    var cartridgeFlags: UInt32
    var romSize: UInt32
    var chipCount: UInt32
    var bankCount: UInt32
    var cartridgeName: String?
    var imagePath: String?

    static let detached = CartridgeStatus(isAttached: false,
                                          cartridgeID: -1,
                                          cartridgeFlags: 0,
                                          romSize: 0,
                                          chipCount: 0,
                                          bankCount: 0,
                                          cartridgeName: nil,
                                          imagePath: nil)
}
