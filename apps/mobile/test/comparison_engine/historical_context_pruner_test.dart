import 'package:archiveme_mobile/features/comparison_engine/domain/models/archive_moment_record.dart';
import 'package:archiveme_mobile/features/comparison_engine/domain/services/historical_context_pruner.dart';
import 'package:flutter_test/flutter_test.dart';

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
    test('returns input unchanged when within maxContextItems', () {
      final history = [
        _moment(id: '1', createdAt: DateTime.utc(2026, 6)),
        _moment(id: '2', createdAt: DateTime.utc(2026, 6, 2)),
      ];

      final pruned = pruneHistoricalContext(history);

      expect(pruned, history);
    });

    test('keeps freshest items and preserves chronological order', () {
      final history = [
        for (var day = 1; day <= 35; day++)
          _moment(id: 'm$day', createdAt: DateTime.utc(2026, 1, day)),
      ];

      final pruned = pruneHistoricalContext(history);

      expect(pruned.length, 30);
      expect(pruned.first.id, 'm6');
      expect(pruned.last.id, 'm35');
      for (var i = 1; i < pruned.length; i++) {
        expect(pruned[i].createdAt.isAfter(pruned[i - 1].createdAt), isTrue);
      }
    });
  });
}