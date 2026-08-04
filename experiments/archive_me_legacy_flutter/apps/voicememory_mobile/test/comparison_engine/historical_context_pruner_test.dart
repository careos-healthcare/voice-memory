import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/comparison_engine/domain/models/archive_moment_record.dart';
import 'package:voicememory_mobile/features/comparison_engine/domain/services/historical_context_pruner.dart';

ArchiveMomentRecord _moment({
  required String id,
  required DateTime createdAt,
}) => ArchiveMomentRecord(
  id: id,
  createdAt: createdAt,
  savedWords: 'words for $id',
);

void main() {
  group('pruneHistoricalContext', () {
    List<ArchiveMomentRecord> historyOf(int count) {
      final start = DateTime.utc(2026);
      return [
        for (var index = 0; index < count; index++)
          _moment(
            id: 'm$index',
            createdAt: start.add(Duration(days: index)),
          ),
      ];
    }

    test('returns an empty list for empty history', () {
      final history = <ArchiveMomentRecord>[];

      final pruned = pruneHistoricalContext(history);

      expect(pruned, isEmpty);
      expect(history, isEmpty);
    });

    test('returns one item unchanged', () {
      final history = historyOf(1);

      final pruned = pruneHistoricalContext(history);

      expect(pruned, history);
      expect(pruned.single, same(history.single));
    });

    test('returns exactly 30 items unchanged', () {
      final history = historyOf(30);

      final pruned = pruneHistoricalContext(history);

      expect(pruned, history);
      expect(identical(pruned, history), isFalse);
      pruned.clear();
      expect(history, hasLength(30));
    });

    test('31 items drops only the oldest item', () {
      final history = historyOf(31);

      final pruned = pruneHistoricalContext(history);

      expect(pruned.length, 30);
      expect(pruned.first.id, 'm1');
      expect(pruned.last.id, 'm30');
      expect(pruned, isNot(contains(same(history.first))));
    });

    test('100 items keeps only the newest 30 without duplicates', () {
      final history = historyOf(100);

      final pruned = pruneHistoricalContext(history);

      expect(pruned, hasLength(30));
      expect(pruned.first.id, 'm70');
      expect(pruned.last.id, 'm99');
      expect(pruned.map((moment) => moment.id).toSet(), hasLength(30));
    });

    test('sorts unordered input without mutating it', () {
      final history = [
        _moment(id: 'newest', createdAt: DateTime.utc(2026, 6, 3)),
        _moment(id: 'oldest', createdAt: DateTime.utc(2026, 6, 1)),
        _moment(id: 'middle', createdAt: DateTime.utc(2026, 6, 2)),
      ];

      final pruned = pruneHistoricalContext(history, maxContextItems: 2);

      expect(pruned.map((moment) => moment.id), ['middle', 'newest']);
      expect(history.map((moment) => moment.id), [
        'newest',
        'oldest',
        'middle',
      ]);
    });

    test('restores chronological order after selecting newest items', () {
      final history = historyOf(100).reversed.toList();

      final pruned = pruneHistoricalContext(history);

      for (var index = 1; index < pruned.length; index++) {
        expect(
          pruned[index].createdAt.isAfter(pruned[index - 1].createdAt),
          isTrue,
        );
      }
    });

    test('preserves source order for equal timestamps', () {
      final timestamp = DateTime.utc(2026, 6, 1);
      final history = [
        _moment(id: 'first', createdAt: timestamp),
        _moment(id: 'second', createdAt: timestamp),
        _moment(id: 'third', createdAt: timestamp),
      ];

      final pruned = pruneHistoricalContext(history, maxContextItems: 2);

      expect(pruned.map((moment) => moment.id), ['second', 'third']);
    });

    test('is null-safe by construction', () {
      final List<ArchiveMomentRecord> history = historyOf(31);

      final List<ArchiveMomentRecord> pruned = pruneHistoricalContext(history);

      expect(pruned, everyElement(isA<ArchiveMomentRecord>()));
    });

    test('returns an empty list when maxContextItems is zero', () {
      final history = [_moment(id: '1', createdAt: DateTime.utc(2026, 6, 1))];

      expect(pruneHistoricalContext(history, maxContextItems: 0), isEmpty);
      expect(history, hasLength(1));
    });

    test('rejects a negative maxContextItems', () {
      expect(
        () => pruneHistoricalContext(
          const <ArchiveMomentRecord>[],
          maxContextItems: -1,
        ),
        throwsRangeError,
      );
    });
  });
}
