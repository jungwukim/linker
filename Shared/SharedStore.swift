import Foundation
import SwiftData

/// The single SwiftData container.
///
/// Tries progressively simpler configurations so the app always launches:
///   1. App Group + CloudKit  → shared across devices via iCloud, and shared with the Share Extension
///   2. App Group only        → shared with the Share Extension, no iCloud sync
///   3. Local                 → last resort so the app never hard-crashes
///
/// CloudKit only activates when the iCloud entitlement/container is provisioned
/// (real DEVELOPMENT_TEAM + signed-in iCloud account). In environments without
/// it, step 1 fails or runs inert and we fall back automatically.
@MainActor
enum SharedStore {
    static let container: ModelContainer = makeContainer()

    private static func makeContainer() -> ModelContainer {
        let schema = Schema([SavedItem.self])

        let configs: [(label: String, configuration: ModelConfiguration)] = [
            ("App Group + CloudKit", ModelConfiguration(
                schema: schema,
                groupContainer: .identifier(AppGroup.identifier),
                cloudKitDatabase: .automatic
            )),
            ("App Group", ModelConfiguration(
                schema: schema,
                groupContainer: .identifier(AppGroup.identifier)
            )),
            ("Local", ModelConfiguration(schema: schema)),
        ]

        for config in configs {
            if let container = try? ModelContainer(for: schema, configurations: [config.configuration]) {
                return container
            }
            NSLog("[Linker] Store configuration '%@' unavailable — trying next.", config.label)
        }

        fatalError("Failed to create any ModelContainer for Linker.")
    }
}
