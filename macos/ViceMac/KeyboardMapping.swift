import AppKit
import Foundation

enum VICEKeyboardMappingMode: String, CaseIterable, Codable, Identifiable {
    case symbolic
    case positional

    var id: String { rawValue }

    var title: String {
        switch self {
        case .symbolic:
            return "Typed Characters"
        case .positional:
            return "Physical Keys"
        }
    }

    var shortTitle: String {
        switch self {
        case .symbolic:
            return "Symbolic"
        case .positional:
            return "Positional"
        }
    }

    var detail: String {
        switch self {
        case .symbolic:
            return "Follows the character produced by the Mac keyboard layout."
        case .positional:
            return "Follows the physical key position expected by VICE."
        }
    }

    var defaultKeymapIndex: Int32 {
        switch self {
        case .symbolic:
            return 0
        case .positional:
            return 1
        }
    }

    var userKeymapIndex: Int32 {
        switch self {
        case .symbolic:
            return 2
        case .positional:
            return 3
        }
    }

    var defaultFilename: String {
        switch self {
        case .symbolic:
            return "macos_sym.vkm"
        case .positional:
            return "macos_pos.vkm"
        }
    }

    var userResourceName: String {
        switch self {
        case .symbolic:
            return "KeymapUserSymFile"
        case .positional:
            return "KeymapUserPosFile"
        }
    }
}

enum VICEKeyboardMappingProfile: String, CaseIterable, Codable, Identifiable {
    case viceDefault
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .viceDefault:
            return "VICE Default"
        case .custom:
            return "Custom"
        }
    }
}

struct VICEKeyboardMappingConfiguration: Codable, Equatable {
    var mode: VICEKeyboardMappingMode
    var profile: VICEKeyboardMappingProfile

    static let standard = VICEKeyboardMappingConfiguration(mode: .symbolic,
                                                           profile: .viceDefault)

    var keymapIndex: Int32 {
        switch profile {
        case .viceDefault:
            return mode.defaultKeymapIndex
        case .custom:
            return mode.userKeymapIndex
        }
    }

    var statusTitle: String {
        "\(profile.title) \(mode.shortTitle)"
    }
}

struct VICEKeyboardMatrixKey: Identifiable, Hashable {
    let row: Int
    let column: Int
    let label: String

    var id: String {
        "\(row):\(column)"
    }

    var title: String {
        label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var detailTitle: String {
        "row \(row), column \(column)"
    }
}

enum VICEKeymapFlags {
    static let emulatedShift = 0x0001
    static let leftShiftKey = 0x0002
    static let rightShiftKey = 0x0004
    static let anyShiftState = 0x0008
    static let deshift = 0x0010
    static let continues = 0x0020
    static let shiftLock = 0x0040
    static let hostShift = 0x0080
    static let c64Mode = 0x0100
    static let hostOption = 0x0200
    static let hostControl = 0x0400
    static let emulatedCBM = 0x0800
    static let emulatedControl = 0x1000
    static let cbmKey = 0x2000
    static let controlKey = 0x4000
}

struct VICEKeymapEntry: Identifiable, Equatable {
    let id: Int
    var symbol: String
    var row: Int
    var column: Int
    var flags: Int?
    var trailingComment: String?

    var isMatrixKey: Bool {
        row >= 0
    }

    var flagsTitle: String {
        guard let flags else {
            return ""
        }

        return String(format: "0x%04x", flags)
    }

    var hostModifierTitle: String {
        guard let flags else {
            return ""
        }

        var titles: [String] = []
        if flags & VICEKeymapFlags.hostShift != 0 {
            titles.append("Shift")
        }
        if flags & VICEKeymapFlags.hostOption != 0 {
            titles.append("Option")
        }
        if flags & VICEKeymapFlags.hostControl != 0 {
            titles.append("Control")
        }

        return titles.joined(separator: " + ")
    }

    var emulatedModifierTitle: String {
        guard let flags else {
            return ""
        }

        var titles: [String] = []
        if flags & VICEKeymapFlags.emulatedShift != 0 {
            titles.append("Shift")
        }
        if flags & VICEKeymapFlags.emulatedCBM != 0 {
            titles.append("CBM")
        }
        if flags & VICEKeymapFlags.emulatedControl != 0 {
            titles.append("Control")
        }

        return titles.joined(separator: " + ")
    }

    var behaviorTitle: String {
        guard let flags else {
            return ""
        }

        var titles: [String] = []
        if flags & VICEKeymapFlags.leftShiftKey != 0 {
            titles.append("Left Shift key")
        }
        if flags & VICEKeymapFlags.rightShiftKey != 0 {
            titles.append("Right Shift key")
        }
        if flags & VICEKeymapFlags.anyShiftState != 0 {
            titles.append("Any shift state")
        }
        if flags & VICEKeymapFlags.deshift != 0 {
            titles.append("Deshift")
        }
        if flags & VICEKeymapFlags.continues != 0 {
            titles.append("Continues")
        }
        if flags & VICEKeymapFlags.shiftLock != 0 {
            titles.append("Shift Lock")
        }
        if flags & VICEKeymapFlags.c64Mode != 0 {
            titles.append("C64 mode")
        }
        if flags & VICEKeymapFlags.cbmKey != 0 {
            titles.append("CBM key")
        }
        if flags & VICEKeymapFlags.controlKey != 0 {
            titles.append("Control key")
        }

        return titles.joined(separator: ", ")
    }
}

enum VICEKeymapLine: Equatable {
    case raw(String)
    case entry(VICEKeymapEntry)

