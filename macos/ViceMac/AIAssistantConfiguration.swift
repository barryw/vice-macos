import Foundation
import FoundationModels
import MacVICEKit
import Security

struct AIAssistantRunResult: Equatable {
    let text: String
    let toolUseCount: Int
}

enum AIAssistantFoundationModelUnavailableReason: Equatable {
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady

    var title: String {
        switch self {
        case .deviceNotEligible:
            return "Mac not eligible"
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence off"
        case .modelNotReady:
            return "Model not ready"
        }
    }

    var detail: String {
        switch self {
        case .deviceNotEligible:
            return "This Mac does not support Apple Intelligence, so on-device AI features are unavailable."
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence in System Settings to use on-device AI features."
        case .modelNotReady:
            return "Apple Intelligence is available, but the local model is still downloading or preparing."
        }
    }

    var systemImage: String {
        switch self {
        case .deviceNotEligible:
            return "desktopcomputer.trianglebadge.exclamationmark"
        case .appleIntelligenceNotEnabled:
            return "sparkles.slash"
        case .modelNotReady:
            return "arrow.down.circle"
        }
    }
}

enum AIAssistantFoundationModelAvailability: Equatable {
    case available
    case unavailable(AIAssistantFoundationModelUnavailableReason)

    var isAvailable: Bool {
        self == .available
    }

    var title: String {
        switch self {
        case .available:
            return "Ready"
        case .unavailable(let reason):
            return reason.title
        }
    }

    var detail: String {
        switch self {
        case .available:
            return "Apple Foundation Models are available on this Mac."
        case .unavailable(let reason):
            return reason.detail
        }
    }

    var systemImage: String {
        switch self {
        case .available:
            return "checkmark.circle.fill"
        case .unavailable(let reason):
            return reason.systemImage
        }
    }

    static func from(systemAvailability availability: SystemLanguageModel.Availability) -> Self {
        switch availability {
        case .available:
            return .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return .unavailable(.deviceNotEligible)
            case .appleIntelligenceNotEnabled:
                return .unavailable(.appleIntelligenceNotEnabled)
            case .modelNotReady:
                return .unavailable(.modelNotReady)
            @unknown default:
                return .unavailable(.deviceNotEligible)
            }
        @unknown default:
            return .unavailable(.deviceNotEligible)
        }
    }
}

enum AIAssistantModelBackend: String, CaseIterable, Codable, Hashable, Identifiable {
    case openAICompatible = "openai"
    case foundation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openAICompatible:
            return "OpenAI"
        case .foundation:
            return "Foundation"
        }
    }

    var detail: String {
        switch self {
        case .openAICompatible:
            return "OpenAI-compatible API"
        case .foundation:
            return "Apple Foundation Models"
        }
    }

    var systemImage: String {
        switch self {
        case .openAICompatible:
            return "network"
        case .foundation:
            return "sparkles"
        }
    }
}

enum AIAssistantRemoteProvider: String, CaseIterable, Codable, Hashable, Identifiable {
    case local
    case openAI
    case anthropic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .local:
            return "Local"
        case .openAI:
            return "OpenAI"
        case .anthropic:
            return "Anthropic"
        }
    }

    var defaultBaseURLString: String {
        switch self {
        case .local:
            return "http://beast:11434/v1"
        case .openAI:
            return "https://api.openai.com/v1"
        case .anthropic:
            return "https://api.anthropic.com/v1"
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .local:
            return false
        case .openAI, .anthropic:
            return true
        }
    }

    var systemImage: String {
        switch self {
        case .local:
            return "server.rack"
        case .openAI:
            return "network"
        case .anthropic:
            return "a.circle"
        }
    }
}

struct AIAssistantRemoteModel: Equatable, Hashable, Identifiable {
    let id: String
    let displayName: String

    init(id: String, displayName: String? = nil) {
        self.id = id
        let normalizedDisplayName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.displayName = normalizedDisplayName.isEmpty ? id : normalizedDisplayName
    }
}

struct AIAssistantRemoteConfiguration: Equatable {
    let provider: AIAssistantRemoteProvider
    let baseURL: URL
    let apiKey: String
    let modelID: String

    var identityKey: String {
        [
            provider.rawValue,
            baseURL.absoluteString,
            modelID
        ].joined(separator: "|")
    }
}

enum AIAssistantRemoteConnectionStatus: Equatable {
    case idle
    case checking
    case connected(modelCount: Int)
    case failed(String)

    var title: String {
        switch self {
        case .idle:
            return "Not tested"
        case .checking:
            return "Checking..."
        case .connected(let modelCount):
            return modelCount == 1 ? "Connected. 1 model." : "Connected. \(modelCount) models."
        case .failed(let message):
            return message
        }
    }

