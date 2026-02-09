import EventKit
import Foundation

// Adding 'Codable' here is the magic that lets Firebase save this struct automatically
struct SharedEvent: Identifiable, Equatable, Codable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarName: String

    // Init from Local Apple Event
    init(from ekEvent: EKEvent) {
        self.id = ekEvent.eventIdentifier
        self.title = ekEvent.title ?? "No Title"
        self.startDate = ekEvent.startDate
        self.endDate = ekEvent.endDate
        self.isAllDay = ekEvent.isAllDay
        self.calendarName = ekEvent.calendar.title
    }
}
