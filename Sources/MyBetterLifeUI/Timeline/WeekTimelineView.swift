import SwiftUI
import MyBetterLifeCore

/// 7-day interactive Week Timeline with shared hour gutter, all-day strip,
/// overlap layout per day, and drag/tap creation on any column.
public struct WeekTimelineView: View {
    public let anchorDate: Date
    public let store: PlannerStore
    public let categoryFilterID: UUID?
    public let selectedItem: SelectedItemRef?
    public let onSelectDay: (Date) -> Void
    public let onCreateTimedBlock: (_ day: Date, _ startMinute: Int, _ endMinute: Int) -> Void
    public let onSelectOccurrence: (DayOccurrence) -> Void
    public let onToggleComplete: (DayOccurrence) -> Void

    @State private var hasScrolledInitially: Bool = false
    private let hourHeight = AppTheme.weekHourHeight

    public init(
        anchorDate: Date,
        store: PlannerStore,
        categoryFilterID: UUID?,
        selectedItem: SelectedItemRef?,
        onSelectDay: @escaping (Date) -> Void,
        onCreateTimedBlock: @escaping (_ day: Date, _ startMinute: Int, _ endMinute: Int) -> Void,
        onSelectOccurrence: @escaping (DayOccurrence) -> Void,
        onToggleComplete: @escaping (DayOccurrence) -> Void
    ) {
        self.anchorDate = anchorDate
        self.store = store
        self.categoryFilterID = categoryFilterID
        self.selectedItem = selectedItem
        self.onSelectDay = onSelectDay
        self.onCreateTimedBlock = onCreateTimedBlock
        self.onSelectOccurrence = onSelectOccurrence
        self.onToggleComplete = onToggleComplete
    }

    private var days: [Date] {
        TimelineMath.weekDays(containing: anchorDate)
    }

