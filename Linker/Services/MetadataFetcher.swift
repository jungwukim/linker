import Foundation

struct LinkMetadata {
    var title: String?
    var description: String?
    var thumbnailURLString: String?
    /// Cleaned main page text (best effort) for deeper analysis of articles/blogs.
    var bodyText: String?
}

/// Best-effort extraction of public metadata for a shared URL.
///
/// YouTube exposes a clean oEmbed endpoint; for everything else we read
/// OpenGraph (`og:*`) tags from the page <head>. Some services (Instagram,
/// Threads, X behind login) return little or nothing — that's expected, and the
/// analyzer falls back to whatever text was captured at share time.
enum MetadataFetcher {
    static func fetch(url: URL, platform: Platform) async -> LinkMetadata {
        if platform == .youtube, let meta = await youTubeOEmbed(url: url) {
            return meta
        }
        return await openGraph(url: url)
    }

    private static func youTubeOEmbed(url: URL) async -> LinkMetadata? {
        var components = URLComponents(string: "https://www.youtube.com/oembed")!
        components.queryItems = [
            URLQueryItem(name: "url", value: url.absoluteString),
            URLQueryItem(name: "format", value: "json"),
        ]
        guard let endpoint = components.url,
              let (data, response) = try? await URLSession.shared.data(from: endpoint),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return LinkMetadata(
            title: json["title"] as? String,
            description: json["author_name"] as? String,
            thumbnailURLString: json["thumbnail_url"] as? String
        )
    }

    private static func openGraph(url: URL) async -> LinkMetadata {
        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.timeoutInterval = 12
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let html = String(data: data, encoding: .utf8)
        else { return LinkMetadata() }

        return LinkMetadata(
            title: ogContent(in: html, property: "og:title") ?? titleTag(in: html),
            description: ogContent(in: html, property: "og:description"),
            thumbnailURLString: ogContent(in: html, property: "og:image"),
            bodyText: extractBodyText(from: html)
        )
    }

    /// Crude main-text extraction: drop script/style/markup, collapse whitespace.
    /// Good enough to give the analyzer real article/blog content beyond og:description.
    private static func extractBodyText(from html: String) -> String? {
        var text = html
        for pattern in ["<script[^>]*>.*?</script>", "<style[^>]*>.*?</style>", "<!--.*?-->", "<[^>]+>"] {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                let range = NSRange(text.startIndex..., in: text)
                text = regex.stringByReplacingMatches(in: text, range: range, withTemplate: " ")
            }
        }
        text = decodeEntities(text)
        let collapsed = text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let trimmed = collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 200 ? String(trimmed.prefix(8000)) : nil
    }

    private static func ogContent(in html: String, property: String) -> String? {
        // Matches <meta property="og:title" content="..."> in either attribute order.
        let patterns = [
            "<meta[^>]+property=[\"']\(property)[\"'][^>]+content=[\"']([^\"']*)[\"']",
            "<meta[^>]+content=[\"']([^\"']*)[\"'][^>]+property=[\"']\(property)[\"']",
        ]
        for pattern in patterns {
            if let value = firstMatch(pattern, in: html) { return decodeEntities(value) }
        }
        return nil
    }

    private static func titleTag(in html: String) -> String? {
        firstMatch("<title[^>]*>([^<]*)</title>", in: html).map(decodeEntities)
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1,
              let captured = Range(match.range(at: 1), in: text) else { return nil }
        let value = String(text[captured]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func decodeEntities(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }
}
