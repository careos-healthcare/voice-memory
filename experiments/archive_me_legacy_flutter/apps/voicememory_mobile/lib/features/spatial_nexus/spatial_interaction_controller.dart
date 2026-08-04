import 'dart:math' as math;

import '../omni_search/omni_search_engine.dart';
import '../omni_search/search_graph_focus.dart';
import '../omni_search/search_query_translator.dart';
import 'spatial_nexus_models.dart';

final class SpatialInteractionController {
  const SpatialInteractionController();

  SpatialCamera pinch(SpatialCamera camera, double scaleDelta) {
    if (!scaleDelta.isFinite || scaleDelta <= 0) return camera;
    final nextZ = (camera.position.z / scaleDelta).clamp(1.5, 30);
    return camera.copyWith(
      position: SpatialVector3(
        camera.position.x,
        camera.position.y,
        nextZ.toDouble(),
      ),
    );
  }

  SpatialScene pullCluster({
    required SpatialScene scene,
    required String clusterId,
    required SpatialVector3 delta,
    double maxDisplacement = 3,
  }) {
    final bounded = delta.length > maxDisplacement
        ? delta.normalized() * maxDisplacement
        : delta;
    return scene.copyWith(
      nodes: List.unmodifiable([
        for (final node in scene.nodes)
          if (node.clusterId == clusterId)
            node.copyWith(position: node.position + bounded)
          else
            node,
      ]),
    );
  }

  SpatialNode? pick({
    required Iterable<SpatialProjectedNode> projected,
    required double x,
    required double y,
    double hitRadius = 28,
  }) {
    SpatialProjectedNode? winner;
    var best = double.infinity;
    for (final item in projected) {
      final distance = math.sqrt(
        math.pow(item.screenX - x, 2) + math.pow(item.screenY - y, 2),
      );
      final radius = math.max(hitRadius, item.node.radius * item.scale * 160);
      if (distance <= radius && distance < best) {
        best = distance;
        winner = item;
      }
    }
    return winner?.node;
  }
}

final class SpatialVoiceNavigator {
  const SpatialVoiceNavigator({
    required this.translator,
    required this.search,
    required this.focus,
  });

  final SearchQueryTranslator translator;
  final OmniSearchEngine search;
  final SearchGraphFocus focus;

  Future<String?> navigate(String command) async {
    final normalized = command.trim().replaceFirst(
      RegExp(r'^take me to\s+', caseSensitive: false),
      '',
    );
    if (normalized.isEmpty) return null;
    final intent = await translator.translate(normalized);
    final results = await search.search(intent, limitPerSection: 1);
    final node = results.graphNodes.firstOrNull?.candidate.node;
    if (node == null) return null;
    focus.focus(node.id);
    return node.id;
  }
}
