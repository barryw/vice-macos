import CryptoKit
import Foundation
import MacVICEKit
import Network
import Security

enum QLinkReloadedServiceError: LocalizedError, Equatable {
    case unsupportedDisk
    case unknownVersion
    case unsupportedDiskLayout
    case legacyProfileStorageUnavailable
    case diskProfileLimitReached
    case incompatibleSettings(modemIssues: [String], driveIssues: [String])

    var errorDescription: String? {
        switch self {
        case .unsupportedDisk:
            return "Choose a supported Commodore disk image for Q-Link."
        case .unknownVersion:
            return "Sorry - unknown version"
        case .unsupportedDiskLayout:
            return "This Q-Link disk image is not in a patchable D64 layout."
        case .legacyProfileStorageUnavailable:
            return "This Q-Link disk does not use legacy on-disk profile storage."
        case .diskProfileLimitReached:
            return "Q-Link disks can store up to 10 saved user profiles. Remove one from the managed disk before adding another."
        case let .incompatibleSettings(modemIssues, driveIssues):
            var issueSections: [String] = []
            if !modemIssues.isEmpty {
                issueSections.append("Modem:\n" + modemIssues.map { "- \($0)" }.joined(separator: "\n"))
            }
            if !driveIssues.isEmpty {
                issueSections.append("Drive:\n" + driveIssues.map { "- \($0)" }.joined(separator: "\n"))
            }
            let issueText = issueSections.joined(separator: "\n\n")
            return """
            Some current settings are not compatible with Q-Link Reloaded. VICE Mac did not change them.

            Q-Link Reloaded needs a supported modem interface using Raw TCP with a dial host configured, plus a writable disk image in drive 8 so the client can validate and update its disk.

            Current differences:
            \(issueText)
            """
        }
    }
}

enum QLinkReloadedSupport {
    static func canConnect(machine: EmulatedMachine,
                           hasConfiguredDisk: Bool,
                           isConnecting: Bool) -> Bool {
        supports(machine: machine) && hasConfiguredDisk && !isConnecting
    }

    static func supports(machine: EmulatedMachine) -> Bool {
        switch machine.family {
        case .c64, .c128:
            return machine.capabilities.supportsNetworking
        case .pet, .vic20, .ted:
            return false
        }
    }
}

enum QLinkReloadedServerCheckResult: Equatable {
    case success
    case failure(String)
}

protocol QLinkReloadedConnectionChecking: Sendable {
    func validateQLinkServer(host: String, port: Int) async -> QLinkReloadedServerCheckResult
}

enum QLinkReloadedConfigurationValidationOutcome: Equatable {
    case success(String)
    case failure(String)
}

enum QLinkReloadedConfigurationValidationStatus: Equatable {
    case idle
    case checking
    case valid(String)
    case invalid(String)

    var title: String {
        switch self {
        case .idle:
            return "Not checked"
        case .checking:
            return "Checking..."
        case let .valid(message), let .invalid(message):
            return message
        }
    }

    var systemImage: String {
        switch self {
        case .idle:
            return "questionmark.circle"
        case .checking:
            return "hourglass"
        case .valid:
            return "checkmark.circle"
        case .invalid:
            return "xmark.octagon"
        }
    }

    var isChecking: Bool {
        if case .checking = self {
            return true
        }
        return false
    }

    static func status(for outcome: QLinkReloadedConfigurationValidationOutcome) -> Self {
        switch outcome {
        case let .success(message):
            return .valid(message)
        case let .failure(message):
            return .invalid(message)
        }
    }
}

struct QLinkReloadedConfigurationValidator: Sendable {
    private let connectionChecker: any QLinkReloadedConnectionChecking

    init(connectionChecker: any QLinkReloadedConnectionChecking = QLinkReloadedServerConnectionChecker()) {
        self.connectionChecker = connectionChecker
    }

    func validate(configuration: NetworkModemConfiguration,
                  machine: EmulatedMachine,
                  storedProfileCount: Int) async -> QLinkReloadedConfigurationValidationOutcome {
        let issues = QLinkReloadedModemRequirements.incompatibilities(in: configuration,
                                                                      for: machine)
        guard issues.isEmpty else {
            return .failure("Current modem settings are not compatible with Q-Link Reloaded:\n" + issues.map { "- \($0)" }.joined(separator: "\n"))
        }

        let modem = configuration.normalized(for: machine)
        let result = await connectionChecker.validateQLinkServer(host: modem.defaultDialHost,
                                                                 port: modem.defaultDialPort)
        switch result {
        case .success:
            return .success(successMessage(storedProfileCount: storedProfileCount))
        case let .failure(message):
            return .failure(message)
        }
    }

    private func successMessage(storedProfileCount: Int) -> String {
        switch storedProfileCount {
        case 0:
            return "Server responded correctly. No stored profiles are available locally."
        case 1:
            return "Server responded correctly. 1 stored profile is available locally."
        default:
            return "Server responded correctly. \(storedProfileCount) stored profiles are available locally."
        }
    }
}

enum QLinkReloadedProtocolProbe {
    static let commandStart: UInt8 = 0x5A
    static let frameEnd: UInt8 = 0x0D
    static let resetCommand: UInt8 = 0x23
    static let resetAckCommand: UInt8 = 0x24
    static let defaultSequence: UInt8 = 0x7F

    static func resetFrame() -> Data {
        frame(command: resetCommand,
              sendSequence: defaultSequence,
              receiveSequence: defaultSequence,
              payload: [5, 9])
    }

    static func frame(command: UInt8,
                      sendSequence: UInt8,
                      receiveSequence: UInt8,
                      payload: [UInt8]) -> Data {
        var bytes = [UInt8](repeating: 0, count: 8 + payload.count)
        bytes[0] = commandStart
        bytes[5] = sendSequence
        bytes[6] = receiveSequence
        bytes[7] = command
        for (index, byte) in payload.enumerated() {
            bytes[8 + index] = byte
        }
        writeCRC(into: &bytes)
        bytes.append(frameEnd)
        return Data(bytes)
    }

    static func containsResetAck(in bytes: [UInt8]) -> Bool {
        var index = 0
        while index < bytes.count {
            guard bytes[index] == commandStart else {
                index += 1
                continue
            }

            guard let end = bytes[(index + 1)...].firstIndex(of: frameEnd) else {
                return false
            }

            if isResetAckFrame(Array(bytes[index...end])) {
                return true
            }
            index = end + 1
        }

        return false
    }

    static func isValidFrame(_ frame: [UInt8]) -> Bool {
        guard frame.count >= 9,
              frame.first == commandStart,
              frame.last == frameEnd else {
            return false
        }

        let body = Array(frame.dropLast())
        return reportedCRC(in: body) == crc16(body[5..<body.count])
    }

    private static func isResetAckFrame(_ frame: [UInt8]) -> Bool {
        isValidFrame(frame) && frame.count >= 9 && frame[7] == resetAckCommand
    }

    private static func writeCRC(into bytes: inout [UInt8]) {
        let crc = crc16(bytes[5..<bytes.count])
        bytes[1] = UInt8(((crc & 0xF000) >> 8) | 0x01)
        bytes[2] = UInt8(((crc & 0x0F00) >> 8) | 0x40)
        bytes[3] = UInt8((crc & 0x00F0) | 0x01)
        bytes[4] = UInt8((crc & 0x000F) | 0x40)
    }

    private static func reportedCRC(in bytes: [UInt8]) -> UInt16 {
        guard bytes.count >= 5 else {
            return 0
        }

        return (UInt16(bytes[1] & 0xF0 | bytes[2] & 0x0F) << 8)
            | UInt16(bytes[3] & 0xF0 | bytes[4] & 0x0F)
    }

    private static func crc16(_ bytes: ArraySlice<UInt8>) -> UInt16 {
        var crc: UInt16 = 0
        for byte in bytes {
            crc ^= UInt16(byte)
            for _ in 0..<8 {
                crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xA001 : (crc >> 1)
            }
        }
        return crc
    }
}

struct QLinkReloadedServerConnectionChecker: QLinkReloadedConnectionChecking {
    var timeout: TimeInterval = 6

    func validateQLinkServer(host: String, port: Int) async -> QLinkReloadedServerCheckResult {
        guard NetworkModemConfiguration.tcpPortRange.contains(port),
              let endpointPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            return .failure("Port \(port) is not valid.")
        }

        return await QLinkReloadedServerProbe(host: host,
                                              port: endpointPort,
                                              timeout: timeout).validate()
    }
}

private final class QLinkReloadedServerProbe: @unchecked Sendable {
    private enum Phase {
        case waitingForTerminalPrompt
        case waitingForTerminalAccepted
        case waitingForConnected
        case waitingForResetAck
    }

    private let host: String
    private let port: NWEndpoint.Port
    private let timeout: TimeInterval
    private let queue = DispatchQueue(label: "com.barrywalker.ViceMac.QLinkValidation")
    private lazy var connection = NWConnection(host: NWEndpoint.Host(host),
                                               port: port,
                                               using: .tcp)
    private var continuation: CheckedContinuation<QLinkReloadedServerCheckResult, Never>?
    private var phase = Phase.waitingForTerminalPrompt
    private var receivedBytes: [UInt8] = []
    private var didFinish = false

    init(host: String, port: NWEndpoint.Port, timeout: TimeInterval) {
        self.host = host
        self.port = port
        self.timeout = timeout
    }

