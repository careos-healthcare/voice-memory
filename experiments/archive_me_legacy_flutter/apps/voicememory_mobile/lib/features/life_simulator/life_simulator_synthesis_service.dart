import 'dart:math' as math;

import '../../api/api_transport.dart';
import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph.dart';
import '../../services/capture_attest_service.dart';
import '../ai_engines/models/ai_explainability.dart';
import 'life_simulator_models.dart';

typedef LifeSimulatorOpaqueToken = String Function();

/// Adds optional cloud-authored narrative and scalar scores to a local
/// simulation without sending personal graph content off-device.
final class LifeSimulatorSynthesisService {
  LifeSimulatorSynthesisService({
    required this.transport,
    required this.attest,
    LifeSimulatorOpaqueToken? opaqueToken,
  }) : _opaqueToken = opaqueToken ?? _secureOpaqueToken;

  static const _horizons = [30, 90, 365];
  static const _maxNodes = 64;
  static const _maxEdges = 128;
  static const _maxCitations = 64;

  final ApiTransport transport;
  final CaptureAttestService attest;
  final LifeSimulatorOpaqueToken _opaqueToken;

  Future<CounterfactualScenario> synthesize({
    required CounterfactualScenario scenario,
    required PersonalKnowledgeGraph graph,
  }) async {
    try {
      final prepared = _prepare(scenario: scenario, graph: graph);
      final token = await attest.ensureCaptureToken();
      final response = await transport.postJson(
        '/api/life-simulator',
        headers: {
          ...transport.jsonHeaders,
          ApiTransport.captureTokenHeader: token,
          'x-vm-client': 'voicememory-mobile',
        },
        body: prepared.payload,
      );
      final parsed = _parseResult(
        transport.decodeJson(response),
        prepared: prepared,
      );
      return CounterfactualScenario(
        id: scenario.id,
        continueTrajectory: _mergeTrajectory(
          scenario.continueTrajectory,
          parsed.continuing,
        ),
        alternativeTrajectory: _mergeTrajectory(
          scenario.alternativeTrajectory,
          parsed.alternative,
        ),
      );
    } catch (_) {
      return scenario;
    }
  }

  /// Exposed for privacy-contract tests and preflight inspection.
  Map<String, Object> buildAnonymizedPayload({
    required CounterfactualScenario scenario,
    required PersonalKnowledgeGraph graph,
  }) => _prepare(scenario: scenario, graph: graph).payload;

