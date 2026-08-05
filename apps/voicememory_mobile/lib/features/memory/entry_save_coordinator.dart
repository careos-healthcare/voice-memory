import '../archive_packs/archive_pack_store.dart';
import '../archive_packs/entry_pack_scope.dart';
import 'archive_thread_store.dart';
import 'entry_aboutness.dart';
import 'memory_surfacing_mode.dart';
import 'clean_slate_prompt_store.dart';
import 'entry_memory_mode.dart';
import 'entry_thread_scope.dart';
import 'keep_exact_details.dart';
import 'curated_memory_marker.dart';
import 'memory_scope.dart';
import 'memory_scope_policy.dart';
import 'next_entry_fresh_mode.dart';
import 'treat_as_new.dart';
import '../pressure_retention/pressure_check_in_record.dart';
import '../pressure_retention/pressure_check_in_store.dart';
import '../../models/journal_entry.dart';
import '../../services/app_services.dart';
import '../trust/archive_trust_receipt.dart';

/// Applies per-entry memory mode, thread/pack assignment, and pressure-record
/// sync after a journal entry is saved.
abstract class EntrySaveCoordinator {
  EntrySaveCoordinator._();

  static Future<JournalEntry> applyNewEntryOptions(
    JournalEntry entry, {
    required int entryCount,
  }) async {
    if (TreatAsNew.selectedForNextSave &&
        EntryMemoryModeSession.selectedMode ==
            EntryMemoryMode.useArchiveContext) {
      EntryMemoryModeSession.selectedMode = EntryMemoryMode.treatAsNew;
    }
    if (NextEntryFreshMode.consumeForSave()) {
      EntryMemoryModeSession.selectedMode = EntryMemoryMode.treatAsNew;
    }
    var toPersist = EntryMemoryModeSession.applyToNewEntry(
      entry,
      entryCount: entryCount,
    );
    toPersist = KeepExactDetails.applyToNewEntry(
      toPersist,
      entryCount: entryCount,
    );
    toPersist = PreserveOriginalSession.applyToNewEntry(
      toPersist,
      entryCount: entryCount,
    );
    toPersist = EntryAboutnessSession.applyToNewEntry(
      toPersist,
      entryCount: entryCount,
    );
    toPersist = MemorySurfacingSession.applyToNewEntry(
      toPersist,
      entryCount: entryCount,
    );
    toPersist = await _applyThreadAssignment(toPersist);
    toPersist = await _applyPackAssignment(toPersist);
    if (MemoryScopePolicy.scope == MemoryScope.off) {
      toPersist = _withFlags(toPersist, treatAsNew: true, keepSeparate: false);
      TreatAsNew.lastSaveWasFresh = true;
    }
    await _syncPressureRecord(toPersist);
    ArchiveTrustReceipt.noteSave(entry: toPersist, entryCount: entryCount);
    CleanSlatePromptStore.resetAfterSave();
    EntryAboutnessSession.resetAfterSave();
    MemorySurfacingSession.resetAfterSave();
    PreserveOriginalSession.resetAfterSave();
    EntryThreadScopeSession.resetAfterSave();
    EntryPackScopeSession.resetAfterSave();
    return toPersist;
  }

  /// Assigns an existing entry to a pack and syncs pressure metadata.
  static Future<JournalEntry> assignExistingEntryToPack(
    JournalEntry entry,
    String packId,
  ) async {
    if (!AppServices.isInitialized) return entry;
    try {
      final store = ArchivePackStore.instance();
      await store.assignEntry(packId, entry.id);
      final updated = _withFlags(entry, archivePackId: packId);
      await AppServices.instance.journalStore.update(updated);
      await _syncPressureRecord(updated);
      return updated;
    } catch (_) {
      return entry;
    }
  }

  static Future<JournalEntry> _applyThreadAssignment(JournalEntry entry) async {
    if (entry.keepSeparate) {
      // Explicitly clear the thread assignment. `_withFlags` cannot express
      // this (it treats a null argument as "leave unchanged"), so this
      // goes straight to the lossless `copyWith`, which does support
      // explicitly clearing a nullable field.
      return entry.copyWith(archiveThreadId: null);
    }
    if (!AppServices.isInitialized) return entry;
    try {
      final store = ArchiveThreadStore.instance();
      String? threadId = EntryThreadScopeSession.resolveThreadIdForSave();
      if (EntryThreadScopeSession.selectedScope == EntryThreadScope.newThread) {
        final name = EntryThreadScopeSession.pendingNewThreadName ?? '';
        final created = await store.create(name);
        threadId = created?.id;
      }
      if (threadId == null) return entry;

      await store.assignEntry(threadId, entry.id);
      return _withFlags(entry, archiveThreadId: threadId);
    } catch (_) {
      return entry;
    }
  }

  static Future<JournalEntry> _applyPackAssignment(JournalEntry entry) async {
    if (!AppServices.isInitialized) return entry;
    try {
      final store = ArchivePackStore.instance();
      String? packId = EntryPackScopeSession.resolvePackIdForSave();
      if (EntryPackScopeSession.selectedScope == EntryPackScope.newPack) {
        final name = EntryPackScopeSession.pendingNewPackName ?? '';
        final created = await store.create(name);
        packId = created?.id;
      }
      if (packId == null) return entry;

      await store.assignEntry(packId, entry.id);
      return _withFlags(entry, archivePackId: packId);
    } catch (_) {
      return entry;
    }
  }

  static Future<void> _syncPressureRecord(JournalEntry entry) async {
    if (!AppServices.isInitialized) return;
    try {
      await PressureCheckInStore.instance().syncFromJournalEntry(entry);
    } catch (_) {}
  }

  /// Only ever used to *assign* (never clear) these fields — every other
  /// field, including biomarkers, parentHookId, wasGrounded, verifiedProof,
  /// ownerKey and all synchronization metadata, passes through untouched
  /// via the lossless [JournalEntry.copyWith]. To explicitly clear a
  /// nullable field, call `entry.copyWith(field: null)` directly instead.
  static JournalEntry _withFlags(
    JournalEntry entry, {
    bool? treatAsNew,
    bool? keepSeparate,
    String? archiveThreadId,
    String? archivePackId,
    String? entryAboutness,
    String? memorySurfacing,
    bool? preserveOriginal,
  }) => entry.copyWith(
    treatAsNew: treatAsNew,
    keepSeparate: keepSeparate,
    archiveThreadId: archiveThreadId ?? entry.archiveThreadId,
    archivePackId: archivePackId ?? entry.archivePackId,
    entryAboutness: entryAboutness,
    memorySurfacing: memorySurfacing,
    preserveOriginal: preserveOriginal,
  );
}
