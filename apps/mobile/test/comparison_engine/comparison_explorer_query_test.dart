import 'package:archiveme_mobile/features/comparison_engine/domain/models/comparison_temporal_window.dart';
import 'package:archiveme_mobile/features/comparison_engine/domain/services/comparison_explorer_query.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({
  required String id,
  required DateTime createdAt,
  required String transcript,
}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt,
    transcript: transcript,
    durationSeconds: 30,
    reflection: Reflection(
      mood: '',
      emotionalIntensity: 0,
      recurringThemes: const [],
      exactLanguagePattern: '',
      concreteObservation: transcript,
      repeatedSignal: '',
    ),
  );
}

void main() {
  group('ComparisonExplorerQuery', () {
    final anchor = DateTime(2026, 8, 9, 12);

    test('filters moments to the selected temporal window', () {
      final entries = [
        _entry(
          id: 'old',
          createdAt: anchor.subtract(const Duration(days: 120)),
          transcript: 'said yes months ago',
        ),
        _entry(
          id: 'recent',
          createdAt: anchor.subtract(const Duration(days: 10)),
          transcript: 'said yes again recently',
        ),
        _entry(
          id: 'latest',
          createdAt: anchor.subtract(const Duration(days: 1)),
          transcript: 'said yes today',
        ),
      ];

      final snapshot = ComparisonExplorerQuery.fromJournalEntries(
        entries: entries,
        window: ComparisonTemporalWindow.quarter,
        now: anchor,
      );

      expect(snapshot.momentCount, 2);
      expect(snapshot.current?.id, 'latest');
      expect(snapshot.historical.single.id, 'recent');
      expect(snapshot.hasEnoughForComparison, isTrue);
    });

    test('ignores empty transcripts and reports insufficient history', () {
      final entries = [
        _entry(
          id: 'only',
          createdAt: anchor.subtract(const Duration(days: 2)),
          transcript: '   ',
        ),
      ];

      final snapshot = ComparisonExplorerQuery.fromJournalEntries(
        entries: entries,
        window: ComparisonTemporalWindow.recent,
        now: anchor,
      );

      expect(snapshot.momentCount, 0);
      expect(snapshot.hasEnoughForComparison, isFalse);
      expect(snapshot.current, isNull);
    });

    test('single moment in range lacks historical context', () {
      final entries = [
        _entry(
          id: 'solo',
          createdAt: anchor.subtract(const Duration(days: 3)),
          transcript: 'one saved thought',
        ),
      ];

      final snapshot = ComparisonExplorerQuery.fromJournalEntries(
        entries: entries,
        window: ComparisonTemporalWindow.recent,
        now: anchor,
      );

      expect(snapshot.momentCount, 1);
      expect(snapshot.hasEnoughForComparison, isFalse);
      expect(snapshot.hasHistoricalContext, isFalse);
      expect(snapshot.current?.id, 'solo');
    });

    test('all time includes the full chronological thread', () {
      final entries = [
        _entry(
          id: 'first',
          createdAt: DateTime(2024),
          transcript: 'first note',
        ),
        _entry(
          id: 'second',
          createdAt: DateTime(2025, 6),
          transcript: 'second note',
        ),
        _entry(
          id: 'third',
          createdAt: DateTime(2026, 7),
          transcript: 'third note',
        ),
      ];

      final snapshot = ComparisonExplorerQuery.fromJournalEntries(
        entries: entries,
        window: ComparisonTemporalWindow.allTime,
        now: anchor,
      );

      expect(snapshot.momentCount, 3);
      expect(snapshot.current?.id, 'third');
      expect(snapshot.historical.map((m) => m.id), ['first', 'second']);
    });
  });
}