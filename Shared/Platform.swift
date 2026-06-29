import Foundation

/// The originating service for a saved item, inferred from its URL host.
/// Drives the per-source icon/label in the UI and gives the analyzer a hint.
enum Platform: String, Codable, CaseIterable {
    case youtube
    case instagram
    case threads
    case x
    case facebook
    case appleNotes
    case web

    var displayName: String {
        switch self {
        case .youtube: return "YouTube"
        case .instagram: return "Instagram"
        case .threads: return "Threads"
        case .x: return "X"
        case .facebook: return "Facebook"
        case .appleNotes: return "메모"
        case .web: return "웹"
        }
    }

    /// SF Symbol used as a lightweight per-source badge.
    var symbolName: String {
        switch self {
        case .youtube: return "play.rectangle.fill"
        case .instagram: return "camera.fill"
        case .threads: return "at"
        case .x: return "bird.fill"
        case .facebook: return "person.2.fill"
        case .appleNotes: return "note.text"
        case .web: return "globe"
        }
    }

    static func infer(fromURL url: URL?, hasText: Bool) -> Platform {
        guard let host = url?.host?.lowercased() else {
            return hasText ? .appleNotes : .web
        }
        if host.contains("youtube.") || host.contains("youtu.be") { return .youtube }
        if host.contains("instagram.") { return .instagram }
        if host.contains("threads.") { return .threads }
        if host.contains("x.com") || host.contains("twitter.") { return .x }
        if host.contains("facebook.") || host.contains("fb.watch") { return .facebook }
        return .web
    }
}
