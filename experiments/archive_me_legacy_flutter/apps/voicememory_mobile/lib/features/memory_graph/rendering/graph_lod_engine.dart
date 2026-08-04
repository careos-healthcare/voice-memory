import 'package:flutter/foundation.dart';

enum GraphLODLevel { far, mid, close }

@immutable
final class GraphLODPolicy {
  const GraphLODPolicy({
    required this.level,
    required this.showLabels,
    required this.showShadows,
    required this.showMediaBadges,
    required this.showAnimations,
    required this.showDirectedArrows,
    required this.maximumLabels,
    required this.edgeStride,
  });

  final GraphLODLevel level;
  final bool showLabels;
  final bool showShadows;
  final bool showMediaBadges;
  final bool showAnimations;
  final bool showDirectedArrows;
  final int maximumLabels;

  /// Draw one out of every [edgeStride] non-highlighted edges.
  final int edgeStride;
}

abstract final class GraphLODEngine {
  static GraphLODPolicy forScale(double scale, {int qualityPenalty = 0}) {
    final requested = !scale.isFinite || scale < .5
        ? GraphLODLevel.far
        : scale <= 1.5
        ? GraphLODLevel.mid
        : GraphLODLevel.close;
    final resolvedIndex = (requested.index - qualityPenalty).clamp(
      GraphLODLevel.far.index,
      GraphLODLevel.close.index,
    );
    return _policy(GraphLODLevel.values[resolvedIndex]);
  }

  static GraphLODPolicy _policy(GraphLODLevel level) => switch (level) {
    GraphLODLevel.far => const GraphLODPolicy(
      level: GraphLODLevel.far,
      showLabels: false,
      showShadows: false,
      showMediaBadges: false,
      showAnimations: false,
      showDirectedArrows: false,
      maximumLabels: 0,
      edgeStride: 3,
    ),
    GraphLODLevel.mid => const GraphLODPolicy(
      level: GraphLODLevel.mid,
      showLabels: true,
      showShadows: false,
      showMediaBadges: true,
      showAnimations: false,
      showDirectedArrows: true,
      maximumLabels: 36,
      edgeStride: 1,
    ),
    GraphLODLevel.close => const GraphLODPolicy(
      level: GraphLODLevel.close,
      showLabels: true,
      showShadows: true,
      showMediaBadges: true,
      showAnimations: true,
      showDirectedArrows: true,
      maximumLabels: 80,
      edgeStride: 1,
    ),
  };
}
