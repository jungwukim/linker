import Foundation

/// Claude (Anthropic Messages API). Structured output is forced via tool-use.
struct AnthropicClient: LLMClient {
    let apiKey: String
    let model: String

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    func analyze(content: String) async throws -> AnalysisPayload {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": AnalysisPrompt.system,
            "tool_choice": ["type": "tool", "name": "save_analysis"],
            "tools": [[
                "name": "save_analysis",
                "description": "분석한 콘텐츠를 지식으로 인덱싱한다.",
                "input_schema": AnalysisSchema.anthropic,
            ]],
            "messages": [["role": "user", "content": content]],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try HTTP.validate(response, data: data)

        // Find the forced tool_use block and decode its `input`.
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let blocks = json["content"] as? [[String: Any]],
              let toolInput = blocks.first(where: { $0["type"] as? String == "tool_use" })?["input"],
              let inputData = try? JSONSerialization.data(withJSONObject: toolInput),
              let payload = try? JSONDecoder().decode(AnalysisPayload.self, from: inputData)
        else { throw LLMError.badResponse }
        return payload
    }
}

/// Shared HTTP status validation for all providers.
enum HTTP {
    static func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw LLMError.http(-1, "응답 없음")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw LLMError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
    }
}
