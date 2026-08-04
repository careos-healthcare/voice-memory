import 'dart:math' as math;

import '../../api/api_transport.dart';
import '../../core/graph/personal_knowledge_graph.dart';
import '../../services/capture_attest_service.dart';
import 'semantic_cluster.dart';

typedef ClusterAnonymousToken = String Function();

/// Applies optional cloud naming to a locally-computed cluster.
///
/// Only an anonymized, request-scoped structural projection leaves the device.
/// Any transport, attestation, payload, or response failure returns [cluster].
final class ClusterSynthesisService {
  ClusterSynthesisService({
    required this.transport,
    required this.attest,
    ClusterAnonymousToken? anonymousToken,
  }) : _anonymousToken = anonymousToken ?? _secureAnonymousToken;

  static const int maxNodes = 64;

  final ApiTransport transport;
  final CaptureAttestService attest;
  final ClusterAnonymousToken _anonymousToken;

  Future<SemanticCluster> synthesize({
    required SemanticCluster cluster,
    required PersonalKnowledgeGraph graph,
  }) async {
    try {
      final payload = buildAnonymizedPayload(cluster: cluster, graph: graph);
      final token = await attest.ensureCaptureToken();
      final response = await transport.postJson(
        '/api/cluster-synthesis',
        headers: {
          ...transport.jsonHeaders,
          ApiTransport.captureTokenHeader: token,
          'x-vm-client': 'voicememory-mobile',
        },
        body: payload,
      );
      final result = _parseResult(transport.decodeJson(response));
      return cluster.copyWith(
        title: result.title,
        summary: result.briefSummary,
        category: result.category,
        confidenceScore: result.confidenceScore,
      );
    } catch (_) {
      return cluster;
    }
  }

  /// Exposed for privacy-contract tests and preflight inspection.
  Map<String, Object> buildAnonymizedPayload({
    required SemanticCluster cluster,
    required PersonalKnowledgeGraph graph,
  }) {
    final clusterIds = cluster.nodeIds.toSet();
    final nodes =
        graph.nodes
            .where(
              (node) =>
                  clusterIds.contains(node.id) &&
                  node.archivedAt == null &&
                  node.label.trim().isNotEmpty,
            )
            .toList()
          ..sort((left, right) => left.id.compareTo(right.id));
    final selected = nodes.take(maxNodes).toList(growable: false);
    if (selected.isEmpty) {
      throw const FormatException('Cluster has no structural nodes.');
    }

    final selectedIds = selected.map((node) => node.id).toSet();
    final internalEdges = graph.edges
        .where(
          (edge) =>
              edge.archivedAt == null &&
              selectedIds.contains(edge.sourceNodeId) &&
              selectedIds.contains(edge.targetNodeId),
        )
        .toList(growable: false);
    final degrees = {for (final id in selectedIds) id: 0};
    for (final edge in internalEdges) {
      degrees[edge.sourceNodeId] = degrees[edge.sourceNodeId]! + 1;
      if (edge.targetNodeId != edge.sourceNodeId) {
        degrees[edge.targetNodeId] = degrees[edge.targetNodeId]! + 1;
      }
    }

    final maxActivity = selected.fold<int>(
      0,
      (maximum, node) => math.max(maximum, node.evidence.length),
    );
    final possibleEdges = selected.length < 2
        ? 0
        : selected.length * (selected.length - 1) / 2;
    final averageWeight = internalEdges.isEmpty
        ? 0.0
        : internalEdges.fold<double>(0, (sum, edge) => sum + edge.weight) /
              internalEdges.length;
    final incidentEdges = graph.edges.where(
      (edge) =>
          edge.archivedAt == null &&
          (selectedIds.contains(edge.sourceNodeId) ||
              selectedIds.contains(edge.targetNodeId)),
    );
    final incidentCount = incidentEdges.length;
    final crossingCount = incidentEdges
        .where(
          (edge) =>
              selectedIds.contains(edge.sourceNodeId) !=
              selectedIds.contains(edge.targetNodeId),
        )
        .length;

    return <String, Object>{
      'clusterId': _anonymousId('c'),
      'category': cluster.category.wireName,
      'candidateTitle': _boundedLabel(cluster.title, 120),
      'nodes': <Map<String, Object>>[
        for (var index = 0; index < selected.length; index++)
          {
            'anonymousId': _anonymousId('n$index'),
            'type': _boundedLabel(selected[index].type.name, 48),
            'label': _boundedLabel(selected[index].label, 120),
            'degree': degrees[selected[index].id]!.clamp(0, 10000),
            'activityWeight': maxActivity == 0
                ? 0.0
                : selected[index].evidence.length / maxActivity,
          },
      ],
      'edgeMetrics': <String, Object>{
        'edgeCount': internalEdges.length.clamp(0, 100000),
        'density': possibleEdges == 0
            ? 0.0
            : (internalEdges.length / possibleEdges).clamp(0.0, 1.0),
        'averageWeight': averageWeight.clamp(0.0, 1.0),
      },
      'vectorMetrics': <String, Object>{
        'cohesion': cluster.confidenceScore,
        'separation': incidentCount == 0
            ? 1.0
            : (1 - (crossingCount / incidentCount)).clamp(0.0, 1.0),
        'centroidMagnitude':
            math.sqrt(selected.length) * cluster.confidenceScore,
      },
      'velocityMetrics': <String, Object>{
        'averageVelocity': cluster.activityVelocity,
        'acceleration': 0.0,
        'stability': (1 - cluster.activityVelocity).clamp(0.0, 1.0),
      },
    };
  }

