import SwiftUI
import MyBetterLifeCore

#if os(macOS)
import AppKit
#endif

/// Interactive Google/Apple Calendar-style Day Timeline with:
/// - Drag-to-paint time selection (15-min snap)
/// - Drag-to-move and drag-edge-to-resize blocks
/// - Overlap column layout
/// - All-day section at the top
/// - Live current-time indicator
public struct DayTimelineView: View {
    public let date: Date
    public let occurrences: [DayOccurrence]
    public let selectedItem: SelectedItemRef?
    public let selectedItems: Set<SelectedItemRef>
    public let globalNotes: [StandaloneNote]
    public let canPaste: Bool
    public let isCompactSideBySide: Bool
    public let onCloseSplitDay: (() -> Void)?
    public let onCreateTimedBlock: (_ startMinute: Int, _ endMinute: Int) -> Void
    public let onCreateAllDayBlock: () -> Void
    public let onSelectOccurrence: (DayOccurrence, _ additive: Bool) -> Void
    public let onToggleComplete: (DayOccurrence) -> Void
    public let onMoveOrResize: (DayOccurrence, _ newStart: Date, _ newEnd: Date) -> Void
    public let onOpenInNewWindow: ((DayOccurrence) -> Void)?
    public let onCopyOccurrence: ((DayOccurrence) -> Void)?
    public let onPasteHere: (() -> Void)?
    public let onClearMultiSelection: (() -> Void)?
    public let onStartFocus: ((DayOccurrence, FocusTimerMode) -> Void)?
    public let onChangeReminder: ((DayOccurrence, Int?) -> Void)?
    public let onQuickRecurrence: ((DayOccurrence, RecurrenceRuleType?, WeekdayMask) -> Void)?
    public let onOpenCustomRecurrence: ((DayOccurrence) -> Void)?
    public let onPromoteToGlobal: ((DayOccurrence) -> Void)?
    public let onLinkToGlobal: ((DayOccurrence, StandaloneNote) -> Void)?
    public let onUnlinkGlobal: ((DayOccurrence) -> Void)?
    public let onDeleteOccurrence: ((DayOccurrence) -> Void)?

    @State private var dragCreateStartMinute: Int? = nil
    @State private var dragCreateCurrentMinute: Int? = nil
    @State private var activeBlockGesture: ActiveBlockGesture? = nil
    @State private var hasScrolledInitially: Bool = false

    private let hourHeight = AppTheme.hourHeight

    private var gridSpaceName: String {
        "dayTimelineGrid-\(Int(Calendar.current.startOfDay(for: date).timeIntervalSince1970))"
    }

    private struct ActiveBlockGesture {
        enum Kind {
            case move
            case resizeTop
            case resizeBottom
        }
        let occurrenceID: String
        let kind: Kind
        let initialCursorY: Double
        let originalStartMinute: Int
        let originalEndMinute: Int
        var currentStartMinute: Int
        var currentEndMinute: Int
    }

