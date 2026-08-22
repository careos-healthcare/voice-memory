import 'package:archiveme_mobile/features/first_session/first_session_pattern_category.dart';
import 'package:archiveme_mobile/features/first_session/first_session_pattern_model.dart';
import 'package:archiveme_mobile/features/post_save_insight/insight_strength_engine.dart';
import 'package:archiveme_mobile/features/post_save_insight/insight_strength_model.dart';
import 'package:archiveme_mobile/features/post_save_insight/post_save_insight_engine.dart';
import 'package:flutter_test/flutter_test.dart';

FirstSessionPattern _pattern({
  List<String> chips = const [],
  double confidenceScore = 0.3,
}) {
  return FirstSessionPattern(
    id: 'test',
    createdAt: DateTime(2026, 6),
    title: 'Carrying too much responsibility',
    whyNoticed: 'You mentioned pressure or responsibility.',
    watchForText: 'whether you take responsibility before asking for help',
    chips: chips,
    confidenceLabel: FirstSessionConfidenceLabel.early,
    sourceTextPreview: 'I said yes again.',
    matchReason: 'Your words pointed toward pressure in this moment.',
    confidenceScore: confidenceScore,
    categoryId: 'responsibility',
    category: FirstSessionPatternCategory.responsibility,
  );
}

void main() {
  const engine = InsightStrengthEngine();

  test('weak evidence yields Early signal', () {
    final strength = engine.build(
      pattern: _pattern(),
      signal: const PostSaveInsightSignalContext(
        categoryId: 'responsibility',
        explanation: 'You mentioned pressure or responsibility.',
      ),
    );
    expect(strength.label, InsightStrengthLabel.earlySignal);
    expect(strength.label.displayLabel, 'Early signal');
  });

  test('repeated evidence yields Possible repeat or Getting clearer', () {
    final strength = engine.build(
      pattern: _pattern(
        chips: const ['saying yes', 'pressure', 'disappoint'],
        confidenceScore: 0.5,
      ),
      signal: const PostSaveInsightSignalContext(
        categoryId: 'responsibility',
        explanation: 'You mentioned pressure.',
      ),
      reflectionCount: 2,
      categoryRepeated: true,
    );
    expect(
      strength.label,
      anyOf(
        InsightStrengthLabel.possibleRepeat,
        InsightStrengthLabel.gettingClearer,
        InsightStrengthLabel.strongPattern,
      ),
    );
  });

  test('strength copy has no percentages or diagnosis language', () {
    const postEngine = PostSaveInsightEngine();
    final bundle = postEngine.build(
      _pattern(chips: const ['saying yes', 'pressure']),
    );
    for (final signal in bundle.signals) {
      final blob =
          '${signal.strengthLabel} ${signal.whySuggested} ${signal.evidenceChips.join(' ')}'
              .toLowerCase();
      expect(blob, isNot(contains('%')));
      expect(blob, isNot(contains('confidence')));
      expect(blob, isNot(contains('diagnosis')));
      expect(blob, isNot(contains('therapy')));
      expect(blob, isNot(contains('coach')));
    }
  });

  test('why suggested references detected words when chips exist', () {
    final strength = engine.build(
      pattern: _pattern(chips: const ['saying yes', 'pressure']),
      signal: const PostSaveInsightSignalContext(
        categoryId: 'responsibility',
        explanation: '',
      ),
    );
    expect(strength.whySuggested.toLowerCase(), contains('you mentioned'));
    expect(strength.evidenceChips, isNotEmpty);
  });
}