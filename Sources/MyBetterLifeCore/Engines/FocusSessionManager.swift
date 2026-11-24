import Foundation
import Observation

/// Timer strategy for an active Focus Mode session.
public enum FocusTimerMode: Equatable, Hashable, Sendable {
    case blockDuration
    case pomodoro(workMinutes: Int, breakMinutes: Int)

    public var displayName: String {
        switch self {
        case .blockDuration: return "Tempo do bloco"
        case .pomodoro(let work, let brk): return "Pomodoro \(work)/\(brk)"
        }
    }
}

public enum FocusPhase: String, Equatable, Sendable {
    case focus
    case shortBreak

    public var label: String {
        switch self {
        case .focus: return "Foco"
        case .shortBreak: return "Pausa"
        }
    }
}

/// Shared Focus Mode state manager coordinated across the main window, timeline banner,
/// notification quick actions, and the macOS Menu Bar popover.
@Observable
@MainActor
public final class FocusSessionManager {
    public private(set) var isActive: Bool = false
    public private(set) var isPaused: Bool = false
    public private(set) var activeBlockID: UUID? = nil
    public private(set) var activeTitle: String = ""
    public private(set) var activeAccentHex: String = "#64748B"
    public private(set) var mode: FocusTimerMode = .blockDuration
    public private(set) var phase: FocusPhase = .focus
    public private(set) var totalSeconds: Int = 0
    public private(set) var remainingSeconds: Int = 0
    public private(set) var completedPomodoros: Int = 0
    public private(set) var scheduledMenuBarSummary: String? = nil

    /// Fired when a focus countdown reaches zero so the UI/app can chime or notify.
    @ObservationIgnored
    public var onSessionFinished: (@MainActor (_ title: String, _ phase: FocusPhase) -> Void)?

    @ObservationIgnored
    private var tickTask: Task<Void, Never>?
    @ObservationIgnored
    private var menuBarPollTask: Task<Void, Never>?

    public init() {}

