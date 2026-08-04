import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_narrative/archive_narrative_engine.dart';
import 'package:voicememory_mobile/features/archive_narrative/narrative_summary_models.dart';
import 'package:voicememory_mobile/features/belief_evolution/belief_evolution_models.dart';
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

List<JournalEntry> _approvalToConfidenceJournal() {
  return [
    ...List.generate(
      3,
      (i) => _entry(
        id: 'early$i',
        at: DateTime(2024, 6, i + 1),
        line: 'I need approval from others at work',
        themes: const ['approval'],
      ),
    ),
    ...List.generate(
      3,
      (i) => _entry(
        id: 'mid$i',
        at: DateTime(2025, 6, i + 1),
        line: 'Neutral filler reflection with enough transcript text here.',
      ),
    ),
    ...List.generate(
      4,
      (i) => _entry(
        id: 'late$i',
        at: DateTime(2026, 3, i + 1),
        line: 'I trust my judgment and feel confident at work',
        themes: const ['confidence'],
      ),
    ),
  ];
}

void main() {
  test('returns empty narrative below archive evidence threshold', () {
    final narrative = const ArchiveNarrativeEngine().build(
      entries: [
        _entry(
          id: '1',
          at: DateTime(2026, 1, 1),
          line: 'I need approval from others',
          themes: const ['approval'],
        ),
      ],
    );
    expect(narrative.hasNarrative, isFalse);
    expect(narrative.hasMinimumArchiveEvidence, isFalse);
  });

  test('builds evidence-backed story with approval to confidence shift', () {
    final narrative = const ArchiveNarrativeEngine().build(
      entries: _approvalToConfidenceJournal(),
    );

    expect(narrative.hasNarrative, isTrue);
    expect(narrative.summary.toLowerCase(), contains('approval'));
    expect(narrative.summary.toLowerCase(), contains('judgement'));
    expect(narrative.supportingThemes, contains('Approval'));
    expect(narrative.supportingThemes, contains('Confidence'));
    expect(narrative.supportingRecordingIds.length, greaterThanOrEqualTo(4));
    expect(narrative.supportingBeliefs, isNotEmpty);
  });

  test('mentions confidence growth when theme trends up', () {
    final narrative = const ArchiveNarrativeEngine().build(
      entries: [
        ...List.generate(
          5,
          (i) => _entry(
            id: 'c$i',
            at: DateTime(2025, 1, i + 1),
            line: 'I am growing in confidence about my decisions',
            themes: const ['confidence'],
          ),
        ),
      ],
    );

    expect(narrative.summary.toLowerCase(), contains('confidence'));
    expect(narrative.supportingRecordingIds, isNotEmpty);
  });

  test('includes belief evolution when timeline has shifts', () {
    final timeline = BeliefEvolutionTimeline(
      blocks: [
        BeliefEvolutionBlock(
          version: BeliefVersionRecord(
            id: 'v1',
            beliefText: 'I need approval from others',
            confidence: 60,
            recordedAt: DateTime.utc(2024, 1, 1).toIso8601String(),
            supportingEntryIds: const ['early0'],
          ),
          evidence: const [
            BeliefEvidenceLine(
              entryId: 'early0',
              quote: 'I need approval from others at work',
              dateLabel: 'Jan 2024',
            ),
          ],
        ),
        BeliefEvolutionBlock(
          version: BeliefVersionRecord(
            id: 'v2',
            beliefText: 'I trust my judgment at work',
            confidence: 72,
            recordedAt: DateTime.utc(2026, 1, 1).toIso8601String(),
            supportingEntryIds: const ['late0'],
          ),
          evidence: const [
            BeliefEvidenceLine(
              entryId: 'late0',
              quote: 'I trust my judgment and feel confident',
              dateLabel: 'Jan 2026',
            ),
          ],
        ),
      ],
      firstBelief: BeliefVersionRecord(
        id: 'v1',
        beliefText: 'I need approval from others',
        confidence: 60,
        recordedAt: DateTime.utc(2024, 1, 1).toIso8601String(),
        supportingEntryIds: const ['early0'],
      ),
      currentBelief: BeliefVersionRecord(
        id: 'v2',
        beliefText: 'I trust my judgment at work',
        confidence: 72,
        recordedAt: DateTime.utc(2026, 1, 1).toIso8601String(),
        supportingEntryIds: const ['late0'],
      ),
    );

    final narrative = const ArchiveNarrativeEngine().build(
      entries: _approvalToConfidenceJournal(),
      beliefEvolution: timeline,
    );

    expect(narrative.summary.toLowerCase(), contains('belief evolution'));
    expect(narrative.supportingRecordingIds, contains('early0'));
    expect(narrative.supportingRecordingIds, contains('late0'));
  });

  test('NarrativeSummary round-trips JSON', () {
    final narrative = const ArchiveNarrativeEngine().build(
      entries: _approvalToConfidenceJournal(),
    );
    final parsed = NarrativeSummary.fromJson(narrative.toJson());
    expect(parsed.summary, narrative.summary);
    expect(parsed.supportingRecordingIds, narrative.supportingRecordingIds);
  });
}
