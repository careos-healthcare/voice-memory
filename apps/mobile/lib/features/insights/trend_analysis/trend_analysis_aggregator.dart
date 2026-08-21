import 'package:archiveme_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:archiveme_mobile/features/discover/theme_engine.dart';
import 'package:archiveme_mobile/features/insights/predictions/prediction_engine.dart';
import 'package:archiveme_mobile/features/insights/trend_analysis/trend_analysis_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';

/// Aggregates rolling-window reflection metadata for ONNX synthesis.
class TrendAnalysisAggregator {
  const TrendAnalysisAggregator({
    this.minReflections = 3,
    PredictionInsightEngine? predictionEngine,
  }) : _predictionEngine = predictionEngine ?? const PredictionInsightEngine();

  final int minReflections;
  final PredictionInsightEngine _predictionEngine;

  TrendAggregatedMetadata? aggregate({
    required TrendAnalysisWindow window,
    required DateTime windowStart,
    required DateTime windowEnd,
    required List<TrendReflectionRecord> records,
    List<JournalEntry>? journalEntriesForPredictions,
  }) {
    if (records.length < minReflections) return null;

    final moodCounts = <String, int>{};
    for (final record in records) {
      final mood = record.mood.trim().toLowerCase();
      if (mood.isEmpty) continue;
      moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
    }

    final pseudoEntries = journalEntriesForPredictions ??
        records
            .map(
              (record) => JournalEntry(
                id: record.entryId,
                createdAt: record.createdAt,
                transcript: record.transcript,
                durationSeconds: 0,
                reflection: Reflection(
                  mood: record.mood,
                  emotionalIntensity: record.emotionalIntensity,
                  recurringThemes: record.recurringThemes,
                  exactLanguagePattern: '',
                  concreteObservation: record.concreteObservation ?? '',
                  repeatedSignal: '',
                  tensionOrContradiction: record.tensionOrContradiction,
                  patternObservations: record.patternObservations,
                ),
              ),
            )
            .toList(growable: false);

    final themeCounts = DiscoverLocalThemeCounts.count(
      archiveEligibleEvidenceEntries(pseudoEntries).isNotEmpty
          ? archiveEligibleEvidenceEntries(pseudoEntries)
          : pseudoEntries,
    );

    final midpoint = records.length ~/ 2;
    final early = records.take(midpoint).toList(growable: false);
    final late = records.skip(midpoint).toList(growable: false);

    final earlyAvg = _averageIntensity(early);
    final lateAvg = _averageIntensity(late);
    final average = _averageIntensity(records);

    final intensityTrend = _resolveIntensityTrend(earlyAvg, lateAvg);

    final tensions = _aggregateTensions(records);
    final patterns = _aggregatePatterns(records, pseudoEntries);

    return TrendAggregatedMetadata(
      window: window,
      windowStart: windowStart,
      windowEnd: windowEnd,
      reflectionCount: records.length,
      averageIntensity: average,
      earlyWindowAverageIntensity: earlyAvg,
      lateWindowAverageIntensity: lateAvg,
      moodCounts: moodCounts,
      themeCounts: themeCounts,
      underlyingTensions: tensions,
      cognitivePatterns: patterns,
      intensityTrend: intensityTrend,
    );
  }

  static double _averageIntensity(List<TrendReflectionRecord> records) {
    final values = records
        .map((record) => record.emotionalIntensity)
        .where((value) => value > 0)
        .toList(growable: false);
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  static TrendIntensityDirection _resolveIntensityTrend(
    double earlyAvg,
    double lateAvg,
  ) {
    if (earlyAvg <= 0 && lateAvg <= 0) {
      return TrendIntensityDirection.unknown;
    }
    if (earlyAvg <= 0 || lateAvg <= 0) {
      return TrendIntensityDirection.steady;
    }
    final delta = lateAvg - earlyAvg;
    if (delta >= 0.75) return TrendIntensityDirection.rising;
    if (delta <= -0.75) return TrendIntensityDirection.falling;
    return TrendIntensityDirection.steady;
  }

  static List<TrendTensionLine> _aggregateTensions(
    List<TrendReflectionRecord> records,
  ) {
    final counts = <String, ({int count, String entryId})>{};
    for (final record in records) {
      final tension = record.tensionOrContradiction?.trim();
      if (tension == null || tension.isEmpty) continue;
      final key = tension.toLowerCase();
      final existing = counts[key];
      counts[key] = (
        count: (existing?.count ?? 0) + 1,
        entryId: existing?.entryId ?? record.entryId,
      );
    }

    final lines = counts.entries
        .map(
          (entry) => TrendTensionLine(
            label: _titleCase(entry.key),
            occurrences: entry.value.count,
            exampleEntryId: entry.value.entryId,
          ),
        )
        .toList(growable: false)
      ..sort((a, b) => b.occurrences.compareTo(a.occurrences));

    return lines.take(6).toList(growable: false);
  }

  List<TrendCognitivePatternLine> _aggregatePatterns(
    List<TrendReflectionRecord> records,
    List<JournalEntry> journalEntries,
  ) {
    final counts = <String, ({int count, String entryId})>{};

    for (final record in records) {
      for (final pattern in record.patternObservations) {
        final trimmed = pattern.trim();
        if (trimmed.isEmpty) continue;
        final key = trimmed.toLowerCase();
        final existing = counts[key];
        counts[key] = (
          count: (existing?.count ?? 0) + 1,
          entryId: existing?.entryId ?? record.entryId,
        );
      }
    }

    for (final insight in _predictionEngine.build(journalEntries)) {
      final label = insight.summary.trim().isNotEmpty
          ? insight.summary.trim()
          : insight.title.trim();
      if (label.isEmpty) continue;
      final key = label.toLowerCase();
      final existing = counts[key];
      counts[key] = (
        count: (existing?.count ?? 0) + insight.evidenceCount,
        entryId:
            existing?.entryId ??
            insight.supportingEvents.firstOrNull?.outcomeEntryId ??
            '',
      );
    }

    final lines = counts.entries
        .map(
          (entry) => TrendCognitivePatternLine(
            label: entry.key,
            occurrences: entry.value.count,
            exampleEntryId: entry.value.entryId,
          ),
        )
        .toList(growable: false)
      ..sort((a, b) => b.occurrences.compareTo(a.occurrences));

    return lines.take(6).toList(growable: false);
  }

  static String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => length == 0 ? null : first;
}
