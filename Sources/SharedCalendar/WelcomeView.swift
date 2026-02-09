import SwiftUI

struct WelcomeView: View {
    // This binding lets us tell the parent view (ContentView) that we are done
    @Binding var isSessionActive: Bool
    @ObservedObject var store: CalendarStore

    // Auto-save the session code to UserDefaults
    @AppStorage("saved_session_code") private var sessionCode: String = ""

    @State private var statusMessage: String = ""
    @State private var isChecking: Bool = false

    // Get the Mac's username
    private var userName: String {
        return NSUserName()
    }

    var body: some View {
        VStack(spacing: 30) {
            // 1. Greeting
            VStack(spacing: 5) {
                Text("Hello, \(userName).")
                    .font(.system(size: 32, weight: .bold, design: .rounded))

                Text("Ready to coordinate?")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 20)

            // 2. Secret Code Input
            VStack(alignment: .leading, spacing: 10) {
                Text("SECRET CODE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                    .padding(.leading, 4)

                TextField("e.g. OurTrip2026", text: $sessionCode)
                    .textFieldStyle(.plain)
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            .frame(maxWidth: 300)

            // 3. Status Message
            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(statusMessage.contains("full") ? .red : .orange)
            }

            // 4. Join Button
            Button(action: joinSession) {
                HStack {
                    if isChecking {
                        ProgressView().controlSize(.small)
                    }
                    Text("Enter Session")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: 200)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(sessionCode.isEmpty || isChecking)
            .controlSize(.large)
        }
        .padding(50)
        .onAppear {
            // Auto-request permissions quietly in the background on launch
            store.requestAccess()

            // Sync the store's code with the saved one
            store.sessionCode = sessionCode
        }
    }

    func joinSession() {
        guard !sessionCode.isEmpty else { return }
        isChecking = true
        statusMessage = "Checking room capacity..."

        Task {
            // Check if the room has space
            let (allowed, message) = await store.firebaseManager.checkSessionAvailability(
                sessionCode: sessionCode)

            isChecking = false
            statusMessage = message

            if allowed {
                // Success! Update the store and unlock the main app
                store.sessionCode = sessionCode
                withAnimation {
                    isSessionActive = true
                }
            }
        }
    }
}
