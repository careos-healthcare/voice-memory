import 'package:archiveme_mobile/api/models/capture_dto.dart';
import 'package:archiveme_mobile/features/insights/trend_analysis/trend_analysis_models.dart';
import 'package:archiveme_mobile/features/insights/trend_analysis/trend_analysis_onnx_synthesizer.dart';
import 'package:archiveme_mobile/features/reflections/data/local_reflection_data_source.dart';
import 'package:archiveme_mobile/features/reflections/data/local_reflection_heuristic_inference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final synthesizer = TrendAnalysisOnnxSynthesizer(
    reflectionModel: LocalReflectionDataSource(
      inference: const LocalReflectionHeuristicInference(),
    ),
  );

  const leakSynthesis = ReflectionDto(
    mood: 'reflective',
    emotionalIntensity: 5,
    concreteObservation: 'LEAK: synthesis prompt text',
    repeatedSignal: 'LEAK: repeated signal prompt',
    tensionOrContradiction: 'LEAK: tension prompt text',
    recurringThemes: ['LEAK theme'],
    patternObservations: ['LEAK: pattern observation'],
    exactLanguagePattern: 'LEAK: exact language pattern',
  );

  final metadata = TrendAggregatedMetadata(
    window: TrendAnalysisWindow.sevenDay,
    windowStart: DateTime.utc(2026, 8, 1),
    windowEnd: DateTime.utc(2026, 8, 8),
    reflectionCount: 3,
    averageIntensity: 5,
    earlyWindowAverageIntensity: 4,
    lateWindowAverageIntensity: 6,
    moodCounts: {},
    themeCounts: {'work': 2},
    underlyingTensions: [],
    cognitivePatterns: [
      TrendCognitivePatternLine(label: 'Avoidance', occurrences: 2),
    ],
    intensityTrend: TrendIntensityDirection.unknown,
  );

  test('heuristic fallback does not leak synthesis prompt fields', () {
    final report = synthesizer.composeReport(
      metadata: metadata,
      synthesis: leakSynthesis,
      usedOnnx: false,
    );

    expect(report.summary.contains('LEAK'), isFalse);
    expect(
      report.cognitiveLoops.map((loop) => loop.pattern),
      ['Avoidance'],
    );
    expect(
      report.cognitiveLoops.every((loop) => loop.detail?.contains('LEAK') != true),
      isTrue,
    );
    expect(
      report.emotionalShifts.every((line) => !line.detail.contains('LEAK')),
      isTrue,
    );
  });

  test('onnx path uses genuine synthesis fields', () {
    final report = synthesizer.composeReport(
      metadata: metadata,
      synthesis: leakSynthesis,
      usedOnnx: true,
    );

    expect(report.summary, 'LEAK: synthesis prompt text');
    expect(
      report.cognitiveLoops.map((loop) => loop.pattern),
      containsAll([
        'Recurring focus on LEAK theme',
        'LEAK: pattern observation',
      ]),
    );
    expect(
      report.emotionalShifts.map((line) => line.detail),
      contains('LEAK: tension prompt text'),
    );
  });
}
