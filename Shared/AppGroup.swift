import Foundation

/// Identifiers shared between the main app and the Share Extension.
/// The App Group is what lets both processes read/write the same SwiftData store.
enum AppGroup {
    static let identifier = "group.dev.linker.app"
}