    var rendered: String {
        switch self {
        case let .raw(line):
            return line
        case let .entry(entry):
            var line = "\(entry.symbol.paddedForVKMColumn(width: 16)) \(entry.row) \(entry.column)"
            if let flags = entry.flags {
                line += " \(String(format: "0x%x", flags))"
            }
            if let trailingComment = entry.trailingComment,
               !trailingComment.isEmpty {
                line += " \(trailingComment)"
            }
            return line
        }
    }
}

struct VICEKeymapDocument: Equatable {
    var lines: [VICEKeymapLine]
    var matrixKeys: [VICEKeyboardMatrixKey]

    var entries: [VICEKeymapEntry] {
        lines.compactMap { line in
            if case let .entry(entry) = line {
                return entry
            }

            return nil
        }
    }

    var nextEntryID: Int {
        (entries.map(\.id).max() ?? -1) + 1
    }

    func matrixKey(row: Int, column: Int) -> VICEKeyboardMatrixKey? {
        matrixKeys.first { $0.row == row && $0.column == column }
    }

    func targetTitle(for entry: VICEKeymapEntry) -> String {
        guard entry.row >= 0 else {
            return negativeTargetTitle(for: entry)
        }

        if let matrixKey = matrixKey(row: entry.row, column: entry.column) {
            return "\(matrixKey.title) (\(matrixKey.detailTitle))"
        }

        return "row \(entry.row), column \(entry.column)"
    }

    func targetDisplayTitle(for entry: VICEKeymapEntry) -> String {
        guard entry.row >= 0 else {
            return Self.specialTargetTitle(row: entry.row, column: entry.column)
        }

        return matrixKey(row: entry.row, column: entry.column)?.title
            ?? "Machine key"
    }

    static func specialTargetTitle(row: Int, column: Int) -> String {
        switch row {
        case -1:
            return "Joystick A \(joystickDirectionTitle(column))"
        case -2:
            return "Joystick B \(joystickDirectionTitle(column))"
        case -3:
            return column == 0 ? "RESTORE" : "RESTORE alternate"
        case -4:
            return column == 0 ? "40/80 column" : "CAPS"
        case -5:
            return joyportKeypadTitle(column)
        default:
            return "Special key"
        }
    }

    func updating(entry updatedEntry: VICEKeymapEntry) -> VICEKeymapDocument {
        var updatedLines = lines
        for index in updatedLines.indices {
            if case let .entry(entry) = updatedLines[index],
               entry.id == updatedEntry.id {
                updatedLines[index] = .entry(updatedEntry)
                return VICEKeymapDocument(lines: updatedLines,
                                          matrixKeys: matrixKeys)
            }
        }

        return VICEKeymapDocument(lines: updatedLines, matrixKeys: matrixKeys)
            .appending(entry: updatedEntry)
    }

    func removingEntry(id: Int) -> VICEKeymapDocument {
        VICEKeymapDocument(lines: lines.filter { line in
            if case let .entry(entry) = line {
                return entry.id != id
            }

            return true
        }, matrixKeys: matrixKeys)
    }

    func appending(entry: VICEKeymapEntry) -> VICEKeymapDocument {
        var updatedLines = lines
        let insertionIndex = updatedLines.lastIndex { line in
            if case let .raw(rawLine) = line {
                return !rawLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }

            return true
        }.map { updatedLines.index(after: $0) } ?? updatedLines.endIndex

        let hasCustomMarker = updatedLines.contains { line in
            if case let .raw(rawLine) = line {
                return rawLine.contains("VICE Mac custom mappings")
            }

            return false
        }

        if !hasCustomMarker {
            updatedLines.insert(.raw("# VICE Mac custom mappings"), at: insertionIndex)
            updatedLines.insert(.entry(entry), at: updatedLines.index(after: insertionIndex))
        } else {
            updatedLines.insert(.entry(entry), at: insertionIndex)
        }

        return VICEKeymapDocument(lines: updatedLines,
                                  matrixKeys: matrixKeys)
    }

