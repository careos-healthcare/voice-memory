import 'dart:math' as math;

import '../../api/api_transport.dart';
import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph.dart';
import '../../services/capture_attest_service.dart';
import '../life_simulator/life_simulator_models.dart';
import '../semantic_clusters/semantic_cluster.dart';
import 'action_plan_models.dart';

typedef ActionPlanOpaqueToken = String Function();
typedef ActionPlanClock = DateTime Function();

/// Generates optional action plans from an ephemeral structural graph projection.
///
/// Request IDs are freshly randomized and exist only long enough to reverse-map
/// validated response targets. Personal labels, evidence, and source IDs never
/// leave the device. This service does not persist generated plans.
final class ActionPlanGeneratorService {
  ActionPlanGeneratorService({
    required this.transport,
    required this.attest,
    ActionPlanOpaqueToken? opaqueToken,
    ActionPlanClock? clock,
  }) : _opaqueToken = opaqueToken ?? _secureToken,
       _clock = clock ?? DateTime.now;

  static const _maxNodes = 64;
  static const _maxEdges = 128;
  static const _horizons = [30, 90, 365];

  final ApiTransport transport;
  final CaptureAttestService attest;
  final ActionPlanOpaqueToken _opaqueToken;
  final ActionPlanClock _clock;

  Future<ActionPlan> generateFromSimulation(
    CounterfactualScenario scenario,
    SimulationPath selectedPath,
    PersonalKnowledgeGraph graph,
  ) {
    final trajectory = selectedPath == SimulationPath.continueTrajectory
        ? scenario.continueTrajectory
        : scenario.alternativeTrajectory;
    if (trajectory.path != selectedPath) {
      throw ArgumentError.value(
        selectedPath,
        'selectedPath',
        'is not available in this scenario',
      );
    }
    final prepared = _prepareSimulation(trajectory, graph);
    return _generate(prepared: prepared, simulationId: scenario.id);
  }

  Future<ActionPlan> generateFromTrajectory(
    SimulationTrajectory trajectory,
    PersonalKnowledgeGraph graph,
  ) => _generate(
    prepared: _prepareSimulation(trajectory, graph),
    simulationId: trajectory.id,
  );

  Future<ActionPlan> generateFromCluster(
    SemanticCluster cluster,
    PersonalKnowledgeGraph graph,
  ) {
    final prepared = _prepareCluster(cluster, graph);
    return _generate(prepared: prepared, clusterId: cluster.id);
  }

  /// Exposed for privacy-contract tests and preflight inspection.
  Map<String, Object> buildSimulationPayload({
    required CounterfactualScenario scenario,
    required SimulationPath selectedPath,
    required PersonalKnowledgeGraph graph,
  }) {
    final trajectory = selectedPath == SimulationPath.continueTrajectory
        ? scenario.continueTrajectory
        : scenario.alternativeTrajectory;
    if (trajectory.path != selectedPath) {
      throw ArgumentError.value(selectedPath, 'selectedPath');
    }
    return _prepareSimulation(trajectory, graph).payload;
  }

  /// Exposed for privacy-contract tests and preflight inspection.
  Map<String, Object> buildClusterPayload({
    required SemanticCluster cluster,
    required PersonalKnowledgeGraph graph,
  }) => _prepareCluster(cluster, graph).payload;

  Future<ActionPlan> _generate({
    required _PreparedActionPlanRequest prepared,
    String? clusterId,
    String? simulationId,
  }) async {
    try {
      final token = await attest.ensureCaptureToken();
      final response = await transport.postJson(
        '/api/action-plan-generator',
        headers: {
          ...transport.jsonHeaders,
          ApiTransport.captureTokenHeader: token,
          'x-vm-client': 'voicememory-mobile',
        },
        body: prepared.payload,
      );
      final result = _parseResult(
        transport.decodeJson(response),
        prepared.localNodeIdByOpaque,
      );
      return _toPlan(result, clusterId: clusterId, simulationId: simulationId);
    } catch (_) {
      return _fallback(
        prepared,
        clusterId: clusterId,
        simulationId: simulationId,
      );
    }
  }

