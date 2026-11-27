import Foundation
import CoreData
import Observation

/// Snapshot of local records (including soft-delete tombstones) ready to push to the Go sync backend.
public struct LocalSyncSnapshot: Sendable {
    public let categories: [BlockCategory]
    public let blocks: [TimeBlock]
    public let series: [RecurrenceSeries]
    public let notes: [StandaloneNote]
    public let attachments: [BlockAttachment]
    public let inboxItems: [InboxItem]
    public let routineItems: [DailyRoutineItem]
    public let routineCompletions: [DailyRoutineCompletion]

    public init(
        categories: [BlockCategory],
        blocks: [TimeBlock],
        series: [RecurrenceSeries],
        notes: [StandaloneNote],
        attachments: [BlockAttachment],
        inboxItems: [InboxItem],
        routineItems: [DailyRoutineItem] = [],
        routineCompletions: [DailyRoutineCompletion] = []
    ) {
        self.categories = categories
        self.blocks = blocks
        self.series = series
        self.notes = notes
        self.attachments = attachments
        self.inboxItems = inboxItems
        self.routineItems = routineItems
        self.routineCompletions = routineCompletions
    }
}

/// Offline-first persistence store backed by Core Data (`NSPersistentContainer`).
/// - Uses a programmatic `NSManagedObjectModel` with automatic lightweight migration.
/// - Soft-deletes records via `deletedAt` tombstones so deletions sync reliably across Mac & iPhone
///   through the Go + PostgreSQL backend (Last-Write-Wins via `updatedAt`).
/// - Also remains CloudKit-schema compatible (`allowsExternalBinaryDataStorage = true` on `imageData`).
@Observable
@MainActor
public final class PlannerStore {
    public private(set) var categories: [BlockCategory] = []
    public private(set) var blocks: [TimeBlock] = []
    public private(set) var seriesList: [RecurrenceSeries] = []
    public private(set) var notes: [StandaloneNote] = []
    public private(set) var attachments: [BlockAttachment] = []
    public private(set) var inboxItems: [InboxItem] = []
    public private(set) var routineItems: [DailyRoutineItem] = []
    public private(set) var routineCompletions: [DailyRoutineCompletion] = []

    /// Fired whenever a local user mutation persists to Core Data (NOT fired on remote sync merges).
    @ObservationIgnored
    public var onLocalMutation: (@MainActor () -> Void)?

    private let container: NSPersistentContainer
    private var context: NSManagedObjectContext { container.viewContext }