    func syncingModifierDirectives(for entry: VICEKeymapEntry) -> VICEKeymapDocument {
        guard let flags = entry.flags else {
            return self
        }

        var updated = self
        if flags & VICEKeymapFlags.leftShiftKey != 0 {
            updated = updated.updatingDirective("!LSHIFT", arguments: "\(entry.row) \(entry.column)")
        }
        if flags & VICEKeymapFlags.rightShiftKey != 0 {
            updated = updated.updatingDirective("!RSHIFT", arguments: "\(entry.row) \(entry.column)")
        }
        if flags & VICEKeymapFlags.shiftLock != 0 {
            let shiftName = updated.shiftDirectiveName(forRow: entry.row, column: entry.column)
            updated = updated.updatingDirective("!SHIFTL", arguments: shiftName)
        }
        if flags & VICEKeymapFlags.cbmKey != 0 {
            updated = updated.updatingDirective("!LCBM", arguments: "\(entry.row) \(entry.column)")
            updated = updated.updatingDirective("!VCBM", arguments: "LCBM")
        }
        if flags & VICEKeymapFlags.controlKey != 0 {
            updated = updated.updatingDirective("!LCTRL", arguments: "\(entry.row) \(entry.column)")
            updated = updated.updatingDirective("!VCTRL", arguments: "LCTRL")
        }

        return updated
    }

    func rendered(customTitle: String) -> String {
        var output: [String] = [
            "# VICE keyboard mapping file",
            "#",
            "# \(customTitle)",
            "# Generated by VICE Mac. This remains a normal VICE .vkm file.",
            "#"
        ]
        output += lines.map(\.rendered)
        return output.joined(separator: "\n") + "\n"
    }

    static func parse(text: String, baseURL: URL? = nil) throws -> VICEKeymapDocument {
        let parser = VICEKeymapParser()
        var visited = Set<URL>()
        try parser.parse(text: text, baseURL: baseURL, visited: &visited)
        return parser.document
    }

    private func negativeTargetTitle(for entry: VICEKeymapEntry) -> String {
        switch entry.row {
        case -1:
            return "Joystick A direction \(entry.column)"
        case -2:
            return "Joystick B direction \(entry.column)"
        case -3:
            return entry.column == 0 ? "RESTORE" : "RESTORE alternate"
        case -4:
            return entry.column == 0 ? "40/80 column key" : "CAPS key"
        case -5:
            return "Joyport keypad \(entry.column)"
        default:
            return "special target \(entry.row):\(entry.column)"
        }
    }

    private static func joystickDirectionTitle(_ value: Int) -> String {
        switch value {
        case 0:
            return "Fire"
        case 1:
            return "South West"
        case 2:
            return "South"
        case 3:
            return "South East"
        case 4:
            return "West"
        case 5:
            return "East"
        case 6:
            return "North West"
        case 7:
            return "North"
        case 8:
            return "North East"
        default:
            return "Direction \(value)"
        }
    }

    private static func joyportKeypadTitle(_ value: Int) -> String {
        switch value {
        case 0...19:
            return "Joyport keypad \(value)"
        default:
            return "Joyport keypad"
        }
    }

    private func updatingDirective(_ directive: String,
                                   arguments: String) -> VICEKeymapDocument {
        var updatedLines = lines
        for index in updatedLines.indices {
            if case let .raw(line) = updatedLines[index],
               line.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("\(directive) ") {
                updatedLines[index] = .raw("\(directive) \(arguments)")
                return VICEKeymapDocument(lines: updatedLines,
                                          matrixKeys: matrixKeys)
            }
        }

        let insertionIndex = updatedLines.firstIndex { line in
            if case let .raw(rawLine) = line {
                return rawLine.trimmingCharacters(in: .whitespacesAndNewlines) == "!CLEAR"
            }

            return false
        }.map { updatedLines.index(after: $0) } ?? updatedLines.startIndex
        updatedLines.insert(.raw("\(directive) \(arguments)"), at: insertionIndex)
        return VICEKeymapDocument(lines: updatedLines,
                                  matrixKeys: matrixKeys)
    }

    private func shiftDirectiveName(forRow row: Int, column: Int) -> String {
        for line in lines {
            guard case let .raw(rawLine) = line else {
                continue
            }

            let tokens = rawLine.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard tokens.count >= 3,
                  let directiveRow = Int(tokens[1]),
                  let directiveColumn = Int(tokens[2]),
                  directiveRow == row,
                  directiveColumn == column else {
                continue
            }

            if tokens[0] == "!RSHIFT" {
                return "RSHIFT"
            }
            if tokens[0] == "!LSHIFT" {
                return "LSHIFT"
            }
        }

        return "LSHIFT"
    }
}

private final class VICEKeymapParser {
    private(set) var lines: [VICEKeymapLine] = []
    private var matrixLabels: [String: VICEKeyboardMatrixKey] = [:]
    private var nextEntryID = 0

    var document: VICEKeymapDocument {
        let matrixKeys = matrixLabels.values.sorted {
            if $0.row == $1.row {
                return $0.column < $1.column
            }

            return $0.row < $1.row
        }

        return VICEKeymapDocument(lines: lines, matrixKeys: matrixKeys)
    }

