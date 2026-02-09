import SwiftUI

@main
struct SharedCalendarApp: App {
    // This connects our Logic (Manager) to the UI
    @StateObject private var calendarStore = CalendarStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: calendarStore)
        }
    }
}
