import 'package:flutter/foundation.dart';

import '../../models/journal_entry.dart';
import '../../services/activation_funnel_analytics.dart';
import 'memory_scope.dart';
import 'memory_scope_policy.dart';
import 'curated_memory_preservation_policy.dart';

/// "Keep exact details" — a per-entry flag that protects workflow and
/// project context from being generalized away.
///
/// ArchiveMe must preserve exact evidence. With this flag:
/// - The entry is stored normally, in full, and stays findable in the
///   archive and search. Text is never altered.
/// - The entry is never compressed into a generic memory summary or
///   folded into a duplicate/pattern group.
/// - It may support future evidence only as an individual exact
///   evidence item.
/// - Only the flag (never the entry text) is visible to analytics.
abstract class KeepExactDetails {
  KeepExactDetails._();

  // --- Consumer copy (compile-time constants) ---

  static const String controlLabel = 'Keep exact details';
  static const String helper =
      'ArchiveMe will keep this as evidence, not fold it into a general '
      'pattern.';
  static const String savedReceipt = 'Saved as exact evidence';

  // --- Session state ---

  /// The control is selected for the next save. Default off; cleared
  /// after every save so the choice is always per-entry.
  static bool selectedForNextSave = false;

  /// The most recent save carried the flag — drives the post-save
  /// receipt line only.
  static bool lastSaveKeptExact = false;

  /// Applies the pending choice to a brand-new entry at save time.
  /// Returns the entry to persist: a flagged copy when selected (same
  /// text, same id, metadata only) or the entry untouched. Consumes the
  /// selection either way.
  static JournalEntry applyToNewEntry(
    JournalEntry entry, {
    required int entryCount,
  }) {
    if (!selectedForNextSave) {
      lastSaveKeptExact = false;
      return entry;
    }
    selectedForNextSave = false;
    lastSaveKeptExact = true;
    CuratedMemoryPreservationPolicy.noteKeepExactApplied(
      entryCount: entryCount,
    );
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.keepExactDetailsSaved,
      entryCount: entryCount,
      enabled: true,
      memoryScope: MemoryScopePolicy.scope.id,
    );
    return JournalEntry(
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
      keepExactDetails: true,
      keepSeparate: entry.keepSeparate,
      archiveThreadId: entry.archiveThreadId,
      archivePackId: entry.archivePackId,
      isPinned: entry.isPinned,
      pinnedAt: entry.pinnedAt,
      isArchived: entry.isArchived,
      archivedAt: entry.archivedAt,
      entryAboutness: entry.entryAboutness,
      memorySurfacing: entry.memorySurfacing,
      preserveOriginal: true,
    );
  }

  @visibleForTesting
  static void resetSessionForTest() {
    selectedForNextSave = false;
    lastSaveKeptExact = false;
  }
}
