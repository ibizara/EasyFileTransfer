import SwiftUI

struct SettingsView: View {
    @Binding var isShowingSettings: Bool
    @State private var serverURL: String = UserDefaults.standard.string(forKey: "serverURL") ?? ""
    @State private var username: String = UserDefaults.standard.string(forKey: "username") ?? ""
    @State private var password: String = UserDefaults.standard.string(forKey: "password") ?? ""
    @State private var isServerURLValid: Bool = true
    @State private var isServerURLSecure: Bool = true

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Server Settings")) {
                    HStack {
                        TextField("Server URL", text: $serverURL)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .onChange(of: serverURL) { _, _ in
                                validateURL()
                            }
                        
                        if !isServerURLSecure {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundColor(.red)
                                .padding(.trailing, 8)
                        }
                    }
                }
                Section(header: Text("Login Details")) {
                    TextField("Username", text: $username)
                    SecureField("Password", text: $password)
                }
                Button("Save") {
                    UserDefaults.standard.set(serverURL, forKey: "serverURL")
                    UserDefaults.standard.set(username, forKey: "username")
                    UserDefaults.standard.set(password, forKey: "password")
                    isShowingSettings = false // Dismiss the settings view after saving
                }
                .disabled(serverURL.isEmpty || username.isEmpty || password.isEmpty || !isServerURLValid)
            }
            .navigationTitle("Settings")
        }
    }

    private func validateURL() {
        isServerURLValid = isValidURL(serverURL)
        isServerURLSecure = isSecureURL(serverURL)
    }

    private func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }

    private func isSecureURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme == "https"
    }
}