  _PreparedRequest _prepare({
    required CounterfactualScenario scenario,
    required PersonalKnowledgeGraph graph,
  }) {
    final graphNodes = {for (final node in graph.nodes) node.id: node};
    final graphEdges = {for (final edge in graph.edges) edge.id: edge};
    final requestedNodeIds = <String>{};
    final requestedEdgeIds = <String>{};
    for (final trajectory in [
      scenario.continueTrajectory,
      scenario.alternativeTrajectory,
    ]) {
      for (final milestone in trajectory.milestones) {
        requestedNodeIds
          ..addAll(milestone.projectedNodeScores.keys)
          ..addAll(milestone.affectedNodeIds);
        requestedEdgeIds
          ..addAll(milestone.projectedEdgeWeights.keys)
          ..addAll(milestone.affectedEdgeIds);
      }
    }
    final target = scenario.continueTrajectory.target;
    if (target.kind != SimulationTargetKind.semanticCluster) {
      requestedNodeIds.add(target.referenceId);
    }
    requestedNodeIds.removeWhere((id) => !graphNodes.containsKey(id));
    requestedEdgeIds.removeWhere((id) => !graphEdges.containsKey(id));
    for (final edgeId in requestedEdgeIds.toList()) {
      final edge = graphEdges[edgeId]!;
      requestedNodeIds
        ..add(edge.sourceNodeId)
        ..add(edge.targetNodeId);
    }
    if (requestedNodeIds.isEmpty) {
      throw const FormatException('Simulation has no graph nodes.');
    }
    if (requestedNodeIds.length > _maxNodes ||
        requestedEdgeIds.length > _maxEdges) {
      throw const FormatException('Simulation exceeds synthesis limits.');
    }

    final nodes = requestedNodeIds.map((id) => graphNodes[id]!).toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    final selectedNodeIds = nodes.map((node) => node.id).toSet();
    final edges =
        requestedEdgeIds
            .map((id) => graphEdges[id]!)
            .where(
              (edge) =>
                  selectedNodeIds.contains(edge.sourceNodeId) &&
                  selectedNodeIds.contains(edge.targetNodeId),
            )
            .toList()
          ..sort((left, right) => left.id.compareTo(right.id));

    final usedOpaqueIds = <String>{};
    final nodeOpaqueByLocal = <String, String>{
      for (final node in nodes) node.id: _uniqueOpaque('n', usedOpaqueIds),
    };
    final edgeOpaqueByLocal = <String, String>{
      for (final edge in edges) edge.id: _uniqueOpaque('e', usedOpaqueIds),
    };
    final localIdByOpaque = <String, String>{
      for (final entry in nodeOpaqueByLocal.entries) entry.value: entry.key,
      for (final entry in edgeOpaqueByLocal.entries) entry.value: entry.key,
    };

    final localCitations = _localCitations(nodes, edges);
    final citationByOpaque = <String, _LocalCitation>{};
    for (final citation in localCitations.take(_maxCitations)) {
      final opaque = _uniqueOpaque('c', usedOpaqueIds);
      citationByOpaque[opaque] = citation;
    }

    final latestEvidence = localCitations.isEmpty
        ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
        : localCitations
              .map((item) => item.observedAt)
              .reduce((left, right) => left.isAfter(right) ? left : right);
    final topology = _topology(nodes, edges);
    final targetNode = target.kind == SimulationTargetKind.semanticCluster
        ? null
        : graphNodes[target.referenceId];

    return _PreparedRequest(
      payload: <String, Object>{
        'target': <String, Object>{
          'categoryToken': target.kind.wireName,
          'typeToken': targetNode == null
              ? _token(target.kind.name)
              : _token(targetNode.type.name),
        },
        'nodes': <Map<String, Object>>[
          for (final node in nodes)
            {
              'id': nodeOpaqueByLocal[node.id]!,
              'typeToken': _token(node.type.name),
              'weight': node.confidence,
            },
        ],
        'edges': <Map<String, Object>>[
          for (final edge in edges)
            {
              'id': edgeOpaqueByLocal[edge.id]!,
              'sourceNodeId': nodeOpaqueByLocal[edge.sourceNodeId]!,
              'targetNodeId': nodeOpaqueByLocal[edge.targetNodeId]!,
              'typeToken': _token(edge.type.name),
              'weight': edge.weight,
            },
        ],
        'aggregateTopology': topology,
        'historicalDeltas': _historicalDeltas(graph, nodes, nodeOpaqueByLocal),
        'externalCorrelationSummaries': _externalCorrelations(scenario, graph),
        'citations': <Map<String, Object>>[
          for (final entry in citationByOpaque.entries)
            {
              'handle': entry.key,
              'signalToken': entry.value.signalToken,
              'direction': _direction(entry.value.confidence - .5),
              'strength': entry.value.confidence,
              'recencyDays': math
                  .max(
                    0,
                    latestEvidence.difference(entry.value.observedAt).inDays,
                  )
                  .clamp(0, 3650),
            },
        ],
      },
      localIdByOpaque: Map.unmodifiable(localIdByOpaque),
      nodeIds: Set.unmodifiable(selectedNodeIds),
      citationByOpaque: Map.unmodifiable(citationByOpaque),
    );
  }

  List<_LocalCitation> _localCitations(
    List<GraphNode> nodes,
    List<GraphEdge> edges,
  ) {
    final byHandle = <String, _LocalCitation>{};
    for (final node in nodes) {
      for (final evidence in node.evidence) {
        final handle = _localHandle(
          evidence.entryId,
          evidence.startUtf16,
          evidence.endUtf16,
        );
        byHandle.putIfAbsent(
          handle,
          () => _LocalCitation(
            localHandle: handle,
            sourceEntryId: evidence.entryId,
            exactQuote: evidence.excerpt,
            startUtf16: evidence.startUtf16,
            endUtf16: evidence.endUtf16,
            confidence: evidence.confidence,
            observedAt: evidence.observedAt,
            signalToken: 'node-${_token(node.type.name)}',
          ),
        );
      }
    }
    for (final edge in edges) {
      for (final evidence in edge.evidence) {
        final handle = _localHandle(
          evidence.entryId,
          evidence.startUtf16,
          evidence.endUtf16,
        );
        byHandle.putIfAbsent(
          handle,
          () => _LocalCitation(
            localHandle: handle,
            sourceEntryId: evidence.entryId,
            exactQuote: evidence.excerpt,
            startUtf16: evidence.startUtf16,
            endUtf16: evidence.endUtf16,
            confidence: evidence.confidence,
            observedAt: evidence.observedAt,
            signalToken: 'edge-${_token(edge.type.name)}',
          ),
        );
      }
    }
    final result = byHandle.values.toList()
      ..sort((left, right) => left.localHandle.compareTo(right.localHandle));
    return result;
  }