    var systemImage: String {
        switch self {
        case .idle:
            return "circle"
        case .checking:
            return "arrow.clockwise"
        case .connected:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    var isConnected: Bool {
        if case .connected = self {
            return true
        }

        return false
    }

    var isFailed: Bool {
        if case .failed = self {
            return true
        }

        return false
    }
}

@MainActor
final class AIAssistantSettings: ObservableObject {
    @Published private(set) var isEnabled: Bool
    @Published private(set) var modelBackend: AIAssistantModelBackend
    @Published private(set) var remoteProvider: AIAssistantRemoteProvider
    @Published private(set) var remoteBaseURLString: String
    @Published private(set) var selectedRemoteModelID: String
    @Published private(set) var remoteModels: [AIAssistantRemoteModel]
    @Published private(set) var remoteCredentialProviders: Set<AIAssistantRemoteProvider>
    @Published private(set) var remoteConnectionStatus: AIAssistantRemoteConnectionStatus
    @Published private(set) var isFetchingRemoteModels: Bool
    @Published private(set) var availability: AIAssistantFoundationModelAvailability

    private let credentialStore: AIAssistantKeychain

    var isConfigured: Bool {
        guard isEnabled else {
            return false
        }

        switch modelBackend {
        case .openAICompatible:
            return remoteConfiguration != nil
        case .foundation:
            return false
        }
    }

    var isAvailable: Bool {
        switch modelBackend {
        case .openAICompatible:
            return remoteConfiguration != nil
        case .foundation:
            return availability.isAvailable
        }
    }

    var assistantSummary: String {
        guard isEnabled else {
            return "Disabled"
        }

        switch modelBackend {
        case .openAICompatible:
            if let configuration = remoteConfiguration {
                return "\(configuration.provider.title) / \(configuration.modelID)"
            }

            return "\(remoteProvider.title) / Not configured"
        case .foundation:
            return "Foundation / Paused"
        }
    }

    var remoteConfiguration: AIAssistantRemoteConfiguration? {
        guard let baseURL = Self.normalizedBaseURL(remoteBaseURLString),
              !selectedRemoteModelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let apiKey = Self.normalizedSecret(credential(for: remoteProvider))
        guard !remoteProvider.requiresAPIKey || !apiKey.isEmpty else {
            return nil
        }

        return AIAssistantRemoteConfiguration(provider: remoteProvider,
                                              baseURL: baseURL,
                                              apiKey: apiKey,
                                              modelID: selectedRemoteModelID)
    }

    var remoteProviderRequiresAPIKey: Bool {
        remoteProvider.requiresAPIKey
    }

    init() {
        let credentialStore = AIAssistantKeychain()
        self.credentialStore = credentialStore
        let currentAvailability = Self.currentAvailability()
        let storedBackend = Self.defaults.string(forKey: Self.modelBackendKey)
            .flatMap(AIAssistantModelBackend.init(rawValue:)) ?? .openAICompatible
        let normalizedBackend: AIAssistantModelBackend = storedBackend == .foundation ? .openAICompatible : storedBackend
        let storedProvider = Self.defaults.string(forKey: Self.remoteProviderKey)
            .flatMap(AIAssistantRemoteProvider.init(rawValue:)) ?? .local
        let baseURLString = Self.remoteBaseURLString(for: storedProvider)
        let selectedModelID = Self.selectedModelID(for: storedProvider)
        let loadedModels = selectedModelID.isEmpty ? [] : [AIAssistantRemoteModel(id: selectedModelID)]
        let enabledValue: Bool
        if Self.defaults.object(forKey: Self.enabledKey) == nil {
            enabledValue = Self.defaults.bool(forKey: Self.legacyFoundationEnabledKey)
        } else {
            enabledValue = Self.defaults.bool(forKey: Self.enabledKey)
        }

        availability = currentAvailability
        modelBackend = normalizedBackend
        remoteProvider = storedProvider
        remoteBaseURLString = baseURLString
        selectedRemoteModelID = selectedModelID
        remoteModels = loadedModels
        remoteCredentialProviders = Self.loadCredentialProviders(using: credentialStore)
        remoteConnectionStatus = .idle
        isFetchingRemoteModels = false
        isEnabled = enabledValue

        Self.defaults.set(normalizedBackend.rawValue, forKey: Self.modelBackendKey)
    }

    func setEnabled(_ enabled: Bool) {
        if isEnabled != enabled {
            isEnabled = enabled
        }

        Self.defaults.set(enabled, forKey: Self.enabledKey)
    }

    func setModelBackend(_ backend: AIAssistantModelBackend) {
        let normalizedBackend: AIAssistantModelBackend = backend == .foundation ? .openAICompatible : backend
        guard modelBackend != normalizedBackend else {
            return
        }

        modelBackend = normalizedBackend
        Self.defaults.set(normalizedBackend.rawValue, forKey: Self.modelBackendKey)
    }

    func setRemoteProvider(_ provider: AIAssistantRemoteProvider) {
        guard remoteProvider != provider else {
            return
        }

        remoteProvider = provider
        remoteBaseURLString = Self.remoteBaseURLString(for: provider)
        selectedRemoteModelID = Self.selectedModelID(for: provider)
        remoteModels = selectedRemoteModelID.isEmpty ? [] : [AIAssistantRemoteModel(id: selectedRemoteModelID)]
        remoteConnectionStatus = .idle
        Self.defaults.set(provider.rawValue, forKey: Self.remoteProviderKey)
    }

    func setRemoteBaseURLString(_ baseURLString: String) {
        guard remoteBaseURLString != baseURLString else {
            return
        }

        remoteBaseURLString = baseURLString
        Self.defaults.set(baseURLString, forKey: Self.remoteBaseURLKey(for: remoteProvider))
        clearRemoteModelsForCurrentProvider()
    }

    func setSelectedRemoteModelID(_ modelID: String) {
        guard selectedRemoteModelID != modelID else {
            return
        }

        selectedRemoteModelID = modelID
        Self.defaults.set(modelID, forKey: Self.selectedModelKey(for: remoteProvider))
        if !modelID.isEmpty,
           !remoteModels.contains(where: { $0.id == modelID }) {
            remoteModels.append(AIAssistantRemoteModel(id: modelID))
        }
    }

    func credential(for provider: AIAssistantRemoteProvider) -> String {
        credentialStore.loadAPIKey(provider: provider) ?? ""
    }

    func setCredential(_ credential: String, for provider: AIAssistantRemoteProvider) {
        let normalizedCredential = Self.normalizedSecret(credential)
        if normalizedCredential.isEmpty {
            credentialStore.deleteAPIKey(provider: provider)
        } else {
            credentialStore.saveAPIKey(normalizedCredential, provider: provider)
        }

        remoteCredentialProviders = Self.loadCredentialProviders(using: credentialStore)
        if provider == remoteProvider {
            remoteConnectionStatus = .idle
            if provider.requiresAPIKey {
                clearRemoteModelsForCurrentProvider()
            }
        }
    }

    func fetchRemoteModels() async {
        guard let baseURL = Self.normalizedBaseURL(remoteBaseURLString) else {
            remoteConnectionStatus = .failed("Enter a valid base URL.")
            return
        }

        let apiKey = Self.normalizedSecret(credential(for: remoteProvider))
        guard !remoteProvider.requiresAPIKey || !apiKey.isEmpty else {
            remoteConnectionStatus = .failed("Enter an API key.")
            return
        }

        isFetchingRemoteModels = true
        remoteConnectionStatus = .checking
        defer {
            isFetchingRemoteModels = false
        }

        do {
            let models = try await AIAssistantRemoteModelClient.fetchModels(provider: remoteProvider,
                                                                            baseURL: baseURL,
                                                                            apiKey: apiKey)
            remoteModels = models
            if models.isEmpty {
                selectedRemoteModelID = ""
                Self.defaults.removeObject(forKey: Self.selectedModelKey(for: remoteProvider))
                remoteConnectionStatus = .failed("Connected, but no models were returned.")
                return
            }

            if !models.contains(where: { $0.id == selectedRemoteModelID }) {
                selectedRemoteModelID = models[0].id
                Self.defaults.set(selectedRemoteModelID, forKey: Self.selectedModelKey(for: remoteProvider))
            }

            remoteConnectionStatus = .connected(modelCount: models.count)
        } catch {
            remoteConnectionStatus = .failed(error.localizedDescription)
        }
    }

    func refreshAvailability() {
        availability = Self.currentAvailability()
    }

    private static func currentAvailability() -> AIAssistantFoundationModelAvailability {
        AIAssistantFoundationModelAvailability.from(systemAvailability: SystemLanguageModel.default.availability)
    }

    private func clearRemoteModelsForCurrentProvider() {
        selectedRemoteModelID = ""
        remoteModels = []
        remoteConnectionStatus = .idle
        Self.defaults.removeObject(forKey: Self.selectedModelKey(for: remoteProvider))
    }

    private static func normalizedBaseURL(_ value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host?.isEmpty == false else {
            return nil
        }

        return url
    }

    private static func normalizedSecret(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func remoteBaseURLString(for provider: AIAssistantRemoteProvider) -> String {
        let stored = defaults.string(forKey: remoteBaseURLKey(for: provider))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return stored.isEmpty ? provider.defaultBaseURLString : stored
    }

    private static func selectedModelID(for provider: AIAssistantRemoteProvider) -> String {
        defaults.string(forKey: selectedModelKey(for: provider))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func loadCredentialProviders(using credentialStore: AIAssistantKeychain) -> Set<AIAssistantRemoteProvider> {
        Set(AIAssistantRemoteProvider.allCases.filter { provider in
            credentialStore.loadAPIKey(provider: provider)?.isEmpty == false
        })
    }

    private static func remoteBaseURLKey(for provider: AIAssistantRemoteProvider) -> String {
        "vice.ai.remote.\(provider.rawValue).baseURL"
    }

    private static func selectedModelKey(for provider: AIAssistantRemoteProvider) -> String {
        "vice.ai.remote.\(provider.rawValue).model"
    }

    private static let enabledKey = "vice.ai.agent.enabled"
    private static let legacyFoundationEnabledKey = "vice.ai.foundationModels.enabled"
    private static let modelBackendKey = "vice.ai.modelBackend"
    private static let remoteProviderKey = "vice.ai.remote.provider"
    private static let defaults = UserDefaults(suiteName: "com.barrywalker.vicemac") ?? .standard
}

@MainActor
final class AIAssistantConversationService {
    private let tools: AIAssistantVMToolExecutor
    private var session: LanguageModelSession
    private var remoteIdentityKey: String?
    private var openAITranscript: [[String: Any]]
    private var anthropicTranscript: [[String: Any]]

    init(emulator: EmulatorSession,
         documentLibrary: AIDocumentLibraryStore) {
        tools = AIAssistantVMToolExecutor(emulator: emulator,
                                          documentLibrary: documentLibrary)
        session = Self.makeSession(with: tools)
        openAITranscript = []
        anthropicTranscript = []
    }

    func reset() {
        session = Self.makeSession(with: tools)
        remoteIdentityKey = nil
        openAITranscript = []
        anthropicTranscript = []
    }

    func run(prompt: String,
             settings: AIAssistantSettings) async throws -> AIAssistantRunResult {
        let normalizedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPrompt.isEmpty else {
            throw AIAssistantConversationError.emptyPrompt
        }

        settings.refreshAvailability()
        guard settings.isEnabled else {
            throw AIAssistantConversationError.notConfigured
        }

        switch settings.modelBackend {
        case .foundation:
            return try await runFoundationModel(prompt: normalizedPrompt,
                                                settings: settings)
        case .openAICompatible:
            guard let configuration = settings.remoteConfiguration else {
                throw AIAssistantConversationError.remoteModelNotConfigured
            }

            return try await runRemoteModel(prompt: normalizedPrompt,
                                            configuration: configuration)
        }
    }

    private func runFoundationModel(prompt: String,
                                    settings: AIAssistantSettings) async throws -> AIAssistantRunResult {
        throw AIAssistantConversationError.foundationModelsPaused
    }

    private func runRemoteModel(prompt: String,
                                configuration: AIAssistantRemoteConfiguration) async throws -> AIAssistantRunResult {
        if remoteIdentityKey != configuration.identityKey {
            remoteIdentityKey = configuration.identityKey
            openAITranscript = []
            anthropicTranscript = []
        }

        let previousToolCount = tools.executedToolCount
        let text: String
        switch configuration.provider {
        case .local, .openAI:
            var transcript = openAITranscript
            text = try await AIAssistantRemoteConversationClient.respondWithOpenAICompatibleModel(prompt: prompt,
                                                                                                  configuration: configuration,
                                                                                                  tools: tools,
                                                                                                  transcript: &transcript)
            openAITranscript = transcript
        case .anthropic:
            var transcript = anthropicTranscript
            text = try await AIAssistantRemoteConversationClient.respondWithAnthropicModel(prompt: prompt,
                                                                                           configuration: configuration,
                                                                                           tools: tools,
                                                                                           transcript: &transcript)
            anthropicTranscript = transcript
        }

        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return AIAssistantRunResult(text: normalizedText.isEmpty ? "Done." : normalizedText,
                                    toolUseCount: tools.executedToolCount - previousToolCount)
    }

    private static func makeSession(with tools: AIAssistantVMToolExecutor) -> LanguageModelSession {
        LanguageModelSession(model: .default,
                             tools: tools.foundationModelTools,
                             instructions: tools.systemPrompt)
    }
}

enum AIAssistantConversationError: LocalizedError {
    case emptyPrompt
    case notConfigured
    case remoteModelNotConfigured
    case foundationModelsPaused
    case foundationModelsUnavailable(AIAssistantFoundationModelAvailability)
    case remoteRequestFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyPrompt:
            return "Enter a prompt first."
        case .notConfigured:
            return "Enable AI features in Settings."
        case .remoteModelNotConfigured:
            return "Choose a provider, connect, and select a model in Settings."
        case .foundationModelsPaused:
            return "Foundation Models are kept in the app, but disabled for now."
        case .foundationModelsUnavailable(let availability):
            return availability.detail
        case .remoteRequestFailed(let message):
            return message
        }
    }
}

private final class AIAssistantKeychain {
    private static let service = "com.barrywalker.vicemac.ai"

    func loadAPIKey(provider: AIAssistantRemoteProvider) -> String? {
        var query = baseQuery(provider: provider)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else {
            return nil
        }

        return value
    }

    func saveAPIKey(_ apiKey: String, provider: AIAssistantRemoteProvider) {
        guard let data = apiKey.data(using: .utf8) else {
            return
        }

        let attributes = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery(provider: provider) as CFDictionary,
                                   attributes as CFDictionary)
        if status != errSecSuccess {
            var query = baseQuery(provider: provider)
            query[kSecValueData as String] = data
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    func deleteAPIKey(provider: AIAssistantRemoteProvider) {
        SecItemDelete(baseQuery(provider: provider) as CFDictionary)
    }

    private func baseQuery(provider: AIAssistantRemoteProvider) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: "\(provider.rawValue).apiKey"
        ]
    }
}

private enum AIAssistantRemoteClientError: LocalizedError {
    case invalidResponse
    case httpStatus(Int, String)
    case invalidPayload(String)
    case tooManyToolRounds

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The model provider returned an invalid response."
        case .httpStatus(let statusCode, let body):
            let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedBody.isEmpty {
                return "The model provider returned HTTP \(statusCode)."
            }

            return "The model provider returned HTTP \(statusCode): \(trimmedBody)"
        case .invalidPayload(let message):
            return message
        case .tooManyToolRounds:
            return "The assistant used too many tool rounds without finishing."
        }
    }
}

private enum AIAssistantRemoteModelClient {
    static func fetchModels(provider: AIAssistantRemoteProvider,
                            baseURL: URL,
                            apiKey: String) async throws -> [AIAssistantRemoteModel] {
        let endpoint = baseURL.appendingPathComponent("models")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        applyHeaders(provider: provider, apiKey: apiKey, to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        let object = try jsonObject(from: data)
        guard let modelObjects = object["data"] as? [[String: Any]] else {
            throw AIAssistantRemoteClientError.invalidPayload("The provider response did not include a model list.")
        }

        return modelObjects.compactMap { modelObject in
            guard let id = modelObject["id"] as? String,
                  !id.isEmpty else {
                return nil
            }

            let displayName = (modelObject["display_name"] as? String)
                ?? (modelObject["name"] as? String)
            return AIAssistantRemoteModel(id: id, displayName: displayName)
        }
        .sorted { lhs, rhs in
            lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
    }

    static func applyHeaders(provider: AIAssistantRemoteProvider,
                             apiKey: String,
                             to request: inout URLRequest) {
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        switch provider {
        case .local:
            if !apiKey.isEmpty {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
        case .openAI:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        case .anthropic:
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        }
    }

    static func validate(response: URLResponse,
                         data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIAssistantRemoteClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: Data(data.prefix(2048)), encoding: .utf8) ?? ""
            throw AIAssistantRemoteClientError.httpStatus(httpResponse.statusCode, body)
        }
    }

    static func jsonObject(from data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIAssistantRemoteClientError.invalidResponse
        }

        return object
    }
}

