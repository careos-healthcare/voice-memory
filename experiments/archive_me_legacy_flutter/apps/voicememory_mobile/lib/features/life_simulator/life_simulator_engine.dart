import 'dart:math' as math;

import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph.dart';
import '../ai_engines/models/hypothesis_evolution.dart';
import '../semantic_clusters/semantic_cluster.dart';
import 'life_simulator_models.dart';

/// Deterministic, local-only counterfactual projection over graph references.
///
/// The engine returns derived score maps and never edits [graph] or any object
/// reachable from it.
final class LifeSimulatorEngine {
  // Keep the public dependency name descriptive while storing it privately.
  // ignore: prefer_initializing_formals
  const LifeSimulatorEngine({DateTime Function()? clock}) : _clock = clock;

  final DateTime Function()? _clock;

  SimulationTrajectory simulate({
    required PersonalKnowledgeGraph graph,
    required SimulationTarget target,
    required SimulationPath path,
    Iterable<SemanticCluster> clusters = const [],
    Iterable<HypothesisEvolution> hypotheses = const [],
  }) {
    final scope = _resolveScope(graph, target, clusters);
    final hypothesisById = {
      for (final hypothesis in hypotheses) hypothesis.theoryId: hypothesis,
    };
    final confidenceSignal = _confidenceSignal(scope.nodes, hypothesisById);
    final activityVelocity = _activityVelocity(scope, clusters);
    final stressSignal = _stressSignal(graph, scope.nodeIds);
    final correlations = _externalCorrelations(graph, scope.nodes);
    final citations = _citationHandles(graph, scope.nodeIds);
    final generatedAt = (_clock?.call() ?? _latestObservation(graph)).toUtc();

    return SimulationTrajectory(
      target: target,
      path: path,
      generatedAt: generatedAt,
      milestones: [
        for (final days in const [30, 90, 365])
          _projectMilestone(
            graph: graph,
            scope: scope,
            path: path,
            days: days,
            confidenceSignal: confidenceSignal,
            activityVelocity: activityVelocity,
            stressSignal: stressSignal,
            correlations: correlations,
            citationHandles: citations,
          ),
      ],
    );
  }

  SimulationTrajectory project({
    required PersonalKnowledgeGraph graph,
    required SimulationTarget target,
    required SimulationPath path,
    Iterable<SemanticCluster> clusters = const [],
    Iterable<HypothesisEvolution> hypotheses = const [],
  }) => simulate(
    graph: graph,
    target: target,
    path: path,
    clusters: clusters,
    hypotheses: hypotheses,
  );

  CounterfactualScenario compare({
    required PersonalKnowledgeGraph graph,
    required SimulationTarget target,
    SimulationPath alternativePath = SimulationPath.stopTrajectory,
    Iterable<SemanticCluster> clusters = const [],
    Iterable<HypothesisEvolution> hypotheses = const [],
  }) {
    if (alternativePath == SimulationPath.continueTrajectory) {
      throw ArgumentError.value(
        alternativePath,
        'alternativePath',
        'must be stopTrajectory or pivotTrajectory',
      );
    }
    return CounterfactualScenario(
      continueTrajectory: simulate(
        graph: graph,
        target: target,
        path: SimulationPath.continueTrajectory,
        clusters: clusters,
        hypotheses: hypotheses,
      ),
      alternativeTrajectory: simulate(
        graph: graph,
        target: target,
        path: alternativePath,
        clusters: clusters,
        hypotheses: hypotheses,
      ),
    );
  }

  CounterfactualScenario createScenario({
    required PersonalKnowledgeGraph graph,
    required SimulationTarget target,
    SimulationPath alternativePath = SimulationPath.stopTrajectory,
    Iterable<SemanticCluster> clusters = const [],
    Iterable<HypothesisEvolution> hypotheses = const [],
  }) => compare(
    graph: graph,
    target: target,
    alternativePath: alternativePath,
    clusters: clusters,
    hypotheses: hypotheses,
  );

