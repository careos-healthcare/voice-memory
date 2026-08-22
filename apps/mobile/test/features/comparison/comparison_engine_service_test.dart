import 'package:archiveme_mobile/features/belief_changes/belief_evolution_models.dart';
import 'package:archiveme_mobile/features/comparison/comparison_engine_service.dart';
import 'package:archiveme_mobile/features/comparison/comparison_models.dart';
import 'package:archiveme_mobile/features/fact_ledger/archive_fact.dart';
import 'package:archiveme_mobile/features/pattern_match_quality/pattern_match_quality_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({
  required String id,
  required DateTime createdAt,
  required String transcript,
  List<String> themes = const ['work'],
  String mood = 'tense',
}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt,
    transcript: transcript,
    durationSeconds: 30,
    reflection: Reflection(
      mood: mood,
      emotionalIntensity: 2,
      recurringThemes: themes,
      exactLanguagePattern: transcript,
      concreteObservation: transcript,
      repeatedSignal: '',
    ),
  );
}

ArchiveFact _fact({
  required String id,
  required String entryId,
  required DateTime createdAt,
  required String label,
  required String value,
}) {
  return ArchiveFact(
    id: id,
    sourceEntryId: entryId,
    label: label,
    value: value,
    note: '',
    createdAt: createdAt,
    updatedAt: createdAt,
    factType: 'detail',
  );
}

void main() {
  group('ComparisonEngineService', () {
    final anchor = DateTime.utc(2026, 8, 10, 12);

    test('maps 30-day vs today windows with ledger citations', () {
      final entries = [
        _entry(
          id: 'then-1',
          createdAt: anchor.subtract(const Duration(days: 45)),
          transcript: 'I have to prove myself every week',
        ),
        _entry(
          id: 'now-1',
          createdAt: anchor.subtract(const Duration(days: 10)),
          transcript: 'I can stop early without apologizing',
          themes: const ['rest'],
          mood: 'calm',
        ),
      ];

      final facts = [
        _fact(
          id: 'fact-1',
          entryId: 'then-1',
          createdAt: entries.first.createdAt,
          label: 'Pressure',
          value: 'Weekly proving cycle',
        ),
      ];

      final evolution = BeliefEvolutionState(
        versions: [
          BeliefVersionRecord(
            id: 'v1',
            beliefText: 'I have to prove myself every week',
            confidence: 55,
            recordedAt: entries.first.createdAt.toUtc().toIso8601String(),
            supportingEntryIds: ['then-1'],
          ),
          BeliefVersionRecord(
            id: 'v2',
            beliefText: 'I can stop early without apologizing',
            confidence: 72,
            recordedAt: entries.last.createdAt.toUtc().toIso8601String(),
            supportingEntryIds: ['now-1'],
          ),
        ],
      );

      final result = ComparisonEngineService.build(
        range: ComparisonTemporalRange.thirtyDaysVsToday,
        entries: entries,
        facts: facts,
        beliefEvolution: evolution,
        now: anchor,
      );

      expect(result.hasEnoughEvidence, isTrue);
      expect(result.then.entryCount, 1);
      expect(result.now.entryCount, 1);
      expect(result.then.citations.single.entryId, 'then-1');
      expect(result.now.citations.single.entryId, 'now-1');
      expect(result.then.factCount, 1);
      expect(result.shifts, isNotEmpty);
      expect(result.shifts.first.kind, ComparisonShiftKind.emerged);
      expect(result.shifts.first.deltaBadgeLabel, contains('over'));
    });

    test('detects dropped assumptions across six-month windows', () {
      final entries = [
        _entry(
          id: 'old-work',
          createdAt: anchor.subtract(const Duration(days: 300)),
          transcript: 'Work is consuming everything',
        ),
        _entry(
          id: 'mid-work',
          createdAt: anchor.subtract(const Duration(days: 240)),
          transcript: 'Still saying yes to everything at work',
        ),
        _entry(
          id: 'recent-rest',
          createdAt: anchor.subtract(const Duration(days: 20)),
          transcript: 'Protected a quiet evening',
          themes: const ['rest'],
        ),
      ];

      final result = ComparisonEngineService.build(
        range: ComparisonTemporalRange.sixMonthsVsToday,
        entries: entries,
        facts: const [],
        beliefEvolution: BeliefEvolutionState.empty(),
        now: anchor,
      );

      expect(result.droppedAssumptions, contains('work'));
      expect(
        result.shifts.any((shift) => shift.kind == ComparisonShiftKind.dropped),
        isTrue,
      );
    });

    test('splits multi-year archive into earlier and recent halves', () {
      final entries = [
        _entry(
          id: 'y2024',
          createdAt: DateTime.utc(2024, 3),
          transcript: 'Starting a new role and overworking',
        ),
        _entry(
          id: 'y2025',
          createdAt: DateTime.utc(2025, 3),
          transcript: 'Still proving myself constantly',
        ),
        _entry(
          id: 'y2026',
          createdAt: DateTime.utc(2026, 3),
          transcript: 'Choosing rest without guilt',
        ),
      ];

      final result = ComparisonEngineService.build(
        range: ComparisonTemporalRange.multiYearShift,
        entries: entries,
        facts: const [],
        beliefEvolution: BeliefEvolutionState.empty(),
        now: anchor,
      );

      expect(result.then.entryCount, 1);
      expect(result.now.entryCount, 2);
      expect(result.then.citations.single.entryId, 'y2024');
      expect(result.now.citations.map((c) => c.entryId), ['y2025', 'y2026']);
    });

    test('maps confidence percent to PatternMatchConfidenceBand on periods', () {
      final entries = [
        _entry(
          id: 'baseline',
          createdAt: anchor.subtract(const Duration(days: 400)),
          transcript: 'Baseline belief with enough usable transcript length',
        ),
        _entry(
          id: 'baseline-2',
          createdAt: anchor.subtract(const Duration(days: 380)),
          transcript: 'Baseline again with enough usable transcript length',
        ),
        _entry(
          id: 'current',
          createdAt: anchor.subtract(const Duration(days: 5)),
          transcript: 'Current belief with enough usable transcript length',
        ),
        _entry(
          id: 'current-2',
          createdAt: anchor.subtract(const Duration(days: 3)),
          transcript: 'Current again with enough usable transcript length',
        ),
      ];

      final result = ComparisonEngineService.build(
        range: ComparisonTemporalRange.oneYearVsToday,
        entries: entries,
        facts: const [],
        beliefEvolution: BeliefEvolutionState.empty(),
        now: anchor,
      );

      expect(result.then.confidenceBand, isNot(PatternMatchConfidenceBand.weak));
      expect(result.now.confidenceBand, isNot(PatternMatchConfidenceBand.weak));
    });
  });
}