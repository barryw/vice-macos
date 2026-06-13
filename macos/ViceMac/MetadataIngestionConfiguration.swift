import Foundation
import Security

enum MetadataProviderConnectionKind: String, Codable {
    case importedDatabase
    case documentedAPI
    case unavailable

    var title: String {
        switch self {
        case .importedDatabase:
            return "Database import"
        case .documentedAPI:
            return "API"
        case .unavailable:
            return "Unavailable"
        }
    }

    var systemImage: String {
        switch self {
        case .importedDatabase:
            return "tray.and.arrow.down"
        case .documentedAPI:
            return "network"
        case .unavailable:
            return "nosign"
        }
    }
}

enum MetadataCredentialField: String, CaseIterable, Codable, Identifiable, Hashable {
    case apiKey
    case clientID
    case accessToken

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apiKey:
            return "API key"
        case .clientID:
            return "Client ID"
        case .accessToken:
            return "Access token"
        }
    }

    var placeholder: String {
        switch self {
        case .apiKey:
            return "API key"
        case .clientID:
            return "Client ID"
        case .accessToken:
            return "Bearer token"
        }
    }

    var isSecret: Bool {
        switch self {
        case .apiKey, .accessToken:
            return true
        case .clientID:
            return false
        }
    }
}

enum MetadataProviderID: String, CaseIterable, Codable, Identifiable, Hashable {
    case gameBase64
    case mobyGames
    case igdb
    case theGamesDB
    case csdb

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gameBase64:
            return "GameBase64"
        case .mobyGames:
            return "MobyGames"
        case .igdb:
            return "IGDB"
        case .theGamesDB:
            return "TheGamesDB"
        case .csdb:
            return "CSDb"
        }
    }

    var systemImage: String {
        switch self {
        case .gameBase64:
            return "archivebox"
        case .mobyGames:
            return "books.vertical"
        case .igdb:
            return "globe"
        case .theGamesDB:
            return "rectangle.stack"
        case .csdb:
            return "person.3.sequence"
        }
    }

    var connectionKind: MetadataProviderConnectionKind {
        switch self {
        case .mobyGames, .igdb, .theGamesDB:
            return .documentedAPI
        case .gameBase64:
            return .importedDatabase
        case .csdb:
            return .unavailable
        }
    }

    var machineScopeTitle: String {
        switch self {
        case .gameBase64, .csdb:
            return "C64"
        case .mobyGames, .igdb, .theGamesDB:
            return "Multi-platform"
        }
    }

    var summaryTitle: String {
        switch self {
        case .gameBase64:
            return "Imports a user-provided MDB directly, or prepares a GB64 ZIP/installer without running Windows code"
        case .mobyGames:
            return "Game metadata API"
        case .igdb:
            return "Game metadata API"
        case .theGamesDB:
            return "Game metadata and artwork API"
        case .csdb:
            return "Scene database; disabled until an import or API connector exists"
        }
    }

    var isConfigurable: Bool {
        connectionKind != .unavailable
    }

    var importFilenameExtensions: [String] {
        switch self {
        case .gameBase64:
            return ["mdb", "zip", "exe"]
        case .mobyGames, .igdb, .theGamesDB, .csdb:
            return []
        }
    }

    var credentialFields: [MetadataCredentialField] {
        switch self {
        case .gameBase64, .csdb:
            return []
        case .mobyGames, .theGamesDB:
            return [.apiKey]
        case .igdb:
            return [.clientID, .accessToken]
        }
    }
}

enum MetadataMatchStrategy: String, CaseIterable, Codable, Identifiable {
    case hashAndTitle
    case hashFirst
    case titleOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hashAndTitle:
            return "Hash and title"
        case .hashFirst:
            return "Hash first"
        case .titleOnly:
            return "Title only"
        }
    }
}

enum MetadataArtworkPreference: String, CaseIterable, Codable, Identifiable {
    case boxFront
    case screenshot
    case titleScreen

    var id: String { rawValue }

    var title: String {
        switch self {
        case .boxFront:
            return "Box front"
        case .screenshot:
            return "Screenshot"
        case .titleScreen:
            return "Title screen"
        }
    }
}

