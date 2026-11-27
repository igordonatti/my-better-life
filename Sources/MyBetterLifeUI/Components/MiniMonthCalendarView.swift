import SwiftUI
import MyBetterLifeCore

/// Drag-and-drop payload encoder/decoder for dragging a day from the Mini Calendar onto the Timeline.
public enum DayDragPayload {
    public static let prefix = "mbl-day:"

    public static func encode(_ date: Date) -> String {
        let dayStart = Calendar.current.startOfDay(for: date)
        return "\(prefix)\(Int(dayStart.timeIntervalSince1970))"
    }

    public static func decode(_ string: String) -> Date? {
        guard string.hasPrefix(prefix) else { return nil }
        let raw = String(string.dropFirst(prefix.count))
        guard let ts = TimeInterval(raw) else { return nil }
        return Calendar.current.startOfDay(for: Date(timeIntervalSince1970: ts))
    }
}

/// Compact Apple-native monthly calendar with day selection, drag-to-split on macOS, and event indicator dots.
public struct MiniMonthCalendarView: View {
    @Binding public var selectedDate: Date
    @Binding public var displayedMonth: Date
    public let secondaryDate: Date?
    public let activeDays: Set<Date>
    public let embedded: Bool
    public let onOpenSecondaryDate: ((Date) -> Void)?

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = AppTheme.ptBRLocale
        cal.firstWeekday = 2 // Monday
        return cal
    }()

    private let weekdayHeaders = ["S", "T", "Q", "Q", "S", "S", "D"]
    private let columns = Array(repeating: GridItem(.flexible(minimum: 22), spacing: 2), count: 7)

    public init(
        selectedDate: Binding<Date>,
        displayedMonth: Binding<Date>,
        secondaryDate: Date? = nil,
        activeDays: Set<Date>,
        embedded: Bool = false,
        onOpenSecondaryDate: ((Date) -> Void)? = nil
    ) {
        self._selectedDate = selectedDate
        self._displayedMonth = displayedMonth
        self.secondaryDate = secondaryDate
        self.activeDays = activeDays
        self.embedded = embedded
        self.onOpenSecondaryDate = onOpenSecondaryDate
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Month header + chevron navigation
            HStack(spacing: 4) {
                Text(AppTheme.monthYearTitle(displayedMonth))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 4)
                HStack(spacing: 2) {
                    Button {
                        shiftMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.caption.weight(.semibold))
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        shiftMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(.secondary)
            }

            // Weekday initials
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(weekdayHeaders.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day cells
            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(Array(monthGridDates().enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(for: day)
                    } else {
                        Color.clear
                            .frame(height: 26)
                    }
                }
            }
        }
        .padding(embedded ? 0 : 10)
        .frame(maxWidth: .infinity)
        .background {
            if !embedded {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.secondarySurface.opacity(0.65))
            }
        }
    }

    private func dayCell(for day: Date) -> some View {
        let dayStart = calendar.startOfDay(for: day)
        let isSelected = calendar.isDate(dayStart, inSameDayAs: selectedDate)
        let isSecondary = secondaryDate.map { calendar.isDate(dayStart, inSameDayAs: $0) } ?? false
        let isToday = calendar.isDateInToday(dayStart)
        let hasItems = activeDays.contains(dayStart)

        return VStack(spacing: 2) {
            Text("\(calendar.component(.day, from: dayStart))")
                .font(.caption.weight(isSelected || isSecondary || isToday ? .semibold : .regular))
                .foregroundStyle(
                    isSelected
                        ? Color.white
                        : (isSecondary ? Color.accentColor : (isToday ? Color.accentColor : Color.primary))
                )
                .frame(width: 24, height: 24)
                .background {
                    if isSelected {
                        Circle().fill(isToday ? AppTheme.nowIndicatorColor : Color.accentColor)
                    } else if isSecondary {
                        Circle()
                            .fill(Color.accentColor.opacity(0.16))
                            .overlay {
                                Circle().strokeBorder(Color.accentColor, lineWidth: 1.2)
                            }
                    } else if isToday {
                        Circle().fill(Color.accentColor.opacity(0.14))
                    }
                }

            Circle()
                .fill(hasItems ? (isSelected ? Color.accentColor : Color.secondary.opacity(0.55)) : Color.clear)
                .frame(width: 3.5, height: 3.5)
        }
        .frame(maxWidth: .infinity, minHeight: 28)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedDate = dayStart
        }
        #if os(macOS)
        .onDrag {
            NSItemProvider(object: DayDragPayload.encode(dayStart) as NSString)
        } preview: {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Text(AppTheme.fullDate(dayStart))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppTheme.canvasBackground, in: Capsule())
            .overlay {
                Capsule().strokeBorder(Color.accentColor.opacity(0.45), lineWidth: 1)
            }
        }
        .contextMenu {
            if let onOpenSecondaryDate, !isSelected {
                Button {
                    onOpenSecondaryDate(dayStart)
                } label: {
                    Label("Abrir ao lado", systemImage: "rectangle.split.2x1")
                }
            }
        }
        #endif
    }

    private func shiftMonth(by delta: Int) {
        if let updated = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = updated
        }
    }

    private func monthGridDates() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else {
            return []
        }
        let firstDay = monthInterval.start
        let weekday = calendar.component(.weekday, from: firstDay)
        let leadingEmpty = (weekday + 5) % 7 // Monday = 0 leading blanks
        let daysInMonth = calendar.range(of: .day, in: .month, for: firstDay)?.count ?? 30

        var grid: [Date?] = Array(repeating: nil, count: leadingEmpty)
        for offset in 0..<daysInMonth {
            if let d = calendar.date(byAdding: .day, value: offset, to: firstDay) {
                grid.append(d)
            }
        }
        return grid
    }
}
