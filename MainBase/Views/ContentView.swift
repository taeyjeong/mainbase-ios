import SwiftUI
import FirebaseMessaging

struct ContentView: View {
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var notificationVM = NotificationViewModel()
    @StateObject private var trackerVM = TimeTrackerViewModel()

    @State private var selectedTab: AppTab = .clockIn
    @State private var didSetInitialTab = false
    @AppStorage("appearancePreference") private var appearancePreference = AppearancePreference.system.rawValue

    var body: some View {
        Group {
            if authVM.isSignedIn {
                TabView(selection: $selectedTab) {
                    TimeTrackerView(onClockIn: { selectedTab = .projects })
                        .environmentObject(notificationVM)
                        .environmentObject(authVM)
                        .environmentObject(trackerVM)
                        .tabItem { Label("Clock In", systemImage: "clock") }
                        .tag(AppTab.clockIn)

                    ProjectsListView()
                        .tabItem { Label("Projects", systemImage: "folder.fill") }
                        .tag(AppTab.projects)

                    OperationsDiagramsView()
                        .tabItem { Label("Operations", systemImage: "map.fill") }
                        .tag(AppTab.operations)
                }
                .onChange(of: trackerVM.isClockedIn) { _, isClockedIn in
                    guard !didSetInitialTab else { return }
                    didSetInitialTab = true
                    if isClockedIn { selectedTab = .projects }
                }
            } else {
                NavigationStack {
                    SignInView()
                }
                .environmentObject(authVM)
            }
        }
        .preferredColorScheme((AppearancePreference(rawValue: appearancePreference) ?? .system).colorScheme)
        .onChange(of: authVM.currentUserId) { _, userId in
            if let userId {
                notificationVM.configure(userId: userId)
                trackerVM.configure()
                if let token = Messaging.messaging().fcmToken {
                    PushNotificationService.saveFCMToken(token)
                }
            } else {
                notificationVM.stopListening()
                trackerVM.stopListening()
                didSetInitialTab = false
                selectedTab = .clockIn
            }
        }
    }
}

#Preview {
    ContentView()
}
