import SwiftUI
import UniformTypeIdentifiers
import MyBetterLifeCore
#if os(macOS)
import AppKit
#endif

/// Multiplatform root view for My Better Life:
/// - macOS: Sidebar (Agenda/Notas selector + Mini Calendar + Categories) + Main Content (Agenda + Inspector OR Notes Workspace)
/// - iOS: TabView (Agenda + Notas) with Drawer Sheet & Editor Sheets
public struct MyBetterLifeRootView: View {
    public let store: PlannerStore
    public let focusManager: FocusSessionManager
    public let windowCoordinator: DetachedWindowCoordinator
    /// Optional private add-on (Open-Core). `nil` in the open-source build.
    private let cloudProvider: (any CloudExtensionProvider)?

    @State private var viewModel = PlannerViewModel()
    @State private var userProfile = LocalUserProfile()
    @State private var updateChecker = AppUpdateChecker()
    @State private var isProfileSettingsPresented: Bool = false
    @State private var isUpdateSheetPresented: Bool = false
    @State private var reminderCoordinator = ReminderCoordinator()
    @State private var defaultReminderOption: ReminderOption = ReminderPreferences.defaultOption
    @State private var isPhoneSidebarPresented: Bool = false
    @State private var isMacInspectorPresented: Bool = true
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var isDropPrimaryTargeted: Bool = false
    @State private var isDropSecondaryTargeted: Bool = false
    @State private var tearingOffTabRef: SelectedItemRef? = nil
    @State private var isTearOffThresholdReached: Bool = false
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    public init(
        store: PlannerStore,
        focusManager: FocusSessionManager = FocusSessionManager(),
        windowCoordinator: DetachedWindowCoordinator = DetachedWindowCoordinator(),
        cloudProvider: (any CloudExtensionProvider)? = nil
    ) {
        self.store = store
        self.focusManager = focusManager
        self.windowCoordinator = windowCoordinator
        self.cloudProvider = cloudProvider
    }

    private var activeMonthDays: Set<Date> {
        var days = RecurrenceEngine.activeDaysInMonth(
            containing: viewModel.displayedMonth,
            blocks: store.blocks,
            seriesList: store.seriesList
        )
        let cal = Calendar.current
        if let monthInterval = cal.dateInterval(of: .month, for: viewModel.displayedMonth) {
            for note in store.notes {
                let d = cal.startOfDay(for: note.updatedAt)
                if d >= monthInterval.start && d < monthInterval.end {
                    days.insert(d)
                }
            }
        }
        return days
    }

    private func occurrences(for day: Date) -> [DayOccurrence] {
        RecurrenceEngine.occurrences(
            on: day,
            blocks: store.blocks,
            seriesList: store.seriesList,
            notes: store.notes,
            categories: store.categories,
            attachments: store.attachments,
            categoryFilterID: viewModel.selectedCategoryFilterID
        )
    }

    private var selectedOccurrence: DayOccurrence? {
        viewModel.resolveSelectedOccurrence(in: store)
    }

