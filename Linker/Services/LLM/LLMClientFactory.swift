import Foundation

/// Builds the right provider client from the current settings (selected provider,
/// its stored key, and its selected model).
enum LLMClientFactory {
    static func makeCurrent() throws -> LLMClient {
        let provider = AppSettings.provider
        guard let key = KeychainStore.apiKey(for: provider), !key.isEmpty else {
            throw LLMError.missingAPIKey(provider)
        }
        let model = AppSettings.model(for: provider)
        switch provider {
        case .anthropic: return AnthropicClient(apiKey: key, model: model)
        case .openai: return OpenAIClient(apiKey: key, model: model)
        case .gemini: return GeminiClient(apiKey: key, model: model)
        }
    }
}
