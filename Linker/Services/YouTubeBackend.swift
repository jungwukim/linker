import Foundation
import CoreGraphics

/// Calls the Linker yt-dlp backend for reliable YouTube transcript + frames.
/// When no backend URL is configured, callers fall back to best-effort direct
/// scraping (`TranscriptFetcher` / `StoryboardFetcher`).
enum YouTubeBackend {
    static var isConfigured: Bool { baseURL != nil }

    private static var baseURL: URL? {
        guard let string = AppSettings.backendURL?.trimmingCharacters(in: .whitespaces),
              !string.isEmpty else { return nil }
        return URL(string: string)
    }

    struct Response: Decodable {
        let title: String?
        let duration: Double?
        let thumbnail: String?
        let transcript: [Cue]
        let frames: [Frame]
    }
    struct Cue: Decodable { let t: Int; let text: String }
    struct Frame: Decodable {
        let t: Double
        let url: String
        let x: Double, y: Double, w: Double, h: Double
    }

    static func fetch(videoID: String) async -> Response? {
        guard let base = baseURL,
              var components = URLComponents(url: base.appendingPathComponent("api/youtube"),
                                             resolvingAgainstBaseURL: false)
        else { return nil }
        components.queryItems = [URLQueryItem(name: "v", value: videoID)]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let decoded = try? JSONDecoder().decode(Response.self, from: data)
        else { return nil }
        return decoded
    }

    /// "[m:ss] text" lines — same shape the analyzer/detail view expect.
    static func transcriptText(_ response: Response) -> String? {
        let lines = response.transcript.map { "[\(Timestamps.label(Double($0.t)))] \($0.text)" }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    static func videoFrames(_ response: Response) -> [VideoFrame] {
        response.frames.compactMap { frame in
            guard let url = URL(string: frame.url) else { return nil }
            return VideoFrame(
                sheetURL: url,
                rect: CGRect(x: frame.x, y: frame.y, width: frame.w, height: frame.h),
                seconds: frame.t
            )
        }
    }
}