    public init(
        date: Date,
        occurrences: [DayOccurrence],
        selectedItem: SelectedItemRef?,
        selectedItems: Set<SelectedItemRef> = [],
        globalNotes: [StandaloneNote] = [],
        canPaste: Bool = false,
        isCompactSideBySide: Bool = false,
        onCloseSplitDay: (() -> Void)? = nil,
        onCreateTimedBlock: @escaping (_ startMinute: Int, _ endMinute: Int) -> Void,
        onCreateAllDayBlock: @escaping () -> Void,
        onSelectOccurrence: @escaping (DayOccurrence, _ additive: Bool) -> Void,
        onToggleComplete: @escaping (DayOccurrence) -> Void,
        onMoveOrResize: @escaping (DayOccurrence, _ newStart: Date, _ newEnd: Date) -> Void,
        onOpenInNewWindow: ((DayOccurrence) -> Void)? = nil,
        onCopyOccurrence: ((DayOccurrence) -> Void)? = nil,
        onPasteHere: (() -> Void)? = nil,
        onClearMultiSelection: (() -> Void)? = nil,
        onStartFocus: ((DayOccurrence, FocusTimerMode) -> Void)? = nil,
        onChangeReminder: ((DayOccurrence, Int?) -> Void)? = nil,
        onQuickRecurrence: ((DayOccurrence, RecurrenceRuleType?, WeekdayMask) -> Void)? = nil,
        onOpenCustomRecurrence: ((DayOccurrence) -> Void)? = nil,
        onPromoteToGlobal: ((DayOccurrence) -> Void)? = nil,
        onLinkToGlobal: ((DayOccurrence, StandaloneNote) -> Void)? = nil,
        onUnlinkGlobal: ((DayOccurrence) -> Void)? = nil,
        onDeleteOccurrence: ((DayOccurrence) -> Void)? = nil
    ) {
        self.date = date
        self.occurrences = occurrences
        self.selectedItem = selectedItem
        self.selectedItems = selectedItems
        self.globalNotes = globalNotes
        self.canPaste = canPaste
        self.isCompactSideBySide = isCompactSideBySide
        self.onCloseSplitDay = onCloseSplitDay
        self.onCreateTimedBlock = onCreateTimedBlock
        self.onCreateAllDayBlock = onCreateAllDayBlock
        self.onSelectOccurrence = onSelectOccurrence
        self.onToggleComplete = onToggleComplete
        self.onMoveOrResize = onMoveOrResize
        self.onOpenInNewWindow = onOpenInNewWindow
        self.onCopyOccurrence = onCopyOccurrence
        self.onPasteHere = onPasteHere
        self.onClearMultiSelection = onClearMultiSelection
        self.onStartFocus = onStartFocus
        self.onChangeReminder = onChangeReminder
        self.onQuickRecurrence = onQuickRecurrence
        self.onOpenCustomRecurrence = onOpenCustomRecurrence
        self.onPromoteToGlobal = onPromoteToGlobal
        self.onLinkToGlobal = onLinkToGlobal
        self.onUnlinkGlobal = onUnlinkGlobal
        self.onDeleteOccurrence = onDeleteOccurrence
    }

    private var allDayOccurrences: [DayOccurrence] {
        occurrences.filter { $0.isAllDay }
    }

    private var timedOccurrences: [DayOccurrence] {
        occurrences.filter { !$0.isAllDay }
    }

