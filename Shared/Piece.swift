import Foundation
import SwiftData

/// One pottery piece. Every stored property is optional or has a default,
/// and the relationship is optional, which CloudKit sync requires.
@Model
final class Piece {
    var title: String = ""
    var notes: String = ""
    var inspirationURL: URL?
    /// Stored as a String so it syncs and filters reliably; use `stage` in code.
    var stageRaw: String = Stage.idea.rawValue

    /// All photos of this piece, each tagged with the stage it was taken at.
    @Relationship(deleteRule: .cascade, inverse: \Photo.piece)
    var photos: [Photo]? = []

    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    // When each stage was reached (simple history, shown on the detail screen).
    var ideaAt: Date?
    var leatherHardAt: Date?
    var greenwareAt: Date?
    var bisquewareAt: Date?
    var finishedAt: Date?

    init(title: String = "", notes: String = "", inspirationURL: URL? = nil, stage: Stage = .idea) {
        self.title = title
        self.notes = notes
        self.inspirationURL = inspirationURL
        self.stageRaw = stage.rawValue
        setReachedDate(.now, for: stage)
    }

    var stage: Stage {
        get { Stage(rawValue: stageRaw) ?? .idea }
        set {
            guard newValue != stage else { return }
            stageRaw = newValue.rawValue
            setReachedDate(.now, for: newValue)
            // Moving a piece back clears the dates of the stages after it.
            for later in Stage.allCases where later.order > newValue.order {
                setReachedDate(nil, for: later)
            }
            updatedAt = .now
        }
    }

    var displayTitle: String {
        title.isEmpty ? "Untitled" : title
    }

    /// Photos in stage order (Idea first), then oldest to newest within a stage.
    var sortedPhotos: [Photo] {
        (photos ?? []).sorted { ($0.stage.order, $0.addedAt) < ($1.stage.order, $1.addedAt) }
    }

    /// The main photo: the newest one taken at the piece's current stage, or the
    /// furthest-along one before that.
    var coverPhoto: Photo? {
        sortedPhotos.last { $0.stage.order <= stage.order } ?? sortedPhotos.last
    }

    /// Adds a photo from any image data (HEIC, PNG, JPEG…), tagged with a stage.
    /// Returns false, and adds nothing, if this piece already has the same photo.
    @discardableResult
    func addPhoto(_ data: Data, stage: Stage, addedAt: Date = .now) -> Bool {
        let photo = Photo(data: data, stage: stage, addedAt: addedAt)
        if let fingerprint = photo.fingerprint,
           (photos ?? []).contains(where: { $0.looksLike(fingerprint) }) {
            return false
        }
        if photos == nil { photos = [] }
        photos?.append(photo)
        catchUp(to: stage)
        updatedAt = .now
        return true
    }

    /// Re-tags a photo with the stage it was taken at.
    func setStage(_ newStage: Stage, of photo: Photo) {
        photo.stage = newStage
        catchUp(to: newStage)
        updatedAt = .now
    }

    /// Moves a photo from another piece into this one.
    func takePhoto(_ photo: Photo) {
        let source = photo.piece
        photo.piece = self
        catchUp(to: photo.stage)
        source?.settleAfterPhotoMovedOut()
        updatedAt = .now
    }

    /// After a photo moves out (e.g. undoing a wrong merge), drop back to the furthest
    /// stage among the photos that are left.
    private func settleAfterPhotoMovedOut() {
        let remaining = (photos ?? []).map(\.stage)
        if let furthest = remaining.max(by: { $0.order < $1.order }), furthest.order < stage.order {
            stage = furthest
        }
        updatedAt = .now
    }

    /// A piece is always at least as far along as its furthest photo.
    private func catchUp(to photoStage: Stage) {
        if photoStage.order > stage.order {
            stage = photoStage
        }
    }