    func parse(text: String, baseURL: URL?, visited: inout Set<URL>) throws {
        for line in text.components(separatedBy: .newlines) {
            if let labels = Self.matrixLabels(from: line) {
                for key in labels {
                    matrixLabels[key.id] = key
                }
            }

            if let includeName = Self.includeName(from: line),
               let baseURL {
                let includeURL = baseURL.appendingPathComponent(includeName).standardizedFileURL
                if !visited.contains(includeURL),
                   FileManager.default.fileExists(atPath: includeURL.path) {
                    visited.insert(includeURL)
                    let includeText = try String(contentsOf: includeURL, encoding: .utf8)
                    lines.append(.raw("# BEGIN !INCLUDE \(includeName)"))
                    try parse(text: includeText,
                              baseURL: includeURL.deletingLastPathComponent(),
                              visited: &visited)
                    lines.append(.raw("# END !INCLUDE \(includeName)"))
                    continue
                }
            }

            if let entry = Self.entry(from: line, id: nextEntryID) {
                nextEntryID += 1
                lines.append(.entry(entry))
            } else {
                lines.append(.raw(line))
            }
        }
    }

    private static func includeName(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("!INCLUDE") else {
            return nil
        }

        let remainder = trimmed.dropFirst("!INCLUDE".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return remainder.isEmpty ? nil : remainder
    }

    private static func entry(from line: String, id: Int) -> VICEKeymapEntry? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.hasPrefix("#"),
              !trimmed.hasPrefix("!") else {
            return nil
        }

        let split = splitCodeAndComment(line)
        let tokens = split.code.split(whereSeparator: { $0 == " " || $0 == "\t" })
        guard tokens.count >= 3,
              let row = parseInteger(tokens[1]),
              let column = parseInteger(tokens[2]) else {
            return nil
        }

        let flags = tokens.count >= 4 ? parseInteger(tokens[3]) : nil
        return VICEKeymapEntry(id: id,
                               symbol: String(tokens[0]),
                               row: row,
                               column: column,
                               flags: flags,
                               trailingComment: split.comment)
    }

    private static func splitCodeAndComment(_ line: String) -> (code: String, comment: String?) {
        let markers = ["/*", "#"].compactMap { marker -> String.Index? in
            line.range(of: marker)?.lowerBound
        }

        guard let markerIndex = markers.min() else {
            return (line, nil)
        }

        let code = String(line[..<markerIndex])
        let comment = String(line[markerIndex...])
        return (code, comment)
    }

    private static func parseInteger(_ token: Substring) -> Int? {
        let text = String(token)
        if text.hasPrefix("0x") || text.hasPrefix("0X") {
            return Int(text.dropFirst(2), radix: 16)
        }

        return Int(text)
    }

    private static func matrixLabels(from line: String) -> [VICEKeyboardMatrixKey]? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#") else {
            return nil
        }

        let comment = trimmed.dropFirst()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if comment.hasPrefix("|Bit ") {
            return bitMatrixLabels(from: comment)
        }

        return numberedMatrixLabels(from: comment)
    }

    private static func bitMatrixLabels(from comment: String) -> [VICEKeyboardMatrixKey]? {
        let cells = comment
            .split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard cells.count >= 9,
              let row = Int(cells[0].replacingOccurrences(of: "Bit ", with: "")) else {
            return nil
        }

        let labels = Array(cells.dropFirst().prefix(8))
        guard !labels.allSatisfy({ $0.hasPrefix("Bit ") }) else {
            return nil
        }

        return labels.enumerated().map { column, label in
            VICEKeyboardMatrixKey(row: row, column: column, label: label)
        }
    }

    private static func numberedMatrixLabels(from comment: String) -> [VICEKeyboardMatrixKey]? {
        guard let firstPipe = comment.firstIndex(of: "|") else {
            return nil
        }

        let rowText = comment[..<firstPipe].trimmingCharacters(in: .whitespacesAndNewlines)
        guard let row = Int(rowText) else {
            return nil
        }

        let labels = comment[firstPipe...]
            .split(separator: "|", omittingEmptySubsequences: false)
            .dropFirst()
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard labels.count >= 8 else {
            return nil
        }

        return labels.prefix(8).enumerated().compactMap { column, label in
            guard !label.isEmpty,
                  !label.allSatisfy({ $0 == "-" }) else {
                return nil
            }

            return VICEKeyboardMatrixKey(row: row, column: column, label: label)
        }
    }
}

enum VICEKeymapStore {
    static func document(for machine: EmulatedMachine,
                         configuration: VICEKeyboardMappingConfiguration) throws -> VICEKeymapDocument {
        switch configuration.profile {
        case .viceDefault:
            return try defaultDocument(for: machine, mode: configuration.mode)
        case .custom:
            let url = customKeymapURL(for: machine, mode: configuration.mode)
            if FileManager.default.fileExists(atPath: url.path) {
                return try document(at: url)
            }

            return try ensureCustomKeymap(for: machine, mode: configuration.mode)
        }
    }

