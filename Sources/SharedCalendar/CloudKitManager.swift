import CloudKit
import Foundation

@MainActor
class CloudKitManager {
    // This accesses the default iCloud container for the app
    private let container = CKContainer.default()

    // The "Public" database is shared by all users of the app
    // The "Private" database is only for the specific user
    private lazy var database = container.privateCloudDatabase

    // Just a test function to see if we can talk to iCloud
    func checkAccountStatus() async -> String {
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                return "iCloud Available"
            case .noAccount:
                return "No iCloud Account"
            case .restricted:
                return "iCloud Restricted"
            case .couldNotDetermine:
                return "Could Not Determine"
            case .temporarilyUnavailable:
                return "Temporarily Unavailable"
            @unknown default:
                return "Unknown"
            }
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }

    // 1. Save a single event to iCloud
    func save(event: SharedEvent) async throws {
        // Create a unique ID for the record based on our event ID
        let recordID = CKRecord.ID(recordName: event.id)
        let record = CKRecord(recordType: "SharedEvent", recordID: recordID)

        // Save the data fields
        record["title"] = event.title
        record["startDate"] = event.startDate
        record["endDate"] = event.endDate
        record["isAllDay"] = event.isAllDay ? 1 : 0
        record["calendarName"] = event.calendarName

        // Perform the save
        // .changedKeys saves the record, updating it if it already exists
        let _ = try await database.modifyRecords(saving: [record], deleting: [])
    }

    // 2. Fetch all events from iCloud
    func fetchEvents() async throws -> [SharedEvent] {
        // Create a query that finds ALL records of type "SharedEvent"
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "SharedEvent", predicate: predicate)

        // Sort by date
        query.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]

        // Execute the query
        // "results" is a list of Result<CKRecord, Error>
        let (matchResults, _) = try await database.records(matching: query)

        // Convert the CKRecords back into our SharedEvent struct
        var events: [SharedEvent] = []
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                if let event = SharedEvent(from: record) {
                    events.append(event)
                }
            case .failure(let error):
                print("⚠️ Failed to decode one record: \(error)")
            }
        }
        return events
    }
}
