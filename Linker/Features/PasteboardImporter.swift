import Foundation
import SwiftData
import UIKit

/// Creates a pending `SavedItem` from whatever link/text is on the clipboard,
/// so the user can save content without going through the Share Sheet.
enum PasteboardImporter {
    enum ImportError: LocalizedError {
        case empty
        var errorDescription: String? { "클립보드에 저장할 링크나 텍스트가 없어요." }
    }

    @MainActor
    @discardableResult
    static func importFromClipboard(into context: ModelContext) throws -> SavedItem {
        let pasteboard = UIPasteboard.general

        var url: URL?
        if pasteboard.hasURLs, let first = pasteboard.urls?.first {
            url = first
        }

        var text: String?
        if let string = pasteboard.string?.trimmingCharacters(in: .whitespacesAndNewlines), !string.isEmpty {
            if url == nil, let detected = firstURL(in: string) {
                url = detected
            } else if url == nil {
                text = string
            }
        }

        guard url != nil || (text?.isEmpty == false) else {
            throw ImportError.empty
        }

        let platform = Platform.infer(fromURL: url, hasText: text?.isEmpty == false)
        let item = SavedItem(
            sourceURLString: url?.absoluteString,
            rawText: text,
            platform: platform,
            status: .pending
        )
        context.insert(item)
        try context.save()
        return item
    }

    private static func firstURL(in string: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let range = NSRange(string.startIndex..., in: string)
        return detector.firstMatch(in: string, range: range)?.url
    }
}