    @discardableResult
    static func ensureCustomKeymap(for machine: EmulatedMachine,
                                   mode: VICEKeyboardMappingMode) throws -> VICEKeymapDocument {
        let url = customKeymapURL(for: machine, mode: mode)
        if FileManager.default.fileExists(atPath: url.path) {
            return try document(at: url)
        }

        let document = try defaultDocument(for: machine, mode: mode)
        try save(document,
                 to: url,
                 title: "Custom \(machine.shortName) \(mode.shortTitle) map")
        return document
    }

    static func save(_ document: VICEKeymapDocument,
                     to url: URL,
                     title: String) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try document.rendered(customTitle: title).write(to: url,
                                                        atomically: true,
                                                        encoding: .utf8)
    }

    static func customKeymapURL(for machine: EmulatedMachine,
                                mode: VICEKeyboardMappingMode) -> URL {
        applicationSupportKeymapDirectory
            .appendingPathComponent("\(machine.keymapStorageName)-\(mode.rawValue).vkm")
    }

    static func bundledKeymapURL(for machine: EmulatedMachine,
                                 mode: VICEKeyboardMappingMode) -> URL? {
        let relativePath = "\(machine.viceDataDirectoryName)/\(machine.defaultKeymapFilename(for: mode))"
        if let url = Bundle.main.resourceURL?
            .appendingPathComponent("VICEData")
            .appendingPathComponent(relativePath),
           FileManager.default.fileExists(atPath: url.path) {
            return url
        }

        #if DEBUG
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("vice/data")
            .appendingPathComponent(relativePath)
        if FileManager.default.fileExists(atPath: sourceURL.path) {
            return sourceURL
        }
        #endif

        return nil
    }

    private static func defaultDocument(for machine: EmulatedMachine,
                                        mode: VICEKeyboardMappingMode) throws -> VICEKeymapDocument {
        guard let url = bundledKeymapURL(for: machine, mode: mode) else {
            throw VICEKeymapError.missingDefaultMap(machine.shortName, mode.title)
        }

        return try document(at: url)
    }

    private static func document(at url: URL) throws -> VICEKeymapDocument {
        let text = try String(contentsOf: url, encoding: .utf8)
        return try VICEKeymapDocument.parse(text: text,
                                            baseURL: url.deletingLastPathComponent())
    }

    private static var applicationSupportKeymapDirectory: URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory,
                                               in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return baseURL
            .appendingPathComponent("VICE Mac", isDirectory: true)
            .appendingPathComponent("Keymaps", isDirectory: true)
    }
}

enum VICEKeymapError: LocalizedError {
    case missingDefaultMap(String, String)

    var errorDescription: String? {
        switch self {
        case let .missingDefaultMap(machine, mode):
            return "Missing VICE \(mode) keymap for \(machine)."
        }
    }
}

extension EmulatedMachine {
    var viceDataDirectoryName: String {
        switch family {
        case .c64:
            return "C64"
        case .c128:
            return "C128"
        case .vic20:
            return "VIC20"
        case .pet:
            return "PET"
        case .ted:
            return "PLUS4"
        }
    }

    var keymapStorageName: String {
        switch model {
        case let .xpet(model):
            return "\(id.rawValue)-\(model.keyboardStyle.rawValue)"
        default:
            return id.rawValue
        }
    }

    func defaultKeymapFilename(for mode: VICEKeyboardMappingMode) -> String {
        switch model {
        case let .xpet(model):
            return "macos_\(model.keyboardStyle.viceKeymapStem)_\(mode.viceFilenameSuffix).vkm"
        default:
            return mode.defaultFilename
        }
    }
}

enum PETKeyboardStyle: String {
    case graphics
    case business

    var viceKeymapStem: String {
        switch self {
        case .graphics:
            return "grus"
        case .business:
            return "buuk"
        }
    }
}

extension PETMachineModel {
    var keyboardStyle: PETKeyboardStyle {
        switch self {
        case .model2001, .model3008, .model3016, .model3032, .model4032:
            return .graphics
        case .model3032B, .model4016, .model4032B, .model8032, .model8096, .model8296, .superPET:
            return .business
        }
    }
}

private extension VICEKeyboardMappingMode {
    var viceFilenameSuffix: String {
        switch self {
        case .symbolic:
            return "sym"
        case .positional:
            return "pos"
        }
    }
}

struct PressedEmulatorKey {
    let symbol: Int64
    let modifiers: Int32
}

struct EmulatorModifierKey {
    let symbol: Int64
    let modifiers: Int32
    let isToggle: Bool
}

enum ViceMacKeyMapper {
    private enum Modifier {
        static let leftShift: Int32 = 1 << 0
        static let rightShift: Int32 = 1 << 1
        static let leftControl: Int32 = 1 << 2
        static let leftOption: Int32 = 1 << 4
        static let rightOption: Int32 = 1 << 5
    }

