import FirebaseCore
import FirebaseFirestore
import Foundation

@MainActor
class FirebaseManager {
    // Singleton instance
    static let shared = FirebaseManager()

    private var db: Firestore?

    init() {
        // 1. Initialize Firebase
        // We check if it's already configured to prevent crashes during development reloading
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        // 2. Get the database instance
        self.db = Firestore.firestore()
        print("🔥 Firebase Initialized")
    }

    // Test Connection
    func checkConnection() async -> String {
        guard let db = db else { return "Firebase Not Configured" }
        do {
            // Try to read a dummy document to see if we have connection
            let _ = try await db.collection("status").document("health_check").getDocument()
            return "🟢 Connected to Firestore"
        } catch {
            return "🔴 Error: \(error.localizedDescription)"
        }
    }

    // 1. Save Event
    func save(event: SharedEvent) async throws {
        guard let db = db else { return }

        // Firestore can save 'Codable' structs directly!
        // We use the event ID as the document ID so we don't create duplicates
        try db.collection("shared_events").document(event.id).setData(from: event)
        print("🔥 Saved: \(event.title)")
    }

    // 2. Fetch Events
    func fetchEvents() async throws -> [SharedEvent] {
        guard let db = db else { return [] }

        // Get all documents from the collection
        let snapshot = try await db.collection("shared_events")
            .order(by: "startDate", descending: false)
            .getDocuments()

        // Convert documents back to SharedEvent structs
        let events = snapshot.documents.compactMap { document in
            try? document.data(as: SharedEvent.self)
        }

        return events
    }
}
