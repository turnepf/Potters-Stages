import SwiftUI

/// The share sheet: a preview, new-or-existing piece, stage, and Save.
struct ShareView: View {
    @Bindable var model: ShareModel

    var body: some View {
        #if os(iOS)
        NavigationStack {
            form
                .navigationTitle("Potter's Stages")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: model.cancel)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", action: model.save).disabled(!model.canSave || model.didSave)
                    }
                }
        }
        .overlay { if model.didSave { savedBadge } }
        #else
        VStack(spacing: 0) {
            form
            HStack {
                Spacer()
                Button("Cancel", action: model.cancel).keyboardShortcut(.cancelAction)
                Button("Save", action: model.save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.canSave || model.didSave)
            }
            .padding()
        }
        .frame(minHeight: 560)
        .overlay { if model.didSave { savedBadge } }
        #endif
    }

    private var form: some View {
        Form {
            Section {
                preview
                if let url = model.url {
                    Label(url.host() ?? url.absoluteString, systemImage: "link")
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Picker("Save to", selection: $model.addToExisting) {
                    Text("New Piece").tag(false)
                    Text("Existing Piece").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if model.addToExisting {
                    piecePicker
                } else {
                    TextField("Title (optional)", text: $model.title)
                }
                TextField("Note (optional)", text: $model.notes, axis: .vertical)
                    .lineLimit(2...5)
            }

            StagePickerSection(stage: $model.stage)
        }
        .formStyle(.grouped)
    }

    /// A row of piece thumbnails to tap; in-progress pieces come first.
    @ViewBuilder
    private var piecePicker: some View {
        if model.pieces.isEmpty {
            Text("No pieces yet.")
                .foregroundStyle(.secondary)
        } else {
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(model.pieces) { piece in
                        let isSelected = model.existingPiece == piece
                        Button {
                            model.existingPiece = piece
                        } label: {
                            VStack(spacing: 4) {
                                PieceThumbnail(piece: piece)
                                    .frame(width: 84, height: 84)
                                    .clipShape(.rect(cornerRadius: 10))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 3)
                                    }
                                Text(piece.displayTitle)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .frame(width: 84)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let image = Image(photoData: model.imageData) {
            image
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 200)
                .clipShape(.rect(cornerRadius: 12))
        } else if model.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 100)
        } else if model.url != nil {
            ContentUnavailableView("No Preview", systemImage: "link",
                                   description: Text("You can add a photo later."))
        } else {
            ContentUnavailableView("Nothing to Save", systemImage: "questionmark.square.dashed",
                                   description: Text("Share a link or a photo."))
        }
    }

    private var savedBadge: some View {
        VStack(spacing: 6) {
            Label("Saved", systemImage: "checkmark.circle.fill")
                .font(.title2.weight(.semibold))
            if model.photoWasAlreadyThere {
                Text("That photo was already on this piece.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
            .background(.regularMaterial, in: .rect(cornerRadius: 16))
            .transition(.scale.combined(with: .opacity))
    }
}

/// A piece's newest photo, or its stage color with a symbol.
private struct PieceThumbnail: View {
    let piece: Piece

    var body: some View {
        Color.clear.overlay {
            if let image = Image(photoData: piece.coverPhoto?.thumbnail) {
                image.resizable().scaledToFill()
            } else {
                ZStack {
                    piece.stage.color.opacity(0.15)
                    Image(systemName: piece.inspirationURL != nil ? "link" : "photo")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .clipped()
    }
}
