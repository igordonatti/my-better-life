import SwiftUI
import MyBetterLifeCore

/// Drag-and-drop payload encoder/decoder for dragging a Daily Routine item from the Sidebar onto the Day Timeline.
public enum DailyRoutineDragPayload {
    public static let prefix = "mbl-routine:"

    public static func encode(_ itemID: UUID) -> String {
        "\(prefix)\(itemID.uuidString)"
    }

    public static func decode(_ string: String) -> UUID? {
        guard string.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(string.dropFirst(prefix.count)))
    }
}

/// Top sidebar card that toggles between "Rotina" (daily recurring checklist) and "Calendário" (MiniMonthCalendarView).
/// Remembers the last selected tab across sessions, defaulting to "Rotina".
public struct SidebarCalendarRoutineCard: View {
    public enum Tab: String, CaseIterable {
        case routine
        case calendar
    }

    public let store: PlannerStore
    @Bindable public var viewModel: PlannerViewModel
    public let selectedDateBinding: Binding<Date>
    public let secondaryDate: Date?
    public let activeDays: Set<Date>
    public let onOpenSecondaryDate: ((Date) -> Void)?

    @AppStorage("mbl.sidebarTopCardTab") private var selectedTabRaw: String = Tab.routine.rawValue

    private var selectedTab: Tab {
        Tab(rawValue: selectedTabRaw) ?? .routine
    }

