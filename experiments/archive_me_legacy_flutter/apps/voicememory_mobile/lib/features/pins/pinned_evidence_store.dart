import '../../models/journal_entry.dart';
import '../../services/app_services.dart';
import '../../storage/journal_store.dart';

/// All consumer copy for pins — compile-time constants so tests can
/// sweep them and no private content can leak in.
abstract class PinnedEvidenceCopy {
  PinnedEvidenceCopy._();

  static const String pinLabel = 'Pin';
  static const String pinnedLabel = 'Pinned';
  static const String pinAccessibilityLabel = 'Pin this entry';
  static const String unpinAccessibilityLabel = 'Unpin this entry';
  static const String pinnedReceipt = 'Saved to Pinned';
  static const String unpinnedReceipt = 'Removed from Pinned';

  static const String settingsTitle = 'Pinned evidence';
  static const String settingsSubtitle = 'Find saved entries quickly.';
  static const String screenTitle = 'Pinned evidence';
  static const String emptyTitle = 'Nothing pinned yet';
  static const String emptyHelper = 'Pin entries you want to revisit.';
}

/// Pins / Saved Evidence — pin state on top of the journal store.
///
/// Pinning writes safe metadata only (`isPinned`, `pinnedAt`) onto the
/// existing entry: the text, reflection, memory flags, and timestamps
/// are untouched. A pin makes an entry easier to find — it never
/// changes memory scope and never creates authority on its own; only
/// explicit user confirmation does that, exactly as before.
class PinnedEvidenceStore {
  PinnedEvidenceStore(this._journal);

  final JournalStore _journal;

  static PinnedEvidenceStore instance() =>
      PinnedEvidenceStore(AppServices.instance.journalStore);

  static PinnedEvidenceStore forStore(JournalStore store) =>
      PinnedEvidenceStore(store);

  /// Sets the pin state. Returns the updated entry, or null when the
  /// entry does not exist. No-op (returns the entry) when the state
  /// already matches.
  Future<JournalEntry?> setPinned(
    String entryId,
    bool pinned, {
    DateTime? now,
  }) async {
    final entry = await _journal.getById(entryId);
    if (entry == null) return null;
    if (entry.isPinned == pinned) return entry;
    final updated = JournalEntry(
      id: entry.id,
      createdAt: entry.createdAt,
      transcript: entry.transcript,
      durationSeconds: entry.durationSeconds,
      reflection: entry.reflection,
      syncStatus: entry.syncStatus,
      localAudioPath: entry.localAudioPath,
      localAudioVaultRef: entry.localAudioVaultRef,
      treatAsNew: entry.treatAsNew,
      connectionApproved: entry.connectionApproved,
      keepExactDetails: entry.keepExactDetails,
      isPinned: pinned,
      pinnedAt: pinned ? (now ?? DateTime.now()) : null,
      isArchived: entry.isArchived,
      archivedAt: entry.archivedAt,
      entryAboutness: entry.entryAboutness,
      memorySurfacing: entry.memorySurfacing,
      preserveOriginal: entry.preserveOriginal,
      captureContextTag: entry.captureContextTag,
    );
    await _journal.save(updated, first25Source: 'pin_toggle');
    return updated;
  }

  /// Flips the pin state. Returns the new pinned value, or null when
  /// the entry does not exist.
  Future<bool?> togglePin(String entryId, {DateTime? now}) async {
    final entry = await _journal.getById(entryId);
    if (entry == null) return null;
    final updated = await setPinned(entryId, !entry.isPinned, now: now);
    return updated?.isPinned;
  }

  /// Pinned entries, most recently pinned first.
  Future<List<JournalEntry>> pinnedEntries() async {
    final all = await _journal.loadAll();
    final pinned = all.where((e) => e.isPinned).toList()
      ..sort((a, b) {
        final aAt = a.pinnedAt ?? a.createdAt;
        final bAt = b.pinnedAt ?? b.createdAt;
        return bAt.compareTo(aAt);
      });
    return pinned;
  }
}
