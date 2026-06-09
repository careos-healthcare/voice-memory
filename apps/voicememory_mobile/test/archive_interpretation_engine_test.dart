import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_explanation_v2/archive_followup_question_engine.dart';
import 'package:voicememory_mobile/features/archive_explanation_v2/archive_interpretation_engine.dart';
import 'package:voicememory_mobile/features/archive_explanations/archive_explanation_engine.dart';
import 'package:voicememory_mobile/features/archive_explanations/explanation_models.dart';
import 'package:voicememory_mobile/features/discover/discover_cache.dart';
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
    transcript: '$line — padding for evidence threshold in transcript body.',
    durationSeconds: 30,
    reflection: Reflection(
      mood: '',
      emotionalIntensity: 4,
      recurringThemes: themes,
      exactLanguagePattern: line,
      concreteObservation: line,
      repeatedSignal: '',
    ),
  );
}

void main() {
  setUp(() => DiscoverYourselfCache.instance.invalidate());

  test('interpretation uses hedged language in what this might mean', () {
    final entries = List.generate(
      12,
      (i) => _entry(
        id: 'b$i',
        at: DateTime(2026, 1, 1).add(Duration(days: i * 3)),
        line: i.isEven
            ? 'I feel uncertain and unsure about my next step'
            : 'I need approval before I decide on things',
      ),
    );

    const explanationEngine = ArchiveExplanationEngine();
    final explanation = explanationEngine.buildExplanation(
      ref: ArchiveInsightRef.belief(),
      entries: entries,
    );
    expect(explanation, isNotNull);

    final interpretation = const ArchiveInterpretationEngine().build(
      ref: ArchiveInsightRef.belief(),
      explanation: explanation!,
      entries: entries,
    );

    expect(interpretation, isNotNull);
    final text = interpretation!.whatThisMightMean.toLowerCase();
    expect(text, isNot(contains('definitely')));
    expect(text, isNot(contains('proves')));
    expect(
      text.contains('may') || text.contains('might') || text.contains('appears'),
      isTrue,
    );
  });

  test('follow-up question is specific not generic', () {
    const engine = ArchiveFollowupQuestionEngine();
    final q = engine.generate(
      ref: ArchiveInsightRef.contradiction(
        entryIdA: 'a',
        entryIdB: 'b',
      ),
      explanation: ArchiveExplanation(
        insightId: 'c',
        kind: ArchiveInsightKind.contradiction,
        title: 'Tension',
        explanation: 'Two lines pull apart.',
        whySummary: 'Paired contrast.',
        supportingEvidence: const [],
        contradictingEvidence: const [],
        relatedThemes: const [],
        relatedBeliefs: const [],
        relatedBlindSpots: const [],
        relatedContradictions: const [],
        timeline: BeliefTimeline.empty,
        confidence: 60,
      ),
      entries: const [],
    );
    expect(q.toLowerCase(), isNot(contains('tell me more')));
    expect(q, contains('close to you'));
  });

  test('mind change lists stronger and weaker conditions', () {
    final entries = List.generate(
      20,
      (i) => _entry(
        id: 't$i',
        at: DateTime(2026, 2, 1).add(Duration(days: i)),
        line: 'Work stress and career pressure at the office reflection $i',
        themes: i % 3 == 0 ? const ['work'] : const ['career'],
      ),
    );

    final snapshot =
        const ArchiveExplanationEngine().discoverEngine.build(entries: entries);
    expect(snapshot.themes, isNotEmpty);
    final key = snapshot.themes.first.themeKey;

    final explanation = const ArchiveExplanationEngine().buildExplanation(
      ref: ArchiveInsightRef.theme(key),
      entries: entries,
    );
    expect(explanation, isNotNull);

    final interpretation = const ArchiveInterpretationEngine().build(
      ref: ArchiveInsightRef.theme(key),
      explanation: explanation!,
      entries: entries,
    );

    expect(interpretation!.mindChange.hasContent, isTrue);
    expect(interpretation.supportsSummary.bullets, isNotEmpty);
  });
}
