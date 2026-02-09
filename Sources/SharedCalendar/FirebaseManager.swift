import FirebaseCore
// FirebaseFirestore throws an error but it can be ignored!
import FirebaseFirestore
import Foundation

@MainActor
class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    private var db: Firestore?

    // CHANGED: 'var' instead of 'let' so we can change it
    // Added @Published so the UI knows when it changes
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

        print("🔥 Firebase Initialized. User ID: \(self.currentUserId)")
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

    // NEW: Debug function to become a "New Person"
    func debugSwitchIdentity() {
        self.currentUserId = UUID().uuidString
        print("🕵️‍♂️ Switched Identity to: \(self.currentUserId)")
    }

    func save(event: SharedEvent) async throws {
        guard let db = db else { return }
        try db.collection("shared_events").document(event.id).setData(from: event)
        print("🔥 Saved: \(event.title)")
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
}
