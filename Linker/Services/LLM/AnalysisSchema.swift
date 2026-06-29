import Foundation

/// JSON schema for `AnalysisPayload` in each provider's required dialect.
enum AnalysisSchema {
    private static let fields = ["title", "summary", "tags", "topics", "entities", "keyPoints", "language"]

    /// OpenAI structured outputs (strict) — lowercase types, additionalProperties: false.
    static var openAI: [String: Any] {
        [
            "type": "object",
            "properties": [
                "title": ["type": "string"],
                "summary": ["type": "string"],
                "tags": ["type": "array", "items": ["type": "string"]],
                "topics": ["type": "array", "items": ["type": "string"]],
                "entities": ["type": "array", "items": ["type": "string"]],
                "keyPoints": ["type": "array", "items": ["type": "string"]],
                "language": ["type": "string"],
            ],
            "required": fields,
            "additionalProperties": false,
        ]
    }

    /// Gemini responseSchema — UPPERCASE enum types, no additionalProperties.
    static var gemini: [String: Any] {
        [
            "type": "OBJECT",
            "properties": [
                "title": ["type": "STRING"],
                "summary": ["type": "STRING"],
                "tags": ["type": "ARRAY", "items": ["type": "STRING"]],
                "topics": ["type": "ARRAY", "items": ["type": "STRING"]],
                "entities": ["type": "ARRAY", "items": ["type": "STRING"]],
                "keyPoints": ["type": "ARRAY", "items": ["type": "STRING"]],
                "language": ["type": "STRING"],
            ],
            "required": fields,
            "propertyOrdering": fields,
        ]
    }

    /// Anthropic tool input_schema (lowercase, with field descriptions).
    static var anthropic: [String: Any] {
        [
            "type": "object",
            "properties": [
                "title": ["type": "string", "description": "콘텐츠를 가장 잘 나타내는 짧은 제목"],
                "summary": ["type": "string", "description": "핵심을 담은 요약. 영상·긴 글이면 5~8문장. 원문의 언어로."],
                "tags": ["type": "array", "items": ["type": "string"], "description": "검색용 짧은 태그 3~7개"],
                "topics": ["type": "array", "items": ["type": "string"], "description": "주요 주제·카테고리"],
                "entities": ["type": "array", "items": ["type": "string"], "description": "인물·제품·장소·브랜드 등 고유명사"],
                "keyPoints": ["type": "array", "items": ["type": "string"], "description": "중요 구간·핵심 요점 5~10개. 자막에 타임스탬프가 있으면 [mm:ss]를 앞에 붙임"],
                "language": ["type": "string", "description": "원문의 주 언어 (예: ko, en)"],
            ],
            "required": fields,
        ]
    }
}
