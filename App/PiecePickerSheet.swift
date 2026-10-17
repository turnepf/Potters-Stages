import SwiftData
import SwiftUI

/// A searchable grid of pieces to choose from (used by Merge and Move Photo).
struct PiecePickerSheet: View {
    let title: String
    /// The piece you came from; it isn't offered.
    let excluding: Piece
    /// When set, asks "Are you sure?" with this message before calling onPick.
    var confirmation: ((Piece) -> String)? = nil
    let onPick: (Piece) -> Void

    @Query(sort: \Piece.updatedAt, order: .reverse) private var pieces: [Piece]
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var pendingPick: Piece?

    /// Every other piece matching the search, grouped In Progress, then Done, then Ideas.
    private var sections: [(group: StageFilter, pieces: [Piece])] {
        let matching = pieces
            .filter { $0 != excluding }
            .filter { searchText.isEmpty
                || $0.title.localizedStandardContains(searchText)
                || $0.notes.localizedStandardContains(searchText) }
        return [StageFilter.inProgress, .done, .ideas].compactMap { group in
            let inGroup = matching
                .filter { group.includes($0.stage) }
                .sorted { $0.stage.order < $1.stage.order }
            return inGroup.isEmpty ? nil : (group, inGroup)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 14)], alignment: .leading, spacing: 18) {
                    ForEach(sections, id: \.group) { section in
                        Section {
                            ForEach(section.pieces) { piece in
                                Button {
                                    if confirmation == nil { pick(piece) } else { pendingPick = piece }
                                } label: {
                                    PieceCell(piece: piece)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("pickerCandidate")
                            }
                        } header: {
                            Label {
                                Text(section.group.name)
                            } icon: {
                                Image(systemName: section.group.symbol)
                                    .foregroundStyle(section.group.color)
                            }
                            .font(.headline)
                            .padding(.top, 6)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $searchText, prompt: "Search titles and notes")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Are you sure?",
                   isPresented: Binding(get: { pendingPick != nil }, set: { if !$0 { pendingPick = nil } }),
                   presenting: pendingPick) { piece in
                Button("Continue") { pick(piece) }
                Button("Cancel", role: .cancel) {}
            } message: { piece in
                Text(confirmation?(piece) ?? "")
            }
        }
        #if os(macOS)
        .frame(minWidth: 560, minHeight: 520)
        #endif
    }

    private func pick(_ piece: Piece) {
        onPick(piece)
        dismiss()
    }
}
