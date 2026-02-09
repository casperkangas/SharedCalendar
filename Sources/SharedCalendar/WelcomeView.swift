import SwiftUI

struct WelcomeView: View {
    @Binding var isSessionActive: Bool
    @ObservedObject var store: CalendarStore
    @AppStorage("saved_session_code") private var sessionCode: String = ""
    @State private var statusMessage: String = ""
    @State private var isChecking: Bool = false

    private var userName: String { NSUserName() }

    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 5) {
                Text("Hello, \(userName).")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text("Ready to coordinate?")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 10) {
                Text("SECRET CODE")
                    .font(.caption).fontWeight(.bold).foregroundColor(.gray)
                TextField("e.g. OurTrip2026", text: $sessionCode)
                    .textFieldStyle(.plain)
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12).stroke(
                            Color.gray.opacity(0.3), lineWidth: 1))
            }
            .frame(maxWidth: 300)

            #if DEBUG
                if let devName = store.firebaseManager.getDevUserName() {
                    Button(action: { store.firebaseManager.debugCycleIdentity() }) {
                        Label("Dev: \(devName)", systemImage: "person.2.badge.gearshape.fill")
                    }
                    .tint(.purple)
                }
            #endif

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(statusMessage.contains("full") ? .red : .orange)
            }

            Button(action: joinSession) {
                HStack {
                    if isChecking { ProgressView().controlSize(.small) }
                    Text("Enter Session")
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
            store.requestAccess()
            store.sessionCode = sessionCode
        }
    }

    func joinSession() {
        guard !sessionCode.isEmpty else { return }
        isChecking = true
        statusMessage = "Checking..."
        Task {
            let (allowed, message) = await store.firebaseManager.checkSessionAvailability(
                sessionCode: sessionCode)
            isChecking = false
            statusMessage = message
            if allowed {
                store.sessionCode = sessionCode
                withAnimation { isSessionActive = true }
            }
        }
    }
}