  ProjectedMilestone _projectMilestone({
    required PersonalKnowledgeGraph graph,
    required _TargetScope scope,
    required SimulationPath path,
    required int days,
    required _ConfidenceSignal confidenceSignal,
    required double activityVelocity,
    required _StressSignal stressSignal,
    required Map<String, double> correlations,
    required List<String> citationHandles,
  }) {
    final saturation = 1 - math.exp(-days / 180);
    final linearMomentum = (confidenceSignal.slopePerDay * days).clamp(
      -0.35,
      0.35,
    );
    final velocityMomentum = activityVelocity * saturation * 0.28;
    final continuingMomentum = (linearMomentum + velocityMomentum).clamp(
      -0.45,
      0.45,
    );
    final positiveSupport = _positiveNeighborSupport(graph, scope.nodeIds);

    final projectedConfidence = switch (path) {
      SimulationPath.continueTrajectory => _unit(
        confidenceSignal.current + continuingMomentum,
      ),
      SimulationPath.stopTrajectory => _unit(
        confidenceSignal.current * math.exp(-days / 240),
      ),
      SimulationPath.pivotTrajectory => _unit(
        confidenceSignal.current * (1 - 0.28 * saturation) +
            positiveSupport * 0.32 * saturation,
      ),
    };

    final stressTrend = (stressSignal.slopePerDay * days).clamp(-0.4, 0.4);
    final stressImpact = switch (path) {
      SimulationPath.continueTrajectory => _signed(
        stressSignal.level * 0.55 + stressTrend,
      ),
      SimulationPath.stopTrajectory => _signed(
        -stressSignal.level.abs() * 0.7 * saturation -
            math.max(0, stressTrend) * saturation,
      ),
      SimulationPath.pivotTrajectory => _signed(
        -stressSignal.level.abs() * 0.42 * saturation -
            math.max(0, stressTrend) * 0.5 * saturation,
      ),
    };

    final rootDelta = projectedConfidence - confidenceSignal.current;
    final nodeScores = _propagateNodeScores(
      graph,
      scope.nodeIds,
      rootDelta,
      path,
    );
    final edgeWeights = _projectEdgeWeights(
      graph,
      scope.nodeIds,
      path,
      days,
      continuingMomentum,
    );
    final affectedNodes = nodeScores.entries
        .where((entry) {
          final original = graph.nodes
              .where((node) => node.id == entry.key)
              .firstOrNull;
          return original == null ||
              (original.confidence - entry.value).abs() > 0.000001;
        })
        .map((entry) => entry.key);
    final originalEdges = {
      for (final edge in graph.edges) edge.id: edge.weight,
    };
    final affectedEdges = edgeWeights.entries
        .where(
          (entry) =>
              ((originalEdges[entry.key] ?? entry.value) - entry.value).abs() >
              0.000001,
        )
        .map((entry) => entry.key);

    return ProjectedMilestone(
      days: days,
      projectedConfidence: projectedConfidence,
      stressImpactScore: stressImpact,
      healthCorrelation: correlations['apple_health'],
      narrativeSummary: _narrative(
        scope.label,
        path,
        days,
        projectedConfidence,
        stressImpact,
        correlations.isNotEmpty,
      ),
      affectedNodeIds: affectedNodes,
      affectedEdgeIds: affectedEdges,
      localCitationHandles: citationHandles,
      projectedNodeScores: nodeScores,
      projectedEdgeWeights: edgeWeights,
      externalCorrelations: correlations,
    );
  }

  static _TargetScope _resolveScope(
    PersonalKnowledgeGraph graph,
    SimulationTarget target,
    Iterable<SemanticCluster> clusters,
  ) {
    final nodesById = {for (final node in graph.nodes) node.id: node};
    if (target.kind == SimulationTargetKind.semanticCluster) {
      SemanticCluster? selected;
      for (final cluster in clusters) {
        if (cluster.id == target.referenceId) {
          selected = cluster;
          break;
        }
      }
      if (selected == null) {
        throw StateError('Semantic cluster not found: ${target.referenceId}');
      }
      final nodes =
          selected.nodeIds
              .map((id) => nodesById[id])
              .whereType<GraphNode>()
              .toList()
            ..sort((a, b) => a.id.compareTo(b.id));
      if (nodes.isEmpty) {
        throw StateError('Semantic cluster has no nodes in the graph.');
      }
      return _TargetScope(
        nodes: nodes,
        nodeIds: nodes.map((node) => node.id).toSet(),
        label: target.displayLabel ?? selected.title,
        cluster: selected,
      );
    }

    final node = nodesById[target.referenceId];
    if (node == null) {
      throw StateError('Graph node not found: ${target.referenceId}');
    }
    if (target.kind == SimulationTargetKind.habit &&
        node.type != NodeType.habit) {
      throw StateError('Simulation habit target is not a habit node.');
    }
    return _TargetScope(
      nodes: [node],
      nodeIds: {node.id},
      label: target.displayLabel ?? node.label,
    );
  }