  static Map<String, Object> _topology(
    List<GraphNode> nodes,
    List<GraphEdge> edges,
  ) {
    final neighbors = {for (final node in nodes) node.id: <String>{}};
    for (final edge in edges) {
      neighbors[edge.sourceNodeId]!.add(edge.targetNodeId);
      neighbors[edge.targetNodeId]!.add(edge.sourceNodeId);
    }
    var components = 0;
    final visited = <String>{};
    for (final node in nodes) {
      if (!visited.add(node.id)) continue;
      components++;
      final pending = <String>[node.id];
      while (pending.isNotEmpty) {
        for (final neighbor in neighbors[pending.removeLast()]!) {
          if (visited.add(neighbor)) pending.add(neighbor);
        }
      }
    }
    final possible = nodes.length < 2 ? 0 : nodes.length * (nodes.length - 1);
    return {
      'nodeCount': nodes.length,
      'edgeCount': edges.length,
      'density': possible == 0
          ? 0.0
          : (edges.length / possible).clamp(0.0, 1.0),
      'componentCount': components,
    };
  }

  static List<Map<String, Object>> _historicalDeltas(
    PersonalKnowledgeGraph graph,
    List<GraphNode> nodes,
    Map<String, String> opaqueByLocal,
  ) {
    final result = <Map<String, Object>>[];
    final trajectoriesByNode = <String, List<GraphTrajectory>>{};
    for (final trajectory in graph.trajectories) {
      (trajectoriesByNode[trajectory.subjectNodeId] ??= []).add(trajectory);
    }
    for (final node in nodes) {
      final trajectories = trajectoriesByNode[node.id] ?? const [];
      for (final trajectory in trajectories) {
        final windows = trajectory.windows.toList()
          ..sort((left, right) => left.end.compareTo(right.end));
        if (windows.length < 2) continue;
        result.add({
          'windowDays': math
              .max(1, windows.last.end.difference(windows.first.start).inDays)
              .clamp(1, 3650),
          'affectedId': opaqueByLocal[node.id]!,
          'metricToken': _trajectoryToken(trajectory.type),
          'delta': (windows.last.value - windows.first.value).clamp(-1.0, 1.0),
        });
      }
      if (trajectories.isNotEmpty || node.evidence.length < 2) continue;
      final evidence = node.evidence.toList()
        ..sort((left, right) => left.observedAt.compareTo(right.observedAt));
      result.add({
        'windowDays': math
            .max(
              1,
              evidence.last.observedAt
                  .difference(evidence.first.observedAt)
                  .inDays,
            )
            .clamp(1, 3650),
        'affectedId': opaqueByLocal[node.id]!,
        'metricToken': 'confidence',
        'delta': (evidence.last.confidence - evidence.first.confidence).clamp(
          -1.0,
          1.0,
        ),
      });
    }
    return result.take(128).toList(growable: false);
  }

  static List<Map<String, Object>> _externalCorrelations(
    CounterfactualScenario scenario,
    PersonalKnowledgeGraph graph,
  ) {
    final values = <String, List<double>>{};
    for (final trajectory in [
      scenario.continueTrajectory,
      scenario.alternativeTrajectory,
    ]) {
      for (final milestone in trajectory.milestones) {
        for (final entry in milestone.externalCorrelations.entries) {
          (values[entry.key] ??= []).add(entry.value);
        }
      }
    }
    final sampleCounts = <String, int>{};
    for (final node in graph.nodes) {
      final source = node.externalSource?.wireName;
      if (source != null) {
        sampleCounts[source] = (sampleCounts[source] ?? 0) + 1;
      }
    }
    final keys = values.keys.toList()..sort();
    return [
      for (final key in keys.take(64))
        {
          'signalToken': _token(key),
          'direction': _direction(
            values[key]!.fold<double>(0, (sum, value) => sum + value) /
                values[key]!.length,
          ),
          'strength':
              (values[key]!.fold<double>(0, (sum, value) => sum + value.abs()) /
                      values[key]!.length)
                  .clamp(0.0, 1.0),
          'sampleSize': math.max(1, sampleCounts[key] ?? values[key]!.length),
          'lagDays': 0,
        },
    ];
  }

