import SwiftUI

struct CalendarView: View {
    let myEvents: [SharedEvent]
    let partnerEvents: [SharedEvent]
    @Binding var selectedDate: Date?

    // Toggle: Month vs Week
    let mode: String  // "Month" or "Week"
    @Binding var visibleDate: Date  // The date controlling the view (e.g. first of month)

    private var daysToShow: [Date] {
        let calendar = Calendar.current

        if mode == "Month" {
            // Get all days in the current visible month
            let interval = calendar.dateInterval(of: .month, for: visibleDate)!
            let range = calendar.range(of: .day, in: .month, for: visibleDate)!

            // Adjust to start on Sunday/Monday depending on locale if needed,
            // but for simple grid, just listing days is fine.
            // Let's make it a nice square grid including padding days.

            let startOfMonth = interval.start
            let weekday = calendar.component(.weekday, from: startOfMonth)  // 1=Sun
            let startOffset = weekday - 1
            let startDate = calendar.date(byAdding: .day, value: -startOffset, to: startOfMonth)!

            // 6 weeks * 7 days = 42 days grid usually covers everything
            return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: startDate) }
        } else {
            // Week View: 7 days surrounding the visible date
            let startOfWeek = calendar.date(
                from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: visibleDate))!
            return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
        }
    }

    var body: some View {
        VStack {
            // Header: Month Name & Arrows
            HStack {
                Button(action: { moveDate(by: -1) }) { Image(systemName: "chevron.left") }

                Spacer()
                Text(
                    visibleDate.formatted(
                        mode == "Month" ? .dateTime.month(.wide).year() : .dateTime.month().day())
                )
                .font(.headline)
                Spacer()

                Button(action: { moveDate(by: 1) }) { Image(systemName: "chevron.right") }
            }
            .padding(.bottom, 10)

            // Days Header
            let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            HStack {
                ForEach(days, id: \.self) { day in
                    Text(day).frame(maxWidth: .infinity).font(.caption).bold().foregroundColor(
                        .secondary)
                }
            }

            // Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                ForEach(daysToShow, id: \.self) { date in
                    DayCell(
                        date: date,
                        myEvents: myEvents,
                        partnerEvents: partnerEvents,
                        isSelected: Calendar.current.isDate(
                            date, inSameDayAs: selectedDate ?? Date.distantPast),
                        isCurrentMonth: Calendar.current.isDate(
                            date, equalTo: visibleDate, toGranularity: .month)
                    )
                    .onTapGesture {
                        selectedDate = date
                        if mode == "Month"
                            && !Calendar.current.isDate(
                                date, equalTo: visibleDate, toGranularity: .month)
                        {
                            visibleDate = date
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }

    func moveDate(by value: Int) {
        let calendar = Calendar.current
        if let newDate = calendar.date(
            byAdding: mode == "Month" ? .month : .weekOfYear, value: value, to: visibleDate)
        {
            visibleDate = newDate
        }
    }
}

struct DayCell: View {
    let date: Date
    let myEvents: [SharedEvent]
    let partnerEvents: [SharedEvent]
    let isSelected: Bool
    let isCurrentMonth: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(date.formatted(.dateTime.day()))
                .font(.system(size: 14))
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundColor(
                    isSelected ? .white : (isCurrentMonth ? .primary : .gray.opacity(0.5))
                )
                .frame(width: 28, height: 28)
                .background(isSelected ? Color.blue : Color.clear)
                .clipShape(Circle())

            HStack(spacing: 3) {
                if hasEvent(in: myEvents) { Circle().fill(Color.blue).frame(width: 4, height: 4) }
                if hasEvent(in: partnerEvents) {
                    Circle().fill(Color.orange).frame(width: 4, height: 4)
                }
            }
        }
        .frame(height: 45)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private func hasEvent(in events: [SharedEvent]) -> Bool {
        return events.contains { Calendar.current.isDate($0.startDate, inSameDayAs: date) }
    }
}
