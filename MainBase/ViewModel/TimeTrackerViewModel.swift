import Foundation
import Combine
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class TimeTrackerViewModel: ObservableObject {
    @Published private(set) var isClockedIn = false
    @Published private(set) var clockInTime: Date? = nil
    @Published private(set) var isSaving = false

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    private var userId: String? { Auth.auth().currentUser?.uid }

    func configure() {
        guard let uid = userId else { return }
        listener?.remove()
        listener = db.collection("users").document(uid).addSnapshotListener { [weak self] snap, _ in
            guard let data = snap?.data() else { return }
            let online = data["isOnline"] as? Bool ?? false
            let ts = data["clockInTime"] as? Timestamp
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isClockedIn = online
                self.clockInTime = ts?.dateValue()
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    func formattedElapsed(from start: Date, now: Date = Date()) -> String {
        let diff = Int(now.timeIntervalSince(start))
        let h = diff / 3600
        let m = (diff % 3600) / 60
        let s = diff % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    func clockIn() async {
        guard let uid = userId else { return }
        isSaving = true
        let now = Date()
        try? await db.collection("users").document(uid).setData([
            "isOnline": true,
            "clockInTime": Timestamp(date: now)
        ], merge: true)
        isSaving = false
    }

    func clockOut(report: String) async {
        guard let uid = userId, let start = clockInTime else { return }
        isSaving = true
        let now = Date()
        let durationMs = Int64(now.timeIntervalSince(start) * 1000)
        let hours = Int(now.timeIntervalSince(start)) / 3600
        let minutes = (Int(now.timeIntervalSince(start)) % 3600) / 60
        do {
            try await db.collection("users").document(uid).updateData([
                "isOnline": false,
                "clockInTime": FieldValue.delete()
            ])
            let historyRef = db.collection("users").document(uid).collection("history").document()
            try await historyRef.setData([
                "clockIn": Timestamp(date: start),
                "clockOut": Timestamp(date: now),
                "durationMs": durationMs,
                "durationFormatted": "\(hours)h \(minutes)m",
                "report": report.trimmingCharacters(in: .whitespaces),
                "createdAt": Timestamp(date: now)
            ])
        } catch {}
        isSaving = false
    }
}
