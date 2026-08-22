import 'dart:math' as math;
import 'dart:ui';

import 'package:archiveme_mobile/features/graph/domain/graph_topology.dart';

/// Coulomb repulsion + Hooke edge attraction force-directed layout.
class GraphForceSimulation {
  GraphForceSimulation({
    required List<GraphLayoutNode> nodes,
    required List<GraphLayoutLink> links,
    this.repulsionStrength = 9000,
    this.maxRepulsionDistance = 420,
    this.centerGravity = 0.015,
    this.damping = 0.82,
    this.maxVelocity = 12,
  }) : _nodes = nodes,
       _links = links;

  final List<GraphLayoutNode> _nodes;
  final List<GraphLayoutLink> _links;

  final double repulsionStrength;
  final double maxRepulsionDistance;
  final double centerGravity;
  final double damping;
  final double maxVelocity;

  List<GraphLayoutNode> get nodes => _nodes;
  List<GraphLayoutLink> get links => _links;

  factory GraphForceSimulation.fromTopology(
    GraphTopology topology, {
    required Size canvasSize,
  }) {
    final random = math.Random(topology.seedEntryId?.hashCode ?? 0);
    final nodes = <GraphLayoutNode>[];
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final radius = math.min(canvasSize.width, canvasSize.height) * 0.28;

    for (var i = 0; i < topology.nodes.length; i++) {
      final record = topology.nodes[i];
      final angle = (i / math.max(1, topology.nodes.length)) * math.pi * 2;
      final jitter = random.nextDouble() * 24 - 12;
      final position = center +
          Offset(
            math.cos(angle) * (radius + jitter),
            math.sin(angle) * (radius + jitter),
          );
      nodes.add(GraphLayoutNode(record: record, position: position));
    }

    final links = topology.links
        .map(
          (link) => GraphLayoutLink(
            fromId: link.fromNodeId,
            toId: link.toNodeId,
            restLength: 110 + (1 - link.weight.clamp(0, 1)) * 40,
            stiffness: 0.03 + link.weight.clamp(0, 1) * 0.03,
          ),
        )
        .toList(growable: false);

    return GraphForceSimulation(nodes: nodes, links: links);
  }

  void tick({Offset center = Offset.zero}) {
    if (_nodes.isEmpty) return;

    final forces = List.generate(_nodes.length, (_) => Offset.zero);
    final indexById = {
      for (var i = 0; i < _nodes.length; i++) _nodes[i].id: i,
    };

    for (var i = 0; i < _nodes.length; i++) {
      for (var j = i + 1; j < _nodes.length; j++) {
        final delta = _nodes[i].position - _nodes[j].position;
        final distance = math.max(delta.distance, 0.01);
        if (distance > maxRepulsionDistance) continue;

        final magnitude = repulsionStrength / (distance * distance);
        final direction = delta / distance;
        final force = direction * magnitude;
        forces[i] += force;
        forces[j] -= force;
      }
    }

    for (final link in _links) {
      final fromIndex = indexById[link.fromId];
      final toIndex = indexById[link.toId];
      if (fromIndex == null || toIndex == null) continue;

      final from = _nodes[fromIndex];
      final to = _nodes[toIndex];
      final delta = to.position - from.position;
      final distance = math.max(delta.distance, 0.01);
      final displacement = distance - link.restLength;
      final direction = delta / distance;
      final force = direction * (displacement * link.stiffness);

      forces[fromIndex] += force;
      forces[toIndex] -= force;
    }

    if (center != Offset.zero) {
      for (var i = 0; i < _nodes.length; i++) {
        forces[i] += (center - _nodes[i].position) * centerGravity;
      }
    }

    for (var i = 0; i < _nodes.length; i++) {
      final node = _nodes[i];
      var velocity = (node.velocity + forces[i] / node.mass) * damping;
      final speed = velocity.distance;
      if (speed > maxVelocity) {
        velocity = velocity / speed * maxVelocity;
      }
      node.velocity = velocity;
      node.position += velocity;
    }
  }
}
