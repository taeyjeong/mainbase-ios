import SwiftUI
import FirebaseCore

@main
struct MainBaseApp: App {
    init() {
        FirebaseApp.configure()
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
