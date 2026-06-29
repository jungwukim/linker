import Foundation

/// Structured result every provider must produce, regardless of API shape.
struct AnalysisPayload: Codable {
    var title: String
    var summary: String
    var tags: [String]
    var topics: [String]
    var entities: [String]
    var keyPoints: [String]
    var language: String

    enum CodingKeys: String, CodingKey {
        case title, summary, tags, topics, entities, keyPoints, language
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        summary = (try? c.decode(String.self, forKey: .summary)) ?? ""
        tags = (try? c.decode([String].self, forKey: .tags)) ?? []
        topics = (try? c.decode([String].self, forKey: .topics)) ?? []
        entities = (try? c.decode([String].self, forKey: .entities)) ?? []
        keyPoints = (try? c.decode([String].self, forKey: .keyPoints)) ?? []
        language = (try? c.decode(String.self, forKey: .language)) ?? ""
    }

    /// Providers return a JSON string (OpenAI message content, Gemini part text);
    /// decode it into a payload.
    static func decode(jsonString: String) throws -> AnalysisPayload {
        guard let data = jsonString.data(using: .utf8) else { throw LLMError.badResponse }
        return try JSONDecoder().decode(AnalysisPayload.self, from: data)
    }
}

enum LLMError: LocalizedError {
    case missingAPIKey(LLMProvider)
    case http(Int, String)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "\(provider.displayName) API 키가 없습니다. 설정에서 입력해 주세요."
        case .http(let code, let body):
            return "API 오류 (\(code)): \(body.prefix(300))"
        case .badResponse:
            return "분석 결과를 해석하지 못했습니다."
        }
    }
}

/// Common analysis instruction shared by all providers.
enum AnalysisPrompt {
    static let system = """
    너는 사용자가 저장한 콘텐츠를 분석해 나중에 검색할 수 있도록 지식으로 인덱싱하는 도우미야.
    다음을 추출해:
    - 제목
    - 2~4문장 요약 (영상·긴 글이면 5~8문장으로 충실하게)
    - 검색용 태그 3~7개
    - 주요 주제
    - 핵심 고유명사(인물·제품·장소·브랜드)
    - keyPoints: 콘텐츠의 중요한 구간·핵심 요점 5~10개. 자막에 [mm:ss] 타임스탬프가 있으면
      각 항목 앞에 가장 가까운 타임스탬프를 "[mm:ss] 내용" 형태로 붙여서 중요 구간을 표시해.
    요약·태그·keyPoints는 반드시 원문의 언어로 작성하고, 반드시 지정된 JSON 스키마 형식으로만 응답해.
    """
}

/// Anything that can turn captured content into an `AnalysisPayload`.
protocol LLMClient {
    func analyze(content: String) async throws -> AnalysisPayload
}

/// The supported AI providers. Each has its own key, endpoints, and model list.
enum LLMProvider: String, CaseIterable, Identifiable {
    case anthropic
    case openai
    case gemini

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anthropic: return "Claude (Anthropic)"
        case .openai: return "ChatGPT (OpenAI)"
        case .gemini: return "Gemini (Google)"
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .anthropic: return "sk-ant-..."
        case .openai: return "sk-..."
        case .gemini: return "AIza..."
        }
    }

    var consoleHint: String {
        switch self {
        case .anthropic: return "console.anthropic.com 에서 키 발급 + 크레딧 충전"
        case .openai: return "platform.openai.com 에서 키 발급 + 크레딧 충전"
        case .gemini: return "aistudio.google.com 에서 키 발급 (무료 등급 있음)"
        }
    }

    /// Shown before a live model fetch, or if the fetch fails. The Settings model
    /// picker replaces these with the provider's real list once a key is present.
    var fallbackModels: [String] {
        switch self {
        case .anthropic:
            return ["claude-haiku-4-5", "claude-sonnet-4-6", "claude-opus-4-8", "claude-opus-4-7", "claude-fable-5"]
        case .openai:
            return ["gpt-4o-mini", "gpt-4o", "gpt-4.1-mini", "gpt-4.1", "gpt-5-mini", "gpt-5", "o4-mini"]
        case .gemini:
            return ["gemini-2.5-flash", "gemini-2.5-pro", "gemini-2.0-flash", "gemini-1.5-flash", "gemini-1.5-pro"]
        }
    }
}