struct MetadataProviderConfiguration: Codable, Equatable, Identifiable {
    let providerID: MetadataProviderID
    var isEnabled: Bool
    var databasePath: String?
    var lastImportedAt: Date?

    var id: MetadataProviderID { providerID }

    init(providerID: MetadataProviderID,
         isEnabled: Bool = false,
         databasePath: String? = nil,
         lastImportedAt: Date? = nil) {
        self.providerID = providerID
        self.isEnabled = isEnabled
        self.databasePath = databasePath
        self.lastImportedAt = lastImportedAt
    }

    func normalized() -> MetadataProviderConfiguration {
        var configuration = self
        if !providerID.isConfigurable {
            configuration.isEnabled = false
        }

        if providerID.connectionKind != .importedDatabase {
            configuration.databasePath = nil
            configuration.lastImportedAt = nil
        }

        if configuration.databasePath?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            configuration.databasePath = nil
        }

        return configuration
    }
}

struct MetadataProviderSnapshot: Identifiable, Equatable {
    let providerID: MetadataProviderID
    var configuration: MetadataProviderConfiguration
    var configuredCredentialFields: Set<MetadataCredentialField>

    var id: MetadataProviderID { providerID }

    var isReady: Bool {
        switch providerID.connectionKind {
        case .importedDatabase:
            return configuration.databasePath != nil
        case .documentedAPI:
            return Set(providerID.credentialFields).isSubset(of: configuredCredentialFields)
        case .unavailable:
            return false
        }
    }

    var statusTitle: String {
        guard providerID.isConfigurable else {
            return "Unavailable"
        }

        if configuration.isEnabled {
            return isReady ? "Enabled" : "Needs setup"
        }

        return isReady ? "Ready" : "Off"
    }
}

protocol MetadataCredentialStoring: AnyObject {
    func loadCredential(providerID: MetadataProviderID, field: MetadataCredentialField) -> String?
    func saveCredential(_ credential: String, providerID: MetadataProviderID, field: MetadataCredentialField)
    func deleteCredential(providerID: MetadataProviderID, field: MetadataCredentialField)
}

final class MetadataIngestionMemoryCredentialStore: MetadataCredentialStoring {
    private var credentials: [String: String] = [:]

    func loadCredential(providerID: MetadataProviderID, field: MetadataCredentialField) -> String? {
        credentials[key(providerID: providerID, field: field)]
    }

    func saveCredential(_ credential: String,
                        providerID: MetadataProviderID,
                        field: MetadataCredentialField) {
        credentials[key(providerID: providerID, field: field)] = credential
    }

    func deleteCredential(providerID: MetadataProviderID, field: MetadataCredentialField) {
        credentials[key(providerID: providerID, field: field)] = nil
    }

    private func key(providerID: MetadataProviderID, field: MetadataCredentialField) -> String {
        "\(providerID.rawValue).\(field.rawValue)"
    }
}

@MainActor
final class MetadataIngestionSettings: ObservableObject {
    @Published private var configurations: [MetadataProviderID: MetadataProviderConfiguration] {
        didSet {
            guard configurations != oldValue else {
                return
            }

            saveConfigurations()
        }
    }

    @Published private(set) var credentialStatus: [MetadataProviderID: Set<MetadataCredentialField>]

    @Published var matchesNewLibraryItems: Bool {
        didSet {
            defaults.set(matchesNewLibraryItems, forKey: Self.matchesNewLibraryItemsKey)
        }
    }

    @Published var matchStrategy: MetadataMatchStrategy {
        didSet {
            defaults.set(matchStrategy.rawValue, forKey: Self.matchStrategyKey)
        }
    }

    @Published var cachesArtworkLocally: Bool {
        didSet {
            defaults.set(cachesArtworkLocally, forKey: Self.cachesArtworkLocallyKey)
        }
    }

    @Published var artworkPreference: MetadataArtworkPreference {
        didSet {
            defaults.set(artworkPreference.rawValue, forKey: Self.artworkPreferenceKey)
        }
    }

    var providerSnapshots: [MetadataProviderSnapshot] {
        MetadataProviderID.allCases.map { providerID in
            MetadataProviderSnapshot(providerID: providerID,
                                     configuration: configuration(for: providerID),
                                     configuredCredentialFields: credentialStatus[providerID] ?? [])
        }
    }

