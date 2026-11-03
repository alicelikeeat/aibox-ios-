import SwiftUI
import PhotosUI

struct MediaPhotoPicker: UIViewControllerRepresentable {
    let kind: LocalMediaImport.Kind
    let onPick: (NSItemProvider) -> Void
    let onDismiss: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 1
        configuration.filter = kind == .video ? .videos : .images
        configuration.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: PHPickerViewController, context: Context) {}
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: MediaPhotoPicker
        init(parent: MediaPhotoPicker) { self.parent = parent }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.onDismiss()
            if let provider = results.first?.itemProvider { parent.onPick(provider) }
        }
    }
}
