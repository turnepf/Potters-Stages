import CloudKit
import CoreData
import Foundation
import Security
import SwiftData

/// Which of the container's two iCloud databases this build talks to. Builds from Xcode use
/// Development; TestFlight and App Store builds use Production. See docs/PUBLISHING.md.
nonisolated enum CloudEnvironment: String {
    case development = "Development"
    case production = "Production"

    static let current: CloudEnvironment = {
        #if os(macOS)
        // The Mac can read its own signed entitlements directly.
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(task, "com.apple.developer.icloud-container-environment" as CFString, nil)
        else { return .development }
        return (value as? String) == "Production" ? .production : .development
        #elseif targetEnvironment(simulator)
        // Simulator builds always come from Xcode and carry no provisioning profile.
        return .development
        #else
        // iOS can't read its entitlements, but development signing always embeds a debug profile
        // (get-task-allow), and TestFlight / App Store builds embed none.
        let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision")
        return fromProvisioningProfile(url.flatMap { try? Data(contentsOf: $0) })
        #endif
    }()

    /// The profile is a signed wrapper around a plain-text plist, so a text search is enough.
    static func fromProvisioningProfile(_ data: Data?) -> CloudEnvironment {
        guard let data else { return .production }
        let text = String(decoding: data, as: UTF8.self)
        return text.range(of: #"<key>get-task-allow</key>\s*<true/>"#, options: .regularExpression) != nil
            ? .development : .production
    }
}

/// How many pieces and photos are in iCloud compared with this device, to confirm everything
/// has uploaded (for instance after importing a backup).
struct SyncCounts: Equatable {
    var cloudPieces = 0
    var cloudPhotos = 0
    var localPieces = 0
    var localPhotos = 0

    var isInSync: Bool { cloudPieces == localPieces && cloudPhotos == localPhotos }

    /// `activity` is what CloudKit last reported doing on this device (see `SyncMonitor`).
    func summary(activity: String = "") -> String {
        var text = "iCloud has \(cloudPieces) pieces and \(cloudPhotos) photos. "
            + "This device has \(localPieces) pieces and \(localPhotos) photos."
        if !isInSync {
            text += "\n\nThey don't match yet. Keep the app open on Wi-Fi for a few minutes and check again."
        }
        if !activity.isEmpty { text += "\n\n" + activity }
        return text
    }

    var summary: String { summary() }

    static func check(_ context: ModelContext) async throws -> SyncCounts {
        var counts = SyncCounts(
            localPieces: try context.fetchCount(FetchDescriptor<Piece>()),
            localPhotos: try context.fetchCount(FetchDescriptor<Photo>())
        )
        let byType = try await cloudRecordCounts()
        counts.cloudPieces = byType["CD_Piece", default: 0]
        counts.cloudPhotos = byType["CD_Photo", default: 0]
        return counts
    }

    /// Counts the records SwiftData has uploaded, by type. Asks for no fields, so photos
    /// aren't downloaded.
    private static func cloudRecordCounts() async throws -> [String: Int] {
        let database = CKContainer(identifier: Store.iCloudContainer).privateCloudDatabase
        let zone = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone")
        var counts: [String: Int] = [:]
        var token: CKServerChangeToken?
        var moreComing = true
        do {
            while moreComing {
                let changes = try await database.recordZoneChanges(inZoneWith: zone, since: token, desiredKeys: [])
                for result in changes.modificationResultsByID.values {
                    if case .success(let modification) = result {
                        counts[modification.record.recordType, default: 0] += 1
                    }
                }
                token = changes.changeToken
                moreComing = changes.moreComing
            }
        } catch let error as CKError where error.code == .zoneNotFound {
            return [:]  // nothing has ever been uploaded to this database
        }
        return counts
    }
}

/// Remembers what SwiftData's iCloud mirroring last did on this device, including the error when
/// it fails. The mirroring is automatic and silent, so without this a stuck upload looks fine.
@MainActor
final class SyncMonitor {
    static let shared = SyncMonitor()

    struct Entry: Equatable {
        var date: Date
        var succeeded: Bool
        var error: String?
    }

    private(set) var lastSetup: Entry?
    private(set) var lastImport: Entry?
    private(set) var lastExport: Entry?
    private var observer: NSObjectProtocol?

    /// Call once at launch so events from startup aren't missed.
    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event,
                  let end = event.endDate else { return }  // still running
            let entry = Entry(date: end, succeeded: event.succeeded, error: event.error?.localizedDescription)
            MainActor.assumeIsolated {
                switch event.type {
                case .setup: self?.lastSetup = entry
                case .import: self?.lastImport = entry
                case .export: self?.lastExport = entry
                @unknown default: break
                }
            }
        }
    }

    /// Plain-language lines for the sync check alert.
    var report: String {
        func line(_ name: String, _ entry: Entry?) -> String {
            guard let entry else { return "\(name): nothing yet this session" }
            let when = entry.date.formatted(date: .omitted, time: .standard)
            return entry.succeeded ? "\(name): OK at \(when)"
                : "\(name): FAILED at \(when) — \(entry.error ?? "unknown error")"
        }
        return ["Last iCloud activity on this device:",
                line("Setup", lastSetup), line("Download", lastImport), line("Upload", lastExport)]
            .joined(separator: "\n")
    }
}
