import Foundation

/// Non-secret user preferences (selected provider + selected model per provider),
/// stored in the App Group's UserDefaults.
enum AppSettings {
    private static let defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard
    private static let providerKey = "llm-provider"

    static var provider: LLMProvider {
        get { LLMProvider(rawValue: defaults.string(forKey: providerKey) ?? "") ?? .anthropic }
        set { defaults.set(newValue.rawValue, forKey: providerKey) }
    }

    /// Base URL of the deployed yt-dlp backend. Defaults to the deployed Vercel
    /// project; override in Settings if you redeploy elsewhere.
    static let defaultBackendURL = "https://backend-two-silk-65.vercel.app"
    static var backendURL: String? {
        get { defaults.string(forKey: "backend-url") ?? defaultBackendURL }
        set { defaults.set(newValue, forKey: "backend-url") }
    }

    /// Selected model for a provider, defaulting to that provider's first fallback model.
    static func model(for provider: LLMProvider) -> String {
        defaults.string(forKey: modelKey(provider)) ?? provider.fallbackModels.first ?? ""
    }

    static func setModel(_ model: String, for provider: LLMProvider) {
        defaults.set(model, forKey: modelKey(provider))
    }

    private static func modelKey(_ provider: LLMProvider) -> String {
        "model-\(provider.rawValue)"
    }
}