    func validate() async -> QLinkReloadedServerCheckResult {
        await withTaskGroup(of: QLinkReloadedServerCheckResult.self) { group in
            group.addTask {
                await self.start()
            }
            group.addTask {
                let nanoseconds = UInt64(self.timeout * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
                self.cancel()
                return .failure("Timed out waiting for Q-Link Reloaded to respond.")
            }

            guard let result = await group.next() else {
                return .failure("Could not start Q-Link Reloaded validation.")
            }

            group.cancelAll()
            cancel()
            return result
        }
    }

    private func start() async -> QLinkReloadedServerCheckResult {
        await withCheckedContinuation { continuation in
            queue.async {
                self.continuation = continuation
                self.connection.stateUpdateHandler = { [weak self] state in
                    guard let probe = self else {
                        return
                    }

                    probe.queue.async {
                        probe.handleConnectionState(state)
                    }
                }
                self.connection.start(queue: self.queue)
            }
        }
    }

    private func cancel() {
        queue.async {
            self.connection.cancel()
        }
    }

    private func handleConnectionState(_ state: NWConnection.State) {
        switch state {
        case .ready:
            sendText("\r\r\r")
            receive()
        case let .failed(error):
            finish(.failure("Could not reach Q-Link Reloaded: \(error.localizedDescription)"))
        case .cancelled:
            break
        default:
            break
        }
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1,
                           maximumLength: 4096) { [weak self] data, _, isComplete, error in
            guard let self else {
                return
            }

            self.queue.async {
                if let error {
                    self.finish(.failure("Q-Link Reloaded closed the validation connection: \(error.localizedDescription)"))
                    return
                }

                if let data, !data.isEmpty {
                    self.receivedBytes.append(contentsOf: data)
                    self.processReceivedBytes()
                }

                if isComplete {
                    self.finish(.failure("Q-Link Reloaded closed the validation connection before completing the protocol check."))
                    return
                }

                if !self.didFinish {
                    self.receive()
                }
            }
        }
    }

    private func processReceivedBytes() {
        switch phase {
        case .waitingForTerminalPrompt:
            guard receivedText.contains("TERMINAL=") else {
                return
            }
            receivedBytes.removeAll()
            phase = .waitingForTerminalAccepted
            sendText("D1\r")

        case .waitingForTerminalAccepted:
            guard receivedText.contains("@") else {
                return
            }
            receivedBytes.removeAll()
            phase = .waitingForConnected
            sendText("CONNECT 1200\r")

        case .waitingForConnected:
            guard receivedText.contains("CONNECTED") else {
                return
            }
            receivedBytes.removeAll()
            phase = .waitingForResetAck
            sendData(QLinkReloadedProtocolProbe.resetFrame())

        case .waitingForResetAck:
            if QLinkReloadedProtocolProbe.containsResetAck(in: receivedBytes) {
                finish(.success)
            }
        }
    }

    private var receivedText: String {
        String(decoding: receivedBytes, as: UTF8.self)
    }

    private func sendText(_ text: String) {
        guard let data = text.data(using: .isoLatin1) else {
            finish(.failure("Could not encode Q-Link validation handshake."))
            return
        }
        sendData(data)
    }

    private func sendData(_ data: Data) {
        connection.send(content: data,
                        completion: .contentProcessed { [weak self] error in
            guard let error else {
                return
            }

            guard let probe = self else {
                return
            }

            probe.queue.async {
                probe.finish(.failure("Could not send Q-Link validation handshake: \(error.localizedDescription)"))
            }
        })
    }

    private func finish(_ result: QLinkReloadedServerCheckResult) {
        guard !didFinish else {
            return
        }

        didFinish = true
        connection.cancel()
        continuation?.resume(returning: result)
        continuation = nil
    }
}

struct QLinkReloadedDiskPatchResult {
    var version: QLinkReloadedDiskVersion
    var changedDisk: Bool
}

struct QLinkReloadedDiskVersion: Equatable {
    var profileAgnosticSHA256: String
    var displayTitle: String
    var requiresLegacyPatch = true
}

struct QLinkReloadedRegistrationProfile: Codable, Equatable, Identifiable {
    var accessNumber: String
    var handle: String?
    var decryptedProfileData: Data
    var userRecordData: Data?

    var id: String {
        key
    }

    var key: String {
        Self.key(accessNumber: accessCode, handle: handle)
    }

    var decryptedProfile: [UInt8] {
        Array(decryptedProfileData)
    }

    var userRecord: [UInt8] {
        if let userRecordData {
            return Array(userRecordData)
        }

        return Self.firstUserRecord(in: decryptedProfile) ?? []
    }

    var accessCode: String {
        Self.accessCode(in: decryptedProfile) ?? accessNumber
    }

    var accountID: String? {
        Self.accountID(inUserRecord: userRecord)
    }

    var accountDisplayTitle: String {
        guard let accountID else {
            return "Unknown"
        }

        let trimmedAccountID = accountID.drop { $0 == "0" }
        return trimmedAccountID.isEmpty ? accountID : String(trimmedAccountID)
    }

    var fullAccountDisplayTitle: String {
        accountID ?? "Unknown"
    }

    var displayTitle: String {
        if let handle, !handle.isEmpty {
            return handle
        }

        if accountID != nil {
            return "Account \(accountDisplayTitle)"
        }

        return "Q-Link Profile"
    }

    init(accessNumber: String, handle: String? = nil, decryptedProfile: [UInt8], userRecord: [UInt8]? = nil) {
        self.accessNumber = Self.accessCode(in: decryptedProfile) ?? accessNumber
        self.handle = handle
            ?? userRecord.flatMap(Self.screenName(inUserRecord:))
            ?? Self.screenName(in: decryptedProfile)
        self.decryptedProfileData = Data(decryptedProfile)
        self.userRecordData = userRecord.map { Data($0) }
    }

    static func key(for accessNumber: String) -> String {
        key(forID: accessNumber)
    }

    static func key(forID id: String) -> String {
        id
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    static func key(accessNumber: String, handle: String?) -> String {
        let handleKey = (handle ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return handleKey.isEmpty ? key(for: accessNumber) : handleKey
    }

    private enum CodingKeys: String, CodingKey {
        case accessNumber
        case username
        case handle
        case decryptedProfileData
        case userRecordData
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedAccessNumber = try container.decodeIfPresent(String.self, forKey: .accessNumber)
            ?? container.decode(String.self, forKey: .username)
        let decodedProfileData = try container.decode(Data.self, forKey: .decryptedProfileData)
        let decodedProfile = Array(decodedProfileData)
        let decodedUserRecordData = try container.decodeIfPresent(Data.self, forKey: .userRecordData)
            ?? Self.firstUserRecord(in: decodedProfile).map { Data($0) }
        let decodedUserRecord = decodedUserRecordData.map { Array($0) }

        accessNumber = Self.accessCode(in: decodedProfile) ?? decodedAccessNumber
        handle = try container.decodeIfPresent(String.self, forKey: .handle)
            ?? decodedUserRecord.flatMap(Self.screenName(inUserRecord:))
            ?? Self.screenName(in: decodedProfile)
        decryptedProfileData = decodedProfileData
        userRecordData = decodedUserRecordData
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accessCode, forKey: .accessNumber)
        try container.encode(accessCode, forKey: .username)
        try container.encodeIfPresent(handle, forKey: .handle)
        try container.encode(decryptedProfileData, forKey: .decryptedProfileData)
        try container.encodeIfPresent(userRecordData, forKey: .userRecordData)
    }

    private static func accessCode(in profile: [UInt8]) -> String? {
        let range = 9..<13
        guard profile.count >= range.upperBound else {
            return nil
        }

        var bytes: [UInt8] = []
        for byte in profile[range] {
            if byte == 0 || byte == 0x80 {
                break
            }

            if (32...126).contains(byte) {
                bytes.append(byte)
            }
        }

        guard let rawAccessCode = String(bytes: bytes, encoding: .ascii) else {
            return nil
        }

        let accessCode = rawAccessCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard accessCode.count > 1 else {
            return nil
        }
        return accessCode
    }

    private static func screenName(in profile: [UInt8]) -> String? {
        guard let userRecord = firstUserRecord(in: profile) else {
            return nil
        }

        return screenName(inUserRecord: userRecord)
    }

    private static func firstUserRecord(in profile: [UInt8]) -> [UInt8]? {
        let range = 51..<66
        guard profile.count >= range.upperBound,
              profile[50] > 0 else {
            return nil
        }

        return Array(profile[range])
    }

    private static func screenName(inUserRecord userRecord: [UInt8]) -> String? {
        let range = 5..<15
        guard userRecord.count >= range.upperBound else {
            return nil
        }

        let characters = userRecord[range].compactMap(screenCodeCharacter(for:))
        let screenName = String(characters)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return screenName.isEmpty ? nil : screenName
    }

    private static func accountID(inUserRecord userRecord: [UInt8]) -> String? {
        guard userRecord.count >= 5 else {
            return nil
        }

        var digits: [UInt8] = []
        for byte in userRecord[0..<5] {
            let highNibble = byte >> 4
            let lowNibble = byte & 0x0f
            guard highNibble <= 9, lowNibble <= 9 else {
                return nil
            }

            digits.append(48 + highNibble)
            digits.append(48 + lowNibble)
        }

        return String(bytes: digits, encoding: .ascii)
    }

    private static func screenCodeCharacter(for byte: UInt8) -> Character? {
        let screenCode = byte & 0x3f
        switch screenCode {
        case 1...26:
            return Character(UnicodeScalar(UInt8(64 + screenCode)))
        case 48...57:
            return Character(UnicodeScalar(screenCode))
        case 32:
            return " "
        default:
            return nil
        }
    }
}

protocol QLinkReloadedRegistrationStoring: AnyObject {
    func loadRegistration(id: String) -> QLinkReloadedRegistrationProfile?
    func saveRegistration(_ registration: QLinkReloadedRegistrationProfile)
    func registrations() -> [QLinkReloadedRegistrationProfile]
    func deleteRegistration(id: String)
}

final class QLinkReloadedRegistrationMemoryStore: QLinkReloadedRegistrationStoring {
    private var registrationsByKey: [String: QLinkReloadedRegistrationProfile] = [:]

