import Foundation
import Security

enum AIAssistantProvider: String, CaseIterable, Identifiable {
    case disabled
    case openAI
    case anthropic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .disabled:
            return "Disabled"
        case .openAI:
            return "OpenAI"
        case .anthropic:
            return "Anthropic"
        }
    }

    var systemImage: String {
        switch self {
        case .disabled:
            return "sparkles.slash"
        case .openAI:
            return "sparkles"
        case .anthropic:
            return "brain"
        }
    }

    var isServiceProvider: Bool {
        self != .disabled
    }

    var authenticationURL: URL? {
        switch self {
        case .disabled:
            return nil
        case .openAI:
            return URL(string: "https://platform.openai.com/api-keys")
        case .anthropic:
            return URL(string: "https://console.anthropic.com/settings/keys")
        }
    }

    var authenticationButtonTitle: String {
        switch self {
        case .disabled:
            return "Choose Provider"
        case .openAI:
            return "Open OpenAI API Keys"
        case .anthropic:
            return "Open Anthropic API Keys"
        }
    }

    var modelListURL: URL? {
        switch self {
        case .disabled:
            return nil
        case .openAI:
            return URL(string: "https://api.openai.com/v1/models")
        case .anthropic:
            return URL(string: "https://api.anthropic.com/v1/models")
        }
    }
}

struct AIAssistantModel: Codable, Equatable, Identifiable {
    let id: String
    let displayName: String

    init(id: String, displayName: String? = nil) {
        self.id = id
        self.displayName = displayName ?? id
    }

    var menuTitle: String {
        displayName == id ? id : "\(displayName) (\(id))"
    }
}

struct AIAssistantRequestConfiguration {
    let provider: AIAssistantProvider
    let model: String
    let apiKey: String
}

enum AIAssistantInteractionMode {
    case ask
    case operate

    var title: String {
        switch self {
        case .ask:
            return "Ask"
        case .operate:
            return "Do"
        }
    }
}

struct AIAssistantRunResult: Equatable {
    let text: String
    let toolUseCount: Int
}

@MainActor
final class AIAssistantSettings: ObservableObject {
    @Published var provider: AIAssistantProvider {
        didSet {
            guard provider != oldValue else {
                return
            }

            Self.defaults.set(provider.rawValue, forKey: Self.providerKey)
            loadProviderState(allowLegacyMigration: false)
        }
    }

    @Published var model: String {
        didSet {
            guard provider.isServiceProvider else {
                return
            }

            let normalizedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
            Self.defaults.set(normalizedModel, forKey: Self.modelKey(for: provider))
        }
    }

    @Published var apiKey: String {
        didSet {
            guard provider.isServiceProvider else {
                return
            }

            let normalizedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalizedAPIKey.isEmpty {
                AIAssistantKeychain.deleteAPIKey(for: provider)
            } else {
                AIAssistantKeychain.saveAPIKey(normalizedAPIKey, for: provider)
            }
        }
    }

    @Published private(set) var availableModels: [AIAssistantModel]
    @Published private(set) var isFetchingModels = false
    @Published private(set) var modelFetchMessage: String?

