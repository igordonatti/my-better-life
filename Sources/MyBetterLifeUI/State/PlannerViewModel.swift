import Foundation
import SwiftUI
import MyBetterLifeCore
#if os(macOS)
import AppKit
#endif

public enum AppSection: String, CaseIterable, Identifiable, Sendable {
    case agenda
    case notes

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .agenda: return L10n.agendaTab
        case .notes: return L10n.notesTab
        }
    }

    public var systemImage: String {
        switch self {
        case .agenda: return "calendar"
        case .notes: return "doc.text"
        }
    }
}

public enum PlannerViewMode: String, CaseIterable, Identifiable, Sendable {
    case day
    case week

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .day: return L10n.dayView
        case .week: return L10n.weekView
        }
    }
}

/// Identifies what is currently selected in the inspector/sheet so selection survives
/// virtual-to-override materialization cleanly.
public enum SelectedItemRef: Equatable, Hashable, Sendable {
    case block(UUID)
    case virtualOccurrence(seriesID: UUID, dayStart: Date)
}

/// Captures a pending recurring edit or delete waiting for the user's scope decision.
public struct PendingRecurrenceDecision: Identifiable, Sendable {
    public enum ActionKind: Sendable {
        case reschedule(newStart: Date, newEnd: Date, isAllDay: Bool)
        case updateMetadata(title: String, categoryID: UUID?, reminderMinutesBefore: Int?)
        case delete
    }

    public let id = UUID()
    public let series: RecurrenceSeries
    public let dayStart: Date
    public let existingOverride: TimeBlock?
    public let kind: ActionKind
}

/// Snapshot of a copied time block (including its Markdown note & image attachments)
/// stored in the app's in-memory block clipboard for single or multi-block Copy/Paste.
public struct CopiedBlockSnapshot: Sendable {
    public struct ClonedAttachment: Sendable {
        public let originalID: UUID
        public let fileName: String
        public let mimeType: String
        public let imageData: Data
    }

    public let title: String
    public let startMinuteOfDay: Int
    public let durationMinutes: Int
    public let isAllDay: Bool
    public let reminderMinutesBefore: Int?
    public let noteMarkdown: String
    public let categoryID: UUID?
    public let globalNoteID: UUID?
    public let sourceDayStart: Date
    public let attachments: [ClonedAttachment]
}

/// Atomic snapshot captured before deleting any block(s), recurring series, or note(s),
/// allowing lossless `⌘Z` / `⌃Z` Undo (including attachments and parent-child subnote hierarchy).
public struct DeletionUndoEntry: Identifiable, Sendable {
    public let id = UUID()
    public let label: String
    public let blocksToRestore: [TimeBlock]
    public let blockIDsToRemoveOnUndo: [UUID]
    public let seriesToRestore: [RecurrenceSeries]
    public let notesToRestore: [StandaloneNote]
    public let attachmentsToRestore: [BlockAttachment]
    public let childParentRestorations: [(childID: UUID, previousParentID: UUID?)]
    public let restoreToSection: AppSection
    public let focusBlockID: UUID?
    public let focusNoteID: UUID?
}

/// Central UI coordinator for My Better Life across macOS and iOS.
@Observable
@MainActor
public final class PlannerViewModel {
    public var selectedSection: AppSection = .agenda
    public var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    public var secondaryDate: Date? = nil
    public var activePasteDate: Date? = nil
    public var displayedMonth: Date = Calendar.current.startOfDay(for: Date())
    public var viewMode: PlannerViewMode = .day
    public var selectedCategoryFilterID: UUID? = nil

    // Agenda selection, Multi-selection, Clipboard, Undo & Inspector tabs
    public var selectedItem: SelectedItemRef? = nil
    public var selectedItems: Set<SelectedItemRef> = []
    public var openBlockTabs: [SelectedItemRef] = []
    public var copiedBlocks: [CopiedBlockSnapshot] = []
    public var clipboardToastMessage: String? = nil
    public private(set) var deletionUndoStack: [DeletionUndoEntry] = []
    public var undoToastMessage: String? = nil
    public var isPhoneEditorSheetPresented: Bool = false
    public var isSearchPresented: Bool = false
    public var searchQuery: String = ""
    public var shouldFocusTitleField: Bool = false

    // Notes workspace state
    public var notesOriginFilter: NoteOriginFilter = .all
    public var notesFilterByDay: Bool = false
    public var notesSearchQuery: String = ""
    public var selectedNoteItemID: String? = nil
    public var shouldFocusNoteTitleField: Bool = false

    public var pendingRecurrenceDecision: PendingRecurrenceDecision? = nil
    public var recurrencePickerTarget: DayOccurrence? = nil

    public init() {}

    // MARK: - Date Navigation

    public func selectDate(_ date: Date) {
        let normalized = Calendar.current.startOfDay(for: date)
        if let sec = secondaryDate, Calendar.current.isDate(sec, inSameDayAs: normalized) {
            // Avoid duplicating the same day in both split panes
            secondaryDate = nil
        }
        selectedDate = normalized
        displayedMonth = normalized
    }

    public func openSecondaryDate(_ date: Date) {
        let normalized = Calendar.current.startOfDay(for: date)
        guard !Calendar.current.isDate(normalized, inSameDayAs: selectedDate) else { return }
        secondaryDate = normalized
        selectedSection = .agenda
        viewMode = .day
    }

    public func closeSecondaryDate() {
        secondaryDate = nil
    }

    public func goToToday() {
        selectDate(Date())
    }

    public func stepDate(by offset: Int) {
        let delta = viewMode == .week ? offset * 7 : offset
        if let next = Calendar.current.date(byAdding: .day, value: delta, to: selectedDate) {
            selectedDate = Calendar.current.startOfDay(for: next)
            displayedMonth = selectedDate
        }
        if viewMode == .day, let sec = secondaryDate,
           let nextSec = Calendar.current.date(byAdding: .day, value: delta, to: sec) {
            secondaryDate = Calendar.current.startOfDay(for: nextSec)
        }
    }

    // MARK: - Selection & Inspector Tabs