    func loadRegistration(id: String) -> QLinkReloadedRegistrationProfile? {
        registrationsByKey[QLinkReloadedRegistrationProfile.key(forID: id)]
    }

    func saveRegistration(_ registration: QLinkReloadedRegistrationProfile) {
        guard !registration.key.isEmpty else {
            return
        }

        registrationsByKey[registration.key] = registration
    }

    func registrations() -> [QLinkReloadedRegistrationProfile] {
        registrationsByKey.values.sorted { $0.displayTitle.localizedStandardCompare($1.displayTitle) == .orderedAscending }
    }

    func deleteRegistration(id: String) {
        registrationsByKey[QLinkReloadedRegistrationProfile.key(forID: id)] = nil
    }
}

final class QLinkReloadedRegistrationKeychain: QLinkReloadedRegistrationStoring {
    private static let service = "com.barrywalker.vicemac.qlink.registration"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func loadRegistration(id: String) -> QLinkReloadedRegistrationProfile? {
        var query = baseQuery(id: id)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }

        return try? decoder.decode(QLinkReloadedRegistrationProfile.self, from: data)
    }

    func saveRegistration(_ registration: QLinkReloadedRegistrationProfile) {
        guard !registration.key.isEmpty,
              let data = try? encoder.encode(registration) else {
            return
        }

        let attributes = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery(id: registration.key) as CFDictionary,
                                   attributes as CFDictionary)
        if status != errSecSuccess {
            var query = baseQuery(id: registration.key)
            query[kSecValueData as String] = data
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    func registrations() -> [QLinkReloadedRegistrationProfile] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            return []
        }

        let resultItems: [[String: Any]]
        if let values = result as? [[String: Any]] {
            resultItems = values
        } else if let value = result as? [String: Any] {
            resultItems = [value]
        } else {
            resultItems = []
        }

        return resultItems
            .compactMap { $0[kSecAttrAccount as String] as? String }
            .compactMap { account -> QLinkReloadedRegistrationProfile? in
                guard let registration = loadRegistration(id: account) else {
                    return nil
                }

                let normalizedAccount = QLinkReloadedRegistrationProfile.key(forID: account)
                if registration.key != normalizedAccount {
                    saveRegistration(registration)
                    SecItemDelete(baseQuery(id: normalizedAccount) as CFDictionary)
                }

                return registration
            }
            .sorted { $0.displayTitle.localizedStandardCompare($1.displayTitle) == .orderedAscending }
    }

    func deleteRegistration(id: String) {
        SecItemDelete(baseQuery(id: id) as CFDictionary)
    }

    private func baseQuery(id: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: QLinkReloadedRegistrationProfile.key(forID: id)
        ]
    }
}

enum QLinkReloadedDiskPatcher {
    static let d64ByteCount = 174_848
    static let profileSectorTrack = 18
    static let profileSector = 15
    static let maximumRegistrationProfileCount = 10

    private static let encryptedProfileSeed: UInt8 = 0x6e
    private static let hayesCommandModemType: UInt8 = 5
    private static let baud1200ProfileValue: UInt8 = 1
    private static let telenetNetworkProfileValue: UInt8 = 2
    private static let toneDialProfileValue: UInt8 = 0
    private static let automaticDialProfileValue: UInt8 = 1
    private static let qLinkReloadedPhoneDigits: [UInt8] = [5, 5, 5, 1, 2, 1, 2]
    private static let encodedPhoneTerminator: UInt8 = 0x80
    private static let accessCodeProfileRange = 9..<13
    private static let registrationProfileStorageRange = 9..<30
    private static let userRecordBlockRange = 50..<201
    private static let userRecordCountOffset = 50
    private static let userRecordStorageRange = 51..<201
    private static let userRecordLength = 15
    private static let userRecordNameRange = 5..<15
    private static let factoryBlankAccessNumberProfile = [0x31, 0x20, 0x20, 0x20]
        + Array(repeating: UInt8(0), count: 17)
    private static let factoryBlankUserRecord = [0x58, 0x89, 0x34, 0x95, 0x67]
        + Array("QLINK     ".utf8)
    private static let factoryBlankUserRecordBlock = [0x01]
        + factoryBlankUserRecord
        + Array(repeating: UInt8(0), count: 135)
    private static let registrationProfileRanges = [
        registrationProfileStorageRange,
        userRecordBlockRange
    ]
    private static let developmentNGVersion = QLinkReloadedDiskVersion(profileAgnosticSHA256: "development-ng",
                                                                       displayTitle: "Q-Link NG Development",
                                                                       requiresLegacyPatch: false)
    private static let legacyBootProgramNames: Set<String> = ["BOOT64", "BOOT128"]
    private static let developmentNGMarkerNames: Set<String> = ["MODBOOT", "NGBOOT"]

    private static let knownVersions: [QLinkReloadedDiskVersion] = [
        QLinkReloadedDiskVersion(profileAgnosticSHA256: "0a82272d2bee8d91c891090cfca8f1dc63d116678cfabf6c084900886f45348b",
                                 displayTitle: "Q-Link Version 4"),
        QLinkReloadedDiskVersion(profileAgnosticSHA256: "7ed3024b8b0e0d2745d82615c94484c51fe990e4e6924ff4ba9fde5f2710b5ae",
                                 displayTitle: "Q-Link Version 4 2400 Test"),
        QLinkReloadedDiskVersion(profileAgnosticSHA256: "189c71a0f306d54eccb3aef06ac95886a41c01933eb34426c2d4f958e1f8d3fa",
                                 displayTitle: "MyQLink Version 4"),
        QLinkReloadedDiskVersion(profileAgnosticSHA256: "be75bf5a2f74a4cbad1dba706fedefe9deb5cf995de146ce50e68f54c6de7db7",
                                 displayTitle: "Q-Link Version 4 Keith 2001"),
        QLinkReloadedDiskVersion(profileAgnosticSHA256: "23c13564d841f2fd6da3b7327fad62ed2fa0287976395bf7d4d442bfaa803908",
                                 displayTitle: "Q-Link Version 4 Keith 2010")
    ]

    static func knownVersion(for url: URL) throws -> QLinkReloadedDiskVersion {
        let data = try Data(contentsOf: url)
        return try knownVersion(for: data)
    }

    static func knownVersion(for data: Data) throws -> QLinkReloadedDiskVersion {
        if data.count == d64ByteCount {
            let profileAgnosticHash = try profileAgnosticSHA256Hex(for: data)
            if let version = knownVersions.first(where: { $0.profileAgnosticSHA256 == profileAgnosticHash }) {
                return version
            }
        }

        if isDevelopmentNGDisk(data) {
            return developmentNGVersion
        }

        throw QLinkReloadedServiceError.unknownVersion
    }

    static func configureReloadedProfile(at url: URL,
                                         version: QLinkReloadedDiskVersion,
                                         restoring registration: QLinkReloadedRegistrationProfile? = nil) throws -> QLinkReloadedDiskPatchResult {
        guard version.requiresLegacyPatch else {
            return QLinkReloadedDiskPatchResult(version: version,
                                                changedDisk: false)
        }

        var data = try Data(contentsOf: url)
        let changedDisk = try configureReloadedProfile(in: &data,
                                                       restoring: registration)
        if changedDisk {
            try data.write(to: url, options: .atomic)
        }

        return QLinkReloadedDiskPatchResult(version: version,
                                            changedDisk: changedDisk)
    }

    static func isDevelopmentNGDisk(_ data: Data) -> Bool {
        guard isSupportedDevelopmentD64ByteCount(data.count),
              let directoryNames = try? directoryNames(in: data) else {
            return false
        }

        return !directoryNames.isDisjoint(with: legacyBootProgramNames)
            && !directoryNames.isDisjoint(with: developmentNGMarkerNames)
    }

    static func removeRegistrationProfile(at url: URL,
                                          version: QLinkReloadedDiskVersion) throws -> QLinkReloadedDiskPatchResult {
        try requireLegacyProfileStorage(for: version)

        var data = try Data(contentsOf: url)
        let changedDisk = try removeRegistrationProfile(in: &data)
        if changedDisk {
            try data.write(to: url, options: .atomic)
        }

        return QLinkReloadedDiskPatchResult(version: version,
                                            changedDisk: changedDisk)
    }

    static func addRegistrationProfile(_ registration: QLinkReloadedRegistrationProfile,
                                       at url: URL,
                                       version: QLinkReloadedDiskVersion) throws -> QLinkReloadedDiskPatchResult {
        try requireLegacyProfileStorage(for: version)

        var data = try Data(contentsOf: url)
        let changedDisk = try addRegistrationProfile(registration,
                                                     in: &data)
        if changedDisk {
            try data.write(to: url, options: .atomic)
        }

        return QLinkReloadedDiskPatchResult(version: version,
                                            changedDisk: changedDisk)
    }

    static func removeRegistrationProfile(id: String,
                                          at url: URL,
                                          version: QLinkReloadedDiskVersion) throws -> QLinkReloadedDiskPatchResult {
        try requireLegacyProfileStorage(for: version)

        var data = try Data(contentsOf: url)
        let changedDisk = try removeRegistrationProfile(id: id,
                                                        in: &data)
        if changedDisk {
            try data.write(to: url, options: .atomic)
        }

        return QLinkReloadedDiskPatchResult(version: version,
                                            changedDisk: changedDisk)
    }