    var isConfigured: Bool {
        provider.isServiceProvider &&
            !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canFetchModels: Bool {
        provider.isServiceProvider &&
            !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !isFetchingModels
    }

    var providerSummary: String {
        guard provider != .disabled else {
            return "Not configured"
        }

        let normalizedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedModel.isEmpty ? "\(provider.title) / no model" : "\(provider.title) / \(normalizedModel)"
    }

    var requestConfiguration: AIAssistantRequestConfiguration? {
        let normalizedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard provider.isServiceProvider,
              !normalizedModel.isEmpty,
              !normalizedAPIKey.isEmpty else {
            return nil
        }

        return AIAssistantRequestConfiguration(provider: provider,
                                               model: normalizedModel,
                                               apiKey: normalizedAPIKey)
    }

    init() {
        let rawProvider = Self.defaults.string(forKey: Self.providerKey) ?? AIAssistantProvider.disabled.rawValue
        let initialProvider = AIAssistantProvider(rawValue: rawProvider) ?? .disabled
        provider = initialProvider
        model = Self.loadModel(for: initialProvider, allowLegacyMigration: true)
        apiKey = AIAssistantKeychain.loadAPIKey(for: initialProvider, allowLegacyMigration: true) ?? ""
        availableModels = Self.loadCachedModels(for: initialProvider)
    }

    func fetchAvailableModels() async {
        guard canFetchModels else {
            modelFetchMessage = "Choose a provider and enter an API key first."
            return
        }

        let provider = provider
        let apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        isFetchingModels = true
        modelFetchMessage = nil

        do {
            let models = try await AIAssistantModelService.fetchModels(for: provider, apiKey: apiKey)
            availableModels = models
            cacheModels(models, for: provider)

            let noun = models.count == 1 ? "model" : "models"
            modelFetchMessage = "Fetched \(models.count) \(noun)."
        } catch {
            modelFetchMessage = error.localizedDescription
        }

        isFetchingModels = false
    }

    private func loadProviderState(allowLegacyMigration: Bool) {
        model = Self.loadModel(for: provider, allowLegacyMigration: allowLegacyMigration)
        apiKey = AIAssistantKeychain.loadAPIKey(for: provider, allowLegacyMigration: allowLegacyMigration) ?? ""
        availableModels = Self.loadCachedModels(for: provider)
        modelFetchMessage = nil
    }

    private func cacheModels(_ models: [AIAssistantModel], for provider: AIAssistantProvider) {
        guard provider.isServiceProvider,
              let data = try? JSONEncoder().encode(models) else {
            return
        }

        Self.defaults.set(data, forKey: Self.modelsKey(for: provider))
    }

    private static func loadModel(for provider: AIAssistantProvider, allowLegacyMigration: Bool) -> String {
        guard provider.isServiceProvider else {
            return ""
        }

        if let model = defaults.string(forKey: modelKey(for: provider)) {
            return model
        }

        guard allowLegacyMigration else {
            return ""
        }

        return defaults.string(forKey: legacyModelKey) ?? ""
    }

    private static func loadCachedModels(for provider: AIAssistantProvider) -> [AIAssistantModel] {
        guard provider.isServiceProvider,
              let data = defaults.data(forKey: modelsKey(for: provider)),
              let models = try? JSONDecoder().decode([AIAssistantModel].self, from: data) else {
            return []
        }

        return models
    }

    private static func modelKey(for provider: AIAssistantProvider) -> String {
        "vice.ai.\(provider.rawValue).model"
    }

    private static func modelsKey(for provider: AIAssistantProvider) -> String {
        "vice.ai.\(provider.rawValue).models"
    }

    private static let providerKey = "vice.ai.provider"
    private static let legacyModelKey = "vice.ai.model"
    private static let defaults = UserDefaults(suiteName: "com.barrywalker.vicemac") ?? .standard
}

enum AIAssistantModelService {
    static func fetchModels(for provider: AIAssistantProvider, apiKey: String) async throws -> [AIAssistantModel] {
        guard provider.isServiceProvider,
              let url = provider.modelListURL else {
            throw AIAssistantModelServiceError.unsupportedProvider
        }

        let normalizedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedAPIKey.isEmpty else {
            throw AIAssistantModelServiceError.missingAPIKey
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        switch provider {
        case .disabled:
            throw AIAssistantModelServiceError.unsupportedProvider
        case .openAI:
            request.setValue("Bearer \(normalizedAPIKey)", forHTTPHeaderField: "Authorization")
        case .anthropic:
            request.setValue(normalizedAPIKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIAssistantModelServiceError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AIAssistantModelServiceError.httpStatus(httpResponse.statusCode,
                                                          providerErrorMessage(from: data))
        }

        let models: [AIAssistantModel]
        switch provider {
        case .disabled:
            throw AIAssistantModelServiceError.unsupportedProvider
        case .openAI:
            models = try decodeOpenAIModels(from: data)
        case .anthropic:
            models = try decodeAnthropicModels(from: data)
        }

        guard !models.isEmpty else {
            throw AIAssistantModelServiceError.noModels
        }

        return models.sorted { lhs, rhs in
            lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending
        }
    }

    static func decodeOpenAIModels(from data: Data) throws -> [AIAssistantModel] {
        let response = try JSONDecoder().decode(OpenAIModelsResponse.self, from: data)
        return response.data.map { AIAssistantModel(id: $0.id) }
    }

    static func decodeAnthropicModels(from data: Data) throws -> [AIAssistantModel] {
        let response = try JSONDecoder().decode(AnthropicModelsResponse.self, from: data)
        return response.data.map { model in
            AIAssistantModel(id: model.id, displayName: model.displayName)
        }
    }

    static func providerErrorMessage(from data: Data) -> String? {
        guard let response = try? JSONDecoder().decode(ProviderErrorResponse.self, from: data) else {
            return nil
        }

        return response.error.message
    }
}

enum AIAssistantModelServiceError: LocalizedError {
    case unsupportedProvider
    case missingAPIKey
    case invalidResponse
    case httpStatus(Int, String?)
    case noModels

    var errorDescription: String? {
        switch self {
        case .unsupportedProvider:
            return "This provider does not expose a model list."
        case .missingAPIKey:
            return "Enter an API key before fetching models."
        case .invalidResponse:
            return "The provider returned an invalid response."
        case .httpStatus(let statusCode, let message):
            if let message, !message.isEmpty {
                return "Model fetch failed (\(statusCode)): \(message)"
            }

            return "Model fetch failed with HTTP \(statusCode)."
        case .noModels:
            return "The provider did not return any models."
        }
    }
}

@MainActor
enum AIAssistantConversationService {
    private static let maximumToolRounds = 6

    static func run(prompt: String,
                    mode: AIAssistantInteractionMode,
                    settings: AIAssistantSettings,
                    emulator: EmulatorSession) async throws -> AIAssistantRunResult {
        let normalizedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPrompt.isEmpty else {
            throw AIAssistantConversationError.emptyPrompt
        }

        guard let configuration = settings.requestConfiguration else {
            throw AIAssistantConversationError.notConfigured
        }

        let tools = AIAssistantVMToolExecutor(emulator: emulator, mode: mode)
        switch configuration.provider {
        case .disabled:
            throw AIAssistantConversationError.notConfigured
        case .openAI:
            return try await runOpenAI(prompt: normalizedPrompt,
                                       configuration: configuration,
                                       tools: tools)
        case .anthropic:
            return try await runAnthropic(prompt: normalizedPrompt,
                                          configuration: configuration,
                                          tools: tools)
        }
    }

    nonisolated static func decodeOpenAIResponse(from data: Data) throws -> AIAssistantOpenAIResponse {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIAssistantConversationError.invalidProviderResponse
        }

        let decoded = try JSONDecoder().decode(OpenAIResponsesAPIResponse.self, from: data)
        let rawOutput = root["output"] as? [[String: Any]] ?? []
        let textParts = (decoded.output ?? []).flatMap { output -> [String] in
            guard output.type == "message" else {
                return []
            }

            return (output.content ?? []).compactMap { content in
                guard content.type == "output_text" || content.type == "text" else {
                    return nil
                }

                return content.text
            }
        }

        let outputText = decoded.outputText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let messageText = textParts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        let toolCalls = (decoded.output ?? []).compactMap { output -> AIAssistantToolCall? in
            guard output.type == "function_call",
                  let callID = output.callID,
                  let name = output.name else {
                return nil
            }

            return AIAssistantToolCall(id: callID,
                                       name: name,
                                       argumentsData: Data((output.arguments ?? "{}").utf8))
        }

        return AIAssistantOpenAIResponse(id: decoded.id,
                                         rawOutput: rawOutput,
                                         text: outputText?.isEmpty == false ? outputText! : messageText,
                                         toolCalls: toolCalls)
    }

    nonisolated static func decodeAnthropicResponse(from data: Data) throws -> AIAssistantAnthropicResponse {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawContent = root["content"] as? [[String: Any]] else {
            throw AIAssistantConversationError.invalidProviderResponse
        }

        var textParts: [String] = []
        var toolCalls: [AIAssistantToolCall] = []

        for block in rawContent {
            guard let type = block["type"] as? String else {
                continue
            }

            if type == "text",
               let text = block["text"] as? String {
                textParts.append(text)
                continue
            }

            if type == "tool_use",
               let id = block["id"] as? String,
               let name = block["name"] as? String {
                let input = block["input"] as? [String: Any] ?? [:]
                let inputData = try JSONSerialization.data(withJSONObject: input)
                toolCalls.append(AIAssistantToolCall(id: id,
                                                     name: name,
                                                     argumentsData: inputData))
            }
        }

        return AIAssistantAnthropicResponse(rawContent: rawContent,
                                            text: textParts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines),
                                            toolCalls: toolCalls)
    }