@MainActor
private enum AIAssistantRemoteConversationClient {
    private static let maximumToolRounds = 8

    static func respondWithOpenAICompatibleModel(prompt: String,
                                                 configuration: AIAssistantRemoteConfiguration,
                                                 tools: AIAssistantVMToolExecutor,
                                                 transcript: inout [[String: Any]]) async throws -> String {
        transcript.append([
            "role": "user",
            "content": prompt
        ])

        for _ in 0..<maximumToolRounds {
            let messages: [[String: Any]] = [[
                "role": "system",
                "content": tools.systemPrompt
            ]] + transcript
            let body: [String: Any] = [
                "model": configuration.modelID,
                "messages": messages,
                "temperature": 0.2,
                "max_tokens": 900,
                "tools": tools.openAIToolDefinitions,
                "tool_choice": "auto"
            ]
            let response = try await postJSON(to: configuration.baseURL.appendingPathComponent("chat/completions"),
                                              provider: configuration.provider,
                                              apiKey: configuration.apiKey,
                                              body: body)
            guard let choices = response["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any] else {
                throw AIAssistantRemoteClientError.invalidPayload("The provider response did not include an assistant message.")
            }

            let toolCalls = openAIToolCalls(from: message)
            if !toolCalls.isEmpty {
                transcript.append(openAIAssistantToolCallMessage(content: message["content"],
                                                                toolCalls: toolCalls))
                for toolCall in toolCalls {
                    let result = tools.callRemoteTool(name: toolCall.name,
                                                      arguments: toolCall.arguments)
                    transcript.append([
                        "role": "tool",
                        "tool_call_id": toolCall.id,
                        "name": toolCall.name,
                        "content": result
                    ])
                }
                continue
            }

            let content = (message["content"] as? String) ?? ""
            transcript.append([
                "role": "assistant",
                "content": content
            ])
            return content
        }

        throw AIAssistantRemoteClientError.tooManyToolRounds
    }

    static func respondWithAnthropicModel(prompt: String,
                                          configuration: AIAssistantRemoteConfiguration,
                                          tools: AIAssistantVMToolExecutor,
                                          transcript: inout [[String: Any]]) async throws -> String {
        transcript.append([
            "role": "user",
            "content": prompt
        ])

        for _ in 0..<maximumToolRounds {
            let body: [String: Any] = [
                "model": configuration.modelID,
                "max_tokens": 900,
                "temperature": 0.2,
                "system": tools.systemPrompt,
                "messages": transcript,
                "tools": tools.anthropicToolDefinitions
            ]
            let response = try await postJSON(to: configuration.baseURL.appendingPathComponent("messages"),
                                              provider: configuration.provider,
                                              apiKey: configuration.apiKey,
                                              body: body)
            guard let contentBlocks = response["content"] as? [[String: Any]] else {
                throw AIAssistantRemoteClientError.invalidPayload("The Anthropic response did not include content blocks.")
            }

            let toolUseBlocks = contentBlocks.filter { block in
                (block["type"] as? String) == "tool_use"
            }
            if !toolUseBlocks.isEmpty {
                transcript.append([
                    "role": "assistant",
                    "content": contentBlocks
                ])

                let toolResults = toolUseBlocks.compactMap { block -> [String: Any]? in
                    guard let id = block["id"] as? String,
                          let name = block["name"] as? String else {
                        return nil
                    }

                    let arguments = block["input"] as? [String: Any] ?? [:]
                    return [
                        "type": "tool_result",
                        "tool_use_id": id,
                        "content": tools.callRemoteTool(name: name,
                                                        arguments: arguments)
                    ]
                }

                transcript.append([
                    "role": "user",
                    "content": toolResults
                ])
                continue
            }

            let text = contentBlocks.compactMap { block -> String? in
                guard (block["type"] as? String) == "text" else {
                    return nil
                }

                return block["text"] as? String
            }
            .joined(separator: "\n\n")
            transcript.append([
                "role": "assistant",
                "content": text
            ])
            return text
        }

        throw AIAssistantRemoteClientError.tooManyToolRounds
    }

    private static func postJSON(to url: URL,
                                 provider: AIAssistantRemoteProvider,
                                 apiKey: String,
                                 body: [String: Any]) async throws -> [String: Any] {
        guard JSONSerialization.isValidJSONObject(body) else {
            throw AIAssistantRemoteClientError.invalidPayload("The assistant request could not be encoded.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        AIAssistantRemoteModelClient.applyHeaders(provider: provider,
                                                  apiKey: apiKey,
                                                  to: &request)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try AIAssistantRemoteModelClient.validate(response: response, data: data)
        return try AIAssistantRemoteModelClient.jsonObject(from: data)
    }

    private static func openAIToolCalls(from message: [String: Any]) -> [AIAssistantRemoteToolCall] {
        guard let toolCalls = message["tool_calls"] as? [[String: Any]] else {
            return []
        }

        return toolCalls.compactMap { toolCall in
            guard let function = toolCall["function"] as? [String: Any],
                  let name = function["name"] as? String else {
                return nil
            }

            let id = (toolCall["id"] as? String) ?? UUID().uuidString
            let argumentsJSON = (function["arguments"] as? String) ?? "{}"
            return AIAssistantRemoteToolCall(id: id,
                                             name: name,
                                             argumentsJSON: argumentsJSON,
                                             arguments: jsonDictionary(from: argumentsJSON))
        }
    }

    private static func openAIAssistantToolCallMessage(content: Any?,
                                                       toolCalls: [AIAssistantRemoteToolCall]) -> [String: Any] {
        let normalizedContent: Any
        if let content = content as? String,
           !content.isEmpty {
            normalizedContent = content
        } else {
            normalizedContent = NSNull()
        }

        return [
            "role": "assistant",
            "content": normalizedContent,
            "tool_calls": toolCalls.map { toolCall in
                [
                    "id": toolCall.id,
                    "type": "function",
                    "function": [
                        "name": toolCall.name,
                        "arguments": toolCall.argumentsJSON
                    ]
                ]
            }
        ]
    }

    private static func jsonDictionary(from json: String) -> [String: Any] {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }

        return object
    }
}

private struct AIAssistantRemoteToolCall {
    let id: String
    let name: String
    let argumentsJSON: String
    let arguments: [String: Any]
}

private struct AIAssistantRemoteToolDefinition {
    let definition: AIAssistantToolDefinition
    let parameters: [String: Any]
}

@MainActor
private final class AIAssistantVMToolExecutor {
    private let emulator: EmulatorSession
    private let documentLibrary: AIDocumentLibraryStore
    private(set) var executedToolCount = 0

    init(emulator: EmulatorSession,
         documentLibrary: AIDocumentLibraryStore) {
        self.emulator = emulator
        self.documentLibrary = documentLibrary
    }

    var systemPrompt: String {
        return """
        You are the built-in VICE Mac assistant for a live Commodore emulator.
        Infer whether to answer or operate. Use read tools for state questions. Use apply_emulator_changes for live changes.
        Use search_machine_docs for machine documentation questions, then read_doc_context with a returned chunk_id when more surrounding text is needed.
        For multi-step changes, plan the full set first and batch them in one apply_emulator_changes call.
        For BASIC, submit numbered uppercase ASCII lines, then submit RUN only if requested.
        Do not claim a change happened unless the tool result says ok.
        Current machine: \(compactMachineContext())
        Keep responses concise. When you operate the machine, summarize exactly what you changed or typed.
        """
    }

    var foundationModelTools: [any Tool] {
        [
            AIAssistantMachineContextTool(executor: self),
            AIAssistantDebuggerSnapshotTool(executor: self),
            AIAssistantGetResourceTool(executor: self),
            AIAssistantApplyChangesTool(executor: self),
            AIAssistantPeekMemoryTool(executor: self),
            AIAssistantSearchMachineDocsTool(executor: self),
            AIAssistantReadDocContextTool(executor: self)
        ]
    }

    var openAIToolDefinitions: [[String: Any]] {
        Self.remoteToolDefinitions.map { tool in
            [
                "type": "function",
                "function": [
                    "name": tool.definition.name,
                    "description": tool.definition.description,
                    "parameters": tool.parameters
                ]
            ]
        }
    }

    var anthropicToolDefinitions: [[String: Any]] {
        Self.remoteToolDefinitions.map { tool in
            [
                "name": tool.definition.name,
                "description": tool.definition.description,
                "input_schema": tool.parameters
            ]
        }
    }

    func callRemoteTool(name: String,
                        arguments: [String: Any]) -> String {
        switch name {
        case AIAssistantToolDefinition.machineContext.name:
            return machineContextToolResult()
        case AIAssistantToolDefinition.debuggerSnapshot.name:
            return debuggerSnapshotToolResult(space: Self.stringValue(arguments["space"]))
        case AIAssistantToolDefinition.getResource.name:
            return getResourceToolResult(name: Self.stringValue(arguments["name"]) ?? "",
                                         valueType: Self.stringValue(arguments["valueType"] ?? arguments["value_type"]))
        case AIAssistantToolDefinition.applyChanges.name:
            return applyChangesToolResult(reason: Self.stringValue(arguments["reason"]),
                                          displayStyle: Self.displayStyleChange(arguments["displayStyle"] ?? arguments["display_style"]),
                                          memoryWrites: Self.memoryWriteChanges(arguments["memoryWrites"] ?? arguments["memory_writes"]),
                                          intResources: Self.intResourceChanges(arguments["intResources"] ?? arguments["int_resources"]),
                                          stringResources: Self.stringResourceChanges(arguments["stringResources"] ?? arguments["string_resources"]),
                                          typedText: Self.stringValue(arguments["typedText"] ?? arguments["typed_text"]),
                                          submittedLines: Self.stringArray(arguments["submittedLines"] ?? arguments["submitted_lines"]))
        case AIAssistantToolDefinition.peekMemory.name:
            return peekMemoryToolResult(space: Self.stringValue(arguments["space"]),
                                        bank: Self.intValue(arguments["bank"]),
                                        address: Self.stringValue(arguments["address"]) ?? "",
                                        length: Self.intValue(arguments["length"]) ?? 0)
        case AIAssistantToolDefinition.searchMachineDocs.name:
            return searchMachineDocsToolResult(query: Self.stringValue(arguments["query"]) ?? "",
                                               limit: Self.intValue(arguments["limit"]))
        case AIAssistantToolDefinition.readDocContext.name:
            return readDocContextToolResult(chunkID: Self.stringValue(arguments["chunkID"] ?? arguments["chunk_id"]) ?? "",
                                           before: Self.intValue(arguments["before"]),
                                           after: Self.intValue(arguments["after"]))
        default:
            executedToolCount += 1
            return Self.jsonString([
                "ok": false,
                "error": "Unknown tool: \(name)"
            ])
        }
    }