    public var body: some View {
        Group {
            #if os(macOS)
            macOSLayout
            #else
            iOSLayout
            #endif
        }
        .onAppear {
            SampleDataSeeder.seedIfNeeded(in: store)
            cloudProvider?.attach(to: store)
            updateChecker.startAutomaticChecks()
            reminderCoordinator.onAction = { action, blockID, seriesID, dayStart in
                viewModel.handleReminderAction(
                    action,
                    blockID: blockID,
                    seriesID: seriesID,
                    dayStart: dayStart,
                    focusManager: focusManager,
                    in: store
                )
                #if os(macOS)
                if action == .open || action == .startFocus {
                    NSApp.activate(ignoringOtherApps: true)
                }
                #endif
            }
            reminderCoordinator.start(store: store)
            focusManager.startMenuBarObserver(store: store)
            focusManager.onSessionFinished = { _, _ in
                #if os(macOS)
                NSSound(named: NSSound.Name("Glass"))?.play()
                #endif
            }
        }
        .onChange(of: store.blocks) { _, _ in
            reminderCoordinator.sync(store: store)
            focusManager.refreshScheduledMenuBarSummary(in: store)
        }
        .onChange(of: store.seriesList) { _, _ in
            reminderCoordinator.sync(store: store)
            focusManager.refreshScheduledMenuBarSummary(in: store)
        }
        .onChange(of: windowCoordinator.pendingDockBackTarget) { _, dockTarget in
            guard let dockTarget else { return }
            windowCoordinator.pendingDockBackTarget = nil
            dockBackTarget(dockTarget)
        }
        .sheet(isPresented: $isProfileSettingsPresented) {
            ProfileAndSettingsSheet(userProfile: userProfile, updateChecker: updateChecker)
        }
        .sheet(isPresented: $isUpdateSheetPresented) {
            if let release = updateChecker.availableUpdate {
                UpdateAvailableSheet(release: release, updateChecker: updateChecker)
            }
        }
        .sheet(item: $viewModel.recurrencePickerTarget) { targetOccurrence in
            RecurrencePickerSheet(
                initialRule: targetOccurrence.series?.ruleType,
                initialMask: targetOccurrence.series?.weekdaysMask ?? .weekdays
            ) { ruleType, mask in
                viewModel.applyRecurrence(
                    for: targetOccurrence,
                    ruleType: ruleType,
                    weekdaysMask: mask,
                    in: store
                )
            }
        }
        #if os(macOS)
        .background(
            MacKeyboardShortcutsMonitor(
                onCloseActiveTab: {
                    guard !viewModel.isSearchPresented, !isAnyAppSheetPresented else { return false }
                    return viewModel.closeActiveTab()
                },
                onPopOutActive: {
                    guard !viewModel.isSearchPresented, !isAnyAppSheetPresented else { return false }
                    return popOutCurrentlySelectedItem()
                },
                onUndoDeletion: {
                    guard !viewModel.isSearchPresented, !isAnyAppSheetPresented else { return false }
                    return viewModel.undoLastDeletion(in: store)
                },
                onCopy: {
                    guard !viewModel.isSearchPresented,
                          !isAnyAppSheetPresented,
                          viewModel.selectedSection == .agenda else { return false }
                    return viewModel.copySelectedBlocks(in: store) > 0
                },
                onPaste: {
                    guard !viewModel.isSearchPresented,
                          !isAnyAppSheetPresented,
                          viewModel.selectedSection == .agenda,
                          !viewModel.copiedBlocks.isEmpty else { return false }
                    let target = viewModel.activePasteDate ?? viewModel.selectedDate
                    return !viewModel.pasteCopiedBlocks(onto: target, in: store).isEmpty
                },
                onSelectAll: {
                    guard !viewModel.isSearchPresented,
                          !isAnyAppSheetPresented,
                          viewModel.selectedSection == .agenda else { return false }
                    let target = viewModel.activePasteDate ?? viewModel.selectedDate
                    viewModel.selectAllOccurrences(on: target, in: store)
                    return !viewModel.selectedItems.isEmpty
                },
                onEscape: {
                    guard !viewModel.isSearchPresented,
                          !isAnyAppSheetPresented,
                          viewModel.isMultiSelecting else { return false }
                    viewModel.clearMultiSelection()
                    return true
                },
                onDelete: {
                    guard !viewModel.isSearchPresented, !isAnyAppSheetPresented else { return false }
                    switch viewModel.selectedSection {
                    case .agenda:
                        return viewModel.deleteSelectedBlocks(in: store)
                    case .notes:
                        guard let noteID = viewModel.selectedNoteItemID else { return false }
                        let allItems = NotesLibraryEngine.items(
                            notes: store.notes,
                            blocks: store.blocks,
                            categories: store.categories,
                            attachments: store.attachments,
                            originFilter: .all
                        )
                        guard let item = allItems.first(where: { $0.id == noteID }) else { return false }
                        viewModel.deleteNoteItem(item, in: store)
                        return true
                    }
                },
                onNavigateDay: { offset in
                    guard !viewModel.isSearchPresented,
                          !isAnyAppSheetPresented,
                          viewModel.selectedSection == .agenda else {
                        return false
                    }
                    viewModel.stepDate(by: offset)
                    viewModel.activePasteDate = viewModel.selectedDate
                    return true
                }
            )
        )
        #endif
        .sheet(isPresented: $viewModel.isSearchPresented) {
            CommandPaletteView(
                store: store,
                query: $viewModel.searchQuery
            ) { item in
                handlePaletteSelection(item)
            }
        }
        .confirmationDialog(
            recurrenceDialogTitle,
            isPresented: Binding(
                get: { viewModel.pendingRecurrenceDecision != nil },
                set: { if !$0 { viewModel.pendingRecurrenceDecision = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(L10n.recurrenceOnlyThisDay) {
                viewModel.applyPendingRecurrenceDecision(scope: .onlyThisDay, in: store)
            }
            Button(L10n.recurrenceThisAndFuture, role: isPendingDelete ? .destructive : nil) {
                viewModel.applyPendingRecurrenceDecision(scope: .thisAndFuture, in: store)
            }
            Button(L10n.recurrenceEntireSeries, role: isPendingDelete ? .destructive : nil) {
                viewModel.applyPendingRecurrenceDecision(scope: .entireSeries, in: store)
            }
            Button(L10n.cancel, role: .cancel) {
                viewModel.pendingRecurrenceDecision = nil
            }
        } message: {
            Text(recurrenceDialogMessage)
        }
    }

    // MARK: - macOS Adaptive Workspace (Native Sidebar + Agenda/Notes Detail + Inspector)

    #if os(macOS)
    private var macOSLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarContent
                .navigationSplitViewColumnWidth(min: 252, ideal: 266, max: 300)
        } detail: {
            VStack(spacing: 0) {
                if let alert = reminderCoordinator.activeInAppAlert {
                    InAppReminderBannerView(
                        alert: alert,
                        onAction: { action in
                            reminderCoordinator.triggerAction(action, for: alert)
                        },
                        onDismiss: {
                            reminderCoordinator.dismissInAppAlert()
                        }
                    )
                }

                if focusManager.isActive {
                    FocusActiveBannerView(focusManager: focusManager, store: store)
                }

                Group {
                    switch viewModel.selectedSection {
                    case .agenda:
                        timelinePane
                            .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
                            .inspector(isPresented: $isMacInspectorPresented) {
                                inspectorPane
                                    .inspectorColumnWidth(min: 350, ideal: 390, max: 480)
                            }
                            .toolbar {
                                agendaToolbarContent
                                ToolbarItem(placement: .automatic) {
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            isMacInspectorPresented.toggle()
                                        }
                                    } label: {
                                        Image(systemName: "sidebar.trailing")
                                    }
                                    .help("Mostrar/ocultar painel de notas")
                                }
                            }

                    case .notes:
                        NotesWorkspaceView(store: store, viewModel: viewModel)
                            .frame(minWidth: 680, maxWidth: .infinity, maxHeight: .infinity)
                            .toolbar {
                                notesToolbarContent
                            }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if let undoMessage = viewModel.undoToastMessage {
                    undoDeletionBanner(message: undoMessage)
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.18), value: viewModel.undoToastMessage)
        }
        .navigationSplitViewStyle(.balanced)
        .navigationTitle(L10n.appName)
        .onChange(of: viewModel.selectedItem) { _, newValue in
            if newValue != nil && !isMacInspectorPresented {
                isMacInspectorPresented = true
            }
        }
    }

    private var inspectorPane: some View {
        let openTabs = viewModel.resolvedOpenTabs(in: store)

        return VStack(spacing: 0) {
            if !openTabs.isEmpty {
                inspectorTabBar(tabs: openTabs)
            }

            if let occurrence = selectedOccurrence {
                BlockInspectorView(
                    store: store,
                    occurrence: occurrence,
                    viewModel: viewModel,
                    focusManager: focusManager,
                    showCloseButton: openTabs.isEmpty
                )
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 38, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text(L10n.selectBlockHintTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(L10n.selectBlockHintSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 260)

                    Button {
                        quickCreateBlockAtCurrentHour()
                    } label: {
                        Label(L10n.newBlock, systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .padding(.top, 4)
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.canvasBackground)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.canvasBackground)
    }

    private func inspectorTabBar(tabs: [(ref: SelectedItemRef, occurrence: DayOccurrence)]) -> some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(tabs, id: \.ref) { entry in
                            let isActive = viewModel.selectedItem == entry.ref
                            let isTearingThis = tearingOffTabRef == entry.ref
                            let accent = Color(hex: entry.occurrence.category?.colorHex ?? AppTheme.defaultAccentHex)

                            HStack(spacing: 6) {
                                Circle()
                                    .fill(accent)
                                    .frame(width: 7, height: 7)

                                Text(entry.occurrence.title.isEmpty ? L10n.untitledBlock : entry.occurrence.title)
                                    .font(.caption.weight(isActive ? .semibold : .medium))
                                    .foregroundStyle(isActive ? .primary : .secondary)
                                    .lineLimit(1)
                                    .frame(maxWidth: 128, alignment: .leading)

                                Button {
                                    withAnimation(.easeInOut(duration: 0.14)) {
                                        viewModel.closeTab(entry.ref)
                                    }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.tertiary)
                                        .frame(width: 16, height: 16)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .help("Fechar aba (⌘W)")
                            }
                            .padding(.leading, 9)
                            .padding(.trailing, 5)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(isTearingThis && isTearOffThresholdReached
                                          ? Color.accentColor.opacity(0.18)
                                          : (isActive ? AppTheme.canvasBackground : AppTheme.secondarySurface.opacity(0.65)))
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .strokeBorder(
                                        isTearingThis && isTearOffThresholdReached
                                            ? Color.accentColor
                                            : (isActive ? accent.opacity(0.5) : AppTheme.hairline.opacity(0.5)),
                                        style: isTearingThis && isTearOffThresholdReached
                                            ? StrokeStyle(lineWidth: 1.4, dash: [4, 2])
                                            : StrokeStyle(lineWidth: isActive ? 1.1 : 0.6)
                                    )
                            }
                            .scaleEffect(isTearingThis ? 0.96 : 1.0)
                            .opacity(isTearingThis && isTearOffThresholdReached ? 0.72 : 1.0)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.openTab(entry.ref)
                            }
                            .gesture(
                                DragGesture(minimumDistance: 10, coordinateSpace: .global)
                                    .onChanged { value in
                                        tearingOffTabRef = entry.ref
                                        let pointer = NSEvent.mouseLocation
                                        let outsideMainWindow = NSApp.keyWindow.map { !$0.frame.contains(pointer) } ?? false
                                        let pulledFar = hypot(value.translation.width, value.translation.height) > 58
                                        isTearOffThresholdReached = outsideMainWindow || pulledFar
                                    }
                                    .onEnded { value in
                                        let pointer = NSEvent.mouseLocation
                                        let outsideMainWindow = NSApp.keyWindow.map { !$0.frame.contains(pointer) } ?? false
                                        let pulledFar = hypot(value.translation.width, value.translation.height) > 58
                                        let shouldDetach = outsideMainWindow || pulledFar
                                        tearingOffTabRef = nil
                                        isTearOffThresholdReached = false

                                        if shouldDetach, let target = DetachedEditorTarget(from: entry.ref) {
                                            windowCoordinator.registerDropPoint(pointer, for: target)
                                            openWindow(id: DetachedEditorTarget.windowID, value: target)
                                            viewModel.closeTab(entry.ref)
                                        }
                                    }
                            )
                            .contextMenu {
                                Button {
                                    if let target = DetachedEditorTarget(from: entry.ref) {
                                        openWindow(id: DetachedEditorTarget.windowID, value: target)
                                        viewModel.closeTab(entry.ref)
                                    }
                                } label: {
                                    Label("Destacar em nova janela (⌘⇧O)", systemImage: "arrow.up.forward.app")
                                }

                                Button {
                                    viewModel.closeTab(entry.ref)
                                } label: {
                                    Label("Fechar aba (⌘W)", systemImage: "xmark")
                                }
                            }
                            .id(entry.ref)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                }
                .onChange(of: viewModel.selectedItem) { _, newRef in
                    if let newRef {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            proxy.scrollTo(newRef, anchor: .center)
                        }
                    }
                }
            }

