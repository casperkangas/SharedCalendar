import EventKit
import Foundation

struct SharedEvent: Identifiable, Equatable, Codable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarName: String

    // NEW: Sharing fields
    let userId: String  // Unique ID of the user who uploaded this
    let sessionCode: String  // The "Room" or "Group" code (e.g., "Family")

    // Init from Local Apple Event + Context
    init(from ekEvent: EKEvent, userId: String, sessionCode: String) {
        self.id = ekEvent.eventIdentifier
        self.title = ekEvent.title ?? "No Title"
        self.startDate = ekEvent.startDate
        self.endDate = ekEvent.endDate
        self.isAllDay = ekEvent.isAllDay
        self.calendarName = ekEvent.calendar.title

        self.userId = userId
        self.sessionCode = sessionCode
    }
}