    var configuredSourceCount: Int {
        providerSnapshots.filter(\.isReady).count
    }

    private let defaults: UserDefaults
    private let credentialStore: MetadataCredentialStoring
    private let metadataSourceDirectoryURL: URL

    init(defaults: UserDefaults = MetadataIngestionSettings.defaults,
         credentialStore: MetadataCredentialStoring = MetadataIngestionKeychain(),
         metadataSourceDirectoryURL: URL = MetadataIngestionSettings.defaultMetadataSourceDirectoryURL) {
        self.defaults = defaults
        self.credentialStore = credentialStore
        self.metadataSourceDirectoryURL = metadataSourceDirectoryURL
        configurations = Self.loadConfigurations(from: defaults)
        credentialStatus = Self.loadCredentialStatus(using: credentialStore)
        matchesNewLibraryItems = defaults.object(forKey: Self.matchesNewLibraryItemsKey) as? Bool ?? true
        matchStrategy = MetadataMatchStrategy(rawValue: defaults.string(forKey: Self.matchStrategyKey) ?? "")
            ?? .hashAndTitle
        cachesArtworkLocally = defaults.object(forKey: Self.cachesArtworkLocallyKey) as? Bool ?? true
        artworkPreference = MetadataArtworkPreference(rawValue: defaults.string(forKey: Self.artworkPreferenceKey) ?? "")
            ?? .boxFront
    }

    func configuration(for providerID: MetadataProviderID) -> MetadataProviderConfiguration {
        configurations[providerID] ?? MetadataProviderConfiguration(providerID: providerID).normalized()
    }

    func setEnabled(_ isEnabled: Bool, for providerID: MetadataProviderID) {
        guard providerID.isConfigurable else {
            return
        }

        var configuration = configuration(for: providerID)
        configuration.isEnabled = isEnabled
        configurations[providerID] = configuration.normalized()
    }

    func setDatabaseURL(_ url: URL?, for providerID: MetadataProviderID) {
        guard providerID.connectionKind == .importedDatabase else {
            return
        }

        var configuration = configuration(for: providerID)
        configuration.databasePath = url?.path
        configuration.lastImportedAt = nil
        configurations[providerID] = configuration.normalized()
    }

    @discardableResult
    func importDatabasePackage(_ url: URL,
                               for providerID: MetadataProviderID) throws -> GameBase64MetadataImportResult {
        guard providerID.connectionKind == .importedDatabase else {
            throw GameBase64MetadataImportError.unsupportedPackage(url.lastPathComponent)
        }

        let result: GameBase64MetadataImportResult
        switch providerID {
        case .gameBase64:
            result = try GameBase64MetadataImporter()
                .importPackage(at: url, into: metadataSourceDirectoryURL)
        case .mobyGames, .igdb, .theGamesDB, .csdb:
            throw GameBase64MetadataImportError.unsupportedPackage(url.lastPathComponent)
        }

        var configuration = configuration(for: providerID)
        configuration.databasePath = result.databaseURL.path
        configuration.lastImportedAt = Date()
        configurations[providerID] = configuration.normalized()
        return result
    }

    func markImported(providerID: MetadataProviderID, at date: Date = Date()) {
        guard providerID.connectionKind == .importedDatabase else {
            return
        }

        var configuration = configuration(for: providerID)
        configuration.lastImportedAt = date
        configurations[providerID] = configuration.normalized()
    }

    func credential(providerID: MetadataProviderID, field: MetadataCredentialField) -> String {
        guard providerID.credentialFields.contains(field) else {
            return ""
        }

        return credentialStore.loadCredential(providerID: providerID, field: field) ?? ""
    }

    func setCredential(_ credential: String,
                       providerID: MetadataProviderID,
                       field: MetadataCredentialField) {
        guard providerID.credentialFields.contains(field) else {
            return
        }

        let normalizedCredential = credential.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedCredential.isEmpty {
            credentialStore.deleteCredential(providerID: providerID, field: field)
        } else {
            credentialStore.saveCredential(normalizedCredential, providerID: providerID, field: field)
        }

        refreshCredentialStatus(for: providerID)
    }

