import Foundation

/// Gemini (Google Generative Language API). Structured output via
/// `generationConfig.responseSchema` + `responseMimeType: application/json`.
struct GeminiClient: LLMClient {
    let apiKey: String
    let model: String

    func analyze(content: String) async throws -> AnalysisPayload {
        guard let endpoint = URL(string:
            "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        ) else { throw LLMError.badResponse }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": AnalysisPrompt.system]]],
            "contents": [["role": "user", "parts": [["text": content]]]],
            "generationConfig": [
                "responseMimeType": "application/json",
                "responseSchema": AnalysisSchema.gemini,
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try HTTP.validate(response, data: data)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let parts = (candidates.first?["content"] as? [String: Any])?["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String
        else { throw LLMError.badResponse }
        return try AnalysisPayload.decode(jsonString: text)
    }
}
