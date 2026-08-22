/**
 * @deprecated Import from journal-sync-engine — re-exports for compatibility.
 */
export {
  type ClientJournalSyncStatus,
  enqueueJournalSync,
  flushJournalSyncQueue,
  getClientJournalSyncStatus,
  hasSignedInSession,
  pullEntriesFromServer as pullJournalFromServer,
  pushEntriesToServer as pushJournalToServer,
  reconcileJournalWithServer,
  setClientJournalSyncStatus,
  syncEntryServerFirst,
} from "@/lib/persistence/journal-sync-engine";