  static _ConfidenceSignal _confidenceSignal(
    List<GraphNode> nodes,
    Map<String, HypothesisEvolution> hypothesisById,
  ) {
    final observations = <_Observation>[];
    for (final node in nodes) {
      observations.addAll(
        node.evidence.map(
          (evidence) => _Observation(evidence.observedAt, evidence.confidence),
        ),
      );
      final hypothesis = node.theoryId == null
          ? null
          : hypothesisById[node.theoryId!];
      if (hypothesis != null) {
        observations.addAll(
          hypothesis.evolutionHistory.map(
            (snapshot) =>
                _Observation(snapshot.date, snapshot.confidenceScore / 100),
          ),
        );
      }
    }
    observations.sort((a, b) => a.date.compareTo(b.date));
    final current = observations.isEmpty
        ? _average(nodes.map((node) => node.confidence))
        : observations.last.value;
    return _ConfidenceSignal(
      current: _unit(current),
      slopePerDay: _linearSlope(observations).clamp(-0.02, 0.02),
    );
  }

  static double _activityVelocity(
    _TargetScope scope,
    Iterable<SemanticCluster> clusters,
  ) {
    if (scope.cluster != null) return scope.cluster!.activityVelocity;
    final containing = clusters
        .where(
          (cluster) =>
              scope.nodeIds.any((nodeId) => cluster.nodeIds.contains(nodeId)),
        )
        .map((cluster) => cluster.activityVelocity)
        .toList();
    if (containing.isNotEmpty) return _average(containing);
    final dates =
        scope.nodes
            .expand((node) => node.evidence)
            .map((item) => item.observedAt)
            .toList()
          ..sort();
    if (dates.length < 2) return 0;
    final span = math.max(1, dates.last.difference(dates.first).inDays);
    return (dates.length / math.max(4, span / 30)).clamp(0.0, 1.0);
  }

  static _StressSignal _stressSignal(
    PersonalKnowledgeGraph graph,
    Set<String> scopeNodeIds,
  ) {
    final connectedIds = <String>{...scopeNodeIds};
    for (final edge in graph.edges) {
      if (scopeNodeIds.contains(edge.sourceNodeId)) {
        connectedIds.add(edge.targetNodeId);
      }
      if (scopeNodeIds.contains(edge.targetNodeId)) {
        connectedIds.add(edge.sourceNodeId);
      }
    }
    final observations = <_Observation>[];
    for (final node in graph.nodes.where(
      (node) => connectedIds.contains(node.id),
    )) {
      final stress = _stressForNode(node);
      if (stress == 0) continue;
      if (node.evidence.isEmpty) {
        observations.add(
          _Observation(node.createdAt, stress * node.confidence),
        );
      } else {
        observations.addAll(
          node.evidence.map(
            (evidence) =>
                _Observation(evidence.observedAt, stress * evidence.confidence),
          ),
        );
      }
    }
    for (final edge in graph.edges.where(
      (edge) =>
          scopeNodeIds.contains(edge.sourceNodeId) ||
          scopeNodeIds.contains(edge.targetNodeId),
    )) {
      final valence = edge.emotionalValenceScore;
      if (valence == null || valence >= 0) continue;
      final value = -valence * (edge.intensity ?? edge.weight);
      final date = edge.interactionDate ?? edge.createdAt;
      observations.add(_Observation(date, value));
    }
    observations.sort((a, b) => a.date.compareTo(b.date));
    return _StressSignal(
      level: observations.isEmpty
          ? 0
          : _signed(_average(observations.map((item) => item.value))),
      slopePerDay: _linearSlope(observations).clamp(-0.02, 0.02),
    );
  }

