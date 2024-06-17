import Foundation

class DownloadManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    @Published var downloadProgress: Double = 0
    @Published var temporaryFileURL: URL?
    @Published var downloadFileName: String?
    private var session: URLSession!
    private var expectedFileSizeBytes: Int64 = 0

    override init() {
        super.init()
        let configuration = URLSessionConfiguration.default
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue())
    }

    func startDownload(url: URL, fileName: String, expectedFileSizeKB: Double) {
        self.downloadFileName = fileName
        self.temporaryFileURL = nil
        self.downloadProgress = 0
        self.expectedFileSizeBytes = Int64(expectedFileSizeKB * 1024) // Convert KB to bytes
        print("Starting download: \(fileName), expected size: \(expectedFileSizeBytes) bytes")
        let downloadTask = session.downloadTask(with: url)
        downloadTask.resume()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            let tempDir = FileManager.default.temporaryDirectory
            let tempURL = tempDir.appendingPathComponent(downloadFileName ?? "downloaded_file")
            
            // Remove existing file if it exists
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            
            try FileManager.default.moveItem(at: location, to: tempURL)
            DispatchQueue.main.async {
                self.temporaryFileURL = tempURL
                self.downloadProgress = 1.0
                print("Download finished: \(tempURL)")
            }
        } catch {
            print("Error moving downloaded file: \(error.localizedDescription)")
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let totalBytes = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : expectedFileSizeBytes
        guard totalBytes > 0 else {
            print("Total bytes expected to write is unknown.")
            return
        }
        
        let progress = Double(totalBytesWritten) / Double(totalBytes)
        DispatchQueue.main.async {
            self.downloadProgress = max(0, min(progress, 1)) // Clamp the progress value between 0 and 1
            print("Download progress: \(self.downloadProgress * 100)%")
        }
    }
}
