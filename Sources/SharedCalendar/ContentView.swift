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

    func loadLocalEvents() {
        guard !sessionCode.isEmpty else { return }
        let calendarsToFetch = calendars.filter {
            selectedCalendarIDs.contains($0.calendarIdentifier)
        }
        guard !calendarsToFetch.isEmpty else { return }

        let now = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 60, to: now)!
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: now)!

        let rawEvents = self.manager.fetchEvents(
            from: calendarsToFetch, startDate: startDate, endDate: endDate)
        self.myEvents = rawEvents.map {
            SharedEvent(from: $0, userId: firebaseManager.currentUserId, sessionCode: sessionCode)
        }
        self.lastSyncMessage = "Loaded \(myEvents.count) local events."
    }

    func sync() {
        guard !sessionCode.isEmpty else { return }
        self.isSyncing = true
        self.lastSyncMessage = "Syncing..."
        Task {
            for event in myEvents { try? await firebaseManager.save(event: event) }
            let allRemoteEvents = try? await firebaseManager.fetchEvents(forSession: sessionCode)
            let currentId = firebaseManager.currentUserId
            self.partnerEvents = (allRemoteEvents ?? []).filter { $0.userId != currentId }
            self.isSyncing = false
            self.lastSyncMessage = "✅ Sync Complete."
        }
    }

    func disconnect() {
        self.sessionCode = ""
        self.myEvents = []
        self.partnerEvents = []
    }

    func leaveSessionAndNuke() {
        let eventsToDelete = self.myEvents
        self.disconnect()
        Task {
            for event in eventsToDelete { try? await firebaseManager.delete(event: event) }
        }
    }
}

struct ContentView: View {
    @StateObject private var store = CalendarStore()
    @State private var isSessionActive: Bool = false

    var body: some View {
        Group {
            if isSessionActive {
                SessionDashboardView(store: store, isSessionActive: $isSessionActive)
                    .transition(.move(edge: .trailing))
            } else {
                WelcomeView(isSessionActive: $isSessionActive, store: store)
                    .transition(.move(edge: .leading))
            }
        }
        .frame(minWidth: 900, minHeight: 700)
    }
}

struct SessionDashboardView: View {
    @ObservedObject var store: CalendarStore
    @Binding var isSessionActive: Bool

    // View State
    @State private var calendarMode: String = "Month"
    @State private var visibleDate: Date = Date()

