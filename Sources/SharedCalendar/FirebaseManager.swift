import FirebaseCore
import FirebaseFirestore
import Foundation
import SwiftUI

@MainActor
class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    private var db: Firestore?

    @Published var currentUserId: String

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        self.db = Firestore.firestore()

        let defaults = UserDefaults.standard
        if let savedId = defaults.string(forKey: "app_user_id") {
            self.currentUserId = savedId
        } else {
            let newId = UUID().uuidString
            defaults.set(newId, forKey: "app_user_id")
            self.currentUserId = newId
        }
    }

    func checkConnection() async -> String {
        guard let db = db else { return "Firebase Not Configured" }
        do {
            let _ = try await db.collection("status").document("health_check").getDocument()
            return "🟢 Connected"
        } catch {
            return "🔴 Error: \(error.localizedDescription)"
        }
    }

    func debugSwitchIdentity() {
        self.currentUserId = UUID().uuidString
        UserDefaults.standard.set(self.currentUserId, forKey: "app_user_id")
        print("🕵️‍♂️ Switched Identity to: \(self.currentUserId)")
    }

    func save(event: SharedEvent) async throws {
        guard let db = db else { return }
        try db.collection("shared_events").document(event.id).setData(from: event)
    }

    // NEW: Delete a specific event
    func delete(event: SharedEvent) async throws {
        guard let db = db else { return }
        try await db.collection("shared_events").document(event.id).delete()
    }

    func fetchEvents(forSession sessionCode: String) async throws -> [SharedEvent] {
        guard let db = db else { return [] }

        let snapshot = try await db.collection("shared_events")
            .whereField("sessionCode", isEqualTo: sessionCode)
            .getDocuments()

        let events = snapshot.documents.compactMap { document in
            try? document.data(as: SharedEvent.self)
        }

        return events.sorted { $0.startDate < $1.startDate }
    }

    func checkSessionAvailability(sessionCode: String) async -> (Bool, String) {
        guard let db = db else { return (false, "No Connection") }

        do {
            let snapshot = try await db.collection("shared_events")
                .whereField("sessionCode", isEqualTo: sessionCode)
                .limit(to: 50)
                .getDocuments()

            let events = snapshot.documents.compactMap { try? $0.data(as: SharedEvent.self) }
            let userIds = Set(events.map { $0.userId })

            if userIds.contains(currentUserId) {
                return (true, "Welcome back!")
            } else if userIds.count < 2 {
                return (true, "Session available.")
            } else {
                return (false, "Session is full (2/2 users).")
            }
        } catch {
            return (false, "Error: \(error.localizedDescription)")
        }
    }
}
