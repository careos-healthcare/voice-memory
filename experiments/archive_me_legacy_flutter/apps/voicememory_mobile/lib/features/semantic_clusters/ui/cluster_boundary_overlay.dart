import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../core/graph/graph_node.dart';
import '../../../ui/screens/life_os/knowledge_graph_layout.dart';
import '../semantic_cluster.dart';

Color semanticClusterCategoryColor(SemanticClusterCategory category) =>
    switch (category) {
      SemanticClusterCategory.theme => const Color(0xFF7C3AED),
      SemanticClusterCategory.project => const Color(0xFF0284C7),
      SemanticClusterCategory.peopleNetwork => const Color(0xFFDB2777),
      SemanticClusterCategory.habitCluster => const Color(0xFF16A34A),
      SemanticClusterCategory.belief => const Color(0xFFD97706),
    };

String semanticClusterCategoryLabel(SemanticClusterCategory category) =>
    switch (category) {
      SemanticClusterCategory.theme => 'Theme',
      SemanticClusterCategory.project => 'Project',
      SemanticClusterCategory.peopleNetwork => 'People network',
      SemanticClusterCategory.habitCluster => 'Habit cluster',
      SemanticClusterCategory.belief => 'Belief',
    };

@immutable
class ClusterBoundary {
  const ClusterBoundary({
    required this.cluster,
    required this.path,
    required this.bounds,
  });

  final SemanticCluster cluster;
  final Path path;
  final Rect bounds;
}

class ClusterBoundaryOverlay extends StatelessWidget {
  const ClusterBoundaryOverlay({
    super.key,
    required this.layout,
    required this.clusters,
    this.focusClusterId,
    this.onClusterSelected,
  });

  final KnowledgeGraphLayout layout;
  final List<SemanticCluster> clusters;
  final String? focusClusterId;
  final ValueChanged<SemanticCluster>? onClusterSelected;

  @override
  Widget build(BuildContext context) => CustomPaint(
    key: const Key('semantic-cluster-boundary-overlay'),
    painter: ClusterBoundaryPainter(
      layout: layout,
      clusters: clusters,
      focusClusterId: focusClusterId,
      onSemanticTap: onClusterSelected,
    ),
  );
}

class ClusterBoundaryPainter extends CustomPainter {
  ClusterBoundaryPainter({
    required this.layout,
    required this.clusters,
    this.focusClusterId,
    this.onSemanticTap,
  }) : boundaries = _buildBoundaries(layout, clusters, focusClusterId);

  final KnowledgeGraphLayout layout;
  final List<SemanticCluster> clusters;
  final String? focusClusterId;
  final ValueChanged<SemanticCluster>? onSemanticTap;
  final List<ClusterBoundary> boundaries;

