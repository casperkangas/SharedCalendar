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
}