    func machineContextToolResult() -> String {
        executedToolCount += 1
        return Self.jsonString([
            "ok": true,
            "context": machineContext()
        ])
    }

    func debuggerSnapshotToolResult(space: String?) -> String {
        executedToolCount += 1
        guard let memorySpace = Self.memorySpace(space),
              let macVICEspace = MacVICEMemorySpace(rawValue: memorySpace.rawValue) else {
            return Self.jsonString([
                "ok": false,
                "error": "Unknown memory space."
            ])
        }

        do {
            let snapshot = try emulator.engine.debugger.snapshot(memorySpace: macVICEspace)
            return Self.jsonString([
                "ok": true,
                "snapshot": Self.debuggerSnapshotDictionary(snapshot)
            ])
        } catch {
            return Self.jsonString([
                "ok": false,
                "error": error.localizedDescription
            ])
        }
    }

    func getResourceToolResult(name: String, valueType: String?) -> String {
        executedToolCount += 1
        guard let resourceName = Self.resourceName(name) else {
            return Self.jsonString([
                "ok": false,
                "error": "Resource name is required and must be at most 63 bytes."
            ])
        }

        switch Self.resourceValueType(valueType) {
        case .int:
            return getIntResourceResult(resourceName)
        case .string:
            return getStringResourceResult(resourceName)
        case .auto:
            if let value = emulator.engine.intResource(resourceName) {
                return Self.jsonString([
                    "ok": true,
                    "name": resourceName,
                    "type": "int",
                    "value": value
                ])
            }
            return getStringResourceResult(resourceName)
        }
    }

    func setIntResourceToolResult(name: String, value: Int) -> String {
        executedToolCount += 1
        return Self.jsonString(applyIntResource(name: name, value: value))
    }

    func setStringResourceToolResult(name: String, value: String) -> String {
        executedToolCount += 1
        return Self.jsonString(applyStringResource(name: name, value: value))
    }

    func displayColorsToolResult(borderColor: Int?,
                                 backgroundColor: Int?,
                                 characterColor: Int?,
                                 applyToVisibleText: Bool?) -> String {
        executedToolCount += 1
        return Self.jsonString(applyDisplayColors(borderColor: borderColor,
                                                  backgroundColor: backgroundColor,
                                                  characterColor: characterColor,
                                                  applyToVisibleText: applyToVisibleText))
    }

    func applyChangesToolResult(reason: String?,
                                displayStyle: AIAssistantDisplayStyleChange?,
                                memoryWrites: [AIAssistantMemoryWriteChange]?,
                                intResources: [AIAssistantIntResourceChange]?,
                                stringResources: [AIAssistantStringResourceChange]?,
                                typedText: String?,
                                submittedLines: [String]?) -> String {
        executedToolCount += 1

        var allOK = true
        var operations: [[String: Any]] = []

        func appendOperation(_ kind: String, result: [String: Any]) {
            var operation = result
            operation["operation"] = kind
            operations.append(operation)
            allOK = allOK && ((result["ok"] as? Bool) == true)
        }

        if let displayStyle,
           displayStyle.borderColor != nil ||
            displayStyle.backgroundColor != nil ||
            displayStyle.characterColor != nil {
            appendOperation("display_style",
                            result: applyDisplayColors(borderColor: displayStyle.borderColor,
                                                       backgroundColor: displayStyle.backgroundColor,
                                                       characterColor: displayStyle.characterColor,
                                                       applyToVisibleText: displayStyle.applyToVisibleText))
        }

        for change in intResources ?? [] {
            appendOperation("int_resource",
                            result: applyIntResource(name: change.name,
                                                     value: change.value))
        }

        for change in stringResources ?? [] {
            appendOperation("string_resource",
                            result: applyStringResource(name: change.name,
                                                        value: change.value))
        }

        for change in memoryWrites ?? [] {
            appendOperation("memory_write",
                            result: applyMemoryWrite(space: change.space,
                                                     bank: change.bank,
                                                     address: change.address,
                                                     values: change.values))
        }

        if let text = typedText,
           !text.isEmpty {
            appendOperation("typed_text",
                            result: applyTypedText(text))
        }

        if let submittedLines,
           !submittedLines.isEmpty {
            appendOperation("submitted_lines",
                            result: applySubmittedLines(submittedLines))
        }

        guard !operations.isEmpty else {
            return Self.jsonString([
                "ok": false,
                "error": "apply_emulator_changes requires at least one change."
            ])
        }

        var response: [String: Any] = [
            "ok": allOK,
            "operation_count": operations.count,
            "operations": operations
        ]
        if let reason = Self.nonEmptyString(reason) {
            response["reason"] = reason
        }
        return Self.jsonString(response)
    }

    func peekMemoryToolResult(space: String?, bank: Int?, address: String, length: Int) -> String {
        executedToolCount += 1
        var arguments: [String: Any] = [
            "address": address,
            "length": length
        ]
        if let space = Self.nonEmptyString(space) {
            arguments["space"] = space
        }
        if let bank {
            arguments["bank"] = bank
        }

        return peekMemory(arguments)
    }

    func searchMachineDocsToolResult(query: String, limit: Int?) -> String {
        executedToolCount += 1
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            return Self.jsonString([
                "ok": false,
                "error": "search_machine_docs requires a query."
            ])
        }

        let machineID = emulator.machine.id.rawValue
        let clampedLimit = min(max(limit ?? 8, 1), 20)

