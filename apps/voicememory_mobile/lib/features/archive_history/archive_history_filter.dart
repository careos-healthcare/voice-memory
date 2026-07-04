import 'archive_history_copy.dart';
import 'archive_history_item.dart';

/// Lightweight status filters for the saved-moments archive history sheet.
enum ArchiveHistoryFilter {
  all,
  usedAsEvidence,
  savedOnly,
  needsYourWords,
  quietDays,
  ignoredForPatterns,
  helped,
}

/// Applies archive history filters locally — no search or backend.
abstract final class ArchiveHistoryFilterEngine {
  ArchiveHistoryFilterEngine._();

  static const defaultFilter = ArchiveHistoryFilter.all;

  static const orderedFilters = [
    ArchiveHistoryFilter.all,
    ArchiveHistoryFilter.usedAsEvidence,
    ArchiveHistoryFilter.savedOnly,
    ArchiveHistoryFilter.needsYourWords,
    ArchiveHistoryFilter.quietDays,
    ArchiveHistoryFilter.ignoredForPatterns,
    ArchiveHistoryFilter.helped,
  ];

  static String label(ArchiveHistoryFilter filter) => switch (filter) {
        ArchiveHistoryFilter.all => ArchiveHistoryCopy.filterAll,
        ArchiveHistoryFilter.usedAsEvidence =>
          ArchiveHistoryCopy.filterUsedAsEvidence,
        ArchiveHistoryFilter.savedOnly => ArchiveHistoryCopy.filterSavedOnly,
        ArchiveHistoryFilter.needsYourWords =>
          ArchiveHistoryCopy.filterNeedsYourWords,
        ArchiveHistoryFilter.quietDays => ArchiveHistoryCopy.filterQuietDays,
        ArchiveHistoryFilter.ignoredForPatterns =>
          ArchiveHistoryCopy.filterIgnoredForPatterns,
        ArchiveHistoryFilter.helped => ArchiveHistoryCopy.filterHelped,
      };

  static String filterKey(ArchiveHistoryFilter filter) => switch (filter) {
        ArchiveHistoryFilter.all => 'all',
        ArchiveHistoryFilter.usedAsEvidence => 'used_as_evidence',
        ArchiveHistoryFilter.savedOnly => 'saved_only',
        ArchiveHistoryFilter.needsYourWords => 'needs_your_words',
        ArchiveHistoryFilter.quietDays => 'quiet_days',
        ArchiveHistoryFilter.ignoredForPatterns => 'ignored_for_patterns',
        ArchiveHistoryFilter.helped => 'helped',
      };

  static List<ArchiveHistoryItem> apply({
    required List<ArchiveHistoryItem> items,
    required ArchiveHistoryFilter filter,
  }) {
    if (filter == ArchiveHistoryFilter.all) return items;
    return [
      for (final item in items)
        if (matches(item: item, filter: filter)) item,
    ];
  }

  static bool matches({
    required ArchiveHistoryItem item,
    required ArchiveHistoryFilter filter,
  }) =>
      switch (filter) {
        ArchiveHistoryFilter.all => true,
        ArchiveHistoryFilter.usedAsEvidence =>
          item.status == ArchiveHistoryStatus.usedAsEvidence,
        ArchiveHistoryFilter.savedOnly =>
          item.status == ArchiveHistoryStatus.savedOnly,
        ArchiveHistoryFilter.needsYourWords =>
          item.status == ArchiveHistoryStatus.needsYourWords,
        ArchiveHistoryFilter.quietDays => item.isQuietDay,
        ArchiveHistoryFilter.ignoredForPatterns =>
          item.status == ArchiveHistoryStatus.ignoredForPatterns,
        ArchiveHistoryFilter.helped => item.helpedNote != null,
      };
}
