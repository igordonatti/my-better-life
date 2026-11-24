import Foundation
import Testing
@testable import MyBetterLifeCore

@Suite("PlannerStore LWW Sync & Soft-Delete Tombstones")
@MainActor
struct SyncMergeTests {
    @Test("Soft-deletes keep tombstones in syncSnapshot while hiding records from active UI lists")
    func softDeleteTombstoneSync() {
        let store = PlannerStore(inMemory: true)
        let now = Date()
        let block = TimeBlock(
            title: "Bloco para apagar",
            startDate: now,
            endDate: now.addingTimeInterval(3600),
            noteMarkdown: "Teste"
        )
        store.upsertBlock(block)
        #expect(store.blocks.count == 1)

        store.deleteBlock(id: block.id)
        #expect(store.blocks.isEmpty)

        let snapshot = store.syncSnapshot()
        #expect(snapshot.blocks.count == 1)
        #expect(snapshot.blocks.first?.deletedAt != nil)
    }

    @Test("Remote LWW merge applies newer remote edits and ignores stale remote records")
    func lastWriteWinsMerge() {
        let store = PlannerStore(inMemory: true)
        let t1 = Date(timeIntervalSince1970: 1_700_000_000)
        let t2 = Date(timeIntervalSince1970: 1_700_000_100)
        let t0 = Date(timeIntervalSince1970: 1_699_999_900)

        let localNote = StandaloneNote(
            title: "Versão Local",
            noteMarkdown: "Texto local",
            createdAt: t1,
            updatedAt: t1
        )
        store.upsertNote(localNote)

        // Older remote edit should NOT overwrite newer local edit
        let staleRemote = StandaloneNote(
            id: localNote.id,
            title: "Versão Antiga",
            noteMarkdown: "Texto antigo",
            createdAt: t0,
            updatedAt: t0
        )
        store.applyRemoteSync(categories: [], blocks: [], notes: [staleRemote], attachments: [])
        #expect(store.note(for: localNote.id)?.title == "Versão Local")

        // Newer remote edit SHOULD overwrite local edit
        let newerRemote = StandaloneNote(
            id: localNote.id,
            title: "Versão do iPhone",
            noteMarkdown: "Editado no celular",
            createdAt: t1,
            updatedAt: t2
        )
        store.applyRemoteSync(categories: [], blocks: [], notes: [newerRemote], attachments: [])
        #expect(store.note(for: localNote.id)?.title == "Versão do iPhone")
        #expect(store.note(for: localNote.id)?.noteMarkdown == "Editado no celular")
    }

    @Test("InboxItem persists in Core Data, preserves soft-delete tombstones, and merges remote LWW updates")
    func inboxPersistenceAndLWW() {
        let store = PlannerStore(inMemory: true)
        let t1 = Date(timeIntervalSince1970: 1_700_000_000)
        let t2 = Date(timeIntervalSince1970: 1_700_000_200)

        let item = InboxItem(title: "Pagar conta de luz", estimatedMinutes: 15, createdAt: t1, updatedAt: t1)
        store.upsertInboxItem(item)
        #expect(store.pendingInboxItems.count == 1)

        // Newer remote update completes & renames it
        let remoteUpdated = InboxItem(
            id: item.id,
            title: "Pagar conta de luz (pago no celular)",
            estimatedMinutes: 15,
            isCompleted: true,
            createdAt: t1,
            updatedAt: t2
        )
        store.applyRemoteSync(categories: [], blocks: [], notes: [], attachments: [], inboxItems: [remoteUpdated])
        #expect(store.inboxItem(for: item.id)?.isCompleted == true)
        #expect(store.pendingInboxItems.isEmpty)

        // Soft-delete keeps tombstone in syncSnapshot
        store.deleteInboxItem(id: item.id)
        #expect(store.inboxItems.isEmpty)
        let snapshot = store.syncSnapshot()
        #expect(snapshot.inboxItems.count == 1)
        #expect(snapshot.inboxItems.first?.deletedAt != nil)
    }
}
