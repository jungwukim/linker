import Foundation

/// Combines captured data + fetched metadata, runs Claude analysis, and produces
/// the enriched fields (incl. a semantic embedding) for a single item.
enum AnalysisService {

    struct Result {
        var payload: AnalysisPayload
        var thumbnailURLString: String?
        var transcript: String?
        var mediaURLs: [String]
        var embedding: [Double]
    }

    static func analyze(
        sourceURLString: String?,
        rawText: String?,
        platform: Platform
    ) async throws -> Result {
        let client = try LLMClientFactory.makeCurrent()

        var metadata = LinkMetadata()
        var transcript: String?
        var mediaURLs: [String] = []
        if let urlString = sourceURLString, let url = URL(string: urlString) {
            metadata = await MetadataFetcher.fetch(url: url, platform: platform)
            if platform == .youtube, let videoID = TranscriptFetcher.videoID(from: url) {
                // On-device first: the phone's residential IP avoids YouTube's
                // datacenter bot wall, so no login cookies are needed anywhere.
                // Fall back to the (cookie-less) backend only if direct scraping
                // comes up empty.
                if let direct = await TranscriptFetcher.youTubeTranscript(url: url), !direct.isEmpty {
                    transcript = direct
                } else if let response = await YouTubeBackend.fetch(videoID: videoID) {
                    transcript = YouTubeBackend.transcriptText(response)
                }
            } else if platform == .threads {
                // Render the whole thread (connected posts + carousel/video media)
                // in an offscreen WebView; fall back to og:description otherwise.
                if let result = await ThreadsWebExtractor.extract(url: url), !result.text.isEmpty {
                    transcript = result.text
                    mediaURLs = result.mediaURLs
                }
            }
        }
        // Deep body: prefer the fetched transcript/thread, else the extracted page text.
        let deepText = transcript ?? metadata.bodyText

        let content = buildContent(
            sourceURLString: sourceURLString,
            rawText: rawText,
            platform: platform,
            metadata: metadata,
            deepText: deepText
        )

        let payload = try await client.analyze(content: content)

        let embeddingSource = [payload.title, payload.summary,
                               payload.tags.joined(separator: " "),
                               payload.topics.joined(separator: " ")]
            .joined(separator: " ")
        let embedding = Embedder.embed(embeddingSource)

        return Result(
            payload: payload,
            thumbnailURLString: metadata.thumbnailURLString ?? mediaURLs.first,
            transcript: transcript ?? metadata.bodyText,
            mediaURLs: mediaURLs,
            embedding: embedding
        )
    }

    private static func buildContent(
        sourceURLString: String?,
        rawText: String?,
        platform: Platform,
        metadata: LinkMetadata,
        deepText: String?
    ) -> String {
        var lines: [String] = []
        lines.append("출처: \(platform.displayName)")
        if let sourceURLString { lines.append("URL: \(sourceURLString)") }
        if let title = metadata.title { lines.append("페이지 제목: \(title)") }
        // Skip the og:description when it's identical to the deep body (true for
        // social posts where both come from og:description) to avoid duplication.
        if let description = metadata.description, description != deepText {
            lines.append("설명: \(description)")
        }
        if let rawText, !rawText.isEmpty {
            lines.append("공유된 텍스트:\n\(String(rawText.prefix(6000)))")
        }
        if let deepText, !deepText.isEmpty {
            let label = platform == .youtube ? "영상 자막(타임스탬프 포함)" : "본문"
            lines.append("\(label):\n\(String(deepText.prefix(20000)))")
        }
        let baselineCount = (sourceURLString == nil ? 1 : 2)
        if lines.count == baselineCount {
            lines.append("(추가 정보가 제한적입니다. URL과 출처만으로 최선을 다해 분석해 주세요.)")
        }
        return lines.joined(separator: "\n")
    }
}