    public init(inMemory: Bool = false, enableCloudKit: Bool = false) {
        let model = Self.buildManagedObjectModel()

        if enableCloudKit && !inMemory {
            container = NSPersistentCloudKitContainer(name: "MyBetterLife", managedObjectModel: model)
        } else {
            container = NSPersistentContainer(name: "MyBetterLife", managedObjectModel: model)
        }

        let description: NSPersistentStoreDescription
        if inMemory {
            description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
        } else {
            let storeURL = Self.defaultStoreURL()
            try? FileManager.default.createDirectory(
                at: storeURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            description = NSPersistentStoreDescription(url: storeURL)
            description.type = NSSQLiteStoreType
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
            if enableCloudKit {
                description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            }
        }

        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error {
                assertionFailure("Falha ao carregar Core Data store: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

        reloadAll()
    }

    // MARK: - Queries & Lookups (Active, non-deleted records)

    public func category(for id: UUID?) -> BlockCategory? {
        guard let id else { return nil }
        return categories.first(where: { $0.id == id })
    }

    public func block(for id: UUID) -> TimeBlock? {
        blocks.first(where: { $0.id == id })
    }

    public func series(for id: UUID) -> RecurrenceSeries? {
        seriesList.first(where: { $0.id == id })
    }

    public func note(for id: UUID) -> StandaloneNote? {
        notes.first(where: { $0.id == id })
    }

    public var globalNotes: [StandaloneNote] {
        notes.filter { $0.isGlobal }
    }

    public func inboxItem(for id: UUID) -> InboxItem? {
        inboxItems.first(where: { $0.id == id })
    }

    public var pendingInboxItems: [InboxItem] {
        inboxItems.filter { !$0.isCompleted }
    }

    public func routineItem(for id: UUID) -> DailyRoutineItem? {
        routineItems.first(where: { $0.id == id })
    }

    /// Returns all active routine items applicable to `date`.
    public func routineItems(for date: Date, calendar: Calendar = .current) -> [DailyRoutineItem] {
        routineItems.filter { $0.applies(to: date, calendar: calendar) }
    }

    /// Returns true if the given routine item is marked completed on `date`.
    public func isRoutineCompleted(_ itemID: UUID, on date: Date, calendar: Calendar = .current) -> Bool {
        let key = DailyRoutineCompletion.dayKey(for: date, calendar: calendar)
        return routineCompletions.first(where: { $0.routineItemID == itemID && $0.dayKey == key })?.isCompleted ?? false
    }

    public func attachments(forBlockID blockID: UUID) -> [BlockAttachment] {
        attachments
            .filter { $0.blockID == blockID }
            .sorted { $0.createdAt < $1.createdAt }
    }

    public func attachments(forSeriesID seriesID: UUID) -> [BlockAttachment] {
        attachments
            .filter { $0.seriesID == seriesID }
            .sorted { $0.createdAt < $1.createdAt }
    }

    public func attachments(forNoteID noteID: UUID) -> [BlockAttachment] {
        attachments
            .filter { $0.noteID == noteID }
            .sorted { $0.createdAt < $1.createdAt }
    }

    public func reloadAll() {
        categories = fetchCategories(includeDeleted: false)
        blocks = fetchBlocks(includeDeleted: false)
        seriesList = fetchSeries(includeDeleted: false)
        notes = fetchNotes(includeDeleted: false)
        attachments = fetchAttachments(includeDeleted: false)
        inboxItems = fetchInboxItems(includeDeleted: false)
        routineItems = fetchRoutineItems(includeDeleted: false)
        routineCompletions = fetchRoutineCompletions(includeDeleted: false)
    }

    // MARK: - Sync Snapshot & Remote LWW Merge

    /// Returns all records (including soft-delete tombstones) for pushing to the Go sync backend.
    public func syncSnapshot() -> LocalSyncSnapshot {
        LocalSyncSnapshot(
            categories: fetchCategories(includeDeleted: true),
            blocks: fetchBlocks(includeDeleted: true),
            series: fetchSeries(includeDeleted: true),
            notes: fetchNotes(includeDeleted: true),
            attachments: fetchAttachments(includeDeleted: true),
            inboxItems: fetchInboxItems(includeDeleted: true),
            routineItems: fetchRoutineItems(includeDeleted: true),
            routineCompletions: fetchRoutineCompletions(includeDeleted: true)
        )
    }

    /// Applies remote records pulled from the Go backend using Last-Write-Wins (`remote.updatedAt >= local.updatedAt`).
    /// Does NOT trigger `onLocalMutation` so sync never loops.
    public func applyRemoteSync(
        categories remoteCategories: [BlockCategory],
        blocks remoteBlocks: [TimeBlock],
        series remoteSeries: [RecurrenceSeries] = [],
        notes remoteNotes: [StandaloneNote],
        attachments remoteAttachments: [BlockAttachment],
        inboxItems remoteInboxItems: [InboxItem] = [],
        routineItems remoteRoutineItems: [DailyRoutineItem] = [],
        routineCompletions remoteRoutineCompletions: [DailyRoutineCompletion] = []
    ) {
        let localCats = Dictionary(uniqueKeysWithValues: fetchCategories(includeDeleted: true).map { ($0.id, $0) })
        for cat in remoteCategories {
            if let local = localCats[cat.id], local.updatedAt > cat.updatedAt {
                continue
            }
            writeCategoryObject(cat)
        }

        let localBlocks = Dictionary(uniqueKeysWithValues: fetchBlocks(includeDeleted: true).map { ($0.id, $0) })
        for block in remoteBlocks {
            if let local = localBlocks[block.id], local.updatedAt > block.updatedAt {
                continue
            }
            writeBlockObject(block)
        }

        let localSeries = Dictionary(uniqueKeysWithValues: fetchSeries(includeDeleted: true).map { ($0.id, $0) })
        for series in remoteSeries {
            if let local = localSeries[series.id], local.updatedAt > series.updatedAt {
                continue
            }
            writeSeriesObject(series)
        }

        let localNotes = Dictionary(uniqueKeysWithValues: fetchNotes(includeDeleted: true).map { ($0.id, $0) })
        for note in remoteNotes {
            if let local = localNotes[note.id], local.updatedAt > note.updatedAt {
                continue
            }
            writeNoteObject(note)
        }

        let localAtts = Dictionary(uniqueKeysWithValues: fetchAttachments(includeDeleted: true).map { ($0.id, $0) })
        for att in remoteAttachments {
            if let local = localAtts[att.id], local.updatedAt > att.updatedAt {
                continue
            }
            var merged = att
            // Preserve locally cached binary bytes if the remote metadata didn't include raw data yet
            if merged.imageData.isEmpty, let existingBytes = localAtts[att.id]?.imageData, !existingBytes.isEmpty {
                merged.imageData = existingBytes
            }
            writeAttachmentObject(merged)
        }

        let localInbox = Dictionary(uniqueKeysWithValues: fetchInboxItems(includeDeleted: true).map { ($0.id, $0) })
        for item in remoteInboxItems {
            if let local = localInbox[item.id], local.updatedAt > item.updatedAt {
                continue
            }
            writeInboxItemObject(item)
        }

        let localRoutines = Dictionary(uniqueKeysWithValues: fetchRoutineItems(includeDeleted: true).map { ($0.id, $0) })
        for item in remoteRoutineItems {
            if let local = localRoutines[item.id], local.updatedAt > item.updatedAt {
                continue
            }
            writeRoutineItemObject(item)
        }

        let localCompletions = Dictionary(uniqueKeysWithValues: fetchRoutineCompletions(includeDeleted: true).map { ($0.id, $0) })
        for completion in remoteRoutineCompletions {
            if let local = localCompletions[completion.id], local.updatedAt > completion.updatedAt {
                continue
            }
            writeRoutineCompletionObject(completion)
        }

        saveAndReload(notifyLocalMutation: false)
    }

    /// Stores downloaded binary bytes for an attachment without bumping `updatedAt` or re-pushing.
    public func cacheAttachmentImageData(_ data: Data, forAttachmentID id: UUID) {
        guard let obj = fetchObject(entityName: "CDAttachment", id: id) else { return }
        obj.setValue(data, forKey: "imageData")
        saveAndReload(notifyLocalMutation: false)
    }

    // MARK: - Category CRUD

    public func upsertCategory(_ category: BlockCategory) {
        var updated = category
        updated.updatedAt = Date()
        updated.deletedAt = nil
        writeCategoryObject(updated)
        saveAndReload(notifyLocalMutation: true)
    }

    public func deleteCategory(id: UUID) {
        let now = Date()
        if let obj = fetchObject(entityName: "CDCategory", id: id) {
            obj.setValue(now, forKey: "deletedAt")
            obj.setValue(now, forKey: "updatedAt")
        }
        for var block in blocks where block.categoryID == id {
            block.categoryID = nil
            block.updatedAt = now
            writeBlockObject(block)
        }
        for var series in seriesList where series.categoryID == id {
            series.categoryID = nil
            series.updatedAt = now
            writeSeriesObject(series)
        }
        for var note in notes where note.categoryID == id {
            note.categoryID = nil
            note.updatedAt = now
            writeNoteObject(note)
        }
        for var item in inboxItems where item.categoryID == id {
            item.categoryID = nil
            item.updatedAt = now
            writeInboxItemObject(item)
        }
        for var routine in routineItems where routine.categoryID == id {
            routine.categoryID = nil
            routine.updatedAt = now
            writeRoutineItemObject(routine)
        }
        saveAndReload(notifyLocalMutation: true)
    }

    // MARK: - TimeBlock CRUD

    public func upsertBlock(_ block: TimeBlock) {
        var updated = block
        updated.deletedAt = nil
        writeBlockObject(updated)
        saveAndReload(notifyLocalMutation: true)
    }

    public func deleteBlock(id: UUID) {
        let now = Date()
        if let obj = fetchObject(entityName: "CDTimeBlock", id: id) {
            obj.setValue(now, forKey: "deletedAt")
            obj.setValue(now, forKey: "updatedAt")
        }
        for att in attachments where att.blockID == id {
            if let attObj = fetchObject(entityName: "CDAttachment", id: att.id) {
                attObj.setValue(now, forKey: "deletedAt")
                attObj.setValue(now, forKey: "updatedAt")
            }
        }
        saveAndReload(notifyLocalMutation: true)
    }

    // MARK: - RecurrenceSeries CRUD

    public func upsertSeries(_ series: RecurrenceSeries) {
        var updated = series
        updated.deletedAt = nil
        writeSeriesObject(updated)
        saveAndReload(notifyLocalMutation: true)
    }

    public func deleteSeries(id: UUID) {
        let now = Date()
        if let obj = fetchObject(entityName: "CDRecurrenceSeries", id: id) {
            obj.setValue(now, forKey: "deletedAt")
            obj.setValue(now, forKey: "updatedAt")
        }
        for block in blocks where block.seriesID == id {
            if let bObj = fetchObject(entityName: "CDTimeBlock", id: block.id) {
                bObj.setValue(now, forKey: "deletedAt")
                bObj.setValue(now, forKey: "updatedAt")
            }
            for att in attachments where att.blockID == block.id {
                if let aObj = fetchObject(entityName: "CDAttachment", id: att.id) {
                    aObj.setValue(now, forKey: "deletedAt")
                    aObj.setValue(now, forKey: "updatedAt")
                }
            }
        }
        for att in attachments where att.seriesID == id {
            if let aObj = fetchObject(entityName: "CDAttachment", id: att.id) {
                aObj.setValue(now, forKey: "deletedAt")
                aObj.setValue(now, forKey: "updatedAt")
            }
        }
        saveAndReload(notifyLocalMutation: true)
    }

    // MARK: - StandaloneNote CRUD

    public func upsertNote(_ note: StandaloneNote) {
        var updated = note
        updated.deletedAt = nil
        writeNoteObject(updated)
        saveAndReload(notifyLocalMutation: true)
    }

    public func deleteNote(id: UUID) {
        let now = Date()
        let grandParentID = note(for: id)?.parentNoteID
        // Promote direct child notes one level up so subnotes are NEVER lost when deleting a parent note
        for var child in notes where child.parentNoteID == id {
            child.parentNoteID = grandParentID
            child.updatedAt = now
            writeNoteObject(child)
        }
        if let obj = fetchObject(entityName: "CDStandaloneNote", id: id) {
            obj.setValue(now, forKey: "deletedAt")
            obj.setValue(now, forKey: "updatedAt")
        }
        for att in attachments where att.noteID == id {
            if let aObj = fetchObject(entityName: "CDAttachment", id: att.id) {
                aObj.setValue(now, forKey: "deletedAt")
                aObj.setValue(now, forKey: "updatedAt")
            }
        }
        saveAndReload(notifyLocalMutation: true)
    }

    // MARK: - Attachment CRUD

    public func upsertAttachment(_ attachment: BlockAttachment) {
        var updated = attachment
        updated.updatedAt = Date()
        updated.deletedAt = nil
        writeAttachmentObject(updated)
        saveAndReload(notifyLocalMutation: true)
    }

    public func deleteAttachment(id: UUID) {
        let now = Date()
        if let obj = fetchObject(entityName: "CDAttachment", id: id) {
            obj.setValue(now, forKey: "deletedAt")
            obj.setValue(now, forKey: "updatedAt")
        }
        saveAndReload(notifyLocalMutation: true)
    }

    // MARK: - Inbox CRUD

    public func upsertInboxItem(_ item: InboxItem) {
        var updated = item
        updated.deletedAt = nil
        writeInboxItemObject(updated)
        saveAndReload(notifyLocalMutation: true)
    }

    public func deleteInboxItem(id: UUID) {
        let now = Date()
        if let obj = fetchObject(entityName: "CDInboxItem", id: id) {
            obj.setValue(now, forKey: "deletedAt")
            obj.setValue(now, forKey: "updatedAt")
        }
        saveAndReload(notifyLocalMutation: true)
    }

    public func toggleInboxCompletion(id: UUID) {
        guard var item = inboxItem(for: id) else { return }
        item.isCompleted.toggle()
        item.updatedAt = Date()
        writeInboxItemObject(item)
        saveAndReload(notifyLocalMutation: true)
    }

    // MARK: - Daily Routine CRUD

    public func upsertRoutineItem(_ item: DailyRoutineItem) {
        var updated = item
        updated.deletedAt = nil
        writeRoutineItemObject(updated)
        saveAndReload(notifyLocalMutation: true)
    }

    public func deleteRoutineItem(id: UUID) {
        let now = Date()
        if let obj = fetchObject(entityName: "CDDailyRoutineItem", id: id) {
            obj.setValue(now, forKey: "deletedAt")
            obj.setValue(now, forKey: "updatedAt")
        }
        saveAndReload(notifyLocalMutation: true)
    }

    /// Sets the completion state for a routine item on a specific local calendar day.
    public func setRoutineCompletion(
        itemID: UUID,
        on date: Date,
        isCompleted: Bool,
        calendar: Calendar = .current
    ) {
        let key = DailyRoutineCompletion.dayKey(for: date, calendar: calendar)
        let now = Date()
        if var existing = routineCompletions.first(where: { $0.routineItemID == itemID && $0.dayKey == key }) {
            guard existing.isCompleted != isCompleted else { return }
            existing.isCompleted = isCompleted
            existing.completedAt = isCompleted ? now : nil
            existing.updatedAt = now
            existing.deletedAt = nil
            writeRoutineCompletionObject(existing)
        } else {
            let record = DailyRoutineCompletion(
                routineItemID: itemID,
                dayKey: key,
                isCompleted: isCompleted,
                completedAt: isCompleted ? now : nil,
                updatedAt: now
            )
            writeRoutineCompletionObject(record)
        }
        saveAndReload(notifyLocalMutation: true)
    }

    /// Toggles the completion state for a routine item on `date` and returns the new completion value.
    @discardableResult
    public func toggleRoutineCompletion(
        itemID: UUID,
        on date: Date,
        calendar: Calendar = .current
    ) -> Bool {
        let next = !isRoutineCompleted(itemID, on: date, calendar: calendar)
        setRoutineCompletion(itemID: itemID, on: date, isCompleted: next, calendar: calendar)
        return next
    }

    // MARK: - Internal Core Data Writers

    private func writeCategoryObject(_ category: BlockCategory) {
        let obj = fetchObject(entityName: "CDCategory", id: category.id)
            ?? NSEntityDescription.insertNewObject(forEntityName: "CDCategory", into: context)
        obj.setValue(category.id, forKey: "id")
        obj.setValue(category.name, forKey: "name")
        obj.setValue(category.colorHex, forKey: "colorHex")
        obj.setValue(category.symbolName, forKey: "symbolName")
        obj.setValue(Int64(category.sortOrder), forKey: "sortOrder")
        obj.setValue(category.createdAt, forKey: "createdAt")
        obj.setValue(category.updatedAt, forKey: "updatedAt")
        obj.setValue(category.deletedAt, forKey: "deletedAt")
    }

    private func writeBlockObject(_ block: TimeBlock) {
        let obj = fetchObject(entityName: "CDTimeBlock", id: block.id)
            ?? NSEntityDescription.insertNewObject(forEntityName: "CDTimeBlock", into: context)
        obj.setValue(block.id, forKey: "id")
        obj.setValue(block.title, forKey: "title")
        obj.setValue(block.startDate, forKey: "startDate")
        obj.setValue(block.endDate, forKey: "endDate")
        obj.setValue(block.isAllDay, forKey: "isAllDay")
        obj.setValue(block.isCompleted, forKey: "isCompleted")
        obj.setValue(block.reminderMinutesBefore.map(NSNumber.init(value:)), forKey: "reminderMinutesBefore")
        obj.setValue(block.noteMarkdown, forKey: "noteMarkdown")
        obj.setValue(block.plainTextIndex, forKey: "plainTextIndex")
        obj.setValue(block.categoryID, forKey: "categoryID")
        obj.setValue(block.seriesID, forKey: "seriesID")
        obj.setValue(block.globalNoteID, forKey: "globalNoteID")
        obj.setValue(block.routineItemID, forKey: "routineItemID")
        obj.setValue(block.occurrenceOriginalDate, forKey: "occurrenceOriginalDate")
        obj.setValue(block.isDeletedOverride, forKey: "isDeletedOverride")
        obj.setValue(block.createdAt, forKey: "createdAt")
        obj.setValue(block.updatedAt, forKey: "updatedAt")
        obj.setValue(block.deletedAt, forKey: "deletedAt")
    }

    private func writeSeriesObject(_ series: RecurrenceSeries) {
        let obj = fetchObject(entityName: "CDRecurrenceSeries", id: series.id)
            ?? NSEntityDescription.insertNewObject(forEntityName: "CDRecurrenceSeries", into: context)
        obj.setValue(series.id, forKey: "id")
        obj.setValue(series.title, forKey: "title")
        obj.setValue(series.ruleType.rawValue, forKey: "ruleTypeRaw")
        obj.setValue(Int64(series.weekdaysMask.rawValue), forKey: "weekdaysMaskRaw")
        obj.setValue(Int64(series.startMinuteOfDay), forKey: "startMinuteOfDay")
        obj.setValue(Int64(series.durationMinutes), forKey: "durationMinutes")
        obj.setValue(series.isAllDay, forKey: "isAllDay")
        obj.setValue(series.reminderMinutesBefore.map(NSNumber.init(value:)), forKey: "reminderMinutesBefore")
        obj.setValue(series.templateMarkdown, forKey: "templateMarkdown")
        obj.setValue(series.templatePlainText, forKey: "templatePlainText")
        obj.setValue(series.seriesStartDate, forKey: "seriesStartDate")
        obj.setValue(series.seriesEndDate, forKey: "seriesEndDate")
        obj.setValue(series.categoryID, forKey: "categoryID")
        obj.setValue(series.globalNoteID, forKey: "globalNoteID")
        obj.setValue(series.createdAt, forKey: "createdAt")
        obj.setValue(series.updatedAt, forKey: "updatedAt")
        obj.setValue(series.deletedAt, forKey: "deletedAt")
    }

    private func writeNoteObject(_ note: StandaloneNote) {
        let obj = fetchObject(entityName: "CDStandaloneNote", id: note.id)
            ?? NSEntityDescription.insertNewObject(forEntityName: "CDStandaloneNote", into: context)
        obj.setValue(note.id, forKey: "id")
        obj.setValue(note.title, forKey: "title")
        obj.setValue(note.noteMarkdown, forKey: "noteMarkdown")
        obj.setValue(note.plainTextIndex, forKey: "plainTextIndex")
        obj.setValue(note.isPinned, forKey: "isPinned")
        obj.setValue(note.isGlobal, forKey: "isGlobal")
        obj.setValue(note.categoryID, forKey: "categoryID")
        obj.setValue(note.parentNoteID, forKey: "parentNoteID")
        obj.setValue(note.createdAt, forKey: "createdAt")
        obj.setValue(note.updatedAt, forKey: "updatedAt")
        obj.setValue(note.deletedAt, forKey: "deletedAt")
    }

    private func writeAttachmentObject(_ attachment: BlockAttachment) {
        let obj = fetchObject(entityName: "CDAttachment", id: attachment.id)
            ?? NSEntityDescription.insertNewObject(forEntityName: "CDAttachment", into: context)
        obj.setValue(attachment.id, forKey: "id")
        obj.setValue(attachment.fileName, forKey: "fileName")
        obj.setValue(attachment.mimeType, forKey: "mimeType")
        obj.setValue(attachment.imageData, forKey: "imageData")
        obj.setValue(attachment.blockID, forKey: "blockID")
        obj.setValue(attachment.seriesID, forKey: "seriesID")
        obj.setValue(attachment.noteID, forKey: "noteID")
        obj.setValue(attachment.createdAt, forKey: "createdAt")
        obj.setValue(attachment.updatedAt, forKey: "updatedAt")
        obj.setValue(attachment.deletedAt, forKey: "deletedAt")
    }

    private func writeInboxItemObject(_ item: InboxItem) {
        let obj = fetchObject(entityName: "CDInboxItem", id: item.id)
            ?? NSEntityDescription.insertNewObject(forEntityName: "CDInboxItem", into: context)
        obj.setValue(item.id, forKey: "id")
        obj.setValue(item.title, forKey: "title")
        obj.setValue(item.noteMarkdown, forKey: "noteMarkdown")
        obj.setValue(Int64(item.estimatedMinutes), forKey: "estimatedMinutes")
        obj.setValue(item.isCompleted, forKey: "isCompleted")
        obj.setValue(item.categoryID, forKey: "categoryID")
        obj.setValue(item.globalNoteID, forKey: "globalNoteID")
        obj.setValue(Int64(item.sortOrder), forKey: "sortOrder")
        obj.setValue(item.createdAt, forKey: "createdAt")
        obj.setValue(item.updatedAt, forKey: "updatedAt")
        obj.setValue(item.deletedAt, forKey: "deletedAt")
    }

    private func writeRoutineItemObject(_ item: DailyRoutineItem) {
        let obj = fetchObject(entityName: "CDDailyRoutineItem", id: item.id)
            ?? NSEntityDescription.insertNewObject(forEntityName: "CDDailyRoutineItem", into: context)
        obj.setValue(item.id, forKey: "id")
        obj.setValue(item.title, forKey: "title")
        obj.setValue(Int64(item.estimatedMinutes), forKey: "estimatedMinutes")
        obj.setValue(Int64(item.weekdaysMask.rawValue), forKey: "weekdaysMaskRaw")
        obj.setValue(item.categoryID, forKey: "categoryID")
        obj.setValue(Int64(item.sortOrder), forKey: "sortOrder")
        obj.setValue(item.createdAt, forKey: "createdAt")
        obj.setValue(item.updatedAt, forKey: "updatedAt")
        obj.setValue(item.deletedAt, forKey: "deletedAt")
    }

    private func writeRoutineCompletionObject(_ completion: DailyRoutineCompletion) {
        let obj = fetchObject(entityName: "CDDailyRoutineCompletion", id: completion.id)
            ?? NSEntityDescription.insertNewObject(forEntityName: "CDDailyRoutineCompletion", into: context)
        obj.setValue(completion.id, forKey: "id")
        obj.setValue(completion.routineItemID, forKey: "routineItemID")
        obj.setValue(completion.dayKey, forKey: "dayKey")
        obj.setValue(completion.isCompleted, forKey: "isCompleted")
        obj.setValue(completion.completedAt, forKey: "completedAt")
        obj.setValue(completion.updatedAt, forKey: "updatedAt")
        obj.setValue(completion.deletedAt, forKey: "deletedAt")
    }

    private func saveAndReload(notifyLocalMutation: Bool) {
        if context.hasChanges {
            try? context.save()
        }
        reloadAll()
        if notifyLocalMutation {
            onLocalMutation?()
        }
    }

    private func fetchObject(entityName: String, id: UUID) -> NSManagedObject? {
        let req = NSFetchRequest<NSManagedObject>(entityName: entityName)
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        req.fetchLimit = 1
        return (try? context.fetch(req))?.first
    }

    private func fetchCategories(includeDeleted: Bool) -> [BlockCategory] {
        let req = NSFetchRequest<NSManagedObject>(entityName: "CDCategory")
        req.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
        if !includeDeleted {
            req.predicate = NSPredicate(format: "deletedAt == nil")
        }
        let objs = (try? context.fetch(req)) ?? []
        return objs.compactMap { obj in
            guard let id = obj.value(forKey: "id") as? UUID else { return nil }
            let createdAt = (obj.value(forKey: "createdAt") as? Date) ?? Date()
            return BlockCategory(
                id: id,
                name: (obj.value(forKey: "name") as? String) ?? "",
                colorHex: (obj.value(forKey: "colorHex") as? String) ?? "#3B82F6",
                symbolName: (obj.value(forKey: "symbolName") as? String) ?? "circle.fill",
                sortOrder: Int((obj.value(forKey: "sortOrder") as? Int64) ?? 0),
                createdAt: createdAt,
                updatedAt: (obj.value(forKey: "updatedAt") as? Date) ?? createdAt,
                deletedAt: obj.value(forKey: "deletedAt") as? Date
            )
        }
    }

    private func fetchBlocks(includeDeleted: Bool) -> [TimeBlock] {
        let req = NSFetchRequest<NSManagedObject>(entityName: "CDTimeBlock")
        req.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]
        if !includeDeleted {
            req.predicate = NSPredicate(format: "deletedAt == nil")
        }
        let objs = (try? context.fetch(req)) ?? []
        return objs.compactMap { obj in
            guard let id = obj.value(forKey: "id") as? UUID else { return nil }
            let start = (obj.value(forKey: "startDate") as? Date) ?? Date()
            let end = (obj.value(forKey: "endDate") as? Date) ?? start.addingTimeInterval(3600)
            let reminderNum = obj.value(forKey: "reminderMinutesBefore") as? NSNumber
            return TimeBlock(
                id: id,
                title: (obj.value(forKey: "title") as? String) ?? "",
                startDate: start,
                endDate: end,
                isAllDay: (obj.value(forKey: "isAllDay") as? Bool) ?? false,
                isCompleted: (obj.value(forKey: "isCompleted") as? Bool) ?? false,
                reminderMinutesBefore: reminderNum?.intValue,
                noteMarkdown: (obj.value(forKey: "noteMarkdown") as? String) ?? "",
                categoryID: obj.value(forKey: "categoryID") as? UUID,
                seriesID: obj.value(forKey: "seriesID") as? UUID,
                globalNoteID: obj.value(forKey: "globalNoteID") as? UUID,
                routineItemID: obj.value(forKey: "routineItemID") as? UUID,
                occurrenceOriginalDate: obj.value(forKey: "occurrenceOriginalDate") as? Date,
                isDeletedOverride: (obj.value(forKey: "isDeletedOverride") as? Bool) ?? false,
                createdAt: (obj.value(forKey: "createdAt") as? Date) ?? Date(),
                updatedAt: (obj.value(forKey: "updatedAt") as? Date) ?? Date(),
                deletedAt: obj.value(forKey: "deletedAt") as? Date
            )
        }
    }

    private func fetchSeries(includeDeleted: Bool) -> [RecurrenceSeries] {
        let req = NSFetchRequest<NSManagedObject>(entityName: "CDRecurrenceSeries")
        req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        if !includeDeleted {
            req.predicate = NSPredicate(format: "deletedAt == nil")
        }
        let objs = (try? context.fetch(req)) ?? []
        return objs.compactMap { obj in
            guard let id = obj.value(forKey: "id") as? UUID else { return nil }
            let ruleRaw = (obj.value(forKey: "ruleTypeRaw") as? String) ?? RecurrenceRuleType.daily.rawValue
            let maskRaw = Int((obj.value(forKey: "weekdaysMaskRaw") as? Int64) ?? Int64(WeekdayMask.weekdays.rawValue))
            let reminderNum = obj.value(forKey: "reminderMinutesBefore") as? NSNumber
            return RecurrenceSeries(
                id: id,
                title: (obj.value(forKey: "title") as? String) ?? "",
                ruleType: RecurrenceRuleType(rawValue: ruleRaw) ?? .daily,
                weekdaysMask: WeekdayMask(rawValue: maskRaw),
                startMinuteOfDay: Int((obj.value(forKey: "startMinuteOfDay") as? Int64) ?? 540),
                durationMinutes: Int((obj.value(forKey: "durationMinutes") as? Int64) ?? 60),
                isAllDay: (obj.value(forKey: "isAllDay") as? Bool) ?? false,
                reminderMinutesBefore: reminderNum?.intValue,
                templateMarkdown: (obj.value(forKey: "templateMarkdown") as? String) ?? "",
                seriesStartDate: (obj.value(forKey: "seriesStartDate") as? Date) ?? Date(),
                seriesEndDate: obj.value(forKey: "seriesEndDate") as? Date,
                categoryID: obj.value(forKey: "categoryID") as? UUID,
                globalNoteID: obj.value(forKey: "globalNoteID") as? UUID,
                createdAt: (obj.value(forKey: "createdAt") as? Date) ?? Date(),
                updatedAt: (obj.value(forKey: "updatedAt") as? Date) ?? Date(),
                deletedAt: obj.value(forKey: "deletedAt") as? Date
            )
        }
    }

    private func fetchNotes(includeDeleted: Bool) -> [StandaloneNote] {
        let req = NSFetchRequest<NSManagedObject>(entityName: "CDStandaloneNote")
        req.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        if !includeDeleted {
            req.predicate = NSPredicate(format: "deletedAt == nil")
        }
        let objs = (try? context.fetch(req)) ?? []
        return objs.compactMap { obj in
            guard let id = obj.value(forKey: "id") as? UUID else { return nil }
            return StandaloneNote(
                id: id,
                title: (obj.value(forKey: "title") as? String) ?? "",
                noteMarkdown: (obj.value(forKey: "noteMarkdown") as? String) ?? "",
                isPinned: (obj.value(forKey: "isPinned") as? Bool) ?? false,
                isGlobal: (obj.value(forKey: "isGlobal") as? Bool) ?? false,
                categoryID: obj.value(forKey: "categoryID") as? UUID,
                parentNoteID: obj.value(forKey: "parentNoteID") as? UUID,
                createdAt: (obj.value(forKey: "createdAt") as? Date) ?? Date(),
                updatedAt: (obj.value(forKey: "updatedAt") as? Date) ?? Date(),
                deletedAt: obj.value(forKey: "deletedAt") as? Date
            )
        }
    }

    private func fetchAttachments(includeDeleted: Bool) -> [BlockAttachment] {
        let req = NSFetchRequest<NSManagedObject>(entityName: "CDAttachment")
        req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        if !includeDeleted {
            req.predicate = NSPredicate(format: "deletedAt == nil")
        }
        let objs = (try? context.fetch(req)) ?? []
        return objs.compactMap { obj in
            guard let id = obj.value(forKey: "id") as? UUID else { return nil }
            let createdAt = (obj.value(forKey: "createdAt") as? Date) ?? Date()
            return BlockAttachment(
                id: id,
                fileName: (obj.value(forKey: "fileName") as? String) ?? "imagem.png",
                mimeType: (obj.value(forKey: "mimeType") as? String) ?? "image/png",
                imageData: (obj.value(forKey: "imageData") as? Data) ?? Data(),
                blockID: obj.value(forKey: "blockID") as? UUID,
                seriesID: obj.value(forKey: "seriesID") as? UUID,
                noteID: obj.value(forKey: "noteID") as? UUID,
                createdAt: createdAt,
                updatedAt: (obj.value(forKey: "updatedAt") as? Date) ?? createdAt,
                deletedAt: obj.value(forKey: "deletedAt") as? Date
            )
        }
    }

    private func fetchInboxItems(includeDeleted: Bool) -> [InboxItem] {
        let req = NSFetchRequest<NSManagedObject>(entityName: "CDInboxItem")
        req.sortDescriptors = [
            NSSortDescriptor(key: "isCompleted", ascending: true),
            NSSortDescriptor(key: "sortOrder", ascending: true),
            NSSortDescriptor(key: "createdAt", ascending: false)
        ]
        if !includeDeleted {
            req.predicate = NSPredicate(format: "deletedAt == nil")
        }
        let objs = (try? context.fetch(req)) ?? []
        return objs.compactMap { obj in
            guard let id = obj.value(forKey: "id") as? UUID else { return nil }
            let createdAt = (obj.value(forKey: "createdAt") as? Date) ?? Date()
            return InboxItem(
                id: id,
                title: (obj.value(forKey: "title") as? String) ?? "",
                noteMarkdown: (obj.value(forKey: "noteMarkdown") as? String) ?? "",
                estimatedMinutes: Int((obj.value(forKey: "estimatedMinutes") as? Int64) ?? 30),
                isCompleted: (obj.value(forKey: "isCompleted") as? Bool) ?? false,
                categoryID: obj.value(forKey: "categoryID") as? UUID,
                globalNoteID: obj.value(forKey: "globalNoteID") as? UUID,
                sortOrder: Int((obj.value(forKey: "sortOrder") as? Int64) ?? 0),
                createdAt: createdAt,
                updatedAt: (obj.value(forKey: "updatedAt") as? Date) ?? createdAt,
                deletedAt: obj.value(forKey: "deletedAt") as? Date
            )
        }
    }

    private func fetchRoutineItems(includeDeleted: Bool) -> [DailyRoutineItem] {
        let req = NSFetchRequest<NSManagedObject>(entityName: "CDDailyRoutineItem")
        req.sortDescriptors = [
            NSSortDescriptor(key: "sortOrder", ascending: true),
            NSSortDescriptor(key: "createdAt", ascending: true)
        ]
        if !includeDeleted {
            req.predicate = NSPredicate(format: "deletedAt == nil")
        }
        let objs = (try? context.fetch(req)) ?? []
        return objs.compactMap { obj in
            guard let id = obj.value(forKey: "id") as? UUID else { return nil }
            let createdAt = (obj.value(forKey: "createdAt") as? Date) ?? Date()
            let maskRaw = Int((obj.value(forKey: "weekdaysMaskRaw") as? Int64) ?? Int64(WeekdayMask.all.rawValue))
            return DailyRoutineItem(
                id: id,
                title: (obj.value(forKey: "title") as? String) ?? "",
                estimatedMinutes: Int((obj.value(forKey: "estimatedMinutes") as? Int64) ?? 30),
                weekdaysMask: WeekdayMask(rawValue: maskRaw),
                categoryID: obj.value(forKey: "categoryID") as? UUID,
                sortOrder: Int((obj.value(forKey: "sortOrder") as? Int64) ?? 0),
                createdAt: createdAt,
                updatedAt: (obj.value(forKey: "updatedAt") as? Date) ?? createdAt,
                deletedAt: obj.value(forKey: "deletedAt") as? Date
            )
        }
    }

    private func fetchRoutineCompletions(includeDeleted: Bool) -> [DailyRoutineCompletion] {
        let req = NSFetchRequest<NSManagedObject>(entityName: "CDDailyRoutineCompletion")
        req.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        if !includeDeleted {
            req.predicate = NSPredicate(format: "deletedAt == nil")
        }
        let objs = (try? context.fetch(req)) ?? []
        return objs.compactMap { obj in
            guard let id = obj.value(forKey: "id") as? UUID,
                  let routineItemID = obj.value(forKey: "routineItemID") as? UUID,
                  let dayKey = obj.value(forKey: "dayKey") as? String else { return nil }
            let updatedAt = (obj.value(forKey: "updatedAt") as? Date) ?? Date()
            return DailyRoutineCompletion(
                id: id,
                routineItemID: routineItemID,
                dayKey: dayKey,
                isCompleted: (obj.value(forKey: "isCompleted") as? Bool) ?? false,
                completedAt: obj.value(forKey: "completedAt") as? Date,
                updatedAt: updatedAt,
                deletedAt: obj.value(forKey: "deletedAt") as? Date
            )
        }
    }

    // MARK: - Programmatic CloudKit & Sync-Compatible NSManagedObjectModel

    private static func buildManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let cat = NSEntityDescription()
        cat.name = "CDCategory"
        cat.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        cat.properties = [
            attr("id", .UUIDAttributeType),
            attr("name", .stringAttributeType, defaultValue: ""),
            attr("colorHex", .stringAttributeType, defaultValue: "#3B82F6"),
            attr("symbolName", .stringAttributeType, defaultValue: "circle.fill"),
            attr("sortOrder", .integer64AttributeType, defaultValue: 0),
            attr("createdAt", .dateAttributeType),
            attr("updatedAt", .dateAttributeType),
            attr("deletedAt", .dateAttributeType)
        ]

        let block = NSEntityDescription()
        block.name = "CDTimeBlock"
        block.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        block.properties = [
            attr("id", .UUIDAttributeType),
            attr("title", .stringAttributeType, defaultValue: ""),
            attr("startDate", .dateAttributeType),
            attr("endDate", .dateAttributeType),
            attr("isAllDay", .booleanAttributeType, defaultValue: false),
            attr("isCompleted", .booleanAttributeType, defaultValue: false),
            attr("reminderMinutesBefore", .integer64AttributeType),
            attr("noteMarkdown", .stringAttributeType, defaultValue: ""),
            attr("plainTextIndex", .stringAttributeType, defaultValue: ""),
            attr("categoryID", .UUIDAttributeType),
            attr("seriesID", .UUIDAttributeType),
            attr("globalNoteID", .UUIDAttributeType),
            attr("routineItemID", .UUIDAttributeType),
            attr("occurrenceOriginalDate", .dateAttributeType),
            attr("isDeletedOverride", .booleanAttributeType, defaultValue: false),
            attr("createdAt", .dateAttributeType),
            attr("updatedAt", .dateAttributeType),
            attr("deletedAt", .dateAttributeType)
        ]

        let series = NSEntityDescription()
        series.name = "CDRecurrenceSeries"
        series.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        series.properties = [
            attr("id", .UUIDAttributeType),
            attr("title", .stringAttributeType, defaultValue: ""),
            attr("ruleTypeRaw", .stringAttributeType, defaultValue: "daily"),
            attr("weekdaysMaskRaw", .integer64AttributeType, defaultValue: 0),
            attr("startMinuteOfDay", .integer64AttributeType, defaultValue: 540),
            attr("durationMinutes", .integer64AttributeType, defaultValue: 60),
            attr("isAllDay", .booleanAttributeType, defaultValue: false),
            attr("reminderMinutesBefore", .integer64AttributeType),
            attr("templateMarkdown", .stringAttributeType, defaultValue: ""),
            attr("templatePlainText", .stringAttributeType, defaultValue: ""),
            attr("seriesStartDate", .dateAttributeType),
            attr("seriesEndDate", .dateAttributeType),
            attr("categoryID", .UUIDAttributeType),
            attr("globalNoteID", .UUIDAttributeType),
            attr("createdAt", .dateAttributeType),
            attr("updatedAt", .dateAttributeType),
            attr("deletedAt", .dateAttributeType)
        ]

        let note = NSEntityDescription()
        note.name = "CDStandaloneNote"
        note.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        note.properties = [
            attr("id", .UUIDAttributeType),
            attr("title", .stringAttributeType, defaultValue: ""),
            attr("noteMarkdown", .stringAttributeType, defaultValue: ""),
            attr("plainTextIndex", .stringAttributeType, defaultValue: ""),
            attr("isPinned", .booleanAttributeType, defaultValue: false),
            attr("isGlobal", .booleanAttributeType, defaultValue: false),
            attr("categoryID", .UUIDAttributeType),
            attr("parentNoteID", .UUIDAttributeType),
            attr("createdAt", .dateAttributeType),
            attr("updatedAt", .dateAttributeType),
            attr("deletedAt", .dateAttributeType)
        ]

        let attachment = NSEntityDescription()
        attachment.name = "CDAttachment"
        attachment.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        let imageDataAttr = attr("imageData", .binaryDataAttributeType)
        imageDataAttr.allowsExternalBinaryDataStorage = true
        attachment.properties = [
            attr("id", .UUIDAttributeType),
            attr("fileName", .stringAttributeType, defaultValue: "imagem.png"),
            attr("mimeType", .stringAttributeType, defaultValue: "image/png"),
            imageDataAttr,
            attr("blockID", .UUIDAttributeType),
            attr("seriesID", .UUIDAttributeType),
            attr("noteID", .UUIDAttributeType),
            attr("createdAt", .dateAttributeType),
            attr("updatedAt", .dateAttributeType),
            attr("deletedAt", .dateAttributeType)
        ]

        let inbox = NSEntityDescription()
        inbox.name = "CDInboxItem"
        inbox.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        inbox.properties = [
            attr("id", .UUIDAttributeType),
            attr("title", .stringAttributeType, defaultValue: ""),
            attr("noteMarkdown", .stringAttributeType, defaultValue: ""),
            attr("estimatedMinutes", .integer64AttributeType, defaultValue: 30),
            attr("isCompleted", .booleanAttributeType, defaultValue: false),
            attr("categoryID", .UUIDAttributeType),
            attr("globalNoteID", .UUIDAttributeType),
            attr("sortOrder", .integer64AttributeType, defaultValue: 0),
            attr("createdAt", .dateAttributeType),
            attr("updatedAt", .dateAttributeType),
            attr("deletedAt", .dateAttributeType)
        ]

        let routineItem = NSEntityDescription()
        routineItem.name = "CDDailyRoutineItem"
        routineItem.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        routineItem.properties = [
            attr("id", .UUIDAttributeType),
            attr("title", .stringAttributeType, defaultValue: ""),
            attr("estimatedMinutes", .integer64AttributeType, defaultValue: 30),
            attr("weekdaysMaskRaw", .integer64AttributeType, defaultValue: Int64(WeekdayMask.all.rawValue)),
            attr("categoryID", .UUIDAttributeType),
            attr("sortOrder", .integer64AttributeType, defaultValue: 0),
            attr("createdAt", .dateAttributeType),
            attr("updatedAt", .dateAttributeType),
            attr("deletedAt", .dateAttributeType)
        ]

        let routineCompletion = NSEntityDescription()
        routineCompletion.name = "CDDailyRoutineCompletion"
        routineCompletion.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        routineCompletion.properties = [
            attr("id", .UUIDAttributeType),
            attr("routineItemID", .UUIDAttributeType),
            attr("dayKey", .stringAttributeType, defaultValue: ""),
            attr("isCompleted", .booleanAttributeType, defaultValue: false),
            attr("completedAt", .dateAttributeType),
            attr("updatedAt", .dateAttributeType),
            attr("deletedAt", .dateAttributeType)
        ]

        model.entities = [cat, block, series, note, attachment, inbox, routineItem, routineCompletion]
        return model
    }

    private static func attr(
        _ name: String,
        _ type: NSAttributeType,
        defaultValue: Any? = nil
    ) -> NSAttributeDescription {
        let desc = NSAttributeDescription()
        desc.name = name
        desc.attributeType = type
        desc.isOptional = true
        desc.defaultValue = defaultValue
        return desc
    }

    private static func defaultStoreURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return appSupport
            .appendingPathComponent("MyBetterLife", isDirectory: true)
            .appendingPathComponent("MyBetterLife.sqlite")
    }
}
