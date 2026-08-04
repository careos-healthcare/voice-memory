import 'dart:convert';
import 'dart:typed_data';

import '../../core/graph/personal_knowledge_graph_store.dart';
import '../../core/graph/personal_knowledge_graph.dart';
import '../cognitive_analytics/cognitive_metrics_engine.dart';
import '../cognitive_analytics/cognitive_metrics_models.dart';
import 'sandbox_models.dart';

typedef SandboxGraphLoader = Future<PersonalKnowledgeGraph> Function();
typedef SandboxMetricsLoader = Future<CognitiveMetricsSnapshot> Function();

final class SandboxDataConnector {
  factory SandboxDataConnector({
    required PersonalKnowledgeGraphStore graphStore,
    required CognitiveMetricsEngine metricsEngine,
  }) => SandboxDataConnector.loaders(
    graphLoader: graphStore.load,
    metricsLoader: () =>
        metricsEngine.calculate(CognitiveTimeRange.allTime, refresh: false),
  );

  factory SandboxDataConnector.loaders({
    required SandboxGraphLoader graphLoader,
    required SandboxMetricsLoader metricsLoader,
  }) => SandboxDataConnector._(graphLoader, metricsLoader);

  const SandboxDataConnector._(this._graphLoader, this._metricsLoader);

  final SandboxGraphLoader _graphLoader;
  final SandboxMetricsLoader _metricsLoader;

  Future<Uint8List> createView(SandboxDataViewRequest request) async {
    if (request.maximumRows < 1 || request.maximumRows > 1000) {
      throw const FormatException('Sandbox row limit is invalid.');
    }
    if (request.maximumBytes < 128 || request.maximumBytes > 1024 * 1024) {
      throw const FormatException('Sandbox byte limit is invalid.');
    }
    final envelope = switch (request.grant) {
      SandboxDataGrant.graphNodes => await _graphNodes(request),
      SandboxDataGrant.cognitiveMetrics => await _metrics(request),
    };
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
    if (bytes.length > request.maximumBytes) {
      bytes.fillRange(0, bytes.length, 0);
      throw const FormatException(
        'Filtered sandbox data exceeds its byte limit.',
      );
    }
    return bytes;
  }

  Future<Map<String, Object?>> _graphNodes(
    SandboxDataViewRequest request,
  ) async {
    if (request.nodeIds.isEmpty) {
      throw const FormatException('Graph views require explicit node ids.');
    }
    final selected = request.nodeIds.take(request.maximumRows).toSet();
    final graph = await _graphLoader();
    final nodes =
        graph.nodes.where((node) => selected.contains(node.id)).toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    return {
      'schemaVersion': 1,
      'grant': SandboxDataGrant.graphNodes.name,
      'rows': [
        for (final node in nodes)
          {
            'id': node.id,
            'type': node.type.name,
            'label': node.label,
            'confidence': node.confidence,
            'createdAt': node.createdAt.toUtc().toIso8601String(),
            'tags': node.tags.toList()..sort(),
          },
      ],
    };
  }

  Future<Map<String, Object?>> _metrics(SandboxDataViewRequest request) async {
    final snapshot = await _metricsLoader();
    final points = snapshot.points
        .where(
          (point) =>
              (request.start == null ||
                  !point.day.isBefore(request.start!.toUtc())) &&
              (request.end == null || !point.day.isAfter(request.end!.toUtc())),
        )
        .take(request.maximumRows);
    return {
      'schemaVersion': 1,
      'grant': SandboxDataGrant.cognitiveMetrics.name,
      'rows': [
        for (final point in points)
          {
            'day': point.day.toUtc().toIso8601String(),
            'valence': point.valence,
            'movingAverage7': point.movingAverage7,
            'movingAverage30': point.movingAverage30,
            'movingAverage90': point.movingAverage90,
            'cognitiveLoad': point.cognitiveLoad,
            'semanticVelocity': point.semanticVelocity,
            'habitMomentum': point.habitMomentum,
            'sleepHours': point.sleepHours,
            'journalCount': point.journalCount,
            'negativeClusterDensity': point.negativeClusterDensity,
            'activeNodeCount': point.activeNodeCount,
            'resolvedClusterCount': point.resolvedClusterCount,
          },
      ],
    };
  }
}