    public var body: some View {
        VStack(spacing: 0) {
            dayHeader
            AllDayStripView(
                occurrences: allDayOccurrences,
                selectedItem: selectedItem,
                selectedItems: selectedItems,
                globalNotes: globalNotes,
                canPaste: canPaste,
                onSelect: onSelectOccurrence,
                onToggleComplete: onToggleComplete,
                onAddAllDay: onCreateAllDayBlock,
                onOpenInNewWindow: onOpenInNewWindow,
                onCopy: onCopyOccurrence,
                onPaste: onPasteHere,
                onQuickRecurrence: onQuickRecurrence,
                onOpenCustomRecurrence: onOpenCustomRecurrence,
                onPromoteToGlobal: onPromoteToGlobal,
                onLinkToGlobal: onLinkToGlobal,
                onUnlinkGlobal: onUnlinkGlobal,
                onDelete: onDeleteOccurrence
            )

            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    ZStack(alignment: .topLeading) {
                        // Invisible hour anchors for crisp auto-scrolling
                        VStack(spacing: 0) {
                            ForEach(0..<24, id: \.self) { hour in
                                Color.clear
                                    .frame(height: hourHeight)
                                    .id("hour-\(hour)")
                            }
                        }
                        .allowsHitTesting(false)

                        HStack(alignment: .top, spacing: 0) {
                            timeGutter
                            interactiveGrid
                        }
                    }
                    .frame(height: hourHeight * 24)
                    .padding(.vertical, 8)
                }
                .background(AppTheme.canvasBackground)
                .onAppear {
                    guard !hasScrolledInitially else { return }
                    hasScrolledInitially = true
                    let targetHour: Int
                    if Calendar.current.isDateInToday(date) {
                        let currentHour = Calendar.current.component(.hour, from: Date())
                        targetHour = max(0, currentHour - 1)
                    } else {
                        targetHour = 7
                    }
                    DispatchQueue.main.async {
                        proxy.scrollTo("hour-\(targetHour)", anchor: .top)
                    }
                }
            }
        }
        .background(AppTheme.canvasBackground)
    }

    // MARK: - Day Header

    private var dayHeader: some View {
        let isToday = Calendar.current.isDateInToday(date)

        return HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(AppTheme.shortWeekday(date))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isToday ? AppTheme.nowIndicatorColor : .secondary)
                    .tracking(0.8)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(AppTheme.dayNumber(date))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(isToday ? AppTheme.nowIndicatorColor : .primary)

                    Text(AppTheme.monthYearTitle(date))
                        .font(.headline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

            Spacer(minLength: 8)

            if let onCloseSplitDay {
                Button(action: onCloseSplitDay) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Fechar dia ao lado")
            } else if !isCompactSideBySide {
                HStack(spacing: 6) {
                    Image(systemName: "hand.draw")
                        .font(.caption)
                    Text(L10n.dragHint)
                        .font(.caption)
                }
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppTheme.secondarySurface.opacity(0.6), in: Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(AppTheme.canvasBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.hairline)
                .frame(height: 0.75)
        }
    }

    // MARK: - Left Time Gutter

    private var timeGutter: some View {
        ZStack(alignment: .topTrailing) {
            ForEach(0..<24, id: \.self) { hour in
                if hour > 0 {
                    Text(TimelineMath.formatHourLabel(hour))
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 10)
                        .offset(y: CGFloat(hour) * hourHeight - 7)
                }
            }
        }
        .frame(width: AppTheme.timeGutterWidth, height: hourHeight * 24, alignment: .topTrailing)
    }

    // MARK: - Interactive Hourly Grid

    private var interactiveGrid: some View {
        GeometryReader { geo in
            let gridWidth = max(120, geo.size.width - 12)
            let layoutInputs = timedOccurrences.map { occ in
                TimelineLayoutInput(
                    id: occ.id,
                    startMinute: TimelineMath.minuteOfDay(for: occ.startDate, on: date),
                    endMinute: TimelineMath.minuteOfDay(for: occ.endDate, on: date)
                )
            }
            let placements = OverlapLayoutEngine.layout(items: layoutInputs)

            ZStack(alignment: .topLeading) {
                // Background grid lines + drag-to-paint gesture layer
                gridBackground
                    .contentShape(Rectangle())
                    .gesture(dragToPaintGesture)
                    #if os(macOS)
                    .onTapGesture {
                        onClearMultiSelection?()
                    }
                    .contextMenu {
                        if canPaste, let onPasteHere {
                            Button(action: onPasteHere) {
                                Label("Colar blocos neste dia (⌘V)", systemImage: "doc.on.clipboard")
                            }
                        }
                        Button {
                            onCreateAllDayBlock()
                        } label: {
                            Label("Adicionar bloco de dia inteiro", systemImage: "sun.max")
                        }
                    }
                    #else
                    .onTapGesture { location in
                        let startMin = TimelineMath.minuteOfDay(forY: Double(location.y), hourHeight: Double(hourHeight))
                        let clampedStart = min(startMin, TimelineMath.minutesPerDay - 60)
                        onCreateTimedBlock(clampedStart, clampedStart + 60)
                    }
                    #endif

                // Drag-to-paint ghost selection preview
                if let s = dragCreateStartMinute, let c = dragCreateCurrentMinute {
                    let startMin = min(s, c)
                    let endMin = max(max(s, c), startMin + 15)
                    dragSelectionGhost(startMinute: startMin, endMinute: endMin, width: gridWidth)
                }

                // Positioned timed blocks
                ForEach(timedOccurrences) { occ in
                    if let placement = placements[occ.id] {
                        positionedBlockView(
                            occurrence: occ,
                            placement: placement,
                            gridWidth: gridWidth
                        )
                    }
                }

                // Live current-time red indicator on Today
                if Calendar.current.isDateInToday(date) {
                    CurrentTimeIndicator(hourHeight: hourHeight)
                        .frame(width: gridWidth)
                }
            }
            .coordinateSpace(name: gridSpaceName)
            .padding(.trailing, 12)
        }
        .frame(height: hourHeight * 24)
    }

    private var gridBackground: some View {
        ZStack(alignment: .topLeading) {
            // Left vertical divider separating time gutter from grid
            Rectangle()
                .fill(AppTheme.hairline)
                .frame(width: 0.75, height: hourHeight * 24)

            ForEach(0..<24, id: \.self) { hour in
                Rectangle()
                    .fill(AppTheme.hairline)
                    .frame(height: 0.75)
                    .offset(y: CGFloat(hour) * hourHeight)

                Rectangle()
                    .fill(AppTheme.halfHourHairline)
                    .frame(height: 0.5)
                    .offset(y: (CGFloat(hour) + 0.5) * hourHeight)
            }
        }
    }

    private var dragToPaintGesture: some Gesture {
        #if os(macOS)
        DragGesture(minimumDistance: 6, coordinateSpace: .named(gridSpaceName))
            .onChanged { value in
                let startMin = TimelineMath.minuteOfDay(forY: Double(value.startLocation.y), hourHeight: Double(hourHeight))
                let currentMin = TimelineMath.minuteOfDay(forY: Double(value.location.y), hourHeight: Double(hourHeight))
                dragCreateStartMinute = startMin
                dragCreateCurrentMinute = currentMin
            }
            .onEnded { value in
                defer {
                    dragCreateStartMinute = nil
                    dragCreateCurrentMinute = nil
                }
                let startMin = TimelineMath.minuteOfDay(forY: Double(value.startLocation.y), hourHeight: Double(hourHeight))
                let endMin = TimelineMath.minuteOfDay(forY: Double(value.location.y), hourHeight: Double(hourHeight))
                let low = min(startMin, endMin)
                let high = max(max(startMin, endMin), low + 30)
                onCreateTimedBlock(low, min(high, TimelineMath.minutesPerDay))
            }
        #else
        LongPressGesture(minimumDuration: 0.22)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(gridSpaceName)))
            .onChanged { value in
                switch value {
                case .second(true, let drag?):
                    let startMin = TimelineMath.minuteOfDay(forY: Double(drag.startLocation.y), hourHeight: Double(hourHeight))
                    let currentMin = TimelineMath.minuteOfDay(forY: Double(drag.location.y), hourHeight: Double(hourHeight))
                    dragCreateStartMinute = startMin
                    dragCreateCurrentMinute = currentMin
                default:
                    break
                }
            }
            .onEnded { value in
                defer {
                    dragCreateStartMinute = nil
                    dragCreateCurrentMinute = nil
                }
                if case .second(true, let drag?) = value {
                    let startMin = TimelineMath.minuteOfDay(forY: Double(drag.startLocation.y), hourHeight: Double(hourHeight))
                    let endMin = TimelineMath.minuteOfDay(forY: Double(drag.location.y), hourHeight: Double(hourHeight))
                    let low = min(startMin, endMin)
                    let high = max(max(startMin, endMin), low + 30)
                    onCreateTimedBlock(low, min(high, TimelineMath.minutesPerDay))
                }
            }
        #endif
    }

    private func dragSelectionGhost(startMinute: Int, endMinute: Int, width: CGFloat) -> some View {
        let topY = CGFloat(TimelineMath.yPosition(forMinute: startMinute, hourHeight: Double(hourHeight)))
        let blockHeight = max(24, CGFloat(TimelineMath.yPosition(forMinute: endMinute - startMinute, hourHeight: Double(hourHeight))))

        return VStack(alignment: .leading, spacing: 2) {
            Text(L10n.newBlock)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
            Text("\(TimelineMath.formatMinute(startMinute)) – \(TimelineMath.formatMinute(endMinute)) · \(TimelineMath.formatDuration(minutes: endMinute - startMinute))")
                .font(.caption2.weight(.medium).monospacedDigit())
                .foregroundStyle(Color.accentColor.opacity(0.85))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(width: max(40, width - 8), height: blockHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.blockCornerRadius, style: .continuous)
                .fill(Color.accentColor.opacity(0.16))
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.blockCornerRadius, style: .continuous)
                .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
        }
        .offset(x: 4, y: topY)
        .allowsHitTesting(false)
    }

    private func positionedBlockView(
        occurrence: DayOccurrence,
        placement: TimelineLayoutPlacement,
        gridWidth: CGFloat
    ) -> some View {
        let isDraggingThis = activeBlockGesture?.occurrenceID == occurrence.id
        let displayStart = isDraggingThis ? activeBlockGesture!.currentStartMinute : placement.startMinute
        let displayEnd = isDraggingThis ? activeBlockGesture!.currentEndMinute : placement.endMinute

        let columnGap: CGFloat = 4
        let totalGap = columnGap * CGFloat(placement.totalColumns + 1)
        let colWidth = max(44, (gridWidth - totalGap) / CGFloat(placement.totalColumns))
        let xOffset = columnGap + CGFloat(placement.column) * (colWidth + columnGap)

        let topY = CGFloat(TimelineMath.yPosition(forMinute: displayStart, hourHeight: Double(hourHeight)))
        let blockHeight = max(
            24,
            CGFloat(TimelineMath.yPosition(forMinute: max(15, displayEnd - displayStart), hourHeight: Double(hourHeight))) - 2
        )

        let handleHeight: CGFloat = blockHeight < 36 ? 5 : 7
        let liveRangeText = isDraggingThis
            ? "\(TimelineMath.formatMinute(displayStart)) – \(TimelineMath.formatMinute(displayEnd))"
            : nil

        let isThisSelected = isOccurrenceSelected(occurrence)

        return TimelineBlockCard(
            occurrence: occurrence,
            height: blockHeight,
            isSelected: isThisSelected || isDraggingThis,
            overrideTimeRangeText: liveRangeText,
            onToggleComplete: {
                onToggleComplete(occurrence)
            }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            #if os(macOS)
            let mods = NSEvent.modifierFlags
            let additive = mods.contains(.command) || mods.contains(.shift)
            #else
            let additive = false
            #endif
            onSelectOccurrence(occurrence, additive)
        }
        .gesture(moveGesture(for: occurrence, placement: placement))
        .overlay(alignment: .top) {
            resizeHandle(edge: .top, occurrence: occurrence, placement: placement)
                .frame(height: handleHeight)
        }
        .overlay(alignment: .bottom) {
            resizeHandle(edge: .bottom, occurrence: occurrence, placement: placement)
                .frame(height: handleHeight)
        }
        .overlay(alignment: .top) {
            if let liveRangeText {
                let dur = max(15, displayEnd - displayStart)
                Text("\(liveRangeText) · \(TimelineMath.formatDuration(minutes: dur))")
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor, in: Capsule())
                    .offset(y: -24)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: colWidth, height: blockHeight)
        .offset(x: xOffset, y: topY + 1)
        .zIndex(isDraggingThis ? 10 : (isThisSelected ? 5 : 1))
        .contextMenu {
            BlockContextMenuContent(
                occurrence: occurrence,
                globalNotes: globalNotes,
                selectedCount: isThisSelected ? max(1, selectedItems.count) : 1,
                canPaste: canPaste,
                onToggleComplete: { onToggleComplete(occurrence) },
                onOpenInNewWindow: onOpenInNewWindow.map { handler in { handler(occurrence) } },
                onCopy: { onCopyOccurrence?(occurrence) },
                onPaste: onPasteHere,
                onStartFocus: { mode in onStartFocus?(occurrence, mode) },
                onChangeReminder: { mins in onChangeReminder?(occurrence, mins) },
                onQuickRecurrence: { rule, mask in onQuickRecurrence?(occurrence, rule, mask) },
                onOpenCustomRecurrence: { onOpenCustomRecurrence?(occurrence) },
                onPromoteToGlobal: { onPromoteToGlobal?(occurrence) },
                onLinkToGlobal: { global in onLinkToGlobal?(occurrence, global) },
                onUnlinkGlobal: { onUnlinkGlobal?(occurrence) },
                onDelete: { onDeleteOccurrence?(occurrence) }
            )
        }
    }

    private func moveGesture(for occurrence: DayOccurrence, placement: TimelineLayoutPlacement) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named(gridSpaceName))
            .onChanged { value in
                let currentCursorY = Double(value.location.y)
                let initialCursorY: Double
                let origStart: Int
                let origEnd: Int

                if let existing = activeBlockGesture, existing.occurrenceID == occurrence.id, existing.kind == .move {
                    initialCursorY = existing.initialCursorY
                    origStart = existing.originalStartMinute
                    origEnd = existing.originalEndMinute
                } else {
                    initialCursorY = Double(value.startLocation.y)
                    origStart = placement.startMinute
                    origEnd = placement.endMinute
                }

                let dy = currentCursorY - initialCursorY
                let deltaMinutes = TimelineMath.snapDelta(
                    minutes: (dy / Double(hourHeight)) * 60.0
                )
                let duration = origEnd - origStart
                let newStart = max(0, min(TimelineMath.minutesPerDay - duration, origStart + deltaMinutes))
                let newEnd = newStart + duration

                activeBlockGesture = ActiveBlockGesture(
                    occurrenceID: occurrence.id,
                    kind: .move,
                    initialCursorY: initialCursorY,
                    originalStartMinute: origStart,
                    originalEndMinute: origEnd,
                    currentStartMinute: newStart,
                    currentEndMinute: newEnd
                )
            }
            .onEnded { _ in
                guard let gesture = activeBlockGesture, gesture.occurrenceID == occurrence.id else { return }
                activeBlockGesture = nil
                guard gesture.currentStartMinute != gesture.originalStartMinute else { return }
                let newStart = TimelineMath.date(on: date, minuteOfDay: gesture.currentStartMinute)
                let newEnd = TimelineMath.date(on: date, minuteOfDay: gesture.currentEndMinute)
                onMoveOrResize(occurrence, newStart, newEnd)
            }
    }

    private enum ResizeEdge { case top, bottom }

    private func resizeHandle(
        edge: ResizeEdge,
        occurrence: DayOccurrence,
        placement: TimelineLayoutPlacement
    ) -> some View {
        Color.clear
            .contentShape(Rectangle())
            #if os(macOS)
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeUpDown.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
            #endif
            .highPriorityGesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .named(gridSpaceName))
                    .onChanged { value in
                        let kind: ActiveBlockGesture.Kind = (edge == .top) ? .resizeTop : .resizeBottom
                        let origStart: Int
                        let origEnd: Int
                        let initialY: Double

                        if let existing = activeBlockGesture, existing.occurrenceID == occurrence.id, existing.kind == kind {
                            origStart = existing.originalStartMinute
                            origEnd = existing.originalEndMinute
                            initialY = existing.initialCursorY
                        } else {
                            origStart = placement.startMinute
                            origEnd = placement.endMinute
                            initialY = Double(value.startLocation.y)
                        }

                        // Track the exact 15-min slot directly under the cursor in the grid coordinate space
                        let cursorMinute = TimelineMath.minuteOfDay(
                            forY: Double(value.location.y),
                            hourHeight: Double(hourHeight)
                        )
                        var newStart = origStart
                        var newEnd = origEnd
                        if edge == .top {
                            newStart = max(0, min(origEnd - 15, cursorMinute))
                        } else {
                            newEnd = min(TimelineMath.minutesPerDay, max(origStart + 15, cursorMinute))
                        }

                        activeBlockGesture = ActiveBlockGesture(
                            occurrenceID: occurrence.id,
                            kind: kind,
                            initialCursorY: initialY,
                            originalStartMinute: origStart,
                            originalEndMinute: origEnd,
                            currentStartMinute: newStart,
                            currentEndMinute: newEnd
                        )
                    }
                    .onEnded { _ in
                        #if os(macOS)
                        NSCursor.arrow.set()
                        #endif
                        guard let gesture = activeBlockGesture, gesture.occurrenceID == occurrence.id else { return }
                        activeBlockGesture = nil
                        guard gesture.currentStartMinute != gesture.originalStartMinute ||
                              gesture.currentEndMinute != gesture.originalEndMinute else { return }
                        let newStart = TimelineMath.date(on: date, minuteOfDay: gesture.currentStartMinute)
                        let newEnd = TimelineMath.date(on: date, minuteOfDay: gesture.currentEndMinute)
                        onMoveOrResize(occurrence, newStart, newEnd)
                    }
            )
    }

    private func isOccurrenceSelected(_ occ: DayOccurrence) -> Bool {
        if let block = occ.block {
            let ref = SelectedItemRef.block(block.id)
            return selectedItem == ref || selectedItems.contains(ref)
        }
        if let series = occ.series {
            let ref = SelectedItemRef.virtualOccurrence(seriesID: series.id, dayStart: occ.dayStart)
            if selectedItems.contains(ref) { return true }
            if case .virtualOccurrence(let sID, let dStart) = selectedItem {
                return sID == series.id && Calendar.current.isDate(occ.dayStart, inSameDayAs: dStart)
            }
        }
        return false
    }
}
