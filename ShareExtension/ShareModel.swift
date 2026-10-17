import Foundation
import LinkPresentation
import SwiftData
import UniformTypeIdentifiers

/// Pulls the link and/or image out of whatever was shared, and saves it to a new
/// or existing piece.
@Observable
final class ShareModel {
    var addToExisting = false
    var existingPiece: Piece? {
        didSet { if let existingPiece { stage = existingPiece.stage } }
    }
    var stage: Stage = .idea
    var title = ""
    var notes = ""

    private(set) var url: URL?
    private(set) var imageData: Data?
    private(set) var isLoading = true
    private(set) var didSave = false
    /// Pieces you can add to: in-progress first, newest first.
    private(set) var pieces: [Piece] = []

    var canSave: Bool {
        (url != nil || imageData != nil) && (!addToExisting || existingPiece != nil)
    }

    private let extensionContext: NSExtensionContext?
    // Opened up front so CloudKit is ready by the time Save is tapped.
    private let container = Store.makeContainer()

    init(context: NSExtensionContext?) {
        self.extensionContext = context
        let all = (try? container.mainContext.fetch(
            FetchDescriptor<Piece>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        )) ?? []
        pieces = all.filter { $0.stage != .finished } + all.filter { $0.stage == .finished }
        Task { await load() }
    }

    func save() {
        let note = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let piece: Piece
        if addToExisting, let existingPiece {
            piece = existingPiece
            piece.stage = stage
            if !note.isEmpty {
                piece.notes = piece.notes.isEmpty ? note : piece.notes + "\n\n" + note
            }
            if let url {
                piece.inspirationURL = url
            }
        } else {
            piece = Piece(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: note,
                inspirationURL: url,
                stage: stage
            )
            container.mainContext.insert(piece)
        }
        if let imageData {
            piece.addPhoto(imageData, stage: stage)
        }
        piece.updatedAt = .now
        try? container.mainContext.save()

        // Show "Saved" briefly; it also gives iCloud a moment to start uploading.
        // If the system closes us before it finishes, the main app uploads it next time it opens.
        didSave = true
        Task {
            try? await Task.sleep(for: .seconds(0.8))
            extensionContext?.completeRequest(returningItems: nil)
        }
    }

    func cancel() {
        extensionContext?.cancelRequest(withError: CocoaError(.userCancelled))
    }

    // MARK: - Reading the shared items

    private func load() async {
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        let providers = items.flatMap { $0.attachments ?? [] }

        for provider in providers {
            if imageData == nil, provider.hasItemConformingToTypeIdentifier(UTType.image.identifier),
               let data = await provider.loadData(of: .image) {
                imageData = await Self.resized(data)
            }
            if url == nil, provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
               let sharedURL = await provider.loadURL(), !sharedURL.isFileURL {
                url = sharedURL
            }
            // Some apps share a link inside plain text.
            if url == nil, provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
               let text = await provider.loadText() {
                url = Self.firstLink(in: text)
            }
        }

        if imageData == nil, let url {
            imageData = await Self.previewImage(for: url)
        }
        isLoading = false
    }

    /// Tries to get the page's preview image (like Messages does). Many sites, including
    /// Instagram, often block this — then we just return nil and show a placeholder.
    private static func previewImage(for url: URL) async -> Data? {
        let provider = LPMetadataProvider()
        provider.timeout = 8
        guard let metadata = try? await provider.startFetchingMetadata(for: url),
              let imageProvider = metadata.imageProvider,
              let data = await imageProvider.loadData(of: .image) else { return nil }
        return await resized(data)
    }

    private static func resized(_ data: Data) async -> Data {
        await Task.detached { ImageTools.jpeg(from: data, maxPixelSize: 2048) ?? data }.value
    }

    private static func firstLink(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        return detector?.firstMatch(in: text, range: range)?.url
    }
}

// Callback-style NSItemProvider APIs wrapped as async. `nonisolated` matters: the callbacks
// arrive on a background thread, so they must not be tied to the main actor.
extension NSItemProvider {
    nonisolated func loadData(of type: UTType) async -> Data? {
        await withCheckedContinuation { continuation in
            _ = loadDataRepresentation(for: type) { data, _ in continuation.resume(returning: data) }
        }
    }

    nonisolated func loadURL() async -> URL? {
        await withCheckedContinuation { continuation in
            _ = loadObject(ofClass: URL.self) { url, _ in continuation.resume(returning: url) }
        }
    }

    nonisolated func loadText() async -> String? {
        await withCheckedContinuation { continuation in
            _ = loadObject(ofClass: String.self) { text, _ in continuation.resume(returning: text) }
        }
    }
}