    private static func requireLegacyProfileStorage(for version: QLinkReloadedDiskVersion) throws {
        guard version.requiresLegacyPatch else {
            throw QLinkReloadedServiceError.legacyProfileStorageUnavailable
        }
    }

    @discardableResult
    static func configureReloadedProfile(in data: inout Data,
                                         restoring registration: QLinkReloadedRegistrationProfile? = nil) throws -> Bool {
        try updateDecryptedProfile(in: &data) { profile in
            if let registration {
                restoreRegistrationFields(from: registration.decryptedProfile, into: &profile)
            } else {
                restoreFactoryBlankRegistrationFieldsIfNeeded(in: &profile)
            }

            configureReloadedConnectionFields(in: &profile)
        }
    }

    @discardableResult
    static func removeRegistrationProfile(in data: inout Data) throws -> Bool {
        try updateDecryptedProfile(in: &data) { profile in
            configureReloadedConnectionFields(in: &profile)
            clearRegistrationFields(in: &profile)
        }
    }

    @discardableResult
    static func addRegistrationProfile(_ registration: QLinkReloadedRegistrationProfile,
                                       in data: inout Data) throws -> Bool {
        try updateDecryptedProfile(in: &data) { profile in
            restoreRegistrationStorageField(from: registration.decryptedProfile,
                                            into: &profile)
            try upsertUserRecord(from: registration,
                                 into: &profile)
            configureReloadedConnectionFields(in: &profile)
        }
    }

    @discardableResult
    static func removeRegistrationProfile(id: String,
                                          in data: inout Data) throws -> Bool {
        try updateDecryptedProfile(in: &data) { profile in
            removeUserRecord(id: id,
                             from: &profile)
            configureReloadedConnectionFields(in: &profile)
        }
    }

    private static func updateDecryptedProfile(in data: inout Data,
                                               update: (inout [UInt8]) throws -> Void) throws -> Bool {
        guard data.count == d64ByteCount else {
            throw QLinkReloadedServiceError.unsupportedDiskLayout
        }

        let profileRange = try sectorRange(track: profileSectorTrack, sector: profileSector)
        var profile = Array(data[profileRange])
        xorProfileSector(&profile)
        let originalProfile = profile

        try update(&profile)

        guard profile != originalProfile else {
            return false
        }

        xorProfileSector(&profile)
        data.replaceSubrange(profileRange, with: profile)
        return true
    }

    static func decryptedProfileSector(from data: Data) throws -> [UInt8] {
        guard data.count == d64ByteCount else {
            throw QLinkReloadedServiceError.unsupportedDiskLayout
        }

        let profileRange = try sectorRange(track: profileSectorTrack, sector: profileSector)
        var profile = Array(data[profileRange])
        xorProfileSector(&profile)
        return profile
    }

    static func registrationProfile(from data: Data) throws -> QLinkReloadedRegistrationProfile? {
        try registrationProfiles(from: data).first
    }

    static func registrationProfiles(from data: Data) throws -> [QLinkReloadedRegistrationProfile] {
        let profile = try decryptedProfileSector(from: data)
        guard let accessCode = registrationAccessCode(in: profile) else {
            return []
        }

        return registrationProfiles(in: profile,
                                    accessCode: accessCode)
    }

    private static func profileAgnosticSHA256Hex(for data: Data) throws -> String {
        var fingerprintData = data
        let profileRange = try sectorRange(track: profileSectorTrack, sector: profileSector)
        fingerprintData.replaceSubrange(profileRange, with: Data(repeating: 0, count: profileRange.count))
        return sha256Hex(for: fingerprintData)
    }

    private static func directoryNames(in data: Data) throws -> Set<String> {
        var names: Set<String> = []
        var track = 18
        var sector = 1
        var visited = Set<String>()

        while track != 0 {
            let key = "\(track):\(sector)"
            guard !visited.contains(key) else {
                throw QLinkReloadedServiceError.unsupportedDiskLayout
            }
            visited.insert(key)

            let directorySectorRange = try sectorRange(track: track, sector: sector)
            guard directorySectorRange.upperBound <= data.count else {
                throw QLinkReloadedServiceError.unsupportedDiskLayout
            }

            let directorySector = Array(data[directorySectorRange])
            for slot in 0..<8 {
                let base = slot * 32
                guard directorySector[base + 2] != 0 else {
                    continue
                }

                let rawName = Array(directorySector[(base + 5)..<(base + 21)])
                let name = decodedDirectoryName(rawName)
                if !name.isEmpty {
                    names.insert(name)
                }
            }

            track = Int(directorySector[0])
            sector = Int(directorySector[1])
        }

        return names
    }

    private static func decodedDirectoryName(_ rawName: [UInt8]) -> String {
        let bytes = rawName.prefix { byte in
            byte != 0 && byte != 0xa0
        }
        return String(bytes: bytes, encoding: .isoLatin1)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() ?? ""
    }

    private static func isSupportedDevelopmentD64ByteCount(_ byteCount: Int) -> Bool {
        for trackCount in 35...42 {
            let sectorCount = (1...trackCount)
                .map(sectors(onTrack:))
                .reduce(0, +)
            let imageByteCount = sectorCount * 256
            if byteCount == imageByteCount || byteCount == imageByteCount + sectorCount {
                return true
            }
        }

        return false
    }

    private static func registrationAccessCode(in profile: [UInt8]) -> String? {
        guard profile.count >= accessCodeProfileRange.upperBound else {
            return nil
        }

        var bytes: [UInt8] = []
        for byte in profile[accessCodeProfileRange] {
            if byte == 0 || byte == encodedPhoneTerminator {
                break
            }

            if (32...126).contains(byte) {
                bytes.append(byte)
            }
        }

        guard let rawAccessCode = String(bytes: bytes, encoding: .ascii) else {
            return nil
        }

        let accessCode = rawAccessCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard accessCode.count > 1 else {
            return nil
        }
        return accessCode
    }

    private static func restoreRegistrationFields(from storedProfile: [UInt8],
                                                  into profile: inout [UInt8]) {
        guard storedProfile.count == profile.count else {
            return
        }

        for range in registrationProfileRanges {
            guard profile.indices.contains(range.lowerBound),
                  profile.indices.contains(range.upperBound - 1),
                  storedProfile.indices.contains(range.lowerBound),
                  storedProfile.indices.contains(range.upperBound - 1) else {
                continue
            }

            profile.replaceSubrange(range, with: storedProfile[range])
        }
    }

    private static func restoreRegistrationStorageField(from storedProfile: [UInt8],
                                                        into profile: inout [UInt8]) {
        replaceProfileRange(registrationProfileStorageRange,
                            with: Array(storedProfile[registrationProfileStorageRange]),
                            in: &profile)
    }

    private static func registrationProfiles(in profile: [UInt8],
                                             accessCode: String) -> [QLinkReloadedRegistrationProfile] {
        userRecords(in: profile).map { record in
            var singleProfile = profile
            replaceUserRecords([record], in: &singleProfile)
            return QLinkReloadedRegistrationProfile(accessNumber: accessCode,
                                                    decryptedProfile: singleProfile,
                                                    userRecord: record)
        }
    }

    private static func userRecords(in profile: [UInt8]) -> [[UInt8]] {
        guard profile.indices.contains(userRecordBlockRange.upperBound - 1) else {
            return []
        }

        let count = min(Int(profile[userRecordCountOffset]), maximumRegistrationProfileCount)
        guard count > 0 else {
            return []
        }

        return (0..<count).compactMap { index in
            let range = userRecordRange(at: index)
            guard profile.indices.contains(range.upperBound - 1) else {
                return nil
            }

            let record = Array(profile[range])
            return isPlaceholderUserRecord(record) ? nil : record
        }
    }

    private static func upsertUserRecord(from registration: QLinkReloadedRegistrationProfile,
                                         into profile: inout [UInt8]) throws {
        let record = registration.userRecord
        guard record.count == userRecordLength else {
            return
        }

        var records = userRecords(in: profile)
        if let existingIndex = records.firstIndex(where: { key(forUserRecord: $0, accessCode: registration.accessCode) == registration.key }) {
            records[existingIndex] = record
        } else {
            guard records.count < maximumRegistrationProfileCount else {
                throw QLinkReloadedServiceError.diskProfileLimitReached
            }
            records.append(record)
        }

        replaceUserRecords(records, in: &profile)
    }

    private static func removeUserRecord(id: String,
                                         from profile: inout [UInt8]) {
        let normalizedID = QLinkReloadedRegistrationProfile.key(forID: id)
        let accessCode = registrationAccessCode(in: profile) ?? ""
        var records = userRecords(in: profile)
        records.removeAll { key(forUserRecord: $0, accessCode: accessCode) == normalizedID }

        if records.isEmpty {
            restoreFactoryBlankRegistrationFields(in: &profile)
        } else {
            replaceUserRecords(records, in: &profile)
        }
    }

    private static func replaceUserRecords(_ records: [[UInt8]],
                                           in profile: inout [UInt8]) {
        guard profile.indices.contains(userRecordBlockRange.upperBound - 1) else {
            return
        }

        profile.replaceSubrange(userRecordBlockRange,
                                with: Array(repeating: UInt8(0), count: userRecordBlockRange.count))
        profile[userRecordCountOffset] = UInt8(min(records.count, maximumRegistrationProfileCount))

        for (index, record) in records.prefix(maximumRegistrationProfileCount).enumerated() {
            guard record.count == userRecordLength else {
                continue
            }

            profile.replaceSubrange(userRecordRange(at: index), with: record)
        }
    }

