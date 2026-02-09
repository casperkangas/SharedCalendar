import EventKit
import Foundation

struct SharedEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarName: String

    // This initializer takes a local Apple Event and converts it into our clean structure
    init(from ekEvent: EKEvent) {
        // We use the unique ID provided by the system
        self.id = ekEvent.eventIdentifier
        self.title = ekEvent.title ?? "No Title"
        self.startDate = ekEvent.startDate
        self.endDate = ekEvent.endDate
        self.isAllDay = ekEvent.isAllDay
        self.calendarName = ekEvent.calendar.title
    }
}
