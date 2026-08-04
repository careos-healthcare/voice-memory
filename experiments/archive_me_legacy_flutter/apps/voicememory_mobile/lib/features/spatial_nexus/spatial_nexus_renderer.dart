import 'dart:math' as math;

import '../../core/graph/personal_knowledge_graph.dart';
import '../horizon_lab/horizon_models.dart';
import '../semantic_clusters/semantic_cluster.dart';
import 'spatial_nexus_models.dart';

abstract interface class SpatialNativeRendererBackend {
  Future<List<SpatialCapability>> capabilities();
}

final class UnavailableSpatialNativeRendererBackend
    implements SpatialNativeRendererBackend {
  const UnavailableSpatialNativeRendererBackend();

  @override
  Future<List<SpatialCapability>> capabilities() async => const [
    SpatialCapability.unavailable(
      SpatialNativeCapability.metal,
      'Metal renderer binary is not packaged.',
    ),
    SpatialCapability.unavailable(
      SpatialNativeCapability.vulkan,
      'Vulkan renderer binary is not packaged.',
    ),
    SpatialCapability.unavailable(
      SpatialNativeCapability.hrtf,
      'Native HRTF audio binary is not packaged.',
    ),
    SpatialCapability.unavailable(
      SpatialNativeCapability.visionOs,
      'VisionOS spatial controller runtime is not packaged.',
    ),
    SpatialCapability.unavailable(
      SpatialNativeCapability.openXr,
      'OpenXR controller runtime is not packaged.',
    ),
  ];
}

final class SpatialNexusRenderer {
  SpatialNexusRenderer({
    this.maxNodes = 512,
    this.nativeBackend = const UnavailableSpatialNativeRendererBackend(),
  }) : assert(maxNodes > 0);

  final int maxNodes;
  final SpatialNativeRendererBackend nativeBackend;

  Future<List<SpatialCapability>> capabilities() =>
      nativeBackend.capabilities();

  SpatialScene buildScene({
    required PersonalKnowledgeGraph graph,
    List<SemanticCluster> clusters = const [],
    List<TimelineBranch> horizonBranches = const [],
    SpatialEnvironmentPreset preset = SpatialEnvironmentPreset.neuralVoid,
  }) {
    final selected = graph.nodes.take(maxNodes).toList(growable: false);
    final selectedIds = selected.map((node) => node.id).toSet();
    final clusterByNode = <String, String>{};
    for (final cluster in clusters) {
      for (final nodeId in cluster.nodeIds) {
        clusterByNode.putIfAbsent(nodeId, () => cluster.id);
      }
    }
    final valenceTotals = <String, double>{};
    final valenceCounts = <String, int>{};
    for (final edge in graph.edges) {
      final valence = edge.emotionalValenceScore;
      if (valence == null) continue;
      for (final id in [edge.sourceNodeId, edge.targetNodeId]) {
        valenceTotals[id] = (valenceTotals[id] ?? 0) + valence;
        valenceCounts[id] = (valenceCounts[id] ?? 0) + 1;
      }
    }
    final nodes = <SpatialNode>[
      for (final node in selected)
        SpatialNode(
          id: node.id,
          label: node.label,
          type: node.type.name,
          position: _seedPosition(node.id, clusterByNode[node.id]),
          velocity: const SpatialVector3.zero(),
          radius: .12 + node.confidence * .12,
          valence:
              (valenceTotals[node.id] ?? 0) / (valenceCounts[node.id] ?? 1),
          clusterId: clusterByNode[node.id],
          isHorizonProjection: false,
        ),
    ];
    final edges = <SpatialEdge>[
      for (final edge in graph.edges)
        if (selectedIds.contains(edge.sourceNodeId) &&
            selectedIds.contains(edge.targetNodeId))
          SpatialEdge(
            sourceId: edge.sourceNodeId,
            targetId: edge.targetNodeId,
            weight: edge.weight,
          ),
    ];
    for (final branch in horizonBranches) {
      for (final projection in branch.projections) {
        if (nodes.length >= maxNodes) break;
        final id = 'horizon:${branch.id}:${projection.id}';
        nodes.add(
          SpatialNode(
            id: id,
            label: projection.label,
            type: projection.type.name,
            position:
                _seedPosition(id, branch.id) + const SpatialVector3(0, 0, -2),
            velocity: const SpatialVector3.zero(),
            radius: .1 + projection.probability * .14,
            valence: projection.risks.alignment * 2 - 1,
            clusterId: 'horizon:${branch.id}',
            isHorizonProjection: true,
          ),
        );
        if (selectedIds.contains(branch.divergenceNodeId)) {
          edges.add(
            SpatialEdge(
              sourceId: branch.divergenceNodeId,
              targetId: id,
              weight: projection.probability,
            ),
          );
        }
      }
    }
    return SpatialScene(
      nodes: List.unmodifiable(nodes),
      edges: List.unmodifiable(edges),
      preset: preset,
    );
  }

