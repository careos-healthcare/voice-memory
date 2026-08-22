import 'package:archiveme_mobile/features/first_session/first_session_pattern_category.dart';
import 'package:archiveme_mobile/features/first_session/first_session_pattern_engine.dart';
import 'package:archiveme_mobile/features/first_session/first_session_pattern_model.dart';
import 'package:archiveme_mobile/features/first_session/pattern_correction_learning_coordinator.dart';
import 'package:archiveme_mobile/features/first_session/pattern_correction_learning_store.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_pcl_coord_journal_$stamp.json',
    prefsPath: '/tmp/vm_pcl_coord_prefs_$stamp.json',
  );
}

FirstSessionPattern _pattern({
  required String title,
  required String categoryId,
}) {
  return FirstSessionPattern(
    id: 'p1',
    createdAt: DateTime(2026, 5, 25),
    title: title,
    whyNoticed: 'why',
    watchForText: 'watch for tomorrow',
    chips: const ['chip'],
    confidenceLabel: FirstSessionConfidenceLabel.early,
    sourceTextPreview: 'preview',
    matchReason: 'reason',
    confidenceScore: 0.5,
    categoryId: categoryId,
  );
}

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
  test('recordFirstSessionCorrection persists learning', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);

    final learning =
        await PatternCorrectionLearningCoordinator.recordFirstSessionCorrection(
          originalPattern: _pattern(
            title: 'Taking responsibility before asking for help',
            categoryId: 'responsibility',
          ),
          correctedPattern: _pattern(
            title: 'The same worry returning',
            categoryId: 'worry',
          ),
          reflectionText:
              'I keep saying yes and feel guilty but the same worry came back',
        );

    expect(learning.correctedCategoryId, 'worry');
    expect(learning.reflectionSnippet.length, lessThanOrEqualTo(160));

    final store = PatternCorrectionLearningStore(AppServices.instance.prefs);
    expect(await store.readAll(), hasLength(1));
  });

  test(
    'preferredCategoryBoosts includes recently corrected category',
    () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);

      await PatternCorrectionLearningCoordinator.recordFirstSessionCorrection(
        originalPattern: _pattern(
          title: 'Taking responsibility before asking for help',
          categoryId: 'responsibility',
        ),
        correctedPattern: _pattern(
          title: 'The same worry returning',
          categoryId: 'worry',
        ),
        reflectionText: 'worried and guilty',
      );

      final boosts =
          await PatternCorrectionLearningCoordinator.preferredCategoryBoosts();
      expect(
        boosts[FirstSessionPatternCategory.worry],
        PatternCorrectionLearningCoordinator.categoryBoostAmount,
      );
    },
  );

  test('recentCorrectionForReflection matches snippet overlap', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);

    await PatternCorrectionLearningCoordinator.recordFirstSessionCorrection(
      originalPattern: _pattern(
        title: 'Something worth watching',
        categoryId: 'fallback',
      ),
      correctedPattern: _pattern(
        title: 'Running on empty',
        categoryId: 'burnout',
      ),
      reflectionText: 'Exhausted after a long week at work',
    );

    final recent =
        await PatternCorrectionLearningCoordinator.recentCorrectionForReflection(
          'Exhausted after a long week at work',
        );
    expect(recent?.correctedCategoryId, 'burnout');
  });

  test('boost helps when categories are close', () async {
    const engine = FirstSessionPatternEngine();
    const text =
        'I feel guilty about pressure and the same worry came back tonight';

    final without = engine.build(_entry(text));
    final withBoost = engine.build(
      _entry(text),
      preferredCategoryBoosts: {
        FirstSessionPatternCategory.worry:
            PatternCorrectionLearningCoordinator.categoryBoostAmount,
      },
    );

    expect(without.categoryId, isNot('worry'));
    expect(withBoost.categoryId, 'worry');
  });

  test('boost does not override strong responsibility match', () async {
    const engine = FirstSessionPatternEngine();
    const text =
        'I keep saying yes too fast and feel guilty about pressure before asking for help';

    final pattern = engine.build(
      _entry(text),
      preferredCategoryBoosts: {
        FirstSessionPatternCategory.worry:
            PatternCorrectionLearningCoordinator.categoryBoostAmount,
      },
    );

    expect(pattern.categoryId, 'responsibility');
  });

  test('boost does not force pattern on vague text', () async {
    const engine = FirstSessionPatternEngine();
    final pattern = engine.build(
      _entry('rough day'),
      preferredCategoryBoosts: {
        FirstSessionPatternCategory.worry:
            PatternCorrectionLearningCoordinator.categoryBoostAmount,
      },
    );

    expect(pattern.categoryId, 'fallback');
  });

  test('developer summary loads corrections', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);

    await PatternCorrectionLearningCoordinator.recordFirstSessionCorrection(
      originalPattern: _pattern(
        title: 'Taking responsibility before asking for help',
        categoryId: 'responsibility',
      ),
      correctedPattern: _pattern(
        title: 'The same worry returning',
        categoryId: 'worry',
      ),
      reflectionText: 'worry tonight',
    );

    final summary =
        await PatternCorrectionLearningCoordinator.buildDeveloperSummary();
    expect(summary.totalLearned, 1);
    expect(summary.recent, hasLength(1));
    expect(summary.mostCorrectedCategoryId, 'worry');
  });
}