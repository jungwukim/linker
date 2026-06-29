import Foundation
import CoreGraphics

/// A single video frame located inside a YouTube storyboard sprite sheet.
struct VideoFrame: Identifiable {
    let id = UUID()
    let sheetURL: URL
    let rect: CGRect   // pixel rect to crop out of the downloaded sheet image
    let seconds: Double
}

/// Best-effort extraction of YouTube storyboard frames (the little preview images
/// shown while scrubbing). We parse `playerStoryboardSpecRenderer` from the watch
/// page, pick the highest-resolution level, and compute the sprite-sheet URL +
/// crop rect for each requested timestamp. Undocumented surface — degrades to no
/// frames if anything is missing.
enum StoryboardFetcher {
    /// Frames at the given timestamps. If `timestamps` is empty, frames are spread
    /// evenly across the video (duration derived from the storyboard itself), so the
    /// gallery still works for videos without usable captions.
    static func frames(videoID: String, timestamps: [Double], fallbackCount: Int = 9) async -> [VideoFrame] {
        guard let html = await YouTube.watchPageHTML(videoID: videoID) else { return [] }
        guard let rawSpec = firstMatch("\"playerStoryboardSpecRenderer\":\\{\"spec\":\"(.*?)\"", in: html) else { return [] }

        let spec = rawSpec
            .replacingOccurrences(of: "\\u0026", with: "&")
            .replacingOccurrences(of: "\\/", with: "/")
        let parts = spec.components(separatedBy: "|")
        guard parts.count >= 2 else { return [] }
        let base = parts[0]
        let fragments = parts.dropFirst()

        // Parse each level; keep the widest (highest resolution).
        struct Level { let index: Int; let w, h, count, cols, rows, interval: Int; let name, sigh: String }
        var best: Level?
        for (offset, fragment) in fragments.enumerated() {
            let f = fragment.components(separatedBy: "#")
            guard f.count >= 8,
                  let w = Int(f[0]), let h = Int(f[1]), let count = Int(f[2]),
                  let cols = Int(f[3]), let rows = Int(f[4]), let interval = Int(f[5])
            else { continue }
            let level = Level(index: offset, w: w, h: h, count: count, cols: cols, rows: rows,
                              interval: interval, name: f[6], sigh: f[7])
            if best == nil || w > best!.w { best = level }
        }
        guard let level = best, level.interval > 0, level.cols > 0, level.rows > 0, level.count > 0
        else { return [] }

        // Use caption timestamps if present, otherwise spread evenly over the video.
        let durationSeconds = Double(level.count * level.interval) / 1000.0
        let targets: [Double]
        if timestamps.isEmpty {
            let count = max(1, min(fallbackCount, level.count))
            targets = (0..<count).map { durationSeconds * (Double($0) + 0.5) / Double(count) }
        } else {
            targets = timestamps
        }

        let perSheet = level.cols * level.rows
        return targets.compactMap { seconds in
            var frameIndex = Int(seconds * 1000 / Double(level.interval))
            frameIndex = max(0, min(frameIndex, level.count - 1))
            let sheetIndex = frameIndex / perSheet
            let inSheet = frameIndex % perSheet
            let col = inSheet % level.cols
            let row = inSheet / level.cols

            // Order matters: replace $N (name, e.g. "M$M") before $M (sheet index).
            var urlString = base
                .replacingOccurrences(of: "$L", with: String(level.index))
                .replacingOccurrences(of: "$N", with: level.name)
                .replacingOccurrences(of: "$M", with: String(sheetIndex))
            if !urlString.contains("sigh=") { urlString += "&sigh=" + level.sigh }

            guard let url = URL(string: urlString) else { return nil }
            let rect = CGRect(x: col * level.w, y: row * level.h, width: level.w, height: level.h)
            return VideoFrame(sheetURL: url, rect: rect, seconds: seconds)
        }
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1,
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }
}
