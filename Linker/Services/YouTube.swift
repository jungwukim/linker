import Foundation

/// Shared YouTube watch-page fetch. A bare request hits YouTube's consent wall
/// (a tiny redirect page); sending a consent cookie + gl/hl returns the real page
/// containing `captionTracks` and `playerStoryboardSpecRenderer`.
enum YouTube {
    static func watchPageHTML(videoID: String) async -> String? {
        guard let url = URL(string: "https://www.youtube.com/watch?v=\(videoID)&hl=en&gl=US") else { return nil }
        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        // URLSession otherwise replaces our manual Cookie header with its (empty)
        // cookie store, which re-triggers the consent wall. Keep our cookie.
        request.httpShouldHandleCookies = false
        // Never serve a previously-cached consent-wall page.
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 12
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Always start with the consent-bypass cookie (so we never hit the consent
    /// wall), then append any logged-in cookies the user captured.
    static var cookieHeader: String {
        var parts = ["CONSENT=YES+1", "SOCS=CAI"]
        if let stored = CookieStore.cookieHeader(for: .youtube) {
            for pair in stored.split(separator: ";") {
                let name = pair.split(separator: "=").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
                if !name.isEmpty, name != "CONSENT", name != "SOCS" {
                    parts.append(pair.trimmingCharacters(in: .whitespaces))
                }
            }
        }
        return parts.joined(separator: "; ")
    }
}
