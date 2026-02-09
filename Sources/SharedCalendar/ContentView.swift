import EventKit
import SwiftUI

@MainActor
class CalendarStore: ObservableObject {
    private let manager = CalendarManager()

    @Published var calendars: [EKCalendar] = []
    @Published var permissionStatus: String = "Unknown"
    @Published var selectedCalendarIDs: Set<String> = []

    // CHANGED: We now store our clean 'SharedEvent' struct instead of raw EKEvents
    @Published var upcomingEvents: [SharedEvent] = []

    func requestAccess() {
        Task {
            let granted = await manager.requestAccess()
            self.permissionStatus = granted ? "Granted" : "Denied"

            if granted {
                self.calendars = self.manager.fetchLocalCalendars()
            }
        }
    }

    func toggleSelection(for calendar: EKCalendar) {
        if selectedCalendarIDs.contains(calendar.calendarIdentifier) {
            selectedCalendarIDs.remove(calendar.calendarIdentifier)
        } else {
            selectedCalendarIDs.insert(calendar.calendarIdentifier)
        }
    }

    func fetchSelectedEvents() {
        let calendarsToFetch = calendars.filter {
            selectedCalendarIDs.contains($0.calendarIdentifier)
        }

        guard !calendarsToFetch.isEmpty else {
            self.upcomingEvents = []
            return
        }

        let now = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 30, to: now)!

        // 1. Fetch raw data
        let rawEvents = self.manager.fetchEvents(
            from: calendarsToFetch, startDate: now, endDate: endDate)

        // 2. Convert to our clean structure using the 'map' function
        // This runs the init(from:) we wrote in SharedEvent.swift for every item
        self.upcomingEvents = rawEvents.map { SharedEvent(from: $0) }

        // 3. Sort them by date (Local calendar fetch doesn't guarantee order)
        self.upcomingEvents.sort { $0.startDate < $1.startDate }
    }
}

struct ContentView: View {
    @ObservedObject var store: CalendarStore

    var body: some View {
        HSplitView {
            // LEFT SIDE: Calendar Selection
            VStack(alignment: .leading) {
                Text("Select Calendars")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top)

                if store.permissionStatus != "Granted" {
                    Button("Request Access") { store.requestAccess() }
                        .padding()
                } else {
                    List {
                        ForEach(store.calendars, id: \.calendarIdentifier) { calendar in
                            HStack {
                                Toggle(
                                    isOn: Binding(
                                        get: {
                                            store.selectedCalendarIDs.contains(
                                                calendar.calendarIdentifier)
                                        },
                                        set: { _ in store.toggleSelection(for: calendar) }
                                    )
                                ) {
                                    HStack {
                                        Circle()
                                            .fill(Color(calendar.color))
                                            .frame(width: 8, height: 8)
                                        Text(calendar.title)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .frame(minWidth: 200, maxWidth: 300)

            // RIGHT SIDE: Event Preview
            VStack(alignment: .leading) {
                HStack {
                    Text("Preview Shared Data")
                        .font(.headline)
                    Spacer()
                    Button("Refresh Events") {
                        store.fetchSelectedEvents()
                    }
                    .disabled(store.selectedCalendarIDs.isEmpty)
                }
                .padding()

                if store.upcomingEvents.isEmpty {
                    Text("Select a calendar and click Refresh.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(store.upcomingEvents) { event in
                        VStack(alignment: .leading) {
                            Text(event.title)
                                .fontWeight(.bold)

                            HStack {
                                if event.isAllDay {
                                    Text("All Day")
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(4)
                                } else {
                                    Text(
                                        event.startDate.formatted(
                                            date: .abbreviated, time: .shortened))
                                    Text("->")
                                    Text(
                                        event.endDate.formatted(
                                            date: .abbreviated, time: .shortened))
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)

                            Text("From: \(event.calendarName)")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .frame(minWidth: 300)
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}