        do {
            let results = try documentLibrary.search(machineID: machineID,
                                                     query: normalizedQuery,
                                                     limit: clampedLimit)
            return Self.jsonString([
                "ok": true,
                "machine": [
                    "id": machineID,
                    "name": emulator.machineDisplayName
                ],
                "query": normalizedQuery,
                "match_count": results.count,
                "matches": results.map(Self.searchResultDictionary)
            ])
        } catch {
            return Self.jsonString([
                "ok": false,
                "error": error.localizedDescription
            ])
        }
    }

    func readDocContextToolResult(chunkID: String, before: Int?, after: Int?) -> String {
        executedToolCount += 1
        let normalizedChunkID = chunkID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedChunkID.isEmpty else {
            return Self.jsonString([
                "ok": false,
                "error": "read_doc_context requires a chunk_id returned by search_machine_docs."
            ])
        }

        let machineID = emulator.machine.id.rawValue
        let beforeCount = min(max(before ?? 1, 0), 2)
        let afterCount = min(max(after ?? 1, 0), 2)

        do {
            guard let context = try documentLibrary.context(machineID: machineID,
                                                            chunkID: normalizedChunkID,
                                                            before: beforeCount,
                                                            after: afterCount) else {
                return Self.jsonString([
                    "ok": false,
                    "error": "No indexed document context matched that chunk_id for the current machine."
                ])
            }

            return Self.jsonString([
                "ok": true,
                "document": [
                    "id": context.documentID.uuidString,
                    "title": context.title,
                    "machine_id": context.machineID
                ],
                "chunks": Self.contextChunkDictionaries(context.chunks)
            ])
        } catch {
            return Self.jsonString([
                "ok": false,
                "error": error.localizedDescription
            ])
        }
    }

    func pokeMemoryToolResult(space: String?, bank: Int?, address: String, values: [Int]) -> String {
        executedToolCount += 1
        var arguments: [String: Any] = [
            "address": address,
            "values": values
        ]
        if let space = Self.nonEmptyString(space) {
            arguments["space"] = space
        }
        if let bank {
            arguments["bank"] = bank
        }

        return pokeMemory(arguments)
    }

    func typeTextToolResult(text: String) -> String {
        executedToolCount += 1
        return typeText(["text": text])
    }

    func submitLineToolResult(line: String) -> String {
        executedToolCount += 1
        return submitLine(["line": line])
    }

    func submitLinesToolResult(lines: [String]) -> String {
        executedToolCount += 1
        return submitLines(["lines": lines])
    }

    private func compactMachineContext() -> String {
        "\(emulator.machineDisplayName) (\(emulator.machine.shortName)), " +
            "\(emulator.videoStandard.rawValue), \(emulator.displayOutput.statusTitle)"
    }

    private func machineContext() -> [String: Any] {
        var context: [String: Any] = [
            "machine": [
                "id": emulator.machine.id.rawValue,
                "name": emulator.machineDisplayName,
                "vice_target": emulator.machine.shortName,
                "video_standard": emulator.videoStandard.rawValue,
                "display_output": emulator.displayOutput.statusTitle,
                "ram_expansion": emulator.ramExpansion.displayTitle(for: emulator.machine)
            ],
            "drives": emulator.driveConfigurations.map { drive in
                [
                    "unit": drive.unit,
                    "attached": drive.isAttached,
                    "type": drive.driveType.title,
                    "access_mode": drive.accessMode.title
                ]
            },
            "control_ports": emulator.availableControlPorts.map { port in
                [
                    "port": port.rawValue,
                    "device": emulator.controlPortDevice(for: port)?.name ?? "None"
                ]
            }
        ]
        context["display_colors"] = displayColorState()
        return context
    }

    private var supportsVICIIDisplayColors: Bool {
        switch emulator.machine.family {
        case .c64, .c128:
            return true
        case .pet, .vic20, .ted:
            return false
        }
    }

    private func displayColorState(includeVisibleTextSummary: Bool = false) -> [String: Any] {
        guard supportsVICIIDisplayColors else {
            return [
                "supported": false,
                "note": "VIC-II color helper supports C64 and C128 40-column display state."
            ]
        }

        let border = emulator.peekMemory(space: .computer,
                                         bank: EmulatorSession.currentMemoryBank,
                                         address: Self.viciiBorderColorAddress,
                                         length: 1)?.first
        let background = emulator.peekMemory(space: .computer,
                                             bank: EmulatorSession.currentMemoryBank,
                                             address: Self.viciiBackgroundColorAddress,
                                             length: 1)?.first
        let character = emulator.peekMemory(space: .computer,
                                            bank: EmulatorSession.currentMemoryBank,
                                            address: Self.viciiCurrentTextColorAddress,
                                            length: 1)?.first
        var state: [String: Any] = [
            "supported": true,
            "border_address": Self.addressString(Self.viciiBorderColorAddress),
            "background_address": Self.addressString(Self.viciiBackgroundColorAddress),
            "current_character_color_address": Self.addressString(Self.viciiCurrentTextColorAddress),
            "visible_character_color_ram_address": Self.addressString(Self.viciiColorRAMAddress),
            "color_palette": Self.commodoreColorPalette()
        ]
        if let border {
            state["border_color"] = Int(border)
            state["border_color_name"] = Self.commodoreColorName(Int(border))
        }
        if let background {
            state["background_color"] = Int(background)
            state["background_color_name"] = Self.commodoreColorName(Int(background))
        }
        if let character {
            let color = Int(character & 0x0f)
            state["current_character_color"] = color
            state["current_character_color_name"] = Self.commodoreColorName(color)
        }
        if includeVisibleTextSummary {
            state["visible_character_color_summary"] = visibleCharacterColorSummary()
        }
        return state
    }

    private func visibleCharacterColorSummary() -> [String: Any] {
        guard let colorRAM = emulator.peekMemory(space: .computer,
                                                 bank: EmulatorSession.currentMemoryBank,
                                                 address: Self.viciiColorRAMAddress,
                                                 length: Self.viciiVisibleTextCellCount) else {
            return [
                "ok": false,
                "error": "Unable to read visible character color RAM."
            ]
        }

        var counts: [String: Int] = [:]
        for byte in colorRAM {
            let color = Int(byte & 0x0f)
            counts[Self.commodoreColorName(color)] = (counts[Self.commodoreColorName(color)] ?? 0) + 1
        }

        return [
            "ok": true,
            "cell_count": colorRAM.count,
            "counts_by_color": counts
        ]
    }

    private func commonResourceState() -> [[String: Any]] {
        let resourceNames = [
            "MachineVideoStandard",
            "Sound",
            "SoundVolume",
            "Speed",
            "SidModel",
            "SidStereo",
            "KeymapIndex",
            "Drive8Type",
            "Drive8TrueEmulation",
            "TrapDevice8",
            "Drive9Type",
            "Drive9TrueEmulation",
            "TrapDevice9"
        ]

        return resourceNames.compactMap { resourceName in
            guard let value = emulator.engine.intResource(resourceName) else {
                return nil
            }

            return [
                "name": resourceName,
                "type": "int",
                "value": value
            ]
        }
    }

    private func getIntResourceResult(_ resourceName: String) -> String {
        guard let value = emulator.engine.intResource(resourceName) else {
            return Self.jsonString([
                "ok": false,
                "name": resourceName,
                "type": "int",
                "error": "Unable to read integer resource."
            ])
        }

        return Self.jsonString([
            "ok": true,
            "name": resourceName,
            "type": "int",
            "value": value
        ])
    }

    private func getStringResourceResult(_ resourceName: String) -> String {
        guard let value = emulator.engine.stringResource(resourceName) else {
            return Self.jsonString([
                "ok": false,
                "name": resourceName,
                "type": "string",
                "error": "Unable to read string resource."
            ])
        }

        return Self.jsonString([
            "ok": true,
            "name": resourceName,
            "type": "string",
            "value": value
        ])
    }

    private func peekMemory(_ arguments: [String: Any]) -> String {
        guard let address = Self.addressValue(arguments["address"]),
              let length = Self.intValue(arguments["length"]),
              (1...512).contains(length) else {
            return Self.jsonString([
                "ok": false,
                "error": "peek_memory requires address and length between 1 and 512."
            ])
        }

        guard let space = Self.memorySpace(arguments["space"]) else {
            return Self.jsonString([
                "ok": false,
                "error": "Unknown memory space."
            ])
        }

        let bank = Int32(Self.intValue(arguments["bank"]) ?? Int(EmulatorSession.currentMemoryBank))
        guard let data = emulator.peekMemory(space: space,
                                             bank: bank,
                                             address: address,
                                             length: length) else {
            return Self.jsonString([
                "ok": false,
                "error": "Unable to read memory."
            ])
        }

        let bytes = [UInt8](data)
        return Self.jsonString([
            "ok": true,
            "space": space.title,
            "bank": bank,
            "address": Self.addressString(address),
            "length": bytes.count,
            "hex": bytes.map { String(format: "%02X", $0) }.joined(separator: " "),
            "ascii": Self.asciiString(bytes)
        ])
    }

    private func pokeMemory(_ arguments: [String: Any]) -> String {
        guard let address = Self.addressValue(arguments["address"]),
              let values = Self.byteArray(arguments["values"]),
              !values.isEmpty,
              values.count <= 512 else {
            return Self.jsonString([
                "ok": false,
                "error": "poke_memory requires address and 1 to 512 byte values."
            ])
        }

        guard let space = Self.memorySpace(arguments["space"]) else {
            return Self.jsonString([
                "ok": false,
                "error": "Unknown memory space."
            ])
        }

        let bank = Int32(Self.intValue(arguments["bank"]) ?? Int(EmulatorSession.currentMemoryBank))
        let didWrite = emulator.pokeMemory(space: space,
                                           bank: bank,
                                           address: address,
                                           bytes: values)
        return Self.jsonString([
            "ok": didWrite,
            "space": space.title,
            "bank": bank,
            "address": Self.addressString(address),
            "length": values.count
        ])
    }

    private func typeText(_ arguments: [String: Any]) -> String {
        guard let text = arguments["text"] as? String,
              !text.isEmpty else {
            return Self.jsonString([
                "ok": false,
                "error": "type_text requires text."
            ])
        }

        let normalizedText = Self.normalizedBASICInput(text)
        let didQueue = emulator.typeText(normalizedText)
        return Self.jsonString([
            "ok": didQueue,
            "typed": normalizedText
        ])
    }

    private func submitLine(_ arguments: [String: Any]) -> String {
        guard let line = arguments["line"] as? String,
              !line.isEmpty else {
            return Self.jsonString([
                "ok": false,
                "error": "submit_line requires line."
            ])
        }

        let normalizedLine = Self.normalizedBASICInput(line)
        let didQueue = emulator.submitLine(normalizedLine)
        return Self.jsonString([
            "ok": didQueue,
            "submitted": normalizedLine
        ])
    }

    private func submitLines(_ arguments: [String: Any]) -> String {
        guard let lines = arguments["lines"] as? [String],
              !lines.isEmpty,
              lines.count <= 200 else {
            return Self.jsonString([
                "ok": false,
                "error": "submit_lines requires 1 to 200 lines."
            ])
        }

        var queuedLines: [String] = []
        for line in lines where !line.isEmpty {
            let normalizedLine = Self.normalizedBASICInput(line)
            if emulator.submitLine(normalizedLine) {
                queuedLines.append(normalizedLine)
            }
        }

        return Self.jsonString([
            "ok": queuedLines.count == lines.count,
            "submitted_count": queuedLines.count,
            "submitted": queuedLines
        ])
    }

    private func applyIntResource(name: String, value: Int) -> [String: Any] {
        guard let resourceName = Self.resourceName(name),
              (Int(Int32.min)...Int(Int32.max)).contains(value) else {
            return [
                "ok": false,
                "error": "Integer resource changes require a resource name up to 63 bytes and a signed 32-bit value."
            ]
        }

        let didSet = emulator.engine.setIntResource(resourceName, value: Int32(value))
        var response: [String: Any] = [
            "ok": didSet,
            "name": resourceName,
            "type": "int",
            "requested_value": value
        ]
        if let currentValue = emulator.engine.intResource(resourceName) {
            response["current_value"] = currentValue
        }
        return response
    }

    private func applyStringResource(name: String, value: String) -> [String: Any] {
        guard let resourceName = Self.resourceName(name),
              value.utf8.count < 4096 else {
            return [
                "ok": false,
                "error": "String resource changes require a resource name up to 63 bytes and a value under 4096 bytes."
            ]
        }

        let didSet = emulator.engine.setStringResource(resourceName, value: value)
        var response: [String: Any] = [
            "ok": didSet,
            "name": resourceName,
            "type": "string",
            "requested_value": value
        ]
        if let currentValue = emulator.engine.stringResource(resourceName) {
            response["current_value"] = currentValue
        }
        return response
    }

    private func applyDisplayColors(borderColor: Int?,
                                    backgroundColor: Int?,
                                    characterColor: Int?,
                                    applyToVisibleText: Bool?) -> [String: Any] {
        guard supportsVICIIDisplayColors else {
            return [
                "ok": false,
                "error": "Display color changes currently support C64 and C128 40-column VIC-II display state."
            ]
        }

        var didSet = true
        var changed: [String] = []

        if let borderColor {
            guard let color = Self.commodoreColorByte(borderColor) else {
                return [
                    "ok": false,
                    "error": "border_color must be 0 through 15."
                ]
            }
            didSet = didSet && emulator.pokeMemory(space: .computer,
                                                   bank: EmulatorSession.currentMemoryBank,
                                                   address: Self.viciiBorderColorAddress,
                                                   bytes: [color])
            changed.append("border")
        }

        if let backgroundColor {
            guard let color = Self.commodoreColorByte(backgroundColor) else {
                return [
                    "ok": false,
                    "error": "background_color must be 0 through 15."
                ]
            }
            didSet = didSet && emulator.pokeMemory(space: .computer,
                                                   bank: EmulatorSession.currentMemoryBank,
                                                   address: Self.viciiBackgroundColorAddress,
                                                   bytes: [color])
            changed.append("background")
        }

        if let characterColor {
            guard let color = Self.commodoreColorByte(characterColor) else {
                return [
                    "ok": false,
                    "error": "character_color must be 0 through 15."
                ]
            }

            didSet = didSet && emulator.pokeMemory(space: .computer,
                                                   bank: EmulatorSession.currentMemoryBank,
                                                   address: Self.viciiCurrentTextColorAddress,
                                                   bytes: [color])
            changed.append("current_character_color")

            if applyToVisibleText ?? true {
                didSet = didSet && emulator.pokeMemory(space: .computer,
                                                       bank: EmulatorSession.currentMemoryBank,
                                                       address: Self.viciiColorRAMAddress,
                                                       bytes: [UInt8](repeating: color,
                                                                       count: Self.viciiVisibleTextCellCount))
                changed.append("visible_character_color_ram")
            }
        }

        var response: [String: Any] = [
            "ok": didSet,
            "changed": changed,
            "display_colors": displayColorState(includeVisibleTextSummary: characterColor != nil)
        ]
        if changed.isEmpty {
            response["note"] = "No color arguments were provided; returned current display colors."
        }
        return response
    }

    private func applyMemoryWrite(space: String?,
                                  bank: Int?,
                                  address: String,
                                  values: [Int]) -> [String: Any] {
        guard let address = Self.addressValue(address),
              !values.isEmpty,
              values.count <= 512 else {
            return [
                "ok": false,
                "error": "Memory writes require an address and 1 to 512 byte values."
            ]
        }

        var bytes: [UInt8] = []
        for value in values {
            guard (0...255).contains(value) else {
                return [
                    "ok": false,
                    "error": "Memory write values must be 0 through 255."
                ]
            }
            bytes.append(UInt8(value))
        }

        guard let memorySpace = Self.memorySpace(space) else {
            return [
                "ok": false,
                "error": "Unknown memory space."
            ]
        }

        let normalizedBank: Int32
        if let bank {
            guard let bankValue = Int32(exactly: bank) else {
                return [
                    "ok": false,
                    "error": "Memory bank must fit in a signed 32-bit value."
                ]
            }
            normalizedBank = bankValue
        } else {
            normalizedBank = EmulatorSession.currentMemoryBank
        }

        let didWrite = emulator.pokeMemory(space: memorySpace,
                                           bank: normalizedBank,
                                           address: address,
                                           bytes: bytes)
        return [
            "ok": didWrite,
            "space": memorySpace.title,
            "bank": normalizedBank,
            "address": Self.addressString(address),
            "length": bytes.count
        ]
    }

    private func applyTypedText(_ text: String) -> [String: Any] {
        guard !text.isEmpty else {
            return [
                "ok": false,
                "error": "Typed text cannot be empty."
            ]
        }

        let normalizedText = Self.normalizedBASICInput(text)
        let didQueue = emulator.typeText(normalizedText)
        return [
            "ok": didQueue,
            "typed": normalizedText
        ]
    }

    private func applySubmittedLines(_ lines: [String]) -> [String: Any] {
        guard !lines.isEmpty,
              lines.count <= 200 else {
            return [
                "ok": false,
                "error": "Submitted lines require 1 to 200 lines."
            ]
        }

        var queuedLines: [String] = []
        for line in lines where !line.isEmpty {
            let normalizedLine = Self.normalizedBASICInput(line)
            if emulator.submitLine(normalizedLine) {
                queuedLines.append(normalizedLine)
            }
        }

        return [
            "ok": queuedLines.count == lines.count,
            "submitted_count": queuedLines.count,
            "submitted": queuedLines
        ]
    }

    private static func displayStyleChange(_ value: Any?) -> AIAssistantDisplayStyleChange? {
        guard let dictionary = objectDictionary(value) else {
            return nil
        }

        let borderColor = intValue(dictionary["borderColor"] ?? dictionary["border_color"])
        let backgroundColor = intValue(dictionary["backgroundColor"] ?? dictionary["background_color"])
        let characterColor = intValue(dictionary["characterColor"] ?? dictionary["character_color"])
        let applyToVisibleText = boolValue(dictionary["applyToVisibleText"] ?? dictionary["apply_to_visible_text"])
        guard borderColor != nil ||
                backgroundColor != nil ||
                characterColor != nil ||
                applyToVisibleText != nil else {
            return nil
        }

        return AIAssistantDisplayStyleChange(borderColor: borderColor,
                                             backgroundColor: backgroundColor,
                                             characterColor: characterColor,
                                             applyToVisibleText: applyToVisibleText)
    }

    private static func memoryWriteChanges(_ value: Any?) -> [AIAssistantMemoryWriteChange]? {
        let changes = dictionaryArray(value).compactMap { dictionary -> AIAssistantMemoryWriteChange? in
            guard let address = stringValue(dictionary["address"]),
                  let values = intArray(dictionary["values"]) else {
                return nil
            }

            return AIAssistantMemoryWriteChange(space: stringValue(dictionary["space"]),
                                                bank: intValue(dictionary["bank"]),
                                                address: address,
                                                values: values)
        }

        return changes.isEmpty ? nil : changes
    }

    private static func intResourceChanges(_ value: Any?) -> [AIAssistantIntResourceChange]? {
        let changes = dictionaryArray(value).compactMap { dictionary -> AIAssistantIntResourceChange? in
            guard let name = stringValue(dictionary["name"]),
                  let value = intValue(dictionary["value"]) else {
                return nil
            }

            return AIAssistantIntResourceChange(name: name,
                                                value: value)
        }

        return changes.isEmpty ? nil : changes
    }

    private static func stringResourceChanges(_ value: Any?) -> [AIAssistantStringResourceChange]? {
        let changes = dictionaryArray(value).compactMap { dictionary -> AIAssistantStringResourceChange? in
            guard let name = stringValue(dictionary["name"]),
                  let value = stringValue(dictionary["value"]) else {
                return nil
            }

            return AIAssistantStringResourceChange(name: name,
                                                  value: value)
        }

        return changes.isEmpty ? nil : changes
    }

    private static func normalizedBASICInput(_ text: String) -> String {
        text.uppercased()
    }

    private static func nonEmptyString(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func objectDictionary(_ value: Any?) -> [String: Any]? {
        value as? [String: Any]
    }

    private static func dictionaryArray(_ value: Any?) -> [[String: Any]] {
        if let dictionaries = value as? [[String: Any]] {
            return dictionaries
        }

        guard let values = value as? [Any] else {
            return []
        }

        return values.compactMap { value in
            value as? [String: Any]
        }
    }

    private static func stringValue(_ value: Any?) -> String? {
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        if let number = value as? NSNumber {
            return number.stringValue
        }

        return nil
    }

    private static func stringArray(_ value: Any?) -> [String]? {
        if let strings = value as? [String] {
            return strings
        }

        guard let values = value as? [Any] else {
            return nil
        }

        let strings = values.compactMap { stringValue($0) }
        return strings.isEmpty ? nil : strings
    }

    private static func boolValue(_ value: Any?) -> Bool? {
        if let bool = value as? Bool {
            return bool
        }

        if let number = value as? NSNumber {
            return number.boolValue
        }

        guard let string = value as? String else {
            return nil
        }

        switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "true", "yes", "1":
            return true
        case "false", "no", "0":
            return false
        default:
            return nil
        }
    }

    private enum ResourceValueType {
        case auto
        case int
        case string
    }

    private static func resourceValueType(_ value: String?) -> ResourceValueType {
        switch nonEmptyString(value)?.lowercased() {
        case "int", "integer", "number":
            return .int
        case "string", "text":
            return .string
        default:
            return .auto
        }
    }

    private static func resourceName(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty,
              trimmed.utf8.count < 64,
              trimmed.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else {
            return nil
        }

        return trimmed
    }

    private static func memorySpace(_ value: Any?) -> EmulatorSession.MemorySpace? {
        let rawValue = (value as? String) ?? "computer"
        switch rawValue.lowercased() {
        case "computer", "main", "cpu":
            return .computer
        case "drive8", "drive_8", "8":
            return .drive8
        case "drive9", "drive_9", "9":
            return .drive9
        case "drive10", "drive_10", "10":
            return .drive10
        case "drive11", "drive_11", "11":
            return .drive11
        default:
            return nil
        }
    }

    private static func addressValue(_ value: Any?) -> UInt16? {
        guard let parsed = intValue(value),
              (0...Int(UInt16.max)).contains(parsed) else {
            return nil
        }

        return UInt16(parsed)
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int {
            return int
        }

        if let number = value as? NSNumber {
            return number.intValue
        }

        guard let string = value as? String else {
            return nil
        }

        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("$") {
            return Int(trimmed.dropFirst(), radix: 16)
        }

        if trimmed.lowercased().hasPrefix("0x") {
            return Int(trimmed.dropFirst(2), radix: 16)
        }

        return Int(trimmed)
    }

    private static func byteArray(_ value: Any?) -> [UInt8]? {
        guard let values = value as? [Any] else {
            return nil
        }

        var bytes: [UInt8] = []
        for value in values {
            guard let intValue = intValue(value),
                  (0...255).contains(intValue) else {
                return nil
            }

            bytes.append(UInt8(intValue))
        }

        return bytes
    }

    private static func intArray(_ value: Any?) -> [Int]? {
        if let values = value as? [Int] {
            return values
        }

        guard let values = value as? [Any] else {
            return nil
        }

        let ints = values.compactMap { intValue($0) }
        return ints.count == values.count ? ints : nil
    }

    private static func addressString(_ address: UInt16) -> String {
        String(format: "$%04X", address)
    }

    private static func commodoreColorByte(_ color: Int) -> UInt8? {
        guard (0...15).contains(color) else {
            return nil
        }

        return UInt8(color)
    }

    private static func commodoreColorName(_ color: Int) -> String {
        switch color & 0x0f {
        case 0:
            return "black"
        case 1:
            return "white"
        case 2:
            return "red"
        case 3:
            return "cyan"
        case 4:
            return "purple"
        case 5:
            return "green"
        case 6:
            return "blue"
        case 7:
            return "yellow"
        case 8:
            return "orange"
        case 9:
            return "brown"
        case 10:
            return "light red"
        case 11:
            return "dark gray"
        case 12:
            return "medium gray"
        case 13:
            return "light green"
        case 14:
            return "light blue"
        case 15:
            return "light gray"
        default:
            return "unknown"
        }
    }

    private static func commodoreColorPalette() -> [String: String] {
        Dictionary(uniqueKeysWithValues: (0...15).map { color in
            (String(color), commodoreColorName(color))
        })
    }

    private static func searchResultDictionary(_ result: AIDocumentSearchResult) -> [String: Any] {
        [
            "chunk_id": result.chunkID,
            "chunkID": result.chunkID,
            "document_id": result.documentID.uuidString,
            "title": result.title,
            "machine_id": result.machineID,
            "chunk_index": result.chunkIndex,
            "page_start": result.pageStart,
            "page_end": result.pageEnd,
            "score": result.score,
            "excerpt": result.excerpt
        ]
    }

    private static func contextChunkDictionaries(_ chunks: [AIDocumentContextResult.Chunk]) -> [[String: Any]] {
        var remainingCharacters = 10_000
        var dictionaries: [[String: Any]] = []

        for chunk in chunks {
            guard remainingCharacters > 0 else {
                break
            }

            let text = chunk.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let limitedText = String(text.prefix(remainingCharacters))
            remainingCharacters -= limitedText.count

            var dictionary: [String: Any] = [
                "chunk_id": chunk.chunkID,
                "chunkID": chunk.chunkID,
                "chunk_index": chunk.chunkIndex,
                "page_start": chunk.pageStart,
                "page_end": chunk.pageEnd,
                "text": limitedText
            ]
            if limitedText.count < text.count {
                dictionary["truncated"] = true
            }
            dictionaries.append(dictionary)
        }

        return dictionaries
    }

    private static func debuggerSnapshotSummary(_ snapshot: MacVICEDebuggerSnapshot) -> [String: Any] {
        [
            "memory_space": memorySpaceTitle(snapshot.memorySpace),
            "bank": snapshot.bank,
            "cycle": snapshot.cycle,
            "program_counter": String(format: "$%04X", snapshot.programCounter & 0xffff)
        ]
    }

    private static func debuggerSnapshotDictionary(_ snapshot: MacVICEDebuggerSnapshot) -> [String: Any] {
        [
            "memory_space": memorySpaceTitle(snapshot.memorySpace),
            "cpu_type": snapshot.cpuType,
            "bank": snapshot.bank,
            "cycle": snapshot.cycle,
            "program_counter": String(format: "$%04X", snapshot.programCounter & 0xffff),
            "supported_cpu_types": snapshot.supportedCPUTypes,
            "registers": snapshot.registers.map { register in
                [
                    "id": register.id,
                    "name": register.name,
                    "bit_width": register.bitWidth,
                    "value": register.value,
                    "hex": String(format: register.bitWidth > 8 ? "$%04X" : "$%02X", register.value),
                    "flags": register.flags
                ] as [String: Any]
            }
        ]
    }

    private static func memorySpaceTitle(_ space: MacVICEMemorySpace) -> String {
        switch space {
        case .computer:
            return "Computer"
        case .drive8:
            return "Drive 8"
        case .drive9:
            return "Drive 9"
        case .drive10:
            return "Drive 10"
        case .drive11:
            return "Drive 11"
        }
    }

    private static func asciiString(_ bytes: [UInt8]) -> String {
        bytes.map { byte in
            if (32...126).contains(Int(byte)),
               let scalar = UnicodeScalar(Int(byte)) {
                return String(scalar)
            }

            return "."
        }
        .joined()
    }

    private static func jsonString(_ object: Any) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object,
                                                     options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "{\"ok\":false,\"error\":\"Unable to encode tool result.\"}"
        }

        return string
    }

    private static let remoteToolDefinitions: [AIAssistantRemoteToolDefinition] = [
        AIAssistantRemoteToolDefinition(
            definition: .machineContext,
            parameters: objectSchema(properties: [
                "reason": stringSchema("Optional reason.")
            ])
        ),
        AIAssistantRemoteToolDefinition(
            definition: .debuggerSnapshot,
            parameters: objectSchema(properties: [
                "space": stringSchema("Memory space: computer, drive8, drive9, drive10, or drive11.")
            ])
        ),
        AIAssistantRemoteToolDefinition(
            definition: .getResource,
            parameters: objectSchema(properties: [
                "name": stringSchema("VICE resource name."),
                "valueType": stringSchema("auto, int, or string.")
            ], required: ["name"])
        ),
        AIAssistantRemoteToolDefinition(
            definition: .applyChanges,
            parameters: objectSchema(properties: [
                "reason": stringSchema("Short reason for the batch."),
                "displayStyle": objectSchema(properties: [
                    "borderColor": integerSchema("Commodore color index 0 through 15."),
                    "backgroundColor": integerSchema("Commodore color index 0 through 15."),
                    "characterColor": integerSchema("Text color index 0 through 15."),
                    "applyToVisibleText": boolSchema("Also recolor visible text color RAM. Defaults to true.")
                ]),
                "memoryWrites": arraySchema("Raw memory writes.",
                                            items: objectSchema(properties: [
                                                "space": stringSchema("computer, drive8, drive9, drive10, or drive11."),
                                                "bank": integerSchema("VICE memory bank; omit for current."),
                                                "address": stringSchema("Start address, such as $0400, 0x0400, or 1024."),
                                                "values": arraySchema("Byte values, each 0 through 255.",
                                                                      items: integerSchema("Byte value."))
                                            ], required: ["address", "values"])),
                "intResources": arraySchema("VICE integer resource writes.",
                                            items: objectSchema(properties: [
                                                "name": stringSchema("VICE resource name."),
                                                "value": integerSchema("Signed 32-bit integer value.")
                                            ], required: ["name", "value"])),
                "stringResources": arraySchema("VICE string resource writes.",
                                               items: objectSchema(properties: [
                                                   "name": stringSchema("VICE resource name."),
                                                   "value": stringSchema("String value.")
                                               ], required: ["name", "value"])),
                "typedText": stringSchema("Text to type without pressing Return."),
                "submittedLines": arraySchema("Lines to type and submit with Return.",
                                              items: stringSchema("Line."))
            ])
        ),
        AIAssistantRemoteToolDefinition(
            definition: .peekMemory,
            parameters: objectSchema(properties: [
                "space": stringSchema("computer, drive8, drive9, drive10, or drive11."),
                "bank": integerSchema("VICE memory bank; omit for current."),
                "address": stringSchema("Start address, such as $0400, 0x0400, or 1024."),
                "length": integerSchema("Number of bytes, 1 through 512.")
            ], required: ["address", "length"])
        ),
        AIAssistantRemoteToolDefinition(
            definition: .searchMachineDocs,
            parameters: objectSchema(properties: [
                "query": stringSchema("Keywords to search in indexed documentation for the current machine."),
                "limit": integerSchema("Maximum matches, 1 through 20. Defaults to 8.")
            ], required: ["query"])
        ),
        AIAssistantRemoteToolDefinition(
            definition: .readDocContext,
            parameters: objectSchema(properties: [
                "chunkID": stringSchema("chunk_id returned by search_machine_docs."),
                "before": integerSchema("Previous chunks to include, 0 through 2. Defaults to 1."),
                "after": integerSchema("Following chunks to include, 0 through 2. Defaults to 1.")
            ], required: ["chunkID"])
        )
    ]

    private static func objectSchema(properties: [String: Any],
                                     required: [String] = []) -> [String: Any] {
        var schema: [String: Any] = [
            "type": "object",
            "properties": properties
        ]
        if !required.isEmpty {
            schema["required"] = required
        }
        return schema
    }

    private static func stringSchema(_ description: String) -> [String: Any] {
        [
            "type": "string",
            "description": description
        ]
    }

    private static func integerSchema(_ description: String) -> [String: Any] {
        [
            "type": "integer",
            "description": description
        ]
    }

    private static func boolSchema(_ description: String) -> [String: Any] {
        [
            "type": "boolean",
            "description": description
        ]
    }

    private static func arraySchema(_ description: String,
                                    items: [String: Any]) -> [String: Any] {
        [
            "type": "array",
            "description": description,
            "items": items
        ]
    }

    private static let viciiBorderColorAddress: UInt16 = 0xd020
    private static let viciiBackgroundColorAddress: UInt16 = 0xd021
    private static let viciiCurrentTextColorAddress: UInt16 = 0x0286
    private static let viciiColorRAMAddress: UInt16 = 0xd800
    private static let viciiVisibleTextCellCount = 1000
}