    public init(
        store: PlannerStore,
        viewModel: PlannerViewModel,
        selectedDateBinding: Binding<Date>,
        secondaryDate: Date?,
        activeDays: Set<Date>,
        onOpenSecondaryDate: ((Date) -> Void)? = nil
    ) {
        self.store = store
        self.viewModel = viewModel
        self.selectedDateBinding = selectedDateBinding
        self.secondaryDate = secondaryDate
        self.activeDays = activeDays
        self.onOpenSecondaryDate = onOpenSecondaryDate
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            tabSwitcher

            switch selectedTab {
            case .routine:
                DailyRoutineCardContent(
                    store: store,
                    viewModel: viewModel
                )
            case .calendar:
                MiniMonthCalendarView(
                    selectedDate: selectedDateBinding,
                    displayedMonth: $viewModel.displayedMonth,
                    secondaryDate: secondaryDate,
                    activeDays: activeDays,
                    embedded: true,
                    onOpenSecondaryDate: onOpenSecondaryDate
                )
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.secondarySurface.opacity(0.65), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var tabSwitcher: some View {
        HStack(spacing: 4) {
            switcherButton(
                tab: .routine,
                title: L10n.routineTabTitle,
                systemImage: "checklist"
            )
            switcherButton(
                tab: .calendar,
                title: L10n.calendarSection,
                systemImage: "calendar"
            )
        }
        .padding(3)
        .background(AppTheme.canvasBackground.opacity(0.6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func switcherButton(tab: Tab, title: String, systemImage: String) -> some View {
        let isActive = selectedTab == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                selectedTabRaw = tab.rawValue
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.caption.weight(isActive ? .semibold : .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isActive ? Color.primary : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(AppTheme.canvasBackground)
                        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Daily recurring checklist embedded inside `SidebarCalendarRoutineCard`.
/// Bound to `viewModel.selectedDate`, supports inline quick-add, progress bar, weekday schedules,
/// inline rename, and drag-and-drop onto the Timeline with bidirectional completion sync.
public struct DailyRoutineCardContent: View {
    public let store: PlannerStore
    @Bindable public var viewModel: PlannerViewModel

    @State private var newItemTitle: String = ""
    @State private var editingItemID: UUID? = nil
    @State private var editingTitle: String = ""
    @FocusState private var isRenameFocused: Bool

    public init(store: PlannerStore, viewModel: PlannerViewModel) {
        self.store = store
        self.viewModel = viewModel
    }

    private var activeDate: Date {
        viewModel.selectedDate
    }

    private var applicableItems: [DailyRoutineItem] {
        store.routineItems(for: activeDate)
    }

    private var pendingItems: [DailyRoutineItem] {
        applicableItems.filter { !store.isRoutineCompleted($0.id, on: activeDate) }
    }

    private var completedItems: [DailyRoutineItem] {
        applicableItems.filter { store.isRoutineCompleted($0.id, on: activeDate) }
    }

    private var completionFraction: Double {
        guard !applicableItems.isEmpty else { return 0 }
        return Double(completedItems.count) / Double(applicableItems.count)
    }

    private var allCompleted: Bool {
        !applicableItems.isEmpty && completedItems.count == applicableItems.count
    }

    private var dayContextLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(activeDate) {
            return L10n.today
        } else if cal.isDateInYesterday(activeDate) {
            return "Ontem"
        } else if cal.isDateInTomorrow(activeDate) {
            return "Amanhã"
        } else {
            let formatter = DateFormatter()
            formatter.locale = AppTheme.ptBRLocale
            formatter.dateFormat = "d MMM"
            return formatter.string(from: activeDate)
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            // Day context + progress counter
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    if !Calendar.current.isDateInToday(activeDate) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                    Text(dayContextLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Calendar.current.isDateInToday(activeDate) ? Color.secondary : Color.accentColor)
                }

                Spacer()

                if !applicableItems.isEmpty {
                    HStack(spacing: 3) {
                        if allCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.green)
                        }
                        Text("\(completedItems.count)/\(applicableItems.count)")
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(allCompleted ? Color.green : Color.accentColor)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        (allCompleted ? Color.green : Color.accentColor).opacity(0.12),
                        in: Capsule()
                    )
                }
            }
            .padding(.horizontal, 2)

            // Thin progress bar
            if !applicableItems.isEmpty {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppTheme.canvasBackground.opacity(0.7))
                        Capsule()
                            .fill(allCompleted ? Color.green : Color.accentColor)
                            .frame(width: max(0, proxy.size.width * completionFraction))
                    }
                }
                .frame(height: 3.5)
                .animation(.easeInOut(duration: 0.22), value: completionFraction)
                .padding(.horizontal, 2)
            }

            // Inline quick-add field
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary.opacity(0.5) : Color.accentColor)

                TextField(L10n.routineQuickAddPlaceholder, text: $newItemTitle)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .onSubmit {
                        submitNewItem()
                    }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(AppTheme.canvasBackground.opacity(0.75), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            // Checklist rows: pending on top, completed below (visible & dimmed)
            if applicableItems.isEmpty {
                Text(store.routineItems.isEmpty ? L10n.routineEmptyHint : "Nenhum item programado para este dia")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 4) {
                    ForEach(pendingItems) { item in
                        routineRow(item, isCompleted: false)
                    }
                    ForEach(completedItems) { item in
                        routineRow(item, isCompleted: true)
                    }
                }
            }
        }
    }

    private func routineRow(_ item: DailyRoutineItem, isCompleted: Bool) -> some View {
        let color = Color(hex: store.category(for: item.categoryID)?.colorHex ?? AppTheme.defaultAccentHex)
        let isEditing = editingItemID == item.id

        return HStack(spacing: 7) {
            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    viewModel.toggleRoutineCompletion(item, on: activeDate, in: store)
                }
            } label: {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isCompleted ? color : .secondary)
            }
            .buttonStyle(.plain)

            if isEditing {
                TextField("", text: $editingTitle)
                    .textFieldStyle(.plain)
                    .font(.caption.weight(.medium))
                    .focused($isRenameFocused)
                    .onSubmit {
                        commitRename(for: item)
                    }
                    #if os(macOS)
                    .onExitCommand {
                        cancelRename()
                    }
                    #endif
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(isCompleted ? .tertiary : .primary)
                        .strikethrough(isCompleted)
                        .lineLimit(2)

                    if let schedule = item.scheduleSummary {
                        Text(schedule)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer(minLength: 4)

            if !isCompleted && !isEditing {
                Text(TimelineMath.formatDuration(minutes: item.estimatedMinutes))
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(AppTheme.secondarySurface, in: Capsule())
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            AppTheme.canvasBackground.opacity(isCompleted ? 0.35 : 0.72),
            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(AppTheme.hairline.opacity(isCompleted ? 0.3 : 0.55), lineWidth: 0.6)
        }
        .contentShape(Rectangle())
        #if os(macOS)
        .onDrag {
            NSItemProvider(object: DailyRoutineDragPayload.encode(item.id) as NSString)
        } preview: {
            HStack(spacing: 6) {
                Image(systemName: "checklist")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(color)
                Text(item.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(TimelineMath.formatDuration(minutes: item.estimatedMinutes))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppTheme.canvasBackground, in: Capsule())
            .overlay {
                Capsule().strokeBorder(color.opacity(0.5), lineWidth: 1)
            }
        }
        #endif
        .contextMenu {
            Button {
                viewModel.scheduleRoutineItem(item, on: activeDate, in: store)
            } label: {
                Label("Agendar no dia selecionado", systemImage: "calendar.badge.plus")
            }

            Button {
                startRename(for: item)
            } label: {
                Label(L10n.routineRename, systemImage: "pencil")
            }

            Menu {
                Button {
                    viewModel.updateRoutineItemWeekdays(item, mask: .all, in: store)
                } label: {
                    Label(L10n.routineAllDays, systemImage: item.weekdaysMask == .all ? "checkmark" : "calendar")
                }

                Button {
                    viewModel.updateRoutineItemWeekdays(item, mask: .weekdays, in: store)
                } label: {
                    Label(L10n.routineWeekdays, systemImage: item.weekdaysMask == .weekdays ? "checkmark" : "briefcase")
                }

                Button {
                    viewModel.updateRoutineItemWeekdays(item, mask: .weekend, in: store)
                } label: {
                    Label(L10n.routineWeekend, systemImage: item.weekdaysMask == .weekend ? "checkmark" : "sun.max")
                }

                Divider()

                ForEach(WeekdayMask.orderedForUI, id: \.calendarWeekday) { entry in
                    let isOn = item.weekdaysMask.contains(entry.mask)
                    Button {
                        toggleWeekday(entry.mask, for: item)
                    } label: {
                        Label(entry.shortLabel, systemImage: isOn ? "checkmark.circle.fill" : "circle")
                    }
                }
            } label: {
                Label(L10n.routineCustomDays, systemImage: "repeat")
            }

            Menu {
                ForEach([15, 30, 45, 60, 90, 120], id: \.self) { mins in
                    Button {
                        viewModel.updateRoutineItemDuration(item, minutes: mins, in: store)
                    } label: {
                        Label(
                            TimelineMath.formatDuration(minutes: mins),
                            systemImage: item.estimatedMinutes == mins ? "checkmark" : "clock"
                        )
                    }
                }
            } label: {
                Label("Duração estimada", systemImage: "clock")
            }

            if !store.categories.isEmpty {
                Menu {
                    Button {
                        viewModel.updateRoutineItemCategory(item, categoryID: nil, in: store)
                    } label: {
                        Label(L10n.noCategory, systemImage: item.categoryID == nil ? "checkmark" : "minus")
                    }
                    Divider()
                    ForEach(store.categories) { cat in
                        Button {
                            viewModel.updateRoutineItemCategory(item, categoryID: cat.id, in: store)
                        } label: {
                            Label(cat.name, systemImage: item.categoryID == cat.id ? "checkmark" : cat.symbolName)
                        }
                    }
                } label: {
                    Label(L10n.category, systemImage: "tag")
                }
            }

            Divider()

            Button {
                viewModel.toggleRoutineCompletion(item, on: activeDate, in: store)
            } label: {
                Label(
                    isCompleted ? "Desmarcar conclusão" : L10n.markCompleted,
                    systemImage: isCompleted ? "arrow.uturn.backward" : "checkmark.circle"
                )
            }

            Button(role: .destructive) {
                viewModel.deleteRoutineItem(item, in: store)
            } label: {
                Label(L10n.delete, systemImage: "trash")
            }
        }
    }

    private func submitNewItem() {
        guard viewModel.createRoutineItem(title: newItemTitle, in: store) != nil else { return }
        newItemTitle = ""
    }

    private func startRename(for item: DailyRoutineItem) {
        editingItemID = item.id
        editingTitle = item.title
        isRenameFocused = true
    }

    private func commitRename(for item: DailyRoutineItem) {
        viewModel.renameRoutineItem(item, title: editingTitle, in: store)
        editingItemID = nil
        editingTitle = ""
    }

    private func cancelRename() {
        editingItemID = nil
        editingTitle = ""
    }

    private func toggleWeekday(_ dayMask: WeekdayMask, for item: DailyRoutineItem) {
        var next = item.weekdaysMask
        if next.contains(dayMask) {
            next.remove(dayMask)
            // Never allow an empty mask (keep at least one day active)
            guard !next.isEmpty else { return }
        } else {
            next.insert(dayMask)
        }
        viewModel.updateRoutineItemWeekdays(item, mask: next, in: store)
    }
}