  _PreparedActionPlanRequest _prepareSimulation(
    SimulationTrajectory trajectory,
    PersonalKnowledgeGraph graph,
  ) {
    final requestedIds = <String>{};
    for (final milestone in trajectory.milestones) {
      requestedIds
        ..addAll(milestone.affectedNodeIds)
        ..addAll(milestone.projectedNodeScores.keys);
    }
    if (trajectory.target.kind != SimulationTargetKind.semanticCluster) {
      requestedIds.add(trajectory.target.referenceId);
    }
    return _prepare(
      sourceData: {
        'source': 'simulation_trajectory',
        'trajectoryData': [
          for (var index = 0; index < _horizons.length; index++)
            {
              'horizonDays': _horizons[index],
              'value': trajectory.milestones[index].projectedConfidence,
            },
        ],
      },
      requestedNodeIds: requestedIds,
      graph: graph,
    );
  }

  _PreparedActionPlanRequest _prepareCluster(
    SemanticCluster cluster,
    PersonalKnowledgeGraph graph,
  ) => _prepare(
    sourceData: {
      'source': 'semantic_cluster',
      'clusterData': {
        'categoryToken': _token(cluster.category.wireName),
        'cohesion': cluster.confidenceScore,
        'activity': cluster.activityVelocity,
      },
    },
    requestedNodeIds: cluster.nodeIds.toSet(),
    graph: graph,
  );

  _PreparedActionPlanRequest _prepare({
    required Map<String, Object> sourceData,
    required Set<String> requestedNodeIds,
    required PersonalKnowledgeGraph graph,
  }) {
    final nodes =
        graph.nodes
            .where(
              (node) =>
                  requestedNodeIds.contains(node.id) && node.archivedAt == null,
            )
            .toList()
          ..sort((left, right) => left.id.compareTo(right.id));
    final selectedNodes = nodes.take(_maxNodes).toList(growable: false);
    if (selectedNodes.isEmpty) {
      throw const FormatException('Action plan source has no graph nodes.');
    }
    final selectedIds = selectedNodes.map((node) => node.id).toSet();
    final edges =
        graph.edges
            .where(
              (edge) =>
                  edge.archivedAt == null &&
                  selectedIds.contains(edge.sourceNodeId) &&
                  selectedIds.contains(edge.targetNodeId),
            )
            .toList()
          ..sort((left, right) => left.id.compareTo(right.id));
    final selectedEdges = edges.take(_maxEdges).toList(growable: false);

    final used = <String>{};
    final opaqueByLocal = <String, String>{
      for (final node in selectedNodes) node.id: _uniqueOpaque('n', used),
    };
    final edgeOpaqueByLocal = <String, String>{
      for (final edge in selectedEdges) edge.id: _uniqueOpaque('e', used),
    };
    final localByOpaque = <String, String>{
      for (final entry in opaqueByLocal.entries) entry.value: entry.key,
    };
    final possible = selectedNodes.length < 2
        ? 0
        : selectedNodes.length * (selectedNodes.length - 1);
    final averageNodeWeight =
        selectedNodes.fold<double>(0, (sum, node) => sum + node.confidence) /
        selectedNodes.length;
    final averageEdgeWeight = selectedEdges.isEmpty
        ? 0.0
        : selectedEdges.fold<double>(0, (sum, edge) => sum + edge.weight) /
              selectedEdges.length;

    return _PreparedActionPlanRequest(
      payload: <String, Object>{
        ...sourceData,
        'nodes': <Map<String, Object>>[
          for (final node in selectedNodes)
            {
              'id': opaqueByLocal[node.id]!,
              'typeToken': _token(node.type.name),
              'weight': node.confidence,
            },
        ],
        'edges': <Map<String, Object>>[
          for (final edge in selectedEdges)
            {
              'id': edgeOpaqueByLocal[edge.id]!,
              'sourceNodeId': opaqueByLocal[edge.sourceNodeId]!,
              'targetNodeId': opaqueByLocal[edge.targetNodeId]!,
              'typeToken': _token(edge.type.name),
              'weight': edge.weight,
            },
        ],
        'aggregateMetrics': <Map<String, Object>>[
          {'metricToken': 'node-count', 'value': selectedNodes.length},
          {'metricToken': 'edge-count', 'value': selectedEdges.length},
          {
            'metricToken': 'density',
            'value': possible == 0 ? 0.0 : selectedEdges.length / possible,
          },
          {'metricToken': 'average-node-weight', 'value': averageNodeWeight},
          {'metricToken': 'average-edge-weight', 'value': averageEdgeWeight},
        ],
      },
      localNodeIdByOpaque: Map.unmodifiable(localByOpaque),
      nodeTypeByLocalId: Map.unmodifiable({
        for (final node in selectedNodes) node.id: node.type,
      }),
    );
  }

