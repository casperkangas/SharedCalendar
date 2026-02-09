import CloudKit
import Foundation

@MainActor
class CloudKitManager {
    // SETTING: Set this to true to prevent crashes without a paid Apple Account
    private let isSimulationMode = true

    // CRITICAL: We use 'lazy' so this line doesn't run (and crash) until we actually try to use it.
    private lazy var container = CKContainer.default()
    private lazy var database = container.privateCloudDatabase

    // Just a test function to see if we can talk to iCloud
    func checkAccountStatus() async -> String {
        if isSimulationMode {
            return "🟢 Simulation Mode (Ready)"
        }

        // This code is skipped in simulation mode
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available: return "iCloud Available"
            case .noAccount: return "No iCloud Account"
            case .restricted: return "iCloud Restricted"
            case .couldNotDetermine: return "Could Not Determine"
            case .temporarilyUnavailable: return "Temporarily Unavailable"
            @unknown default: return "Unknown"
            }
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }

    // 1. Save a single event
    func save(event: SharedEvent) async throws {
        if isSimulationMode {
            // Fake the network delay so it feels real
            try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds
            print("☁️ [Simulated Upload] Saved: \(event.title)")
            return
        }

        // REAL ICLOUD CODE (Skipped)
        let recordID = CKRecord.ID(recordName: event.id)
        let record = CKRecord(recordType: "SharedEvent", recordID: recordID)

        record["title"] = event.title
        record["startDate"] = event.startDate
        record["endDate"] = event.endDate
        record["isAllDay"] = event.isAllDay ? 1 : 0
        record["calendarName"] = event.calendarName

        let _ = try await database.modifyRecords(saving: [record], deleting: [])
    }

    // 2. Fetch all events
    func fetchEvents() async throws -> [SharedEvent] {
        if isSimulationMode {
            // Return empty list for simulation
            try await Task.sleep(nanoseconds: 1_000_000_000)
            print("☁️ [Simulated Fetch] Check complete.")
            return []
        }

        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "SharedEvent", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]

        let (matchResults, _) = try await database.records(matching: query)

        var events: [SharedEvent] = []
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                if let event = SharedEvent(from: record) {
                    events.append(event)
                }
            case .failure(let error):
                print("⚠️ Failed to decode record: \(error)")
            }
        }
        return events
    }
}
