import SwiftUI
import PhotosUI
import UIKit

struct SelectedImage {
    let image: UIImage
    let filename: String
    
    var imageData: Data? {
        if let imageData = image.pngData() {
            return imageData
        }
        return image.jpegData(compressionQuality: 1.0)
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImages: [SelectedImage]
    @Environment(\.presentationMode) private var presentationMode

    class Coordinator: NSObject, UINavigationControllerDelegate, PHPickerViewControllerDelegate {
        var parent: ImagePicker

        init(parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            for result in results {
                result.itemProvider.loadObject(ofClass: UIImage.self) { (object, error) in
                    if let error = error {
                        print("Error loading image: \(error.localizedDescription)")
                    } else if let image = object as? UIImage {
                        let filename = result.itemProvider.suggestedName ?? "image.jpg"
                        let fileExtension = filename.contains(".") ? filename : "\(filename).jpg"
                        let selectedImage = SelectedImage(image: image, filename: fileExtension)
                        DispatchQueue.main.async {
                            self.parent.selectedImages.append(selectedImage)
                        }
                    }
                }
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 0 // Allow multiple selection
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
}
