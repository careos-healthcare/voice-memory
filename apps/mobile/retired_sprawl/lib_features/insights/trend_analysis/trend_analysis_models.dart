import 'package:archiveme_mobile/api/models/capture_dto.dart';

/// Rolling analysis window for local trend reports.
enum TrendAnalysisWindow {
  sevenDay(7),
  thirtyDay(30);

  const TrendAnalysisWindow(this.dayCount);
  final int dayCount;

  String get storageKey => name;

  String get label => switch (this) {
    TrendAnalysisWindow.sevenDay => '7-day',
    TrendAnalysisWindow.thirtyDay => '30-day',
  };
}

/// Lightweight reflection row loaded from drift for trend aggregation.
class TrendReflectionRecord {
  const TrendReflectionRecord({
    required this.entryId,
    required this.createdAt,
    required this.mood,
    required this.emotionalIntensity,
    required this.recurringThemes,
    this.tensionOrContradiction,
    this.patternObservations = const [],
    this.concreteObservation,
    this.transcript = '',
  });

  final String entryId;
  final DateTime createdAt;
  final String mood;
  final int emotionalIntensity;
  final List<String> recurringThemes;
  final String? tensionOrContradiction;
  final List<String> patternObservations;
  final String? concreteObservation;
  final String transcript;

  bool get hasUsableReflection =>
      emotionalIntensity > 0 ||
      mood.trim().isNotEmpty ||
      recurringThemes.isNotEmpty ||
      (concreteObservation?.trim().isNotEmpty ?? false);
}

/// Aggregated metadata passed into the local ONNX synthesizer.
class TrendAggregatedMetadata {
  const TrendAggregatedMetadata({
    required this.window,
    required this.windowStart,
    required this.windowEnd,
    required this.reflectionCount,
    required this.averageIntensity,
    required this.earlyWindowAverageIntensity,
    required this.lateWindowAverageIntensity,
    required this.moodCounts,
    required this.themeCounts,
    required this.underlyingTensions,
    required this.cognitivePatterns,
    required this.intensityTrend,
  });

  final TrendAnalysisWindow window;
  final DateTime windowStart;
  final DateTime windowEnd;
  final int reflectionCount;
  final double averageIntensity;
  final double earlyWindowAverageIntensity;
  final double lateWindowAverageIntensity;
  final Map<String, int> moodCounts;
  final Map<String, int> themeCounts;
  final List<TrendTensionLine> underlyingTensions;
  final List<TrendCognitivePatternLine> cognitivePatterns;
  final TrendIntensityDirection intensityTrend;
}

enum TrendIntensityDirection { rising, falling, steady, unknown }

class TrendTensionLine {
  const TrendTensionLine({
    required this.label,
    required this.occurrences,
    this.exampleEntryId,
  });

  final String label;
  final int occurrences;
  final String? exampleEntryId;
}

class TrendCognitivePatternLine {
  const TrendCognitivePatternLine({
    required this.label,
    required this.occurrences,
    this.exampleEntryId,
  });

  final String label;
  final int occurrences;
  final String? exampleEntryId;
}

class EmotionalShiftLine {
  const EmotionalShiftLine({
    required this.headline,
    required this.detail,
  });

  final String headline;
  final String detail;
}

class CognitiveLoopLine {
  const CognitiveLoopLine({
    required this.pattern,
    required this.occurrences,
    this.detail,
  });

  final String pattern;
  final int occurrences;
  final String? detail;
}

/// Weekly self-reflection report synthesized from drift history + local ONNX.
class WeeklySelfReflectionReport {
  const WeeklySelfReflectionReport({
    required this.window,
    required this.windowStart,
    required this.windowEnd,
    required this.reflectionCount,
    required this.metadata,
    required this.summary,
    required this.emotionalShifts,
    required this.cognitiveLoops,
    required this.generatedAt,
    this.synthesisReflection,
    this.usedOnnx = false,
  });

