import Foundation

/// Fetches the list of usable models for a provider from its own models endpoint,
/// so the picker reflects exactly what the user's account can run. Falls back to
/// the provider's curated list when no key is set or the request fails.
enum ModelCatalog {
    static func models(for provider: LLMProvider, apiKey: String?) async -> [String] {
        guard let apiKey, !apiKey.isEmpty else { return provider.fallbackModels }
        let fetched: [String]?
        switch provider {
        case .anthropic: fetched = await anthropic(apiKey: apiKey)
        case .openai: fetched = await openAI(apiKey: apiKey)
        case .gemini: fetched = await gemini(apiKey: apiKey)
        }
        guard let fetched, !fetched.isEmpty else { return provider.fallbackModels }
        return fetched
    }

    private static func anthropic(apiKey: String) async -> [String]? {
        guard let url = URL(string: "https://api.anthropic.com/v1/models?limit=100") else { return nil }
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        guard let data = try? await fetch(request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = json["data"] as? [[String: Any]] else { return nil }
        return list.compactMap { $0["id"] as? String }
            .filter { $0.hasPrefix("claude") }
    }

    private static func openAI(apiKey: String) async -> [String]? {
        guard let url = URL(string: "https://api.openai.com/v1/models") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        guard let data = try? await fetch(request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = json["data"] as? [[String: Any]] else { return nil }
        let exclude = ["embedding", "whisper", "tts", "audio", "image", "dall-e", "moderation", "realtime", "transcribe", "search"]
        return list.compactMap { $0["id"] as? String }
            .filter { id in
                (id.hasPrefix("gpt") || id.hasPrefix("o1") || id.hasPrefix("o3") || id.hasPrefix("o4"))
                    && !exclude.contains { id.contains($0) }
            }
            .sorted()
    }

    private static func gemini(apiKey: String) async -> [String]? {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(apiKey)&pageSize=200") else { return nil }
        guard let data = try? await fetch(URLRequest(url: url)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = json["models"] as? [[String: Any]] else { return nil }
        return list
            .filter { ($0["supportedGenerationMethods"] as? [String])?.contains("generateContent") == true }
            .compactMap { ($0["name"] as? String)?.replacingOccurrences(of: "models/", with: "") }
            .filter { $0.hasPrefix("gemini") }
            .sorted()
    }

    private static func fetch(_ request: URLRequest) async throws -> Data {
        var request = request
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw LLMError.badResponse
        }
        return data
    }
}
