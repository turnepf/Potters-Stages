import Foundation
import SwiftData
import Testing
@testable import PottersStages

/// Export then import must bring back every piece and photo unchanged, since the backup is
/// how the real collection moves from the Development to the Production iCloud database.
@MainActor
final class BackupTests {
    /// Containers stay alive for the whole test; a context outlived by its container crashes.
    private var containers: [ModelContainer] = []

    private func makeContext() -> ModelContext {
        let container = Store.makeContainer(inMemory: true)
        containers.append(container)
        return container.mainContext
    }

    private func makeSamplePiece(in context: ModelContext) -> Piece {
        let piece = Piece(title: "Tall vase", notes: "Celadon glaze", inspirationURL: URL(string: "https://example.com/vase"), stage: .greenware)
        piece.createdAt = Date(timeIntervalSince1970: 1_750_000_000.123)
        piece.ideaAt = Date(timeIntervalSince1970: 1_750_000_000)
        piece.leatherHardAt = Date(timeIntervalSince1970: 1_750_100_000)
        context.insert(piece)
        piece.photos = [
            Photo(imageData: Data([1, 2, 3]), thumbnail: Data([4]), stageRaw: Stage.idea.rawValue, addedAt: Date(timeIntervalSince1970: 1_750_000_001), fingerprint: "abc"),
            Photo(imageData: Data([5, 6]), thumbnail: nil, stageRaw: Stage.greenware.rawValue, addedAt: Date(timeIntervalSince1970: 1_750_200_000), fingerprint: nil),
        ]
        return piece
    }

    @Test func roundTripKeepsEverything() throws {
        let source = makeContext()
        let original = makeSamplePiece(in: source)
        source.insert(Piece(title: "", stage: .idea))
        try source.save()

        let data = try Backup(from: source).encoded()

        let destination = makeContext()
        let result = try Backup.decode(data).restore(into: destination)
        #expect(result == .init(pieces: 2, photos: 2, skipped: 0))

        let restored = try #require(try destination.fetch(FetchDescriptor<Piece>()).first { $0.title == "Tall vase" })
        #expect(restored.notes == original.notes)
        #expect(restored.inspirationURL == original.inspirationURL)
        #expect(restored.stage == .greenware)
        #expect(restored.createdAt == original.createdAt)
        #expect(restored.updatedAt == original.updatedAt)
        for stage in Stage.allCases {
            #expect(restored.reachedDate(for: stage) == original.reachedDate(for: stage))
        }
        let photos = restored.sortedPhotos
        #expect(photos.map(\.imageData) == [Data([1, 2, 3]), Data([5, 6])])
        #expect(photos.map(\.thumbnail) == [Data([4]), nil])
        #expect(photos.map(\.stage) == [.idea, .greenware])
        #expect(photos.map(\.addedAt) == original.sortedPhotos.map(\.addedAt))
        #expect(photos.map(\.fingerprint) == ["abc", nil])
    }

    @Test func importingTwiceAddsNothingTheSecondTime() throws {
        let source = makeContext()
        _ = makeSamplePiece(in: source)
        let backup = try Backup.decode(Backup(from: source).encoded())

        let destination = makeContext()
        try backup.restore(into: destination)
        let second = try backup.restore(into: destination)

        #expect(second == .init(pieces: 0, photos: 0, skipped: 1))
        #expect(try destination.fetchCount(FetchDescriptor<Piece>()) == 1)
        #expect(try destination.fetchCount(FetchDescriptor<Photo>()) == 2)
    }

    @Test func nonWebLinksAreDropped() throws {
        var backup = Backup()
        backup.pieces = [.init(title: "Bowl", notes: "", inspirationURL: "file:///etc/hosts", stageRaw: Stage.idea.rawValue, createdAt: .now, updatedAt: .now, photos: [])]
        let context = makeContext()
        try backup.restore(into: context)
        #expect(try context.fetch(FetchDescriptor<Piece>()).first?.inspirationURL == nil)
    }

    @Test func newerBackupIsRefused() throws {
        var backup = Backup()
        backup.version = Backup.currentVersion + 1
        #expect(throws: BackupError.self) { try Backup.decode(backup.encoded()) }
    }
}
