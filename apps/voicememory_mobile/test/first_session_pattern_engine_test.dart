import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/first_session/first_session_pattern_category.dart';
import 'package:voicememory_mobile/features/first_session/first_session_pattern_engine.dart';
import 'package:voicememory_mobile/features/first_session/first_pattern_quality_titles.dart';
import 'package:voicememory_mobile/features/first_session/pattern_correction_learning_coordinator.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

JournalEntry _entry(String text) {
  return JournalEntry(
    id: 'e1',
    createdAt: DateTime(2026, 5, 25),
    transcript: text,
    durationSeconds: 30,
    reflection: Reflection(
      mood: '',
      emotionalIntensity: 3,
      recurringThemes: const [],
      exactLanguagePattern: text,
      concreteObservation: text,
      repeatedSignal: text,
    ),
  );
}

void main() {
  const engine = FirstSessionPatternEngine();

  test('responsibility text wins over generic fallback', () {
    final pattern = engine.build(
      _entry(
        'I keep saying yes too fast and feel guilty about pressure before asking for help',
      ),
    );
    expect(pattern.categoryId, 'responsibility');
    expect(pattern.title, contains('Taking responsibility'));
    expect(pattern.confidenceScore, lessThanOrEqualTo(0.65));
  });

  test('worry text wins for rumination language', () {
    final pattern = engine.build(
      _entry('The same worry came back tonight and I could not switch off'),
    );
    expect(pattern.categoryId, 'worry');
    expect(pattern.title, contains('worry'));
  });

  test('not worried does not produce worry', () {
    final pattern = engine.build(
      _entry('I was not worried today, just a normal afternoon'),
    );
    expect(pattern.title, isNot(FirstPatternQualityTitles.worry));
    expect(pattern.negativeMatchPenaltyApplied, isTrue);
  });

  test('finally asked for help does not produce responsibility without guilt', () {
    final pattern = engine.build(
      _entry('I finally asked for help and it felt okay'),
    );
    expect(pattern.title, isNot(FirstPatternQualityTitles.responsibility));
  });

  test('tired alone does not produce burnout', () {
    final pattern = engine.build(_entry('I was tired'));
    expect(pattern.title, isNot(FirstPatternQualityTitles.burnout));
    expect(
      pattern.title,
      anyOf(
        FirstPatternQualityTitles.fallback,
        FirstPatternQualityTitles.lighter,
      ),
    );
  });

  test('friend alone does not produce relationship tension', () {
    final pattern = engine.build(_entry('I messaged my friend'));
    expect(pattern.title, isNot(FirstPatternQualityTitles.relationship));
  });

  test('positive calm reflection produces lighter fallback', () {
    final pattern = engine.build(
      _entry('Had coffee and walked outside, felt calm and peaceful'),
    );
    expect(pattern.title, FirstPatternQualityTitles.lighter);
    expect(pattern.watchForText, contains('lighter'));
  });

  test('multi-topic ambiguity creates alternatives', () {
    final pattern = engine.build(
      _entry(
        'I feel anxious and exhausted, worried, cannot switch off, drained with no energy',
      ),
    );
    expect(pattern.alternativePatterns, isNotEmpty);
    expect(pattern.userCanCorrect, isTrue);
    expect(pattern.isAmbiguousMatch, isTrue);
    expect(pattern.matchReason, contains('few things'));
  });

  test('low score produces fallback with low confidence', () {
    final pattern = engine.build(
      _entry('A quiet afternoon with coffee and sunshine'),
    );
    expect(pattern.title, FirstPatternQualityTitles.fallback);
    expect(pattern.confidenceScore, lessThan(0.45));
  });

  test('confidence stays below overconfident threshold', () {
    final pattern = engine.build(
      _entry('I keep saying yes and feel guilty about pressure'),
    );
    expect(pattern.confidenceScore, lessThanOrEqualTo(0.65));
  });

  test('exhausted with context produces burnout', () {
    final pattern = engine.build(
      _entry('I am exhausted and drained with no energy, feeling heavy'),
    );
    expect(pattern.categoryId, 'burnout');
  });

  test('preferred category boost does not override decisive match', () {
    final pattern = engine.build(
      _entry(
        'I keep saying yes too fast and feel guilty about pressure before asking for help',
      ),
      preferredCategoryBoosts: {
        FirstSessionPatternCategory.worry:
            PatternCorrectionLearningCoordinator.categoryBoostAmount,
      },
    );
    expect(pattern.categoryId, 'responsibility');
  });

  test('preferred category boost does not force vague text into a pattern', () {
    final pattern = engine.build(
      _entry('felt off'),
      preferredCategoryBoosts: {
        FirstSessionPatternCategory.worry:
            PatternCorrectionLearningCoordinator.categoryBoostAmount,
      },
    );
    expect(pattern.categoryId, 'fallback');
  });
}
