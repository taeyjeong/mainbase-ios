import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation

@MainActor
final class TimeOffRequestsViewModel: ObservableObject {
    /// Soonest shift first.
    @Published private(set) var requests: [TimeOffRequest] = []
    @Published private(set) var isSaving = false
    @Published var alertMessage: String?

    private let db = Firestore.firestore()
    private let userId: String

    init(userId: String) {
        self.userId = userId
    }

    private var requestsRef: CollectionReference {
        db.collection("users").document(userId).collection("timeOffRequests")
    }

    func load() async {
        do {
            let snapshot = try await requestsRef.getDocuments()
            requests = snapshot.documents
                .compactMap { TimeOffRequest(id: $0.documentID, data: $0.data()) }
                .sorted { $0.shiftStart < $1.shiftStart }
        } catch {
            alertMessage = "Could not load your time-off requests right now."
        }
    }

    /// Requests for shifts that haven't ended yet.
    var upcoming: [TimeOffRequest] {
        let now = Date()
        return requests.filter { $0.shiftEnd > now }
    }

    /// The pending or approved request for `shift`, if any. A denied one doesn't block a new request.
    func activeRequest(for shift: DateInterval) -> TimeOffRequest? {
        requests.first { $0.shiftStart == shift.start && $0.status != .denied }
    }

    /// Sends a pending request for `shift` (TimeOffRequestSheet). For a shortened day,
    /// `requested` is the part of the shift the employee still wants to work. Returns an error
    /// message, or nil once saved.
    func submit(kind: TimeOffRequest.Kind, shift: DateInterval, requested: DateInterval?, reason: String) async -> String? {
        if activeRequest(for: shift) != nil {
            return "You already have a request for this shift."
        }
        if kind == .shortenedDay {
            guard let requested, requested.duration > 0 else {
                return "The end time must be after the start time."
            }
            guard requested.start >= shift.start, requested.end <= shift.end, requested != shift else {
                return "A shortened day must fit inside the scheduled shift and be shorter than it."
            }
        }

        let request = TimeOffRequest(kind: kind, shift: shift, requested: requested, reason: reason)
        var data = request.firestoreData
        data["createdAt"] = FieldValue.serverTimestamp()
        data["requestedByEmail"] = Auth.auth().currentUser?.email ?? ""

        isSaving = true
        defer { isSaving = false }
        do {
            try await requestsRef.document(request.id).setData(data)
            requests = (requests + [request]).sorted { $0.shiftStart < $1.shiftStart }
            return nil
        } catch {
            return "Could not send your request right now."
        }
    }

    /// Withdraws a request that hasn't been answered yet.
    func withdraw(_ request: TimeOffRequest) async {
        guard request.status == .pending else { return }
        do {
            try await requestsRef.document(request.id).delete()
            requests.removeAll { $0.id == request.id }
        } catch {
            alertMessage = "Could not withdraw that request right now."
        }
    }
}
