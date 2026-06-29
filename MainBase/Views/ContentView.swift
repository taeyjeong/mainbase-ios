import SwiftUI

struct ContentView: View {
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var notificationVM = NotificationViewModel()

    var body: some View {
        Group {
            if authVM.isSignedIn {
                TimeTrackerView()
                    .environmentObject(notificationVM)
                    .environmentObject(authVM)
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
            } else {
                notificationVM.stopListening()
            }
        }
    }
}

#Preview {
    TimeTrackerView()
        .environmentObject(NotificationViewModel())
        .environmentObject(AuthViewModel())
}
