import 'package:archiveme_mobile/features/journal/domain/task_node.dart';
import 'package:archiveme_mobile/features/journal/providers/journal_entry_map_notifier.dart';
import 'package:archiveme_mobile/features/journal/providers/journal_timeline_pagination_notifier.dart';
import 'package:archiveme_mobile/features/journal/providers/task_node_map_notifier.dart';
import 'package:archiveme_mobile/features/journal/providers/task_timeline_pagination_notifier.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'journal_dependency_providers.dart';
export 'journal_entity_slices.dart';
export 'journal_entry_map_notifier.dart';
export 'journal_timeline_pagination_notifier.dart';
export 'task_node_map_notifier.dart';
export 'task_timeline_pagination_notifier.dart';

/// Select a single journal entry without rebuilding unrelated timeline rows.
final journalEntryByIdProvider = Provider.family<JournalEntry?, String>(
  (ref, entryId) {
    return ref.watch(
      journalEntryMapProvider.select(
        (asyncValue) => asyncValue.value?.entries[entryId],
      ),
    );
  },
);

/// Select a single task node without rebuilding unrelated task rows.
final taskNodeByIdProvider = Provider.family<TaskNode?, String>(
  (ref, nodeId) {
    return ref.watch(
      taskNodeMapProvider.select(
        (asyncValue) => asyncValue.value?.nodes[nodeId],
      ),
    );
  },
);

/// Ordered timeline ids for infinite-scroll list builders.
final journalTimelineEntryIdsProvider = Provider<List<String>>((ref) {
  return ref.watch(
    journalTimelinePaginationProvider.select(
      (asyncValue) => asyncValue.value?.orderedEntryIds ?? const [],
    ),
  );
});

/// Ordered task ids for infinite-scroll list builders.
final taskTimelineEntryIdsProvider = Provider<List<String>>((ref) {
  return ref.watch(
    taskTimelinePaginationProvider.select(
      (asyncValue) => asyncValue.value?.orderedTaskIds ?? const [],
    ),
  );
});
