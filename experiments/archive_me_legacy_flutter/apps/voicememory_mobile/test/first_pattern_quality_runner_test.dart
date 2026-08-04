import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/first_session/first_pattern_quality_result.dart';
import 'package:voicememory_mobile/features/first_session/first_pattern_quality_runner.dart';
import 'package:voicememory_mobile/features/first_session/first_pattern_quality_sample.dart';
import 'package:voicememory_mobile/features/first_session/first_pattern_quality_samples.dart';
import 'package:voicememory_mobile/features/first_session/first_pattern_quality_titles.dart';

void main() {
  const runner = FirstPatternQualityRunner();

  test('sample dataset has curated and messy counts', () {
    expect(FirstPatternQualitySamples.curated.length, 44);
    expect(FirstPatternQualitySamples.messy.length, 62);
    expect(FirstPatternQualitySamples.hard.length, 106);
  });

  test('QA runner returns total count', () {
    final result = runner.run(FirstPatternQualitySamples.hard);
    expect(result.total, 106);
  });

  test('accepts known responsibility sample', () {
    final result = runner.run([
      FirstPatternQualitySamples.responsibility.first,
    ]);
    expect(result.accepted, 1);
    expect(result.rejected, 0);
    expect(result.failures, isEmpty);
  });

  test('flags wrong title as failure and overconfident wrong', () {
    const sample = FirstPatternQualitySample(
      id: 'forced-fail',
      reflectionText:
          'I keep saying yes too fast and feel guilty about pressure before asking for help',
      expectedCategory: 'worry',
      acceptableTitles: [FirstPatternQualityTitles.worry],
      unacceptableTitles: [FirstPatternQualityTitles.responsibility],
    );
    final result = runner.run([sample]);
    expect(result.accepted, 0);
    expect(result.rejected, 1);
    expect(result.overconfidentWrongCount, 1);
    expect(
      result.failures.first.actualTitle,
      FirstPatternQualityTitles.responsibility,
    );
  });

  test('tracks fallback on neutral sample', () {
    final result = runner.run([
      FirstPatternQualitySamples.ambiguous.firstWhere(
        (s) => s.id == 'neutral-1',
      ),
    ]);
    expect(result.fallbackCount, 1);
    expect(result.accepted, 1);
  });

  test('hard dataset meets 85% accuracy and QA gates', () {
    final result = runner.run(FirstPatternQualitySamples.hard);
    expect(
      result.accuracyRate,
      greaterThanOrEqualTo(FirstPatternQualityResult.hardAccuracyMinimum),
      reason: result.summaryText,
    );
    expect(result.overconfidentWrongCount, 0);
    expect(result.passesHardQaGates, isTrue);
  });

  test('messy vague samples allow fallback', () {
    final vague = FirstPatternQualitySamples.messy
        .where((s) => s.isVagueOrNeutral)
        .toList();
    final result = runner.run(vague);
    expect(result.vagueNeutralSampleCount, greaterThan(0));
    expect(
      result.vagueFallbackAcceptedCount,
      greaterThanOrEqualTo((result.vagueNeutralSampleCount * 0.6).ceil()),
    );
  });

  test('messy ambiguous samples get correction path', () {
    final ambiguous = FirstPatternQualitySamples.messy
        .where((s) => s.isAmbiguous)
        .toList();
    final result = runner.run(ambiguous);
    expect(result.ambiguousSampleCount, greaterThan(0));
    expect(result.ambiguousHandledCount, greaterThan(0));
  });

  test('prints QA report for tool script', () {
    final curated = runner.run(FirstPatternQualitySamples.curated);
    final hard = runner.run(FirstPatternQualitySamples.hard);
    // ignore: avoid_print
    print('Curated: ${(curated.accuracyRate * 100).toStringAsFixed(1)}%');
    // ignore: avoid_print
    print(hard.summaryText);
    expect(hard.total, greaterThan(0));
  });
}
