import 'package:archiveme_mobile/features/journal/data/journal_cursor_data_source.dart';
import 'package:archiveme_mobile/features/journal/domain/task_node.dart';
import 'package:archiveme_mobile/features/journal/providers/journal_dependency_providers.dart';
import 'package:archiveme_mobile/features/journal/providers/journal_entity_parse_pool.dart';
import 'package:archiveme_mobile/features/journal/providers/journal_entity_slices.dart';
import 'package:archiveme_mobile/features/journal/providers/task_node_map_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cursor-paginated task feed that hydrates [taskNodeMapProvider].
final class TaskTimelinePaginationNotifier
    extends AsyncNotifier<TaskTimelinePaginationState> {
  JournalCursorDataSource get _dataSource =>
      ref.read(journalCursorDataSourceProvider);

  JournalEntityParsePool get _parsePool =>
      ref.read(journalEntityParsePoolProvider);

  @override
  Future<TaskTimelinePaginationState> build() async {
    ref.keepAlive();
    return _loadFirstPage();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadFirstPage);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) {
      return;
    }

    state = AsyncData(current.copyWith(isLoadingMore: true));

    try {
      final rows = await _dataSource.fetchTaskNodeRows(
        after: current.cursor,
        limit: JournalCursorDataSource.pageSize,
      );
      final parsed = await _parsePool.parseTaskNodes(rows);
      ref.read(taskNodeMapProvider.notifier).mergeParsed(parsed);

      final nextIds = _orderedIdsFromRows(rows, parsed);
      final mergedIds = _mergeUniqueIds(current.orderedTaskIds, nextIds);
      final lastNode = _lastNodeFromRows(rows, parsed);

      state = AsyncData(
        current.copyWith(
          orderedTaskIds: mergedIds,
          cursor: lastNode == null
              ? current.cursor
              : TaskNodeFeedCursor(
                  updatedAt: lastNode.updatedAt,
                  id: lastNode.id,
                ),
          hasMore: rows.length >= JournalCursorDataSource.pageSize,
          isLoadingMore: false,
        ),
      );
    } on Object {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  Future<TaskTimelinePaginationState> _loadFirstPage() async {
    final rows = await _dataSource.fetchTaskNodeRows(
      limit: JournalCursorDataSource.pageSize,
    );
    final parsed = await _parsePool.parseTaskNodes(rows);
    ref.read(taskNodeMapProvider.notifier).mergeParsed(parsed);

    final orderedIds = _orderedIdsFromRows(rows, parsed);
    final lastNode = _lastNodeFromRows(rows, parsed);

    return TaskTimelinePaginationState(
      orderedTaskIds: orderedIds,
      cursor: lastNode == null
          ? null
          : TaskNodeFeedCursor(
              updatedAt: lastNode.updatedAt,
              id: lastNode.id,
            ),
      hasMore: rows.length >= JournalCursorDataSource.pageSize,
    );
  }

  List<String> _orderedIdsFromRows(
    List<Map<String, dynamic>> rows,
    Map<String, TaskNode> parsed,
  ) {
    return rows
        .map((row) => row['id'] as String? ?? '')
        .where((id) => id.isNotEmpty && parsed.containsKey(id))
        .toList(growable: false);
  }

  TaskNode? _lastNodeFromRows(
    List<Map<String, dynamic>> rows,
    Map<String, TaskNode> parsed,
  ) {
    if (rows.isEmpty) return null;
    final lastId = rows.last['id'] as String? ?? '';
    return parsed[lastId];
  }

  List<String> _mergeUniqueIds(List<String> existing, List<String> next) {
    if (next.isEmpty) return existing;
    final seen = existing.toSet();
    final merged = [...existing];
    for (final id in next) {
      if (seen.add(id)) {
        merged.add(id);
      }
    }
    return merged;
  }
}

final taskTimelinePaginationProvider = AsyncNotifierProvider<
    TaskTimelinePaginationNotifier, TaskTimelinePaginationState>(
  TaskTimelinePaginationNotifier.new,
);