  ActionPlan _toPlan(
    _ActionPlanResult result, {
    String? clusterId,
    String? simulationId,
  }) {
    final usedLocalIds = <String>{};
    final planId = _localId('plan', usedLocalIds);
    return ActionPlan(
      id: planId,
      clusterId: clusterId,
      simulationId: simulationId,
      title: result.title,
      targetOutcome: result.targetOutcome,
      createdAt: _clock().toUtc(),
      steps: [
        for (final habit in result.habits)
          MicroHabitStep(
            id: _localId('step', usedLocalIds),
            planId: planId,
            title: habit.title,
            frequency: habit.frequency,
            targetNodeId: habit.localTargetNodeId,
          ),
      ],
    );
  }

  ActionPlan _fallback(
    _PreparedActionPlanRequest prepared, {
    String? clusterId,
    String? simulationId,
  }) {
    final nodeIds = prepared.nodeTypeByLocalId.keys.toList()..sort();
    final habits = <_ParsedHabit>[];
    for (var index = 0; index < 3; index++) {
      final nodeId = nodeIds[index % nodeIds.length];
      habits.add(
        _ParsedHabit(
          title: _fallbackTitle(prepared.nodeTypeByLocalId[nodeId]!, index),
          frequency: ActionPlanFrequency.daily(),
          localTargetNodeId: nodeId,
        ),
      );
    }
    return _toPlan(
      _ActionPlanResult(
        title: 'Three small experiments',
        targetOutcome:
            'Try three brief actions and notice what feels sustainable.',
        habits: habits,
      ),
      clusterId: clusterId,
      simulationId: simulationId,
    );
  }

  String _uniqueOpaque(String prefix, Set<String> used) {
    for (var attempt = 0; attempt < 16; attempt++) {
      final candidate = _cleanOpaque(_opaqueToken());
      if (candidate.isNotEmpty) {
        final value = '${prefix}_$candidate';
        if (used.add(value)) return value;
      }
    }
    throw StateError('Unable to allocate an opaque identifier.');
  }

  String _localId(String prefix, Set<String> used) {
    for (var attempt = 0; attempt < 16; attempt++) {
      final token = _cleanOpaque(_opaqueToken());
      if (token.isNotEmpty) {
        final value = '${prefix}_$token';
        if (used.add(value)) return value;
      }
    }
    throw StateError('Unable to allocate a local identifier.');
  }

  static _ActionPlanResult _parseResult(
    Map<String, dynamic> value,
    Map<String, String> localNodeIdByOpaque,
  ) {
    _requireKeys(value, const {'planTitle', 'targetOutcome', 'microHabits'});
    final rawHabits = value['microHabits'];
    if (rawHabits is! List || rawHabits.length != 3) {
      throw const FormatException(
        'Response must contain exactly three habits.',
      );
    }
    return _ActionPlanResult(
      title: _strictText(value['planTitle'], 80),
      targetOutcome: _strictText(value['targetOutcome'], 240),
      habits: [
        for (final rawHabit in rawHabits)
          _parseHabit(rawHabit, localNodeIdByOpaque),
      ],
    );
  }

