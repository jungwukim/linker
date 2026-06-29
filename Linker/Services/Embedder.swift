import Foundation
import NaturalLanguage

/// On-device sentence embeddings via Apple's NaturalLanguage framework — no
/// network, no extra API key. Coverage is language-dependent (English is solid;
/// many languages, including Korean, may have no sentence model). When a vector
/// isn't available we return `[]` and search falls back to lexical matching.
enum Embedder {
    static func embed(_ text: String) -> [Double] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let language = NLLanguageRecognizer.dominantLanguage(for: trimmed) ?? .english
        guard let embedding = NLEmbedding.sentenceEmbedding(for: language) else {
            return []
        }
        return embedding.vector(for: trimmed) ?? []
    }

    static func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot = 0.0, normA = 0.0, normB = 0.0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        guard normA > 0, normB > 0 else { return 0 }
        return dot / (normA.squareRoot() * normB.squareRoot())
    }
}
