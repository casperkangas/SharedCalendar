import CloudKit
import EventKit
import Foundation

struct SharedEvent: Identifiable, Equatable {
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

    // Init from CloudKit Record (Downloading from Cloud)
    init?(from record: CKRecord) {
        // We ensure all required fields exist, otherwise we fail gracefully
        guard
            let title = record["title"] as? String,
            let startDate = record["startDate"] as? Date,
            let endDate = record["endDate"] as? Date,
            let isAllDayInt = record["isAllDay"] as? Int,
            let calendarName = record["calendarName"] as? String
        else {
            return nil
        }

        self.id = record.recordID.recordName
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDayInt == 1
        self.calendarName = calendarName
    }
}