    private static func runOpenAI(prompt: String,
                                  configuration: AIAssistantRequestConfiguration,
                                  tools: AIAssistantVMToolExecutor) async throws -> AIAssistantRunResult {
        var inputItems: [[String: Any]] = [
            [
                "role": "user",
                "content": prompt
            ]
        ]
        var response = try await sendOpenAIRequest(configuration: configuration,
                                                   body: [
                                                       "model": configuration.model,
                                                       "instructions": tools.systemPrompt,
                                                       "input": inputItems,
                                                       "tools": tools.openAIToolDefinitions,
                                                       "tool_choice": tools.initialOpenAIToolChoice
                                                   ])
        var toolUseCount = 0

        for _ in 0..<maximumToolRounds {
            guard !response.toolCalls.isEmpty else {
                return AIAssistantRunResult(text: response.textOrFallback,
                                            toolUseCount: toolUseCount)
            }

            inputItems.append(contentsOf: response.rawOutput)
            for toolCall in response.toolCalls {
                let result = await tools.execute(name: toolCall.name,
                                                 argumentsData: toolCall.argumentsData)
                toolUseCount += 1
                inputItems.append([
                    "type": "function_call_output",
                    "call_id": toolCall.id,
                    "output": result
                ])
            }

            response = try await sendOpenAIRequest(configuration: configuration,
                                                   body: [
                                                       "model": configuration.model,
                                                       "instructions": tools.systemPrompt,
                                                       "input": inputItems,
                                                       "tools": tools.openAIToolDefinitions,
                                                       "tool_choice": "auto"
                                                   ])
        }

        throw AIAssistantConversationError.maximumToolRoundsExceeded
    }