  static double _stressForNode(GraphNode node) {
    final label = normalizeGraphLabel(node.label);
    const stressTerms = {
      'stress',
      'stressed',
      'anxious',
      'anxiety',
      'afraid',
      'fear',
      'worried',
      'overwhelmed',
      'tense',
      'burnout',
      'exhausted',
    };
    const calmingTerms = {
      'calm',
      'relieved',
      'rested',
      'safe',
      'supported',
      'grateful',
    };
    if (node.type == NodeType.fear ||
        stressTerms.any((term) => label.contains(term))) {
      return 1;
    }
    if (calmingTerms.any((term) => label.contains(term))) return -0.6;
    return 0;
  }

  static Map<String, double> _externalCorrelations(
    PersonalKnowledgeGraph graph,
    List<GraphNode> scopeNodes,
  ) {
    final targetByDay = _dailyValues(
      scopeNodes
          .expand((node) => node.evidence)
          .map((item) => _Observation(item.observedAt, item.confidence)),
    );
    final bySource = <ExternalSource, List<_Observation>>{};
    for (final node in graph.nodes) {
      final source = node.externalSource;
      if (source == null) continue;
      final metric = _externalMetric(node);
      if (metric == null) continue;
      (bySource[source] ??= []).add(_Observation(node.createdAt, metric));
    }
    final result = <String, double>{};
    for (final entry in bySource.entries) {
      final externalByDay = _dailyValues(entry.value);
      final sharedDays =
          targetByDay.keys.where(externalByDay.containsKey).toList()..sort();
      if (sharedDays.length < 2) continue;
      final correlation = _pearson(
        sharedDays.map((day) => targetByDay[day]!).toList(),
        sharedDays.map((day) => externalByDay[day]!).toList(),
      );
      if (correlation != null) {
        result[entry.key.wireName] = _signed(correlation);
      }
    }
    return Map.unmodifiable(result);
  }

  static double? _externalMetric(GraphNode node) {
    final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(node.label);
    final raw = double.tryParse(match?.group(0) ?? '');
    if (raw == null || !raw.isFinite) return null;
    final label = node.label.toLowerCase();
    if (node.externalSource == ExternalSource.appleHealth) {
      if (label.contains('sleep')) return (raw / 8).clamp(0.0, 1.0);
      if (label.contains('step')) return (raw / 10000).clamp(0.0, 1.0);
      if (label.contains('heart rate')) {
        return ((100 - raw) / 50).clamp(0.0, 1.0);
      }
    }
    if (node.externalSource == ExternalSource.spotify) {
      if (label.contains('valence') || label.contains('energy')) {
        return (raw / 100).clamp(0.0, 1.0);
      }
      if (label.contains('listening')) return (raw / 30).clamp(0.0, 1.0);
    }
    return null;
  }

  static Map<String, double> _dailyValues(Iterable<_Observation> values) {
    final grouped = <String, List<double>>{};
    for (final item in values) {
      final date = item.date.toUtc();
      final key =
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      (grouped[key] ??= []).add(item.value);
    }
    return {
      for (final entry in grouped.entries) entry.key: _average(entry.value),
    };
  }

  static Map<String, double> _propagateNodeScores(
    PersonalKnowledgeGraph graph,
    Set<String> scopeNodeIds,
    double rootDelta,
    SimulationPath path,
  ) {
    final original = {for (final node in graph.nodes) node.id: node.confidence};
    final deltas = <String, double>{
      for (final nodeId in scopeNodeIds) nodeId: rootDelta,
    };
    var frontier = <String, double>{
      for (final nodeId in scopeNodeIds) nodeId: rootDelta,
    };
    for (var depth = 1; depth <= 3; depth++) {
      final next = <String, double>{};
      final orderedFrontier = frontier.keys.toList()..sort();
      for (final nodeId in orderedFrontier) {
        for (final edge in graph.edges) {
          final neighbor = _propagatingNeighbor(edge, nodeId);
          if (neighbor == null || scopeNodeIds.contains(neighbor)) continue;
          final valence = edge.emotionalValenceScore ?? 0.25;
          final signedValence = path == SimulationPath.stopTrajectory
              ? -valence
              : valence;
          final propagated =
              frontier[nodeId]! *
              edge.weight *
              (0.5 + signedValence * 0.25) *
              math.pow(0.45, depth);
          next[neighbor] = (next[neighbor] ?? 0) + propagated;
        }
      }
      for (final entry in next.entries) {
        deltas[entry.key] = (deltas[entry.key] ?? 0) + entry.value;
      }
      frontier = next;
    }
    return Map.unmodifiable({
      for (final entry in deltas.entries)
        if (original.containsKey(entry.key))
          entry.key: _unit(original[entry.key]! + entry.value),
    });
  }