    public var body: some View {
        let dayOccurrencesMap: [Date: [DayOccurrence]] = Dictionary(
            uniqueKeysWithValues: days.map { day in
                (day, RecurrenceEngine.occurrences(
                    on: day,
                    blocks: store.blocks,
                    seriesList: store.seriesList,
                    notes: store.notes,
                    categories: store.categories,
                    attachments: store.attachments,
                    categoryFilterID: categoryFilterID
                ))
            }
        )

        VStack(spacing: 0) {
            // 7-day header strip
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: AppTheme.timeGutterWidth, height: 1)

                ForEach(days, id: \.self) { day in
                    let isToday = Calendar.current.isDateInToday(day)
                    let isSelected = Calendar.current.isDate(day, inSameDayAs: anchorDate)
                    Button {
                        onSelectDay(day)
                    } label: {
                        VStack(spacing: 3) {
                            Text(AppTheme.shortWeekday(day))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(isToday ? AppTheme.nowIndicatorColor : .secondary)
                            Text(AppTheme.dayNumber(day))
                                .font(.callout.weight(.bold))
                                .foregroundStyle(
                                    isToday ? .white : (isSelected ? Color.accentColor : .primary)
                                )
                                .frame(width: 28, height: 28)
                                .background {
                                    if isToday {
                                        Circle().fill(AppTheme.nowIndicatorColor)
                                    } else if isSelected {
                                        Circle().fill(Color.accentColor.opacity(0.14))
                                    }
                                }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .background(AppTheme.canvasBackground)
            .overlay(alignment: .bottom) {
                Rectangle().fill(AppTheme.hairline).frame(height: 0.75)
            }

            // Compact All-Day row across the week (only shown if any day has all-day items)
            let hasAnyAllDay = days.contains { !(dayOccurrencesMap[$0]?.filter { $0.isAllDay }.isEmpty ?? true) }
            if hasAnyAllDay {
                HStack(alignment: .center, spacing: 0) {
                    Text(L10n.allDay)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.leading, 12)
                        .padding(.trailing, 8)
                        .frame(width: AppTheme.timeGutterWidth, alignment: .trailing)

                    ForEach(days, id: \.self) { day in
                        let allDayItems = (dayOccurrencesMap[day] ?? []).filter { $0.isAllDay }
                        VStack(spacing: 3) {
                            ForEach(allDayItems) { occ in
                                let accent = Color(hex: occ.category?.colorHex ?? AppTheme.defaultAccentHex)
                                Text(occ.title.isEmpty ? L10n.untitledBlock : occ.title)
                                    .font(.caption2.weight(.semibold))
                                    .lineLimit(1)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 4))
                                    .overlay(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 2).fill(accent).frame(width: 2.5)
                                    }
                                    .onTapGesture {
                                        onSelectOccurrence(occ)
                                    }
                            }
                        }
                        .padding(.horizontal, 2)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .background(AppTheme.secondarySurface.opacity(0.4))
                .overlay(alignment: .bottom) {
                    Rectangle().fill(AppTheme.hairline).frame(height: 0.75)
                }
            }

            // Scrollable 7-column hourly grid
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    ZStack(alignment: .topLeading) {
                        VStack(spacing: 0) {
                            ForEach(0..<24, id: \.self) { hour in
                                Color.clear
                                    .frame(height: hourHeight)
                                    .id("week-hour-\(hour)")
                            }
                        }
                        .allowsHitTesting(false)

                        HStack(alignment: .top, spacing: 0) {
                            // Time gutter
                            ZStack(alignment: .topTrailing) {
                                ForEach(1..<24, id: \.self) { hour in
                                    Text(TimelineMath.formatHourLabel(hour))
                                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                                        .foregroundStyle(.secondary)
                                        .padding(.trailing, 8)
                                        .offset(y: CGFloat(hour) * hourHeight - 6)
                                }
                            }
                            .frame(width: AppTheme.timeGutterWidth, height: hourHeight * 24, alignment: .topTrailing)

                            // 7 day columns
                            ForEach(days, id: \.self) { day in
                                WeekDayColumnView(
                                    day: day,
                                    hourHeight: hourHeight,
                                    occurrences: (dayOccurrencesMap[day] ?? []).filter { !$0.isAllDay },
                                    selectedItem: selectedItem,
                                    onCreateTimedBlock: { s, e in onCreateTimedBlock(day, s, e) },
                                    onSelectOccurrence: onSelectOccurrence,
                                    onToggleComplete: onToggleComplete
                                )
                            }
                        }
                    }
                    .frame(height: hourHeight * 24)
                    .padding(.vertical, 6)
                }
                .onAppear {
                    guard !hasScrolledInitially else { return }
                    hasScrolledInitially = true
                    DispatchQueue.main.async {
                        proxy.scrollTo("week-hour-7", anchor: .top)
                    }
                }
            }
        }
        .background(AppTheme.canvasBackground)
    }
}

private struct WeekDayColumnView: View {
    let day: Date
    let hourHeight: CGFloat
    let occurrences: [DayOccurrence]
    let selectedItem: SelectedItemRef?
    let onCreateTimedBlock: (_ startMinute: Int, _ endMinute: Int) -> Void
    let onSelectOccurrence: (DayOccurrence) -> Void
    let onToggleComplete: (DayOccurrence) -> Void

    @State private var dragStartMin: Int? = nil
    @State private var dragEndMin: Int? = nil

