import Foundation
import Observation
#if canImport(UserNotifications)
import UserNotifications
#endif
#if os(macOS)
import AppKit
#endif

/// Reminder option presets for time blocks.
public enum ReminderOption: Int, CaseIterable, Identifiable, Sendable {
    case none = -1
    case atTime = 0
    case fiveMinutes = 5
    case tenMinutes = 10
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case oneHour = 60

    public var id: Int { rawValue }

    public var minutesBefore: Int? {
        self == .none ? nil : rawValue
    }

    public var displayName: String {
        switch self {
        case .none: return L10n.reminderNone
        case .atTime: return L10n.reminderAtTime
        case .fiveMinutes: return L10n.reminder5Min
        case .tenMinutes: return L10n.reminder10Min
        case .fifteenMinutes: return L10n.reminder15Min
        case .thirtyMinutes: return L10n.reminder30Min
        case .oneHour: return L10n.reminder1Hour
        }
    }

    public static func from(minutesBefore: Int?) -> ReminderOption {
        guard let minutesBefore else { return .none }
        return ReminderOption(rawValue: minutesBefore) ?? .tenMinutes
    }
}

/// Interactive action chosen by the user on a local reminder notification (native or in-app).
public enum ReminderNotificationAction: Sendable {
    case open
    case startFocus
    case snooze15Minutes
    case markCompleted
}

/// Payload representing an in-app reminder banner (used when running unbundled via `make run`,
/// or when a foreground alert is desired).
public struct InAppReminderAlert: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let blockID: UUID?
    public let seriesID: UUID?
    public let dayStart: Date
    public let startDate: Date

    public init(
        id: String,
        title: String,
        subtitle: String,
        blockID: UUID?,
        seriesID: UUID?,
        dayStart: Date,
        startDate: Date
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.blockID = blockID
        self.seriesID = seriesID
        self.dayStart = dayStart
        self.startDate = startDate
    }
}

/// Persisted user preference for the default reminder applied to newly created timed blocks.
public enum ReminderPreferences {
    private static let defaultKey = "mbl.reminder.defaultOption"

    public static var defaultOption: ReminderOption {
        get {
            if UserDefaults.standard.object(forKey: defaultKey) == nil {
                return .tenMinutes
            }
            let raw = UserDefaults.standard.integer(forKey: defaultKey)
            return ReminderOption(rawValue: raw) ?? .tenMinutes
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultKey)
        }
    }
}

