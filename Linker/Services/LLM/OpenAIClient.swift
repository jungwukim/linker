import Foundation

/// ChatGPT (OpenAI Chat Completions). Structured output via `response_format`
/// json_schema (strict). Token limit is intentionally omitted for compatibility
/// across both standard and reasoning models.
struct OpenAIClient: LLMClient {
    let apiKey: String
    let model: String

    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    func analyze(content: String) async throws -> AnalysisPayload {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": AnalysisPrompt.system],
                ["role": "user", "content": content],
            ],
            "response_format": [
                "type": "json_schema",
                "json_schema": [
                    "name": "content_analysis",
                    "strict": true,
                    "schema": AnalysisSchema.openAI,
                ],
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try HTTP.validate(response, data: data)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let text = message["content"] as? String
        else { throw LLMError.badResponse }
        return try AnalysisPayload.decode(jsonString: text)
    }
}
