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
    case igdb
    case theGamesDB
    case csdb

    var id: String { rawValue }

    static var activeProviderIDs: [MetadataProviderID] {
        [.gameBase64, .igdb, .theGamesDB, .csdb]
    }

    var title: String {
        switch self {
        case .gameBase64:
            return "GameBase64"
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
        case .igdb, .theGamesDB:
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
        case .igdb, .theGamesDB:
            return "Multi-platform"
        }
    }

    var summaryTitle: String {
        switch self {
        case .gameBase64:
            return "Imports a user-provided MDB directly, or prepares a GB64 ZIP/installer without running Windows code"
        case .igdb:
            return "Game metadata API with cover and screenshot image fields"
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
        case .igdb, .theGamesDB, .csdb:
            return []
        }
    }

    var credentialFields: [MetadataCredentialField] {
        switch self {
        case .gameBase64, .csdb:
            return []
        case .theGamesDB:
            return [.apiKey]
        case .igdb:
            return [.clientID, .accessToken]
        }
    }

    var supportedArtworkPreferences: [MetadataArtworkPreference] {
        switch self {
        case .gameBase64, .csdb:
            return []
        case .igdb:
            return [.boxFront, .screenshot]
        case .theGamesDB:
            return [.boxFront, .screenshot, .titleScreen]
        }
    }

    var supportsArtwork: Bool {
        !supportedArtworkPreferences.isEmpty
    }

    func supportsArtworkPreference(_ preference: MetadataArtworkPreference) -> Bool {
        supportedArtworkPreferences.contains(preference)
    }

    var supportsMediaLibraryMetadataSearch: Bool {
        switch self {
        case .theGamesDB:
            return true
        case .gameBase64, .igdb, .csdb:
            return false
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

struct MediaLibraryMetadataSearchResult: Identifiable, Equatable {
    var id: String
    var providerID: MetadataProviderID
    var externalID: String
    var title: String
    var platformName: String?
    var releaseDate: String?
    var overview: String?
    var artworkURL: URL?

    var subtitle: String {
        [platformName, releaseDate]
            .compactMap { value -> String? in
                let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed?.isEmpty == false ? trimmed : nil
            }
            .joined(separator: " - ")
    }
}

struct MediaLibraryMetadataUpdate: Equatable {
    var providerID: MetadataProviderID
    var externalID: String
    var title: String
    var notes: String
    var artworkKind: MetadataArtworkPreference?
    var artworkSourceURL: URL?
    var artworkData: Data?
    var artworkFileExtension: String?
}

enum MetadataLookupError: Error, LocalizedError, Equatable {
    case missingCredential(MetadataProviderID)
    case unsupportedProvider(MetadataProviderID)
    case invalidResponse(String)
    case noResults

    var errorDescription: String? {
        switch self {
        case .missingCredential(let providerID):
            return "\(providerID.title) needs credentials before it can update metadata."
        case .unsupportedProvider(let providerID):
            return "\(providerID.title) does not support media library metadata search yet."
        case .invalidResponse(let message):
            return message
        case .noResults:
            return "No metadata matches were found."
        }
    }
}

final class TheGamesDBMetadataClient: Sendable {
    private let apiKey: String
    private let session: URLSession

    init(apiKey: String,
         session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func searchGames(query: String,
                     artworkPreference: MetadataArtworkPreference,
                     limit: Int = 12) async throws -> [MediaLibraryMetadataSearchResult] {
        let response: TheGamesDBGamesResponse = try await request(
            path: "/v1.1/Games/ByGameName",
            queryItems: [
                URLQueryItem(name: "name", value: query),
                URLQueryItem(name: "fields", value: "overview,platform,players,publishers,genres,alternates"),
                URLQueryItem(name: "include", value: "boxart,platform")
            ]
        )

        return Self.searchResults(from: response,
                                  artworkPreference: artworkPreference,
                                  limit: limit)
    }

    func metadataUpdate(for result: MediaLibraryMetadataSearchResult,
                        artworkPreference: MetadataArtworkPreference) async throws -> MediaLibraryMetadataUpdate {
        var artworkURL = result.artworkURL
        if artworkURL == nil || artworkPreference != .boxFront {
            artworkURL = try await imageURL(gameID: result.externalID,
                                            artworkPreference: artworkPreference)
        }

        let artworkData: Data?
        if let artworkURL {
            artworkData = try await downloadArtwork(from: artworkURL)
        } else {
            artworkData = nil
        }

        return MediaLibraryMetadataUpdate(providerID: result.providerID,
                                          externalID: result.externalID,
                                          title: result.title,
                                          notes: Self.notes(for: result),
                                          artworkKind: artworkData == nil ? nil : artworkPreference,
                                          artworkSourceURL: artworkURL,
                                          artworkData: artworkData,
                                          artworkFileExtension: artworkURL?.pathExtension)
    }

    func imageURL(gameID: String,
                  artworkPreference: MetadataArtworkPreference) async throws -> URL? {
        let response: TheGamesDBImagesResponse = try await request(
            path: "/v1/Games/Images",
            queryItems: [
                URLQueryItem(name: "games_id", value: gameID),
                URLQueryItem(name: "filter[type]", value: Self.theGamesDBImageType(for: artworkPreference))
            ]
        )

        return Self.imageURL(for: gameID,
                             preference: artworkPreference,
                             baseURLs: response.data.baseURL,
                             imagesByGameID: response.data.images)
    }

    func downloadArtwork(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw MetadataLookupError.invalidResponse("TheGamesDB artwork download failed.")
        }

        guard !data.isEmpty else {
            throw MetadataLookupError.invalidResponse("TheGamesDB returned an empty artwork file.")
        }

        return data
    }

    static func searchResults(from data: Data,
                              artworkPreference: MetadataArtworkPreference,
                              limit: Int = 12) throws -> [MediaLibraryMetadataSearchResult] {
        let response = try JSONDecoder().decode(TheGamesDBGamesResponse.self, from: data)
        return searchResults(from: response,
                             artworkPreference: artworkPreference,
                             limit: limit)
    }

    static func searchResults(from response: TheGamesDBGamesResponse,
                              artworkPreference: MetadataArtworkPreference,
                              limit: Int = 12) -> [MediaLibraryMetadataSearchResult] {
        let platformData = response.include?.platform?.data ?? [:]
        let boxartData = response.include?.boxart
        let games = response.data.games.prefix(max(0, limit))

        return games.map { game in
            let externalID = String(game.id)
            let platformName = game.platform.flatMap { platformData[String($0)]?.name }
            let artworkURL = imageURL(for: externalID,
                                      preference: .boxFront,
                                      baseURLs: boxartData?.baseURL,
                                      imagesByGameID: boxartData?.data ?? [:])
            return MediaLibraryMetadataSearchResult(id: "theGamesDB:\(externalID)",
                                                    providerID: .theGamesDB,
                                                    externalID: externalID,
                                                    title: game.gameTitle,
                                                    platformName: platformName,
                                                    releaseDate: game.releaseDate,
                                                    overview: game.overview,
                                                    artworkURL: artworkURL)
        }
    }

    private func request<T: Decodable>(path: String,
                                       queryItems: [URLQueryItem]) async throws -> T {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.thegamesdb.net"
        components.path = path
        components.queryItems = [URLQueryItem(name: "apikey", value: apiKey)] + queryItems

        guard let url = components.url else {
            throw MetadataLookupError.invalidResponse("TheGamesDB request URL could not be built.")
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw MetadataLookupError.invalidResponse("TheGamesDB request failed.")
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func notes(for result: MediaLibraryMetadataSearchResult) -> String {
        let source = "Metadata: TheGamesDB \(result.externalID)"
        let overview = result.overview?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return overview.isEmpty ? source : "\(overview)\n\n\(source)"
    }

    private static func imageURL(for gameID: String,
                                 preference: MetadataArtworkPreference,
                                 baseURLs: TheGamesDBImageBaseURLs?,
                                 imagesByGameID: [String: [TheGamesDBImage]]) -> URL? {
        guard let baseURLs,
              let images = imagesByGameID[gameID] else {
            return nil
        }

        let imageType = theGamesDBImageType(for: preference)
        let image = images.first { image in
            image.type.caseInsensitiveCompare(imageType) == .orderedSame
                && (preference != .boxFront || image.side?.caseInsensitiveCompare("front") == .orderedSame)
        } ?? images.first { image in
            image.type.caseInsensitiveCompare(imageType) == .orderedSame
        }

        guard let filename = image?.filename else {
            return nil
        }

        if let absoluteURL = URL(string: filename),
           absoluteURL.scheme != nil {
            return absoluteURL
        }

        let baseURLString = baseURLs.large
            ?? baseURLs.medium
            ?? baseURLs.original
            ?? baseURLs.small
            ?? baseURLs.thumb
        guard let baseURLString,
              let baseURL = URL(string: baseURLString) else {
            return nil
        }

        return baseURL.appendingPathComponent(filename)
    }

    private static func theGamesDBImageType(for preference: MetadataArtworkPreference) -> String {
        switch preference {
        case .boxFront:
            return "boxart"
        case .screenshot:
            return "screenshot"
        case .titleScreen:
            return "titlescreen"
        }
    }
}

struct TheGamesDBGamesResponse: Decodable, Equatable {
    var data: TheGamesDBGamesData
    var include: TheGamesDBInclude?
}

struct TheGamesDBGamesData: Decodable, Equatable {
    var games: [TheGamesDBGame]
}

struct TheGamesDBGame: Decodable, Equatable {
    var id: Int
    var gameTitle: String
    var releaseDate: String?
    var platform: Int?
    var overview: String?

    enum CodingKeys: String, CodingKey {
        case id
        case gameTitle = "game_title"
        case releaseDate = "release_date"
        case platform
        case overview
    }
}

struct TheGamesDBInclude: Decodable, Equatable {
    var boxart: TheGamesDBBoxartInclude?
    var platform: TheGamesDBPlatformInclude?
}

struct TheGamesDBBoxartInclude: Decodable, Equatable {
    var baseURL: TheGamesDBImageBaseURLs
    var data: [String: [TheGamesDBImage]]

    enum CodingKeys: String, CodingKey {
        case baseURL = "base_url"
        case data
    }
}

struct TheGamesDBPlatformInclude: Decodable, Equatable {
    var data: [String: TheGamesDBPlatform]
}

struct TheGamesDBPlatform: Decodable, Equatable {
    var id: Int
    var name: String
}

struct TheGamesDBImagesResponse: Decodable, Equatable {
    var data: TheGamesDBImagesData
}

struct TheGamesDBImagesData: Decodable, Equatable {
    var baseURL: TheGamesDBImageBaseURLs
    var images: [String: [TheGamesDBImage]]

    enum CodingKeys: String, CodingKey {
        case baseURL = "base_url"
        case images
    }
}

struct TheGamesDBImageBaseURLs: Decodable, Equatable {
    var original: String?
    var small: String?
    var thumb: String?
    var medium: String?
    var large: String?
}

struct TheGamesDBImage: Decodable, Equatable {
    var type: String
    var side: String?
    var filename: String
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

private struct StoredMetadataProviderConfiguration: Decodable {
    let configuration: MetadataProviderConfiguration?

    private enum CodingKeys: String, CodingKey {
        case providerID
        case isEnabled
        case databasePath
        case lastImportedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawProviderID = try? container.decode(String.self, forKey: .providerID)
        guard let rawProviderID,
              let providerID = MetadataProviderID(rawValue: rawProviderID) else {
            configuration = nil
            return
        }

        configuration = MetadataProviderConfiguration(
            providerID: providerID,
            isEnabled: (try? container.decode(Bool.self, forKey: .isEnabled)) ?? false,
            databasePath: try? container.decode(String.self, forKey: .databasePath),
            lastImportedAt: try? container.decode(Date.self, forKey: .lastImportedAt)
        )
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
        MetadataProviderID.activeProviderIDs.map { providerID in
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
        case .igdb, .theGamesDB, .csdb:
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
        let storedConfigurations = MetadataProviderID.activeProviderIDs.map { providerID in
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
           let decodedConfigurations = try? JSONDecoder().decode([StoredMetadataProviderConfiguration].self, from: data) {
            storedConfigurations = decodedConfigurations.compactMap(\.configuration)
        } else {
            storedConfigurations = []
        }

        var configurations = Dictionary(uniqueKeysWithValues: MetadataProviderID.activeProviderIDs.map { providerID in
            (providerID, MetadataProviderConfiguration(providerID: providerID).normalized())
        })

        for configuration in storedConfigurations {
            configurations[configuration.providerID] = configuration.normalized()
        }

        return configurations
    }

    private static func loadCredentialStatus(using credentialStore: MetadataCredentialStoring) -> [MetadataProviderID: Set<MetadataCredentialField>] {
        Dictionary(uniqueKeysWithValues: MetadataProviderID.activeProviderIDs.map { providerID in
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