  static _ParsedResult _parseResult(
    Map<String, dynamic> value, {
    required _PreparedRequest prepared,
  }) {
    _requireKeys(value, const {'continueTrajectory', 'stopOrPivotTrajectory'});
    return _ParsedResult(
      continuing: _parseTrajectory(
        value['continueTrajectory'],
        prepared: prepared,
      ),
      alternative: _parseTrajectory(
        value['stopOrPivotTrajectory'],
        prepared: prepared,
      ),
    );
  }

  static List<_CloudMilestone> _parseTrajectory(
    Object? value, {
    required _PreparedRequest prepared,
  }) {
    final object = _record(value);
    _requireKeys(object, const {'summary', 'milestones'});
    _strictText(object['summary'], 640);
    final milestones = object['milestones'];
    if (milestones is! List || milestones.length != _horizons.length) {
      throw const FormatException('Invalid trajectory milestones.');
    }
    return [
      for (var index = 0; index < milestones.length; index++)
        _parseMilestone(
          milestones[index],
          expectedHorizon: _horizons[index],
          prepared: prepared,
        ),
    ];
  }

  static _CloudMilestone _parseMilestone(
    Object? value, {
    required int expectedHorizon,
    required _PreparedRequest prepared,
  }) {
    final object = _record(value);
    _requireKeys(object, const {
      'horizonDays',
      'narrativeSummary',
      'projectedConfidence',
      'stressImpactScore',
      'healthCorrelation',
      'affectedIds',
      'citationHandles',
    });
    if (object['horizonDays'] != expectedHorizon) {
      throw const FormatException('Invalid milestone horizon.');
    }
    final affected = _strictStringList(object['affectedIds'], 32);
    final handles = _strictStringList(object['citationHandles'], _maxCitations);
    if (affected.any((id) => !prepared.localIdByOpaque.containsKey(id)) ||
        handles.any(
          (handle) => !prepared.citationByOpaque.containsKey(handle),
        )) {
      throw const FormatException('Response contains unknown references.');
    }
    final localAffected = affected
        .map((id) => prepared.localIdByOpaque[id]!)
        .toList(growable: false);
    final localCitations = handles
        .map((handle) => prepared.citationByOpaque[handle]!)
        .toList(growable: false);
    return _CloudMilestone(
      days: expectedHorizon,
      narrative: _strictText(object['narrativeSummary'], 480),
      confidence: _boundedNumber(object['projectedConfidence'], 0, 1),
      stress: _boundedNumber(object['stressImpactScore'], -1, 1),
      health: object['healthCorrelation'] == null
          ? null
          : _boundedNumber(object['healthCorrelation'], -1, 1),
      affectedNodeIds: localAffected
          .where(prepared.nodeIds.contains)
          .toList(growable: false),
      affectedEdgeIds: localAffected
          .where((id) => !prepared.nodeIds.contains(id))
          .toList(growable: false),
      citationHandles: localCitations
          .map((citation) => citation.localHandle)
          .toList(growable: false),
      citations: localCitations
          .map(
            (citation) => VerifiableCitation(
              sourceEntryId: citation.sourceEntryId,
              exactQuote: citation.exactQuote,
              confidenceScore: citation.confidence,
              startUtf16: citation.startUtf16,
              endUtf16: citation.endUtf16,
            ),
          )
          .toList(growable: false),
    );
  }

  static SimulationTrajectory _mergeTrajectory(
    SimulationTrajectory local,
    List<_CloudMilestone> cloud,
  ) => SimulationTrajectory(
    id: local.id,
    target: local.target,
    path: local.path,
    generatedAt: local.generatedAt,
    milestones: [
      for (var index = 0; index < _horizons.length; index++)
        ProjectedMilestone(
          days: cloud[index].days,
          projectedConfidence: cloud[index].confidence,
          stressImpactScore: cloud[index].stress,
          healthCorrelation: cloud[index].health,
          narrativeSummary: cloud[index].narrative,
          affectedNodeIds: cloud[index].affectedNodeIds,
          affectedEdgeIds: cloud[index].affectedEdgeIds,
          localCitationHandles: cloud[index].citationHandles,
          citations: cloud[index].citations,
          projectedNodeScores: local.milestones[index].projectedNodeScores,
          projectedEdgeWeights: local.milestones[index].projectedEdgeWeights,
          externalCorrelations: local.milestones[index].externalCorrelations,
        ),
    ],
  );