    private static func userRecordRange(at index: Int) -> Range<Int> {
        let lowerBound = userRecordStorageRange.lowerBound + index * userRecordLength
        return lowerBound..<(lowerBound + userRecordLength)
    }

    private static func key(forUserRecord record: [UInt8],
                            accessCode: String) -> String {
        QLinkReloadedRegistrationProfile.key(accessNumber: accessCode,
                                             handle: screenName(inUserRecord: record))
    }

    private static func screenName(inUserRecord record: [UInt8]) -> String? {
        guard record.count >= userRecordNameRange.upperBound else {
            return nil
        }

        let characters = record[userRecordNameRange].compactMap(screenCodeCharacter(for:))
        let screenName = String(characters)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return screenName.isEmpty ? nil : screenName
    }

    private static func screenCodeCharacter(for byte: UInt8) -> Character? {
        let screenCode = byte & 0x3f
        switch screenCode {
        case 1...26:
            return Character(UnicodeScalar(UInt8(64 + screenCode)))
        case 48...57:
            return Character(UnicodeScalar(screenCode))
        case 32:
            return " "
        default:
            return nil
        }
    }

    private static func isPlaceholderUserRecord(_ record: [UInt8]) -> Bool {
        record.allSatisfy { $0 == 0 } || record == factoryBlankUserRecord || screenName(inUserRecord: record) == "QLINK"
    }

    private static func configureReloadedConnectionFields(in profile: inout [UInt8]) {
        profile[0] = hayesCommandModemType
        profile[1] = baud1200ProfileValue
        profile[2] = telenetNetworkProfileValue
        profile[3] = toneDialProfileValue
        profile[5] = automaticDialProfileValue
        for index in 0..<20 {
            profile[30 + index] = index < qLinkReloadedPhoneDigits.count
                ? qLinkReloadedPhoneDigits[index]
                : encodedPhoneTerminator
        }
    }

    private static func clearRegistrationFields(in profile: inout [UInt8]) {
        restoreFactoryBlankRegistrationFields(in: &profile)
    }

    private static func restoreFactoryBlankRegistrationFieldsIfNeeded(in profile: inout [UInt8]) {
        guard registrationAccessCode(in: profile) == nil,
              profile.indices.contains(userRecordBlockRange.upperBound - 1),
              profile[userRecordBlockRange].allSatisfy({ $0 == 0 }) else {
            return
        }

        restoreFactoryBlankRegistrationFields(in: &profile)
    }

    private static func restoreFactoryBlankRegistrationFields(in profile: inout [UInt8]) {
        replaceProfileRange(registrationProfileStorageRange,
                            with: factoryBlankAccessNumberProfile,
                            in: &profile)
        replaceProfileRange(userRecordBlockRange,
                            with: factoryBlankUserRecordBlock,
                            in: &profile)
    }

    private static func replaceProfileRange(_ range: Range<Int>,
                                            with bytes: [UInt8],
                                            in profile: inout [UInt8]) {
        guard bytes.count == range.count,
              profile.indices.contains(range.lowerBound),
              profile.indices.contains(range.upperBound - 1) else {
            return
        }

        profile.replaceSubrange(range, with: bytes)
    }

    private static func xorProfileSector(_ sector: inout [UInt8]) {
        var crypto = encryptedProfileSeed
        for index in sector.indices {
            sector[index] ^= crypto
            crypto &+= 1
        }
    }

    private static func sectorRange(track: Int, sector: Int) throws -> Range<Data.Index> {
        guard (1...35).contains(track),
              sector >= 0,
              sector < sectors(onTrack: track) else {
            throw QLinkReloadedServiceError.unsupportedDiskLayout
        }

        let precedingSectorCount = (1..<track)
            .map(sectors(onTrack:))
            .reduce(0, +)
        let offset = (precedingSectorCount + sector) * 256
        return offset..<(offset + 256)
    }

    private static func sectors(onTrack track: Int) -> Int {
        switch track {
        case 1...17:
            return 21
        case 18...24:
            return 19
        case 25...30:
            return 18
        default:
            return 17
        }
    }

    private static func sha256Hex(for data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

enum EmulatorMediaFile: Equatable {
    case disk(DiskImageFileType)
    case autostart(AutostartMediaFileType)
    case cartridge(CartridgeImageFileType)
    case snapshot(SnapshotFileType)

    init?(url: URL) {
        if let snapshotType = SnapshotFileType(url: url) {
            self = .snapshot(snapshotType)
            return
        }

        if let diskImageType = DiskImageFileType(url: url) {
            self = .disk(diskImageType)
            return
        }

        if let autostartMediaType = AutostartMediaFileType(url: url) {
            self = .autostart(autostartMediaType)
            return
        }

        if let cartridgeImageType = CartridgeImageFileType(url: url) {
            self = .cartridge(cartridgeImageType)
            return
        }

        return nil
    }

    var title: String {
        switch self {
        case let .disk(type):
            return "\(type.title) disk image"
        case let .autostart(type):
            return type.title
        case let .cartridge(type):
            return "\(type.title) cartridge"
        case let .snapshot(type):
            return "\(type.title) snapshot"
        }
    }

    static func supportedFilenameExtensions(for machine: EmulatedMachine) -> [String] {
        var extensions = Set(machine.capabilities.driveTypes
            .flatMap(\.supportedDiskImageTypes)
            .map(\.rawValue))

        extensions.formUnion(AutostartMediaFileType.allCases.map(\.rawValue))
        if machine.capabilities.supportsCartridges {
            extensions.formUnion(CartridgeImageFileType.allCases.map(\.rawValue))
        }
        extensions.formUnion(SnapshotFileType.allCases.map(\.rawValue))

        return extensions.sorted()
    }
}

enum MediaOpenBehavior: String, CaseIterable, Codable, Identifiable {
    case attach
    case load
    case run

    var id: String { rawValue }

    var title: String {
        switch self {
        case .attach:
            return "Attach"
        case .load:
            return "Load"
        case .run:
            return "Run"
        }
    }

    var detail: String {
        switch self {
        case .attach:
            return "Insert disks and tapes without typing a command."
        case .load:
            return "Load programs and leave them ready at the prompt."
        case .run:
            return "Load programs and start them automatically."
        }
    }

    var systemImage: String {
        switch self {
        case .attach:
            return "externaldrive"
        case .load:
            return "arrow.down.doc"
        case .run:
            return "play.fill"
        }
    }

    var viceRunMode: Int32 {
        switch self {
        case .attach:
            return -1
        case .run:
            return 0
        case .load:
            return 1
        }
    }

    var macVICERunMode: MacVICEMediaRunMode {
        switch self {
        case .attach:
            return .attach
        case .load:
            return .load
        case .run:
            return .run
        }
    }

    var statusVerb: String {
        switch self {
        case .attach:
            return "attached"
        case .load:
            return "loading"
        case .run:
            return "started"
        }
    }
}

struct MediaBehaviorConfiguration: Codable, Equatable {
    var openBehavior: MediaOpenBehavior
    var warpDuringAutostart: Bool
    var useTrueDriveDuringAutostart: Bool

    static let standard = MediaBehaviorConfiguration(openBehavior: .attach,
                                                     warpDuringAutostart: true,
                                                     useTrueDriveDuringAutostart: false)

    init(openBehavior: MediaOpenBehavior,
         warpDuringAutostart: Bool,
         useTrueDriveDuringAutostart: Bool) {
        self.openBehavior = openBehavior
        self.warpDuringAutostart = warpDuringAutostart
        self.useTrueDriveDuringAutostart = useTrueDriveDuringAutostart
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.standard

        openBehavior = try container.decodeIfPresent(MediaOpenBehavior.self, forKey: .openBehavior)
            ?? defaults.openBehavior
        warpDuringAutostart = try container.decodeIfPresent(Bool.self, forKey: .warpDuringAutostart)
            ?? defaults.warpDuringAutostart
        useTrueDriveDuringAutostart = try container.decodeIfPresent(Bool.self, forKey: .useTrueDriveDuringAutostart)
            ?? defaults.useTrueDriveDuringAutostart
    }
}

struct SnapshotConfiguration: Codable, Equatable {
    var includesROMImages: Bool
    var includesAttachedDisks: Bool

    static let standard = SnapshotConfiguration(includesROMImages: true,
                                                includesAttachedDisks: true)

    init(includesROMImages: Bool,
         includesAttachedDisks: Bool) {
        self.includesROMImages = includesROMImages
        self.includesAttachedDisks = includesAttachedDisks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.standard

        includesROMImages = try container.decodeIfPresent(Bool.self, forKey: .includesROMImages)
            ?? defaults.includesROMImages
        includesAttachedDisks = try container.decodeIfPresent(Bool.self, forKey: .includesAttachedDisks)
            ?? defaults.includesAttachedDisks
    }

    var summaryTitle: String {
        switch (includesROMImages, includesAttachedDisks) {
        case (true, true):
            return "Machine state, ROM images, and attached disks"
        case (true, false):
            return "Machine state and ROM images"
        case (false, true):
            return "Machine state and attached disks"
        case (false, false):
            return "Machine state only"
        }
    }
}

struct SessionBehaviorConfiguration: Codable, Equatable {
    var pauseWhenAppInactive: Bool

    static let standard = SessionBehaviorConfiguration(pauseWhenAppInactive: false)

    init(pauseWhenAppInactive: Bool) {
        self.pauseWhenAppInactive = pauseWhenAppInactive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pauseWhenAppInactive = try container.decodeIfPresent(Bool.self, forKey: .pauseWhenAppInactive)
            ?? Self.standard.pauseWhenAppInactive
    }
}

enum PrinterEmulationModel: String, CaseIterable, Codable, Identifiable {
    case mps803
    case nl10
    case ascii
    case raw

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mps803:
            return "Commodore MPS-803"
        case .nl10:
            return "Star NL-10"
        case .ascii:
            return "ASCII"
        case .raw:
            return "Raw"
        }
    }