    func clearCredentials(for providerID: MetadataProviderID) {
        for field in providerID.credentialFields {
            credentialStore.deleteCredential(providerID: providerID, field: field)
        }

        refreshCredentialStatus(for: providerID)
    }

    private func refreshCredentialStatus(for providerID: MetadataProviderID) {
        credentialStatus[providerID] = Self.configuredCredentialFields(for: providerID,
                                                                       using: credentialStore)
    }

    private func saveConfigurations() {
        let storedConfigurations = MetadataProviderID.allCases.map { providerID in
            configuration(for: providerID).normalized()
        }

        guard let data = try? JSONEncoder().encode(storedConfigurations) else {
            return
        }

        defaults.set(data, forKey: Self.providerConfigurationsKey)
    }

    private static func loadConfigurations(from defaults: UserDefaults) -> [MetadataProviderID: MetadataProviderConfiguration] {
        let storedConfigurations: [MetadataProviderConfiguration]
        if let data = defaults.data(forKey: providerConfigurationsKey),
           let decodedConfigurations = try? JSONDecoder().decode([MetadataProviderConfiguration].self, from: data) {
            storedConfigurations = decodedConfigurations
        } else {
            storedConfigurations = []
        }

        var configurations = Dictionary(uniqueKeysWithValues: MetadataProviderID.allCases.map { providerID in
            (providerID, MetadataProviderConfiguration(providerID: providerID).normalized())
        })

        for configuration in storedConfigurations {
            configurations[configuration.providerID] = configuration.normalized()
        }

        return configurations
    }

    private static func loadCredentialStatus(using credentialStore: MetadataCredentialStoring) -> [MetadataProviderID: Set<MetadataCredentialField>] {
        Dictionary(uniqueKeysWithValues: MetadataProviderID.allCases.map { providerID in
            (providerID, configuredCredentialFields(for: providerID, using: credentialStore))
        })
    }

    private static func configuredCredentialFields(for providerID: MetadataProviderID,
                                                   using credentialStore: MetadataCredentialStoring) -> Set<MetadataCredentialField> {
        Set(providerID.credentialFields.filter { field in
            credentialStore.loadCredential(providerID: providerID, field: field)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty == false
        })
    }

    private static let providerConfigurationsKey = "vice.metadata.providers"
    private static let matchesNewLibraryItemsKey = "vice.metadata.matchesNewLibraryItems"
    private static let matchStrategyKey = "vice.metadata.matchStrategy"
    private static let cachesArtworkLocallyKey = "vice.metadata.cachesArtworkLocally"
    private static let artworkPreferenceKey = "vice.metadata.artworkPreference"
    private static let defaults = UserDefaults(suiteName: "com.barrywalker.vicemac") ?? .standard

    static var defaultMetadataSourceDirectoryURL: URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory,
                                               in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")

        return baseURL
            .appendingPathComponent("VICE Mac", isDirectory: true)
            .appendingPathComponent("Metadata Sources", isDirectory: true)
    }
}

final class MetadataIngestionKeychain: MetadataCredentialStoring {
    private static let service = "com.barrywalker.vicemac.metadata"

    func loadCredential(providerID: MetadataProviderID, field: MetadataCredentialField) -> String? {
        var query = baseQuery(providerID: providerID, field: field)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let credential = String(data: data, encoding: .utf8),
              !credential.isEmpty else {
            return nil
        }

        return credential
    }

    func saveCredential(_ credential: String,
                        providerID: MetadataProviderID,
                        field: MetadataCredentialField) {
        guard let data = credential.data(using: .utf8) else {
            return
        }

        let attributes = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery(providerID: providerID, field: field) as CFDictionary,
                                   attributes as CFDictionary)
        if status != errSecSuccess {
            var query = baseQuery(providerID: providerID, field: field)
            query[kSecValueData as String] = data
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    func deleteCredential(providerID: MetadataProviderID, field: MetadataCredentialField) {
        SecItemDelete(baseQuery(providerID: providerID, field: field) as CFDictionary)
    }

    private func baseQuery(providerID: MetadataProviderID,
                           field: MetadataCredentialField) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: "\(providerID.rawValue).\(field.rawValue)"
        ]
    }
}