  String _uniqueOpaque(String prefix, Set<String> used) {
    for (var attempt = 0; attempt < 16; attempt++) {
      var token = _opaqueToken().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
      if (token.length > 96) token = token.substring(0, 96);
      if (token.isEmpty) continue;
      final result = '${prefix}_$token';
      if (used.add(result)) return result;
    }
    throw StateError('Unable to allocate an opaque identifier.');
  }

  static String _secureOpaqueToken() {
    final random = math.Random.secure();
    return List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static String _token(String value) => value
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match.group(1)}-${match.group(2)}',
      )
      .replaceAll(RegExp(r'[^A-Za-z0-9._:-]'), '-')
      .toLowerCase();

  static String _trajectoryToken(GraphTrajectoryType type) => switch (type) {
    GraphTrajectoryType.beliefEvolution => 'belief-confidence',
    GraphTrajectoryType.relationshipSentiment => 'relationship-sentiment',
    GraphTrajectoryType.habitFrequency => 'habit-frequency',
    GraphTrajectoryType.projectProgress => 'project-progress',
    GraphTrajectoryType.decisionOutcome => 'decision-outcome',
  };

  static String _direction(num value) =>
      value > .05 ? 'positive' : (value < -.05 ? 'negative' : 'neutral');

  static String _localHandle(String entryId, int start, int end) =>
      '$entryId:$start:$end';

  static Map<String, dynamic> _record(Object? value) {
    if (value is! Map) throw const FormatException('Expected object.');
    return Map<String, dynamic>.from(value);
  }

  static void _requireKeys(Map<String, dynamic> value, Set<String> keys) {
    if (value.keys.toSet().difference(keys).isNotEmpty ||
        keys.difference(value.keys.toSet()).isNotEmpty) {
      throw const FormatException('Invalid response shape.');
    }
  }

  static String _strictText(Object? value, int maximumLength) {
    if (value is! String ||
        value.trim().isEmpty ||
        value.length > maximumLength ||
        RegExp(r'[\u0000-\u001F\u007F]').hasMatch(value)) {
      throw const FormatException('Invalid response text.');
    }
    return value.trim();
  }

  static double _boundedNumber(Object? value, double minimum, double maximum) {
    if (value is! num ||
        !value.toDouble().isFinite ||
        value < minimum ||
        value > maximum) {
      throw const FormatException('Invalid response number.');
    }
    return value.toDouble();
  }

  static List<String> _strictStringList(Object? value, int maximumLength) {
    if (value is! List ||
        value.length > maximumLength ||
        value.any(
          (item) =>
              item is! String ||
              item.isEmpty ||
              item.length > 128 ||
              !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(item),
        )) {
      throw const FormatException('Invalid response references.');
    }
    final result = value.cast<String>();
    if (result.toSet().length != result.length) {
      throw const FormatException('Duplicate response references.');
    }
    return result;
  }
}

final class _PreparedRequest {
  const _PreparedRequest({
    required this.payload,
    required this.localIdByOpaque,
    required this.nodeIds,
    required this.citationByOpaque,
  });

  final Map<String, Object> payload;
  final Map<String, String> localIdByOpaque;
  final Set<String> nodeIds;
  final Map<String, _LocalCitation> citationByOpaque;
}

final class _LocalCitation {
  const _LocalCitation({
    required this.localHandle,
    required this.sourceEntryId,
    required this.exactQuote,
    required this.startUtf16,
    required this.endUtf16,
    required this.confidence,
    required this.observedAt,
    required this.signalToken,
  });

  final String localHandle;
  final String sourceEntryId;
  final String exactQuote;
  final int startUtf16;
  final int endUtf16;
  final double confidence;
  final DateTime observedAt;
  final String signalToken;
}

final class _CloudMilestone {
  const _CloudMilestone({
    required this.days,
    required this.narrative,
    required this.confidence,
    required this.stress,
    required this.health,
    required this.affectedNodeIds,
    required this.affectedEdgeIds,
    required this.citationHandles,
    required this.citations,
  });

  final int days;
  final String narrative;
  final double confidence;
  final double stress;
  final double? health;
  final List<String> affectedNodeIds;
  final List<String> affectedEdgeIds;
  final List<String> citationHandles;
  final List<VerifiableCitation> citations;
}

final class _ParsedResult {
  const _ParsedResult({required this.continuing, required this.alternative});

  final List<_CloudMilestone> continuing;
  final List<_CloudMilestone> alternative;
}
