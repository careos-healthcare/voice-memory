import 'package:archiveme_mobile/features/archive_explanations/archive_explanation_engine.dart';
import 'package:archiveme_mobile/features/archive_explanations/belief_timeline_engine.dart';
import 'package:archiveme_mobile/features/archive_explanations/cross_reference_engine.dart';
import 'package:archiveme_mobile/features/archive_explanations/explanation_models.dart';
import 'package:archiveme_mobile/features/discover/discover_cache.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

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
      emotionalIntensity: 0,
      recurringThemes: themes,
      exactLanguagePattern: line,
      concreteObservation: line,
      repeatedSignal: '',
    ),
  );
}

void main() {
  setUp(() => DiscoverYourselfCache.instance.invalidate());

  test('belief explanation includes evidence and timeline', () {
    final entries = List.generate(
      12,
      (i) => _entry(
        id: 'b$i',
        at: DateTime(2026).add(Duration(days: i * 3)),
        line: i.isEven
            ? 'I need approval before I decide on things'
            : 'I hope they think I did a good job today',
        themes: const ['confidence'],
      ),
    );

    const engine = ArchiveExplanationEngine();
    final explanation = engine.buildExplanation(
      ref: ArchiveInsightRef.belief(),
      entries: entries,
    );

    expect(explanation, isNotNull);
    expect(explanation!.supportingEvidence, isNotEmpty);
    expect(explanation.confidence, greaterThan(0));
    expect(explanation.timeline.points, isNotEmpty);
  });

  test('theme explanation links related cross-references', () {
    final entries = List.generate(
      20,
      (i) => _entry(
        id: 't$i',
        at: DateTime(2026, 2).add(Duration(days: i)),
        line: 'Achievement and comparison at work reflection $i',
        themes: i % 3 == 0 ? const ['achievement'] : const ['career'],
      ),
    );

    const engine = ArchiveExplanationEngine();
    final snapshot = engine.discoverEngine.build(entries: entries);
    expect(snapshot.themes, isNotEmpty);

    final key = snapshot.themes.first.themeKey;
    final explanation = engine.buildExplanation(
      ref: ArchiveInsightRef.theme(key),
      entries: entries,
    );

    expect(explanation, isNotNull);
    expect(explanation!.supportingEvidence, isNotEmpty);
  });

  test('contradiction explanation resolves entry pair', () {
    final entries = [
      _entry(
        id: 'a1',
        at: DateTime(2026, 3),
        line: 'I am completely independent and need no one',
      ),
      _entry(
        id: 'b1',
        at: DateTime(2026, 3, 5),
        line: 'I keep seeking reassurance from everyone around me',
      ),
      ...List.generate(
        8,
        (i) => _entry(
          id: 'pad$i',
          at: DateTime(2026, 2, i + 1),
          line: 'Neutral filler reflection $i',
        ),
      ),
    ];

    const engine = ArchiveExplanationEngine();
    final explanation = engine.buildExplanation(
      ref: ArchiveInsightRef.contradiction(entryIdA: 'a1', entryIdB: 'b1'),
      entries: entries,
    );

    expect(explanation, isNotNull);
    expect(
      explanation!.supportingEvidence.map((e) => e.entryId),
      containsAll(['a1', 'b1']),
    );
  });

  test('belief timeline engine tracks monthly strength', () {
    final entries = List.generate(
      15,
      (i) => _entry(
        id: 'tl$i',
        at: DateTime(2026).add(Duration(days: i * 5)),
        line: 'External validation drives my self-worth today',
      ),
    );

    final timeline = const BeliefTimelineEngine().build(
      entries: entries,
      beliefText: 'external validation',
    );

    expect(timeline.points.length, greaterThanOrEqualTo(1));
    expect(timeline.currentPercent, greaterThanOrEqualTo(0));
    expect(timeline.trend, isNot(BeliefTimelineTrend.unknown));
  });

  test('cross reference engine scores themes and blind spots', () {
    final entries = List.generate(
      25,
      (i) => _entry(
        id: 'cr$i',
        at: DateTime(2026).add(Duration(days: i)),
        line: 'Achievement comparison productivity reflection $i',
        themes: const ['achievement', 'comparison'],
      ),
    );

    final cross = const CrossReferenceEngine().build(
      entries: entries,
      focusBelief: 'need to prove myself',
      focusThemeKeys: const ['achievement'],
    );

    expect(cross.relatedThemes, isNotEmpty);
  });

  test('unexpected insights require minimum evidence', () {
    const engine = ArchiveExplanationEngine();
    expect(engine.buildUnexpectedInsights([]), isEmpty);

    final few = List.generate(
      3,
      (i) => _entry(id: 'f$i', at: DateTime(2026, 1, i + 1), line: 'short'),
    );
    expect(engine.buildUnexpectedInsights(few), isEmpty);
  });

  test('relationship vs work surprise when patterns match', () {
    final entries = <JournalEntry>[
      ...List.generate(
        5,
        (i) => _entry(
          id: 'rel$i',
          at: DateTime(2026, 4, i + 1),
          line: 'My relationship with my partner feels difficult today',
        ),
      ),
      ...List.generate(
        3,
        (i) => _entry(
          id: 'work$i',
          at: DateTime(2026, 4, 10 + i),
          line: 'Work stress and worry about my job performance',
        ),
      ),
      ...List.generate(
        3,
        (i) => _entry(
          id: 'pad$i',
          at: DateTime(2026, 3, i + 1),
          line: 'General reflection padding $i',
        ),
      ),
    ];

    final surprises = const ArchiveExplanationEngine().buildUnexpectedInsights(
      entries,
    );
    expect(surprises, isNotEmpty);
    expect(surprises.first.evidenceEntryIds, isNotEmpty);
  });

  test('challenge insights surface attention vs recognition', () {
    final entries = <JournalEntry>[
      _entry(
        id: 'c1',
        at: DateTime(2026, 5),
        line: 'I hate attention and dislike the spotlight on me',
      ),
      _entry(
        id: 'c2',
        at: DateTime(2026, 5, 2),
        line: 'I want recognition and to feel appreciated by others',
      ),
      _entry(
        id: 'c3',
        at: DateTime(2026, 5, 3),
        line: 'I want credit when my work is noticed by the team',
      ),
      ...List.generate(
        6,
        (i) => _entry(
          id: 'cpad$i',
          at: DateTime(2026, 4, i + 1),
          line: 'Filler reflection for threshold $i',
        ),
      ),
    ];

    final challenges = const ArchiveExplanationEngine().buildChallengeInsights(
      entries,
    );
    expect(challenges, isNotEmpty);
    expect(challenges.first.evidenceEntryIds.length, greaterThanOrEqualTo(1));
  });

  test('noticed feed caps at three items', () {
    final entries = List.generate(
      25,
      (i) => _entry(
        id: 'n$i',
        at: DateTime(2026).add(Duration(days: i)),
        line: 'Achievement comparison confidence reflection $i',
        themes: const ['achievement'],
      ),
    );

    final feed = const ArchiveExplanationEngine().buildNoticedFeed(
      entries: entries,
    );
    expect(feed.length, lessThanOrEqualTo(3));
  });

  test('parseRouteId round-trips insight refs', () {
    final ref = ArchiveInsightRef.contradiction(entryIdA: 'e1', entryIdB: 'e2');
    final parsed = ArchiveInsightRef.parseRouteId(ref.id);
    expect(parsed?.entryIdA, 'e1');
    expect(parsed?.entryIdB, 'e2');
  });
}