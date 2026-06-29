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
