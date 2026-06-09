import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/belief_shift/belief_shift_engine.dart';
import 'package:voicememory_mobile/features/belief_shift/belief_shift_models.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

JournalEntry _entry({
  required String id,
  required DateTime at,
  required String line,
  List<String> themes = const [],
}) {
  return JournalEntry(
    id: id,
    createdAt: at,
    transcript: '$line — additional transcript padding for evidence threshold.',
    durationSeconds: 30,
    reflection: Reflection(
      mood: '',
      emotionalIntensity: 0,
      recurringThemes: themes,
      exactLanguagePattern: line,
      concreteObservation: line,
      repeatedSignal: '',
    ),
  );
}

List<JournalEntry> _networkingArc() {
  return [
    _entry(
      id: 'old',
      at: DateTime(2025, 1, 10),
      line: 'I hate networking events',
      themes: const ['networking'],
    ),
    _entry(
      id: 'mid',
      at: DateTime(2025, 8, 1),
      line: 'Networking is uncomfortable but I am trying',
      themes: const ['networking'],
    ),
    _entry(
      id: 'new',
      at: DateTime(2026, 2, 1),
      line: 'Networking changed my career',
      themes: const ['networking', 'career'],
    ),
    ...List.generate(
      3,
      (i) => _entry(
        id: 'pad$i',
        at: DateTime(2025, 6, i + 1),
        line: 'Neutral filler reflection with enough transcript text.',
      ),
    ),
  ];
}

void main() {
  test('detects gradual networking arc with evidence chain', () {
    final result = const BeliefShiftEngine().detect(entries: _networkingArc());

    expect(result.hasMajorShifts, isTrue);
    final report = result.reports.first;
    expect(report.originalBelief.toLowerCase(), contains('hate'));
    expect(report.newBelief.toLowerCase(), contains('networking'));
    expect(report.confidence, greaterThanOrEqualTo(BeliefShiftEngine.minConfidence));
    expect(report.evidenceIds.length, greaterThanOrEqualTo(2));
    expect(report.evolutionTimeline.length, greaterThanOrEqualTo(2));
    expect(
      report.evolutionTimeline.any((s) => s.beliefText.toLowerCase().contains('uncomfortable')),
      isTrue,
    );
  });

  test('returns empty below archive evidence threshold', () {
    final result = const BeliefShiftEngine().detect(
      entries: [
        _entry(
          id: 'only',
          at: DateTime(2026, 1, 1),
          line: 'I hate networking events',
        ),
      ],
    );
    expect(result.reports, isEmpty);
  });

  test('BeliefShiftReport round-trips JSON', () {
    const report = BeliefShiftReport(
      id: 'shift-1',
      originalBelief: 'I hate networking',
      newBelief: 'Networking changed my career',
      confidence: 78,
      evolutionTimeline: [
        BeliefShiftTimelineStep(
          beliefText: 'I hate networking',
          entryId: 'a',
        ),
        BeliefShiftTimelineStep(
          beliefText: 'Networking is uncomfortable',
          entryId: 'b',
        ),
        BeliefShiftTimelineStep(
          beliefText: 'Networking changed my career',
          entryId: 'c',
        ),
      ],
      evidenceIds: ['a', 'b', 'c'],
      kind: BeliefShiftKind.gradualBeliefChange,
      sharedTopics: ['networking'],
    );
    final parsed = BeliefShiftReport.fromJson(report.toJson());
    expect(parsed?.evidenceIds, ['a', 'b', 'c']);
    expect(parsed?.evolutionTimeline.length, 3);
  });
}
