import UIKit

/// Forces the interface orientation for full-screen experiences (e.g. the maximized
/// project photo viewer), then releases the lock back to `.all` when dismissed.
enum OrientationLock {
    static func lock(to mask: UIInterfaceOrientationMask) {
        AppDelegate.orientationLock = mask
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
        scene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}
