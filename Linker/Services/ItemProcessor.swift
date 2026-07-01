import Foundation
import SwiftData

/// Drives the enrichment pipeline: finds pending items (captured by the Share
/// Extension) and runs analysis on each, updating their status as it goes.
@MainActor
final class ItemProcessor: ObservableObject {
    @Published var isWorking = false
    @Published var lastError: String?

    func processPending(_ context: ModelContext) async {
        guard !isWorking else { return }

        let descriptor = FetchDescriptor<SavedItem>(
            predicate: #Predicate { $0.statusRaw == "pending" }
        )
        guard let pending = try? context.fetch(descriptor), !pending.isEmpty else { return }

        isWorking = true
        defer { isWorking = false }

        for item in pending {
            await process(item, in: context)
        }
    }

    /// Re-run analysis for a single item (used by the "다시 분석" action).
    func reprocess(_ item: SavedItem, in context: ModelContext) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        await process(item, in: context)
    }

    /// Merge several saved items (e.g. a Threads chain split across posts) into
    /// one. Their bodies are concatenated in chain order (oldest first) and
    /// re-analyzed as a single piece; the originals are then removed. Returns the
    /// merged item, or nil if there was nothing to merge.
    @discardableResult
    func merge(_ items: [SavedItem], in context: ModelContext) async -> SavedItem? {
        guard items.count >= 2, !isWorking else { return nil }
        isWorking = true
        defer { isWorking = false }

        let ordered = items.sorted { $0.createdAt < $1.createdAt }
        let combined = ordered
            .compactMap { item -> String? in
                let body = item.transcript ?? item.rawText ?? item.summary
                return (body?.isEmpty == false) ? body : nil
            }
            .joined(separator: "\n\n———\n\n")

        let first = ordered.first!
        let merged = SavedItem(
            createdAt: first.createdAt,
            sourceURLString: first.sourceURLString,
            rawText: combined,
            platform: first.platform,
            status: .analyzing
        )
        merged.transcript = combined
        merged.thumbnailURLString = first.thumbnailURLString
        // Carry over every original's media (merge re-analyzes text only, no refetch).
        var seenMedia = Set<String>()
        merged.mediaURLs = ordered.flatMap(\.mediaURLs).filter { seenMedia.insert($0).inserted }
        context.insert(merged)
        try? context.save()

        do {
            // Analyze the combined text directly (no single-post URL re-fetch).
            let result = try await AnalysisService.analyze(
                sourceURLString: nil,
                rawText: combined,
                platform: first.platform
            )
            merged.title = result.payload.title
            merged.summary = result.payload.summary
            merged.tags = result.payload.tags
            merged.topics = result.payload.topics
            merged.entities = result.payload.entities
            merged.keyPoints = result.payload.keyPoints
            merged.embedding = result.embedding
            merged.transcript = combined   // keep the combined chain as the body
            merged.status = .done
        } catch {
            merged.status = .failed
            merged.analysisError = error.localizedDescription
            lastError = error.localizedDescription
        }

        for item in ordered { context.delete(item) }
        try? context.save()
        return merged
    }

    private func process(_ item: SavedItem, in context: ModelContext) async {
        item.status = .analyzing
        item.analysisError = nil
        try? context.save()

        do {
            let result = try await AnalysisService.analyze(
                sourceURLString: item.sourceURLString,
                rawText: item.rawText,
                platform: item.platform
            )
            item.title = result.payload.title
            item.summary = result.payload.summary
            item.tags = result.payload.tags
            item.topics = result.payload.topics
            item.entities = result.payload.entities
            item.keyPoints = result.payload.keyPoints
            item.thumbnailURLString = result.thumbnailURLString
            item.mediaURLs = result.mediaURLs
            item.transcript = result.transcript
            item.embedding = result.embedding
            item.status = .done
        } catch {
            item.status = .failed
            item.analysisError = error.localizedDescription
            lastError = error.localizedDescription
        }
        try? context.save()
    }
}