    private static func runAnthropic(prompt: String,
                                     configuration: AIAssistantRequestConfiguration,
                                     tools: AIAssistantVMToolExecutor) async throws -> AIAssistantRunResult {
        var messages: [[String: Any]] = [
            [
                "role": "user",
                "content": prompt
            ]
        ]
        var toolUseCount = 0

        for _ in 0..<maximumToolRounds {
            let toolChoice: [String: Any] = messages.count == 1 ? tools.initialAnthropicToolChoice : ["type": "auto"]
            let body: [String: Any] = [
                "model": configuration.model,
                "max_tokens": 1600,
                "system": tools.systemPrompt,
                "messages": messages,
                "tools": tools.anthropicToolDefinitions,
                "tool_choice": toolChoice
            ]
            let response = try await sendAnthropicRequest(configuration: configuration,
                                                         body: body)

            guard !response.toolCalls.isEmpty else {
                return AIAssistantRunResult(text: response.textOrFallback,
                                            toolUseCount: toolUseCount)
            }

            messages.append([
                "role": "assistant",
                "content": response.rawContent
            ])

            var toolResults: [[String: Any]] = []
            for toolCall in response.toolCalls {
                let result = await tools.execute(name: toolCall.name,
                                                 argumentsData: toolCall.argumentsData)
                toolUseCount += 1
                toolResults.append([
                    "type": "tool_result",
                    "tool_use_id": toolCall.id,
                    "content": result
                ])
            }

            messages.append([
                "role": "user",
                "content": toolResults
            ])
        }

        throw AIAssistantConversationError.maximumToolRoundsExceeded
    }

