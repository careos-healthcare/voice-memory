import 'package:archiveme_mobile/api/models/capture_dto.dart';
import 'package:archiveme_mobile/features/insights/trend_analysis/trend_analysis_models.dart';
import 'package:archiveme_mobile/features/reflections/data/local_reflection_data_source.dart';

/// Passes aggregated trend metadata through the local ONNX reflection model.
class TrendAnalysisOnnxSynthesizer {
  TrendAnalysisOnnxSynthesizer({
    required LocalReflectionDataSource reflectionModel,
  }) : _reflectionModel = reflectionModel;

  final LocalReflectionDataSource _reflectionModel;

  static Future<TrendAnalysisOnnxSynthesizer> create({
    LocalReflectionDataSource? reflectionModel,
  }) async {
    return TrendAnalysisOnnxSynthesizer(
      reflectionModel:
          reflectionModel ?? await LocalReflectionDataSource.create(),
    );
  }

  Future<({ReflectionDto reflection, bool usedOnnx})> synthesize(
    TrendAggregatedMetadata metadata,
  ) async {
    final transcript = _buildTrendTranscript(metadata);
    final inference = await _reflectionModel.inferFromTranscript(
      transcript: transcript,
      entryId: 'trend-${metadata.window.storageKey}',
    );
    return (reflection: inference.reflection, usedOnnx: inference.usedOnnx);
  }

  WeeklySelfReflectionReport composeReport({
    required TrendAggregatedMetadata metadata,
    required ReflectionDto synthesis,
    required bool usedOnnx,
    DateTime? generatedAt,
  }) {
    final summary = _composeSummary(metadata, synthesis);
    return WeeklySelfReflectionReport(
      window: metadata.window,
      windowStart: metadata.windowStart,
      windowEnd: metadata.windowEnd,
      reflectionCount: metadata.reflectionCount,
      metadata: metadata,
      summary: summary,
      emotionalShifts: _composeEmotionalShifts(metadata, synthesis),
      cognitiveLoops: _composeCognitiveLoops(metadata, synthesis),
      synthesisReflection: synthesis,
      usedOnnx: usedOnnx,
      generatedAt: generatedAt ?? DateTime.now().toUtc(),
    );
  }

  static String _buildTrendTranscript(TrendAggregatedMetadata metadata) {
    final buffer = StringBuffer()
      ..writeln('Weekly trend analysis (local only):')
      ..writeln('Window: last ${metadata.window.label}')
      ..writeln('Reflections analyzed: ${metadata.reflectionCount}')
      ..writeln(
        'Average emotional intensity: '
        '${metadata.averageIntensity.toStringAsFixed(1)} '
        '(early ${metadata.earlyWindowAverageIntensity.toStringAsFixed(1)}, '
        'late ${metadata.lateWindowAverageIntensity.toStringAsFixed(1)})',
      );

    if (metadata.moodCounts.isNotEmpty) {
      final moods = metadata.moodCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      buffer.writeln(
        'Dominant moods: ${moods.take(4).map((entry) => '${entry.key} (${entry.value})').join(', ')}',
      );
    }

    if (metadata.themeCounts.isNotEmpty) {
      final themes = metadata.themeCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      buffer.writeln(
        'Recurring themes: ${themes.take(5).map((entry) => '${entry.key} (${entry.value})').join(', ')}',
      );
    }

    if (metadata.underlyingTensions.isNotEmpty) {
      buffer.writeln('Underlying tensions:');
      for (final tension in metadata.underlyingTensions.take(5)) {
        buffer.writeln('- ${tension.label} (${tension.occurrences}x)');
      }
    }

    if (metadata.cognitivePatterns.isNotEmpty) {
      buffer.writeln('Recurring patterns in your entries:');
      for (final pattern in metadata.cognitivePatterns.take(5)) {
        buffer.writeln('- ${pattern.label} (${pattern.occurrences}x)');
      }
    }

    buffer.writeln(
      'Synthesize a weekly self-reflection summarizing emotional shifts '
      'and recurring patterns from this archive metadata.',
    );

    return buffer.toString().trim();
  }

