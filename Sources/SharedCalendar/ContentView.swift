import EventKit
import SwiftUI

@MainActor
class CalendarStore: ObservableObject {
    private let manager = CalendarManager()
    // SWITCH: Using FirebaseManager now
    private let firebaseManager = FirebaseManager.shared

    @Published var calendars: [EKCalendar] = []
    @Published var permissionStatus: String = "Unknown"
    @Published var cloudStatus: String = "Connecting..."
    @Published var selectedCalendarIDs: Set<String> = []
    @Published var upcomingEvents: [SharedEvent] = []

    @Published var isSyncing: Bool = false
    @Published var lastSyncMessage: String = "Ready to Sync"

    func requestAccess() {
        Task {
            // 1. Check Calendar Access
            let granted = await manager.requestAccess()
            self.permissionStatus = granted ? "Granted" : "Denied"
            if granted {
                self.calendars = self.manager.fetchLocalCalendars()
            }

            // 2. Check Firebase Connection
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
        let rawEvents = self.manager.fetchEvents(
            from: calendarsToFetch, startDate: now, endDate: endDate)

        self.upcomingEvents = rawEvents.map { SharedEvent(from: $0) }
        self.upcomingEvents.sort { $0.startDate < $1.startDate }

        self.lastSyncMessage = "Found \(upcomingEvents.count) local events."
    }

    func syncToCloud() {
        guard !upcomingEvents.isEmpty else { return }

        self.isSyncing = true
        self.lastSyncMessage = "Syncing to Firebase..."

        Task {
            var successCount = 0
            var failCount = 0

            for event in upcomingEvents {
                do {
                    try await firebaseManager.save(event: event)
                    successCount += 1
                } catch {
                    print("Upload failed: \(error.localizedDescription)")
                    failCount += 1
                }
            }

            self.isSyncing = false
            self.lastSyncMessage = "🔥 Uploaded: \(successCount) | Failed: \(failCount)"
        }
    }
}

struct ContentView: View {
    @ObservedObject var store: CalendarStore

    var body: some View {
        HSplitView {
            // LEFT SIDE
            VStack(alignment: .leading) {
                Text("Select Calendars")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Local Access: \(store.permissionStatus)")
                        .font(.caption)
                        .foregroundColor(store.permissionStatus == "Granted" ? .green : .red)
                    Text("Database: \(store.cloudStatus)")
                        .font(.caption)
                        .foregroundColor(.orange)  // Orange for Firebase
                }
                .padding(.horizontal)

                if store.permissionStatus != "Granted" {
                    Button("Request Access / Connect") { store.requestAccess() }
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

            // RIGHT SIDE
            VStack(alignment: .leading) {
                HStack {
                    Text("Sync Dashboard")
                        .font(.headline)
                    Spacer()
                    if store.isSyncing { ProgressView().scaleEffect(0.5) }
                }
                .padding(.horizontal)
                .padding(.top)

                HStack {
                    Button("1. Load Local") {
                        store.fetchSelectedEvents()
                    }
                    .disabled(store.selectedCalendarIDs.isEmpty || store.isSyncing)

                    Button("2. Push to Firebase") {
                        store.syncToCloud()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.upcomingEvents.isEmpty || store.isSyncing)
                }
                .padding(.horizontal)

                Text(store.lastSyncMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                Divider()

                List(store.upcomingEvents) { event in
                    VStack(alignment: .leading) {
                        Text(event.title).fontWeight(.bold)
                        HStack {
                            Text(event.startDate.formatted(date: .abbreviated, time: .shortened))
                            Text("->")
                            Text(event.endDate.formatted(date: .abbreviated, time: .shortened))
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }
            .frame(minWidth: 350)
        }
        .frame(minWidth: 700, minHeight: 450)
    }
}
