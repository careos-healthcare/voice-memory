import 'package:archiveme_mobile/features/archive_history/archive_history_item.dart';
import 'package:archiveme_mobile/features/entry_importance/entry_importance_store.dart';
import 'package:archiveme_mobile/features/pattern_detail/pattern_detail_model.dart';

/// Entry importance helpers — display priority only, no proof changes.
abstract final class EntryImportanceEngine {
  EntryImportanceEngine._();

  static bool isImportant(String entryId) =>
      EntryImportanceStore.isImportant(entryId);

  static List<ArchiveHistoryItem> prioritizeHistoryItems(
    List<ArchiveHistoryItem> items,
  ) {
    if (items.length < 2) return items;
    final important = <ArchiveHistoryItem>[];
    final rest = <ArchiveHistoryItem>[];
    for (final item in items) {
      if (item.isImportant) {
        important.add(item);
      } else {
        rest.add(item);
      }
    }
    if (important.isEmpty || rest.isEmpty) return items;
    return [...important, ...rest];
  }

  static List<PatternDetailMoment> prioritizePatternMoments(
    List<PatternDetailMoment> moments,
  ) {
    if (moments.length < 2) return moments;
    final important = <PatternDetailMoment>[];
    final rest = <PatternDetailMoment>[];
    for (final moment in moments) {
      if (moment.isImportant) {
        important.add(moment);
      } else {
        rest.add(moment);
      }
    }
    if (important.isEmpty || rest.isEmpty) return moments;
    return [...important, ...rest];
  }
}