    /// Moves everything from `other` into this piece: photos, notes, link, the further-along
    /// stage and the earliest dates. The caller then deletes `other`.
    func absorb(_ other: Piece) {
        for photo in other.photos ?? [] {
            photo.piece = self
        }
        if title.isEmpty {
            title = other.title
        }
        var otherNotes = other.notes
        if let otherURL = other.inspirationURL {
            if inspirationURL == nil {
                inspirationURL = otherURL
            } else if otherURL != inspirationURL {
                otherNotes += (otherNotes.isEmpty ? "" : "\n") + otherURL.absoluteString
            }
        }
        notes = [notes, otherNotes].filter { !$0.isEmpty }.joined(separator: "\n\n")
        if other.stage.order > stage.order {
            stageRaw = other.stageRaw  // set directly so the history isn't restamped
        }
        for stage in Stage.allCases {
            let dates = [reachedDate(for: stage), other.reachedDate(for: stage)].compactMap { $0 }
            setReachedDate(dates.min(), for: stage)
        }
        createdAt = min(createdAt, other.createdAt)
        updatedAt = .now
    }

    func reachedDate(for stage: Stage) -> Date? {
        switch stage {
        case .idea: ideaAt
        case .leatherHard: leatherHardAt
        case .greenware: greenwareAt
        case .bisqueware: bisquewareAt
        case .finished: finishedAt
        }
    }

    func setReachedDate(_ date: Date?, for stage: Stage) {
        switch stage {
        case .idea: ideaAt = date
        case .leatherHard: leatherHardAt = date
        case .greenware: greenwareAt = date
        case .bisqueware: bisquewareAt = date
        case .finished: finishedAt = date
        }
    }
}

/// One photo of a piece.
@Model
final class Photo {
    /// JPEG, longest side ≤ 2048 px. Kept outside the database file.
    @Attribute(.externalStorage) var imageData: Data?
    /// Small copy for grids and pickers.
    @Attribute(.externalStorage) var thumbnail: Data?
    var stageRaw: String = Stage.idea.rawValue
    var addedAt: Date = Date.now
    /// Visual fingerprint used to spot the same photo being added twice.
    var fingerprint: String?
    var piece: Piece?

    init(data: Data, stage: Stage, addedAt: Date = .now) {
        self.imageData = ImageTools.jpeg(from: data, maxPixelSize: 2048) ?? data
        self.thumbnail = ImageTools.jpeg(from: data, maxPixelSize: 600)
        self.stageRaw = stage.rawValue
        self.addedAt = addedAt
        self.fingerprint = thumbnail.flatMap(ImageTools.fingerprint(from:))
    }

    /// Restores a photo exactly as it was saved (used by backup import), without re-encoding.
    init(imageData: Data?, thumbnail: Data?, stageRaw: String, addedAt: Date, fingerprint: String?) {
        self.imageData = imageData
        self.thumbnail = thumbnail
        self.stageRaw = stageRaw
        self.addedAt = addedAt
        self.fingerprint = fingerprint
    }

    /// Whether this is the same picture as `otherFingerprint`. Photos saved before
    /// fingerprints existed get one worked out (and kept) the first time they're compared.
    func looksLike(_ otherFingerprint: String) -> Bool {
        if fingerprint == nil, let thumbnail {
            fingerprint = ImageTools.fingerprint(from: thumbnail)
        }
        guard let fingerprint else { return false }
        return ImageTools.isSamePhoto(fingerprint, otherFingerprint)
    }

    var stage: Stage {
        get { Stage(rawValue: stageRaw) ?? .idea }
        set { stageRaw = newValue.rawValue }
    }
}

extension URL {
    /// True for http and https links, the only kind the app saves or opens. Anything else
    /// (file://, shortcuts://, tel:…) could open a local file or another app when tapped.
    var isWebLink: Bool {
        ["http", "https"].contains(scheme?.lowercased()) && host() != nil
    }

    /// Turns what someone typed ("instagram.com/p/abc") into a usable web link, or nil.
    static func fromUserInput(_ text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let withScheme = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let url = URL(string: withScheme), url.isWebLink else { return nil }
        return url
    }

    /// The first web link in some text (some apps share a link inside plain text), or nil.
    static func firstWebLink(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        return detector?.matches(in: text, range: range).lazy.compactMap(\.url).first(where: \.isWebLink)
    }
}
