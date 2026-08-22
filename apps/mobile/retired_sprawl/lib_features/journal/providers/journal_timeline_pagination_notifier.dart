import 'package:archiveme_mobile/features/journal/data/journal_cursor_data_source.dart';
import 'package:archiveme_mobile/features/journal/providers/journal_dependency_providers.dart';
import 'package:archiveme_mobile/features/journal/providers/journal_entity_parse_pool.dart';
import 'package:archiveme_mobile/features/journal/providers/journal_entity_slices.dart';
import 'package:archiveme_mobile/features/journal/providers/journal_entry_map_notifier.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cursor-paginated journal timeline that hydrates [journalEntryMapProvider].
final class JournalTimelinePaginationNotifier
    extends AsyncNotifier<JournalTimelinePaginationState> {
  JournalCursorDataSource get _dataSource =>
      ref.read(journalCursorDataSourceProvider);

  JournalEntityParsePool get _parsePool =>
      ref.read(journalEntityParsePoolProvider);

  @override
  Future<JournalTimelinePaginationState> build() async {
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
      final rows = await _dataSource.fetchJournalEntryRows(
        after: current.cursor,
        limit: JournalCursorDataSource.pageSize,
      );
      final parsed = await _parsePool.parseJournalEntries(rows);
      ref.read(journalEntryMapProvider.notifier).mergeParsed(parsed);

      final nextIds = _orderedIdsFromRows(rows, parsed);
      final mergedIds = _mergeUniqueIds(current.orderedEntryIds, nextIds);
      final lastEntry = _lastEntryFromRows(rows, parsed);

      state = AsyncData(
        current.copyWith(
          orderedEntryIds: mergedIds,
          cursor: lastEntry == null
              ? current.cursor
              : JournalFeedCursor(
                  createdAt: lastEntry.createdAt,
                  id: lastEntry.id,
                ),
          hasMore: rows.length >= JournalCursorDataSource.pageSize,
          isLoadingMore: false,
        ),
      );
    } on Object {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  Future<JournalTimelinePaginationState> _loadFirstPage() async {
    final rows = await _dataSource.fetchJournalEntryRows(
      limit: JournalCursorDataSource.pageSize,
    );
    final parsed = await _parsePool.parseJournalEntries(rows);
    ref.read(journalEntryMapProvider.notifier).mergeParsed(parsed);

    final orderedIds = _orderedIdsFromRows(rows, parsed);
    final lastEntry = _lastEntryFromRows(rows, parsed);

    return JournalTimelinePaginationState(
      orderedEntryIds: orderedIds,
      cursor: lastEntry == null
          ? null
          : JournalFeedCursor(
              createdAt: lastEntry.createdAt,
              id: lastEntry.id,
            ),
      hasMore: rows.length >= JournalCursorDataSource.pageSize,
    );
  }

  List<String> _orderedIdsFromRows(
    List<Map<String, dynamic>> rows,
    Map<String, JournalEntry> parsed,
  ) {
    return rows
        .map((row) => row['id'] as String? ?? '')
        .where((id) => id.isNotEmpty && parsed.containsKey(id))
        .toList(growable: false);
  }

  JournalEntry? _lastEntryFromRows(
    List<Map<String, dynamic>> rows,
    Map<String, JournalEntry> parsed,
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

final journalTimelinePaginationProvider = AsyncNotifierProvider<
    JournalTimelinePaginationNotifier, JournalTimelinePaginationState>(
  JournalTimelinePaginationNotifier.new,
);