    var shortTitle: String {
        switch self {
        case .mps803:
            return "MPS-803"
        case .nl10:
            return "NL-10"
        case .ascii:
            return "ASCII"
        case .raw:
            return "Raw"
        }
    }

    var geosDriverTitle: String {
        switch self {
        case .mps803:
            return "MPS-803"
        case .nl10:
            return "Star NL-10(com)"
        case .ascii:
            return "Commodore compatible"
        case .raw:
            return "Raw device output"
        }
    }

    var viceDriverName: String {
        rawValue
    }

    var outputMode: String {
        switch self {
        case .ascii, .raw:
            return "text"
        case .mps803, .nl10:
            return "graphics"
        }
    }

    var supportsPagePreview: Bool {
        outputMode == "graphics"
    }
}

struct PrinterConfiguration: Codable, Equatable {
    var isEnabled: Bool
    var deviceNumber: Int
    var model: PrinterEmulationModel

    static let standard = PrinterConfiguration(isEnabled: false,
                                               deviceNumber: 4,
                                               model: .mps803)

    init(isEnabled: Bool,
         deviceNumber: Int,
         model: PrinterEmulationModel) {
        self.isEnabled = isEnabled
        self.deviceNumber = Self.normalizedDeviceNumber(deviceNumber)
        self.model = model
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.standard

        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled)
            ?? defaults.isEnabled
        deviceNumber = Self.normalizedDeviceNumber(try container.decodeIfPresent(Int.self, forKey: .deviceNumber)
                                                   ?? defaults.deviceNumber)
        model = try container.decodeIfPresent(PrinterEmulationModel.self, forKey: .model)
            ?? defaults.model
    }

    var statusTitle: String {
        isEnabled ? "\(model.shortTitle) on device \(deviceNumber)" : "Off"
    }

    var geosDriverTitle: String {
        model.geosDriverTitle
    }

    var canPreviewPages: Bool {
        isEnabled && model.supportsPagePreview
    }

    private static func normalizedDeviceNumber(_ deviceNumber: Int) -> Int {
        switch deviceNumber {
        case 4...6:
            return deviceNumber
        default:
            return 4
        }
    }
}

struct PrinterSpoolPage: Identifiable, Equatable {
    static let filenamePrefix = "geos-print"

    let url: URL
    let byteCount: Int
    let modifiedAt: Date

    var id: String {
        url.path
    }

    var displayName: String {
        url.deletingPathExtension().lastPathComponent
    }

    var detailTitle: String {
        "\(byteCount.formatted(.byteCount(style: .file))) - \(modifiedAt.formatted(date: .abbreviated, time: .shortened))"
    }
}

enum NetworkModemInterface: String, CaseIterable, Codable, Identifiable {
    case userPort
    case swiftLink
    case turbo232

    var id: String { rawValue }

    var title: String {
        switch self {
        case .userPort:
            return "User Port"
        case .swiftLink:
            return "SwiftLink"
        case .turbo232:
            return "Turbo232"
        }
    }

    var shortTitle: String {
        switch self {
        case .userPort:
            return "User"
        case .swiftLink:
            return "SwiftLink"
        case .turbo232:
            return "Turbo232"
        }
    }

    var detailTitle: String {
        switch self {
        case .userPort:
            return "Standard VICE user port modem"
        case .swiftLink:
            return "6551 ACIA cartridge"
        case .turbo232:
            return "Turbo232 ACIA cartridge"
        }
    }

    var systemImage: String {
        switch self {
        case .userPort:
            return "rectangle.connected.to.line.below"
        case .swiftLink:
            return "point.3.connected.trianglepath.dotted"
        case .turbo232:
            return "bolt.horizontal"
        }
    }

    var usesUserPort: Bool {
        self == .userPort
    }

    var usesIP232Control: Bool {
        switch self {
        case .userPort:
            return false
        case .swiftLink, .turbo232:
            return true
        }
    }

    var aciaMode: Int32? {
        switch self {
        case .userPort:
            return nil
        case .swiftLink:
            return 1
        case .turbo232:
            return 2
        }
    }

    var requiresACIAAddress: Bool {
        switch self {
        case .userPort:
            return false
        case .swiftLink, .turbo232:
            return true
        }
    }

    var supportedBaudRates: [Int] {
        switch self {
        case .userPort:
            return [300, 1200, 2400]
        case .swiftLink, .turbo232:
            return [300, 1200, 2400, 9600, 19200, 38400]
        }
    }
}

enum NetworkModemACIAAddress: Int32, CaseIterable, Codable, Identifiable {
    case d700 = 0xd700
    case de00 = 0xde00
    case df00 = 0xdf00
    case vic20_9800 = 0x9800
    case vic20_9c00 = 0x9c00

    var id: Int32 { rawValue }

    var title: String {
        String(format: "$%04X", rawValue)
    }

    var shortTitle: String {
        String(format: "%02X", rawValue >> 8)
    }

    func terminalSelectionTitle(for modemInterface: NetworkModemInterface) -> String {
        switch modemInterface {
        case .userPort:
            return "User Port"
        case .swiftLink:
            return "Swift \(shortTitle)"
        case .turbo232:
            return "Turbo \(shortTitle)"
        }
    }

    static func defaultAddress(for machine: EmulatedMachine) -> NetworkModemACIAAddress {
        switch machine.family {
        case .vic20:
            return .vic20_9800
        case .c64, .c128, .pet, .ted:
            return .de00
        }
    }

    static func supportedAddresses(for machine: EmulatedMachine) -> [NetworkModemACIAAddress] {
        switch machine.family {
        case .c64:
            return [.de00, .df00]
        case .c128:
            return [.de00, .df00, .d700]
        case .vic20:
            return [.vic20_9800, .vic20_9c00]
        case .pet, .ted:
            return []
        }
    }
}

enum NetworkTransportMode: String, CaseIterable, Codable, Identifiable {
    case telnet
    case raw

    var id: String { rawValue }

    var title: String {
        switch self {
        case .telnet:
            return "Telnet"
        case .raw:
            return "Raw TCP"
        }
    }
}

enum NetworkModemRuntimeState: String, Equatable {
    case disabled
    case waitingForMachine
    case ready
    case ringing
    case connected
    case error
}

struct NetworkModemRuntimeStatus: Equatable {
    var state: NetworkModemRuntimeState
    var localPort: Int?
    var incomingPort: Int?
    var remoteDescription: String?
    var message: String?

    static let disabled = NetworkModemRuntimeStatus(state: .disabled,
                                                    localPort: nil,
                                                    incomingPort: nil,
                                                    remoteDescription: nil,
                                                    message: nil)

    var title: String {
        switch state {
        case .disabled:
            return "Off"
        case .waitingForMachine:
            return "Waiting for machine"
        case .ready:
            return "Ready"
        case .ringing:
            return "Incoming call"
        case .connected:
            return remoteDescription.map { "Connected to \($0)" } ?? "Connected"
        case .error:
            return "Unavailable"
        }
    }

    var detailTitle: String {
        if let message,
           !message.isEmpty {
            return message
        }

        switch state {
        case .disabled:
            return "No modem configured"
        case .waitingForMachine:
            return localPort.map { "Local modem socket on port \($0)" } ?? "Local modem socket starting"
        case .ready:
            return incomingPort.map { "Accepting incoming calls on port \($0)" } ?? "Dial from terminal software"
        case .ringing:
            return remoteDescription.map { "\($0) is calling" } ?? "Remote caller is ringing"
        case .connected:
            return remoteDescription ?? "Carrier detected"
        case .error:
            return "Modem service could not start"
        }
    }
}

enum QLinkReloadedModemRequirements {
    static let serverHost = "q-link.net"
    static let serverPort = 5190
    static let preferredInterface = NetworkModemInterface.swiftLink
    static let preferredBaudRate = 38400
    static let supportedInterfaces: [NetworkModemInterface] = [.userPort, .swiftLink, .turbo232]
    static let transportMode = NetworkTransportMode.raw

    static func preset(preservingValuesFrom configuration: NetworkModemConfiguration) -> NetworkModemConfiguration {
        let interface = presetInterface(preserving: configuration.interface)
        return NetworkModemConfiguration(isEnabled: true,
                                         interface: interface,
                                         baudRate: preferredBaudRate(for: interface),
                                         transportMode: transportMode,
                                         acceptsIncomingCalls: false,
                                         incomingPort: configuration.incomingPort,
                                         autoAnswerRings: 0,
                                         echoCommands: true,
                                         verboseResultCodes: true,
                                         connectResultIncludesBaudRate: false,
                                         defaultDialPort: serverPort,
                                         defaultDialHost: serverHost,
                                         aciaBaseAddress: configuration.aciaBaseAddress)
    }

    static func incompatibilities(in configuration: NetworkModemConfiguration,
                                  for machine: EmulatedMachine) -> [String] {
        let modem = configuration.normalized(for: machine)
        var issues: [String] = []

        if !modem.isEnabled {
            issues.append("Modem is off")
        }

        if !supportedInterfaces.contains(modem.interface) {
            issues.append("Hardware is \(modem.interface.title), not \(supportedInterfaceTitle)")
        }

        if modem.transportMode != transportMode {
            issues.append("Connection is \(modem.transportMode.title), not Raw TCP")
        }

        if modem.defaultDialHost.isEmpty {
            issues.append("Dial host is blank")
        }

        if !modem.verboseResultCodes {
            issues.append("Verbose result codes are off")
        }

        if modem.connectResultIncludesBaudRate {
            issues.append("CONNECT response includes baud rate")
        }

        return issues
    }

