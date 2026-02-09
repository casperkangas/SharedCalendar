import SwiftUI

@main
struct SharedCalendarApp: App {
    // ContentView now handles its own state storage, so we don't need to create it here.

    var body: some Scene {
        WindowGroup {
            // Simply initialize ContentView without arguments
            ContentView()
        }
    }
}
