import 'package:archiveme_mobile/features/insights/trend_analysis/trend_analysis_aggregator.dart';
import 'package:archiveme_mobile/features/insights/trend_analysis/trend_analysis_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const aggregator = TrendAnalysisAggregator(minReflections: 3);

  test('aggregates intensity, themes, tensions, and patterns', () {
    final records = [
      TrendReflectionRecord(
        entryId: '1',
        createdAt: DateTime.utc(2026, 8, 10),
        mood: 'anxious',
        emotionalIntensity: 4,
        recurringThemes: const ['work'],
        tensionOrContradiction: 'Want rest but keep accepting extra work',
        patternObservations: const ['Language loops without resolving'],
        transcript: 'I said yes again even though I am tired.',
      ),
      TrendReflectionRecord(
        entryId: '2',
        createdAt: DateTime.utc(2026, 8, 12),
        mood: 'reflective',
        emotionalIntensity: 6,
        recurringThemes: const ['work', 'boundaries'],
        tensionOrContradiction: 'Want rest but keep accepting extra work',
        transcript: 'Still carrying too much at work.',
      ),
      TrendReflectionRecord(
        entryId: '3',
        createdAt: DateTime.utc(2026, 8, 15),
        mood: 'overwhelmed',
        emotionalIntensity: 8,
        recurringThemes: const ['work'],
        patternObservations: const ['Language loops without resolving'],
        transcript: 'Conflict at work and I avoided the conversation.',
      ),
    ];

    final metadata = aggregator.aggregate(
      window: TrendAnalysisWindow.sevenDay,
      windowStart: DateTime.utc(2026, 8, 10),
      windowEnd: DateTime.utc(2026, 8, 16),
      records: records,
    );

    expect(metadata, isNotNull);
    expect(metadata!.reflectionCount, 3);
    expect(metadata.intensityTrend, TrendIntensityDirection.rising);
    expect(metadata.themeCounts['work'], 3);
    expect(metadata.underlyingTensions.single.occurrences, 2);
    expect(metadata.cognitivePatterns, isNotEmpty);
  });

  test('returns null when below minimum reflections', () {
    final metadata = aggregator.aggregate(
      window: TrendAnalysisWindow.sevenDay,
      windowStart: DateTime.utc(2026, 8, 10),
      windowEnd: DateTime.utc(2026, 8, 16),
      records: [
        TrendReflectionRecord(
          entryId: '1',
          createdAt: DateTime.utc(2026, 8, 10),
          mood: 'calm',
          emotionalIntensity: 3,
          recurringThemes: ['health'],
        ),
      ],
    );
    expect(metadata, isNull);
  });
}
