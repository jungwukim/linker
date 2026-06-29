import Foundation

/// In-memory search over saved items. Combines two signals:
///  - lexical: how many query terms appear in the item's searchable text
///  - semantic: cosine similarity between query and item embeddings (when both exist)
///
/// Lexical guarantees exact-keyword recall; semantic surfaces conceptually
/// related items even when wording differs. Semantic gracefully degrades to
/// lexical-only for languages without an on-device embedding model.
enum SearchService {
    static func search(query: String, in items: [SavedItem]) -> [SavedItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return items.sorted { $0.createdAt > $1.createdAt }
        }

        let terms = trimmed.lowercased().split(separator: " ").map(String.init)
        let queryVector = Embedder.embed(trimmed)

        let scored: [(item: SavedItem, score: Double)] = items.compactMap { item in
            let haystack = item.searchableText
            let lexicalHits = terms.reduce(0) { $0 + (haystack.contains($1) ? 1 : 0) }

            var semantic = 0.0
            if !queryVector.isEmpty, !item.embedding.isEmpty {
                semantic = Embedder.cosineSimilarity(queryVector, item.embedding)
            }

            let matched = lexicalHits > 0 || semantic > 0.25
            guard matched else { return nil }

            let score = Double(lexicalHits) + semantic * 2.0
            return (item, score)
        }

        return scored
            .sorted { $0.score == $1.score ? $0.item.createdAt > $1.item.createdAt : $0.score > $1.score }
            .map(\.item)
    }
}
