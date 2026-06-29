import Foundation
import SwiftData

/// A single piece of content the user shared into Linker.
///
/// Created in a "pending" state by the Share Extension (which only has the raw
/// URL/text), then enriched by the main app's analysis pipeline into a
/// searchable knowledge item (title, summary, tags, topics, entities, embedding).
@Model
final class SavedItem {
    // NOTE: CloudKit mirroring requires NO unique constraints and every property
    // to have a default value (or be optional). Keep both invariants when editing.
    var id: UUID = UUID()
    var createdAt: Date = Date()

    // Captured at share time
    var sourceURLString: String?
    var rawText: String?
    var platformRaw: String = Platform.web.rawValue

    // Produced by analysis
    var title: String?
    var summary: String?
    var tags: [String] = []
    var topics: [String] = []
    var entities: [String] = []
    /// Key sections / important moments (for videos, prefixed with [mm:ss] timestamps).
    var keyPoints: [String] = []
    var thumbnailURLString: String?

    /// Deep body text used for analysis (YouTube transcript or extracted page text).
    var transcript: String?

    // Pipeline state
    var statusRaw: String = ItemStatus.pending.rawValue
    var analysisError: String?

    // Semantic-search vector (empty when on-device embedding is unavailable for the content's language)
    var embedding: [Double] = []

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        sourceURLString: String? = nil,
        rawText: String? = nil,
        platform: Platform = .web,
        status: ItemStatus = .pending
    ) {
        self.id = id
        self.createdAt = createdAt
        self.sourceURLString = sourceURLString
        self.rawText = rawText
        self.platformRaw = platform.rawValue
        self.title = nil
        self.summary = nil
        self.tags = []
        self.topics = []
        self.entities = []
        self.keyPoints = []
        self.thumbnailURLString = nil
        self.transcript = nil
        self.statusRaw = status.rawValue
        self.analysisError = nil
        self.embedding = []
    }
}

extension SavedItem {
    var platform: Platform {
        get { Platform(rawValue: platformRaw) ?? .web }
        set { platformRaw = newValue.rawValue }
    }

    var status: ItemStatus {
        get { ItemStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var sourceURL: URL? {
        guard let sourceURLString else { return nil }
        return URL(string: sourceURLString)
    }

    var displayTitle: String {
        if let title, !title.isEmpty { return title }
        if let rawText, !rawText.isEmpty { return String(rawText.prefix(80)) }
        if let host = sourceURL?.host { return host }
        return "제목 없음"
    }

    /// Lowercased haystack used for lexical (keyword) search.
    var searchableText: String {
        var parts: [String] = []
        if let title { parts.append(title) }
        if let summary { parts.append(summary) }
        parts.append(contentsOf: tags)
        parts.append(contentsOf: topics)
        parts.append(contentsOf: entities)
        parts.append(contentsOf: keyPoints)
        if let rawText { parts.append(rawText) }
        parts.append(platform.displayName)
        if let host = sourceURL?.host { parts.append(host) }
        return parts.joined(separator: " ").lowercased()
    }
}

enum ItemStatus: String, Codable {
    case pending    // captured, not yet analyzed
    case analyzing  // analysis in flight
    case done       // enriched and searchable
    case failed     // analysis failed (see analysisError)

    var label: String {
        switch self {
        case .pending: return "대기 중"
        case .analyzing: return "분석 중"
        case .done: return "완료"
        case .failed: return "실패"
        }
    }
}