/// Schedules and cancels local notifications via `UserNotifications` with interactive quick actions.
/// Safely becomes a no-op for `UNUserNotificationCenter` when executed outside an `.app` bundle (e.g., `swift run`).
public actor ReminderScheduler {
    public static let shared = ReminderScheduler()

    public static let categoryIdentifier = "MBL_BLOCK_REMINDER"
    public static let actionStartFocus = "MBL_ACTION_START_FOCUS"
    public static let actionSnooze15 = "MBL_ACTION_SNOOZE_15"
    public static let actionMarkDone = "MBL_ACTION_MARK_DONE"
    private static let reminderPrefix = "mbl-rem-"

    private var isBundledApp: Bool {
        Bundle.main.bundleURL.pathExtension == "app" && Bundle.main.bundleIdentifier != nil
    }

    public var supportsNativeSystemNotifications: Bool {
        isBundledApp
    }

    public func registerInteractiveCategory() {
        #if canImport(UserNotifications)
        guard isBundledApp else { return }
        let startFocus = UNNotificationAction(
            identifier: Self.actionStartFocus,
            title: "Iniciar Foco",
            options: [.foreground]
        )
        let snooze = UNNotificationAction(
            identifier: Self.actionSnooze15,
            title: "Adiar 15 min",
            options: []
        )
        let complete = UNNotificationAction(
            identifier: Self.actionMarkDone,
            title: "Concluir",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [startFocus, snooze, complete],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
        #endif
    }

    public func requestAuthorizationIfNeeded() async {
        #if canImport(UserNotifications)
        guard isBundledApp else { return }
        registerInteractiveCategory()
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
        #endif
    }

    public func schedule(
        identifier: String,
        title: String,
        body: String,
        startDate: Date,
        minutesBefore: Int?,
        userInfo: [String: String] = [:]
    ) async {
        #if canImport(UserNotifications)
        guard isBundledApp else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard let minutesBefore else { return }
        let fireDate = startDate.addingTimeInterval(TimeInterval(-minutesBefore * 60))
        guard fireDate > Date() else { return }

        await requestAuthorizationIfNeeded()

        let content = UNMutableNotificationContent()
        content.title = title.isEmpty ? L10n.appName : title
        content.body = body.isEmpty
            ? (minutesBefore == 0 ? "Começando agora" : "Começa em \(minutesBefore) minutos")
            : body
        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier
        content.userInfo = userInfo

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
        #endif
    }

    /// Rebuilds the next 7 days of local notifications (including expanded recurring series occurrences),
    /// capped to 60 upcoming reminders to respect the OS 64-notification budget.
    public func syncUpcomingReminders(
        blocks: [TimeBlock],
        seriesList: [RecurrenceSeries],
        notes: [StandaloneNote],
        categories: [BlockCategory],
        now: Date = Date()
    ) async {
        #if canImport(UserNotifications)
        guard isBundledApp else { return }
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let managedIDs = pending.map(\.identifier).filter { $0.hasPrefix(Self.reminderPrefix) }
        if !managedIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: managedIDs)
        }

        let candidates = Self.upcomingReminderCandidates(
            blocks: blocks,
            seriesList: seriesList,
            notes: notes,
            categories: categories,
            now: now,
            daysAhead: 7,
            limit: 60
        )

        guard !candidates.isEmpty else { return }
        await requestAuthorizationIfNeeded()

        for candidate in candidates {
            let content = UNMutableNotificationContent()
            content.title = candidate.title.isEmpty ? L10n.appName : candidate.title
            content.body = candidate.subtitle
            content.sound = .default
            content.categoryIdentifier = Self.categoryIdentifier
            var info: [String: String] = [
                "dayTimestamp": "\(Int(candidate.dayStart.timeIntervalSince1970))"
            ]
            if let bid = candidate.blockID {
                info["blockID"] = bid.uuidString
            }
            if let sid = candidate.seriesID {
                info["seriesID"] = sid.uuidString
            }
            content.userInfo = info

            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: candidate.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: candidate.identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
        #endif
    }

    public func cancel(identifier: String) {
        #if canImport(UserNotifications)
        guard isBundledApp else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        #endif
    }

    /// Computes upcoming reminder fire candidates across standalone blocks and recurring series.
    public struct ReminderCandidate: Sendable {
        public let identifier: String
        public let title: String
        public let subtitle: String
        public let fireDate: Date
        public let startDate: Date
        public let dayStart: Date
        public let blockID: UUID?
        public let seriesID: UUID?
    }

    public static func upcomingReminderCandidates(
        blocks: [TimeBlock],
        seriesList: [RecurrenceSeries],
        notes: [StandaloneNote],
        categories: [BlockCategory],
        now: Date = Date(),
        daysAhead: Int = 7,
        limit: Int = 60,
        calendar: Calendar = .current
    ) -> [ReminderCandidate] {
        let today = calendar.startOfDay(for: now)
        var candidates: [ReminderCandidate] = []

        for offset in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let occs = RecurrenceEngine.occurrences(
                on: day,
                blocks: blocks,
                seriesList: seriesList,
                notes: notes,
                categories: categories,
                calendar: calendar
            )
            for occ in occs {
                guard !occ.isAllDay, !occ.isCompleted, let minutesBefore = occ.reminderMinutesBefore else {
                    continue
                }
                let fireDate = occ.startDate.addingTimeInterval(TimeInterval(-minutesBefore * 60))
                guard fireDate > now else { continue }
                let timeLabel = TimelineMath.formatTime(occ.startDate)
                let body = minutesBefore == 0
                    ? "Começando agora (\(timeLabel))"
                    : "Começa em \(minutesBefore) min (\(timeLabel))"
                let id = "\(reminderPrefix)\(occ.id)"
                candidates.append(ReminderCandidate(
                    identifier: id,
                    title: occ.title.isEmpty ? L10n.untitledBlock : occ.title,
                    subtitle: body,
                    fireDate: fireDate,
                    startDate: occ.startDate,
                    dayStart: occ.dayStart,
                    blockID: occ.block?.id,
                    seriesID: occ.series?.id
                ))
            }
        }

        return Array(candidates.sorted { $0.fireDate < $1.fireDate }.prefix(limit))
    }
}

/// Bridges `UNUserNotificationCenterDelegate` events back into `@MainActor` app callbacks,
/// AND runs a lightweight in-app reminder monitor when running outside a `.app` bundle (`make run`).
@Observable
@MainActor
public final class ReminderCoordinator: NSObject {
    public var activeInAppAlert: InAppReminderAlert? = nil

    @ObservationIgnored
    public var onAction: (@MainActor (
        _ action: ReminderNotificationAction,
        _ blockID: UUID?,
        _ seriesID: UUID?,
        _ dayStart: Date
    ) -> Void)?

