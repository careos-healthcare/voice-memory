import 'dart:math' as math;

import '../../core/search/local_vector_search_engine.dart';
import 'autonomous_muse_models.dart';
import 'autonomous_muse_store.dart';
import 'bridge_confidence_engine.dart';

final class ThematicDeck {
  ThematicDeck({
    required this.id,
    required this.topic,
    required Iterable<LegacyBridgeSuggestion> suggestions,
  }) : suggestions = List.unmodifiable(suggestions);

  final String id;
  final String topic;
  final List<LegacyBridgeSuggestion> suggestions;
}

final class ThematicClusterManager {
  const ThematicClusterManager({
    required this.embeddingDriver,
    this.minimumClusterSimilarity = .72,
  });

  final LocalEmbeddingDriver embeddingDriver;
  final double minimumClusterSimilarity;

  List<ThematicDeck> cluster(Iterable<LegacyBridgeSuggestion> values) {
    final clusters =
        <({List<LegacyBridgeSuggestion> suggestions, List<double> centroid})>[];
    final ordered = values.toList()
      ..sort(
        (left, right) => right.confidenceScore.compareTo(left.confidenceScore),
      );
    for (final suggestion in ordered) {
      final vector = embeddingDriver.embed(_clusterText(suggestion));
      var bestIndex = -1;
      var bestScore = -1.0;
      for (var index = 0; index < clusters.length; index++) {
        final score = _cosine(vector, clusters[index].centroid);
        if (score > bestScore) {
          bestScore = score;
          bestIndex = index;
        }
      }
      if (bestIndex < 0 || bestScore < minimumClusterSimilarity) {
        clusters.add((suggestions: [suggestion], centroid: vector.toList()));
      } else {
        final cluster = clusters[bestIndex];
        cluster.suggestions.add(suggestion);
        clusters[bestIndex] = (
          suggestions: cluster.suggestions,
          centroid: _meanVector(
            cluster.centroid,
            vector,
            cluster.suggestions.length,
          ),
        );
      }
    }
    final decks =
        [
          for (var index = 0; index < clusters.length; index++)
            ThematicDeck(
              id: 'muse-deck-${_slug(_topic(clusters[index].suggestions))}-$index',
              topic: _topic(clusters[index].suggestions),
              suggestions: clusters[index].suggestions,
            ),
        ]..sort((left, right) {
          final count = right.suggestions.length.compareTo(
            left.suggestions.length,
          );
          return count != 0 ? count : left.topic.compareTo(right.topic);
        });
    return List.unmodifiable(decks);
  }

  static String _clusterText(LegacyBridgeSuggestion suggestion) =>
      '${suggestion.entities.join(' ')} ${suggestion.sourceLabel} '
      '${suggestion.targetLabel} ${suggestion.rationale}';

  static String _topic(List<LegacyBridgeSuggestion> suggestions) {
    final counts = <String, int>{};
    for (final suggestion in suggestions) {
      for (final entity in suggestion.entities) {
        final clean = entity.trim();
        if (clean.isNotEmpty) {
          counts.update(clean, (value) => value + 1, ifAbsent: () => 1);
        }
      }
    }
    if (counts.isNotEmpty) {
      final ranked = counts.entries.toList()
        ..sort((left, right) {
          final count = right.value.compareTo(left.value);
          return count != 0 ? count : left.key.compareTo(right.key);
        });
      return ranked.first.key;
    }
    return suggestions.first.sourceLabel;
  }
}

final class DailyDigestQueue {
  DailyDigestQueue({
    required this.store,
    this.confidenceEngine = const BridgeConfidenceEngine(),
    DateTime Function()? clock,
    this.dailyLimit = 15,
  }) : _clock = clock ?? DateTime.now;

  final AutonomousMuseStore store;
  final BridgeConfidenceEngine confidenceEngine;
  final int dailyLimit;
  final DateTime Function() _clock;

  List<LegacyBridgeSuggestion> active({bool includeDeepConnections = false}) {
    final now = _clock();
    final day = includeDeepConnections ? '${_day(now)}-deep' : _day(now);
    final candidates =
        store
            .legacySuggestions(status: LegacyBridgeSuggestionStatus.pending)
            .where(
              (suggestion) =>
                  suggestion.deferredUntil == null ||
                  !suggestion.deferredUntil!.isAfter(now),
            )
            .where((suggestion) {
              final band = confidenceEngine.categorize(suggestion).band;
              return band == BridgeConfidenceBand.actionable ||
                  (includeDeepConnections &&
                      band == BridgeConfidenceBand.fringe);
            })
            .toList()
          ..sort((left, right) {
            if (includeDeepConnections) {
              final leftFringe =
                  confidenceEngine.categorize(left).band ==
                  BridgeConfidenceBand.fringe;
              final rightFringe =
                  confidenceEngine.categorize(right).band ==
                  BridgeConfidenceBand.fringe;
              if (leftFringe != rightFringe) return leftFringe ? -1 : 1;
            }
            final leftScore = confidenceEngine
                .categorize(left)
                .combinedConfidence;
            final rightScore = confidenceEngine
                .categorize(right)
                .combinedConfidence;
            final score = rightScore.compareTo(leftScore);
            return score != 0
                ? score
                : left.createdAt.compareTo(right.createdAt);
          });

    final byId = {for (final item in candidates) item.id: item};
    final selected = <LegacyBridgeSuggestion>[];
    final selectedIds = <String>{};
    for (final id in store.readDailyDigestIds(day)) {
      final item = byId[id];
      if (item != null && selected.length < dailyLimit) {
        selected.add(item);
        selectedIds.add(id);
      }
    }
    for (final item in candidates) {
      if (selected.length >= dailyLimit) break;
      if (selectedIds.add(item.id)) selected.add(item);
    }
    store.saveDailyDigestIds(day, selected.map((item) => item.id));
    return List.unmodifiable(selected);
  }

  int backlogCount({bool includeDeepConnections = false}) {
    final activeIds = active(
      includeDeepConnections: includeDeepConnections,
    ).map((item) => item.id).toSet();
    return store
        .legacySuggestions(status: LegacyBridgeSuggestionStatus.pending)
        .where((item) => !activeIds.contains(item.id))
        .length;
  }
}

List<double> _meanVector(
  List<double> previous,
  List<double> next,
  int count,
) => [
  for (var index = 0; index < math.min(previous.length, next.length); index++)
    ((previous[index] * (count - 1)) + next[index]) / count,
];

double _cosine(List<double> left, List<double> right) {
  if (left.length != right.length || left.isEmpty) return -1;
  var dot = 0.0;
  var leftNorm = 0.0;
  var rightNorm = 0.0;
  for (var index = 0; index < left.length; index++) {
    dot += left[index] * right[index];
    leftNorm += left[index] * left[index];
    rightNorm += right[index] * right[index];
  }
  if (leftNorm == 0 || rightNorm == 0) return -1;
  return dot / (math.sqrt(leftNorm) * math.sqrt(rightNorm));
}

String _slug(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-|-$'), '');

String _day(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
