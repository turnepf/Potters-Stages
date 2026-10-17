import PhotosUI
import SwiftUI

/// "Choose Photo" (Photos library) and, on iPhone/iPad, "Take Photo" (camera).
/// Calls `onPick` with the image data, already resized to a sensible size.
struct PhotoButtons: View {
    var onPick: (Data) -> Void

    @State private var pickerItem: PhotosPickerItem?
    @State private var isShowingCamera = false

    var body: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            Label("Choose Photo", systemImage: "photo.on.rectangle")
                .frame(minHeight: 32)
        }
        .onChange(of: pickerItem) {
            guard let item = pickerItem else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    onPick(await resized(data))
                }
                pickerItem = nil
            }
        }

        #if os(iOS)
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            Button {
                isShowingCamera = true
            } label: {
                Label("Take Photo", systemImage: "camera")
                    .frame(minHeight: 32)
            }
            .fullScreenCover(isPresented: $isShowingCamera) {
                CameraView { data in
                    Task { onPick(await resized(data)) }
                }
                .ignoresSafeArea()
            }
        }
        #endif
    }

    /// Shrinks big camera photos off the main thread so the UI stays smooth.
    private func resized(_ data: Data) async -> Data {
        await Task.detached { ImageTools.jpeg(from: data, maxPixelSize: 2048) ?? data }.value
    }
}

#if os(iOS)
/// The system camera, wrapped for SwiftUI.
struct CameraView: UIViewControllerRepresentable {
    var onCapture: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        init(_ parent: CameraView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 0.9) {
                parent.onCapture(data)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
#endif
