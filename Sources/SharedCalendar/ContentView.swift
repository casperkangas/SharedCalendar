import EventKit
import SwiftUI

@MainActor
class CalendarStore: ObservableObject {
    private let manager = CalendarManager()
    let firebaseManager = FirebaseManager.shared

    @Published var calendars: [EKCalendar] = []
    @Published var permissionStatus: String = "Unknown"
    @Published var cloudStatus: String = "Connecting..."
    @Published var selectedCalendarIDs: Set<String> = []
    @Published var sessionCode: String = ""

    @Published var myEvents: [SharedEvent] = []
    @Published var partnerEvents: [SharedEvent] = []

    @Published var isSyncing: Bool = false
    @Published var lastSyncMessage: String = "Ready"

    // NEW: For Calendar Selection
    @Published var selectedDate: Date? = Date()

    func requestAccess() {
        Task {
            let granted = await manager.requestAccess()
            self.permissionStatus = granted ? "Granted" : "Denied"
            if granted {
                self.calendars = self.manager.fetchLocalCalendars()
            }
            self.cloudStatus = await firebaseManager.checkConnection()
        }
    }

    func toggleSelection(for calendar: EKCalendar) {
        if selectedCalendarIDs.contains(calendar.calendarIdentifier) {
            selectedCalendarIDs.remove(calendar.calendarIdentifier)
        } else {
            selectedCalendarIDs.insert(calendar.calendarIdentifier)
        }
    }

    func loadLocalEvents() {
        guard !sessionCode.isEmpty else {
            lastSyncMessage = "⚠️ Enter a Session Code first!"
            return
        }

        let calendarsToFetch = calendars.filter {
            selectedCalendarIDs.contains($0.calendarIdentifier)
        }
        guard !calendarsToFetch.isEmpty else { return }

        let now = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 30, to: now)!
        let rawEvents = self.manager.fetchEvents(
            from: calendarsToFetch, startDate: now, endDate: endDate)

        self.myEvents = rawEvents.map {
            SharedEvent(from: $0, userId: firebaseManager.currentUserId, sessionCode: sessionCode)
        }
        self.myEvents.sort { $0.startDate < $1.startDate }

        self.lastSyncMessage = "Loaded \(myEvents.count) local events."
    }

    func sync() {
        guard !sessionCode.isEmpty else { return }

        self.isSyncing = true
        self.lastSyncMessage = "Syncing..."

        Task {
            for event in myEvents {
                try? await firebaseManager.save(event: event)
            }

            let allRemoteEvents = try? await firebaseManager.fetchEvents(forSession: sessionCode)

            let currentId = firebaseManager.currentUserId
            let others = (allRemoteEvents ?? []).filter { $0.userId != currentId }

            self.partnerEvents = others
            self.isSyncing = false
            self.lastSyncMessage = "✅ Sync Complete. Partners found: \(others.count)"
        }
    }

    func switchIdentity() {
        firebaseManager.debugSwitchIdentity()
        self.myEvents = []
        self.partnerEvents = []
        self.lastSyncMessage = "🕵️‍♂️ Identity Switched."
    }
}

struct ContentView: View {
    @ObservedObject var store: CalendarStore
    @State private var viewMode: String = "List"  // List or Calendar

    var body: some View {
        HSplitView {
            // LEFT SIDE: Settings
            VStack(alignment: .leading) {
                Text("Setup")
                    .font(.headline)
                    .padding(.top)

                TextField("Session Code", text: $store.sessionCode)
                    .textFieldStyle(.roundedBorder)

                // DEBUG AREA: Only visible in Debug builds
                #if DEBUG
                    VStack(alignment: .leading) {
                        Text(
                            "My ID: " + String(store.firebaseManager.currentUserId.prefix(8))
                                + "..."
                        )
                        .font(.caption2)
                        .foregroundColor(.gray)

                        Button("🕵️‍♂️ Simulate New User") {
                            store.switchIdentity()
                        }
                        .font(.caption)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 5)
                #endif

                Divider()

                if store.permissionStatus != "Granted" {
                    Button("Connect Calendars") { store.requestAccess() }
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
                                    Text(calendar.title)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
            .frame(minWidth: 250, maxWidth: 300)

            // RIGHT SIDE: Main Content
            VStack(alignment: .leading) {
                HStack {
                    Picker("View Mode", selection: $viewMode) {
                        Text("List").tag("List")
                        Text("Calendar").tag("Calendar")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)

                    Spacer()
                    if store.isSyncing { ProgressView().scaleEffect(0.5) }
                }
                .padding()

                HStack {
                    Button("1. Load My Events") { store.loadLocalEvents() }
                    Button("2. Sync with Partner") { store.sync() }
                        .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
                .disabled(store.sessionCode.isEmpty)

                Text(store.lastSyncMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                Divider()

                if viewMode == "List" {
                    // OLD LIST VIEW
                    List {
                        Section("My Events (Local)") {
                            ForEach(store.myEvents) { event in
                                EventRow(event: event, color: .blue)
                            }
                        }
                        Section("Partner Events (Cloud)") {
                            ForEach(store.partnerEvents) { event in
                                EventRow(event: event, color: .orange)
                            }
                        }
                    }
                } else {
                    // NEW CALENDAR VIEW
                    ScrollView {
                        CalendarView(
                            myEvents: store.myEvents,
                            partnerEvents: store.partnerEvents,
                            selectedDate: $store.selectedDate
                        )

                        Divider().padding()

                        // Combined Timeline for Selected Day
                        if let selectedDate = store.selectedDate {
                            VStack(alignment: .leading) {
                                Text(
                                    "Schedule for \(selectedDate.formatted(.dateTime.month().day()))"
                                )
                                .font(.headline)
                                .padding(.horizontal)

                                let daysEvents = getEventsForDate(date: selectedDate)

                                if daysEvents.isEmpty {
                                    Text("No events on this day.")
                                        .foregroundColor(.secondary)
                                        .padding()
                                } else {
                                    // Use explicit ID because tuple isn't Identifiable
                                    ForEach(daysEvents, id: \.event.id) { item in
                                        EventRow(
                                            event: item.event, color: item.isMine ? .blue : .orange
                                        )
                                        .padding(.horizontal)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .frame(minWidth: 400)
        }
        .frame(minWidth: 800, minHeight: 600)
    }

    // Helper to merge and sort events for a specific day
    func getEventsForDate(date: Date) -> [(event: SharedEvent, isMine: Bool)] {
        let calendar = Calendar.current

        let my = store.myEvents.filter { calendar.isDate($0.startDate, inSameDayAs: date) }
            .map { (event: $0, isMine: true) }

        let partner = store.partnerEvents.filter {
            calendar.isDate($0.startDate, inSameDayAs: date)
        }
        .map { (event: $0, isMine: false) }

        // Sort purely by time
        return (my + partner).sorted { $0.event.startDate < $1.event.startDate }
    }
}

// FIX: Added the missing EventRow struct here
struct EventRow: View {
    let event: SharedEvent
    let color: Color

    var body: some View {
        HStack {
            Rectangle()
                .fill(color)
                .frame(width: 4)
                .cornerRadius(2)

            VStack(alignment: .leading) {
                Text(event.title).fontWeight(.medium)
                HStack {
                    Text(event.startDate.formatted(date: .abbreviated, time: .shortened))
                    if event.isAllDay { Text("(All Day)") }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
