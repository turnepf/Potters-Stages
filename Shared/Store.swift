import Foundation
import SwiftData

/// The one place the SwiftData store is configured, used by both the app and the share extension.
enum Store {
    static let appGroup = "group.net.patrickturner.pottersstages"
    static let iCloudContainer = "iCloud.net.patrickturner.pottersstages"

    /// The database lives in the shared App Group folder (so the share extension can write to it)
    /// and mirrors to the user's private iCloud database. Works offline; syncs when connected.
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let configuration = inMemory
            ? ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            : ModelConfiguration(
                "PottersStages",
                groupContainer: .identifier(appGroup),
                cloudKitDatabase: .private(iCloudContainer)
            )
        do {
            return try ModelContainer(for: Piece.self, Photo.self, configurations: configuration)
        } catch {
            fatalError("Could not open the Potter's Stages database: \(error)")
        }
    }
}