            if isTearOffThresholdReached {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.caption2.weight(.semibold))
                    Text("Solte para destacar em nova janela")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(Color.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.10))
                .transition(.opacity)
            }
        }
        .background(AppTheme.secondarySurface.opacity(0.45))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.hairline)
                .frame(height: 0.75)
        }
    }
    #endif

    // MARK: - iOS Layout (TabView: Agenda + Notas)

    #if os(iOS)
    private var iOSLayout: some View {
        TabView(selection: $viewModel.selectedSection) {
            NavigationStack {
                VStack(spacing: 0) {
                    if focusManager.isActive {
                        FocusActiveBannerView(focusManager: focusManager, store: store)
                    }
                    timelinePane
                }
                    .navigationTitle(L10n.appName)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                isPhoneSidebarPresented = true
                            } label: {
                                Image(systemName: "calendar")
                            }
                        }
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                isProfileSettingsPresented = true
                            } label: {
                                Image(systemName: "person.crop.circle")
                                    .overlay(alignment: .topTrailing) {
                                        if updateChecker.pendingUpdateForBadge != nil {
                                            Circle()
                                                .fill(Color.accentColor)
                                                .frame(width: 8, height: 8)
                                                .offset(x: 2, y: -2)
                                        }
                                    }
                            }
                            .accessibilityLabel(L10n.profileSettingsTitle)
                        }
                        agendaToolbarContent
                    }
            }
            .tabItem {
                Label(L10n.agendaTab, systemImage: "calendar")
            }
            .tag(AppSection.agenda)

            NotesWorkspaceView(store: store, viewModel: viewModel)
                .tabItem {
                    Label(L10n.notesTab, systemImage: "doc.text")
                }
                .tag(AppSection.notes)
        }
        .sheet(isPresented: $isPhoneSidebarPresented) {
            NavigationStack {
                sidebarContent
                    .navigationTitle(L10n.calendarSection)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(L10n.close) { isPhoneSidebarPresented = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $viewModel.isPhoneEditorSheetPresented, onDismiss: {
            viewModel.clearSelection()
        }) {
            if let occurrence = selectedOccurrence {
                NavigationStack {
                    BlockInspectorView(
                        store: store,
                        occurrence: occurrence,
                        viewModel: viewModel,
                        focusManager: focusManager,
                        showCloseButton: false
                    )
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text(occurrenceScheduleSummary(for: occurrence))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                viewModel.clearSelection()
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .accessibilityLabel(L10n.close)
                        }
                    }
                }
                .presentationDetents([.large])
            }
        }
    }

    private func occurrenceScheduleSummary(for occurrence: DayOccurrence) -> String {
        let datePart = AppTheme.shortDate(occurrence.dayStart)
        if occurrence.isAllDay {
            return "\(datePart) · \(L10n.allDay)"
        }
        return "\(datePart) · \(TimelineMath.formatTimeRange(start: occurrence.startDate, end: occurrence.endDate))"
    }
    #endif

    // MARK: - Shared Sidebar, Timeline & Toolbars

    private var sidebarContent: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 14) {
                #if os(macOS)
                sectionSwitcher
                #endif

                Button {
                    viewModel.isSearchPresented = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(L10n.searchPlaceholder)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        #if os(macOS)
                        Text("⌘K")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(AppTheme.canvasBackground.opacity(0.8), in: RoundedRectangle(cornerRadius: 4))
                        #endif
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.secondarySurface.opacity(0.85), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
                #if os(macOS)
                .keyboardShortcut("k", modifiers: .command)
                #endif

                MiniMonthCalendarView(
                    selectedDate: Binding(
                        get: { viewModel.selectedDate },
                        set: { newDate in
                            viewModel.selectDate(newDate)
                            if viewModel.selectedSection == .notes {
                                viewModel.notesFilterByDay = true
                            }
                            #if os(iOS)
                            isPhoneSidebarPresented = false
                            #endif
                        }
                    ),
                    displayedMonth: $viewModel.displayedMonth,
                    secondaryDate: viewModel.selectedSection == .agenda && viewModel.viewMode == .day ? viewModel.secondaryDate : nil,
                    activeDays: activeMonthDays,
                    onOpenSecondaryDate: { droppedDay in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.openSecondaryDate(droppedDay)
                        }
                    }
                )

                InboxSidebarSection(
                    store: store,
                    viewModel: viewModel
                )

                GlobalBlocksSidebarSection(
                    store: store,
                    viewModel: viewModel
                )

                CategorySidebarSection(
                    store: store,
                    selectedFilterID: $viewModel.selectedCategoryFilterID
                )

                Divider()
                    .padding(.vertical, 2)

                VStack(spacing: 8) {
                    if let pending = updateChecker.pendingUpdateForBadge {
                        updateBadgeButton(for: pending)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    userProfileCard
                }
                .animation(.easeInOut(duration: 0.2), value: updateChecker.pendingUpdateForBadge?.versionString)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(iOS)
        .background(AppTheme.tertiarySurface.opacity(0.6))
        #endif
    }

    /// Blocks global keyboard shortcuts while a modal from the root view is open.
    private var isAnyAppSheetPresented: Bool {
        isProfileSettingsPresented || isUpdateSheetPresented
    }

    private func updateBadgeButton(for release: AppReleaseInfo) -> some View {
        Button {
            #if os(iOS)
            isPhoneSidebarPresented = false
            #endif
            isUpdateSheetPresented = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text(L10n.updateAvailableTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("v\(release.versionString)")
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(L10n.updateAvailableTitle): versão \(release.versionString)")
    }

    private var userProfileCard: some View {
        Button {
            #if os(iOS)
            isPhoneSidebarPresented = false
            #endif
            isProfileSettingsPresented = true
        } label: {
            HStack(spacing: 9) {
                ProfileAvatarView(initials: userProfile.initials, size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(userProfile.resolvedDisplayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("\(L10n.localModeSubtitle) · v\(AppVersionInfo.shortVersion)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "gearshape")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(AppTheme.secondarySurface.opacity(0.75), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(userProfile.resolvedDisplayName), \(L10n.profileSettingsTitle)")
    }

    #if os(macOS)
    private var sectionSwitcher: some View {
        VStack(spacing: 4) {
            sectionRow(section: .agenda, shortcutKey: "1")
            sectionRow(section: .notes, shortcutKey: "2", badgeCount: store.notes.count)
        }
    }

    private func sectionRow(section: AppSection, shortcutKey: KeyEquivalent, badgeCount: Int? = nil) -> some View {
        let isSelected = viewModel.selectedSection == section
        return Button {
            viewModel.selectedSection = section
        } label: {
            HStack(spacing: 10) {
                Image(systemName: section.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 20)
                Text(section.title)
                    .font(.subheadline.weight(isSelected ? .semibold : .medium))
                    .foregroundStyle(.primary)
                Spacer()
                if let badgeCount, badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(
                            (isSelected ? Color.accentColor.opacity(0.14) : AppTheme.secondarySurface),
                            in: Capsule()
                        )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(shortcutKey, modifiers: .command)
    }
    #endif

    private var timelinePane: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch viewModel.viewMode {
            case .day:
                #if os(macOS)
                if let secondaryDate = viewModel.secondaryDate {
                    HStack(spacing: 0) {
                        dayColumnView(
                            for: viewModel.selectedDate,
                            isCompactSideBySide: true,
                            onCloseSplitDay: nil
                        )
                        .overlay {
                            if isDropPrimaryTargeted {
                                dayDropOverlay(label: "Soltar para trocar este dia")
                            }
                        }
                        .onDrop(of: [.utf8PlainText, .plainText, .text], isTargeted: $isDropPrimaryTargeted) { providers in
                            handleTimelineDrop(providers, targetDay: viewModel.selectedDate, onDayDrop: { dropped in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.selectDate(dropped)
                                }
                            })
                        }

                        Rectangle()
                            .fill(AppTheme.hairline)
                            .frame(width: 1)

                        dayColumnView(
                            for: secondaryDate,
                            isCompactSideBySide: true,
                            onCloseSplitDay: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.closeSecondaryDate()
                                }
                            }
                        )
                        .overlay {
                            if isDropSecondaryTargeted {
                                dayDropOverlay(label: "Soltar dia ou bloco global")
                            }
                        }
                        .onDrop(of: [.utf8PlainText, .plainText, .text], isTargeted: $isDropSecondaryTargeted) { providers in
                            handleTimelineDrop(providers, targetDay: secondaryDate, onDayDrop: { dropped in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.openSecondaryDate(dropped)
                                }
                            })
                        }
                    }
                } else {
                    dayColumnView(
                        for: viewModel.selectedDate,
                        isCompactSideBySide: false,
                        onCloseSplitDay: nil
                    )
                    .overlay(alignment: .trailing) {
                        if isDropSecondaryTargeted {
                            GeometryReader { geo in
                                HStack(spacing: 0) {
                                    Spacer()
                                    dayDropOverlay(label: "Solte para abrir ao lado ou agendar")
                                        .frame(width: max(220, geo.size.width * 0.48))
                                }
                            }
                            .allowsHitTesting(false)
                        }
                    }
                    .onDrop(of: [.utf8PlainText, .plainText, .text], isTargeted: $isDropSecondaryTargeted) { providers in
                        handleTimelineDrop(providers, targetDay: viewModel.selectedDate, onDayDrop: { dropped in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.openSecondaryDate(dropped)
                            }
                        })
                    }
                }
                #else
                dayColumnView(
                    for: viewModel.selectedDate,
                    isCompactSideBySide: false,
                    onCloseSplitDay: nil
                )
                #endif
            case .week:
                WeekTimelineView(
                    anchorDate: viewModel.selectedDate,
                    store: store,
                    categoryFilterID: viewModel.selectedCategoryFilterID,
                    selectedItem: viewModel.selectedItem,
                    onSelectDay: { day in
                        viewModel.selectDate(day)
                        viewModel.viewMode = .day
                    },
                    onCreateTimedBlock: { day, startMin, endMin in
                        viewModel.selectDate(day)
                        viewModel.createTimedBlock(
                            on: day,
                            startMinute: startMin,
                            endMinute: endMin,
                            in: store
                        )
                    },
                    onSelectOccurrence: { occ in
                        viewModel.selectOccurrence(occ)
                    },
                    onToggleComplete: { occ in
                        viewModel.toggleCompletion(for: occ, in: store)
                    }
                )
            }
        }

        if viewModel.isMultiSelecting || viewModel.clipboardToastMessage != nil {
            timelineSelectionAndClipboardBar
                .padding(.bottom, 14)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        }
        .animation(.easeInOut(duration: 0.18), value: viewModel.isMultiSelecting)
        .animation(.easeInOut(duration: 0.18), value: viewModel.clipboardToastMessage)
    }

    private func undoDeletionBanner(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.orange)

            Text(message)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Button {
                viewModel.undoLastDeletion(in: store)
            } label: {
                Text("Desfazer (⌘Z)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentColor, in: Capsule())
            }
            .buttonStyle(.plain)

            Button {
                viewModel.dismissUndoToast()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule().strokeBorder(AppTheme.hairline.opacity(0.8), lineWidth: 0.75)
        }
        .shadow(color: .black.opacity(0.14), radius: 10, x: 0, y: 4)
    }

    private var timelineSelectionAndClipboardBar: some View {
        HStack(spacing: 10) {
            if viewModel.isMultiSelecting {
                Text("\(viewModel.selectedItems.count) blocos selecionados")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)

                Divider().frame(height: 14)

                Button {
                    viewModel.copySelectedBlocks(in: store)
                } label: {
                    Label("Copiar (⌘C)", systemImage: "doc.on.doc")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)

                if !viewModel.copiedBlocks.isEmpty {
                    Button {
                        let target = viewModel.activePasteDate ?? viewModel.selectedDate
                        viewModel.pasteCopiedBlocks(onto: target, in: store)
                    } label: {
                        Label("Colar (⌘V)", systemImage: "doc.on.clipboard")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }

                Button(role: .destructive) {
                    viewModel.deleteSelectedBlocks(in: store)
                } label: {
                    Label("Apagar", systemImage: "trash")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)

                Button {
                    viewModel.clearMultiSelection()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Limpar seleção múltipla (Esc)")
            } else if let toast = viewModel.clipboardToastMessage {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                Text(toast)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule().strokeBorder(AppTheme.hairline.opacity(0.8), lineWidth: 0.75)
        }
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
    }

    private func dayColumnView(
        for day: Date,
        isCompactSideBySide: Bool,
        onCloseSplitDay: (() -> Void)?
    ) -> some View {
        DayTimelineView(
            date: day,
            occurrences: occurrences(for: day),
            selectedItem: viewModel.selectedItem,
            selectedItems: viewModel.selectedItems,
            globalNotes: store.globalNotes,
            canPaste: !viewModel.copiedBlocks.isEmpty,
            isCompactSideBySide: isCompactSideBySide,
            onCloseSplitDay: onCloseSplitDay,
            onCreateTimedBlock: { startMin, endMin in
                viewModel.activePasteDate = day
                viewModel.createTimedBlock(
                    on: day,
                    startMinute: startMin,
                    endMinute: endMin,
                    in: store
                )
            },
            onCreateAllDayBlock: {
                viewModel.activePasteDate = day
                viewModel.createAllDayBlock(
                    on: day,
                    in: store
                )
            },
            onSelectOccurrence: { occ, additive in
                viewModel.selectOccurrence(occ, additive: additive)
            },
            onToggleComplete: { occ in
                viewModel.toggleCompletion(for: occ, in: store)
            },
            onMoveOrResize: { occ, newStart, newEnd in
                viewModel.requestReschedule(
                    occurrence: occ,
                    newStart: newStart,
                    newEnd: newEnd,
                    isAllDay: false,
                    in: store
                )
            },
            onOpenInNewWindow: { occ in
                #if os(macOS)
                if let ref = viewModel.occurrenceRef(for: occ),
                   let target = DetachedEditorTarget(from: ref) {
                    openWindow(id: DetachedEditorTarget.windowID, value: target)
                }
                #endif
            },
            onCopyOccurrence: { occ in
                viewModel.copySelectedBlocks(in: store, fallbackOccurrence: occ)
            },
            onPasteHere: {
                viewModel.activePasteDate = day
                viewModel.pasteCopiedBlocks(onto: day, in: store)
            },
            onClearMultiSelection: {
                viewModel.activePasteDate = day
                if viewModel.isMultiSelecting {
                    viewModel.clearMultiSelection()
                }
            },
            onStartFocus: { occ, mode in
                focusManager.start(occurrence: occ, mode: mode, in: store)
            },
            onChangeReminder: { occ, mins in
                viewModel.updateOccurrenceReminder(mins, for: occ, in: store)
            },
            onQuickRecurrence: { occ, rule, mask in
                viewModel.applyRecurrence(for: occ, ruleType: rule, weekdaysMask: mask, in: store)
            },
            onOpenCustomRecurrence: { occ in
                viewModel.recurrencePickerTarget = occ
            },
            onPromoteToGlobal: { occ in
                viewModel.promoteToGlobalBlock(occurrence: occ, in: store)
            },
            onLinkToGlobal: { occ, global in
                viewModel.linkOccurrence(occ, toGlobalNote: global, in: store)
            },
            onUnlinkGlobal: { occ in
                viewModel.unlinkFromGlobalBlock(occurrence: occ, in: store)
            },
            onDeleteOccurrence: { occ in
                viewModel.requestDelete(occurrence: occ, in: store)
            }
        )
    }

    private func handleTimelineDrop(
        _ providers: [NSItemProvider],
        targetDay: Date,
        onDayDrop: @escaping @MainActor (Date) -> Void
    ) -> Bool {
        for provider in providers where provider.canLoadObject(ofClass: NSString.self) {
            _ = provider.loadObject(ofClass: NSString.self) { object, _ in
                guard let str = object as? String else { return }
                Task { @MainActor in
                    if let droppedDay = DayDragPayload.decode(str) {
                        onDayDrop(droppedDay)
                    } else if let inboxID = InboxDragPayload.decode(str),
                              let inboxItem = store.inboxItem(for: inboxID) {
                        viewModel.scheduleInboxItem(inboxItem, on: targetDay, in: store)
                    } else if let globalNoteID = GlobalBlockDragPayload.decode(str),
                              let globalNote = store.note(for: globalNoteID) {
                        viewModel.scheduleGlobalBlock(globalNote, on: targetDay, in: store)
                    }
                }
            }
            return true
        }
        return false
    }

    private func dayDropOverlay(label: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentColor.opacity(0.10))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [7, 4]))
                }

            VStack(spacing: 8) {
                Image(systemName: "rectangle.split.2x1")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(Color.accentColor)
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppTheme.canvasBackground.opacity(0.92), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(10)
        .allowsHitTesting(false)
    }

    @ToolbarContentBuilder
    private var agendaToolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            HStack(spacing: 4) {
                Button {
                    viewModel.stepDate(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }

                Button(L10n.today) {
                    viewModel.goToToday()
                }

                Button {
                    viewModel.stepDate(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
            }

            Picker("Visualização", selection: $viewModel.viewMode) {
                ForEach(PlannerViewMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 140)

            #if os(macOS)
            if viewModel.viewMode == .day {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if viewModel.secondaryDate != nil {
                            viewModel.closeSecondaryDate()
                        } else if let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: viewModel.selectedDate) {
                            viewModel.openSecondaryDate(nextDay)
                        }
                    }
                } label: {
                    Image(systemName: viewModel.secondaryDate != nil ? "rectangle.split.2x1.fill" : "rectangle.split.2x1")
                }
                .help(viewModel.secondaryDate != nil ? "Fechar visualização de 2 dias" : "Abrir 2 dias lado a lado (ou arraste um dia do calendário)")
            }
            #endif

            Menu {
                Text("Lembrete padrão para novos blocos")
                Divider()
                ForEach(ReminderOption.allCases) { option in
                    Button {
                        defaultReminderOption = option
                        ReminderPreferences.defaultOption = option
                    } label: {
                        Label(
                            option.displayName,
                            systemImage: option == defaultReminderOption ? "checkmark" : "bell"
                        )
                    }
                }
            } label: {
                Image(systemName: defaultReminderOption == .none ? "bell.slash" : "bell")
            }
            .help("Lembrete padrão: \(defaultReminderOption.displayName)")

            Button {
                viewModel.isSearchPresented = true
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .help("\(L10n.searchTitle) (⌘K)")

            Button {
                quickCreateBlockAtCurrentHour()
            } label: {
                Label(L10n.newBlock, systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)
        }
    }

    @ToolbarContentBuilder
    private var notesToolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            Button {
                viewModel.isSearchPresented = true
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .help(L10n.searchTitle)

            Button {
                _ = viewModel.createStandaloneNote(in: store)
            } label: {
                Label(L10n.newNote, systemImage: "square.and.pencil")
            }
            .keyboardShortcut("n", modifiers: .command)
        }
    }

    // MARK: - Helpers

    #if os(macOS)
    private func popOutCurrentlySelectedItem() -> Bool {
        switch viewModel.selectedSection {
        case .agenda:
            guard let ref = viewModel.selectedItem,
                  let target = DetachedEditorTarget(from: ref) else {
                return false
            }
            openWindow(id: DetachedEditorTarget.windowID, value: target)
            viewModel.closeTab(ref)
            return true
        case .notes:
            guard let noteID = viewModel.selectedNoteItemID, noteID.hasPrefix("note-"),
                  let uuid = UUID(uuidString: String(noteID.dropFirst(5))) else {
                return false
            }
            openWindow(id: DetachedEditorTarget.windowID, value: DetachedEditorTarget.standaloneNote(uuid))
            return true
        }
    }
    #endif

    private func dockBackTarget(_ target: DetachedEditorTarget) {
        switch target {
        case .block(let blockID):
            viewModel.selectedSection = .agenda
            if let block = store.block(for: blockID) {
                viewModel.selectDate(block.startDate)
                viewModel.viewMode = .day
            }
            viewModel.openTab(.block(blockID))
            #if os(macOS)
            isMacInspectorPresented = true
            #endif

        case .virtualOccurrence(let seriesID, let dayStart):
            viewModel.selectedSection = .agenda
            viewModel.selectDate(dayStart)
            viewModel.viewMode = .day
            viewModel.openTab(.virtualOccurrence(seriesID: seriesID, dayStart: dayStart))
            #if os(macOS)
            isMacInspectorPresented = true
            #endif

        case .standaloneNote(let noteID):
            if let note = store.note(for: noteID) {
                viewModel.openGlobalNoteInNotes(note)
            }
        }
    }

    private func handlePaletteSelection(_ item: PaletteItem) {
        viewModel.searchQuery = ""
        switch item.payload {
        case .jumpToDate(let date, let openSideBySide):
            viewModel.selectedSection = .agenda
            viewModel.viewMode = .day
            if openSideBySide {
                viewModel.openSecondaryDate(date)
            } else {
                viewModel.selectDate(date)
            }

        case .action(let action):
            switch action {
            case .goToToday:
                viewModel.selectedSection = .agenda
                viewModel.goToToday()
            case .goToTomorrow:
                viewModel.selectedSection = .agenda
                if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) {
                    viewModel.selectDate(tomorrow)
                }
            case .toggleSplitDay:
                viewModel.selectedSection = .agenda
                viewModel.viewMode = .day
                if viewModel.secondaryDate != nil {
                    viewModel.closeSecondaryDate()
                } else if let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: viewModel.selectedDate) {
                    viewModel.openSecondaryDate(nextDay)
                }
            case .toggleDayWeekMode:
                viewModel.selectedSection = .agenda
                viewModel.viewMode = (viewModel.viewMode == .day) ? .week : .day
            case .newBlockNow:
                viewModel.selectedSection = .agenda
                quickCreateBlockAtCurrentHour()
            case .newNote:
                _ = viewModel.createStandaloneNote(in: store)
            case .newGlobalBlock:
                viewModel.createGlobalBlock(in: store)
            case .focusCurrentOrSelectedBlock:
                if let current = selectedOccurrence, !current.isAllDay {
                    focusManager.start(occurrence: current, mode: .blockDuration, in: store)
                } else if let nowOcc = focusManager.currentScheduledOccurrence(in: store) {
                    focusManager.start(occurrence: nowOcc, mode: .blockDuration, in: store)
                } else {
                    viewModel.selectedSection = .agenda
                    let created = quickCreateBlockAtCurrentHourReturning()
                    if let occ = viewModel.resolveOccurrence(for: .block(created.id), in: store) {
                        focusManager.start(occurrence: occ, mode: .blockDuration, in: store)
                    }
                }
            case .openAgenda:
                viewModel.selectedSection = .agenda
            case .openNotes:
                viewModel.selectedSection = .notes
            case .openSettings:
                isProfileSettingsPresented = true
            }

        case .globalBlock(let globalNote):
            viewModel.openGlobalNoteInNotes(globalNote)

        case .inboxItem(let inboxItem):
            viewModel.scheduleInboxItem(inboxItem, on: viewModel.selectedDate, in: store)

        case .searchResult(let result):
            if let note = result.note {
                viewModel.selectedSection = .notes
                if viewModel.notesOriginFilter == .agendaOnly {
                    viewModel.notesOriginFilter = .all
                }
                viewModel.notesFilterByDay = false
                viewModel.selectedNoteItemID = "note-\(note.id.uuidString)"
            } else {
                viewModel.selectedSection = .agenda
                viewModel.selectDate(result.targetDate)
                viewModel.viewMode = .day
                if let block = result.block {
                    viewModel.openTab(.block(block.id))
                } else if let series = result.series {
                    viewModel.openTab(.virtualOccurrence(
                        seriesID: series.id,
                        dayStart: result.targetDate
                    ))
                }
            }

        case .quickCaptureInbox(let title):
            _ = viewModel.createInboxItem(title: title, in: store)
        }
    }

    @discardableResult
    private func quickCreateBlockAtCurrentHourReturning() -> TimeBlock {
        let now = Date()
        let comps = Calendar.current.dateComponents([.hour, .minute], from: now)
        let currentMin = (comps.hour ?? 9) * 60 + (comps.minute ?? 0)
        let snapped = min(TimelineMath.snap(minute: Double(currentMin)), TimelineMath.minutesPerDay - 60)
        return viewModel.createTimedBlock(
            on: viewModel.selectedDate,
            startMinute: snapped,
            endMinute: snapped + 60,
            in: store
        )
    }

    private func quickCreateBlockAtCurrentHour() {
        _ = quickCreateBlockAtCurrentHourReturning()
    }

    private var isPendingDelete: Bool {
        if case .delete = viewModel.pendingRecurrenceDecision?.kind {
            return true
        }
        return false
    }

    private var recurrenceDialogTitle: String {
        isPendingDelete ? L10n.recurrenceDeleteTitle : L10n.recurrenceScopeTitle
    }

    private var recurrenceDialogMessage: String {
        isPendingDelete ? L10n.recurrenceDeleteMessage : L10n.recurrenceScopeMessage
    }
}

