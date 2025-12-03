import SwiftUI
import UIKit

struct CalendarView: View {
    let onMenuTapped: () -> Void
    let onOpenSchedule: () -> Void   // Para abrir la pantalla de Schedule

    // Horario cargado desde el mismo provider híbrido que usa ScheduleViewModel
    @State private var schedule: Schedule = .empty

    // Mes actual y día seleccionado
    @State private var currentMonth: Date = Date()
    @State private var selectedDate: Date = Date()

    // 👉 Usa el provider unificado (cache + remoto) en vez de ScheduleLocalStore
    private let scheduleProvider = UnifiedHybridDataProviders.shared.scheduleProvider

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView {
                VStack(spacing: 24) {
                    monthHeader
                    monthGrid
                    dayDetailSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .background(UI.neutralLight)
        }
        .onAppear {
            loadSchedule()
            alignSelectedDateToCurrentMonth()
        }
        .navigationBarHidden(true)
    }

    // MARK: - Cargar horario

    private func loadSchedule() {
        Task { @MainActor in
            let loaded = await scheduleProvider.loadSchedule()
            self.schedule = loaded
            print("📂 CalendarView -> loaded schedule with \(loaded.days.count) days")
        }
    }

    private func alignSelectedDateToCurrentMonth() {
        let today = Date()
        let calendar = Calendar.current
        if calendar.isDate(today, equalTo: currentMonth, toGranularity: .month) {
            selectedDate = today
        } else if let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)) {
            selectedDate = firstDay
        }
    }

    // MARK: - Header superior

    private var topBar: some View {
        HStack {
            Button(action: onMenuTapped) {
                Image(systemName: "line.3.horizontal")
                    .foregroundColor(UI.navy)
                    .font(.title2)
            }

            Spacer()

            Text("Calendar")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(UI.navy)

            Spacer()

            Button(action: onOpenSchedule) {
                Image(systemName: "pencil")
                    .foregroundColor(UI.navy)
                    .font(.title2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color(hex: "#B8C8DB"))
    }

    // MARK: - Encabezado mes + flechas

    private var monthHeader: some View {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM yyyy".uppercased()

        return VStack(alignment: .center, spacing: 8) {
            HStack {
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }

                Spacer()

                Text(formatter.string(from: currentMonth))
                    .font(.headline)
                    .foregroundColor(UI.navy)

                Spacer()

                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
            }

            HStack {
                ForEach(weekdaySymbolsShort(), id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(UI.muted)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func changeMonth(by offset: Int) {
        if let newMonth = Calendar.current.date(
            byAdding: .month,
            value: offset,
            to: currentMonth.startOfMonth()
        ) {
            currentMonth = newMonth
            alignSelectedDateToCurrentMonth()
        }
    }

    // MARK: - Grid mensual

    private var monthGrid: some View {
        let days = daysForMonth(currentMonth)

        return VStack(spacing: 8) {
            ForEach(0..<days.count / 7, id: \.self) { weekIndex in
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { dayIndex in
                        let index = weekIndex * 7 + dayIndex
                        let date = days[index]
                        dayCell(for: date)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(for date: Date?) -> some View {
        let calendar = Calendar.current

        if let date {
            let isToday = calendar.isDateInToday(date)
            let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
            let sessions = sessions(for: date)

            Button {
                selectedDate = date
            } label: {
                VStack(spacing: 4) {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.subheadline)
                        .fontWeight(isSelected ? .bold : .regular)
                        .foregroundColor(isSelected ? Color.white : UI.navy)
                        .frame(maxWidth: .infinity)

                    if !sessions.isEmpty {
                        VStack(spacing: 2) {
                            ForEach(0..<min(sessions.count, 3), id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 2)
                                    .frame(height: 3)
                                    .foregroundColor(isSelected ? Color.white.opacity(0.9) : UI.primary)
                            }
                        }
                    } else {
                        Spacer().frame(height: 6)
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    ZStack {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(UI.primary)
                        } else if isToday {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(UI.primary, lineWidth: 1)
                        }
                    }
                )
            }
            .buttonStyle(.plain)
        } else {
            Color.clear
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    // MARK: - Detalle del día

    private var dayDetailSection: some View {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE d MMM"

        let sessionsToday = sessions(for: selectedDate)

        return VStack(alignment: .leading, spacing: 12) {
            Text(formatter.string(from: selectedDate).uppercased())
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(UI.navy)

            if sessionsToday.isEmpty {
                Text("No classes on this day.")
                    .font(.footnote)
                    .foregroundColor(UI.muted)
            } else {
                ForEach(sessionsToday.indices, id: \.self) { idx in
                    let s = sessionsToday[idx]

                    HStack(alignment: .top, spacing: 8) {
                        // 🕒 columna de horas
                        let timeRange: String = {
                            if let start = s.start, let end = s.end, !start.isEmpty, !end.isEmpty {
                                return "\(start) – \(end)"
                            } else if let start = s.start, !start.isEmpty {
                                return start
                            } else {
                                return "—"
                            }
                        }()

                        Text(timeRange)
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundColor(UI.navy)
                            .frame(width: 70, alignment: .leading)

                        // 📚 info de la clase
                        VStack(alignment: .leading, spacing: 4) {
                            Text(s.course)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(UI.navy)

                            if let loc = s.location, !loc.isEmpty {
                                Text(loc)
                                    .font(.caption)
                                    .foregroundColor(UI.muted)
                            }

                            if let notes = s.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.caption2)
                                    .foregroundColor(UI.muted)
                            }
                        }

                        Spacer()
                    }
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Helpers

    private func sessions(for date: Date) -> [ScheduleSession] {
        let calendar = Calendar.current
        let weekdayNumber = calendar.component(.weekday, from: date) // 1 = Sun ... 7 = Sat

        guard let weekdayEnum = Weekday(systemWeekday: weekdayNumber) else {
            return []
        }

        return schedule.days.first(where: { $0.weekday == weekdayEnum })?.sessions ?? []
    }

    private func weekdaySymbolsShort() -> [String] {
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "es_CO")
        calendar.firstWeekday = 2 // Monday

        let symbols = calendar.shortWeekdaySymbols
        let mondayIndex = (calendar.firstWeekday - 1 + 7) % 7
        let reordered = Array(symbols[mondayIndex...] + symbols[..<mondayIndex])
        return reordered.map { $0.uppercased() }
    }

    private func daysForMonth(_ month: Date) -> [Date?] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday

        let firstOfMonth = month.startOfMonth()
        let range = calendar.range(of: .day, in: .month, for: firstOfMonth) ?? (1..<31)
        let numDays = range.count

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth) // 1..7
        let weekdayIndex = (firstWeekday - calendar.firstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: weekdayIndex)

        for day in 0..<numDays {
            if let date = calendar.date(byAdding: .day, value: day, to: firstOfMonth) {
                days.append(date)
            }
        }

        while days.count % 7 != 0 {
            days.append(nil)
        }

        return days
    }
}

// MARK: - Extensiones

fileprivate extension Date {
    func startOfMonth() -> Date {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: comps) ?? self
    }
}

fileprivate extension Weekday {
    init?(systemWeekday: Int) {
        switch systemWeekday {
        case 1: self = .sunday
        case 2: self = .monday
        case 3: self = .tuesday
        case 4: self = .wednesday
        case 5: self = .thursday
        case 6: self = .friday
        case 7: self = .saturday
        default:
            return nil
        }
    }
}
