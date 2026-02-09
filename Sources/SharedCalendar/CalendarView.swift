import SwiftUI

struct CalendarView: View {
    let myEvents: [SharedEvent]
    let partnerEvents: [SharedEvent]
    @Binding var selectedDate: Date?

    // Helper to get the days in the current month
    private var daysInMonth: [Date] {
        let calendar = Calendar.current
        let now = Date()

        // Start from the 1st of this month
        let components = calendar.dateComponents([.year, .month], from: now)
        let startOfMonth = calendar.date(from: components)!

        // Get range of days
        let range = calendar.range(of: .day, in: .month, for: startOfMonth)!

        return range.compactMap { day -> Date? in
            return calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)
        }
    }

    var body: some View {
        VStack {
            // Month Header
            Text(Date().formatted(.dateTime.month(.wide).year()))
                .font(.title2)
                .bold()
                .padding(.bottom)

            // The Grid
            let columns = Array(repeating: GridItem(.flexible()), count: 7)

            LazyVGrid(columns: columns, spacing: 15) {
                // Weekday Headers
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                    Text(day).font(.caption).bold().foregroundColor(.secondary)
                }

                // Days
                ForEach(daysInMonth, id: \.self) { date in
                    DayCell(
                        date: date,
                        myEvents: myEvents,
                        partnerEvents: partnerEvents,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate ?? Date())
                    )
                    .onTapGesture {
                        selectedDate = date
                    }
                }
            }
        }
        .padding()
    }

    private var calendar: Calendar { Calendar.current }
}

struct DayCell: View {
    let date: Date
    let myEvents: [SharedEvent]
    let partnerEvents: [SharedEvent]
    let isSelected: Bool

    var body: some View {
        VStack {
            Text(date.formatted(.dateTime.day()))
                .font(.body)
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundColor(isSelected ? .white : .primary)

            // Dots Container
            HStack(spacing: 4) {
                if hasEvent(in: myEvents) {
                    Circle().fill(Color.blue).frame(width: 5, height: 5)
                }
                if hasEvent(in: partnerEvents) {
                    Circle().fill(Color.orange).frame(width: 5, height: 5)
                }
            }
        }
        .frame(height: 40)
        .frame(maxWidth: .infinity)
        .background(isSelected ? Color.blue.opacity(0.8) : Color.clear)
        .cornerRadius(8)
        .contentShape(Rectangle())  // Makes the whole cell tappable
    }

    private func hasEvent(in events: [SharedEvent]) -> Bool {
        return events.contains { event in
            Calendar.current.isDate(event.startDate, inSameDayAs: date)
        }
    }
}
