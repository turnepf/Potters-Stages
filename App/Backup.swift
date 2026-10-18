import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// A whole-collection backup file: every piece and photo, saved as a binary property list.
///
/// Its main job is the one-time move from the CloudKit Development database (Xcode builds)
/// to Production (TestFlight / App Store builds): export in one, import in the other.
/// See docs/PUBLISHING.md.
nonisolated struct Backup: Codable {
    static let currentVersion = 1

    var version = Backup.currentVersion
    var exportedAt = Date.now
    var pieces: [PieceRecord] = []

    struct PieceRecord: Codable {
        var title: String
        var notes: String
        var inspirationURL: String?
        var stageRaw: String
        var createdAt: Date
        var updatedAt: Date
        var ideaAt: Date?
        var leatherHardAt: Date?
        var greenwareAt: Date?
        var bisquewareAt: Date?
        var finishedAt: Date?
        var photos: [PhotoRecord]
    }

    struct PhotoRecord: Codable {
        var imageData: Data?
        var thumbnail: Data?
        var stageRaw: String
        var addedAt: Date
        var fingerprint: String?
    }

    var photoCount: Int { pieces.reduce(0) { $0 + $1.photos.count } }

    func encoded() throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> Backup {
        let backup = try PropertyListDecoder().decode(Backup.self, from: data)
        guard backup.version <= currentVersion else { throw BackupError.newerVersion }
        return backup
    }
}

enum BackupError: LocalizedError {
    case newerVersion

    var errorDescription: String? {
        "This backup was made by a newer version of Potter's Stages. Update the app and try again."
    }
}

extension Backup {
    /// Everything in the database.
    init(from context: ModelContext) throws {
        let pieces = try context.fetch(FetchDescriptor<Piece>(sortBy: [SortDescriptor(\.createdAt)]))
        self.pieces = pieces.map { piece in
            PieceRecord(
                title: piece.title,
                notes: piece.notes,
                inspirationURL: piece.inspirationURL?.absoluteString,
                stageRaw: piece.stageRaw,
                createdAt: piece.createdAt,
                updatedAt: piece.updatedAt,
                ideaAt: piece.ideaAt,
                leatherHardAt: piece.leatherHardAt,
                greenwareAt: piece.greenwareAt,
                bisquewareAt: piece.bisquewareAt,
                finishedAt: piece.finishedAt,
                photos: piece.sortedPhotos.map { photo in
                    PhotoRecord(
                        imageData: photo.imageData,
                        thumbnail: photo.thumbnail,
                        stageRaw: photo.stageRaw,
                        addedAt: photo.addedAt,
                        fingerprint: photo.fingerprint
                    )
                }
            )
        }
    }

    struct ImportResult: Equatable {
        var pieces = 0
        var photos = 0
        var skipped = 0
    }

    /// Adds the backup's pieces to the database. A piece that's already there (same title,
    /// created at the same moment) is skipped, so importing the same file twice is harmless.
    @discardableResult
    func restore(into context: ModelContext) throws -> ImportResult {
        let existing = try context.fetch(FetchDescriptor<Piece>())
        var result = ImportResult()
        for record in pieces {
            // CloudKit keeps dates to the millisecond, so allow a little slack.
            let alreadyHere = existing.contains {
                $0.title == record.title && abs($0.createdAt.timeIntervalSince(record.createdAt)) < 1
            }
            if alreadyHere {
                result.skipped += 1
                continue
            }
            let piece = Piece(title: record.title, notes: record.notes)
            piece.inspirationURL = record.inspirationURL.flatMap(URL.init(string:)).flatMap { $0.isWebLink ? $0 : nil }
            piece.stageRaw = record.stageRaw
            piece.createdAt = record.createdAt
            piece.updatedAt = record.updatedAt
            piece.ideaAt = record.ideaAt
            piece.leatherHardAt = record.leatherHardAt
            piece.greenwareAt = record.greenwareAt
            piece.bisquewareAt = record.bisquewareAt
            piece.finishedAt = record.finishedAt
            context.insert(piece)
            piece.photos = record.photos.map {
                Photo(
                    imageData: $0.imageData,
                    thumbnail: $0.thumbnail,
                    stageRaw: $0.stageRaw,
                    addedAt: $0.addedAt,
                    fingerprint: $0.fingerprint
                )
            }
            result.pieces += 1
            result.photos += record.photos.count
        }
        try context.save()
        return result
    }
}

/// The exported file handed to the system save dialog.
nonisolated struct BackupFile: FileDocument {
    static let readableContentTypes: [UTType] = [.propertyList]

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// Adds a "More" toolbar menu with Export Backup and Import Backup.
struct BackupCommands: ViewModifier {
    @Environment(\.modelContext) private var context
    @State private var exportFile: BackupFile?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var message: (title: String, body: String)?

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Menu("More", systemImage: "ellipsis.circle") {
                        Button("Export Backup…", systemImage: "square.and.arrow.up", action: export)
                        Button("Import Backup…", systemImage: "square.and.arrow.down") { isImporting = true }
                    }
                }
            }
            .fileExporter(
                isPresented: $isExporting,
                document: exportFile,
                contentType: .propertyList,
                defaultFilename: "Potter's Stages Backup \(Date.now.formatted(.iso8601.year().month().day()))"
            ) { result in
                exportFile = nil
                if case .failure(let error) = result {
                    message = ("Couldn't Save Backup", error.localizedDescription)
                }
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.propertyList]) { result in
                switch result {
                case .success(let url): importBackup(from: url)
                case .failure(let error): message = ("Couldn't Open Backup", error.localizedDescription)
                }
            }
            .alert(
                message?.title ?? "",
                isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })
            ) {
                Button("OK") {}
            } message: {
                Text(message?.body ?? "")
            }
    }

    private func export() {
        do {
            let backup = try Backup(from: context)
            exportFile = BackupFile(data: try backup.encoded())
            isExporting = true
        } catch {
            message = ("Couldn't Export", error.localizedDescription)
        }
    }

    private func importBackup(from url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        do {
            let backup = try Backup.decode(Data(contentsOf: url))
            let result = try backup.restore(into: context)
            var lines = ["Added \(result.pieces) pieces and \(result.photos) photos."]
            if result.skipped > 0 {
                lines.append("Skipped \(result.skipped) pieces that were already here.")
            }
            message = ("Backup Imported", lines.joined(separator: " "))
        } catch {
            message = ("Couldn't Import", error.localizedDescription)
        }
    }
}