    var body: some View {
        GeometryReader { geo in
            let colWidth = max(36, geo.size.width)
            let layoutInputs = occurrences.map { occ in
                TimelineLayoutInput(
                    id: occ.id,
                    startMinute: TimelineMath.minuteOfDay(for: occ.startDate, on: day),
                    endMinute: TimelineMath.minuteOfDay(for: occ.endDate, on: day)
                )
            }
            let placements = OverlapLayoutEngine.layout(items: layoutInputs)

            ZStack(alignment: .topLeading) {
                // Column border & hourly lines
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(AppTheme.hairline.opacity(0.6))
                        .frame(width: 0.75, height: hourHeight * 24)

                    ForEach(0..<24, id: \.self) { hour in
                        Rectangle()
                            .fill(AppTheme.hairline.opacity(0.75))
                            .frame(height: 0.5)
                            .offset(y: CGFloat(hour) * hourHeight)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { location in
                    let start = TimelineMath.minuteOfDay(forY: Double(location.y), hourHeight: Double(hourHeight))
                    let safeStart = min(start, TimelineMath.minutesPerDay - 60)
                    onCreateTimedBlock(safeStart, safeStart + 60)
                }
                #if os(macOS)
                .gesture(
                    DragGesture(minimumDistance: 6, coordinateSpace: .named("weekCol-\(day.timeIntervalSince1970)"))
                        .onChanged { value in
                            dragStartMin = TimelineMath.minuteOfDay(forY: Double(value.startLocation.y), hourHeight: Double(hourHeight))
                            dragEndMin = TimelineMath.minuteOfDay(forY: Double(value.location.y), hourHeight: Double(hourHeight))
                        }
                        .onEnded { value in
                            defer { dragStartMin = nil; dragEndMin = nil }
                            let s = TimelineMath.minuteOfDay(forY: Double(value.startLocation.y), hourHeight: Double(hourHeight))
                            let e = TimelineMath.minuteOfDay(forY: Double(value.location.y), hourHeight: Double(hourHeight))
                            let low = min(s, e)
                            let high = max(max(s, e), low + 30)
                            onCreateTimedBlock(low, min(high, TimelineMath.minutesPerDay))
                        }
                )
                #endif

                if let s = dragStartMin, let e = dragEndMin {
                    let low = min(s, e)
                    let high = max(max(s, e), low + 15)
                    let y = CGFloat(TimelineMath.yPosition(forMinute: low, hourHeight: Double(hourHeight)))
                    let h = max(18, CGFloat(TimelineMath.yPosition(forMinute: high - low, hourHeight: Double(hourHeight))))
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.accentColor.opacity(0.18))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.accentColor, lineWidth: 1.2)
                        }
                        .frame(width: max(20, colWidth - 4), height: h)
                        .offset(x: 2, y: y)
                        .allowsHitTesting(false)
                }

                ForEach(occurrences) { occ in
                    if let placement = placements[occ.id] {
                        let gap: CGFloat = 2
                        let w = max(20, (colWidth - gap * CGFloat(placement.totalColumns + 1)) / CGFloat(placement.totalColumns))
                        let x = gap + CGFloat(placement.column) * (w + gap)
                        let y = CGFloat(TimelineMath.yPosition(forMinute: placement.startMinute, hourHeight: Double(hourHeight)))
                        let h = max(20, CGFloat(TimelineMath.yPosition(forMinute: max(15, placement.endMinute - placement.startMinute), hourHeight: Double(hourHeight))) - 2)

                        TimelineBlockCard(
                            occurrence: occ,
                            height: h,
                            isSelected: isOccurrenceSelected(occ),
                            isCompactWeekStyle: true,
                            onToggleComplete: { onToggleComplete(occ) }
                        )
                        .frame(width: w, height: h)
                        .offset(x: x, y: y + 1)
                        .onTapGesture {
                            onSelectOccurrence(occ)
                        }
                    }
                }

                if Calendar.current.isDateInToday(day) {
                    CurrentTimeIndicator(hourHeight: hourHeight, showDot: true)
                        .frame(width: colWidth)
                }
            }
            .coordinateSpace(name: "weekCol-\(day.timeIntervalSince1970)")
        }
        .frame(maxWidth: .infinity)
        .frame(height: hourHeight * 24)
    }

    private func isOccurrenceSelected(_ occ: DayOccurrence) -> Bool {
        guard let selectedItem else { return false }
        switch selectedItem {
        case .block(let id):
            return occ.block?.id == id
        case .virtualOccurrence(let sID, let dStart):
            return occ.block == nil && occ.series?.id == sID && Calendar.current.isDate(occ.dayStart, inSameDayAs: dStart)
        }
    }
}
