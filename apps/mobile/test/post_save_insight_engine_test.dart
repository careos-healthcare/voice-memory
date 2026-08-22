import 'package:archiveme_mobile/features/first_session/first_session_pattern_category.dart';
import 'package:archiveme_mobile/features/first_session/first_session_pattern_model.dart';
import 'package:archiveme_mobile/features/post_save_insight/post_save_insight_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

FirstSessionPattern _pattern() {
  return FirstSessionPattern(
    id: 'test',
    createdAt: DateTime(2026, 6),
    title: 'Taking responsibility before asking for help',
    whyNoticed: 'You mentioned pressure or responsibility.',
    watchForText: 'whether you take responsibility before asking for help',
    chips: const ['saying yes fast'],
    confidenceLabel: FirstSessionConfidenceLabel.early,
    sourceTextPreview: 'I said yes again.',
    matchReason: 'Your words pointed toward pressure in this moment.',
    confidenceScore: 0.5,
    categoryId: 'responsibility',
    category: FirstSessionPatternCategory.responsibility,
  );
}

JournalEntry _entry(String transcript) {
  return JournalEntry(
    id: '1',
    createdAt: DateTime(2026, 6),
    transcript: transcript,
    durationSeconds: 30,
    reflection: const Reflection(
      mood: 'neutral',
      emotionalIntensity: 2,
      recurringThemes: [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
  );
}

void main() {
  const engine = PostSaveInsightEngine();

  test('uses interpretation reads when entry provided', () {
    final bundle = engine.build(
      _pattern(),
      entry: _entry(
        'I said yes to something I did not have time for, and now I feel pressure.',
      ),
    );

    expect(bundle.signals, isNotEmpty);
    expect(
      bundle.signals.first.title.toLowerCase(),
      anyOf(contains('saying yes'), contains('capacity')),
    );
    expect(bundle.signals.first.evidenceUsed, isNotNull);
    expect(bundle.signals.first.readId, isNotNull);
  });

  test('legacy build still works without entry', () {
    final bundle = engine.build(_pattern());
    expect(bundle.signals.length, greaterThanOrEqualTo(1));
  });
}