    private enum Key {
        static let backspace: Int64 = 0xff08
        static let tab: Int64 = 0xff09
        static let returnKey: Int64 = 0xff0d
        static let escape: Int64 = 0xff1b
        static let insert: Int64 = 0xff63
        static let delete: Int64 = 0xffff
        static let home: Int64 = 0xff50
        static let left: Int64 = 0xff51
        static let up: Int64 = 0xff52
        static let right: Int64 = 0xff53
        static let down: Int64 = 0xff54
        static let pageUp: Int64 = 0xff55
        static let pageDown: Int64 = 0xff56
        static let end: Int64 = 0xff57
        static let shiftLeft: Int64 = 0xffe1
        static let shiftRight: Int64 = 0xffe2
        static let controlLeft: Int64 = 0xffe3
        static let capsLock: Int64 = 0xffe5
        static let f1: Int64 = 0xffbe
        static let keypadEnter: Int64 = 0xff8d
        static let keypadMultiply: Int64 = 0xffaa
        static let keypadAdd: Int64 = 0xffab
        static let keypadSeparator: Int64 = 0xffac
        static let keypadSubtract: Int64 = 0xffad
        static let keypadDecimal: Int64 = 0xffae
        static let keypadDivide: Int64 = 0xffaf
        static let keypad0: Int64 = 0xffb0
    }

    private enum MacKeyCode {
        static let tab: UInt16 = 48
        static let returnKey: UInt16 = 36
        static let keypadEnter: UInt16 = 76
        static let escape: UInt16 = 53
        static let delete: UInt16 = 51
        static let forwardDelete: UInt16 = 117
        static let home: UInt16 = 115
        static let end: UInt16 = 119
        static let pageUp: UInt16 = 116
        static let pageDown: UInt16 = 121
        static let leftArrow: UInt16 = 123
        static let rightArrow: UInt16 = 124
        static let downArrow: UInt16 = 125
        static let upArrow: UInt16 = 126
        static let leftShift: UInt16 = 56
        static let rightShift: UInt16 = 60
        static let capsLock: UInt16 = 57
        static let leftControl: UInt16 = 59
        static let keypadDecimal: UInt16 = 65
        static let keypadMultiply: UInt16 = 67
        static let keypadPlus: UInt16 = 69
        static let keypadClear: UInt16 = 71
        static let keypadDivide: UInt16 = 75
        static let keypadMinus: UInt16 = 78
        static let keypadEquals: UInt16 = 81
        static let keypad0: UInt16 = 82
        static let keypad1: UInt16 = 83
        static let keypad2: UInt16 = 84
        static let keypad3: UInt16 = 85
        static let keypad4: UInt16 = 86
        static let keypad5: UInt16 = 87
        static let keypad6: UInt16 = 88
        static let keypad7: UInt16 = 89
        static let keypad8: UInt16 = 91
        static let keypad9: UInt16 = 92
        static let f1: UInt16 = 122
        static let f2: UInt16 = 120
        static let f3: UInt16 = 99
        static let f4: UInt16 = 118
        static let f5: UInt16 = 96
        static let f6: UInt16 = 97
        static let f7: UInt16 = 98
        static let f8: UInt16 = 100
        static let f9: UInt16 = 101
        static let f10: UInt16 = 109
        static let f11: UInt16 = 103
        static let f12: UInt16 = 111
    }

    private static let printableSymbolNames: [UnicodeScalar: String] = [
        " ": "space",
        "!": "exclam",
        "\"": "quotedbl",
        "#": "numbersign",
        "$": "dollar",
        "%": "percent",
        "&": "ampersand",
        "'": "apostrophe",
        "(": "parenleft",
        ")": "parenright",
        "*": "asterisk",
        "+": "plus",
        ",": "comma",
        "-": "minus",
        ".": "period",
        "/": "slash",
        ":": "colon",
        ";": "semicolon",
        "<": "less",
        "=": "equal",
        ">": "greater",
        "?": "question",
        "@": "at",
        "[": "bracketleft",
        "\\": "backslash",
        "]": "bracketright",
        "^": "asciicircum",
        "_": "underscore",
        "`": "grave",
        "{": "braceleft",
        "|": "bar",
        "}": "braceright",
        "~": "asciitilde"
    ]

