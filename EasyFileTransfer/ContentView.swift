import SwiftUI

struct ContentView: View {
    @State private var isShowingSettings: Bool = !isConfigured()

    var body: some View {
        if isShowingSettings {
            SettingsView(isShowingSettings: $isShowingSettings)
        } else {
            MainView(isShowingSettings: $isShowingSettings)
        }
    }
    
    static func isConfigured() -> Bool {
        let serverURL = UserDefaults.standard.string(forKey: "serverURL")
        let username = UserDefaults.standard.string(forKey: "username")
        let password = UserDefaults.standard.string(forKey: "password")
        return !(serverURL?.isEmpty ?? true) && !(username?.isEmpty ?? true) && !(password?.isEmpty ?? true)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
