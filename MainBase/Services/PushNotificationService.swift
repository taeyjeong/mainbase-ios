import FirebaseAuth
import FirebaseFirestore
import Foundation

enum PushNotificationService {
    static func saveFCMToken(_ token: String) {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { document, error in
            if error != nil { return }

            if let existingToken = document?.data()?["fcmToken"] as? String, existingToken == token {
                return
            }

            db.collection("users").document(userId).updateData([
                "fcmToken": token,
                "lastTokenUpdate": Timestamp(date: Date())
            ])
        }
    }
}
