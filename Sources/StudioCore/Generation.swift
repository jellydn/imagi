import Foundation

public struct ProviderAuthentication: Equatable, Sendable {
    public let subscriptionTitle: String
    public let subscriptionStatus: String
    public let subscriptionDescription: String
    public let subscriptionHelpURL: URL
    public let apiKeyURL: URL
    public let apiUsageTitle: String
    public let apiUsageURL: URL
}

public enum ProviderID: String, CaseIterable, Codable, Sendable, Identifiable {
    case openAI, xAI
    public var id: String { rawValue }
    public var title: String { self == .openAI ? "OpenAI" : "Grok · xAI" }
    public var model: String { self == .openAI ? "gpt-image-1" : "grok-imagine-image-2.0" }
    public var authentication: ProviderAuthentication {
        switch self {
        case .openAI:
            return ProviderAuthentication(
                subscriptionTitle: "ChatGPT subscriptions",
                subscriptionStatus: "Not supported",
                subscriptionDescription: "ChatGPT Plus and Pro do not include OpenAI API usage. OpenAI API billing is separate, and there is no supported ChatGPT sign-in for this app.",
                subscriptionHelpURL: URL(string: "https://help.openai.com/en/articles/9039756")!,
                apiKeyURL: URL(string: "https://platform.openai.com/api-keys")!,
                apiUsageTitle: "Set up API billing ↗",
                apiUsageURL: URL(string: "https://platform.openai.com/settings/organization/billing/overview")!
            )
        case .xAI:
            return ProviderAuthentication(
                subscriptionTitle: "Grok subscriptions",
                subscriptionStatus: "No public sign-in",
                subscriptionDescription: "Paid Grok plans can include a shared usage pool with an API category. xAI does not document a general OAuth registration flow for this app, so use its public API-key flow. Allowance depends on your account and plan.",
                subscriptionHelpURL: URL(string: "https://docs.x.ai/grok/faq")!,
                apiKeyURL: URL(string: "https://console.x.ai/team/default/api-keys")!,
                apiUsageTitle: "Manage API usage ↗",
                apiUsageURL: URL(string: "https://console.x.ai/team/default/billing")!
            )
        }
    }
}

public enum AspectRatio: String, CaseIterable, Codable, Sendable, Identifiable {
    case square = "1:1", landscape = "4:3", portrait = "3:4"
    case widescreen = "16:9", story = "9:16"
    public var id: String { rawValue }
    public var value: Double {
        switch self {
        case .square: return 1
        case .landscape: return 4.0 / 3
        case .portrait: return 3.0 / 4
        case .widescreen: return 16.0 / 9
        case .story: return 9.0 / 16
        }
    }
    public var openAISize: String {
        if self == .square { return "1024x1024" }
        return value > 1 ? "1536x1024" : "1024x1536"
    }
}

public struct GenerationOptions: Codable, Sendable, Equatable {
    public let provider: ProviderID
    public let count: Int
    public let ratio: AspectRatio
    public init(provider: ProviderID, count: Int, ratio: AspectRatio) {
        self.provider = provider
        self.count = count
        self.ratio = ratio
    }
}

public struct ImageRequest: Sendable {
    public let prompt: String
    public let options: GenerationOptions
    /// References are normalized to PNG by the local image store.
    public let referencePNG: Data?
    public init(prompt: String, options: GenerationOptions, referencePNG: Data? = nil) {
        self.prompt = prompt
        self.options = options
        self.referencePNG = referencePNG
    }
    public func validate() throws {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw StudioError.invalidRequest("Describe the image first.")
        }
        guard (1...4).contains(options.count) else {
            throw StudioError.invalidRequest("Choose 1–4 variants.")
        }
        if let referencePNG, referencePNG.isEmpty {
            throw StudioError.invalidRequest("The reference image is empty.")
        }
    }
}

public enum StudioError: LocalizedError {
    case invalidRequest(String), missingCredential, http(Int), invalidResponse
    public var errorDescription: String? {
        switch self {
        case .invalidRequest(let message): return message
        case .missingCredential: return "Add an API key for this provider in Settings. Subscription sign-in is not available."
        case .http(401): return "The API key was rejected. Check it in Settings."
        case .http(403): return "This account cannot use the image model. Check provider access and organization verification."
        case .http(429): return "The provider limit was reached. Check API credit and rate limits before you try again."
        case .http(let code): return "The provider could not complete the request (HTTP \(code)). Check the prompt and provider status."
        case .invalidResponse: return "The provider did not return valid images. No new images were saved."
        }
    }
}

public protocol ImageGenerationProvider: Sendable {
    func generate(_ request: ImageRequest, apiKey: String) async throws -> [Data]
}

public struct ImageGenerationService: Sendable {
    private let openAI: any ImageGenerationProvider
    private let xAI: any ImageGenerationProvider
    public init(openAI: any ImageGenerationProvider = OpenAIProvider(), xAI: any ImageGenerationProvider = XAIProvider()) {
        self.openAI = openAI
        self.xAI = xAI
    }
    public func generate(_ request: ImageRequest, apiKey: String) async throws -> [Data] {
        try request.validate()
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw StudioError.missingCredential
        }
        let provider = request.options.provider == .openAI ? openAI : xAI
        return try await provider.generate(request, apiKey: apiKey)
    }
}
