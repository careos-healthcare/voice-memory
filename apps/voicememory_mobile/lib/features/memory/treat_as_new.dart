import 'package:flutter/foundation.dart';

import '../../models/journal_entry.dart';
import '../../services/activation_funnel_analytics.dart';
import 'memory_scope.dart';
import 'memory_scope_policy.dart';

/// "Treat this as new" — a clear, lightweight way to keep one entry
/// separate from previous archive patterns. Memory should be evidence,
/// not gravity: ArchiveMe can connect entries when useful, and it can
/// also leave an entry alone.
///
/// What the flag does:
/// - The entry is saved normally, in full, and stays findable in the
///   archive. The recording/note text is never altered.
/// - A metadata flag (`treatAsNew: true`) tells memory/insight engines
///   not to use this entry to create immediate connection claims.
/// - Memory is never globally disabled: only this entry is left alone,
///   and future entries connect exactly as before.
abstract class TreatAsNew {
  TreatAsNew._();

  // --- Consumer copy (compile-time constants) ---

  static const String controlLabel = 'Treat this as new';
  static const String helper = 'Not everything needs to connect.';
  static const String expandedHelper =
      'ArchiveMe will save this entry without using it to suggest a '
      'connection right now.';
  static const String postSaveTitle = 'Saved as a fresh entry.';
  static const String postSaveBody =
      'ArchiveMe will not force this into an old pattern.';

  // --- Session state ---

  /// The control is selected for the next save. Default off; cleared
  /// after every save so the choice is always per-entry.
  static bool selectedForNextSave = false;

  /// The most recent save carried the flag — drives the post-save
  /// fresh-entry receipt only.
  static bool lastSaveWasFresh = false;

  /// Applies the pending choice to a brand-new entry at save time.
  ///
  /// Returns the entry to persist: a flagged copy when the control was
  /// selected (same text, same id, metadata only), or the entry untouched
  /// otherwise. Consumes the selection either way so it never leaks into
  /// a later save.
  static JournalEntry applyToNewEntry(
    JournalEntry entry, {
    required int entryCount,
  }) {
    if (!selectedForNextSave) {
      lastSaveWasFresh = false;
      return entry;
    }
    selectedForNextSave = false;
    lastSaveWasFresh = true;
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.treatAsNewSaved,
      entryCount: entryCount,
      enabled: true,
    );
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.memoryTreatAsNewSaved,
      entryCount: entryCount,
      memoryScope: MemoryScopePolicy.scope.id,
    );
    return entry.copyWith(treatAsNew: true);
  }

  @visibleForTesting
  static void resetSessionForTest() {
    selectedForNextSave = false;
    lastSaveWasFresh = false;
  }
}