    private static let symbolTitles: [String: String] = [
        "BackSpace": "Delete",
        "Tab": "Tab",
        "ISO_Left_Tab": "Shift-Tab",
        "Return": "Return",
        "Escape": "Escape",
        "Delete": "Forward Delete",
        "Insert": "Insert",
        "Home": "Home",
        "Left": "Left Arrow",
        "Up": "Up Arrow",
        "Right": "Right Arrow",
        "Down": "Down Arrow",
        "Page_Up": "Page Up",
        "Prior": "Page Up",
        "Page_Down": "Page Down",
        "End": "End",
        "Caps_Lock": "Caps Lock",
        "Shift_L": "Left Shift",
        "Shift_R": "Right Shift",
        "Control_L": "Control",
        "KP_0": "Keypad 0",
        "KP_1": "Keypad 1",
        "KP_2": "Keypad 2",
        "KP_3": "Keypad 3",
        "KP_4": "Keypad 4",
        "KP_5": "Keypad 5",
        "KP_6": "Keypad 6",
        "KP_7": "Keypad 7",
        "KP_8": "Keypad 8",
        "KP_9": "Keypad 9",
        "KP_Decimal": "Keypad .",
        "KP_Separator": "Keypad Separator",
        "KP_Add": "Keypad +",
        "KP_Subtract": "Keypad -",
        "KP_Multiply": "Keypad *",
        "KP_Divide": "Keypad /",
        "KP_Enter": "Keypad Enter",
        "KP_Delete": "Keypad Delete",
        "space": "Space",
        "exclam": "!",
        "quotedbl": "\"",
        "numbersign": "#",
        "dollar": "$",
        "percent": "%",
        "ampersand": "&",
        "apostrophe": "'",
        "parenleft": "(",
        "parenright": ")",
        "asterisk": "*",
        "plus": "+",
        "comma": ",",
        "minus": "-",
        "period": ".",
        "slash": "/",
        "colon": ":",
        "semicolon": ";",
        "less": "<",
        "equal": "=",
        "greater": ">",
        "question": "?",
        "at": "@",
        "bracketleft": "[",
        "backslash": "\\",
        "bracketright": "]",
        "asciicircum": "^",
        "underscore": "_",
        "grave": "`",
        "braceleft": "{",
        "bar": "|",
        "braceright": "}",
        "asciitilde": "~"
    ]

    static func symbol(for event: NSEvent) -> Int64? {
        if let special = specialSymbol(for: event.keyCode) {
            return special
        }

        guard let scalar = event.characters?.unicodeScalars.first,
              scalar.value >= 0x20,
              scalar.value <= 0x7e else {
            return nil
        }

        return Int64(scalar.value)
    }

    static func keySymbolName(for event: NSEvent) -> String? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !flags.contains(.command) else {
            return nil
        }

        if let special = specialSymbolName(for: event.keyCode) {
            return special
        }

        guard let scalar = event.characters?.unicodeScalars.first,
              scalar.value >= 0x20,
              scalar.value <= 0x7e else {
            return nil
        }