@Generable
private struct AIAssistantMachineContextArguments {
    @Guide(description: "Optional reason.")
    var reason: String?
}

private struct AIAssistantMachineContextTool: Tool, @unchecked Sendable {
    typealias Arguments = AIAssistantMachineContextArguments
    typealias Output = String

    let executor: AIAssistantVMToolExecutor

    var name: String { AIAssistantToolDefinition.machineContext.name }
    var description: String { AIAssistantToolDefinition.machineContext.description }

    @concurrent func call(arguments: AIAssistantMachineContextArguments) async throws -> String {
        await executor.machineContextToolResult()
    }
}

@Generable
private struct AIAssistantDebuggerSnapshotArguments {
    @Guide(description: "computer, drive8, drive9, drive10, or drive11.")
    var space: String?
}

private struct AIAssistantDebuggerSnapshotTool: Tool, @unchecked Sendable {
    typealias Arguments = AIAssistantDebuggerSnapshotArguments
    typealias Output = String

    let executor: AIAssistantVMToolExecutor

    var name: String { AIAssistantToolDefinition.debuggerSnapshot.name }
    var description: String { AIAssistantToolDefinition.debuggerSnapshot.description }

    @concurrent func call(arguments: AIAssistantDebuggerSnapshotArguments) async throws -> String {
        await executor.debuggerSnapshotToolResult(space: arguments.space)
    }
}

