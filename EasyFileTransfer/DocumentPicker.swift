import SwiftUI
import UIKit

struct DocumentPickerView: UIViewControllerRepresentable {
    var fileURL: URL
    var fileName: String
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [fileURL], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPickerView

        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            // Document was picked and saved
            print("Document saved to: \(urls.first?.path ?? "")")
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // Handle cancellation
            print("Document picker was cancelled.")
        }
    }
}