  static _ParsedHabit _parseHabit(
    Object? value,
    Map<String, String> localNodeIdByOpaque,
  ) {
    final object = _record(value);
    _requireKeys(object, const {
      'title',
      'frequency',
      'customWeekdays',
      'targetNodeId',
      'stackingCue',
    });
    final frequency = object['frequency'];
    final rawDays = object['customWeekdays'];
    if (rawDays is! List ||
        rawDays.length > 7 ||
        rawDays.any(
          (day) => day is! String || !_weekdayNumbers.containsKey(day),
        )) {
      throw const FormatException('Invalid custom weekdays.');
    }
    final dayNames = rawDays.cast<String>();
    if (dayNames.toSet().length != dayNames.length ||
        frequency == 'daily' && dayNames.isNotEmpty ||
        frequency == 'custom_days' && dayNames.isEmpty ||
        frequency != 'daily' && frequency != 'custom_days') {
      throw const FormatException('Invalid habit frequency.');
    }
    final opaqueTarget = object['targetNodeId'];
    if (opaqueTarget is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(opaqueTarget) ||
        !localNodeIdByOpaque.containsKey(opaqueTarget)) {
      throw const FormatException('Unknown habit target.');
    }
    final cue = object['stackingCue'];
    if (cue != null) _strictText(cue, 160);
    return _ParsedHabit(
      title: _strictText(object['title'], 96),
      frequency: frequency == 'daily'
          ? ActionPlanFrequency.daily()
          : ActionPlanFrequency.customDays(
              dayNames.map((day) => _weekdayNumbers[day]!),
            ),
      localTargetNodeId: localNodeIdByOpaque[opaqueTarget]!,
    );
  }

  static String _fallbackTitle(NodeType type, int index) {
    final actions = switch (type) {
      NodeType.person || NodeType.interaction => const [
        'Pause for one breath before connecting',
        'Make one small gesture of attention',
        'Take two minutes to reflect after connecting',
      ],
      NodeType.place || NodeType.event || NodeType.chapter => const [
        'Take one minute to get ready',
        'Notice one useful detail',
        'Take two minutes to reset afterward',
      ],
      NodeType.goal ||
      NodeType.project ||
      NodeType.actionItem ||
      NodeType.promise ||
      NodeType.decision => const [
        'Open the next task for two minutes',
        'Complete one tiny next action',
        'Take one minute to choose the next step',
      ],
      NodeType.habit => const [
        'Begin the routine for two minutes',
        'Make the routine one step easier',
        'Mark the routine after trying it',
      ],
      NodeType.belief ||
      NodeType.memory ||
      NodeType.identityShift ||
      NodeType.archiveInsight ||
      NodeType.topic ||
      NodeType.text => const [
        'Pause for one minute of reflection',
        'Notice one concrete observation',
        'Write one short neutral note',
      ],
      NodeType.fear || NodeType.emotion || NodeType.outcome => const [
        'Pause and take one slow breath',
        'Notice one present detail',
        'Choose one gentle two-minute action',
      ],
      NodeType.object || NodeType.journalEntry => const [
        'Spend one minute getting started',
        'Do one small useful action',
        'Take one minute to note completion',
      ],
    };
    return actions[index];
  }

  static String _cleanOpaque(String value) {
    var token = value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    if (token.length > 120) token = token.substring(0, 120);
    return token;
  }

  static String _secureToken() {
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

  static Map<String, dynamic> _record(Object? value) {
    if (value is! Map) throw const FormatException('Expected object.');
    return Map<String, dynamic>.from(value);
  }

  static void _requireKeys(Map<String, dynamic> value, Set<String> keys) {
    final actual = value.keys.toSet();
    if (actual.length != keys.length ||
        actual.difference(keys).isNotEmpty ||
        keys.difference(actual).isNotEmpty) {
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

  static const _weekdayNumbers = {
    'monday': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'friday': DateTime.friday,
    'saturday': DateTime.saturday,
    'sunday': DateTime.sunday,
  };
}

final class _PreparedActionPlanRequest {
  const _PreparedActionPlanRequest({
    required this.payload,
    required this.localNodeIdByOpaque,
    required this.nodeTypeByLocalId,
  });

  final Map<String, Object> payload;
  final Map<String, String> localNodeIdByOpaque;
  final Map<String, NodeType> nodeTypeByLocalId;
}

final class _ActionPlanResult {
  const _ActionPlanResult({
    required this.title,
    required this.targetOutcome,
    required this.habits,
  });

  final String title;
  final String targetOutcome;
  final List<_ParsedHabit> habits;
}

final class _ParsedHabit {
  const _ParsedHabit({
    required this.title,
    required this.frequency,
    required this.localTargetNodeId,
  });

  final String title;
  final ActionPlanFrequency frequency;
  final String localTargetNodeId;
}