@Generable
private struct AIAssistantGetResourceArguments {
    @Guide(description: "VICE resource name.")
    var name: String

    @Guide(description: "auto, int, or string.")
    var valueType: String?
}

private struct AIAssistantGetResourceTool: Tool, @unchecked Sendable {
    typealias Arguments = AIAssistantGetResourceArguments
    typealias Output = String

    let executor: AIAssistantVMToolExecutor

    var name: String { AIAssistantToolDefinition.getResource.name }
    var description: String { AIAssistantToolDefinition.getResource.description }

    @concurrent func call(arguments: AIAssistantGetResourceArguments) async throws -> String {
        await executor.getResourceToolResult(name: arguments.name,
                                             valueType: arguments.valueType)
    }
}

@Generable
private struct AIAssistantSetIntResourceArguments {
    @Guide(description: "VICE integer resource name, such as Sound, SoundVolume, Speed, SidModel, MachineVideoStandard, VICIIBorderColor, or VICIIBackgroundColor.")
    var name: String

    @Guide(description: "Signed 32-bit integer value to assign.")
    var value: Int
}

private struct AIAssistantSetIntResourceTool: Tool, @unchecked Sendable {
    typealias Arguments = AIAssistantSetIntResourceArguments
    typealias Output = String

    let executor: AIAssistantVMToolExecutor

    var name: String { AIAssistantToolDefinition.setIntResource.name }
    var description: String { AIAssistantToolDefinition.setIntResource.description }

    @concurrent func call(arguments: AIAssistantSetIntResourceArguments) async throws -> String {
        await executor.setIntResourceToolResult(name: arguments.name,
                                                value: arguments.value)
    }
}

@Generable
private struct AIAssistantSetStringResourceArguments {
    @Guide(description: "VICE string resource name, such as keymap, ROM, palette, printer, or filesystem path resources.")
    var name: String

    @Guide(description: "String value to assign.")
    var value: String
}

private struct AIAssistantSetStringResourceTool: Tool, @unchecked Sendable {
    typealias Arguments = AIAssistantSetStringResourceArguments
    typealias Output = String

    let executor: AIAssistantVMToolExecutor

    var name: String { AIAssistantToolDefinition.setStringResource.name }
    var description: String { AIAssistantToolDefinition.setStringResource.description }

    @concurrent func call(arguments: AIAssistantSetStringResourceArguments) async throws -> String {
        await executor.setStringResourceToolResult(name: arguments.name,
                                                   value: arguments.value)
    }
}

@Generable
private struct AIAssistantDisplayStyleChange {
    @Guide(description: "Color index 0-15.")
    var borderColor: Int?

    @Guide(description: "Color index 0-15.")
    var backgroundColor: Int?

    @Guide(description: "Text color index 0-15.")
    var characterColor: Int?

    @Guide(description: "Also recolor visible text. Defaults true.")
    var applyToVisibleText: Bool?
}

@Generable
private struct AIAssistantMemoryWriteChange {
    @Guide(description: "computer, drive8, drive9, drive10, or drive11.")
    var space: String?

    @Guide(description: "VICE bank; omit for current.")
    var bank: Int?

    @Guide(description: "Start address.")
    var address: String

    @Guide(description: "1-512 bytes, 0-255.")
    var values: [Int]
}

@Generable
private struct AIAssistantIntResourceChange {
    @Guide(description: "VICE resource name.")
    var name: String

    @Guide(description: "Signed 32-bit value.")
    var value: Int
}

@Generable
private struct AIAssistantStringResourceChange {
    @Guide(description: "VICE resource name.")
    var name: String

    @Guide(description: "String value.")
    var value: String
}

@Generable
private struct AIAssistantApplyChangesArguments {
    @Guide(description: "Short reason.")
    var reason: String?

    @Guide(description: "Display colors/style.")
    var displayStyle: AIAssistantDisplayStyleChange?

    @Guide(description: "Raw memory writes.")
    var memoryWrites: [AIAssistantMemoryWriteChange]?