  String _anonymousId(String prefix) {
    var token = _anonymousToken().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    if (token.isEmpty) token = _secureAnonymousToken();
    if (token.length > 96) token = token.substring(0, 96);
    return '${prefix}_$token';
  }

  static String _boundedLabel(String value, int maximumLength) {
    final label = value.trim().replaceAll(
      RegExp(r'[\u0000-\u001F\u007F]'),
      ' ',
    );
    final bounded = label.length <= maximumLength
        ? label
        : label.substring(0, maximumLength);
    if (bounded.trim().isEmpty) {
      throw const FormatException('Structural label is empty.');
    }
    return bounded.trim();
  }

  static _ClusterSynthesisResult _parseResult(Map<String, dynamic> value) {
    const fields = {'title', 'briefSummary', 'category', 'confidenceScore'};
    if (value.keys.toSet().difference(fields).isNotEmpty ||
        fields.difference(value.keys.toSet()).isNotEmpty) {
      throw const FormatException('Invalid cluster synthesis response shape.');
    }
    final title = _strictResponseText(value['title'], 120);
    final summary = _strictResponseText(value['briefSummary'], 320);
    final categoryValue = value['category'];
    final confidence = value['confidenceScore'];
    if (categoryValue is! String ||
        confidence is! num ||
        !confidence.toDouble().isFinite ||
        confidence < 0 ||
        confidence > 1) {
      throw const FormatException('Invalid cluster synthesis response.');
    }
    return (
      title: title,
      briefSummary: summary,
      category: SemanticClusterCategory.parse(categoryValue),
      confidenceScore: confidence.toDouble(),
    );
  }

  static String _strictResponseText(Object? value, int maximumLength) {
    if (value is! String ||
        value.trim().isEmpty ||
        value.length > maximumLength ||
        RegExp(r'[\u0000-\u001F\u007F]').hasMatch(value)) {
      throw const FormatException('Invalid cluster synthesis text.');
    }
    return value.trim();
  }

  static String _secureAnonymousToken() {
    final random = math.Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}

typedef _ClusterSynthesisResult = ({
  String title,
  String briefSummary,
  SemanticClusterCategory category,
  double confidenceScore,
});
