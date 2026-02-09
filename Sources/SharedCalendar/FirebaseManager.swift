import FirebaseCore
import FirebaseFirestore
import Foundation
import SwiftUI

@MainActor
class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    private var db: Firestore?

    @Published var currentUserId: String

    // DEV MODE: Fixed users
    private let devUsers = [
        "dev_user_1": "User 1 (Red)",
        "dev_user_2": "User 2 (Green)",
        "dev_user_3": "User 3 (Blue)",
    ]
    private var devUserKeys: [String] { Array(devUsers.keys).sorted() }

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

    // Cycle through User 1 -> User 2 -> User 3 -> User 1
    func debugCycleIdentity() {
        let currentIndex = devUserKeys.firstIndex(of: currentUserId) ?? -1
        let nextIndex = (currentIndex + 1) % devUserKeys.count
        let nextId = devUserKeys[nextIndex]

        self.currentUserId = nextId
        UserDefaults.standard.set(nextId, forKey: "app_user_id")

        let name = devUsers[nextId] ?? "Unknown"
        print("🕵️‍♂️ Switched to Dev User: \(name) (\(nextId))")
    }

    func getDevUserName() -> String? {
        return devUsers[currentUserId]
    }

    func save(event: SharedEvent) async throws {
        guard let db = db else { return }
        try db.collection("shared_events").document(event.id).setData(from: event)
    }

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