    @Guide(description: "Integer resource writes.")
    var intResources: [AIAssistantIntResourceChange]?

    @Guide(description: "String resource writes.")
    var stringResources: [AIAssistantStringResourceChange]?

    @Guide(description: "Text to type.")
    var typedText: String?

    @Guide(description: "Lines to submit with Return.")
    var submittedLines: [String]?
}

private struct AIAssistantApplyChangesTool: Tool, @unchecked Sendable {
    typealias Arguments = AIAssistantApplyChangesArguments
    typealias Output = String

    let executor: AIAssistantVMToolExecutor

    var name: String { AIAssistantToolDefinition.applyChanges.name }
    var description: String { AIAssistantToolDefinition.applyChanges.description }

    @concurrent func call(arguments: AIAssistantApplyChangesArguments) async throws -> String {
        await executor.applyChangesToolResult(reason: arguments.reason,
                                              displayStyle: arguments.displayStyle,
                                              memoryWrites: arguments.memoryWrites,
                                              intResources: arguments.intResources,
                                              stringResources: arguments.stringResources,
                                              typedText: arguments.typedText,
                                              submittedLines: arguments.submittedLines)
    }
}

@Generable
private struct AIAssistantDisplayColorsArguments {
    @Guide(description: "Optional VIC-II border color number, 0 through 15. Omit to leave unchanged.")
    var borderColor: Int?

    @Guide(description: "Optional VIC-II background color number, 0 through 15. Omit to leave unchanged.")
    var backgroundColor: Int?

    @Guide(description: "Optional character/text foreground color number, 0 through 15. Omit to leave unchanged.")
    var characterColor: Int?

    @Guide(description: "When characterColor is provided, also recolor visible 40x25 text color RAM at $D800-$DBE7. Defaults to true.")
    var applyToVisibleText: Bool?
}

private struct AIAssistantDisplayColorsTool: Tool, @unchecked Sendable {
    typealias Arguments = AIAssistantDisplayColorsArguments
    typealias Output = String

    let executor: AIAssistantVMToolExecutor

    var name: String { AIAssistantToolDefinition.displayColors.name }
    var description: String { AIAssistantToolDefinition.displayColors.description }

    @concurrent func call(arguments: AIAssistantDisplayColorsArguments) async throws -> String {
        await executor.displayColorsToolResult(borderColor: arguments.borderColor,
                                               backgroundColor: arguments.backgroundColor,
                                               characterColor: arguments.characterColor,
                                               applyToVisibleText: arguments.applyToVisibleText)
    }
}

@Generable
private struct AIAssistantPeekMemoryArguments {
    @Guide(description: "computer, drive8, drive9, drive10, or drive11.")
    var space: String?

    @Guide(description: "VICE bank; omit for current.")
    var bank: Int?

    @Guide(description: "Start address.")
    var address: String

    @Guide(description: "1-512 bytes.")
    var length: Int
}

private struct AIAssistantPeekMemoryTool: Tool, @unchecked Sendable {
    typealias Arguments = AIAssistantPeekMemoryArguments
    typealias Output = String

    let executor: AIAssistantVMToolExecutor

    var name: String { AIAssistantToolDefinition.peekMemory.name }
    var description: String { AIAssistantToolDefinition.peekMemory.description }

    @concurrent func call(arguments: AIAssistantPeekMemoryArguments) async throws -> String {
        await executor.peekMemoryToolResult(space: arguments.space,
                                            bank: arguments.bank,
                                            address: arguments.address,
                                            length: arguments.length)
    }
}

@Generable
private struct AIAssistantSearchMachineDocsArguments {
    @Guide(description: "Keywords to search in indexed documentation for the current emulated machine.")
    var query: String

    @Guide(description: "Maximum number of matches, 1 through 20. Defaults to 8.")
    var limit: Int?
}

private struct AIAssistantSearchMachineDocsTool: Tool, @unchecked Sendable {
    typealias Arguments = AIAssistantSearchMachineDocsArguments
    typealias Output = String

    let executor: AIAssistantVMToolExecutor

    var name: String { AIAssistantToolDefinition.searchMachineDocs.name }
    var description: String { AIAssistantToolDefinition.searchMachineDocs.description }

    @concurrent func call(arguments: AIAssistantSearchMachineDocsArguments) async throws -> String {
        await executor.searchMachineDocsToolResult(query: arguments.query,
                                                   limit: arguments.limit)
    }
}

@Generable
private struct AIAssistantReadDocContextArguments {
    @Guide(description: "chunk_id returned by search_machine_docs.")
    var chunkID: String

    @Guide(description: "Number of previous chunks to include, 0 through 2. Defaults to 1.")
    var before: Int?

    @Guide(description: "Number of following chunks to include, 0 through 2. Defaults to 1.")
    var after: Int?
}

private struct AIAssistantReadDocContextTool: Tool, @unchecked Sendable {
    typealias Arguments = AIAssistantReadDocContextArguments
    typealias Output = String

    let executor: AIAssistantVMToolExecutor

    var name: String { AIAssistantToolDefinition.readDocContext.name }
    var description: String { AIAssistantToolDefinition.readDocContext.description }

    @concurrent func call(arguments: AIAssistantReadDocContextArguments) async throws -> String {
        await executor.readDocContextToolResult(chunkID: arguments.chunkID,
                                                before: arguments.before,
                                                after: arguments.after)
    }
}

@Generable
private struct AIAssistantPokeMemoryArguments {
    @Guide(description: "Memory space to write: computer, drive8, drive9, drive10, or drive11. Omit this for computer memory.")
    var space: String?

    @Guide(description: "VICE monitor memory bank. Omit this for the current bank.")
    var bank: Int?

    @Guide(description: "Start address, such as $0400, 0x0400, or 1024.")
    var address: String

    @Guide(description: "Byte values to write, each from 0 through 255.")
    var values: [Int]
}

private struct AIAssistantPokeMemoryTool: Tool, @unchecked Sendable {
    typealias Arguments = AIAssistantPokeMemoryArguments
    typealias Output = String

    let executor: AIAssistantVMToolExecutor

    var name: String { AIAssistantToolDefinition.pokeMemory.name }
    var description: String { AIAssistantToolDefinition.pokeMemory.description }

    @concurrent func call(arguments: AIAssistantPokeMemoryArguments) async throws -> String {
        await executor.pokeMemoryToolResult(space: arguments.space,
                                            bank: arguments.bank,
                                            address: arguments.address,
                                            values: arguments.values)
    }
}

@Generable
private struct AIAssistantTypeTextArguments {
    @Guide(description: "Text to type into the emulated keyboard without pressing Return.")
    var text: String
}

private struct AIAssistantTypeTextTool: Tool, @unchecked Sendable {
    typealias Arguments = AIAssistantTypeTextArguments
    typealias Output = String

    let executor: AIAssistantVMToolExecutor

    var name: String { AIAssistantToolDefinition.typeText.name }
    var description: String { AIAssistantToolDefinition.typeText.description }

    @concurrent func call(arguments: AIAssistantTypeTextArguments) async throws -> String {
        await executor.typeTextToolResult(text: arguments.text)
    }
}

@Generable
private struct AIAssistantSubmitLineArguments {
    @Guide(description: "Line to type into the emulated keyboard and submit with Return.")
    var line: String
}

private struct AIAssistantSubmitLineTool: Tool, @unchecked Sendable {
    typealias Arguments = AIAssistantSubmitLineArguments
    typealias Output = String

    let executor: AIAssistantVMToolExecutor

    var name: String { AIAssistantToolDefinition.submitLine.name }
    var description: String { AIAssistantToolDefinition.submitLine.description }

    @concurrent func call(arguments: AIAssistantSubmitLineArguments) async throws -> String {
        await executor.submitLineToolResult(line: arguments.line)
    }
}

@Generable
private struct AIAssistantSubmitLinesArguments {
    @Guide(description: "Lines to type into the emulated keyboard and submit with Return, in order.")
    var lines: [String]
}

private struct AIAssistantSubmitLinesTool: Tool, @unchecked Sendable {
    typealias Arguments = AIAssistantSubmitLinesArguments
    typealias Output = String

    let executor: AIAssistantVMToolExecutor

    var name: String { AIAssistantToolDefinition.submitLines.name }
    var description: String { AIAssistantToolDefinition.submitLines.description }

    @concurrent func call(arguments: AIAssistantSubmitLinesArguments) async throws -> String {
        await executor.submitLinesToolResult(lines: arguments.lines)
    }
}

private struct AIAssistantToolDefinition: Sendable {
    let name: String
    let description: String

    static let machineContext = AIAssistantToolDefinition(
        name: "get_machine_context",
        description: "Read current machine, drives, ports, and display state."
    )

    static let debuggerSnapshot = AIAssistantToolDefinition(
        name: "get_debugger_snapshot",
        description: "Read CPU/debugger state."
    )

    static let getResource = AIAssistantToolDefinition(
        name: "get_vice_resource",
        description: "Read a VICE resource."
    )

    static let setIntResource = AIAssistantToolDefinition(
        name: "set_vice_int_resource",
        description: "Set a raw VICE integer resource by name and return readback when available."
    )

    static let setStringResource = AIAssistantToolDefinition(
        name: "set_vice_string_resource",
        description: "Set a raw VICE string resource by name and return readback when available."
    )

    static let applyChanges = AIAssistantToolDefinition(
        name: "apply_emulator_changes",
        description: "Apply display, memory, resource, and keyboard changes in one batch."
    )

    static let displayColors = AIAssistantToolDefinition(
        name: "set_display_colors",
        description: "Read or batch-set C64/C128 40-column VIC-II border, background, and character/text foreground colors using Commodore color indexes."
    )

    static let peekMemory = AIAssistantToolDefinition(
        name: "peek_memory",
        description: "Read emulator memory."
    )

    static let searchMachineDocs = AIAssistantToolDefinition(
        name: "search_machine_docs",
        description: "Search user-indexed PDF documentation for the current emulated machine and return matching chunk IDs with excerpts."
    )

    static let readDocContext = AIAssistantToolDefinition(
        name: "read_doc_context",
        description: "Read bounded surrounding context from a user-indexed documentation chunk returned by search_machine_docs."
    )

    static let pokeMemory = AIAssistantToolDefinition(
        name: "poke_memory",
        description: "Write emulator memory through VICE monitor poke hooks without triggering emulated bus side effects."
    )

    static let typeText = AIAssistantToolDefinition(
        name: "type_text",
        description: "Type text into the live emulated machine without pressing Return."
    )

    static let submitLine = AIAssistantToolDefinition(
        name: "submit_line",
        description: "Type a line into the live emulated machine and press Return."
    )

    static let submitLines = AIAssistantToolDefinition(
        name: "submit_lines",
        description: "Type multiple lines into the live emulated machine, pressing Return after each line. Use this for BASIC programs."
    )
}
