import Foundation

struct SIDTuneFile: Equatable, Sendable {
    enum Format: String, Sendable {
        case psid = "PSID"
        case rsid = "RSID"
        case mus = "MUS"
        case unknown = "SID"
    }

    let url: URL
    let format: Format
    let version: Int
    let dataOffset: Int
    let loadAddress: Int
    let initAddress: Int
    let playAddress: Int
    let tuneCount: Int
    let defaultTune: Int
    let speed: UInt32
    let flags: UInt16
    let startPage: UInt8
    let pageCount: UInt8
    let secondSIDAddress: Int?
    let thirdSIDAddress: Int?
    let title: String
    let author: String
    let released: String
    let dataSize: Int

    var displayTitle: String {
        title.isEmpty ? url.deletingPathExtension().lastPathComponent : title
    }

    var displayAuthor: String {
        author.isEmpty ? "Unknown composer" : author
    }

    var sidModelName: String {
        switch (flags >> 4) & 0x03 {
        case 1:
            return "MOS 6581"
        case 2:
            return "MOS 8580"
        case 3:
            return "6581 or 8580"
        default:
            return "Tune default"
        }
    }

    var clockName: String {
        switch (flags >> 2) & 0x03 {
        case 1:
            return "PAL"
        case 2:
            return "NTSC"
        case 3:
            return "PAL/NTSC"
        default:
            return "Unknown clock"
        }
    }

    var compatibilityName: String {
        format == .rsid ? "Real C64 environment" : "C64 player driver"
    }

    var sidChipCount: Int {
        1 + (secondSIDAddress == nil ? 0 : 1) + (thirdSIDAddress == nil ? 0 : 1)
    }

    static func load(from url: URL) throws -> SIDTuneFile {
        let data = try Data(contentsOf: url)
        return try SIDTuneFile(data: data, url: url)
    }

    private init(data: Data, url: URL) throws {
        self.url = url

        guard data.count >= 4 else {
            throw SIDTuneFileError.unsupportedFormat
        }

        let magic = String(decoding: data.prefix(4), as: UTF8.self)
        if magic == "PSID" || magic == "RSID" {
            guard data.count >= 0x76 else {
                throw SIDTuneFileError.truncatedHeader
            }

            format = magic == "RSID" ? .rsid : .psid
            version = Int(data.bigEndianUInt16(at: 4))
            dataOffset = Int(data.bigEndianUInt16(at: 6))
            loadAddress = Int(data.bigEndianUInt16(at: 8))
            initAddress = Int(data.bigEndianUInt16(at: 10))
            playAddress = Int(data.bigEndianUInt16(at: 12))
            tuneCount = max(1, Int(data.bigEndianUInt16(at: 14)))
            defaultTune = max(1, Int(data.bigEndianUInt16(at: 16)))
            speed = data.bigEndianUInt32(at: 18)
            title = data.sidString(in: 22..<54)
            author = data.sidString(in: 54..<86)
            released = data.sidString(in: 86..<118)
            flags = data.count >= 0x78 ? data.bigEndianUInt16(at: 0x76) : 0
            startPage = data.count > 0x78 ? data[0x78] : 0
            pageCount = data.count > 0x79 ? data[0x79] : 0

            // PSID/RSID v3+ define bytes 0x7A and 0x7B as two independent SID
            // address fields (each encodes its address as $D000 | value<<4).
            // Earlier versions leave them reserved/zero, so only decode for v3+.
            if version >= 3 {
                secondSIDAddress = data.count > 0x7a ? Self.sidAddress(fromAddressByte: data[0x7a]) : nil
                thirdSIDAddress = data.count > 0x7b ? Self.sidAddress(fromAddressByte: data[0x7b]) : nil
            } else {
                secondSIDAddress = nil
                thirdSIDAddress = nil
            }
            dataSize = max(0, data.count - dataOffset)
            return
        }

        let lowerExtension = url.pathExtension.lowercased()
        if lowerExtension == "mus" || lowerExtension == "str" {
            format = .mus
            version = 0
            dataOffset = 0
            loadAddress = 0
            initAddress = 0
            playAddress = 0
            tuneCount = 1
            defaultTune = 1
            speed = 0
            flags = 0
            startPage = 0
            pageCount = 0
            secondSIDAddress = nil
            thirdSIDAddress = nil
            title = url.deletingPathExtension().lastPathComponent
            author = ""
            released = ""
            dataSize = data.count
            return
        }

        throw SIDTuneFileError.unsupportedFormat
    }

    /// Decodes a PSID/RSID second- or third-SID address byte. The byte encodes
    /// the address as `$D000 | (value << 4)`; `0x00` means "not present". Only
    /// the documented mirrors `$D420…$D7E0` and `$DE00…$DFE0` are accepted.
    private static func sidAddress(fromAddressByte value: UInt8) -> Int? {
        guard value != 0 else {
            return nil
        }

        let address = 0xd000 | (Int(value) << 4)
        let isValidMirror = (0xd420...0xd7e0).contains(address)
            || (0xde00...0xdfe0).contains(address)
        guard isValidMirror else {
            return nil
        }

        return address
    }
}

enum SIDTuneFileError: LocalizedError {
    case unsupportedFormat
    case truncatedHeader

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "This is not a supported SID tune."
        case .truncatedHeader:
            return "The SID header is incomplete."
        }
    }
}

private extension Data {
    func bigEndianUInt16(at offset: Int) -> UInt16 {
        guard offset + 1 < count else {
            return 0
        }

        return (UInt16(self[offset]) << 8) | UInt16(self[offset + 1])
    }

    func bigEndianUInt32(at offset: Int) -> UInt32 {
        guard offset + 3 < count else {
            return 0
        }

        return (UInt32(self[offset]) << 24)
            | (UInt32(self[offset + 1]) << 16)
            | (UInt32(self[offset + 2]) << 8)
            | UInt32(self[offset + 3])
    }

    func sidString(in range: Range<Int>) -> String {
        let clampedRange = range.clamped(to: 0..<count)
        let bytes = self[clampedRange].prefix { $0 != 0 }
        return String(decoding: bytes, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
