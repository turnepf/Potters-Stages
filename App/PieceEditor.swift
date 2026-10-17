import SwiftData
import SwiftUI

/// Add a new piece (piece == nil) or edit an existing one.
struct PieceEditor: View {
    let piece: Piece?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var link: String
    @State private var notes: String
    @State private var stage: Stage
    @State private var photoData: Data?

    init(piece: Piece?) {
        self.piece = piece
        _title = State(initialValue: piece?.title ?? "")
        _link = State(initialValue: piece?.inspirationURL?.absoluteString ?? "")
        _notes = State(initialValue: piece?.notes ?? "")
        _stage = State(initialValue: piece?.stage ?? .idea)
    }

    private var linkIsValid: Bool {
        link.trimmingCharacters(in: .whitespaces).isEmpty || URL.fromUserInput(link) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                // Photos of an existing piece are managed on its detail screen.
                if piece == nil {
                    Section {
                        if let image = Image(photoData: photoData) {
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: 260)
                                .clipShape(.rect(cornerRadius: 12))
                        }
                        PhotoButtons { data in photoData = data }
                        if photoData != nil {
                            Button("Remove Photo", systemImage: "trash", role: .destructive) {
                                photoData = nil
                            }
                        }
                    }
                }

                Section {
                    TextField("Title", text: $title)
                    TextField("Inspiration link", text: $link)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        #endif
                } footer: {
                    if !linkIsValid {
                        Text("That doesn't look like a web link.")
                            .foregroundStyle(.red)
                    }
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...12)
                }

                StagePickerSection(stage: $stage)
            }
            .formStyle(.grouped)
            .navigationTitle(piece == nil ? "New Piece" : "Edit Piece")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!linkIsValid)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 440, minHeight: 560)
        #endif
    }

    private func save() {
        let target: Piece
        if let piece {
            target = piece
        } else {
            target = Piece()
            context.insert(target)
        }
        target.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        target.inspirationURL = URL.fromUserInput(link)
        target.stage = stage
        if let photoData {
            target.addPhoto(photoData, stage: stage)
        }
        target.updatedAt = .now
        dismiss()
    }
}
