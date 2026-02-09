import EventKit
import SwiftUI

@MainActor
class CalendarStore: ObservableObject {
    private let manager = CalendarManager()
    let firebaseManager = FirebaseManager.shared

    @Published var calendars: [EKCalendar] = []
    @Published var permissionStatus: String = "Unknown"
    @Published var selectedCalendarIDs: Set<String> = []
    @Published var sessionCode: String = ""

    @Published var myEvents: [SharedEvent] = []
    @Published var partnerEvents: [SharedEvent] = []

    @Published var isSyncing: Bool = false
    @Published var lastSyncMessage: String = "Ready"
    @Published var selectedDate: Date? = Date()

    func requestAccess() {
        Task {
            let granted = await manager.requestAccess()
            self.permissionStatus = granted ? "Granted" : "Denied"
            if granted {
                self.calendars = self.manager.fetchLocalCalendars()
                // Auto-select all calendars by default
                if self.selectedCalendarIDs.isEmpty {
                    self.selectedCalendarIDs = Set(self.calendars.map { $0.calendarIdentifier })
                }
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

    // Load events from your Mac
    func loadLocalEvents() {
        guard !sessionCode.isEmpty else { return }

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

    // Sync with Firebase
    func sync() {
        guard !sessionCode.isEmpty else { return }
        self.isSyncing = true
        self.lastSyncMessage = "Syncing..."

        Task {
            // A. Upload my events
            for event in myEvents {
                try? await firebaseManager.save(event: event)
            }

            // B. Download ALL events for this session
            let allRemoteEvents = try? await firebaseManager.fetchEvents(forSession: sessionCode)

            // C. Filter: Show only events that are NOT mine
            let currentId = firebaseManager.currentUserId
            let others = (allRemoteEvents ?? []).filter { $0.userId != currentId }

            self.partnerEvents = others
            self.isSyncing = false
            self.lastSyncMessage = "✅ Sync Complete. Partners found: \(others.count)"
        }
    }

    // LOGOUT: Just clears local state, keeps cloud data
    func disconnect() {
        self.sessionCode = ""
        self.myEvents = []
        self.partnerEvents = []
        self.lastSyncMessage = "Ready"
    }

    // LEAVE: Deletes cloud data and clears local state
    func leaveSessionAndNuke() {
        let eventsToDelete = self.myEvents
        self.disconnect()  // Leave immediately

        Task {
            for event in eventsToDelete {
                try? await firebaseManager.delete(event: event)
            }
        }
    }

    // Helper grouping for UI
    func getEventsGroupedByDay() -> [Date: (my: [SharedEvent], partner: [SharedEvent])] {
        var groups: [Date: (my: [SharedEvent], partner: [SharedEvent])] = [:]
        let calendar = Calendar.current

        func startOfDay(_ date: Date) -> Date {
            return calendar.startOfDay(for: date)
        }

        for event in myEvents {
            let day = startOfDay(event.startDate)
            var current = groups[day] ?? (my: [], partner: [])
            current.my.append(event)
            groups[day] = current
        }

        for event in partnerEvents {
            let day = startOfDay(event.startDate)
            var current = groups[day] ?? (my: [], partner: [])
            current.partner.append(event)
            groups[day] = current
        }

        return groups
    }

    func getSortedDays() -> [Date] {
        return getEventsGroupedByDay().keys.sorted()
    }
}

// MARK: - Main Container
struct ContentView: View {
    @StateObject private var store = CalendarStore()
    @State private var isSessionActive: Bool = false

    var body: some View {
        Group {
            if isSessionActive {
                // Renamed to ensure the old "MainAppView" is definitely gone
                SessionDashboardView(store: store, isSessionActive: $isSessionActive)
                    .transition(.move(edge: .trailing))
            } else {
                WelcomeView(isSessionActive: $isSessionActive, store: store)
                    .transition(.move(edge: .leading))
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}

// MARK: - Full Dashboard (Split View)
struct SessionDashboardView: View {
    @ObservedObject var store: CalendarStore
    @Binding var isSessionActive: Bool
    @State private var viewMode: String = "List"

    var body: some View {
        HSplitView {
            // SIDEBAR
            VStack(alignment: .leading) {
                Text("Your Calendars")
                    .font(.headline)
                    .padding()

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
            .frame(minWidth: 200, maxWidth: 300)

            // MAIN CONTENT
            VStack(spacing: 0) {
                // TOOLBAR
                HStack {
                    Picker("View", selection: $viewMode) {
                        Text("List").tag("List")
                        Text("Calendar").tag("Calendar")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)

                    Spacer()

                    if store.isSyncing {
                        ProgressView().controlSize(.small)
                        Text("Syncing...").font(.caption).foregroundColor(.secondary)
                    }

                    Button(action: { store.loadLocalEvents() }) {
                        Label("Refresh Local", systemImage: "arrow.clockwise")
                    }

                    Button(action: { store.sync() }) {
                        Label("Sync Cloud", systemImage: "cloud.fill")
                    }
                    .buttonStyle(.borderedProminent)

                    // SESSION MENU
                    Menu {
                        Text("Session: \(store.sessionCode)")
                        Divider()

                        Button("Log Out (Switch Session)") {
                            store.disconnect()
                            withAnimation { isSessionActive = false }
                        }

                        Button("Delete Data & Leave", role: .destructive) {
                            store.leaveSessionAndNuke()
                            withAnimation { isSessionActive = false }
                        }
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .menuStyle(.borderedButton)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))

                Divider()

                // CONTENT
                if viewMode == "List" {
                    TwoColumnListView(store: store)
                } else {
                    CalendarView(
                        myEvents: store.myEvents,
                        partnerEvents: store.partnerEvents,
                        selectedDate: $store.selectedDate
                    )
                }
            }
            .frame(minWidth: 500)
        }
    }
}

// MARK: - List View Components
struct TwoColumnListView: View {
    @ObservedObject var store: CalendarStore

    var body: some View {
        let grouped = store.getEventsGroupedByDay()
        let days = store.getSortedDays()

        ScrollView {
            LazyVStack(spacing: 20) {
                if days.isEmpty {
                    ContentUnavailableView(
                        "No Events", systemImage: "calendar",
                        description: Text("Click Refresh or Sync to see events.")
                    )
                    .padding(.top, 50)
                }

                ForEach(days, id: \.self) { day in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(day.formatted(date: .complete, time: .omitted))
                            .font(.headline)
                            .padding(.horizontal)
                            .padding(.bottom, 5)
                            .foregroundColor(.secondary)

                        Divider()

                        HStack(alignment: .top, spacing: 0) {
                            // Left: MY EVENTS
                            VStack(alignment: .leading, spacing: 8) {
                                if let events = grouped[day]?.my, !events.isEmpty {
                                    ForEach(events) { event in
                                        EventCard(event: event, color: .blue)
                                    }
                                } else {
                                    Text("Free").font(.caption).italic().foregroundColor(.secondary)
                                        .padding()
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(8)
                            .background(Color.blue.opacity(0.05))

                            Divider()

                            // Right: PARTNER EVENTS
                            VStack(alignment: .leading, spacing: 8) {
                                if let events = grouped[day]?.partner, !events.isEmpty {
                                    ForEach(events) { event in
                                        EventCard(event: event, color: .orange)
                                    }
                                } else {
                                    Text("Free").font(.caption).italic().foregroundColor(.secondary)
                                        .padding()
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(8)
                            .background(Color.orange.opacity(0.05))
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 8).stroke(
                                Color.gray.opacity(0.2), lineWidth: 1))
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}

struct EventCard: View {
    let event: SharedEvent
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(color)
                .frame(width: 4)
                .cornerRadius(2)

            VStack(alignment: .leading) {
                Text(event.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                HStack {
                    if event.isAllDay {
                        Text("All Day")
                    } else {
                        Text(event.startDate.formatted(date: .omitted, time: .shortened))
                        Text("-")
                        Text(event.endDate.formatted(date: .omitted, time: .shortened))
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(6)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
}
