#if DEBUG
import Foundation
import SwiftData

/// One-time import of the old Apple Notes data. Debug builds only.
/// If Documents/Import/import.json exists at launch, it creates those pieces and
/// then deletes the Import folder, so it only ever runs once.
enum NotesImport {
    private struct Entry: Decodable {
        var title: String
        var notes: String?
        var url: String?
        var stage: String
        var photos: [PhotoEntry]
    }

    private struct PhotoEntry: Decodable {
        var file: String
        var stage: String
    }

    static func runIfPresent(into context: ModelContext) {
        let folder = URL.documentsDirectory.appending(path: "Import")
        guard let json = try? Data(contentsOf: folder.appending(path: "import.json")),
              let entries = try? JSONDecoder().decode([Entry].self, from: json) else { return }

        // Keep the notes' order: earlier entries get later dates so they sort first.
        let start = Date.now
        for (index, entry) in entries.enumerated() {
            let date = start.addingTimeInterval(-Double(index) * 60)
            let piece = Piece(
                title: entry.title,
                notes: entry.notes ?? "",
                inspirationURL: entry.url.flatMap(URL.init(string:)),
                stage: Stage(rawValue: entry.stage) ?? .idea
            )
            // Notes never recorded stage dates, so leave the history empty.
            Stage.allCases.forEach { piece.setReachedDate(nil, for: $0) }
            context.insert(piece)
            for (photoIndex, photo) in entry.photos.enumerated() {
                if let data = try? Data(contentsOf: folder.appending(path: photo.file)) {
                    piece.addPhoto(data, stage: Stage(rawValue: photo.stage) ?? piece.stage,
                                   addedAt: date.addingTimeInterval(Double(photoIndex)))
                }
            }
            piece.createdAt = date
            piece.updatedAt = date
        }
        try? context.save()
        try? FileManager.default.removeItem(at: folder)
    }
}
#endif