    private static func sendOpenAIRequest(configuration: AIAssistantRequestConfiguration,
                                          body: [String: Any]) async throws -> AIAssistantOpenAIResponse {
        guard let url = URL(string: "https://api.openai.com/v1/responses") else {
            throw AIAssistantConversationError.invalidProviderResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data = try await send(request: request)
        return try decodeOpenAIResponse(from: data)
    }

    private static func sendAnthropicRequest(configuration: AIAssistantRequestConfiguration,
                                             body: [String: Any]) async throws -> AIAssistantAnthropicResponse {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw AIAssistantConversationError.invalidProviderResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(configuration.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data = try await send(request: request)
        return try decodeAnthropicResponse(from: data)
    }

    private static func send(request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIAssistantConversationError.invalidProviderResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AIAssistantConversationError.providerError(httpResponse.statusCode,
                                                             AIAssistantModelService.providerErrorMessage(from: data))
        }

        return data
    }
}

enum AIAssistantConversationError: LocalizedError {
    case emptyPrompt
    case notConfigured
    case invalidProviderResponse
    case providerError(Int, String?)
    case maximumToolRoundsExceeded

    var errorDescription: String? {
        switch self {
        case .emptyPrompt:
            return "Enter a prompt first."
        case .notConfigured:
            return "Choose a provider, API key, and model in Settings."
        case .invalidProviderResponse:
            return "The provider returned a response the app could not read."
        case .providerError(let statusCode, let message):
            if let message, !message.isEmpty {
                return "Assistant request failed (\(statusCode)): \(message)"
            }

            return "Assistant request failed with HTTP \(statusCode)."
        case .maximumToolRoundsExceeded:
            return "The assistant used too many tool rounds."
        }
    }
}

struct AIAssistantToolCall: Equatable {
    let id: String
    let name: String
    let argumentsData: Data
}

struct AIAssistantOpenAIResponse {
    let id: String?
    let rawOutput: [[String: Any]]
    let text: String
    let toolCalls: [AIAssistantToolCall]

    var textOrFallback: String {
        text.isEmpty ? "Done." : text
    }
}

struct AIAssistantAnthropicResponse {
    let rawContent: [[String: Any]]
    let text: String
    let toolCalls: [AIAssistantToolCall]

    var textOrFallback: String {
        text.isEmpty ? "Done." : text
    }
}

@MainActor
private final class AIAssistantVMToolExecutor {
    private let emulator: EmulatorSession
    private let mode: AIAssistantInteractionMode

    init(emulator: EmulatorSession, mode: AIAssistantInteractionMode) {
        self.emulator = emulator
        self.mode = mode
    }

    var systemPrompt: String {
        let writePolicy: String
        switch mode {
        case .ask:
            writePolicy = "You are in Ask mode. Answer questions and inspect memory if useful. Do not change emulator state."
        case .operate:
            writePolicy = "You are in Do mode. You must use at least one VM tool before claiming you operated the machine. For BASIC programs, use submit_lines with numbered uppercase ASCII program lines in order, then optionally submit RUN if the user asked you to run it. Prefer typing BASIC/program lines over poking memory unless direct memory work is clearly appropriate."
        }

        return """
        You are the built-in VICE Mac assistant for a live Commodore emulator.
        \(writePolicy)
        Current machine context:
        \(Self.jsonString(machineContext()))
        Keep responses concise. When you operate the machine, summarize exactly what you changed or typed.
        """
    }

    var openAIToolDefinitions: [[String: Any]] {
        toolDefinitions.map { tool in
            [
                "type": "function",
                "name": tool.name,
                "description": tool.description,
                "parameters": tool.inputSchema
            ]
        }
    }

    var anthropicToolDefinitions: [[String: Any]] {
        toolDefinitions.map { tool in
            [
                "name": tool.name,
                "description": tool.description,
                "input_schema": tool.inputSchema
            ]
        }
    }

    var initialOpenAIToolChoice: Any {
        mode == .operate ? "required" : "auto"
    }

    var initialAnthropicToolChoice: [String: Any] {
        mode == .operate ? ["type": "any"] : ["type": "auto"]
    }

