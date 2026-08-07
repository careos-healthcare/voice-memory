import 'package:flutter/foundation.dart';

import '../../models/journal_entry.dart';
import '../../services/activation_funnel_analytics.dart';
import '../action_items/archive_action_item.dart';
import 'memory_scope.dart';
import 'memory_scope_policy.dart';

/// Stable preservation-source ids for analytics — never user text.
enum CuratedPreservationSource {
  manual('manual'),
  keepExactDetails('keep_exact_details'),
  pin('pin'),
  actionItem('action_item'),
  userConfirmedConnection('user_confirmed_connection'),
  packMaterial('pack_material');

  const CuratedPreservationSource(this.id);

  final String id;
}

/// Whether an entry carries explicit preserve-original metadata.
enum PreserveOriginalMode {
  normal('normal'),
  preserveOriginal('preserve_original');

  const PreserveOriginalMode(this.id);

  final String id;

  String get label => CuratedMemoryCopy.preserveOriginalLabel;

  String get helper => CuratedMemoryCopy.preserveOriginalHelper;

  static PreserveOriginalMode fromEntry(JournalEntry entry) =>
      entry.preserveOriginal
      ? PreserveOriginalMode.preserveOriginal
      : PreserveOriginalMode.normal;
}

/// Session selection for the next save.
abstract class PreserveOriginalSession {
  PreserveOriginalSession._();

  static var selectedForNextSave = false;
  static var lastSavePreservedOriginal = false;

  static void select(bool enabled, {required int entryCount}) {
    selectedForNextSave = enabled;
    ActivationFunnelAnalytics.track(
      enabled
          ? ActivationFunnelAnalytics.preserveOriginalSelected
          : ActivationFunnelAnalytics.preserveOriginalRemoved,
      entryCount: entryCount,
      memoryScope: MemoryScopePolicy.scope.id,
      source: 'record',
      preservationSource: CuratedPreservationSource.manual.id,
    );
  }

  static JournalEntry applyToNewEntry(
    JournalEntry entry, {
    required int entryCount,
  }) {
    if (!selectedForNextSave) {
      lastSavePreservedOriginal = false;
      selectedForNextSave = false;
      return entry;
    }
    selectedForNextSave = false;
    lastSavePreservedOriginal = true;
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.curatedMemoryPreservationApplied,
      entryCount: entryCount,
      memoryScope: MemoryScopePolicy.scope.id,
      source: 'record',
      preservationSource: CuratedPreservationSource.manual.id,
    );
    return _copy(entry, preserveOriginal: true);
  }

  static JournalEntry _copy(
    JournalEntry entry, {
    required bool preserveOriginal,
  }) => entry.copyWith(preserveOriginal: preserveOriginal);

  static void clearSaveReceipt() {
    lastSavePreservedOriginal = false;
  }

  static void resetAfterSave() {
    selectedForNextSave = false;
  }

  @visibleForTesting
  static void resetSessionForTest() {
    selectedForNextSave = false;
    lastSavePreservedOriginal = false;
  }
}

abstract class CuratedMemoryCopy {
  CuratedMemoryCopy._();

  static const String preserveOriginalLabel = 'Preserve original';
  static const String preserveOriginalHelper =
      'Keep this wording as evidence, not just a summary.';
  static const String savedReceipt = 'Original preserved';
  static const String summarySectionTitle = 'Summary';
  static const String originalEvidenceSectionTitle = 'Original evidence';
  static const String sourceEntrySectionTitle = 'Source entry';
  static const String originalSavedDetail = 'Original saved detail';
  static const String openEntryLabel = 'Open entry';
  static const String searchFilterLabel = 'Preserved original';
  static const String searchChipLabel = 'Original preserved';
  static const String exportLabel = 'Original preserved';
  static const String exportYes = 'Yes';
  static const String generatedSummaryLabel = 'Generated summary';
  static const String updatedReceipt = 'Original preserved';

  static const List<String> all = [
    preserveOriginalLabel,
    preserveOriginalHelper,
    savedReceipt,
    summarySectionTitle,
    originalEvidenceSectionTitle,
    sourceEntrySectionTitle,
    originalSavedDetail,
    openEntryLabel,
    searchFilterLabel,
    searchChipLabel,
    exportLabel,
    exportYes,
    generatedSummaryLabel,
    updatedReceipt,
  ];
}

/// Identifies user-curated evidence without inferring from content.
abstract class CuratedMemoryMarker {
  CuratedMemoryMarker._();

  static bool isCurated(JournalEntry entry, {bool hasActionItem = false}) =>
      entry.preserveOriginal ||
      entry.keepExactDetails ||
      entry.isPinned ||
      entry.connectionApproved ||
      hasActionItem ||
      entry.entryAboutness == 'project_material';

  static bool showsPreservedChip(JournalEntry entry) =>
      entry.preserveOriginal || entry.keepExactDetails;

  static bool matchesPreservedFilter(JournalEntry entry) =>
      entry.preserveOriginal || entry.keepExactDetails;

  static CuratedPreservationSource? sourceFor(
    JournalEntry entry, {
    bool hasActionItem = false,
  }) {
    if (entry.preserveOriginal) {
      return CuratedPreservationSource.manual;
    }
    if (entry.keepExactDetails) {
      return CuratedPreservationSource.keepExactDetails;
    }
    if (entry.isPinned) return CuratedPreservationSource.pin;
    if (hasActionItem) return CuratedPreservationSource.actionItem;
    if (entry.connectionApproved) {
      return CuratedPreservationSource.userConfirmedConnection;
    }
    if (entry.entryAboutness == 'project_material') {
      return CuratedPreservationSource.packMaterial;
    }
    return null;
  }

  static bool hasActionItemForEntry(
    String entryId,
    List<ArchiveActionItem> actionItems,
  ) => actionItems.any(
    (item) => item.sourceEntryId == entryId && !item.isDismissed,
  );
}
