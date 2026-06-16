import 'package:flutter/foundation.dart';

import '../archive_packs/entry_pack_scope.dart';
import '../pressure_retention/pressure_check_in_record.dart';
import 'entry_memory_mode.dart';
import 'entry_thread_scope.dart';
import 'memory_connection_rules.dart';
import 'memory_control_model.dart';
import 'wrong_thread_feedback.dart';

/// Deterministic classification of what the user is doing right now.
enum CurrentIntent {
  firstSave('first_save'),
  freshEntry('fresh_entry'),
  useArchiveContext('use_archive_context'),
  keepSeparate('keep_separate'),
  threadBound('thread_bound'),
  packBound('pack_bound'),
  searchingArchive('searching_archive'),
  unknown('unknown');

  const CurrentIntent(this.id);

  final String id;
}

/// Classifies current intent from entry state — no AI, no user text logged.
abstract class CurrentIntentSignal {
  CurrentIntentSignal._();

  static CurrentIntent classify({
    required MemoryCardType cardType,
    required List<PressureCheckInRecord> records,
    required int entryCount,
    bool searchingArchive = false,
  }) {
    if (searchingArchive) return CurrentIntent.searchingArchive;
    if (entryCount <= 1) return CurrentIntent.firstSave;
    if (EntryMemoryModeSession.selectedMode == EntryMemoryMode.keepSeparate ||
        records.any((r) => r.keepSeparate)) {
      return CurrentIntent.keepSeparate;
    }
    if (EntryMemoryModeSession.selectedMode == EntryMemoryMode.treatAsNew ||
        records.any((r) => r.treatAsNew) ||
        MemoryConnectionRules.isFutureFresh(cardType.id)) {
      return CurrentIntent.freshEntry;
    }
    if (WrongThreadFeedback.explicitThreadFor(cardType) != null ||
        EntryThreadScopeSession.selectedScope ==
            EntryThreadScope.existingThread ||
        records.any(
          (r) => r.archiveThreadId != null && r.archiveThreadId!.isNotEmpty,
        )) {
      return CurrentIntent.threadBound;
    }
    if (EntryPackScopeSession.selectedScope == EntryPackScope.existingPack ||
        records.any(
          (r) => r.archivePackId != null && r.archivePackId!.isNotEmpty,
        )) {
      return CurrentIntent.packBound;
    }
    if (EntryMemoryModeSession.selectedMode ==
        EntryMemoryMode.useArchiveContext) {
      return CurrentIntent.useArchiveContext;
    }
    return CurrentIntent.unknown;
  }

  static bool blocksMemoryClaims(CurrentIntent intent) => switch (intent) {
    CurrentIntent.firstSave ||
    CurrentIntent.freshEntry ||
    CurrentIntent.keepSeparate => true,
    _ => false,
  };

  @visibleForTesting
  static void resetSessionForTest() {
    EntryMemoryModeSession.resetSessionForTest();
    EntryThreadScopeSession.resetSessionForTest();
    EntryPackScopeSession.resetSessionForTest();
  }
}
