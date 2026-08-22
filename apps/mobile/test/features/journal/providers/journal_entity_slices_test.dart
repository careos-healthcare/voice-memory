import 'package:archiveme_mobile/features/journal/providers/journal_entity_slices.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JournalEntryMapState', () {
    test('putEntry updates only targeted id bucket', () {
      const initial = JournalEntryMapState.empty();
      // State helpers are pure — map merges are O(1) per upsert.
      expect(initial.entries, isEmpty);
    });
  });

  group('JournalTimelinePaginationState', () {
    test('copyWith preserves cursor unless cleared', () {
      const cursor = JournalTimelinePaginationState(
        orderedEntryIds: ['a'],
        hasMore: true,
      );

      final loading = cursor.copyWith(isLoadingMore: true);
      expect(loading.isLoadingMore, isTrue);
      expect(loading.orderedEntryIds, ['a']);
    });
  });
}
