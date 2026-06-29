import Foundation

/// Parses/formats the `[m:ss]` / `[h:mm:ss]` timestamps that the analyzer prefixes
/// onto video key points.
enum Timestamps {
    /// Seconds from a key-point string that starts with `[m:ss]` or `[h:mm:ss]`.
    static func seconds(fromKeyPoint string: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: "^\\s*\\[(\\d{1,2}):(\\d{2})(?::(\\d{2}))?\\]") else { return nil }
        let range = NSRange(string.startIndex..., in: string)
        guard let match = regex.firstMatch(in: string, range: range) else { return nil }

        func group(_ index: Int) -> Int? {
            guard let r = Range(match.range(at: index), in: string) else { return nil }
            return Int(string[r])
        }
        let first = group(1) ?? 0
        let second = group(2) ?? 0
        if let third = group(3) {           // [h:mm:ss]
            return Double(first * 3600 + second * 60 + third)
        }
        return Double(first * 60 + second)  // [m:ss]
    }

    static func label(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
