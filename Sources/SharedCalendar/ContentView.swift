import EventKit
import SwiftUI

@MainActor
class CalendarStore: ObservableObject {
    private let manager = CalendarManager()

    @Published var calendars: [EKCalendar] = []
    @Published var permissionStatus: String = "Unknown"

    // New: Track which calendars are selected (by their unique ID)
    @Published var selectedCalendarIDs: Set<String> = []

    // New: Store the events we fetch
    @Published var upcomingEvents: [EKEvent] = []

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

    // New: Fetch events only for the selected calendars
    func fetchSelectedEvents() {
        // 1. Filter the list of all calendars to find the selected objects
        let calendarsToFetch = calendars.filter {
            selectedCalendarIDs.contains($0.calendarIdentifier)
        }

        guard !calendarsToFetch.isEmpty else {
            self.upcomingEvents = []
            return
        }

        // 2. Define the date range (Now -> 30 days from now)
        let now = Date()
        // Using 30 days so we have a good dataset
        let endDate = Calendar.current.date(byAdding: .day, value: 30, to: now)!

        // 3. Ask the manager for data
        self.upcomingEvents = self.manager.fetchEvents(
            from: calendarsToFetch, startDate: now, endDate: endDate)
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
                    Text("Preview Data")
                        .font(.headline)
                    Spacer()
                    Button("Refresh Events") {
                        store.fetchSelectedEvents()
                    }
                    .disabled(store.selectedCalendarIDs.isEmpty)
                }
                .padding()

                if store.upcomingEvents.isEmpty {
                    Text("Select a calendar and click Refresh to see events.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(store.upcomingEvents, id: \.eventIdentifier) { event in
                        VStack(alignment: .leading) {
                            Text(event.title ?? "No Title")
                                .fontWeight(.bold)
                            HStack {
                                Text(event.startDate.formatted())
                                Text("->")
                                Text(event.endDate.formatted(date: .omitted, time: .shortened))
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .frame(minWidth: 300)
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}
