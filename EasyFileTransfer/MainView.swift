import SwiftUI
import UniformTypeIdentifiers

struct FileDetails: Identifiable, Codable {
    var id: UUID { UUID() }
    var name: String
    var size: String
    var lastModified: String
    
    var sizeInKB: Double {
        return Double(size.replacingOccurrences(of: ",", with: "")) ?? 0.0
    }
}

struct MainView: View {
    @Binding var isShowingSettings: Bool
    @StateObject private var downloadManager = DownloadManager()
    @State private var files: [FileDetails] = []
    @State private var isFilePickerPresented: Bool = false
    @State private var isPhotoPickerPresented: Bool = false
    @State private var isShowingDocumentPicker = false
    @State private var isLoggedIn: Bool = false
    @State private var loginError: String?
    @State private var uploadProgress: Double = 0
    @State private var observations: [NSKeyValueObservation] = []
    @State private var selectedImages: [SelectedImage] = []

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isLoggedIn {
                    List {
                        ForEach(files) { file in
                            HStack {
                                Text(file.name)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                startDownload(file)
                            }
                            .contextMenu {
                                Text("Size: \(file.size) KB")
                                Text("Last Modified: \(file.lastModified)")
                            }
                        }
                        .onDelete(perform: deleteFiles)
                    }
                    .listStyle(InsetGroupedListStyle())
                    .padding(.top, -30) // Reduce the space above the list

                    HStack {
                        Button(action: {
                            isFilePickerPresented = true
                        }) {
                            HStack {
                                Image(systemName: "doc.fill")
                                Text("Upload Files")
                            }
                        }
                        .buttonStyle(UploadButtonStyle())

                        Button(action: {
                            isPhotoPickerPresented = true
                        }) {
                            HStack {
                                Image(systemName: "photo.fill")
                                Text("Upload Photos")
                            }
                        }
                        .buttonStyle(UploadButtonStyle())
                    }
                    .frame(maxWidth: .infinity) // Set the width to 100%
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground)) // Set the background color

                    if uploadProgress > 0 {
                        ProgressView(value: uploadProgress, total: 1.0)
                            .padding()
                    }
                } else if let loginError = loginError {
                    VStack {
                        Text("Login Failed")
                            .foregroundColor(.red)
                        Text(loginError)
                            .foregroundColor(.red)
                            .padding()
                        Button("Go to Settings") {
                            isShowingSettings = true
                        }
                        .padding()
                    }
                } else {
                    Text("Logging in...")
                        .onAppear(perform: login)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Files")
            .toolbar {
                if isLoggedIn {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { isShowingSettings = true }) {
                            Image(systemName: "gear")
                        }
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $isFilePickerPresented,
            allowedContentTypes: [UTType.data],
            allowsMultipleSelection: true,
            onCompletion: { result in
                do {
                    let selectedFiles = try result.get()
                    uploadFiles(selectedFiles)
                } catch {
                    print("Error selecting files: \(error.localizedDescription)")
                }
            }
        )
        .sheet(isPresented: $isPhotoPickerPresented, onDismiss: {
            uploadPhotos()
            selectedImages.removeAll()  // Clear the selected images when the picker is dismissed
        }) {
            ImagePicker(selectedImages: $selectedImages)
        }
        .sheet(isPresented: $isShowingDocumentPicker) {
            VStack {
                if downloadManager.downloadProgress < 1.0 {
                    ProgressView(value: downloadManager.downloadProgress, total: 1.0)
                        .padding()
                } else {
                    if let fileURL = downloadManager.temporaryFileURL, let fileName = downloadManager.downloadFileName {
                        DocumentPickerView(fileURL: fileURL, fileName: fileName)
                    } else {
                        Text("Download in progress or failed. Please try again.")
                            .padding()
                    }
                }
            }
            .onAppear {
                print("Showing Document Picker with progress: \(downloadManager.downloadProgress * 100)%")
            }
            .onChange(of: downloadManager.downloadProgress) {
                if downloadManager.downloadProgress >= 1.0 {
                    self.isShowingDocumentPicker = true
                }
            }
        }
    }

    func login() {
        guard let urlString = UserDefaults.standard.string(forKey: "serverURL"), let url = URL(string: urlString) else {
            print("Error: Missing server URL.")
            loginError = "Missing server URL."
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        if let username = UserDefaults.standard.string(forKey: "username"), let password = UserDefaults.standard.string(forKey: "password") {
            let bodyString = "username=\(username)&password=\(password)"
            request.httpBody = bodyString.data(using: .utf8)
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        } else {
            print("Error: Missing username or password.")
            loginError = "Missing username or password."
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error logging in: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.loginError = error.localizedDescription
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("Login failed with response: \(String(describing: response))")
                DispatchQueue.main.async {
                    self.loginError = "Login failed. Please check your settings."
                }
                return
            }
            
            if httpResponse.statusCode == 401 {
                if let data = data, let responseDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], let message = responseDict["message"] as? String {
                    DispatchQueue.main.async {
                        self.loginError = message
                    }
                } else {
                    DispatchQueue.main.async {
                        self.loginError = "Invalid username or password."
                    }
                }
                return
            }
            
            if httpResponse.statusCode != 200 {
                DispatchQueue.main.async {
                    self.loginError = "Login failed with response code \(httpResponse.statusCode)."
                    self.isLoggedIn = false
                }
                return
            }
            
            DispatchQueue.main.async {
                self.isLoggedIn = true
                self.loginError = nil
                self.fetchFiles() // Fetch files after login
            }
        }.resume()
    }

    func fetchFiles() {
        guard let urlString = UserDefaults.standard.string(forKey: "serverURL"), let url = URL(string: urlString) else {
            print("Error: Missing server URL.")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error fetching files: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.loginError = error.localizedDescription
                    self.isLoggedIn = false
                }
                return
            }
            
            guard let data = data else {
                print("Error: No data received.")
                DispatchQueue.main.async {
                    self.loginError = "No data received."
                    self.isLoggedIn = false
                }
                return
            }
            
            do {
                let jsonString = String(data: data, encoding: .utf8) ?? "No data"
                print("Received JSON: \(jsonString)")
                if let fileList = try? JSONDecoder().decode([FileDetails].self, from: data) {
                    DispatchQueue.main.async {
                        self.files = fileList
                    }
                } else {
                    throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format."])
                }
            } catch {
                print("Error parsing file list: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.loginError = "Error parsing file list: \(error.localizedDescription)"
                    self.isLoggedIn = false
                }
            }
        }.resume()
    }

    func uploadFiles(_ selectedFiles: [URL]) {
        guard let urlString = UserDefaults.standard.string(forKey: "serverURL"), let url = URL(string: urlString) else { return }
        
        uploadProgress = 0
        observations.removeAll()

        for file in selectedFiles {
            guard file.startAccessingSecurityScopedResource() else {
                print("Unable to access security scoped resource.")
                continue
            }
            
            defer {
                file.stopAccessingSecurityScopedResource()
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            let boundary = UUID().uuidString
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            var body = Data()
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"files[]\"; filename=\"\(file.lastPathComponent)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
            
            do {
                let fileData = try Data(contentsOf: file)
                body.append(fileData)
            } catch {
                print("Error reading file data: \(error.localizedDescription)")
                continue
            }
            
            body.append("\r\n".data(using: .utf8)!)
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            let task = URLSession.shared.uploadTask(with: request, from: body) { data, response, error in
                if let error = error {
                    print("Error uploading file: \(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    print("Upload failed with response: \(String(describing: response))")
                    return
                }
                
                DispatchQueue.main.async {
                    self.fetchFiles() // Refresh the file list after upload
                }
            }
            
            let observation = task.observe(\.countOfBytesSent) { task, _ in
                DispatchQueue.main.async {
                    self.uploadProgress = Double(task.countOfBytesSent) / Double(task.countOfBytesExpectedToSend)
                    if task.countOfBytesSent >= task.countOfBytesExpectedToSend {
                        self.uploadProgress = 0
                    }
                }
            }

            observations.append(observation)
            task.resume()
        }
    }

    func startDownload(_ file: FileDetails) {
        guard let urlString = UserDefaults.standard.string(forKey: "serverURL"), let url = URL(string: "\(urlString)?download=\(file.name)&uuid=\(UUID().uuidString)") else { return }
        let fileSizeKB = file.sizeInKB
        print("Starting download for \(file.name) with expected file size: \(fileSizeKB) KB")
        downloadManager.startDownload(url: url, fileName: file.name, expectedFileSizeKB: fileSizeKB)
        DispatchQueue.main.async {
            self.isShowingDocumentPicker = true
        }
    }

    func uploadPhotos() {
        guard let urlString = UserDefaults.standard.string(forKey: "serverURL"), let url = URL(string: urlString) else { return }
        
        uploadProgress = 0
        observations.removeAll()

        for selectedImage in selectedImages {
            guard let imageData = selectedImage.imageData else {
                print("Error getting image data.")
                continue
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            let boundary = UUID().uuidString
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            var body = Data()
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"files[]\"; filename=\"\(selectedImage.filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            let task = URLSession.shared.uploadTask(with: request, from: body) { data, response, error in
                if let error = error {
                    print("Error uploading photo: \(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    print("Upload failed with response: \(String(describing: response))")
                    return
                }
                
                DispatchQueue.main.async {
                    self.fetchFiles() // Refresh the file list after upload
                }
            }
            
            let observation = task.observe(\.countOfBytesSent) { task, _ in
                DispatchQueue.main.async {
                    self.uploadProgress = Double(task.countOfBytesSent) / Double(task.countOfBytesExpectedToSend)
                    if task.countOfBytesSent >= task.countOfBytesExpectedToSend {
                        self.uploadProgress = 0
                    }
                }
            }

            observations.append(observation)
            task.resume()
        }
    }

    func deleteFiles(at offsets: IndexSet) {
        for index in offsets {
            let fileName = files[index].name
            deleteFile(fileName)
        }
    }

    func deleteFile(_ fileName: String) {
        guard let urlString = UserDefaults.standard.string(forKey: "serverURL"), let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyString = "delete=\(fileName)"
        request.httpBody = bodyString.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error deleting file: \(error.localizedDescription)")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("Delete failed with response: \(String(describing: response))")
                return
            }

            guard let data = data else {
                print("Error: No data received.")
                return
            }

            do {
                if let responseDict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], responseDict["status"] as? String == "success" {
                    DispatchQueue.main.async {
                        self.files.removeAll { $0.name == fileName }
                    }
                } else {
                    print("Error: File deletion failed.")
                }
            } catch {
                print("Error parsing delete response: \(error.localizedDescription)")
            }
        }.resume()
    }
}

struct UploadButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(Color(UIColor.systemBlue))
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}