#if os(macOS)
/// Monitors macOS keyboard shortcuts:
/// - `⌘W`: closes the active right-hand block tab (even while editing text inside that tab!)
/// - `⌘C`, `⌘V`, `⌘A`, `Esc`, `⌫`, `←`, `→`: handled ONLY when no text input (`NSText`) has keyboard focus,
///   so text editing & Markdown copy/paste continue working 100% natively.
private struct MacKeyboardShortcutsMonitor: NSViewRepresentable {
    let onCloseActiveTab: () -> Bool
    let onPopOutActive: () -> Bool
    let onUndoDeletion: () -> Bool
    let onCopy: () -> Bool
    let onPaste: () -> Bool
    let onSelectAll: () -> Bool
    let onEscape: () -> Bool
    let onDelete: () -> Bool
    let onNavigateDay: (Int) -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onCloseActiveTab: onCloseActiveTab,
            onPopOutActive: onPopOutActive,
            onUndoDeletion: onUndoDeletion,
            onCopy: onCopy,
            onPaste: onPaste,
            onSelectAll: onSelectAll,
            onEscape: onEscape,
            onDelete: onDelete,
            onNavigateDay: onNavigateDay
        )
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.hostWindow = view.window
        }
        context.coordinator.startMonitoring()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let win = nsView.window {
            context.coordinator.hostWindow = win
        }
        context.coordinator.onCloseActiveTab = onCloseActiveTab
        context.coordinator.onPopOutActive = onPopOutActive
        context.coordinator.onUndoDeletion = onUndoDeletion
        context.coordinator.onCopy = onCopy
        context.coordinator.onPaste = onPaste
        context.coordinator.onSelectAll = onSelectAll
        context.coordinator.onEscape = onEscape
        context.coordinator.onDelete = onDelete
        context.coordinator.onNavigateDay = onNavigateDay
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stopMonitoring()
    }

    @MainActor
    final class Coordinator {
        weak var hostWindow: NSWindow?
        var onCloseActiveTab: () -> Bool
        var onPopOutActive: () -> Bool
        var onUndoDeletion: () -> Bool
        var onCopy: () -> Bool
        var onPaste: () -> Bool
        var onSelectAll: () -> Bool
        var onEscape: () -> Bool
        var onDelete: () -> Bool
        var onNavigateDay: (Int) -> Bool
        private var monitor: Any?

        init(
            onCloseActiveTab: @escaping () -> Bool,
            onPopOutActive: @escaping () -> Bool,
            onUndoDeletion: @escaping () -> Bool,
            onCopy: @escaping () -> Bool,
            onPaste: @escaping () -> Bool,
            onSelectAll: @escaping () -> Bool,
            onEscape: @escaping () -> Bool,
            onDelete: @escaping () -> Bool,
            onNavigateDay: @escaping (Int) -> Bool
        ) {
            self.onCloseActiveTab = onCloseActiveTab
            self.onPopOutActive = onPopOutActive
            self.onUndoDeletion = onUndoDeletion
            self.onCopy = onCopy
            self.onPaste = onPaste
            self.onSelectAll = onSelectAll
            self.onEscape = onEscape
            self.onDelete = onDelete
            self.onNavigateDay = onNavigateDay
        }

        func startMonitoring() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                // Only intercept shortcuts belonging to the main window (never hijack detached pop-out windows!)
                if let hostWindow = self.hostWindow, event.window !== hostWindow {
                    return event
                }
                let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
                let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""

                // 1. ⌘W: close active block tab in the right-hand inspector even while typing inside it
                if mods == .command && chars == "w" {
                    return self.onCloseActiveTab() ? nil : event
                }

                // 1b. ⌘⇧O: pop out currently active block/note into a detached window
                if mods == [.command, .shift] && chars == "o" {
                    return self.onPopOutActive() ? nil : event
                }

                // All shortcuts below yield to active text inputs (`NSText` / `NSTextView`)
                if let responder = NSApp.keyWindow?.firstResponder, responder is NSText {
                    return event
                }

                // 2. Undo deletion via ⌘Z OR ⌃Z (works for both macOS Command+Z and Control+Z muscle memory!)
                if (mods == .command || mods == .control) && chars == "z" {
                    return self.onUndoDeletion() ? nil : event
                }

                // 2. Command shortcuts for timeline blocks (Copy, Paste, Select All)
                if mods == .command {
                    switch chars {
                    case "c":
                        return self.onCopy() ? nil : event
                    case "v":
                        return self.onPaste() ? nil : event
                    case "a":
                        return self.onSelectAll() ? nil : event
                    default:
                        return event
                    }
                }

                // 3. Unmodified navigation, Escape & Delete
                guard mods.isEmpty else { return event }
                switch event.keyCode {
                case 53: // Escape
                    return self.onEscape() ? nil : event
                case 51, 117: // Backspace / Forward Delete
                    return self.onDelete() ? nil : event
                case 123: // Left Arrow -> previous day / week
                    return self.onNavigateDay(-1) ? nil : event
                case 124: // Right Arrow -> next day / week
                    return self.onNavigateDay(1) ? nil : event
                default:
                    return event
                }
            }
        }

        func stopMonitoring() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }
    }
}
#endif