  static String _composeSummary(
    TrendAggregatedMetadata metadata,
    ReflectionDto synthesis,
  ) {
    final observation = synthesis.concreteObservation?.trim();
    if (observation != null && observation.isNotEmpty) {
      return observation;
    }
    final repeated = synthesis.repeatedSignal?.trim();
    if (repeated != null && repeated.isNotEmpty) {
      return repeated;
    }
    return 'Based on these entries, your archive noticed emotional intensity that '
        'may be ${_intensityTrendWord(metadata.intensityTrend)} with recurring '
        'focus on ${_topThemes(metadata)}.';
  }

  static List<EmotionalShiftLine> _composeEmotionalShifts(
    TrendAggregatedMetadata metadata,
    ReflectionDto synthesis,
  ) {
    final lines = <EmotionalShiftLine>[];

    lines.add(
      EmotionalShiftLine(
        headline: _intensityHeadline(metadata.intensityTrend),
        detail:
            'Average intensity moved from '
            '${metadata.earlyWindowAverageIntensity.toStringAsFixed(1)} '
            'to ${metadata.lateWindowAverageIntensity.toStringAsFixed(1)} '
            'across ${metadata.reflectionCount} reflections.',
      ),
    );

    if (metadata.moodCounts.isNotEmpty) {
      final topMood = metadata.moodCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      lines.add(
        EmotionalShiftLine(
          headline: 'Most common mood label: ${topMood.first.key}',
          detail:
              synthesis.mood.trim().isNotEmpty
                  ? 'Latest synthesis mood: ${synthesis.mood}.'
                  : 'Most frequent mood label in the window.',
        ),
      );
    }

    final tension = synthesis.tensionOrContradiction?.trim();
    if (tension != null && tension.isNotEmpty) {
      lines.add(
        EmotionalShiftLine(
          headline: 'Tension mentioned in recent entries',
          detail: tension,
        ),
      );
    }

    return lines.take(4).toList(growable: false);
  }

  static List<CognitiveLoopLine> _composeCognitiveLoops(
    TrendAggregatedMetadata metadata,
    ReflectionDto synthesis,
  ) {
    final loops = <CognitiveLoopLine>[];

    for (final pattern in metadata.cognitivePatterns.take(4)) {
      loops.add(
        CognitiveLoopLine(
          pattern: pattern.label,
          occurrences: pattern.occurrences,
        ),
      );
    }

    for (final theme in synthesis.recurringThemes.take(2)) {
      final trimmed = theme.trim();
      if (trimmed.isEmpty) continue;
      loops.add(
        CognitiveLoopLine(
          pattern: 'Recurring focus on $trimmed',
          occurrences: metadata.themeCounts[trimmed.toLowerCase()] ?? 1,
          detail: synthesis.exactLanguagePattern,
        ),
      );
    }

    for (final observation in synthesis.patternObservations.take(2)) {
      final trimmed = observation.trim();
      if (trimmed.isEmpty) continue;
      loops.add(
        CognitiveLoopLine(
          pattern: trimmed,
          occurrences: 1,
        ),
      );
    }

    return loops.take(6).toList(growable: false);
  }

  static String _intensityHeadline(TrendIntensityDirection trend) {
    return switch (trend) {
      TrendIntensityDirection.rising => 'Emotional intensity may be rising',
      TrendIntensityDirection.falling => 'Emotional intensity may be easing',
      TrendIntensityDirection.steady => 'Emotional intensity held steady',
      TrendIntensityDirection.unknown => 'Emotional intensity varied',
    };
  }

  static String _intensityTrendWord(TrendIntensityDirection trend) {
    return switch (trend) {
      TrendIntensityDirection.rising => 'rising',
      TrendIntensityDirection.falling => 'easing',
      TrendIntensityDirection.steady => 'holding steady',
      TrendIntensityDirection.unknown => 'varying',
    };
  }

  static String _topThemes(TrendAggregatedMetadata metadata) {
    if (metadata.themeCounts.isEmpty) return 'mixed themes';
    final themes = metadata.themeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return themes.take(3).map((entry) => entry.key).join(', ');
  }
}
