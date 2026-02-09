import EventKit
import Foundation

// Fix: Add @MainActor.
// This ensures the manager runs on the same thread as the UI,
// eliminating the "Sending self.manager" concurrency error.
@MainActor
class CalendarManager {
    private let eventStore = EKEventStore()

    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            if granted {
                print("✅ Access to Calendar granted.")
            } else {
                print("❌ Access denied. Check System Settings > Privacy & Security > Calendars.")
            }
            return granted
        } catch {
            print("❌ Error requesting access: \(error.localizedDescription)")
            return false
        }
    }

    func fetchLocalCalendars() -> [EKCalendar] {
        return eventStore.calendars(for: .event)
    }

    func fetchEvents(from calendars: [EKCalendar], startDate: Date, endDate: Date) -> [EKEvent] {
        let predicate = eventStore.predicateForEvents(
            withStart: startDate, end: endDate, calendars: calendars)
        return eventStore.events(matching: predicate)
    }
}