    @ObservationIgnored
    private var monitorTask: Task<Void, Never>?
    @ObservationIgnored
    private var firedKeys: Set<String> = []
    @ObservationIgnored
    private var isDelegateInstalled = false

    public override init() {
        super.init()
    }

    public var isBundledApp: Bool {
        Bundle.main.bundleURL.pathExtension == "app" && Bundle.main.bundleIdentifier != nil
    }

    public func start(store: PlannerStore) {
        #if canImport(UserNotifications)
        if isBundledApp && !isDelegateInstalled {
            isDelegateInstalled = true
            UNUserNotificationCenter.current().delegate = self
            Task {
                await ReminderScheduler.shared.registerInteractiveCategory()
            }
        }
        #endif

        sync(store: store)
        startInAppMonitor(store: store)
    }

    public func sync(store: PlannerStore) {
        let blocks = store.blocks
        let series = store.seriesList
        let notes = store.notes
        let categories = store.categories
        Task {
            await ReminderScheduler.shared.syncUpcomingReminders(
                blocks: blocks,
                seriesList: series,
                notes: notes,
                categories: categories
            )
        }
    }

    public func dismissInAppAlert() {
        activeInAppAlert = nil
    }

    public func triggerAction(_ action: ReminderNotificationAction, for alert: InAppReminderAlert) {
        activeInAppAlert = nil
        onAction?(action, alert.blockID, alert.seriesID, alert.dayStart)
    }

    private func startInAppMonitor(store: PlannerStore) {
        monitorTask?.cancel()
        monitorTask = Task { [weak self, weak store] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                guard !Task.isCancelled, let self, let store else { break }
                // When native notifications are unavailable (e.g. `make run`), deliver an in-app alert banner + chime.
                guard !self.isBundledApp else { continue }
                self.checkDueInAppReminders(in: store, now: Date())
            }
        }
    }

    private func checkDueInAppReminders(in store: PlannerStore, now: Date) {
        let today = Calendar.current.startOfDay(for: now)
        let occs = RecurrenceEngine.occurrences(
            on: today,
            blocks: store.blocks,
            seriesList: store.seriesList,
            notes: store.notes,
            categories: store.categories
        )

        for occ in occs {
            guard !occ.isAllDay, !occ.isCompleted, let minutesBefore = occ.reminderMinutesBefore else { continue }
            let fireDate = occ.startDate.addingTimeInterval(TimeInterval(-minutesBefore * 60))
            let delta = now.timeIntervalSince(fireDate)
            // Trigger if we crossed fireDate within the last 60 seconds and haven't alerted yet
            guard delta >= 0 && delta <= 60 else { continue }
            let key = "\(occ.id)-\(Int(fireDate.timeIntervalSince1970))"
            guard !firedKeys.contains(key) else { continue }
            firedKeys.insert(key)

            let timeLabel = TimelineMath.formatTime(occ.startDate)
            let subtitle = minutesBefore == 0
                ? "Começando agora (\(timeLabel))"
                : "Começa em \(minutesBefore) min (\(timeLabel))"

            activeInAppAlert = InAppReminderAlert(
                id: key,
                title: occ.title.isEmpty ? L10n.untitledBlock : occ.title,
                subtitle: subtitle,
                blockID: occ.block?.id,
                seriesID: occ.series?.id,
                dayStart: occ.dayStart,
                startDate: occ.startDate
            )
            #if os(macOS)
            NSSound.beep()
            #endif
            break
        }
    }
}

#if canImport(UserNotifications)
extension ReminderCoordinator: @preconcurrency UNUserNotificationCenterDelegate {
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let blockID = (userInfo["blockID"] as? String).flatMap(UUID.init(uuidString:))
        let seriesID = (userInfo["seriesID"] as? String).flatMap(UUID.init(uuidString:))
        let dayStart: Date
        if let tsStr = userInfo["dayTimestamp"] as? String, let ts = Double(tsStr) {
            dayStart = Date(timeIntervalSince1970: ts)
        } else {
            dayStart = Calendar.current.startOfDay(for: Date())
        }

        let action: ReminderNotificationAction
        switch response.actionIdentifier {
        case ReminderScheduler.actionStartFocus:
            action = .startFocus
        case ReminderScheduler.actionSnooze15:
            action = .snooze15Minutes
        case ReminderScheduler.actionMarkDone:
            action = .markCompleted
        default:
            action = .open
        }

        onAction?(action, blockID, seriesID, dayStart)
    }
}
#endif