    var body: some View {
        HSplitView {
            // SIDEBAR
            VStack(alignment: .leading) {
                Text("Your Calendars")
                    .font(.headline).padding()
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
            .frame(minWidth: 200, maxWidth: 300)

            // MAIN CONTENT
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    Picker("Mode", selection: $calendarMode) {
                        Text("Month").tag("Month")
                        Text("Week").tag("Week")
                    }
                    .pickerStyle(.segmented).frame(width: 150)

                    Spacer()
                    if store.isSyncing { ProgressView().controlSize(.small) }

                    Button(action: { store.loadLocalEvents() }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    Button(action: { store.sync() }) { Label("Sync", systemImage: "cloud.fill") }
                        .buttonStyle(.borderedProminent)

                    Menu {
                        Text("Session: \(store.sessionCode)")
                        Button("Log Out") {
                            store.disconnect()
                            withAnimation { isSessionActive = false }
                        }
                        Button("Delete & Leave", role: .destructive) {
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

                // 1. Calendar Grid
                CalendarView(
                    myEvents: store.myEvents,
                    partnerEvents: store.partnerEvents,
                    selectedDate: $store.selectedDate,
                    mode: calendarMode,
                    visibleDate: $visibleDate
                )
                .padding()

                // 2. Day Timeline (One Day View)
                if let selected = store.selectedDate {
                    Divider()
                    Text("Schedule for \(selected.formatted(date: .complete, time: .omitted))")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding([.top, .horizontal])

                    DayTimelineView(
                        date: selected, myEvents: store.myEvents, partnerEvents: store.partnerEvents
                    )
                }
            }
            .frame(minWidth: 500)
        }
    }
}

// Visual Timeline for a single day
struct DayTimelineView: View {
    let date: Date
    let myEvents: [SharedEvent]
    let partnerEvents: [SharedEvent]

    // Timeline Settings
    let startHour = 7
    let endHour = 22
    let hourHeight: CGFloat = 50

    var body: some View {
        let dayEvents = getEventsForDay()
        let freeSlots = calculateFreeSlots(events: dayEvents)

        ScrollView {
            HStack(alignment: .top, spacing: 20) {

                // 1. Time Labels
                VStack(spacing: 0) {
                    ForEach(startHour...endHour, id: \.self) { hour in
                        Text("\(hour):00")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(height: hourHeight, alignment: .top)
                    }
                }
                .padding(.top, 10)

                // 2. Event Canvas
                ZStack(alignment: .topLeading) {
                    // Grid Lines
                    VStack(spacing: 0) {
                        ForEach(startHour...endHour, id: \.self) { _ in
                            Divider().frame(height: hourHeight, alignment: .top)
                        }
                    }
                    .padding(.top, 10)

                    // Event Blocks
                    ForEach(dayEvents) { item in
                        EventBlock(
                            event: item.event, color: item.isMine ? .blue : .orange,
                            startHour: startHour, hourHeight: hourHeight
                        )
                        .padding(.leading, item.isMine ? 0 : 50)  // Simple offset to show overlaps visualy
                        .frame(width: 150)
                    }
                }

                // 3. Info Panel (Free Time)
                VStack(alignment: .leading) {
                    Text("Free Time").font(.headline)
                    if freeSlots.isEmpty {
                        Text("No free blocks found between \(startHour):00 and \(endHour):00")
                            .font(.caption).foregroundColor(.secondary)
                    } else {
                        ForEach(freeSlots, id: \.self) { slot in
                            Text("• \(slot)").font(.body).foregroundColor(.green)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
    }

    // Helpers
    struct EventWrapper: Identifiable {
        let id = UUID()
        let event: SharedEvent
        let isMine: Bool
    }

    func getEventsForDay() -> [EventWrapper] {
        let calendar = Calendar.current
        let my = myEvents.filter { calendar.isDate($0.startDate, inSameDayAs: date) }.map {
            EventWrapper(event: $0, isMine: true)
        }
        let partner = partnerEvents.filter { calendar.isDate($0.startDate, inSameDayAs: date) }.map
        { EventWrapper(event: $0, isMine: false) }
        return my + partner
    }

    func calculateFreeSlots(events: [EventWrapper]) -> [String] {
        // Simplified free time logic
        let calendar = Calendar.current
        var busyIntervals: [(start: Date, end: Date)] = events.map {
            ($0.event.startDate, $0.event.endDate)
        }
        busyIntervals.sort { $0.start < $1.start }

        var freeStrings: [String] = []
        var cursor = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: date)!
        let endOfDay = calendar.date(bySettingHour: endHour, minute: 0, second: 0, of: date)!

        for interval in busyIntervals {
            if interval.start > cursor {
                if cursor < endOfDay {
                    freeStrings.append(
                        "\(cursor.formatted(date: .omitted, time: .shortened)) - \(interval.start.formatted(date: .omitted, time: .shortened))"
                    )
                }
            }
            cursor = max(cursor, interval.end)
        }

        if cursor < endOfDay {
            freeStrings.append(
                "\(cursor.formatted(date: .omitted, time: .shortened)) - \(endOfDay.formatted(date: .omitted, time: .shortened))"
            )
        }

        return freeStrings
    }
}

struct EventBlock: View {
    let event: SharedEvent
    let color: Color
    let startHour: Int
    let hourHeight: CGFloat

    var body: some View {
        let calendar = Calendar.current
        let startMin = calendar.component(.minute, from: event.startDate)
        let startH = calendar.component(.hour, from: event.startDate)

        // Calculate Y position relative to startHour
        let offsetMinutes = (startH - startHour) * 60 + startMin
        let topOffset = CGFloat(offsetMinutes) / 60.0 * hourHeight

        // Calculate Height
        let duration = event.endDate.timeIntervalSince(event.startDate) / 3600.0  // in hours
        let height = CGFloat(duration) * hourHeight

        return VStack(alignment: .leading) {
            Text(event.title).font(.caption).bold().foregroundColor(.white)
            Text(event.startDate.formatted(date: .omitted, time: .shortened))
                .font(.caption2).foregroundColor(.white.opacity(0.8))
        }
        .padding(4)
        .frame(height: max(20, height), alignment: .top)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.8))
        .cornerRadius(6)
        .offset(y: topOffset + 10)  // +10 for padding
    }
}
