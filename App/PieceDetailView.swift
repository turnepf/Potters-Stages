import SwiftData
import SwiftUI

struct PieceDetailView: View {
    @Bindable var piece: Piece

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var isMerging = false
    @State private var pieceToDelete: Piece?
    @State private var photoToDelete: Photo?
    @State private var photoToMove: Photo?
    @State private var isShowingDuplicateNotice = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                photoStrip
                stageControls

                if let url = piece.inspirationURL, url.isWebLink {
                    // Instagram links open in the Instagram app when it's installed.
                    Link(destination: url) {
                        Label(url.host() ?? url.absoluteString, systemImage: "link")
                            .frame(minHeight: 44)
                    }
                }

                if !piece.notes.isEmpty {
                    Text(piece.notes)
                        .textSelection(.enabled)
                }

                history
            }
            .padding()
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(piece.displayTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { isEditing = true }
            }
            ToolbarItem {
                Menu("More", systemImage: "ellipsis") {
                    Button("Merge with Another Piece…", systemImage: "arrow.triangle.merge") { isMerging = true }
                    Button("Delete", systemImage: "trash", role: .destructive) { pieceToDelete = piece }
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            PieceEditor(piece: piece)
        }
        .sheet(isPresented: $isMerging) {
            PiecePickerSheet(title: "Merge Into \(piece.displayTitle)", excluding: piece) { other in
                "\(other.displayTitle)'s photos and notes will move into \(piece.displayTitle), and \(other.displayTitle) will be removed."
            } onPick: { other in
                piece.absorb(other)
                context.delete(other)
            }
        }
        .sheet(item: $photoToMove) { photo in
            PiecePickerSheet(title: "Move Photo To…", excluding: piece) { target in
                target.takePhoto(photo)
            }
        }
        .deleteConfirmation(for: $pieceToDelete) { piece in
            dismiss()
            context.delete(piece)
        }
        .alert("Already Added", isPresented: $isShowingDuplicateNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("That photo is already on this piece, so it wasn't added again.")
        }
        .alert("Delete this photo?", isPresented: Binding(get: { photoToDelete != nil },
                                                          set: { if !$0 { photoToDelete = nil } })) {
            Button("Delete", role: .destructive) {
                if let photoToDelete { context.delete(photoToDelete) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    /// All photos side by side, newest on the right (shown first). Swipe to see earlier stages.
    private var photoStrip: some View {
        VStack(spacing: 12) {
            let photos = piece.sortedPhotos
            if photos.isEmpty {
                PhotoTile(data: nil, stage: piece.stage, hasLink: piece.inspirationURL != nil)
                    .frame(height: 220)
                    .clipShape(.rect(cornerRadius: 16))
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 12) {
                        ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                            PhotoPage(photo: photo, position: photos.count > 1 ? "\(index + 1) of \(photos.count)" : nil)
                                .containerRelativeFrame(.horizontal)
                                .contextMenu { photoMenu(for: photo) }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollIndicators(photos.count > 1 ? .visible : .hidden)
                .defaultScrollAnchor(.trailing)
            }

            // New photos are tagged with the piece's current stage.
            HStack(spacing: 20) {
                PhotoButtons { data in
                    if !piece.addPhoto(data, stage: piece.stage) {
                        isShowingDuplicateNotice = true
                    }
                }
            }
            .buttonStyle(.bordered)
        }
    }

    /// Long-press menu on a photo: its stage, moving it (to undo a merge), deleting it.
    @ViewBuilder
    private func photoMenu(for photo: Photo) -> some View {
        Picker("Stage", systemImage: photo.stage.symbol, selection: Binding(
            get: { photo.stage },
            set: { piece.setStage($0, of: photo) }
        )) {
            ForEach(Stage.allCases) { stage in
                Label(stage.name, systemImage: stage.symbol).tag(stage)
            }
        }
        .pickerStyle(.menu)

        Button("Move to New Piece", systemImage: "rectangle.badge.plus") {
            let newPiece = Piece(stage: photo.stage)
            context.insert(newPiece)
            newPiece.takePhoto(photo)
        }
        Button("Move to Another Piece…", systemImage: "arrow.right.square") {
            photoToMove = photo
        }
        Button("Delete Photo", systemImage: "trash", role: .destructive) {
            photoToDelete = photo
        }
    }

    private var stageControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Stage")
                    .font(.headline)
                Spacer()
                Picker("Stage", selection: $piece.stage) {
                    ForEach(Stage.allCases) { stage in
                        Label(stage.name, systemImage: stage.symbol).tag(stage)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
            }

            Text(piece.stage.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let next = piece.stage.next {
                Button {
                    withAnimation { piece.stage = next }
                } label: {
                    Label("Advance to \(next.name)", systemImage: "arrow.right.circle.fill")
                        .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("History")
                .font(.headline)
            ForEach(Stage.allCases) { stage in
                if let date = piece.reachedDate(for: stage) {
                    HStack {
                        Circle().fill(stage.color).frame(width: 8, height: 8)
                        Text(stage.name)
                        Spacer()
                        Text(date, format: .dateTime.month().day().year())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Text("Updated \(piece.updatedAt, format: .relative(presentation: .named))")
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .font(.subheadline)
    }
}

/// One photo in the detail strip, captioned with its stage and date.
private struct PhotoPage: View {
    let photo: Photo
    /// "2 of 3" when the piece has several photos.
    let position: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image = Image(photoData: photo.imageData) {
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 480)
                    .clipShape(.rect(cornerRadius: 16))
                    .accessibilityIdentifier("piecePhoto")
            }
            HStack {
                StageTag(stage: photo.stage)
                if let position {
                    Text(position)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(photo.addedAt, format: .dateTime.month().day().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