        return printableSymbolNames[scalar] ?? String(scalar)
    }

    static func displayTitle(forKeySymbol symbol: String) -> String {
        if let title = symbolTitles[symbol] {
            return title
        }

        if symbol.hasPrefix("F"),
           symbol.dropFirst().allSatisfy(\.isNumber) {
            return symbol
        }

        return symbol
    }

    static func modifiers(for event: NSEvent) -> Int32 {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: Int32 = 0

        if flags.contains(.shift) {
            modifiers |= Modifier.leftShift
        }
        if flags.contains(.control) {
            modifiers |= Modifier.leftControl
        }
        if flags.contains(.option) {
            modifiers |= Modifier.leftOption
        }

        return modifiers
    }

    static func modifierKey(for event: NSEvent) -> EmulatorModifierKey? {
        switch event.keyCode {
        case MacKeyCode.leftShift:
            return EmulatorModifierKey(symbol: Key.shiftLeft,
                                       modifiers: Modifier.leftShift,
                                       isToggle: false)
        case MacKeyCode.rightShift:
            return EmulatorModifierKey(symbol: Key.shiftRight,
                                       modifiers: Modifier.rightShift,
                                       isToggle: false)
        case MacKeyCode.leftControl:
            return EmulatorModifierKey(symbol: Key.controlLeft,
                                       modifiers: Modifier.leftControl,
                                       isToggle: false)
        case MacKeyCode.capsLock:
            return EmulatorModifierKey(symbol: Key.capsLock,
                                       modifiers: 0,
                                       isToggle: true)
        default:
            return nil
        }
    }

    private static func specialSymbol(for keyCode: UInt16) -> Int64? {
        switch keyCode {
        case MacKeyCode.keypad0:
            return Key.keypad0
        case MacKeyCode.keypad1:
            return Key.keypad0 + 1
        case MacKeyCode.keypad2:
            return Key.keypad0 + 2
        case MacKeyCode.keypad3:
            return Key.keypad0 + 3
        case MacKeyCode.keypad4:
            return Key.keypad0 + 4
        case MacKeyCode.keypad5:
            return Key.keypad0 + 5
        case MacKeyCode.keypad6:
            return Key.keypad0 + 6
        case MacKeyCode.keypad7:
            return Key.keypad0 + 7
        case MacKeyCode.keypad8:
            return Key.keypad0 + 8
        case MacKeyCode.keypad9:
            return Key.keypad0 + 9
        case MacKeyCode.keypadEnter:
            return Key.keypadEnter
        case MacKeyCode.keypadDecimal:
            return Key.keypadDecimal
        case MacKeyCode.keypadPlus:
            return Key.keypadAdd
        case MacKeyCode.keypadMinus:
            return Key.keypadSubtract
        case MacKeyCode.keypadMultiply:
            return Key.keypadMultiply
        case MacKeyCode.keypadDivide:
            return Key.keypadDivide
        case MacKeyCode.tab:
            return Key.tab
        case MacKeyCode.returnKey, MacKeyCode.keypadEnter:
            return Key.returnKey
        case MacKeyCode.escape:
            return Key.escape
        case MacKeyCode.delete:
            return Key.backspace
        case MacKeyCode.forwardDelete:
            return Key.delete
        case MacKeyCode.home:
            return Key.home
        case MacKeyCode.end:
            return Key.end
        case MacKeyCode.pageUp:
            return Key.pageUp
        case MacKeyCode.pageDown:
            return Key.pageDown
        case MacKeyCode.leftArrow:
            return Key.left
        case MacKeyCode.rightArrow:
            return Key.right
        case MacKeyCode.downArrow:
            return Key.down
        case MacKeyCode.upArrow:
            return Key.up
        default:
            return functionSymbol(for: keyCode)
        }
    }

    private static func specialSymbolName(for keyCode: UInt16) -> String? {
        switch keyCode {
        case MacKeyCode.keypad0:
            return "KP_0"
        case MacKeyCode.keypad1:
            return "KP_1"
        case MacKeyCode.keypad2:
            return "KP_2"
        case MacKeyCode.keypad3:
            return "KP_3"
        case MacKeyCode.keypad4:
            return "KP_4"
        case MacKeyCode.keypad5:
            return "KP_5"
        case MacKeyCode.keypad6:
            return "KP_6"
        case MacKeyCode.keypad7:
            return "KP_7"
        case MacKeyCode.keypad8:
            return "KP_8"
        case MacKeyCode.keypad9:
            return "KP_9"
        case MacKeyCode.keypadEnter:
            return "KP_Enter"
        case MacKeyCode.keypadDecimal:
            return "KP_Decimal"
        case MacKeyCode.keypadPlus:
            return "KP_Add"
        case MacKeyCode.keypadMinus:
            return "KP_Subtract"
        case MacKeyCode.keypadMultiply:
            return "KP_Multiply"
        case MacKeyCode.keypadDivide:
            return "KP_Divide"
        case MacKeyCode.keypadClear:
            return "KP_Delete"
        case MacKeyCode.tab:
            return "Tab"
        case MacKeyCode.returnKey, MacKeyCode.keypadEnter:
            return "Return"
        case MacKeyCode.escape:
            return "Escape"
        case MacKeyCode.delete:
            return "BackSpace"
        case MacKeyCode.forwardDelete:
            return "Delete"
        case MacKeyCode.home:
            return "Home"
        case MacKeyCode.end:
            return "End"
        case MacKeyCode.pageUp:
            return "Page_Up"
        case MacKeyCode.pageDown:
            return "Page_Down"
        case MacKeyCode.leftArrow:
            return "Left"
        case MacKeyCode.rightArrow:
            return "Right"
        case MacKeyCode.downArrow:
            return "Down"
        case MacKeyCode.upArrow:
            return "Up"
        default:
            return functionSymbolName(for: keyCode)
        }
    }

    private static func functionSymbol(for keyCode: UInt16) -> Int64? {
        switch keyCode {
        case MacKeyCode.f1:
            return Key.f1
        case MacKeyCode.f2:
            return Key.f1 + 1
        case MacKeyCode.f3:
            return Key.f1 + 2
        case MacKeyCode.f4:
            return Key.f1 + 3
        case MacKeyCode.f5:
            return Key.f1 + 4
        case MacKeyCode.f6:
            return Key.f1 + 5
        case MacKeyCode.f7:
            return Key.f1 + 6
        case MacKeyCode.f8:
            return Key.f1 + 7
        case MacKeyCode.f9:
            return Key.f1 + 8
        case MacKeyCode.f10:
            return Key.f1 + 9
        case MacKeyCode.f11:
            return Key.f1 + 10
        case MacKeyCode.f12:
            return Key.f1 + 11
        default:
            return nil
        }
    }

    private static func functionSymbolName(for keyCode: UInt16) -> String? {
        switch keyCode {
        case MacKeyCode.f1:
            return "F1"
        case MacKeyCode.f2:
            return "F2"
        case MacKeyCode.f3:
            return "F3"
        case MacKeyCode.f4:
            return "F4"
        case MacKeyCode.f5:
            return "F5"
        case MacKeyCode.f6:
            return "F6"
        case MacKeyCode.f7:
            return "F7"
        case MacKeyCode.f8:
            return "F8"
        case MacKeyCode.f9:
            return "F9"
        case MacKeyCode.f10:
            return "F10"
        case MacKeyCode.f11:
            return "F11"
        case MacKeyCode.f12:
            return "F12"
        default:
            return nil
        }
    }
}

private extension String {
    func paddedForVKMColumn(width: Int) -> String {
        guard count < width else {
            return self
        }

        return self + String(repeating: " ", count: width - count)
    }
}