  static String? _propagatingNeighbor(GraphEdge edge, String nodeId) {
    if (edge.sourceNodeId == nodeId) return edge.targetNodeId;
    if (!edge.isDirected && edge.targetNodeId == nodeId) {
      return edge.sourceNodeId;
    }
    return null;
  }

  static Map<String, double> _projectEdgeWeights(
    PersonalKnowledgeGraph graph,
    Set<String> scopeNodeIds,
    SimulationPath path,
    int days,
    double continuingMomentum,
  ) {
    final incident =
        graph.edges
            .where(
              (edge) =>
                  scopeNodeIds.contains(edge.sourceNodeId) ||
                  scopeNodeIds.contains(edge.targetNodeId),
            )
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    final result = <String, double>{};
    if (path == SimulationPath.pivotTrajectory) {
      final positives = incident.where(_isPositiveEdge).toList()
        ..sort((a, b) {
          final byScore = _edgePositiveScore(
            b,
          ).compareTo(_edgePositiveScore(a));
          return byScore != 0 ? byScore : a.id.compareTo(b.id);
        });
      final selectedIds = positives
          .take(math.max(1, (positives.length / 2).ceil()))
          .map((edge) => edge.id)
          .toSet();
      final weakenedTotal = incident
          .where((edge) => !selectedIds.contains(edge.id))
          .map((edge) => edge.weight * 0.55)
          .fold<double>(0, (sum, value) => sum + value);
      final bonus = selectedIds.isEmpty
          ? 0
          : weakenedTotal / selectedIds.length;
      for (final edge in incident) {
        result[edge.id] = selectedIds.contains(edge.id)
            ? _unit(edge.weight + bonus)
            : _unit(edge.weight * 0.45);
      }
      return Map.unmodifiable(result);
    }

    final saturation = 1 - math.exp(-days / 180);
    for (final edge in incident.where(_isCausalOrAssociated)) {
      if (path == SimulationPath.stopTrajectory) {
        final projected = edge.weight * (1 - 0.88 * saturation);
        result[edge.id] = projected < 0.2 ? 0 : _unit(projected);
      } else {
        final gain =
            (0.08 + continuingMomentum.abs() * 0.32) *
            saturation *
            (edge.emotionalValenceScore == null
                ? 1
                : 1 + edge.emotionalValenceScore! * 0.25);
        result[edge.id] = _unit(edge.weight + gain);
      }
    }
    return Map.unmodifiable(result);
  }

  static bool _isCausalOrAssociated(GraphEdge edge) => switch (edge.type) {
    EdgeType.triggeredBy ||
    EdgeType.associatedWith ||
    EdgeType.influences ||
    EdgeType.resultedIn ||
    EdgeType.mentionedWith => true,
    _ => false,
  };

  static bool _isPositiveEdge(GraphEdge edge) =>
      (edge.emotionalValenceScore ?? 0) >= 0;

  static double _edgePositiveScore(GraphEdge edge) =>
      edge.weight * (1 + (edge.emotionalValenceScore ?? 0));

  static double _positiveNeighborSupport(
    PersonalKnowledgeGraph graph,
    Set<String> scopeNodeIds,
  ) {
    final values = graph.edges
        .where(
          (edge) =>
              (scopeNodeIds.contains(edge.sourceNodeId) ||
                  scopeNodeIds.contains(edge.targetNodeId)) &&
              _isPositiveEdge(edge),
        )
        .map(_edgePositiveScore)
        .toList();
    return values.isEmpty ? 0 : _unit(_average(values));
  }