    public func openTab(_ ref: SelectedItemRef, focusTitle: Bool = false) {
        shouldFocusTitleField = focusTitle
        if !openBlockTabs.contains(ref) {
            openBlockTabs.append(ref)
        }
        selectedItem = ref
        selectedItems = [ref]
        #if os(macOS)
        if !focusTitle {
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
        #elseif os(iOS)
        isPhoneEditorSheetPresented = true
        #endif
    }

    public func closeTab(_ ref: SelectedItemRef) {
        selectedItems.remove(ref)
        guard let idx = openBlockTabs.firstIndex(of: ref) else {
            if selectedItem == ref { selectedItem = nil }
            return
        }
        openBlockTabs.remove(at: idx)
        if selectedItem == ref {
            if openBlockTabs.isEmpty {
                selectedItem = nil
                isPhoneEditorSheetPresented = false
            } else {
                let nextIdx = min(idx, openBlockTabs.count - 1)
                let next = openBlockTabs[nextIdx]
                selectedItem = next
                selectedItems = [next]
            }
        }
    }

    /// Closes the currently active block tab in the right-hand inspector (`⌘W` on macOS).
    /// Returns `true` if a tab was closed (so the app window itself does not close).
    @discardableResult
    public func closeActiveTab() -> Bool {
        guard selectedSection == .agenda,
              let current = selectedItem,
              openBlockTabs.contains(current) else {
            return false
        }
        closeTab(current)
        return true
    }

    public func occurrenceRef(for occurrence: DayOccurrence) -> SelectedItemRef? {
        if let block = occurrence.block {
            return .block(block.id)
        } else if let series = occurrence.series {
            return .virtualOccurrence(seriesID: series.id, dayStart: occurrence.dayStart)
        }
        return nil
    }

    public func selectOccurrence(
        _ occurrence: DayOccurrence,
        additive: Bool = false,
        focusTitle: Bool = false
    ) {
        activePasteDate = occurrence.dayStart
        guard let ref = occurrenceRef(for: occurrence) else { return }

        if additive {
            if let existingPrimary = selectedItem, !selectedItems.contains(existingPrimary) {
                selectedItems.insert(existingPrimary)
            }
            if selectedItems.contains(ref) {
                selectedItems.remove(ref)
                if selectedItem == ref {
                    selectedItem = selectedItems.first
                }
            } else {
                selectedItems.insert(ref)
                selectedItem = ref
                if !openBlockTabs.contains(ref) {
                    openBlockTabs.append(ref)
                }
            }
            #if os(macOS)
            NSApp.keyWindow?.makeFirstResponder(nil)
            #endif
        } else {
            openTab(ref, focusTitle: focusTitle)
        }
    }

    public func selectAllOccurrences(on day: Date, in store: PlannerStore) {
        let dayOccs = RecurrenceEngine.occurrences(
            on: day,
            blocks: store.blocks,
            seriesList: store.seriesList,
            notes: store.notes,
            categories: store.categories,
            attachments: store.attachments,
            categoryFilterID: selectedCategoryFilterID
        )
        let refs = dayOccs.compactMap { occurrenceRef(for: $0) }
        guard !refs.isEmpty else { return }
        selectedItems = Set(refs)
        selectedItem = refs.first
        activePasteDate = Calendar.current.startOfDay(for: day)
    }

    public func clearMultiSelection() {
        if let current = selectedItem {
            selectedItems = [current]
        } else {
            selectedItems.removeAll()
        }
    }

    public var isMultiSelecting: Bool {
        selectedItems.count > 1
    }

    // MARK: - Copy, Paste & Bulk Delete Blocks

    private var toastClearTask: Task<Void, Never>?
    private var undoToastClearTask: Task<Void, Never>?

    public var canUndoDeletion: Bool {
        !deletionUndoStack.isEmpty
    }

    private func showClipboardToast(_ message: String) {
        clipboardToastMessage = message
        toastClearTask?.cancel()
        toastClearTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.4))
            guard !Task.isCancelled, let self else { return }
            self.clipboardToastMessage = nil
        }
    }

    private func pushDeletionUndo(_ entry: DeletionUndoEntry) {
        deletionUndoStack.append(entry)
        if deletionUndoStack.count > 30 {
            deletionUndoStack.removeFirst(deletionUndoStack.count - 30)
        }
        undoToastMessage = entry.label
        undoToastClearTask?.cancel()
        undoToastClearTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5.5))
            guard !Task.isCancelled, let self else { return }
            self.undoToastMessage = nil
        }
        #if os(macOS)
        // Resign text focus after deletion so immediate ⌘Z / ⌃Z restores the deleted block or note
        NSApp.keyWindow?.makeFirstResponder(nil)
        #endif
    }

    public func dismissUndoToast() {
        undoToastClearTask?.cancel()
        undoToastMessage = nil
    }

    /// Restores the most recently deleted block(s), recurring series, or note (including attachments & subnotes).
    @discardableResult
    public func undoLastDeletion(in store: PlannerStore) -> Bool {
        guard let entry = deletionUndoStack.popLast() else { return false }
        dismissUndoToast()
        let now = Date()

        for tombstoneID in entry.blockIDsToRemoveOnUndo {
            store.deleteBlock(id: tombstoneID)
        }

        for var series in entry.seriesToRestore {
            series.deletedAt = nil
            series.updatedAt = now
            store.upsertSeries(series)
        }

        for var block in entry.blocksToRestore {
            block.deletedAt = nil
            block.updatedAt = now
            store.upsertBlock(block)
            scheduleReminder(for: block)
        }

        for var note in entry.notesToRestore {
            note.deletedAt = nil
            note.updatedAt = now
            store.upsertNote(note)
        }

        for att in entry.attachmentsToRestore {
            store.upsertAttachment(att)
        }

        for rel in entry.childParentRestorations {
            if var child = store.note(for: rel.childID) {
                child.parentNoteID = rel.previousParentID
                child.updatedAt = now
                store.upsertNote(child)
            }
        }

        if let noteID = entry.focusNoteID, let restoredNote = store.note(for: noteID) {
            openGlobalNoteInNotes(restoredNote)
        } else if let blockID = entry.focusBlockID, let restoredBlock = store.block(for: blockID) {
            selectedSection = .agenda
            selectDate(restoredBlock.startDate)
            viewMode = .day
            openTab(.block(restoredBlock.id))
        } else if let firstSeries = entry.seriesToRestore.first {
            selectedSection = .agenda
            _ = firstSeries
        }

        showClipboardToast("Exclusão desfeita ✓")
        return true
    }

    /// Copies all currently selected blocks (or `fallbackOccurrence` if invoked via right-click on an unselected block).
    @discardableResult
    public func copySelectedBlocks(
        in store: PlannerStore,
        fallbackOccurrence: DayOccurrence? = nil
    ) -> Int {
        var targets: [DayOccurrence] = []

        if let fallback = fallbackOccurrence,
           let fallbackRef = occurrenceRef(for: fallback),
           !selectedItems.contains(fallbackRef) {
            targets = [fallback]
        } else {
            let refsToCopy: [SelectedItemRef]
            if !selectedItems.isEmpty {
                refsToCopy = Array(selectedItems)
            } else if let current = selectedItem {
                refsToCopy = [current]
            } else if let fallback = fallbackOccurrence {
                targets = [fallback]
                refsToCopy = []
            } else {
                refsToCopy = []
            }
            for ref in refsToCopy {
                if let occ = resolveOccurrence(for: ref, in: store) {
                    targets.append(occ)
                }
            }
        }

        guard !targets.isEmpty else { return 0 }

        let sortedTargets = targets.sorted { lhs, rhs in
            if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay && !rhs.isAllDay }
            return lhs.startDate < rhs.startDate
        }

        let cal = Calendar.current
        copiedBlocks = sortedTargets.map { occ in
            let dayStart = cal.startOfDay(for: occ.startDate)
            let startMin = TimelineMath.minuteOfDay(for: occ.startDate, on: dayStart)
            let endMin = TimelineMath.minuteOfDay(for: occ.endDate, on: dayStart)
            let dur = max(15, endMin - startMin)

            let sourceAttachments: [BlockAttachment]
            if occ.globalNote != nil {
                // Global blocks share their live attachments via globalNoteID — no need to duplicate bytes
                sourceAttachments = []
            } else if let block = occ.block {
                sourceAttachments = store.attachments(forBlockID: block.id)
            } else if let series = occ.series {
                sourceAttachments = store.attachments(forSeriesID: series.id)
            } else {
                sourceAttachments = []
            }

            return CopiedBlockSnapshot(
                title: occ.title,
                startMinuteOfDay: startMin,
                durationMinutes: dur,
                isAllDay: occ.isAllDay,
                reminderMinutesBefore: occ.reminderMinutesBefore,
                noteMarkdown: occ.globalNote == nil ? occ.noteMarkdown : "",
                categoryID: occ.category?.id,
                globalNoteID: occ.globalNote?.id,
                sourceDayStart: dayStart,
                attachments: sourceAttachments.map {
                    CopiedBlockSnapshot.ClonedAttachment(
                        originalID: $0.id,
                        fileName: $0.fileName,
                        mimeType: $0.mimeType,
                        imageData: $0.imageData
                    )
                }
            )
        }

        let count = copiedBlocks.count
        showClipboardToast(count == 1 ? "1 bloco copiado · ⌘V para colar" : "\(count) blocos copiados · ⌘V para colar")
        return count
    }

    /// Pastes all copied blocks onto `targetDay`, preserving relative timing, notes, Global Block links, and attachments.
    /// - When pasting onto a different day: preserves exact original start times.
    /// - When pasting onto the same day: shifts timed blocks slightly (+30 min) so copies are immediately visible.
    @discardableResult
    public func pasteCopiedBlocks(
        onto targetDay: Date,
        atStartMinute: Int? = nil,
        in store: PlannerStore
    ) -> [TimeBlock] {
        guard !copiedBlocks.isEmpty else { return [] }
        let cal = Calendar.current
        let targetDayStart = cal.startOfDay(for: targetDay)

        let timedCopies = copiedBlocks.filter { !$0.isAllDay }
        let earliestStart = timedCopies.map(\.startMinuteOfDay).min() ?? 540
        let latestEnd = timedCopies.map { $0.startMinuteOfDay + $0.durationMinutes }.max() ?? 600

        let deltaMinutes: Int
        if let requestedStart = atStartMinute {
            let maxAllowedShift = TimelineMath.minutesPerDay - latestEnd
            let minAllowedShift = -earliestStart
            deltaMinutes = max(minAllowedShift, min(maxAllowedShift, requestedStart - earliestStart))
        } else if let firstSourceDay = copiedBlocks.first?.sourceDayStart,
                  cal.isDate(firstSourceDay, inSameDayAs: targetDayStart) {
            let preferredShift = 30
            if latestEnd + preferredShift <= TimelineMath.minutesPerDay {
                deltaMinutes = preferredShift
            } else {
                deltaMinutes = max(-earliestStart, TimelineMath.minutesPerDay - latestEnd)
            }
        } else {
            deltaMinutes = 0
        }

        var createdBlocks: [TimeBlock] = []
        var newRefs: [SelectedItemRef] = []

        for snap in copiedBlocks {
            let blockStart: Date
            let blockEnd: Date
            if snap.isAllDay {
                blockStart = targetDayStart
                blockEnd = cal.date(byAdding: .day, value: 1, to: targetDayStart) ?? targetDayStart.addingTimeInterval(86400)
            } else {
                let sMin = max(0, min(TimelineMath.minutesPerDay - 15, snap.startMinuteOfDay + deltaMinutes))
                let eMin = max(sMin + 15, min(TimelineMath.minutesPerDay, sMin + snap.durationMinutes))
                blockStart = TimelineMath.date(on: targetDayStart, minuteOfDay: sMin)
                blockEnd = TimelineMath.date(on: targetDayStart, minuteOfDay: eMin)
            }

            var clonedMarkdown = snap.noteMarkdown
            var pasted = TimeBlock(
                title: snap.title,
                startDate: blockStart,
                endDate: blockEnd,
                isAllDay: snap.isAllDay,
                isCompleted: false,
                reminderMinutesBefore: snap.reminderMinutesBefore,
                noteMarkdown: clonedMarkdown,
                categoryID: snap.categoryID,
                globalNoteID: snap.globalNoteID
            )

            for att in snap.attachments {
                let newID = UUID()
                let cloned = BlockAttachment(
                    id: newID,
                    fileName: att.fileName,
                    mimeType: att.mimeType,
                    imageData: att.imageData,
                    blockID: pasted.id
                )
                store.upsertAttachment(cloned)
                clonedMarkdown = clonedMarkdown.replacingOccurrences(
                    of: att.originalID.uuidString,
                    with: newID.uuidString,
                    options: .caseInsensitive
                )
            }
            if !snap.attachments.isEmpty {
                pasted.updateNoteMarkdown(clonedMarkdown, attachmentCount: snap.attachments.count)
            }
            store.upsertBlock(pasted)

            createdBlocks.append(pasted)
            newRefs.append(.block(pasted.id))
        }

        if let firstRef = newRefs.first {
            openTab(firstRef, focusTitle: false)
            selectedItems = Set(newRefs)
        }

        let count = createdBlocks.count
        showClipboardToast(count == 1 ? "1 bloco colado" : "\(count) blocos colados")
        return createdBlocks
    }

    /// Deletes all selected blocks when in multi-selection mode, or delegates to single-block delete.
    @discardableResult
    public func deleteSelectedBlocks(in store: PlannerStore) -> Bool {
        if selectedItems.count > 1 {
            let refs = Array(selectedItems)
            var restoredBlocks: [TimeBlock] = []
            var tombstonesToRemove: [UUID] = []
            var restoredAttachments: [BlockAttachment] = []
            var firstFocusID: UUID? = nil

            for ref in refs {
                guard let occ = resolveOccurrence(for: ref, in: store) else { continue }
                if occ.series != nil {
                    if let existing = occ.block {
                        let latest = store.block(for: existing.id) ?? existing
                        restoredBlocks.append(latest)
                        if firstFocusID == nil { firstFocusID = latest.id }
                    }
                    let tombstone = deleteSingleOccurrenceDirectlyReturningTombstone(occ, in: store)
                    if occ.block == nil, let tid = tombstone {
                        tombstonesToRemove.append(tid)
                    }
                } else if let block = occ.block {
                    let latest = store.block(for: block.id) ?? block
                    restoredBlocks.append(latest)
                    restoredAttachments.append(contentsOf: store.attachments(forBlockID: latest.id))
                    if firstFocusID == nil { firstFocusID = latest.id }
                    _ = deleteSingleOccurrenceDirectlyReturningTombstone(occ, in: store)
                }
            }

            let count = restoredBlocks.count + tombstonesToRemove.count
            if count > 0 {
                pushDeletionUndo(DeletionUndoEntry(
                    label: count == 1 ? "Bloco apagado" : "\(count) blocos apagados",
                    blocksToRestore: restoredBlocks,
                    blockIDsToRemoveOnUndo: tombstonesToRemove,
                    seriesToRestore: [],
                    notesToRestore: [],
                    attachmentsToRestore: restoredAttachments,
                    childParentRestorations: [],
                    restoreToSection: .agenda,
                    focusBlockID: firstFocusID,
                    focusNoteID: nil
                ))
            }

            selectedItems.removeAll()
            selectedItem = openBlockTabs.last
            if let current = selectedItem {
                selectedItems = [current]
            }
            return true
        }
        guard let single = resolveSelectedOccurrence(in: store) else { return false }
        requestDelete(occurrence: single, in: store)
        return true
    }

    public func clearSelection() {
        if let current = selectedItem {
            closeTab(current)
        } else {
            isPhoneEditorSheetPresented = false
            shouldFocusTitleField = false
        }
    }

    public func resolveOccurrence(for ref: SelectedItemRef, in store: PlannerStore) -> DayOccurrence? {
        switch ref {
        case .block(let blockID):
            guard let block = store.block(for: blockID), !block.isDeletedOverride else {
                return nil
            }
            let day = Calendar.current.startOfDay(for: block.startDate)
            let series = block.seriesID.flatMap { store.series(for: $0) }
            let globalNote = (block.globalNoteID ?? series?.globalNoteID).flatMap { store.note(for: $0) }
            let catID = globalNote?.categoryID ?? block.categoryID
            return DayOccurrence(
                id: block.seriesID == nil ? "block-\(block.id.uuidString)" : "override-\(block.id.uuidString)",
                dayStart: day,
                startDate: block.startDate,
                endDate: block.endDate,
                isAllDay: block.isAllDay,
                title: globalNote?.title ?? block.title,
                isCompleted: block.isCompleted,
                reminderMinutesBefore: block.reminderMinutesBefore,
                noteMarkdown: globalNote?.noteMarkdown ?? block.noteMarkdown,
                category: store.category(for: catID),
                block: block,
                series: series,
                globalNote: globalNote,
                attachmentCount: globalNote.map { store.attachments(forNoteID: $0.id).count } ?? store.attachments(forBlockID: block.id).count
            )
        case .virtualOccurrence(let seriesID, let dayStart):
            guard let series = store.series(for: seriesID) else { return nil }
            let dayItems = RecurrenceEngine.occurrences(
                on: dayStart,
                blocks: store.blocks,
                seriesList: [series],
                notes: store.notes,
                categories: store.categories,
                attachments: store.attachments
            )
            return dayItems.first
        }
    }

    public func resolveSelectedOccurrence(in store: PlannerStore) -> DayOccurrence? {
        guard let selectedItem else { return nil }
        return resolveOccurrence(for: selectedItem, in: store)
    }

    public func resolvedOpenTabs(in store: PlannerStore) -> [(ref: SelectedItemRef, occurrence: DayOccurrence)] {
        openBlockTabs.compactMap { ref in
            guard let occ = resolveOccurrence(for: ref, in: store) else { return nil }
            return (ref, occ)
        }
    }

    // MARK: - Creating Blocks

    @discardableResult
    public func createTimedBlock(
        on day: Date,
        startMinute: Int,
        endMinute: Int,
        in store: PlannerStore
    ) -> TimeBlock {
        let dayStart = Calendar.current.startOfDay(for: day)
        let safeStart = max(0, min(TimelineMath.minutesPerDay - 15, startMinute))
        let safeEnd = max(safeStart + 15, min(TimelineMath.minutesPerDay, endMinute))

        let startDate = TimelineMath.date(on: dayStart, minuteOfDay: safeStart)
        let endDate = TimelineMath.date(on: dayStart, minuteOfDay: safeEnd)

        let block = TimeBlock(
            title: "",
            startDate: startDate,
            endDate: endDate,
            isAllDay: false,
            reminderMinutesBefore: ReminderPreferences.defaultOption.minutesBefore,
            categoryID: selectedCategoryFilterID
        )
        store.upsertBlock(block)
        openTab(.block(block.id), focusTitle: true)
        return block
    }

    @discardableResult
    public func createAllDayBlock(
        on day: Date,
        in store: PlannerStore
    ) -> TimeBlock {
        let dayStart = Calendar.current.startOfDay(for: day)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86400)

        let block = TimeBlock(
            title: "",
            startDate: dayStart,
            endDate: dayEnd,
            isAllDay: true,
            categoryID: selectedCategoryFilterID
        )
        store.upsertBlock(block)
        openTab(.block(block.id), focusTitle: true)
        return block
    }

    // MARK: - Per-Day Independent Note & Completion Mutations

    /// Ensures a concrete `TimeBlock` exists for an occurrence (materializing a per-day override
    /// automatically if it was a virtual recurring occurrence) and updates selection cleanly.
    public func ensureConcreteBlock(
        for occurrence: DayOccurrence,
        in store: PlannerStore
    ) -> TimeBlock {
        if let block = occurrence.block {
            return store.block(for: block.id) ?? block
        }
        guard let series = occurrence.series else {
            let fallback = TimeBlock(
                title: occurrence.title,
                startDate: occurrence.startDate,
                endDate: occurrence.endDate,
                isAllDay: occurrence.isAllDay,
                noteMarkdown: occurrence.noteMarkdown,
                categoryID: occurrence.category?.id
            )
            store.upsertBlock(fallback)
            selectedItem = .block(fallback.id)
            return fallback
        }
        let override = RecurrenceEngine.materializeOverride(
            for: series,
            on: occurrence.dayStart,
            in: store
        )
        let virtualRef = SelectedItemRef.virtualOccurrence(seriesID: series.id, dayStart: occurrence.dayStart)
        let concreteRef = SelectedItemRef.block(override.id)
        if let tabIdx = openBlockTabs.firstIndex(where: { ref in
            if case .virtualOccurrence(let sID, let dStart) = ref {
                return sID == series.id && Calendar.current.isDate(dStart, inSameDayAs: occurrence.dayStart)
            }
            return false
        }) {
            openBlockTabs[tabIdx] = concreteRef
        }
        if case .virtualOccurrence(let sID, let dStart) = selectedItem,
           sID == series.id,
           Calendar.current.isDate(dStart, inSameDayAs: occurrence.dayStart) {
            selectedItem = concreteRef
        }
        _ = virtualRef
        return override
    }

    public func toggleCompletion(for occurrence: DayOccurrence, in store: PlannerStore) {
        var block = ensureConcreteBlock(for: occurrence, in: store)
        block.isCompleted.toggle()
        block.updatedAt = Date()
        store.upsertBlock(block)
    }

    public func updateNoteMarkdown(
        _ markdown: String,
        for occurrence: DayOccurrence,
        in store: PlannerStore
    ) {
        // If linked to a Global Block, edit the single living Global document directly!
        if var globalNote = occurrence.globalNote {
            let latest = store.note(for: globalNote.id) ?? globalNote
            guard latest.noteMarkdown != markdown else { return }
            globalNote = latest
            let attCount = store.attachments(forNoteID: globalNote.id).count
            globalNote.updateNoteMarkdown(markdown, attachmentCount: attCount)
            store.upsertNote(globalNote)
            return
        }
        var block = ensureConcreteBlock(for: occurrence, in: store)
        guard block.noteMarkdown != markdown else { return }
        let attCount = store.attachments(forBlockID: block.id).count
        block.updateNoteMarkdown(markdown, attachmentCount: attCount)
        store.upsertBlock(block)
    }

    public func updateOccurrenceTitle(
        _ title: String,
        for occurrence: DayOccurrence,
        in store: PlannerStore
    ) {
        if var globalNote = occurrence.globalNote {
            let latest = store.note(for: globalNote.id) ?? globalNote
            guard latest.title != title else { return }
            globalNote = latest
            globalNote.title = title
            globalNote.updatedAt = Date()
            store.upsertNote(globalNote)
            if var series = occurrence.series {
                let latestSeries = store.series(for: series.id) ?? series
                series = latestSeries
                series.title = title
                series.updatedAt = Date()
                store.upsertSeries(series)
            }
            return
        }

        if let series = occurrence.series {
            let latestSeries = store.series(for: series.id) ?? series
            guard latestSeries.title != title || occurrence.block?.title != title else { return }
            var updatedSeries = latestSeries
            updatedSeries.title = title
            updatedSeries.updatedAt = Date()
            store.upsertSeries(updatedSeries)

            for var overrideBlock in store.blocks where overrideBlock.seriesID == series.id && !overrideBlock.isDeletedOverride {
                if overrideBlock.title != title {
                    overrideBlock.title = title
                    overrideBlock.updatedAt = Date()
                    store.upsertBlock(overrideBlock)
                }
            }
            return
        }

        var block = ensureConcreteBlock(for: occurrence, in: store)
        guard block.title != title else { return }
        block.title = title
        block.updatedAt = Date()
        store.upsertBlock(block)
    }

    public func updateOccurrenceCategory(
        _ categoryID: UUID?,
        for occurrence: DayOccurrence,
        in store: PlannerStore
    ) {
        if let globalNote = occurrence.globalNote {
            var latest = store.note(for: globalNote.id) ?? globalNote
            latest.categoryID = categoryID
            latest.updatedAt = Date()
            store.upsertNote(latest)
            if var series = occurrence.series {
                series = store.series(for: series.id) ?? series
                series.categoryID = categoryID
                series.updatedAt = Date()
                store.upsertSeries(series)
            }
            return
        }

        if let series = occurrence.series {
            var updatedSeries = store.series(for: series.id) ?? series
            updatedSeries.categoryID = categoryID
            updatedSeries.updatedAt = Date()
            store.upsertSeries(updatedSeries)

            for var overrideBlock in store.blocks where overrideBlock.seriesID == series.id && !overrideBlock.isDeletedOverride {
                if overrideBlock.categoryID != categoryID {
                    overrideBlock.categoryID = categoryID
                    overrideBlock.updatedAt = Date()
                    store.upsertBlock(overrideBlock)
                }
            }
            return
        }

        var block = ensureConcreteBlock(for: occurrence, in: store)
        block.categoryID = categoryID
        block.updatedAt = Date()
        store.upsertBlock(block)
    }

    /// Saves the current day's Markdown note (and any inline image attachments) as the template
    /// for all future unedited occurrences of this `RecurrenceSeries`.
    public func applyNoteAsSeriesTemplate(
        for occurrence: DayOccurrence,
        in store: PlannerStore
    ) {
        guard let series = occurrence.series, !occurrence.isGlobalLinked else { return }
        var updatedSeries = store.series(for: series.id) ?? series
        var templateMD = occurrence.noteMarkdown

        // Replace previous template attachments with fresh clones of this occurrence's attachments (if concrete)
        if let block = occurrence.block {
            let oldTemplateAtts = store.attachments(forSeriesID: updatedSeries.id)
            for old in oldTemplateAtts {
                store.deleteAttachment(id: old.id)
            }
            let blockAtts = store.attachments(forBlockID: block.id)
            for att in blockAtts {
                let newID = UUID()
                let copy = BlockAttachment(
                    id: newID,
                    fileName: att.fileName,
                    mimeType: att.mimeType,
                    imageData: att.imageData,
                    seriesID: updatedSeries.id
                )
                store.upsertAttachment(copy)
                templateMD = templateMD.replacingOccurrences(
                    of: att.id.uuidString,
                    with: newID.uuidString,
                    options: .caseInsensitive
                )
            }
            updatedSeries.updateTemplateMarkdown(templateMD, attachmentCount: blockAtts.count)
        } else {
            updatedSeries.updateTemplateMarkdown(templateMD, attachmentCount: store.attachments(forSeriesID: updatedSeries.id).count)
        }

        store.upsertSeries(updatedSeries)
        showClipboardToast("Modelo salvo para os próximos dias")
    }

    public func toggleChecklistLine(
        at lineIndex: Int,
        for occurrence: DayOccurrence,
        in store: PlannerStore
    ) {
        let updated = RichNoteDocument.toggleChecklist(at: lineIndex, in: occurrence.noteMarkdown)
        updateNoteMarkdown(updated, for: occurrence, in: store)
    }

    public func attachImage(
        rawData: Data,
        fileName: String,
        to occurrence: DayOccurrence,
        in store: PlannerStore
    ) {
        guard let normalized = PlatformHelpers.normalizedImageData(from: rawData) else { return }
        if let globalNote = occurrence.globalNote {
            var latest = store.note(for: globalNote.id) ?? globalNote
            let att = BlockAttachment(
                fileName: fileName,
                mimeType: normalized.mimeType,
                imageData: normalized.data,
                noteID: latest.id
            )
            store.upsertAttachment(att)
            let updatedMD = RichNoteDocument.appendImageReference(attachmentID: att.id, caption: "", to: latest.noteMarkdown)
            latest.updateNoteMarkdown(updatedMD, attachmentCount: store.attachments(forNoteID: latest.id).count)
            store.upsertNote(latest)
            return
        }
        var block = ensureConcreteBlock(for: occurrence, in: store)
        let attachment = BlockAttachment(
            fileName: fileName,
            mimeType: normalized.mimeType,
            imageData: normalized.data,
            blockID: block.id
        )
        store.upsertAttachment(attachment)
        let updatedMD = RichNoteDocument.appendImageReference(
            attachmentID: attachment.id,
            caption: "",
            to: block.noteMarkdown
        )
        let attCount = store.attachments(forBlockID: block.id).count
        block.updateNoteMarkdown(updatedMD, attachmentCount: attCount)
        store.upsertBlock(block)
    }

    public func removeAttachment(
        _ attachment: BlockAttachment,
        from occurrence: DayOccurrence,
        in store: PlannerStore
    ) {
        if let globalNote = occurrence.globalNote {
            var latest = store.note(for: globalNote.id) ?? globalNote
            let cleaned = RichNoteDocument.removeImageReference(attachmentID: attachment.id, from: latest.noteMarkdown)
            store.deleteAttachment(id: attachment.id)
            latest.updateNoteMarkdown(cleaned, attachmentCount: store.attachments(forNoteID: latest.id).count)
            store.upsertNote(latest)
            return
        }
        var block = ensureConcreteBlock(for: occurrence, in: store)
        let targetAttachment: BlockAttachment
        if attachment.blockID == block.id {
            targetAttachment = attachment
        } else if let cloned = store.attachments(forBlockID: block.id).first(where: { $0.fileName == attachment.fileName }) {
            targetAttachment = cloned
        } else {
            return
        }
        let cleaned = RichNoteDocument.removeImageReference(attachmentID: targetAttachment.id, from: block.noteMarkdown)
        store.deleteAttachment(id: targetAttachment.id)
        let remaining = store.attachments(forBlockID: block.id).count
        block.updateNoteMarkdown(cleaned, attachmentCount: remaining)
        store.upsertBlock(block)
    }

    // MARK: - Reschedule / Metadata / Delete (with Recurring Scope Prompt)

    public func requestReschedule(
        occurrence: DayOccurrence,
        newStart: Date,
        newEnd: Date,
        isAllDay: Bool,
        in store: PlannerStore
    ) {
        let safeEnd = max(newEnd, newStart.addingTimeInterval(15 * 60))
        if let series = occurrence.series {
            pendingRecurrenceDecision = PendingRecurrenceDecision(
                series: store.series(for: series.id) ?? series,
                dayStart: occurrence.dayStart,
                existingOverride: occurrence.block,
                kind: .reschedule(newStart: newStart, newEnd: safeEnd, isAllDay: isAllDay)
            )
            return
        }

        var block = ensureConcreteBlock(for: occurrence, in: store)
        block.startDate = newStart
        block.endDate = safeEnd
        block.isAllDay = isAllDay
        block.updatedAt = Date()
        store.upsertBlock(block)
        scheduleReminder(for: block)
    }

    public func requestMetadataUpdate(
        occurrence: DayOccurrence,
        title: String,
        categoryID: UUID?,
        reminderMinutesBefore: Int?,
        promptIfRecurring: Bool,
        in store: PlannerStore
    ) {
        if let series = occurrence.series, promptIfRecurring {
            pendingRecurrenceDecision = PendingRecurrenceDecision(
                series: store.series(for: series.id) ?? series,
                dayStart: occurrence.dayStart,
                existingOverride: occurrence.block,
                kind: .updateMetadata(
                    title: title,
                    categoryID: categoryID,
                    reminderMinutesBefore: reminderMinutesBefore
                )
            )
            return
        }

        var block = ensureConcreteBlock(for: occurrence, in: store)
        block.title = title
        block.categoryID = categoryID
        block.reminderMinutesBefore = reminderMinutesBefore
        block.updatedAt = Date()
        store.upsertBlock(block)
        scheduleReminder(for: block)
    }

    public func requestDelete(occurrence: DayOccurrence, in store: PlannerStore) {
        if let series = occurrence.series {
            pendingRecurrenceDecision = PendingRecurrenceDecision(
                series: store.series(for: series.id) ?? series,
                dayStart: occurrence.dayStart,
                existingOverride: occurrence.block,
                kind: .delete
            )
            return
        }

        if let block = occurrence.block {
            let latest = store.block(for: block.id) ?? block
            let atts = store.attachments(forBlockID: latest.id)
            let name = latest.title.trimmingCharacters(in: .whitespacesAndNewlines)
            pushDeletionUndo(DeletionUndoEntry(
                label: name.isEmpty ? "Bloco apagado" : "\"\(name)\" apagado",
                blocksToRestore: [latest],
                blockIDsToRemoveOnUndo: [],
                seriesToRestore: [],
                notesToRestore: [],
                attachmentsToRestore: atts,
                childParentRestorations: [],
                restoreToSection: .agenda,
                focusBlockID: latest.id,
                focusNoteID: nil
            ))
        }

        _ = deleteSingleOccurrenceDirectlyReturningTombstone(occurrence, in: store)
    }

    /// Immediately deletes a standalone block or hides only a single day's occurrence of a recurring series
    /// without prompting (used by single standalone delete and bulk multi-selection delete).
    @discardableResult
    private func deleteSingleOccurrenceDirectlyReturningTombstone(_ occurrence: DayOccurrence, in store: PlannerStore) -> UUID? {
        if let series = occurrence.series {
            var override = occurrence.block ?? RecurrenceEngine.materializeOverride(
                for: series,
                on: occurrence.dayStart,
                in: store
            )
            override.isDeletedOverride = true
            override.updatedAt = Date()
            store.upsertBlock(override)
            closeTab(.block(override.id))
            closeTab(.virtualOccurrence(seriesID: series.id, dayStart: occurrence.dayStart))
            return override.id
        }

        if let block = occurrence.block {
            let blockID = block.id.uuidString
            Task { await ReminderScheduler.shared.cancel(identifier: blockID) }
            store.deleteBlock(id: block.id)
            closeTab(.block(block.id))
        }
        return nil
    }

    public func applyPendingRecurrenceDecision(
        scope: RecurrenceEditScope,
        in store: PlannerStore
    ) {
        guard let decision = pendingRecurrenceDecision else { return }
        pendingRecurrenceDecision = nil

        let cal = Calendar.current
        let decisionDay = cal.startOfDay(for: decision.dayStart)

        switch (decision.kind, scope) {
        case (.reschedule(let newStart, let newEnd, let isAllDay), .onlyThisDay):
            var override = decision.existingOverride ?? RecurrenceEngine.materializeOverride(
                for: decision.series,
                on: decisionDay,
                in: store
            )
            override.startDate = newStart
            override.endDate = max(newEnd, newStart.addingTimeInterval(15 * 60))
            override.isAllDay = isAllDay
            override.updatedAt = Date()
            store.upsertBlock(override)
            openTab(.block(override.id))
            scheduleReminder(for: override)

        case (.reschedule(let newStart, let newEnd, let isAllDay), .thisAndFuture):
            let latestSeries = store.series(for: decision.series.id) ?? decision.series
            let seriesStart = cal.startOfDay(for: latestSeries.seriesStartDate)
            if decisionDay <= seriesStart {
                applyRescheduleToEntireSeries(latestSeries, newStart: newStart, newEnd: newEnd, isAllDay: isAllDay, in: store)
                return
            }

            let targetDay = cal.startOfDay(for: newStart)
            let startMin = TimelineMath.minuteOfDay(for: newStart, on: targetDay)
            let endMin = TimelineMath.minuteOfDay(for: newEnd, on: targetDay)
            let duration = max(15, endMin - startMin)

            // 1. Terminate previous series on the day before `decisionDay` to preserve past history & streaks
            let dayBefore = cal.date(byAdding: .day, value: -1, to: decisionDay) ?? decisionDay.addingTimeInterval(-86400)
            var endedOld = latestSeries
            endedOld.seriesEndDate = dayBefore
            endedOld.updatedAt = Date()
            store.upsertSeries(endedOld)

            // 2. Spawn continuation series starting on `decisionDay` with the new schedule
            var futureSeries = RecurrenceSeries(
                title: latestSeries.title,
                ruleType: latestSeries.ruleType,
                weekdaysMask: latestSeries.weekdaysMask,
                startMinuteOfDay: startMin,
                durationMinutes: duration,
                isAllDay: isAllDay,
                reminderMinutesBefore: latestSeries.reminderMinutesBefore,
                templateMarkdown: latestSeries.templateMarkdown,
                seriesStartDate: decisionDay,
                seriesEndDate: latestSeries.seriesEndDate,
                categoryID: latestSeries.categoryID,
                globalNoteID: latestSeries.globalNoteID
            )
            let oldAtts = store.attachments(forSeriesID: latestSeries.id)
            if !oldAtts.isEmpty {
                var clonedMD = futureSeries.templateMarkdown
                for att in oldAtts {
                    let newID = UUID()
                    let copy = BlockAttachment(
                        id: newID,
                        fileName: att.fileName,
                        mimeType: att.mimeType,
                        imageData: att.imageData,
                        seriesID: futureSeries.id
                    )
                    store.upsertAttachment(copy)
                    clonedMD = clonedMD.replacingOccurrences(of: att.id.uuidString, with: newID.uuidString, options: .caseInsensitive)
                }
                futureSeries.updateTemplateMarkdown(clonedMD, attachmentCount: oldAtts.count)
            }
            store.upsertSeries(futureSeries)

            // 3. Re-parent existing overrides on or after `decisionDay` to `futureSeries` and update their time-of-day
            var updatedCurrentOverrideID: UUID? = nil
            for var ov in store.blocks where ov.seriesID == latestSeries.id {
                let origDay = cal.startOfDay(for: ov.occurrenceOriginalDate ?? ov.startDate)
                guard origDay >= decisionDay else { continue }
                ov.seriesID = futureSeries.id
                if !ov.isDeletedOverride {
                    if isAllDay {
                        ov.isAllDay = true
                        ov.startDate = origDay
                        ov.endDate = cal.date(byAdding: .day, value: 1, to: origDay) ?? origDay.addingTimeInterval(86400)
                    } else {
                        ov.isAllDay = false
                        ov.startDate = TimelineMath.date(on: origDay, minuteOfDay: startMin)
                        ov.endDate = TimelineMath.date(on: origDay, minuteOfDay: min(TimelineMath.minutesPerDay, startMin + duration))
                    }
                }
                ov.updatedAt = Date()
                store.upsertBlock(ov)
                if cal.isDate(origDay, inSameDayAs: decisionDay) {
                    updatedCurrentOverrideID = ov.id
                }
            }

            closeTab(.virtualOccurrence(seriesID: latestSeries.id, dayStart: decisionDay))
            if let ovID = updatedCurrentOverrideID {
                openTab(.block(ovID))
            } else {
                openTab(.virtualOccurrence(seriesID: futureSeries.id, dayStart: decisionDay))
            }

        case (.reschedule(let newStart, let newEnd, let isAllDay), .entireSeries):
            let latestSeries = store.series(for: decision.series.id) ?? decision.series
            applyRescheduleToEntireSeries(latestSeries, newStart: newStart, newEnd: newEnd, isAllDay: isAllDay, in: store)

        case (.updateMetadata(let title, let categoryID, let reminder), .onlyThisDay):
            var override = decision.existingOverride ?? RecurrenceEngine.materializeOverride(
                for: decision.series,
                on: decisionDay,
                in: store
            )
            override.title = title
            override.categoryID = categoryID
            override.reminderMinutesBefore = reminder
            override.updatedAt = Date()
            store.upsertBlock(override)
            openTab(.block(override.id))
            scheduleReminder(for: override)

        case (.updateMetadata(let title, let categoryID, let reminder), .thisAndFuture),
             (.updateMetadata(let title, let categoryID, let reminder), .entireSeries):
            var updatedSeries = store.series(for: decision.series.id) ?? decision.series
            updatedSeries.title = title
            updatedSeries.categoryID = categoryID
            updatedSeries.reminderMinutesBefore = reminder
            updatedSeries.updatedAt = Date()
            store.upsertSeries(updatedSeries)

            for var ov in store.blocks where ov.seriesID == updatedSeries.id && !ov.isDeletedOverride {
                ov.title = title
                ov.categoryID = categoryID
                ov.reminderMinutesBefore = reminder
                ov.updatedAt = Date()
                store.upsertBlock(ov)
                scheduleReminder(for: ov)
            }

        case (.delete, .onlyThisDay):
            let previousOverride = decision.existingOverride.flatMap { store.block(for: $0.id) ?? $0 }
            var override = previousOverride ?? RecurrenceEngine.materializeOverride(
                for: decision.series,
                on: decisionDay,
                in: store
            )
            override.isDeletedOverride = true
            override.updatedAt = Date()
            store.upsertBlock(override)

            pushDeletionUndo(DeletionUndoEntry(
                label: "Ocorrência apagada",
                blocksToRestore: previousOverride.map { [$0] } ?? [],
                blockIDsToRemoveOnUndo: previousOverride == nil ? [override.id] : [],
                seriesToRestore: [],
                notesToRestore: [],
                attachmentsToRestore: [],
                childParentRestorations: [],
                restoreToSection: .agenda,
                focusBlockID: previousOverride?.id,
                focusNoteID: nil
            ))

            closeTab(.block(override.id))
            closeTab(.virtualOccurrence(seriesID: decision.series.id, dayStart: decisionDay))

        case (.delete, .thisAndFuture):
            let latestSeries = store.series(for: decision.series.id) ?? decision.series
            let seriesStart = cal.startOfDay(for: latestSeries.seriesStartDate)
            if decisionDay <= seriesStart {
                deleteEntireSeriesWithUndo(latestSeries, in: store)
                return
            }

            let futureOverrides = store.blocks.filter { ov in
                ov.seriesID == latestSeries.id && cal.startOfDay(for: ov.occurrenceOriginalDate ?? ov.startDate) >= decisionDay
            }
            let futureAtts = futureOverrides.flatMap { store.attachments(forBlockID: $0.id) }

            let dayBefore = cal.date(byAdding: .day, value: -1, to: decisionDay) ?? decisionDay.addingTimeInterval(-86400)
            var ended = latestSeries
            ended.seriesEndDate = dayBefore
            ended.updatedAt = Date()
            store.upsertSeries(ended)

            for ov in futureOverrides {
                store.deleteBlock(id: ov.id)
                closeTab(.block(ov.id))
            }
            closeTab(.virtualOccurrence(seriesID: latestSeries.id, dayStart: decisionDay))

            pushDeletionUndo(DeletionUndoEntry(
                label: "Ocorrências futuras apagadas",
                blocksToRestore: futureOverrides,
                blockIDsToRemoveOnUndo: [],
                seriesToRestore: [latestSeries],
                notesToRestore: [],
                attachmentsToRestore: futureAtts,
                childParentRestorations: [],
                restoreToSection: .agenda,
                focusBlockID: futureOverrides.first?.id,
                focusNoteID: nil
            ))

        case (.delete, .entireSeries):
            let latestSeries = store.series(for: decision.series.id) ?? decision.series
            deleteEntireSeriesWithUndo(latestSeries, in: store)
        }
    }

    private func deleteEntireSeriesWithUndo(_ series: RecurrenceSeries, in store: PlannerStore) {
        let relatedBlocks = store.blocks.filter { $0.seriesID == series.id }
        var atts = store.attachments(forSeriesID: series.id)
        for b in relatedBlocks {
            atts.append(contentsOf: store.attachments(forBlockID: b.id))
        }

        store.deleteSeries(id: series.id)
        for b in relatedBlocks {
            closeTab(.block(b.id))
        }
        closeTabsForSeries(series.id)

        let title = series.title.trimmingCharacters(in: .whitespacesAndNewlines)
        pushDeletionUndo(DeletionUndoEntry(
            label: title.isEmpty ? "Série recorrente apagada" : "Série \"\(title)\" apagada",
            blocksToRestore: relatedBlocks,
            blockIDsToRemoveOnUndo: [],
            seriesToRestore: [series],
            notesToRestore: [],
            attachmentsToRestore: atts,
            childParentRestorations: [],
            restoreToSection: .agenda,
            focusBlockID: relatedBlocks.first?.id,
            focusNoteID: nil
        ))
    }

    private func applyRescheduleToEntireSeries(
        _ series: RecurrenceSeries,
        newStart: Date,
        newEnd: Date,
        isAllDay: Bool,
        in store: PlannerStore
    ) {
        let cal = Calendar.current
        let day = cal.startOfDay(for: newStart)
        let startMin = TimelineMath.minuteOfDay(for: newStart, on: day)
        let endMin = TimelineMath.minuteOfDay(for: newEnd, on: day)
        let duration = max(15, endMin - startMin)

        var updatedSeries = series
        updatedSeries.startMinuteOfDay = startMin
        updatedSeries.durationMinutes = duration
        updatedSeries.isAllDay = isAllDay
        updatedSeries.updatedAt = Date()
        store.upsertSeries(updatedSeries)

        for var ov in store.blocks where ov.seriesID == series.id && !ov.isDeletedOverride {
            let ovDay = cal.startOfDay(for: ov.occurrenceOriginalDate ?? ov.startDate)
            if isAllDay {
                ov.isAllDay = true
                ov.startDate = ovDay
                ov.endDate = cal.date(byAdding: .day, value: 1, to: ovDay) ?? ovDay.addingTimeInterval(86400)
            } else {
                ov.isAllDay = false
                ov.startDate = TimelineMath.date(on: ovDay, minuteOfDay: startMin)
                ov.endDate = TimelineMath.date(on: ovDay, minuteOfDay: min(TimelineMath.minutesPerDay, startMin + duration))
            }
            ov.updatedAt = Date()
            store.upsertBlock(ov)
            scheduleReminder(for: ov)
        }
    }

    private func closeTabsForSeries(_ seriesID: UUID) {
        let matching = openBlockTabs.filter { ref in
            if case .virtualOccurrence(let sID, _) = ref {
                return sID == seriesID
            }
            return false
        }
        for ref in matching {
            closeTab(ref)
        }
    }

    public func scheduleReminder(for block: TimeBlock) {
        let id = block.id.uuidString
        let title = block.title
        let preview = block.summary().previewText
        let start = block.startDate
        let minutes = block.isAllDay ? nil : block.reminderMinutesBefore
        Task {
            await ReminderScheduler.shared.schedule(
                identifier: id,
                title: title,
                body: preview,
                startDate: start,
                minutesBefore: minutes
            )
        }
    }

    // MARK: - Notes Workspace CRUD & Agenda Bridge

    public func selectNoteItem(_ item: UnifiedNoteItem, focusTitle: Bool = false) {
        shouldFocusNoteTitleField = focusTitle
        selectedNoteItemID = item.id
        #if os(macOS)
        if !focusTitle {
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
        #endif
    }

    @discardableResult
    public func createStandaloneNote(in store: PlannerStore) -> StandaloneNote {
        let note = StandaloneNote(
            title: "",
            noteMarkdown: "",
            isPinned: false,
            categoryID: selectedCategoryFilterID
        )
        store.upsertNote(note)
        selectedSection = .notes
        if notesOriginFilter == .agendaOnly {
            notesOriginFilter = .all
        }
        notesFilterByDay = false
        selectedNoteItemID = "note-\(note.id.uuidString)"
        shouldFocusNoteTitleField = true
        return note
    }

    @discardableResult
    public func importMarkdownNote(title: String, markdown: String, in store: PlannerStore) -> StandaloneNote {
        let note = StandaloneNote(
            title: title,
            noteMarkdown: markdown,
            isPinned: false,
            categoryID: selectedCategoryFilterID
        )
        store.upsertNote(note)
        selectedSection = .notes
        if notesOriginFilter == .agendaOnly {
            notesOriginFilter = .all
        }
        notesFilterByDay = false
        selectedNoteItemID = "note-\(note.id.uuidString)"
        shouldFocusNoteTitleField = false
        return note
    }

    public func togglePin(for note: StandaloneNote, in store: PlannerStore) {
        var updated = store.note(for: note.id) ?? note
        updated.isPinned.toggle()
        updated.updatedAt = Date()
        store.upsertNote(updated)
    }

    public func updateUnifiedNoteTitle(_ title: String, for item: UnifiedNoteItem, in store: PlannerStore) {
        switch item.source {
        case .standalone(let note):
            var updated = store.note(for: note.id) ?? note
            guard updated.title != title else { return }
            updated.title = title
            updated.updatedAt = Date()
            store.upsertNote(updated)
        case .agendaBlock(let block):
            var updated = store.block(for: block.id) ?? block
            guard updated.title != title else { return }
            updated.title = title
            updated.updatedAt = Date()
            store.upsertBlock(updated)
        }
    }

    public func updateUnifiedNoteCategory(_ categoryID: UUID?, for item: UnifiedNoteItem, in store: PlannerStore) {
        switch item.source {
        case .standalone(let note):
            var updated = store.note(for: note.id) ?? note
            updated.categoryID = categoryID
            updated.updatedAt = Date()
            store.upsertNote(updated)
        case .agendaBlock(let block):
            var updated = store.block(for: block.id) ?? block
            updated.categoryID = categoryID
            updated.updatedAt = Date()
            store.upsertBlock(updated)
        }
    }

    public func updateUnifiedNoteMarkdown(_ markdown: String, for item: UnifiedNoteItem, in store: PlannerStore) {
        switch item.source {
        case .standalone(let note):
            var updated = store.note(for: note.id) ?? note
            guard updated.noteMarkdown != markdown else { return }
            let attCount = store.attachments(forNoteID: updated.id).count
            updated.updateNoteMarkdown(markdown, attachmentCount: attCount)
            store.upsertNote(updated)
        case .agendaBlock(let block):
            var updated = store.block(for: block.id) ?? block
            guard updated.noteMarkdown != markdown else { return }
            let attCount = store.attachments(forBlockID: updated.id).count
            updated.updateNoteMarkdown(markdown, attachmentCount: attCount)
            store.upsertBlock(updated)
        }
    }

    public func toggleUnifiedNoteChecklistLine(at lineIndex: Int, for item: UnifiedNoteItem, in store: PlannerStore) {
        let updated = RichNoteDocument.toggleChecklist(at: lineIndex, in: item.noteMarkdown)
        updateUnifiedNoteMarkdown(updated, for: item, in: store)
    }

    public func attachImage(rawData: Data, fileName: String, to item: UnifiedNoteItem, in store: PlannerStore) {
        guard let normalized = PlatformHelpers.normalizedImageData(from: rawData) else { return }
        switch item.source {
        case .standalone(let note):
            var updated = store.note(for: note.id) ?? note
            let att = BlockAttachment(
                fileName: fileName,
                mimeType: normalized.mimeType,
                imageData: normalized.data,
                noteID: updated.id
            )
            store.upsertAttachment(att)
            let updatedMD = RichNoteDocument.appendImageReference(attachmentID: att.id, to: updated.noteMarkdown)
            updated.updateNoteMarkdown(updatedMD, attachmentCount: store.attachments(forNoteID: updated.id).count)
            store.upsertNote(updated)
        case .agendaBlock(let block):
            var updated = store.block(for: block.id) ?? block
            let att = BlockAttachment(
                fileName: fileName,
                mimeType: normalized.mimeType,
                imageData: normalized.data,
                blockID: updated.id
            )
            store.upsertAttachment(att)
            let updatedMD = RichNoteDocument.appendImageReference(attachmentID: att.id, to: updated.noteMarkdown)
            updated.updateNoteMarkdown(updatedMD, attachmentCount: store.attachments(forBlockID: updated.id).count)
            store.upsertBlock(updated)
        }
    }

    public func removeAttachment(_ attachment: BlockAttachment, from item: UnifiedNoteItem, in store: PlannerStore) {
        switch item.source {
        case .standalone(let note):
            var updated = store.note(for: note.id) ?? note
            let cleaned = RichNoteDocument.removeImageReference(attachmentID: attachment.id, from: updated.noteMarkdown)
            store.deleteAttachment(id: attachment.id)
            updated.updateNoteMarkdown(cleaned, attachmentCount: store.attachments(forNoteID: updated.id).count)
            store.upsertNote(updated)
        case .agendaBlock(let block):
            var updated = store.block(for: block.id) ?? block
            let cleaned = RichNoteDocument.removeImageReference(attachmentID: attachment.id, from: updated.noteMarkdown)
            store.deleteAttachment(id: attachment.id)
            updated.updateNoteMarkdown(cleaned, attachmentCount: store.attachments(forBlockID: updated.id).count)
            store.upsertBlock(updated)
        }
    }

    public func deleteStandaloneNote(_ note: StandaloneNote, in store: PlannerStore) {
        let latest = store.note(for: note.id) ?? note
        let atts = store.attachments(forNoteID: latest.id)
        let directChildren = store.notes
            .filter { $0.parentNoteID == latest.id }
            .map { (childID: $0.id, previousParentID: Optional(latest.id)) }

        store.deleteNote(id: latest.id)
        if selectedNoteItemID == "note-\(latest.id.uuidString)" {
            selectedNoteItemID = nil
        }

        let name = latest.title.trimmingCharacters(in: .whitespacesAndNewlines)
        pushDeletionUndo(DeletionUndoEntry(
            label: name.isEmpty ? "Nota apagada" : "Nota \"\(name)\" apagada",
            blocksToRestore: [],
            blockIDsToRemoveOnUndo: [],
            seriesToRestore: [],
            notesToRestore: [latest],
            attachmentsToRestore: atts,
            childParentRestorations: directChildren,
            restoreToSection: .notes,
            focusBlockID: nil,
            focusNoteID: latest.id
        ))
    }

    public func deleteNoteItem(_ item: UnifiedNoteItem, in store: PlannerStore) {
        switch item.source {
        case .standalone(let note):
            deleteStandaloneNote(note, in: store)
        case .agendaBlock(let block):
            let latest = store.block(for: block.id) ?? block
            let atts = store.attachments(forBlockID: latest.id)
            store.deleteBlock(id: latest.id)
            closeTab(.block(latest.id))
            if selectedNoteItemID == item.id {
                selectedNoteItemID = nil
            }
            let name = latest.title.trimmingCharacters(in: .whitespacesAndNewlines)
            pushDeletionUndo(DeletionUndoEntry(
                label: name.isEmpty ? "Bloco apagado" : "\"\(name)\" apagado",
                blocksToRestore: [latest],
                blockIDsToRemoveOnUndo: [],
                seriesToRestore: [],
                notesToRestore: [],
                attachmentsToRestore: atts,
                childParentRestorations: [],
                restoreToSection: .notes,
                focusBlockID: latest.id,
                focusNoteID: nil
            ))
        }
    }

    /// Jumps from an Agenda note in the Notes tab straight to that block on the Agenda Day View.
    public func jumpToAgendaBlock(_ block: TimeBlock) {
        selectDate(block.startDate)
        viewMode = .day
        selectedSection = .agenda
        openTab(.block(block.id))
    }

    /// Creates a timed block on today's Agenda seeded from a standalone note (copying title, category, markdown & images).
    public func scheduleStandaloneNoteToday(_ note: StandaloneNote, in store: PlannerStore) {
        let today = Calendar.current.startOfDay(for: Date())
        let nowComps = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let currentMin = (nowComps.hour ?? 9) * 60 + (nowComps.minute ?? 0)
        let startMin = min(TimelineMath.snap(minute: Double(currentMin)), TimelineMath.minutesPerDay - 60)
        let startDate = TimelineMath.date(on: today, minuteOfDay: startMin)
        let endDate = TimelineMath.date(on: today, minuteOfDay: startMin + 60)

        var clonedMarkdown = note.noteMarkdown
        var newBlock = TimeBlock(
            title: note.title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: false,
            noteMarkdown: clonedMarkdown,
            categoryID: note.categoryID
        )

        let noteAttachments = store.attachments(forNoteID: note.id)
        for att in noteAttachments {
            let newID = UUID()
            let copy = BlockAttachment(
                id: newID,
                fileName: att.fileName,
                mimeType: att.mimeType,
                imageData: att.imageData,
                blockID: newBlock.id
            )
            store.upsertAttachment(copy)
            clonedMarkdown = clonedMarkdown.replacingOccurrences(
                of: att.id.uuidString,
                with: newID.uuidString,
                options: .caseInsensitive
            )
        }
        newBlock.updateNoteMarkdown(clonedMarkdown, attachmentCount: noteAttachments.count)
        store.upsertBlock(newBlock)

        selectDate(today)
        viewMode = .day
        selectedSection = .agenda
        openTab(.block(newBlock.id))
    }

    // MARK: - Global Blocks (Second Brain Hubs) & Right-Click Weekly Recurrence

    @discardableResult
    public func createGlobalBlock(title: String = "", in store: PlannerStore) -> StandaloneNote {
        let note = StandaloneNote(
            title: title,
            noteMarkdown: "",
            isPinned: false,
            isGlobal: true,
            categoryID: selectedCategoryFilterID
        )
        store.upsertNote(note)
        selectedSection = .notes
        if notesOriginFilter == .agendaOnly || notesOriginFilter == .standaloneOnly {
            notesOriginFilter = .all
        }
        notesFilterByDay = false
        selectedNoteItemID = "note-\(note.id.uuidString)"
        shouldFocusNoteTitleField = title.isEmpty
        return note
    }

    public func openGlobalNoteInNotes(_ note: StandaloneNote) {
        selectedSection = .notes
        if notesOriginFilter == .agendaOnly || notesOriginFilter == .standaloneOnly {
            notesOriginFilter = .all
        }
        notesFilterByDay = false
        selectedNoteItemID = "note-\(note.id.uuidString)"
        shouldFocusNoteTitleField = false
    }

    public func toggleGlobalFlag(for note: StandaloneNote, in store: PlannerStore) {
        var updated = store.note(for: note.id) ?? note
        updated.isGlobal.toggle()
        updated.updatedAt = Date()
        store.upsertNote(updated)
    }

    /// Promotes an Agenda block into a reusable living Global Block and links the block (and series if recurring) to it.
    @discardableResult
    public func promoteToGlobalBlock(occurrence: DayOccurrence, in store: PlannerStore) -> StandaloneNote {
        if let existingGlobal = occurrence.globalNote {
            return existingGlobal
        }
        var block = ensureConcreteBlock(for: occurrence, in: store)
        var clonedMD = block.noteMarkdown

        var globalNote = StandaloneNote(
            title: block.title.isEmpty ? "Novo Bloco Global" : block.title,
            noteMarkdown: clonedMD,
            isPinned: false,
            isGlobal: true,
            categoryID: block.categoryID
        )

        // Clone block attachments onto the Global Note so images live in the single source of truth
        let blockAtts = store.attachments(forBlockID: block.id)
        for att in blockAtts {
            let newID = UUID()
            let copy = BlockAttachment(
                id: newID,
                fileName: att.fileName,
                mimeType: att.mimeType,
                imageData: att.imageData,
                noteID: globalNote.id
            )
            store.upsertAttachment(copy)
            clonedMD = clonedMD.replacingOccurrences(of: att.id.uuidString, with: newID.uuidString, options: .caseInsensitive)
        }
        globalNote.updateNoteMarkdown(clonedMD, attachmentCount: blockAtts.count)
        store.upsertNote(globalNote)

        block.globalNoteID = globalNote.id
        block.updatedAt = Date()
        store.upsertBlock(block)

        if var series = occurrence.series {
            series.globalNoteID = globalNote.id
            series.updatedAt = Date()
            store.upsertSeries(series)
        }

        openTab(.block(block.id))
        return globalNote
    }

    /// Links an Agenda block (or recurring series) to an existing Global Block so it opens the same living .md document.
    public func linkOccurrence(_ occurrence: DayOccurrence, toGlobalNote globalNote: StandaloneNote, in store: PlannerStore) {
        var block = ensureConcreteBlock(for: occurrence, in: store)
        block.globalNoteID = globalNote.id
        block.title = globalNote.title
        if let catID = globalNote.categoryID {
            block.categoryID = catID
        }
        block.updatedAt = Date()
        store.upsertBlock(block)

        if var series = occurrence.series {
            series.globalNoteID = globalNote.id
            series.title = globalNote.title
            if let catID = globalNote.categoryID {
                series.categoryID = catID
            }
            series.updatedAt = Date()
            store.upsertSeries(series)
        }
        openTab(.block(block.id))
    }

    /// Detaches an Agenda block from its Global Block, copying the current markdown into the local day block.
    public func unlinkFromGlobalBlock(occurrence: DayOccurrence, in store: PlannerStore) {
        var block = ensureConcreteBlock(for: occurrence, in: store)
        if let global = occurrence.globalNote {
            block.title = global.title
            block.updateNoteMarkdown(global.noteMarkdown)
        }
        block.globalNoteID = nil
        block.updatedAt = Date()
        store.upsertBlock(block)

        if var series = occurrence.series {
            series.globalNoteID = nil
            series.updatedAt = Date()
            store.upsertSeries(series)
        }
    }

    /// Schedules a 1-hour session on `day` linked to `globalNote` (used when dragging from Sidebar onto the Timeline).
    @discardableResult
    public func scheduleGlobalBlock(
        _ globalNote: StandaloneNote,
        on day: Date,
        startMinute: Int? = nil,
        in store: PlannerStore
    ) -> TimeBlock {
        let dayStart = Calendar.current.startOfDay(for: day)
        let resolvedStart: Int
        if let startMinute {
            resolvedStart = max(0, min(TimelineMath.minutesPerDay - 60, startMinute))
        } else {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: Date())
            let currentMin = (comps.hour ?? 9) * 60 + (comps.minute ?? 0)
            resolvedStart = min(TimelineMath.snap(minute: Double(currentMin)), TimelineMath.minutesPerDay - 60)
        }
        let startDate = TimelineMath.date(on: dayStart, minuteOfDay: resolvedStart)
        let endDate = TimelineMath.date(on: dayStart, minuteOfDay: resolvedStart + 60)

        let block = TimeBlock(
            title: globalNote.title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: false,
            reminderMinutesBefore: ReminderPreferences.defaultOption.minutesBefore,
            categoryID: globalNote.categoryID,
            globalNoteID: globalNote.id
        )
        store.upsertBlock(block)
        selectedSection = .agenda
        viewMode = .day
        openTab(.block(block.id))
        return block
    }

    /// Opens an existing note matching `[[title]]`, or creates a new `.md` note
    /// (nested as a subnote under `fromParentNoteID` when created from a parent note) and opens it.
    public func openOrCreateWikiLink(
        title: String,
        fromParentTitle parentTitle: String?,
        fromParentNoteID: UUID? = nil,
        in store: PlannerStore
    ) {
        let targetKey = SecondBrainEngine.normalizeKey(title)
        guard !targetKey.isEmpty else { return }

        if let existing = store.notes.first(where: { SecondBrainEngine.normalizeKey($0.title) == targetKey }) {
            openGlobalNoteInNotes(existing)
            return
        }

        let parentNote = fromParentNoteID.flatMap { store.note(for: $0) }
        let intro: String
        if parentNote != nil {
            intro = ""
        } else if let parentTitle, !parentTitle.trimmingCharacters(in: .whitespaces).isEmpty {
            intro = "Conectado a [[\(parentTitle)]]\n\n"
        } else {
            intro = ""
        }
        let created = StandaloneNote(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            noteMarkdown: intro,
            isPinned: false,
            isGlobal: false,
            categoryID: parentNote?.categoryID ?? selectedCategoryFilterID,
            parentNoteID: parentNote?.id
        )
        store.upsertNote(created)
        openGlobalNoteInNotes(created)
    }

    /// Creates a new child subnote nested under `parentNote` (`parentNoteID = parentNote.id`),
    /// optionally appending `- [[childTitle]]` to the parent and optionally navigating into the new subnote.
    @discardableResult
    public func createSubnote(
        title: String,
        parentNote: StandaloneNote,
        appendWikiLinkToParent: Bool = true,
        openCreated: Bool = true,
        in store: PlannerStore
    ) -> StandaloneNote? {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = cleanTitle.isEmpty ? "" : cleanTitle

        let child = StandaloneNote(
            title: finalTitle,
            noteMarkdown: "",
            isPinned: false,
            isGlobal: false,
            categoryID: parentNote.categoryID,
            parentNoteID: parentNote.id
        )
        store.upsertNote(child)

        if appendWikiLinkToParent && !finalTitle.isEmpty {
            var updatedParent = store.note(for: parentNote.id) ?? parentNote
            let linkLine = "- [[\(finalTitle)]]"
            if !updatedParent.noteMarkdown.localizedCaseInsensitiveContains("[[\(finalTitle)]]") {
                let sep = updatedParent.noteMarkdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? ""
                    : (updatedParent.noteMarkdown.hasSuffix("\n") ? "\n" : "\n\n")
                updatedParent.updateNoteMarkdown(
                    updatedParent.noteMarkdown + sep + linkLine,
                    attachmentCount: store.attachments(forNoteID: updatedParent.id).count
                )
                store.upsertNote(updatedParent)
            }
        }

        if openCreated {
            openGlobalNoteInNotes(child)
            if finalTitle.isEmpty {
                shouldFocusNoteTitleField = true
            }
        }
        return child
    }

    /// Reparents an existing note under `newParentID` (or root when `nil`), guarded against cycles.
    public func moveNote(
        _ note: StandaloneNote,
        toParentID newParentID: UUID?,
        in store: PlannerStore
    ) {
        guard SecondBrainEngine.canReparent(noteID: note.id, toParentID: newParentID, in: store.notes) else {
            return
        }
        var updated = store.note(for: note.id) ?? note
        guard updated.parentNoteID != newParentID else { return }
        updated.parentNoteID = newParentID
        updated.updatedAt = Date()
        store.upsertNote(updated)
    }

    /// Creates a new child note connected bidirectionally to a parent Global Block or Note,
    /// nesting it under `parentNote` (`parentNoteID`) and appending `- [[childTitle]]` to the parent.
    public func createConnectedNote(
        title: String,
        parentNote: StandaloneNote,
        in store: PlannerStore
    ) {
        _ = createSubnote(
            title: title,
            parentNote: parentNote,
            appendWikiLinkToParent: true,
            openCreated: true,
            in: store
        )
    }

    /// Applies weekly/daily/custom recurrence from the right-click context menu on any block.
    public func applyRecurrence(
        for occurrence: DayOccurrence,
        ruleType: RecurrenceRuleType?,
        weekdaysMask: WeekdayMask,
        in store: PlannerStore
    ) {
        if let ruleType {
            if var series = occurrence.series {
                series.ruleType = ruleType
                series.weekdaysMask = weekdaysMask
                series.updatedAt = Date()
                store.upsertSeries(series)
            } else {
                let block = ensureConcreteBlock(for: occurrence, in: store)
                _ = RecurrenceEngine.convertToRecurringSeries(
                    block: block,
                    ruleType: ruleType,
                    weekdaysMask: weekdaysMask,
                    in: store
                )
            }
        } else if let series = occurrence.series {
            // Stop repeating: detach today's block as standalone & delete the series
            var keepBlock = ensureConcreteBlock(for: occurrence, in: store)
            keepBlock.seriesID = nil
            keepBlock.occurrenceOriginalDate = nil
            keepBlock.updatedAt = Date()
            store.upsertBlock(keepBlock)
            store.deleteSeries(id: series.id)
            openTab(.block(keepBlock.id))
        }
    }

    // MARK: - Reminders

    public func updateOccurrenceReminder(
        _ minutesBefore: Int?,
        for occurrence: DayOccurrence,
        in store: PlannerStore
    ) {
        if let series = occurrence.series {
            var updatedSeries = store.series(for: series.id) ?? series
            updatedSeries.reminderMinutesBefore = minutesBefore
            updatedSeries.updatedAt = Date()
            store.upsertSeries(updatedSeries)
            for var ov in store.blocks where ov.seriesID == series.id && !ov.isDeletedOverride {
                ov.reminderMinutesBefore = minutesBefore
                ov.updatedAt = Date()
                store.upsertBlock(ov)
            }
        } else {
            var block = ensureConcreteBlock(for: occurrence, in: store)
            block.reminderMinutesBefore = minutesBefore
            block.updatedAt = Date()
            store.upsertBlock(block)
        }
    }

    /// Resolves a notification action target to a concrete occurrence and executes open/snooze/complete.
    public func handleReminderAction(
        _ action: ReminderNotificationAction,
        blockID: UUID?,
        seriesID: UUID?,
        dayStart: Date,
        focusManager: FocusSessionManager,
        in store: PlannerStore
    ) {
        let occ: DayOccurrence?
        if let blockID, let resolved = resolveOccurrence(for: .block(blockID), in: store) {
            occ = resolved
        } else if let seriesID, let resolved = resolveOccurrence(for: .virtualOccurrence(seriesID: seriesID, dayStart: dayStart), in: store) {
            occ = resolved
        } else {
            occ = nil
        }

        guard let occ else { return }

        switch action {
        case .open:
            selectedSection = .agenda
            selectDate(occ.dayStart)
            viewMode = .day
            selectOccurrence(occ)
        case .startFocus:
            selectedSection = .agenda
            selectDate(occ.dayStart)
            viewMode = .day
            selectOccurrence(occ)
            focusManager.start(occurrence: occ, mode: .blockDuration, in: store)
        case .snooze15Minutes:
            var block = ensureConcreteBlock(for: occ, in: store)
            if !block.isAllDay {
                let shift: TimeInterval = 15 * 60
                block.startDate = block.startDate.addingTimeInterval(shift)
                block.endDate = block.endDate.addingTimeInterval(shift)
                block.updatedAt = Date()
                store.upsertBlock(block)
            }
        case .markCompleted:
            if !occ.isCompleted {
                toggleCompletion(for: occ, in: store)
            }
        }
    }

    // MARK: - Inbox Quick-Capture & Scheduling

    @discardableResult
    public func createInboxItem(
        title: String,
        estimatedMinutes: Int = 30,
        categoryID: UUID? = nil,
        globalNoteID: UUID? = nil,
        in store: PlannerStore
    ) -> InboxItem? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let nextOrder = (store.inboxItems.map(\.sortOrder).min() ?? 0) - 1
        let item = InboxItem(
            title: trimmed,
            estimatedMinutes: estimatedMinutes,
            categoryID: categoryID ?? selectedCategoryFilterID,
            globalNoteID: globalNoteID,
            sortOrder: nextOrder
        )
        store.upsertInboxItem(item)
        return item
    }

    public func updateInboxItemDuration(_ item: InboxItem, minutes: Int, in store: PlannerStore) {
        var updated = item
        updated.estimatedMinutes = max(15, minutes)
        updated.updatedAt = Date()
        store.upsertInboxItem(updated)
    }

    public func linkInboxItem(_ item: InboxItem, toGlobalNote global: StandaloneNote?, in store: PlannerStore) {
        var updated = item
        updated.globalNoteID = global?.id
        if let catID = global?.categoryID {
            updated.categoryID = catID
        }
        updated.updatedAt = Date()
        store.upsertInboxItem(updated)
    }

    public func toggleInboxCompletion(_ item: InboxItem, in store: PlannerStore) {
        store.toggleInboxCompletion(id: item.id)
    }

    public func deleteInboxItem(_ item: InboxItem, in store: PlannerStore) {
        store.deleteInboxItem(id: item.id)
    }

    /// Converts an Inbox item into a scheduled `TimeBlock` on `day` and automatically marks the Inbox item completed.
    @discardableResult
    public func scheduleInboxItem(
        _ item: InboxItem,
        on day: Date,
        startMinute: Int? = nil,
        in store: PlannerStore
    ) -> TimeBlock {
        let dayStart = Calendar.current.startOfDay(for: day)
        let duration = max(15, item.estimatedMinutes)
        let resolvedStart: Int
        if let startMinute {
            resolvedStart = max(0, min(TimelineMath.minutesPerDay - duration, startMinute))
        } else {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: Date())
            let currentMin = (comps.hour ?? 9) * 60 + (comps.minute ?? 0)
            resolvedStart = min(TimelineMath.snap(minute: Double(currentMin)), TimelineMath.minutesPerDay - duration)
        }

        let startDate = TimelineMath.date(on: dayStart, minuteOfDay: resolvedStart)
        let endDate = TimelineMath.date(on: dayStart, minuteOfDay: resolvedStart + duration)

        let block = TimeBlock(
            title: item.title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: false,
            reminderMinutesBefore: ReminderPreferences.defaultOption.minutesBefore,
            noteMarkdown: item.noteMarkdown,
            categoryID: item.categoryID,
            globalNoteID: item.globalNoteID
        )
        store.upsertBlock(block)

        // Remove from pending Inbox automatically (soft-completed so sync preserves history)
        var doneItem = item
        doneItem.isCompleted = true
        doneItem.updatedAt = Date()
        store.upsertInboxItem(doneItem)

        selectedSection = .agenda
        viewMode = .day
        openTab(.block(block.id))
        return block
    }
}