    static func isCompatible(_ configuration: NetworkModemConfiguration,
                             for machine: EmulatedMachine) -> Bool {
        incompatibilities(in: configuration, for: machine).isEmpty
    }

    static var summary: String {
        "\(preferredInterface.title), \(preferredBaudRate) baud, Raw TCP, \(serverHost):\(serverPort), plain CONNECT response"
    }

    private static func presetInterface(preserving interface: NetworkModemInterface) -> NetworkModemInterface {
        switch interface {
        case .swiftLink, .turbo232:
            return interface
        case .userPort:
            return preferredInterface
        }
    }

    private static func preferredBaudRate(for interface: NetworkModemInterface) -> Int {
        interface.supportedBaudRates.contains(preferredBaudRate) ? preferredBaudRate : interface.supportedBaudRates.last ?? preferredBaudRate
    }

    private static var supportedInterfaceTitle: String {
        supportedInterfaces.map(\.title).joined(separator: ", ")
    }
}

enum QLinkReloadedDriveRequirements {
    static let unit = 8
    static let diskImageType = DiskImageFileType.d64

    static func preset(preservingValuesFrom configurations: [DriveConfiguration],
                       for machine: EmulatedMachine) -> [DriveConfiguration] {
        var updatedConfigurations = configurations
        guard let index = updatedConfigurations.firstIndex(where: { $0.unit == unit }) else {
            return updatedConfigurations
        }

        updatedConfigurations[index].isAttached = true
        updatedConfigurations[index].storageKind = .diskImage
        if !updatedConfigurations[index].driveType.supportsDiskImage(diskImageType) {
            updatedConfigurations[index].driveType = machine.capabilities.defaultDriveType
        }
        updatedConfigurations[index].accessMode = .native
        updatedConfigurations[index].protectsInsertedDisks = false
        return EmulatorSession.normalizedDriveConfigurations(updatedConfigurations, for: machine)
    }

    static func incompatibilities(in configurations: [DriveConfiguration],
                                  for machine: EmulatedMachine) -> [String] {
        let drives = EmulatorSession.normalizedDriveConfigurations(configurations, for: machine)
        guard let drive = drives.first(where: { $0.unit == unit }) else {
            return ["Drive \(unit) is missing"]
        }

        var issues: [String] = []
        if !drive.isAttached {
            issues.append("Drive \(unit) is disabled")
        }

        if drive.storageKind == .sharedFolder {
            issues.append("Drive \(unit) is a Shared Mac Folder, not a disk image drive")
        }

        if !drive.driveType.supportsDiskImage(diskImageType) {
            issues.append("Drive \(unit) does not support \(diskImageType.title) disk images")
        }

        if drive.accessMode != .native {
            issues.append("Drive \(unit) is \(drive.accessMode.title), not Native")
        }

        if drive.protectsInsertedDisks {
            issues.append("Drive \(unit) protects inserted disks")
        }

        return issues
    }

    static func isCompatible(_ configurations: [DriveConfiguration],
                             for machine: EmulatedMachine) -> Bool {
        incompatibilities(in: configurations, for: machine).isEmpty
    }

    static var summary: String {
        "Drive \(unit), Native, writable \(diskImageType.title) disk image"
    }
}

struct NetworkModemConfiguration: Codable, Equatable {
    var isEnabled: Bool
    var interface: NetworkModemInterface
    var baudRate: Int
    var transportMode: NetworkTransportMode
    var acceptsIncomingCalls: Bool
    var incomingPort: Int
    var autoAnswerRings: Int
    var echoCommands: Bool
    var verboseResultCodes: Bool
    var connectResultIncludesBaudRate: Bool
    var defaultDialPort: Int
    var defaultDialHost: String
    var aciaBaseAddress: NetworkModemACIAAddress

    static let tcpPortRange = 1...65535

    static let standard = NetworkModemConfiguration(isEnabled: false,
                                                    interface: .swiftLink,
                                                    baudRate: 9600,
                                                    transportMode: .telnet,
                                                    acceptsIncomingCalls: false,
                                                    incomingPort: 6400,
                                                    autoAnswerRings: 0,
                                                    echoCommands: true,
                                                    verboseResultCodes: true,
                                                    connectResultIncludesBaudRate: true,
                                                    defaultDialPort: 23,
                                                    defaultDialHost: "",
                                                    aciaBaseAddress: .de00)

    init(isEnabled: Bool,
         interface: NetworkModemInterface,
         baudRate: Int,
         transportMode: NetworkTransportMode,
         acceptsIncomingCalls: Bool,
         incomingPort: Int,
         autoAnswerRings: Int,
         echoCommands: Bool,
         verboseResultCodes: Bool,
         connectResultIncludesBaudRate: Bool = true,
         defaultDialPort: Int,
         defaultDialHost: String = "",
         aciaBaseAddress: NetworkModemACIAAddress = .de00) {
        self.isEnabled = isEnabled
        self.interface = interface
        self.baudRate = Self.normalizedBaudRate(baudRate, for: interface)
        self.transportMode = transportMode
        self.acceptsIncomingCalls = acceptsIncomingCalls
        self.incomingPort = Self.normalizedTCPPort(incomingPort, fallback: 6400)
        self.autoAnswerRings = Self.normalizedAutoAnswerRings(autoAnswerRings)
        self.echoCommands = echoCommands
        self.verboseResultCodes = verboseResultCodes
        self.connectResultIncludesBaudRate = connectResultIncludesBaudRate
        self.defaultDialPort = Self.normalizedTCPPort(defaultDialPort, fallback: 23)
        self.defaultDialHost = Self.normalizedDialHost(defaultDialHost)
        self.aciaBaseAddress = aciaBaseAddress
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.standard

        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? defaults.isEnabled
        interface = try container.decodeIfPresent(NetworkModemInterface.self, forKey: .interface)
            ?? defaults.interface
        baudRate = Self.normalizedBaudRate(try container.decodeIfPresent(Int.self, forKey: .baudRate)
                                           ?? defaults.baudRate,
                                           for: interface)
        transportMode = try container.decodeIfPresent(NetworkTransportMode.self, forKey: .transportMode)
            ?? defaults.transportMode
        acceptsIncomingCalls = try container.decodeIfPresent(Bool.self, forKey: .acceptsIncomingCalls)
            ?? defaults.acceptsIncomingCalls
        incomingPort = Self.normalizedTCPPort(try container.decodeIfPresent(Int.self, forKey: .incomingPort)
                                              ?? defaults.incomingPort,
                                              fallback: defaults.incomingPort)
        autoAnswerRings = Self.normalizedAutoAnswerRings(try container.decodeIfPresent(Int.self,
                                                                                       forKey: .autoAnswerRings)
                                                         ?? defaults.autoAnswerRings)
        echoCommands = try container.decodeIfPresent(Bool.self, forKey: .echoCommands)
            ?? defaults.echoCommands
        verboseResultCodes = try container.decodeIfPresent(Bool.self, forKey: .verboseResultCodes)
            ?? defaults.verboseResultCodes
        connectResultIncludesBaudRate = try container.decodeIfPresent(Bool.self,
                                                                       forKey: .connectResultIncludesBaudRate)
            ?? defaults.connectResultIncludesBaudRate
        defaultDialPort = Self.normalizedTCPPort(try container.decodeIfPresent(Int.self, forKey: .defaultDialPort)
                                                 ?? defaults.defaultDialPort,
                                                 fallback: defaults.defaultDialPort)
        defaultDialHost = Self.normalizedDialHost(try container.decodeIfPresent(String.self, forKey: .defaultDialHost)
                                                  ?? defaults.defaultDialHost)
        aciaBaseAddress = try container.decodeIfPresent(NetworkModemACIAAddress.self, forKey: .aciaBaseAddress)
            ?? defaults.aciaBaseAddress
    }

    var usesActiveUserPort: Bool {
        isEnabled && interface.usesUserPort
    }

    var supportedBaudRates: [Int] {
        interface.supportedBaudRates
    }

    var statusTitle: String {
        guard isEnabled else {
            return "Off"
        }

        return "\(interface.title), \(baudRate) baud"
    }

    var dialCommandPreview: String {
        defaultDialHost.isEmpty
            ? "ATD host:\(defaultDialPort)"
            : "ATD \(defaultDialHost):\(defaultDialPort)"
    }

    var testDialCommand: String {
        "ATDTEST"
    }

    static func clampedTCPPort(_ port: Int) -> Int {
        min(max(port, tcpPortRange.lowerBound), tcpPortRange.upperBound)
    }

    func terminalSelectionHint(for machine: EmulatedMachine) -> String? {
        switch interface {
        case .userPort:
            return "Choose User Port at \(baudRate) baud in terminal software."
        case .swiftLink, .turbo232:
            guard NetworkModemACIAAddress.supportedAddresses(for: machine).contains(aciaBaseAddress) else {
                return nil
            }

            return "Choose \(aciaBaseAddress.terminalSelectionTitle(for: interface)) in terminal software."
        }
    }

    func normalized(for machine: EmulatedMachine) -> NetworkModemConfiguration {
        var configuration = self
        let supportedInterfaces = machine.capabilities.supportedModemInterfaces

        guard !supportedInterfaces.isEmpty else {
            configuration.isEnabled = false
            configuration.interface = .swiftLink
            return configuration.normalizedValues()
        }

        if !supportedInterfaces.contains(configuration.interface) {
            configuration.interface = supportedInterfaces.first ?? .swiftLink
        }

        let supportedAddresses = NetworkModemACIAAddress.supportedAddresses(for: machine)
        if configuration.interface.requiresACIAAddress,
           !supportedAddresses.contains(configuration.aciaBaseAddress) {
            configuration.aciaBaseAddress = NetworkModemACIAAddress.defaultAddress(for: machine)
        }

        return configuration.normalizedValues()
    }

