import Foundation

/// Best-effort YouTube transcript fetch (no API key).
///
/// Pulls the watch page, locates the `captionTracks` list inside the embedded
/// player JSON, picks a track (preferring Korean, then English, then the first),
/// downloads its timed-text XML, and flattens it to plain text. This is an
/// undocumented surface and can break or return nothing (no captions, consent
/// walls, region blocks) — callers treat the result as optional enrichment.
enum TranscriptFetcher {
    static func youTubeTranscript(url: URL) async -> String? {
        guard let videoID = videoID(from: url) else { return nil }
        guard let html = await YouTube.watchPageHTML(videoID: videoID),
              let trackURL = captionTrackURL(in: html) else { return nil }
        return await fetchTimedText(trackURL)
    }

    static func videoID(from url: URL) -> String? {
        guard let host = url.host?.lowercased() else { return nil }
        if host.contains("youtu.be") {
            return url.pathComponents.dropFirst().first
        }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let v = components?.queryItems?.first(where: { $0.name == "v" })?.value {
            return v
        }
        // /shorts/<id> or /embed/<id>
        let parts = url.pathComponents
        if let idx = parts.firstIndex(where: { $0 == "shorts" || $0 == "embed" }),
           idx + 1 < parts.count {
            return parts[idx + 1]
        }
        return nil
    }

    /// Finds the preferred caption track's baseUrl inside `"captionTracks":[ ... ]`.
    private static func captionTrackURL(in html: String) -> URL? {
        guard let arrayJSON = firstMatch("\"captionTracks\":(\\[.*?\\])", in: html),
              let data = arrayJSON.data(using: .utf8),
              let tracks = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              !tracks.isEmpty else { return nil }

        func track(forLanguage code: String) -> [String: Any]? {
            tracks.first { ($0["languageCode"] as? String)?.hasPrefix(code) == true }
        }
        let chosen = track(forLanguage: "ko") ?? track(forLanguage: "en") ?? tracks.first
        guard let baseURL = chosen?["baseUrl"] as? String else { return nil }
        // baseUrl arrives JSON-escaped (& → &, \/ → /); request srv3 XML explicitly.
        let unescaped = baseURL
            .replacingOccurrences(of: "\\u0026", with: "&")
            .replacingOccurrences(of: "\\/", with: "/")
        return URL(string: unescaped + "&fmt=srv3")
    }

    private static func fetchTimedText(_ url: URL) async -> String? {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64)", forHTTPHeaderField: "User-Agent")
        request.setValue(YouTube.cookieHeader, forHTTPHeaderField: "Cookie")
        request.httpShouldHandleCookies = false
        request.cachePolicy = .reloadIgnoringLocalCacheData
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let xml = String(data: data, encoding: .utf8) else { return nil }

        // Capture each cue's start time + text → "[mm:ss] text" lines so both the
        // analyzer and the detail view get a timestamped, jumpable transcript.
        guard let regex = try? NSRegularExpression(
            pattern: "<text start=\"([0-9.]+)\"[^>]*>(.*?)</text>",
            options: [.dotMatchesLineSeparators]
        ) else { return nil }

        let range = NSRange(xml.startIndex..., in: xml)
        let lines = regex.matches(in: xml, range: range).compactMap { match -> String? in
            guard let startRange = Range(match.range(at: 1), in: xml),
                  let textRange = Range(match.range(at: 2), in: xml) else { return nil }
            let start = Double(xml[startRange]) ?? 0
            let text = decodeEntities(String(xml[textRange]))
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            return text.isEmpty ? nil : "[\(timestamp(start))] \(text)"
        }
        let joined = lines.joined(separator: "\n")
        return joined.isEmpty ? nil : String(joined.prefix(100_000))
    }

    private static func timestamp(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1,
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }

    private static func decodeEntities(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "\\n", with: " ")
    }
}