  SpatialScene simulate(
    SpatialScene scene, {
    double timeStep = 1 / 60,
    int iterations = 1,
  }) {
    final dt = timeStep.clamp(0.001, .05);
    var nodes = scene.nodes;
    for (var iteration = 0; iteration < iterations.clamp(1, 12); iteration++) {
      final forces = List<SpatialVector3>.filled(
        nodes.length,
        const SpatialVector3.zero(),
      );
      final indexById = {
        for (var index = 0; index < nodes.length; index++)
          nodes[index].id: index,
      };
      for (var left = 0; left < nodes.length; left++) {
        for (var right = left + 1; right < nodes.length; right++) {
          var delta = nodes[left].position - nodes[right].position;
          var distance = delta.length;
          if (distance < 1e-5) {
            delta = SpatialVector3(.001 * (right + 1), 0, 0);
            distance = delta.length;
          }
          final minimum = nodes[left].radius + nodes[right].radius + .04;
          final repulsion = .018 / math.max(distance * distance, .01);
          final collision = distance < minimum ? (minimum - distance) * 3 : 0;
          final force = delta.normalized() * (repulsion + collision);
          forces[left] = forces[left] + force;
          forces[right] = forces[right] - force;
        }
      }
      for (final edge in scene.edges) {
        final source = indexById[edge.sourceId];
        final target = indexById[edge.targetId];
        if (source == null || target == null) continue;
        final delta = nodes[target].position - nodes[source].position;
        final attraction =
            delta.normalized() * ((delta.length - 1.2) * .12 * edge.weight);
        forces[source] = forces[source] + attraction;
        forces[target] = forces[target] - attraction;
      }
      for (var index = 0; index < nodes.length; index++) {
        final node = nodes[index];
        final anchor = _clusterAnchor(node.clusterId);
        forces[index] =
            forces[index] +
            (anchor - node.position) * .025 -
            node.position * .004;
      }
      nodes = List.generate(nodes.length, (index) {
        final velocity = (nodes[index].velocity + forces[index] * dt) * .92;
        return nodes[index].copyWith(
          velocity: velocity,
          position: nodes[index].position + velocity,
        );
      }, growable: false);
    }
    return scene.copyWith(nodes: List.unmodifiable(nodes));
  }

  List<SpatialProjectedNode> project({
    required SpatialScene scene,
    required SpatialCamera camera,
    required double viewportWidth,
    required double viewportHeight,
  }) {
    if (viewportWidth <= 0 || viewportHeight <= 0) return const [];
    final aspect = viewportWidth / viewportHeight;
    final focal = 1 / math.tan(camera.fieldOfViewRadians / 2);
    final projected = <SpatialProjectedNode>[];
    for (final node in scene.nodes) {
      final relative = node.position - camera.position;
      final depth = -relative.z;
      if (depth < camera.near || depth > camera.far) continue;
      final normalizedX = relative.x * focal / (depth * aspect);
      final normalizedY = relative.y * focal / depth;
      final margin = node.radius / math.max(depth, .01);
      if (normalizedX.abs() > 1 + margin || normalizedY.abs() > 1 + margin) {
        continue;
      }
      projected.add(
        SpatialProjectedNode(
          node: node,
          screenX: (normalizedX + 1) * .5 * viewportWidth,
          screenY: (1 - normalizedY) * .5 * viewportHeight,
          depth: depth,
          scale: (focal / depth).clamp(.08, 4),
          blurSigma: ((depth - 5) / 5).clamp(0, 6),
        ),
      );
    }
    projected.sort((left, right) => right.depth.compareTo(left.depth));
    return List.unmodifiable(projected);
  }

  SpatialVector3 _seedPosition(String id, String? clusterId) {
    final seed = _hash(id);
    final cluster = _clusterAnchor(clusterId);
    return cluster +
        SpatialVector3(
          ((seed & 0x3ff) / 1023 - .5) * 2.4,
          (((seed >> 10) & 0x3ff) / 1023 - .5) * 2.4,
          (((seed >> 20) & 0x3ff) / 1023 - .5) * 2.4,
        );
  }

  SpatialVector3 _clusterAnchor(String? clusterId) {
    if (clusterId == null) return const SpatialVector3.zero();
    final seed = _hash(clusterId);
    final angle = (seed % 360) * math.pi / 180;
    final elevation = (((seed >> 9) % 180) - 90) * math.pi / 360;
    return SpatialVector3(
      math.cos(angle) * math.cos(elevation) * 2.2,
      math.sin(elevation) * 1.4,
      math.sin(angle) * math.cos(elevation) * 2.2,
    );
  }
}

int _hash(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}
