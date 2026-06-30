import SwiftUI

struct ContentView: View {
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var notificationVM = NotificationViewModel()
    @StateObject private var trackerVM = TimeTrackerViewModel()

    @State private var selectedTab: AppTab = .clockIn
    @State private var didSetInitialTab = false

    var body: some View {
        Group {
            if authVM.isSignedIn {
                TabView(selection: $selectedTab) {
                    TimeTrackerView(onClockIn: { selectedTab = .reports })
                        .environmentObject(notificationVM)
                        .environmentObject(authVM)
                        .environmentObject(trackerVM)
                        .tabItem { Label("Clock In", systemImage: "clock") }
                        .tag(AppTab.clockIn)

                    ReportsListView()
                        .environmentObject(authVM)
                        .tabItem { Label("Reports", systemImage: "doc.text.fill") }
                        .tag(AppTab.reports)
                }
                .onChange(of: trackerVM.isClockedIn) { _, isClockedIn in
                    guard !didSetInitialTab else { return }
                    didSetInitialTab = true
                    if isClockedIn { selectedTab = .reports }
                }
            } else {
                NavigationStack {
                    SignInView()
                }
                .environmentObject(authVM)
            }
        }
        .onChange(of: authVM.currentUserId) { _, userId in
            if let userId {
                notificationVM.configure(userId: userId)
                trackerVM.configure()
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
