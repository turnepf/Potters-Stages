import SwiftData
import SwiftUI

/// Photo grid of pieces, grouped by stage.
struct PieceGrid: View {
    let filter: StageFilter
    let searchText: String

    @Query(sort: \Piece.updatedAt, order: .reverse) private var pieces: [Piece]
    @Environment(\.modelContext) private var context
    @State private var pieceToDelete: Piece?

    var body: some View {
        let sections = self.sections
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], alignment: .leading, spacing: 18) {
                ForEach(sections, id: \.stage) { section in
                    Section {
                        ForEach(section.pieces) { piece in
                            NavigationLink(value: piece) {
                                PieceCell(piece: piece)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("pieceCell")
                            .contextMenu {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    pieceToDelete = piece
                                }
                            }
                        }
                    } header: {
                        if sections.count > 1 {
                            Label {
                                Text(section.stage.name)
                            } icon: {
                                Image(systemName: section.stage.symbol)
                                    .foregroundStyle(section.stage.color)
                            }
                            .font(.headline)
                            .padding(.top, 6)
                        }
                    }
                }
            }
            .padding()
        }
        .overlay {
            if sections.isEmpty {
                if searchText.isEmpty {
                    ContentUnavailableView("No Pieces", systemImage: "square.grid.2x2",
                                           description: Text("Tap + to add a piece."))
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
        .deleteConfirmation(for: $pieceToDelete) { piece in
            context.delete(piece)
        }
    }

    /// Searching looks through every piece, whichever view you're on.
    private var sections: [(stage: Stage, pieces: [Piece])] {
        let matching = pieces.filter { (!searchText.isEmpty || filter.includes($0.stage)) && matchesSearch($0) }
        return Stage.allCases.compactMap { stage in
            let inStage = matching.filter { $0.stage == stage }
            return inStage.isEmpty ? nil : (stage, inStage)
        }
    }

    private func matchesSearch(_ piece: Piece) -> Bool {
        searchText.isEmpty
            || piece.title.localizedStandardContains(searchText)
            || piece.notes.localizedStandardContains(searchText)
    }
}

struct PieceCell: View {
    let piece: Piece

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PhotoTile(data: piece.coverPhoto?.thumbnail, stage: piece.stage, hasLink: piece.inspirationURL != nil)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 12))
            Text(piece.displayTitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(piece.title.isEmpty ? .secondary : .primary)
                .lineLimit(1)
            StageTag(stage: piece.stage)
        }
        .contentShape(.rect)
    }
}

/// A piece's photo filling its frame, or a calm placeholder when there's no photo yet.
struct PhotoTile: View {
    let data: Data?
    let stage: Stage
    var hasLink = false

    var body: some View {
        Color.clear
            .overlay {
                if let image = Image(photoData: data) {
                    image.resizable().scaledToFill()
                } else {
                    ZStack {
                        stage.color.opacity(0.12)
                        Image(systemName: hasLink ? "link" : "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .clipped()
    }
}

extension View {
    /// Asks "Delete this piece?" whenever `piece` is set, and runs `delete` on confirm.
    func deleteConfirmation(for piece: Binding<Piece?>, delete: @escaping (Piece) -> Void) -> some View {
        alert("Delete this piece?",
              isPresented: Binding(get: { piece.wrappedValue != nil }, set: { if !$0 { piece.wrappedValue = nil } }),
              presenting: piece.wrappedValue) { target in
            Button("Delete", role: .destructive) { delete(target) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("It will be removed from all your devices.")
        }
    }
}