  static List<String> _citationHandles(
    PersonalKnowledgeGraph graph,
    Set<String> scopeNodeIds,
  ) {
    final handles = <String>{};
    for (final node in graph.nodes.where(
      (node) => scopeNodeIds.contains(node.id),
    )) {
      for (final evidence in node.evidence) {
        handles.add(
          _citationHandle(
            evidence.entryId,
            evidence.startUtf16,
            evidence.endUtf16,
          ),
        );
      }
    }
    for (final edge in graph.edges.where(
      (edge) =>
          scopeNodeIds.contains(edge.sourceNodeId) ||
          scopeNodeIds.contains(edge.targetNodeId),
    )) {
      for (final evidence in edge.evidence) {
        handles.add(
          _citationHandle(
            evidence.entryId,
            evidence.startUtf16,
            evidence.endUtf16,
          ),
        );
      }
    }
    final result = handles.toList()..sort();
    return List.unmodifiable(result.take(24));
  }

  static String _citationHandle(String entryId, int start, int end) =>
      '$entryId:$start:$end';

  static String _narrative(
    String label,
    SimulationPath path,
    int days,
    double confidence,
    double stressImpact,
    bool hasExternalContext,
  ) {
    final action = switch (path) {
      SimulationPath.continueTrajectory => 'continues at its observed pace',
      SimulationPath.stopTrajectory => 'is paused and its links weaken',
      SimulationPath.pivotTrajectory =>
        'shifts toward the strongest positive links',
    };
    final stress = stressImpact > 0.15
        ? 'observed stress-linked signals may rise'
        : stressImpact < -0.15
        ? 'observed stress-linked signals may ease'
        : 'stress-linked signals may remain near their observed range';
    final external = hasExternalContext
        ? ' Available device data is contextual correlation only.'
        : '';
    return 'If $label $action, the $days-day graph projection has '
        '${(confidence * 100).round()}% evidence confidence and $stress. '
        'This is a local, non-diagnostic scenario—not a certain outcome.'
        '$external';
  }

  static DateTime _latestObservation(PersonalKnowledgeGraph graph) {
    DateTime? latest;
    for (final node in graph.nodes) {
      for (final evidence in node.evidence) {
        if (latest == null || evidence.observedAt.isAfter(latest)) {
          latest = evidence.observedAt;
        }
      }
    }
    return latest ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  static double _linearSlope(List<_Observation> observations) {
    if (observations.length < 2) return 0;
    final origin = observations.first.date;
    final x = observations
        .map((item) => item.date.difference(origin).inHours / 24)
        .toList();
    final y = observations.map((item) => item.value).toList();
    final meanX = _average(x);
    final meanY = _average(y);
    var numerator = 0.0;
    var denominator = 0.0;
    for (var index = 0; index < x.length; index++) {
      numerator += (x[index] - meanX) * (y[index] - meanY);
      denominator += math.pow(x[index] - meanX, 2);
    }
    return denominator == 0 ? 0 : numerator / denominator;
  }

  static double? _pearson(List<double> x, List<double> y) {
    if (x.length != y.length || x.length < 2) return null;
    final meanX = _average(x);
    final meanY = _average(y);
    var numerator = 0.0;
    var squareX = 0.0;
    var squareY = 0.0;
    for (var index = 0; index < x.length; index++) {
      final dx = x[index] - meanX;
      final dy = y[index] - meanY;
      numerator += dx * dy;
      squareX += dx * dx;
      squareY += dy * dy;
    }
    final denominator = math.sqrt(squareX * squareY);
    return denominator == 0 ? null : numerator / denominator;
  }

  static double _average(Iterable<num> values) {
    var total = 0.0;
    var count = 0;
    for (final value in values) {
      total += value;
      count++;
    }
    return count == 0 ? 0 : total / count;
  }

  static double _unit(num value) => value.toDouble().clamp(0.0, 1.0);
  static double _signed(num value) => value.toDouble().clamp(-1.0, 1.0);
}

final class _TargetScope {
  const _TargetScope({
    required this.nodes,
    required this.nodeIds,
    required this.label,
    this.cluster,
  });

  final List<GraphNode> nodes;
  final Set<String> nodeIds;
  final String label;
  final SemanticCluster? cluster;
}

final class _Observation {
  const _Observation(this.date, this.value);

  final DateTime date;
  final double value;
}

final class _ConfidenceSignal {
  const _ConfidenceSignal({required this.current, required this.slopePerDay});

  final double current;
  final double slopePerDay;
}

final class _StressSignal {
  const _StressSignal({required this.level, required this.slopePerDay});

  final double level;
  final double slopePerDay;
}