  final TrendAnalysisWindow window;
  final DateTime windowStart;
  final DateTime windowEnd;
  final int reflectionCount;
  final TrendAggregatedMetadata metadata;
  final String summary;
  final List<EmotionalShiftLine> emotionalShifts;
  final List<CognitiveLoopLine> cognitiveLoops;
  final ReflectionDto? synthesisReflection;
  final bool usedOnnx;
  final DateTime generatedAt;

  Map<String, dynamic> toJson() => {
    'window': window.storageKey,
    'windowStart': windowStart.toUtc().toIso8601String(),
    'windowEnd': windowEnd.toUtc().toIso8601String(),
    'reflectionCount': reflectionCount,
    'summary': summary,
    'emotionalShifts': emotionalShifts
        .map((line) => {'headline': line.headline, 'detail': line.detail})
        .toList(),
    'cognitiveLoops': cognitiveLoops
        .map(
          (line) => {
            'pattern': line.pattern,
            'occurrences': line.occurrences,
            if (line.detail != null) 'detail': line.detail,
          },
        )
        .toList(),
    'usedOnnx': usedOnnx,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    if (synthesisReflection != null)
      'synthesisReflection': synthesisReflection!.toJson(),
  };

  static WeeklySelfReflectionReport? fromJson(Map<String, dynamic> json) {
    final windowRaw = json['window'] as String?;
    final window = TrendAnalysisWindow.values.firstWhere(
      (value) => value.storageKey == windowRaw,
      orElse: () => TrendAnalysisWindow.sevenDay,
    );

    final windowStart = DateTime.tryParse(json['windowStart'] as String? ?? '');
    final windowEnd = DateTime.tryParse(json['windowEnd'] as String? ?? '');
    final generatedAt = DateTime.tryParse(json['generatedAt'] as String? ?? '');
    if (windowStart == null || windowEnd == null || generatedAt == null) {
      return null;
    }

    ReflectionDto? synthesis;
    final synthesisJson = json['synthesisReflection'];
    if (synthesisJson is Map<String, dynamic>) {
      synthesis = ReflectionDto.fromJson(synthesisJson);
    }

    final metadata = TrendAggregatedMetadata(
      window: window,
      windowStart: windowStart,
      windowEnd: windowEnd,
      reflectionCount: (json['reflectionCount'] as num?)?.toInt() ?? 0,
      averageIntensity: 0,
      earlyWindowAverageIntensity: 0,
      lateWindowAverageIntensity: 0,
      moodCounts: const {},
      themeCounts: const {},
      underlyingTensions: const [],
      cognitivePatterns: const [],
      intensityTrend: TrendIntensityDirection.unknown,
    );

    final shiftLines = (json['emotionalShifts'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => EmotionalShiftLine(
            headline: (item['headline'] as String?) ?? '',
            detail: (item['detail'] as String?) ?? '',
          ),
        )
        .where((line) => line.headline.isNotEmpty)
        .toList(growable: false);

    final loopLines = (json['cognitiveLoops'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => CognitiveLoopLine(
            pattern: (item['pattern'] as String?) ?? '',
            occurrences: (item['occurrences'] as num?)?.toInt() ?? 0,
            detail: item['detail'] as String?,
          ),
        )
        .where((line) => line.pattern.isNotEmpty)
        .toList(growable: false);

    return WeeklySelfReflectionReport(
      window: window,
      windowStart: windowStart,
      windowEnd: windowEnd,
      reflectionCount: (json['reflectionCount'] as num?)?.toInt() ?? 0,
      metadata: metadata,
      summary: (json['summary'] as String?) ?? '',
      emotionalShifts: shiftLines,
      cognitiveLoops: loopLines,
      synthesisReflection: synthesis,
      usedOnnx: json['usedOnnx'] as bool? ?? false,
      generatedAt: generatedAt,
    );
  }
}