    /// Periodically refreshes `scheduledMenuBarSummary` (every 30s) without using `TimelineView`
    /// inside `MenuBarExtra`'s label (which causes an AppKit `NSStatusBarButton` layout loop on macOS).
    public func startMenuBarObserver(store: PlannerStore) {
        refreshScheduledMenuBarSummary(in: store)
        menuBarPollTask?.cancel()
        menuBarPollTask = Task { [weak self, weak store] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled, let self, let store else { break }
                self.refreshScheduledMenuBarSummary(in: store)
            }
        }
    }

    public func refreshScheduledMenuBarSummary(in store: PlannerStore, now: Date = Date()) {
        guard !isActive else {
            if scheduledMenuBarSummary != nil { scheduledMenuBarSummary = nil }
            return
        }
        if let current = currentScheduledOccurrence(in: store, now: now) {
            let remMin = max(1, Int(ceil(current.endDate.timeIntervalSince(now) / 60)))
            let raw = current.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = raw.isEmpty ? "Bloco" : (raw.count > 16 ? String(raw.prefix(15)) + "…" : raw)
            let next = "\(name) · \(remMin)m"
            if scheduledMenuBarSummary != next {
                scheduledMenuBarSummary = next
            }
        } else if scheduledMenuBarSummary != nil {
            scheduledMenuBarSummary = nil
        }
    }

    public var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        let elapsed = max(0, totalSeconds - remainingSeconds)
        return min(1.0, max(0.0, Double(elapsed) / Double(totalSeconds)))
    }

    public var formattedRemaining: String {
        let clamped = max(0, remainingSeconds)
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        let seconds = clamped % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Starts a focus session for a concrete or virtual `DayOccurrence`.
    /// Materializes a virtual recurring occurrence automatically so completion and `+15m` extensions persist.
    public func start(
        occurrence: DayOccurrence,
        mode: FocusTimerMode = .blockDuration,
        in store: PlannerStore,
        now: Date = Date()
    ) {
        let concreteBlock: TimeBlock
        if let existing = occurrence.block {
            concreteBlock = store.block(for: existing.id) ?? existing
        } else if let series = occurrence.series {
            concreteBlock = RecurrenceEngine.materializeOverride(
                for: series,
                on: occurrence.dayStart,
                in: store
            )
        } else {
            return
        }

        self.activeBlockID = concreteBlock.id
        self.activeTitle = occurrence.title.isEmpty ? L10n.untitledBlock : occurrence.title
        self.activeAccentHex = occurrence.category?.colorHex ?? "#64748B"
        self.mode = mode
        self.phase = .focus
        self.isPaused = false
        self.isActive = true

        let durationSec: Int
        switch mode {
        case .blockDuration:
            // If currently inside the block's scheduled window, count down to its endDate;
            // otherwise use the block's full duration.
            if now >= concreteBlock.startDate && now < concreteBlock.endDate {
                durationSec = max(60, Int(concreteBlock.endDate.timeIntervalSince(now)))
            } else {
                durationSec = max(15 * 60, Int(concreteBlock.endDate.timeIntervalSince(concreteBlock.startDate)))
            }
        case .pomodoro(let workMinutes, _):
            durationSec = max(60, workMinutes * 60)
        }

        self.totalSeconds = durationSec
        self.remainingSeconds = durationSec
        restartTicker()
    }

    /// Starts focus directly from a `TimeBlock` ID (e.g., from a Notification quick action).
    public func start(blockID: UUID, mode: FocusTimerMode = .blockDuration, in store: PlannerStore) {
        guard let block = store.block(for: blockID), !block.isDeletedOverride else { return }
        let day = Calendar.current.startOfDay(for: block.startDate)
        let dayItems = RecurrenceEngine.occurrences(
            on: day,
            blocks: store.blocks,
            seriesList: store.seriesList,
            notes: store.notes,
            categories: store.categories,
            attachments: store.attachments
        )
        if let occ = dayItems.first(where: { $0.block?.id == blockID }) {
            start(occurrence: occ, mode: mode, in: store)
        }
    }

    public func togglePause() {
        guard isActive else { return }
        isPaused.toggle()
        if isPaused {
            tickTask?.cancel()
            tickTask = nil
        } else {
            restartTicker()
        }
    }

    /// Extends the active timer AND the underlying `TimeBlock.endDate` by `minutes`.
    public func extend(minutes: Int = 15, in store: PlannerStore) {
        guard isActive else { return }
        let extraSec = minutes * 60
        remainingSeconds += extraSec
        totalSeconds += extraSec

        if let id = activeBlockID, var block = store.block(for: id), !block.isAllDay {
            let maxEnd = Calendar.current.startOfDay(for: block.startDate).addingTimeInterval(24 * 60 * 60)
            block.endDate = min(maxEnd, block.endDate.addingTimeInterval(TimeInterval(extraSec)))
            block.updatedAt = Date()
            store.upsertBlock(block)
        }
    }

    /// Marks the active block as completed and ends the focus session cleanly.
    public func completeActiveBlock(in store: PlannerStore) {
        if let id = activeBlockID, var block = store.block(for: id) {
            block.isCompleted = true
            block.updatedAt = Date()
            store.upsertBlock(block)
        }
        stop()
    }

    public func stop() {
        tickTask?.cancel()
        tickTask = nil
        isActive = false
        isPaused = false
        activeBlockID = nil
        activeTitle = ""
        totalSeconds = 0
        remainingSeconds = 0
        phase = .focus
    }

    /// Returns the timed occurrence currently taking place right now (if any).
    public func currentScheduledOccurrence(in store: PlannerStore, now: Date = Date()) -> DayOccurrence? {
        let today = Calendar.current.startOfDay(for: now)
        let items = RecurrenceEngine.occurrences(
            on: today,
            blocks: store.blocks,
            seriesList: store.seriesList,
            notes: store.notes,
            categories: store.categories,
            attachments: store.attachments
        )
        return items.first { occ in
            !occ.isAllDay && !occ.isCompleted && occ.startDate <= now && occ.endDate > now
        }
    }

    /// Returns upcoming uncompleted timed occurrences for today starting after `now`.
    public func upcomingTodayOccurrences(in store: PlannerStore, now: Date = Date(), limit: Int = 3) -> [DayOccurrence] {
        let today = Calendar.current.startOfDay(for: now)
        let items = RecurrenceEngine.occurrences(
            on: today,
            blocks: store.blocks,
            seriesList: store.seriesList,
            notes: store.notes,
            categories: store.categories,
            attachments: store.attachments
        )
        return Array(
            items
                .filter { !$0.isAllDay && !$0.isCompleted && $0.startDate > now }
                .sorted { $0.startDate < $1.startDate }
                .prefix(limit)
        )
    }

    private func restartTicker() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { break }
                guard self.isActive && !self.isPaused else { continue }
                if self.remainingSeconds > 1 {
                    self.remainingSeconds -= 1
                } else {
                    self.remainingSeconds = 0
                    self.handleCountdownReachedZero()
                    break
                }
            }
        }
    }

    private func handleCountdownReachedZero() {
        let finishedTitle = activeTitle
        let finishedPhase = phase
        onSessionFinished?(finishedTitle, finishedPhase)

        switch mode {
        case .blockDuration:
            isPaused = true
            tickTask?.cancel()
            tickTask = nil
        case .pomodoro(let workMinutes, let breakMinutes):
            if phase == .focus {
                completedPomodoros += 1
                phase = .shortBreak
                totalSeconds = max(60, breakMinutes * 60)
                remainingSeconds = totalSeconds
                restartTicker()
            } else {
                phase = .focus
                totalSeconds = max(60, workMinutes * 60)
                remainingSeconds = totalSeconds
                restartTicker()
            }
        }
    }
}
