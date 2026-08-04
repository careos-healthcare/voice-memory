import 'package:flutter/foundation.dart';

import '../../models/journal_entry.dart';
import '../../services/activation_funnel_analytics.dart';
import 'entry_thread_scope.dart';
import 'memory_scope.dart';
import 'memory_scope_policy.dart';
import 'treat_as_new.dart';

/// Per-entry memory mode — narrows (never widens) the global memory scope.
enum EntryMemoryMode {
  useArchiveContext('use_archive_context'),
  treatAsNew('treat_as_new'),
  keepSeparate('keep_separate');

  const EntryMemoryMode(this.id);

  final String id;

  String get label => switch (this) {
    EntryMemoryMode.useArchiveContext => EntryMemoryModeCopy.useLabel,
    EntryMemoryMode.treatAsNew => EntryMemoryModeCopy.treatAsNewLabel,
    EntryMemoryMode.keepSeparate => EntryMemoryModeCopy.keepSeparateLabel,
  };

  String get helper => switch (this) {
    EntryMemoryMode.useArchiveContext =>
      EntryMemoryModeCopy.useArchiveContextHelper,
    EntryMemoryMode.treatAsNew => EntryMemoryModeCopy.treatAsNewHelper,
    EntryMemoryMode.keepSeparate => EntryMemoryModeCopy.keepSeparateHelper,
  };

  static EntryMemoryMode? fromId(String? id) {
    if (id == null) return null;
    for (final mode in values) {
      if (mode.id == id) return mode;
    }
    return null;
  }
}

/// Session selection for the next save. Default: use archive context.
abstract class EntryMemoryModeSession {
  EntryMemoryModeSession._();

  static EntryMemoryMode selectedMode = EntryMemoryMode.useArchiveContext;

  static void select(EntryMemoryMode mode, {int? entryCount}) {
    selectedMode = mode;
    // Keep legacy treat-as-new session flag in sync for ask-mode paths.
    TreatAsNew.selectedForNextSave = mode == EntryMemoryMode.treatAsNew;
    if (mode == EntryMemoryMode.treatAsNew) {
      MemoryScopePolicy.connectApprovedForNextSave = false;
    } else if (mode == EntryMemoryMode.useArchiveContext &&
        MemoryScopePolicy.scope == MemoryScope.ask) {
      MemoryScopePolicy.connectApprovedForNextSave = true;
    } else {
      MemoryScopePolicy.connectApprovedForNextSave = false;
    }
    if (mode == EntryMemoryMode.keepSeparate) {
      EntryThreadScopeSession.forceNoThread();
    }
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.entryMemoryModeSelected,
      entryCount: entryCount,
      entryMemoryMode: mode.id,
      memoryScope: MemoryScopePolicy.scope.id,
      source: 'record',
    );
  }

  /// Applies the pending mode to a brand-new entry at save time.
  static JournalEntry applyToNewEntry(
    JournalEntry entry, {
    required int entryCount,
  }) {
    final mode = selectedMode;
    selectedMode = EntryMemoryMode.useArchiveContext;
    TreatAsNew.selectedForNextSave = false;

    switch (mode) {
      case EntryMemoryMode.treatAsNew:
        TreatAsNew.lastSaveWasFresh = true;
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
        return _copy(entry, treatAsNew: true, keepSeparate: false);

      case EntryMemoryMode.keepSeparate:
        TreatAsNew.lastSaveWasFresh = false;
        ActivationFunnelAnalytics.track(
          ActivationFunnelAnalytics.entrySavedKeepSeparate,
          entryCount: entryCount,
          memoryScope: MemoryScopePolicy.scope.id,
          source: 'record',
        );
        return _copy(entry, treatAsNew: false, keepSeparate: true);

      case EntryMemoryMode.useArchiveContext:
        TreatAsNew.lastSaveWasFresh = false;
        var result = _copy(entry, treatAsNew: false, keepSeparate: false);
        if (MemoryScopePolicy.scope == MemoryScope.ask) {
          final approved = MemoryScopePolicy.consumeConnectApproval();
          if (approved) {
            result = _copy(result, connectionApproved: true);
          }
        }
        ActivationFunnelAnalytics.track(
          ActivationFunnelAnalytics.entrySavedUseArchiveContext,
          entryCount: entryCount,
          memoryScope: MemoryScopePolicy.scope.id,
          source: 'record',
        );
        return result;
    }
  }

  static JournalEntry _copy(
    JournalEntry entry, {
    bool? treatAsNew,
    bool? keepSeparate,
    bool? connectionApproved,
  }) => JournalEntry(
    id: entry.id,
    createdAt: entry.createdAt,
    transcript: entry.transcript,
    durationSeconds: entry.durationSeconds,
    reflection: entry.reflection,
    verifiedProof: entry.verifiedProof,
    syncStatus: entry.syncStatus,
    localAudioPath: entry.localAudioPath,
    treatAsNew: treatAsNew ?? entry.treatAsNew,
    connectionApproved: connectionApproved ?? entry.connectionApproved,
    keepExactDetails: entry.keepExactDetails,
    keepSeparate: keepSeparate ?? entry.keepSeparate,
    archiveThreadId: entry.archiveThreadId,
    archivePackId: entry.archivePackId,
    isPinned: entry.isPinned,
    pinnedAt: entry.pinnedAt,
    isArchived: entry.isArchived,
    archivedAt: entry.archivedAt,
    entryAboutness: entry.entryAboutness,
    memorySurfacing: entry.memorySurfacing,
    preserveOriginal: entry.preserveOriginal,
    captureContextTag: entry.captureContextTag,
  );

  @visibleForTesting
  static void resetSessionForTest() {
    selectedMode = EntryMemoryMode.useArchiveContext;
  }
}

abstract class EntryMemoryModeCopy {
  EntryMemoryModeCopy._();

  static const String sectionTitle = 'For this entry';
  static const String entryOptionsTitle = 'Entry options';
  static const String advancedSaveOptionsTitle = 'Advanced save options';
  static const String advancedSaveOptionsCollapsedHelper =
      'Most entries can use the default. ArchiveMe will compare this with '
      'future entries when there is enough to compare.';
  static const String useLabel = 'Use archive context';
  static const String treatAsNewLabel = 'Treat as new';
  static const String keepSeparateLabel = 'Keep separate';
  static const String useArchiveContextHelper =
      'ArchiveMe may compare this with related entries when memory is allowed.';
  static const String treatAsNewHelper =
      'Save this without using earlier entries to shape it.';
  static const String keepSeparateHelper =
      'Save this separately from existing threads and suggestions.';
  static const String memoryOffTitle = 'Memory is off';
  static const String memoryOffBody =
      'This entry will be saved without archive suggestions.';

  static const List<String> all = [
    sectionTitle,
    entryOptionsTitle,
    advancedSaveOptionsTitle,
    advancedSaveOptionsCollapsedHelper,
    useLabel,
    treatAsNewLabel,
    keepSeparateLabel,
    useArchiveContextHelper,
    treatAsNewHelper,
    keepSeparateHelper,
    memoryOffTitle,
    memoryOffBody,
  ];
}