    private func normalizedValues() -> NetworkModemConfiguration {
        NetworkModemConfiguration(isEnabled: isEnabled,
                                  interface: interface,
                                  baudRate: baudRate,
                                  transportMode: transportMode,
                                  acceptsIncomingCalls: acceptsIncomingCalls,
                                  incomingPort: incomingPort,
                                  autoAnswerRings: autoAnswerRings,
                                  echoCommands: echoCommands,
                                  verboseResultCodes: verboseResultCodes,
                                  connectResultIncludesBaudRate: connectResultIncludesBaudRate,
                                  defaultDialPort: defaultDialPort,
                                  defaultDialHost: defaultDialHost,
                                  aciaBaseAddress: aciaBaseAddress)
    }

    private static func normalizedBaudRate(_ baudRate: Int, for interface: NetworkModemInterface) -> Int {
        guard let nearest = interface.supportedBaudRates.min(by: { abs($0 - baudRate) < abs($1 - baudRate) }) else {
            return 9600
        }

        return nearest
    }

    private static func normalizedTCPPort(_ port: Int, fallback: Int) -> Int {
        if tcpPortRange.contains(port) {
            return port
        }

        return fallback
    }

    private static func normalizedDialHost(_ host: String) -> String {
        host
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
    }

    private static func normalizedAutoAnswerRings(_ rings: Int) -> Int {
        min(max(rings, 0), 9)
    }
}

struct NetworkSettingsPresentation {
    static func dialingSectionTitle(supportsQLinkReloaded: Bool) -> String {
        supportsQLinkReloaded ? "Q-Link Reloaded" : "Dialing"
    }

    static func autoAnswerOptionTitle(for rings: Int) -> String {
        guard rings > 0 else {
            return "Off"
        }

        return rings == 1 ? "After 1 ring" : "After \(rings) rings"
    }

    static func qLinkDiskTitle(configuredDiskTitle: String?,
                               configuredDiskVersionTitle: String?) -> String {
        guard let configuredDiskTitle else {
            return "No disk selected"
        }

        guard let configuredDiskVersionTitle else {
            return configuredDiskTitle
        }

        return "\(configuredDiskTitle) (\(configuredDiskVersionTitle))"
    }

    static func qLinkProfileSummary(diskProfileCount: Int,
                                    keychainProfileCount: Int) -> String {
        "\(diskProfileCount) on disk, \(keychainProfileCount) in Keychain"
    }
}

struct QLinkProfileManagerPresentation {
    static func diskTitle(configuredDiskTitle: String?,
                          configuredDiskVersionTitle: String?) -> String {
        guard let configuredDiskTitle else {
            return "No Q-Link disk selected"
        }

        guard let configuredDiskVersionTitle else {
            return configuredDiskTitle
        }

        return "\(configuredDiskTitle) (\(configuredDiskVersionTitle))"
    }

    static func diskProfilesEmptyTitle(hasConfiguredDisk: Bool) -> String {
        hasConfiguredDisk ? "No Profiles" : "No Q-Link Disk"
    }

    static func diskProfilesEmptyDescription(hasConfiguredDisk: Bool) -> String {
        hasConfiguredDisk
            ? "This disk does not currently have saved Q-Link users."
            : "Choose a validated Q-Link disk to manage its saved users."
    }

    static func diskProfileCapacityTitle(count: Int, maximum: Int) -> String {
        "\(count)/\(maximum)"
    }

    static func keychainProfileCountTitle(count: Int) -> String {
        count == 1 ? "1 saved" : "\(count) saved"
    }
}

enum SIDLayout: String, CaseIterable, Codable, Identifiable {
    case single
    case stereo
    case triple

    var id: String { rawValue }

    var title: String {
        switch self {
        case .single:
            return "Single SID"
        case .stereo:
            return "Stereo SID"
        case .triple:
            return "Triple SID"
        }
    }

    var shortTitle: String {
        switch self {
        case .single:
            return "Single"
        case .stereo:
            return "Stereo"
        case .triple:
            return "Triple"
        }
    }

    var extraSIDCount: Int32 {
        switch self {
        case .single:
            return 0
        case .stereo:
            return 1
        case .triple:
            return 2
        }
    }
}

enum SIDAddressPreset: Int32, CaseIterable, Codable, Identifiable {
    case d420 = 0xd420
    case d500 = 0xd500
    case d600 = 0xd600
    case d700 = 0xd700
    case de00 = 0xde00
    case df00 = 0xdf00

    var id: Int32 { rawValue }

    var title: String {
        String(format: "$%04X", rawValue)
    }
}

struct SIDConfiguration: Codable, Equatable {
    var layout: SIDLayout
    var secondAddress: SIDAddressPreset
    var thirdAddress: SIDAddressPreset

    static let standard = SIDConfiguration(layout: .single,
                                           secondAddress: .d420,
                                           thirdAddress: .de00)

    init(layout: SIDLayout,
         secondAddress: SIDAddressPreset,
         thirdAddress: SIDAddressPreset) {
        self.layout = layout
        self.secondAddress = secondAddress
        self.thirdAddress = thirdAddress
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.standard

        layout = try container.decodeIfPresent(SIDLayout.self, forKey: .layout) ?? defaults.layout
        secondAddress = try container.decodeIfPresent(SIDAddressPreset.self, forKey: .secondAddress)
            ?? defaults.secondAddress
        thirdAddress = try container.decodeIfPresent(SIDAddressPreset.self, forKey: .thirdAddress)
            ?? defaults.thirdAddress
    }
}

enum TapeControlCommand: Int32, CaseIterable, Identifiable {
    case stop = 0
    case play = 1
    case fastForward = 2
    case rewind = 3
    case record = 4
    case reset = 5
    case resetCounter = 6

    var id: Int32 { rawValue }

    var title: String {
        switch self {
        case .stop:
            return "Stop"
        case .play:
            return "Play"
        case .fastForward:
            return "Fast Forward"
        case .rewind:
            return "Rewind"
        case .record:
            return "Record"
        case .reset:
            return "Reset"
        case .resetCounter:
            return "Reset Counter"
        }
    }

    var systemImage: String {
        switch self {
        case .stop:
            return "stop.fill"
        case .play:
            return "play.fill"
        case .fastForward:
            return "forward.fill"
        case .rewind:
            return "backward.fill"
        case .record:
            return "record.circle"
        case .reset:
            return "arrow.counterclockwise"
        case .resetCounter:
            return "gauge.with.dots.needle.33percent"
        }
    }
}

struct TapeConfiguration: Codable, Equatable {
    private static let viceSoundVolumeMax = 4096

    var isDatasetteEnabled: Bool
    var soundEnabled: Bool
    var soundVolume: Int

    static let standard = TapeConfiguration(isDatasetteEnabled: true,
                                            soundEnabled: false,
                                            soundVolume: 25)

    init(isDatasetteEnabled: Bool,
         soundEnabled: Bool,
         soundVolume: Int) {
        self.isDatasetteEnabled = isDatasetteEnabled
        self.soundEnabled = soundEnabled
        self.soundVolume = Self.normalizedSoundVolumePercent(soundVolume)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.standard

        isDatasetteEnabled = try container.decodeIfPresent(Bool.self, forKey: .isDatasetteEnabled)
            ?? defaults.isDatasetteEnabled
        soundEnabled = try container.decodeIfPresent(Bool.self, forKey: .soundEnabled)
            ?? defaults.soundEnabled
        soundVolume = Self.soundVolumePercent(fromStoredValue: try container.decodeIfPresent(Int.self, forKey: .soundVolume)
                                              ?? defaults.soundVolume)
    }

    var viceSoundVolume: Int32 {
        Int32(Self.viceSoundVolume(fromPercent: soundVolume))
    }

    static func normalizedSoundVolumePercent(_ volume: Int) -> Int {
        min(max(volume, 0), 100)
    }

    private static func soundVolumePercent(fromStoredValue volume: Int) -> Int {
        if volume > 100 {
            return normalizedSoundVolumePercent((volume * 100 + (viceSoundVolumeMax / 2)) / viceSoundVolumeMax)
        }

        return normalizedSoundVolumePercent(volume)
    }

    private static func viceSoundVolume(fromPercent percent: Int) -> Int {
        min(max(percent, 0), 100) * viceSoundVolumeMax / 100
    }
}

enum AutostartMediaFileType: String, CaseIterable, Identifiable {
    case prg
    case t64
    case tap

    var id: String { rawValue }

    var title: String {
        switch self {
        case .prg:
            return "PRG program"
        case .t64:
            return "T64 tape archive"
        case .tap:
            return "TAP tape image"
        }
    }

    init?(url: URL) {
        self.init(rawValue: url.pathExtension.lowercased())
    }
}

enum SnapshotFileType: String, CaseIterable, Identifiable {
    case vsf

    var id: String { rawValue }
    var title: String { rawValue.uppercased() }

    init?(url: URL) {
        self.init(rawValue: url.pathExtension.lowercased())
    }
}

enum CartridgeImageFileType: String, CaseIterable, Identifiable {
    case crt

    var id: String { rawValue }
    var title: String { rawValue.uppercased() }

    init?(url: URL) {
        self.init(rawValue: url.pathExtension.lowercased())
    }
}

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
