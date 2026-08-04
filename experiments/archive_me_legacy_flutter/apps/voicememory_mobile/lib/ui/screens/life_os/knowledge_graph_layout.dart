import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/graph/graph_node.dart';
import '../../../features/memory_graph/spatial/quad_tree_spatial_index.dart';

/// Immutable, deterministic positions used by the knowledge graph canvas.
class KnowledgeGraphLayout {
  KnowledgeGraphLayout(this.nodes, this.positions, this.size)
    : spatialIndex = _buildIndex(nodes, positions, size);

  final List<GraphNode> nodes;
  final Map<String, Offset> positions;
  final Size size;
  final QuadTreeSpatialIndex<GraphNode> spatialIndex;

  List<GraphNode> nodesIn(Rect viewport) => spatialIndex.query(viewport);

  GraphNode? nodeAt(Offset point) {
    GraphNode? closest;
    var distance = double.infinity;
    for (final node in spatialIndex.query(
      Rect.fromCenter(center: point, width: 64, height: 64),
    )) {
      final position = positions[node.id];
      if (position == null) continue;
      final candidate = (position - point).distance;
      if (candidate <= knowledgeGraphNodeRadius(node) + 7 &&
          candidate < distance) {
        closest = node;
        distance = candidate;
      }
    }
    return closest;
  }

  static QuadTreeSpatialIndex<GraphNode> _buildIndex(
    List<GraphNode> nodes,
    Map<String, Offset> positions,
    Size size,
  ) {
    final index = QuadTreeSpatialIndex<GraphNode>(
      bounds: (Offset.zero & size).inflate(32),
    );
    for (final node in nodes) {
      final center = positions[node.id];
      if (center == null) continue;
      index.insert(
        Rect.fromCircle(
          center: center,
          radius: knowledgeGraphNodeRadius(node) + 9,
        ),
        node,
      );
    }
    return index;
  }
}

/// A bounded force layout whose spatial buckets keep large graphs responsive.
abstract final class ForceDirectedKnowledgeGraphLayout {
  static KnowledgeGraphLayout compute(
    List<GraphNode> nodes,
    List<GraphEdge> edges,
    Size size,
  ) {
    if (nodes.isEmpty) {
      return KnowledgeGraphLayout(const [], const {}, size);
    }
    const padding = 34.0;
    final columns = math.max(1, math.sqrt(nodes.length).ceil());
    final rows = (nodes.length / columns).ceil();
    final positions = <String, Offset>{};
    for (var index = 0; index < nodes.length; index++) {
      final node = nodes[index];
      final hash = _stableHash(node.id);
      final x =
          padding +
          (index % columns + 0.5) * ((size.width - padding * 2) / columns) +
          ((hash & 31) - 15) * 0.32;
      final y =
          padding +
          (index ~/ columns + 0.5) * ((size.height - padding * 2) / rows) +
          (((hash >> 5) & 31) - 15) * 0.32;
      positions[node.id] = Offset(x, y);
    }
    final nodeIds = nodes.map((node) => node.id).toSet();
    final visibleEdges = edges
        .where(
          (edge) =>
              nodeIds.contains(edge.sourceNodeId) &&
              nodeIds.contains(edge.targetNodeId),
        )
        .toList();
    final cellSize = math.max(
      42.0,
      math.sqrt(size.width * size.height / nodes.length) * 1.7,
    );

    final iterationCount = nodes.length > 2000
        ? 0
        : nodes.length > 750
        ? 6
        : 22;
    for (var iteration = 0; iteration < iterationCount; iteration++) {
      final buckets = <(int, int), List<String>>{};
      for (final node in nodes) {
        final point = positions[node.id]!;
        buckets
            .putIfAbsent((
              (point.dx / cellSize).floor(),
              (point.dy / cellSize).floor(),
            ), () => [])
            .add(node.id);
      }
      final forces = {for (final node in nodes) node.id: Offset.zero};
      for (final node in nodes) {
        final point = positions[node.id]!;
        final cell = (
          (point.dx / cellSize).floor(),
          (point.dy / cellSize).floor(),
        );
        var force = Offset.zero;
        for (var dx = -1; dx <= 1; dx++) {
          for (var dy = -1; dy <= 1; dy++) {
            for (final otherId
                in buckets[(cell.$1 + dx, cell.$2 + dy)] ?? const <String>[]) {
              if (otherId == node.id) continue;
              var delta = point - positions[otherId]!;
              var distanceSquared = delta.distanceSquared;
              if (distanceSquared < 0.01) {
                delta = const Offset(0.1, 0.1);
                distanceSquared = 0.02;
              }
              force +=
                  delta / math.sqrt(distanceSquared) * (170 / distanceSquared);
            }
          }
        }
        forces[node.id] = force;
      }
      for (final edge in visibleEdges) {
        final source = positions[edge.sourceNodeId]!;
        final target = positions[edge.targetNodeId]!;
        final delta = target - source;
        final distance = math.max(1.0, delta.distance);
        final attraction =
            delta / distance * ((distance - cellSize * 0.9) * 0.018);
        forces[edge.sourceNodeId] =
            forces[edge.sourceNodeId]! + attraction * edge.weight;
        forces[edge.targetNodeId] =
            forces[edge.targetNodeId]! - attraction * edge.weight;
      }
      final cooling = 1 - iteration / math.max(iterationCount + 4, 1);
      for (final node in nodes) {
        final point = positions[node.id]!;
        final centerPull =
            (Offset(size.width / 2, size.height / 2) - point) * 0.002;
        final force = forces[node.id]! + centerPull;
        final magnitude = force.distance;
        final bounded = magnitude > 9 ? force / magnitude * 9.0 : force;
        positions[node.id] = Offset(
          (point.dx + bounded.dx * cooling).clamp(
            padding,
            size.width - padding,
          ),
          (point.dy + bounded.dy * cooling).clamp(
            padding,
            size.height - padding,
          ),
        );
      }
    }
    return KnowledgeGraphLayout(
      List.unmodifiable(nodes),
      Map.unmodifiable(positions),
      size,
    );
  }

  static int _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return hash;
  }
}

double knowledgeGraphNodeRadius(GraphNode node) {
  final evidenceRadius = 8 + math.sqrt(node.evidence.length + 1) * 2.2;
  final maturityScale = .72 + node.confidence.clamp(0, 1) * .58;
  return (evidenceRadius * maturityScale).clamp(8, 24);
}