    func execute(name: String, argumentsData: Data) async -> String {
        let arguments: [String: Any]
        do {
            arguments = try Self.arguments(from: argumentsData)
        } catch {
            return Self.jsonString([
                "ok": false,
                "error": "Invalid tool arguments."
            ])
        }

        switch name {
        case "get_machine_context":
            return Self.jsonString([
                "ok": true,
                "context": machineContext()
            ])
        case "peek_memory":
            return peekMemory(arguments)
        case "poke_memory":
            guard mode == .operate else {
                return Self.jsonString([
                    "ok": false,
                    "error": "poke_memory is unavailable in Ask mode."
                ])
            }

            return pokeMemory(arguments)
        case "type_text":
            guard mode == .operate else {
                return Self.jsonString([
                    "ok": false,
                    "error": "type_text is unavailable in Ask mode."
                ])
            }

            return typeText(arguments)
        case "submit_line":
            guard mode == .operate else {
                return Self.jsonString([
                    "ok": false,
                    "error": "submit_line is unavailable in Ask mode."
                ])
            }

            return submitLine(arguments)
        case "submit_lines":
            guard mode == .operate else {
                return Self.jsonString([
                    "ok": false,
                    "error": "submit_lines is unavailable in Ask mode."
                ])
            }

            return submitLines(arguments)
        default:
            return Self.jsonString([
                "ok": false,
                "error": "Unknown tool: \(name)"
            ])
        }
    }

    private var toolDefinitions: [AIAssistantToolDefinition] {
        var tools: [AIAssistantToolDefinition] = [
            .machineContext,
            .peekMemory
        ]

        if mode == .operate {
            tools += [
                .typeText,
                .submitLine,
                .submitLines,
                .pokeMemory
            ]
        }

        return tools
    }