  SemanticCluster? clusterAt(Offset position) {
    for (final boundary in boundaries.reversed) {
      if (boundary.bounds.contains(position) &&
          boundary.path.contains(position)) {
        return boundary.cluster;
      }
    }
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final boundary in boundaries) {
      final focused = boundary.cluster.id == focusClusterId;
      final color = semanticClusterCategoryColor(boundary.cluster.category);
      canvas.drawPath(
        boundary.path,
        Paint()
          ..color = color.withValues(alpha: focused ? .24 : .11)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, focused ? 18 : 12),
      );
      canvas.drawPath(
        boundary.path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: focused ? .28 : .18),
              color.withValues(alpha: focused ? .18 : .08),
            ],
          ).createShader(boundary.bounds)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        boundary.path,
        Paint()
          ..color = color.withValues(alpha: focused ? .9 : .55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = focused ? 2.5 : 1.4,
      );
    }
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder =>
      (size) => [
        for (final boundary in boundaries)
          CustomPainterSemantics(
            rect: boundary.bounds,
            properties: SemanticsProperties(
              label:
                  '${semanticClusterCategoryLabel(boundary.cluster.category)} '
                  'cluster, ${boundary.cluster.title}, '
                  '${boundary.cluster.nodeIds.length} members',
              hint: 'Shows this cluster in the knowledge graph',
              textDirection: TextDirection.ltr,
              button: onSemanticTap != null,
              selected: boundary.cluster.id == focusClusterId,
              onTap: onSemanticTap == null
                  ? null
                  : () => onSemanticTap!(boundary.cluster),
            ),
          ),
      ];

  @override
  bool shouldRepaint(covariant ClusterBoundaryPainter oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.clusters != clusters ||
      oldDelegate.focusClusterId != focusClusterId;

  @override
  bool shouldRebuildSemantics(covariant ClusterBoundaryPainter oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.clusters != clusters ||
      oldDelegate.focusClusterId != focusClusterId ||
      oldDelegate.onSemanticTap != onSemanticTap;

  static List<ClusterBoundary> _buildBoundaries(
    KnowledgeGraphLayout layout,
    List<SemanticCluster> clusters,
    String? focusClusterId,
  ) {
    final result = <ClusterBoundary>[];
    for (final cluster in clusters) {
      final nodes = <GraphNode>[];
      for (final node in layout.nodes) {
        if (cluster.nodeIds.contains(node.id) &&
            layout.positions.containsKey(node.id)) {
          nodes.add(node);
        }
      }
      if (nodes.isEmpty) continue;
      final points = [for (final node in nodes) layout.positions[node.id]!];
      final padding =
          nodes.map(knowledgeGraphNodeRadius).fold(0.0, math.max) + 24;
      final path = _organicHull(points, padding);
      result.add(
        ClusterBoundary(cluster: cluster, path: path, bounds: path.getBounds()),
      );
    }
    result.sort((left, right) {
      if (left.cluster.id == focusClusterId) return 1;
      if (right.cluster.id == focusClusterId) return -1;
      return right.bounds.size.longestSide.compareTo(
        left.bounds.size.longestSide,
      );
    });
    return List.unmodifiable(result);
  }

  static Path _organicHull(List<Offset> points, double padding) {
    if (points.length == 1) {
      return Path()
        ..addOval(Rect.fromCircle(center: points.single, radius: padding));
    }
    if (points.length == 2) {
      final start = points.first;
      final end = points.last;
      final direction = end - start;
      final angle = math.atan2(direction.dy, direction.dx);
      final path = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: (start + end) / 2,
              width: direction.distance + padding * 2,
              height: padding * 2,
            ),
            Radius.circular(padding),
          ),
        );
      return path.transform(
        (Matrix4.identity()
              ..translateByDouble(
                (start.dx + end.dx) / 2,
                (start.dy + end.dy) / 2,
                0,
                1,
              )
              ..rotateZ(angle)
              ..translateByDouble(
                -(start.dx + end.dx) / 2,
                -(start.dy + end.dy) / 2,
                0,
                1,
              ))
            .storage,
      );
    }

    final hull = _convexHull(points);
    final center =
        hull.fold(Offset.zero, (sum, point) => sum + point) /
        hull.length.toDouble();
    final expanded = [
      for (final point in hull)
        point +
            (point - center) /
                math.max((point - center).distance, .001) *
                padding,
    ];
    Offset midpoint(Offset a, Offset b) => (a + b) / 2;
    final path = Path()
      ..moveTo(
        midpoint(expanded.last, expanded.first).dx,
        midpoint(expanded.last, expanded.first).dy,
      );
    for (var index = 0; index < expanded.length; index++) {
      final point = expanded[index];
      final next = expanded[(index + 1) % expanded.length];
      final end = midpoint(point, next);
      path.quadraticBezierTo(point.dx, point.dy, end.dx, end.dy);
    }
    return path..close();
  }

  static List<Offset> _convexHull(List<Offset> input) {
    final points = input.toSet().toList()
      ..sort((a, b) {
        final x = a.dx.compareTo(b.dx);
        return x != 0 ? x : a.dy.compareTo(b.dy);
      });
    if (points.length <= 2) return points;
    double cross(Offset origin, Offset a, Offset b) =>
        (a.dx - origin.dx) * (b.dy - origin.dy) -
        (a.dy - origin.dy) * (b.dx - origin.dx);
    final lower = <Offset>[];
    for (final point in points) {
      while (lower.length >= 2 &&
          cross(lower[lower.length - 2], lower.last, point) <= 0) {
        lower.removeLast();
      }
      lower.add(point);
    }
    final upper = <Offset>[];
    for (final point in points.reversed) {
      while (upper.length >= 2 &&
          cross(upper[upper.length - 2], upper.last, point) <= 0) {
        upper.removeLast();
      }
      upper.add(point);
    }
    return [...lower..removeLast(), ...upper..removeLast()];
  }
}
