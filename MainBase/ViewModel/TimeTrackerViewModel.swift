import Foundation
import Combine
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

@MainActor
final class TimeTrackerViewModel: ObservableObject {
    @Published private(set) var isClockedIn = false
    @Published private(set) var clockInTime: Date? = nil
    @Published private(set) var isSaving = false
    @Published private(set) var isAdmin = false

    private static let maxSessionDuration: TimeInterval = 8 * 60 * 60
    private static let autoClockOutReport = "Automatically clocked out after 8 hours."

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var autoStopTimer: Timer?

    private var userId: String? { Auth.auth().currentUser?.uid }

    func configure() {
        guard let uid = userId else { return }
        listener?.remove()
        listener = db.collection("users").document(uid).addSnapshotListener { [weak self] snap, _ in
            guard let data = snap?.data() else { return }
            let online = data["isOnline"] as? Bool ?? false
            let ts = data["clockInTime"] as? Timestamp
            let admin = data["admin"] as? Bool ?? false
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isClockedIn = online
                self.clockInTime = ts?.dateValue()
                self.isAdmin = admin
            }
        }
        startAutoStopTimer()
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        autoStopTimer?.invalidate()
        autoStopTimer = nil
    }

    private func startAutoStopTimer() {
        autoStopTimer?.invalidate()
        autoStopTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.autoClockOutIfNeeded()
            }
        }
    }

    private func autoClockOutIfNeeded() async {
        guard isClockedIn, !isSaving, let start = clockInTime else { return }
        guard Date().timeIntervalSince(start) >= Self.maxSessionDuration else { return }
        await clockOut(report: Self.autoClockOutReport)
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
        await notifyClockEvent(action: .clockIn)
        isSaving = false
    }

    func clockOut(report: String) async {
        guard let uid = userId, let start = clockInTime else { return }
        let trimmedReport = report.trimmingCharacters(in: .whitespaces)
        guard !trimmedReport.isEmpty else { return }

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
                "report": trimmedReport,
                "createdAt": Timestamp(date: now)
            ])
            if !trimmedReport.isEmpty {
                try await db.collection("users").document(uid).collection("reports").addDocument(data: [
                    "reportText": trimmedReport,
                    "timestamp": Timestamp(date: now)
                ])
            }
            await notifyClockEvent(action: .clockOut, report: trimmedReport)
        } catch {}
        isSaving = false
    }

    private func notifyClockEvent(action: ClockAction, report: String? = nil) async {
        guard let uid = userId else { return }
        var payload: [String: Any] = ["actorUserId": uid, "action": action.rawValue]
        if let report, !report.isEmpty {
            payload["report"] = report
        }
        let callable = Functions.functions().httpsCallable("createClockEventNotification")
        do {
            _ = try await callable.call(payload)
        } catch {
            // Notification failures should not block clock in/out.
        }
    }
}