    private func machineContext() -> [String: Any] {
        [
            "machine": [
                "id": emulator.machine.id.rawValue,
                "name": emulator.machine.displayName,
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

    private static func arguments(from data: Data) throws -> [String: Any] {
        if data.isEmpty {
            return [:]
        }

        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    private static func normalizedBASICInput(_ text: String) -> String {
        text.uppercased()
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

    private static func addressString(_ address: UInt16) -> String {
        String(format: "$%04X", address)
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
}

private struct AIAssistantToolDefinition {
    let name: String
    let description: String
    let inputSchema: [String: Any]

    static let machineContext = AIAssistantToolDefinition(
        name: "get_machine_context",
        description: "Return the current emulated machine, video, RAM, drive, and control-port configuration.",
        inputSchema: objectSchema(properties: [:], required: [])
    )

    static let peekMemory = AIAssistantToolDefinition(
        name: "peek_memory",
        description: "Read emulator memory through VICE monitor peek hooks without triggering emulated bus side effects.",
        inputSchema: objectSchema(properties: [
            "space": [
                "type": "string",
                "enum": ["computer", "drive8", "drive9", "drive10", "drive11"],
                "description": "Memory space to read. Defaults to computer."
            ],
            "bank": [
                "type": "integer",
                "description": "VICE monitor memory bank. Use -1 for current bank."
            ],
            "address": [
                "type": "string",
                "description": "Start address, such as $0400, 0x0400, or 1024."
            ],
            "length": [
                "type": "integer",
                "minimum": 1,
                "maximum": 512,
                "description": "Number of bytes to read."
            ]
        ], required: ["address", "length"])
    )

    static let pokeMemory = AIAssistantToolDefinition(
        name: "poke_memory",
        description: "Write emulator memory through VICE monitor poke hooks without triggering emulated bus side effects.",
        inputSchema: objectSchema(properties: [
            "space": [
                "type": "string",
                "enum": ["computer", "drive8", "drive9", "drive10", "drive11"],
                "description": "Memory space to write. Defaults to computer."
            ],
            "bank": [
                "type": "integer",
                "description": "VICE monitor memory bank. Use -1 for current bank."
            ],
            "address": [
                "type": "string",
                "description": "Start address, such as $0400, 0x0400, or 1024."
            ],
            "values": [
                "type": "array",
                "minItems": 1,
                "maxItems": 512,
                "items": [
                    "type": "integer",
                    "minimum": 0,
                    "maximum": 255
                ],
                "description": "Byte values to write."
            ]
        ], required: ["address", "values"])
    )

    static let typeText = AIAssistantToolDefinition(
        name: "type_text",
        description: "Type text into the live emulated machine without pressing Return.",
        inputSchema: objectSchema(properties: [
            "text": [
                "type": "string",
                "description": "Text to type into the emulated keyboard."
            ]
        ], required: ["text"])
    )

    static let submitLine = AIAssistantToolDefinition(
        name: "submit_line",
        description: "Type a line into the live emulated machine and press Return.",
        inputSchema: objectSchema(properties: [
            "line": [
                "type": "string",
                "description": "Line to type and submit."
            ]
        ], required: ["line"])
    )

    static let submitLines = AIAssistantToolDefinition(
        name: "submit_lines",
        description: "Type multiple lines into the live emulated machine, pressing Return after each line. Use this for BASIC programs.",
        inputSchema: objectSchema(properties: [
            "lines": [
                "type": "array",
                "minItems": 1,
                "maxItems": 200,
                "items": [
                    "type": "string"
                ],
                "description": "Lines to type and submit in order."
            ]
        ], required: ["lines"])
    )

    private static func objectSchema(properties: [String: Any],
                                     required: [String]) -> [String: Any] {
        [
            "type": "object",
            "properties": properties,
            "required": required,
            "additionalProperties": false
        ]
    }
}

private struct OpenAIModelsResponse: Decodable {
    struct Model: Decodable {
        let id: String
    }

    let data: [Model]
}

private struct AnthropicModelsResponse: Decodable {
    struct Model: Decodable {
        let id: String
        let displayName: String?

        enum CodingKeys: String, CodingKey {
            case id
            case displayName = "display_name"
        }
    }

    let data: [Model]
}

private struct ProviderErrorResponse: Decodable {
    struct ProviderError: Decodable {
        let message: String?
    }

    let error: ProviderError
}

private struct OpenAIResponsesAPIResponse: Decodable {
    let id: String?
    let output: [OpenAIResponseOutput]?
    let outputText: String?

    enum CodingKeys: String, CodingKey {
        case id
        case output
        case outputText = "output_text"
    }
}

private struct OpenAIResponseOutput: Decodable {
    let type: String
    let content: [OpenAIResponseContent]?
    let callID: String?
    let name: String?
    let arguments: String?

    enum CodingKeys: String, CodingKey {
        case type
        case content
        case callID = "call_id"
        case name
        case arguments
    }
}

private struct OpenAIResponseContent: Decodable {
    let type: String
    let text: String?
}

private enum AIAssistantKeychain {
    private static let service = "com.barrywalker.vicemac.ai"
    private static let legacyAccount = "api-key"

    static func loadAPIKey(for provider: AIAssistantProvider, allowLegacyMigration: Bool) -> String? {
        guard provider.isServiceProvider else {
            return nil
        }

        if let apiKey = loadAPIKey(account: account(for: provider)) {
            return apiKey
        }

        guard allowLegacyMigration else {
            return nil
        }

        return loadAPIKey(account: legacyAccount)
    }

    static func saveAPIKey(_ apiKey: String, for provider: AIAssistantProvider) {
        guard provider.isServiceProvider,
              let data = apiKey.data(using: .utf8) else {
            return
        }

        let account = account(for: provider)
        let attributes = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery(account: account) as CFDictionary, attributes as CFDictionary)
        if status != errSecSuccess {
            var query = baseQuery(account: account)
            query[kSecValueData as String] = data
            SecItemAdd(query as CFDictionary, nil)
        }

        SecItemDelete(baseQuery(account: legacyAccount) as CFDictionary)
    }

    static func deleteAPIKey(for provider: AIAssistantProvider) {
        guard provider.isServiceProvider else {
            return
        }

        SecItemDelete(baseQuery(account: account(for: provider)) as CFDictionary)
    }

    private static func loadAPIKey(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let apiKey = String(data: data, encoding: .utf8),
              !apiKey.isEmpty else {
            return nil
        }

        return apiKey
    }

    private static func account(for provider: AIAssistantProvider) -> String {
        "api-key.\(provider.rawValue)"
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
