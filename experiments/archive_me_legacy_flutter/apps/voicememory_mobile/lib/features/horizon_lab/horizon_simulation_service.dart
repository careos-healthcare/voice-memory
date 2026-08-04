import 'dart:math';

import '../../api/api_transport.dart';
import '../../core/graph/graph_node.dart';
import '../../services/capture_attest_service.dart';
import '../semantic_clusters/semantic_cluster.dart';
import 'horizon_lab_service.dart';
import 'horizon_models.dart';

final class HorizonSimulationParameters {
  HorizonSimulationParameters({
    required num resourceCommitment,
    required num changeTolerance,
    required num timeCommitment,
    required num uncertaintyTolerance,
  }) : resourceCommitment = _unit(resourceCommitment),
       changeTolerance = _unit(changeTolerance),
       timeCommitment = _unit(timeCommitment),
       uncertaintyTolerance = _unit(uncertaintyTolerance);

  final double resourceCommitment;
  final double changeTolerance;
  final double timeCommitment;
  final double uncertaintyTolerance;

  Map<String, double> toJson() => {
    'resourceCommitment': resourceCommitment,
    'changeTolerance': changeTolerance,
    'timeCommitment': timeCommitment,
    'uncertaintyTolerance': uncertaintyTolerance,
  };
}

final class HorizonSimulationService {
  HorizonSimulationService({
    required this.transport,
    required this.attest,
    required this.lab,
    Random? random,
  }) : _random = random ?? Random.secure();

  final ApiTransport transport;
  final CaptureAttestService attest;
  final HorizonLabService lab;
  final Random _random;

  Future<TimelineBranch> project({
    required TimelineBranch branch,
    required List<SemanticCluster> clusters,
    required HorizonSimulationParameters parameters,
  }) async {
    final token = await attest.ensureCaptureToken();
    final response = await transport.postJson(
      '/api/horizon-simulation',
      headers: {
        ...transport.jsonHeaders,
        ApiTransport.captureTokenHeader: token,
        'x-vm-client': 'voicememory-mobile',
      },
      body: buildAnonymizedPayload(
        branch: branch,
        clusters: clusters,
        parameters: parameters,
      ),
    );
    final json = transport.decodeJson(response);
    final rows = json['projections'];
    if (rows is! List || rows.length != 3) {
      throw const FormatException('Invalid horizon simulation response.');
    }
    final projections = rows.whereType<Map>().map((row) {
      final value = Map<String, dynamic>.from(row);
      return HorizonProjectedNode(
        id: value['id'] as String,
        horizon: switch ((value['year'] as num).toInt()) {
          1 => HorizonProjection.oneYear,
          3 => HorizonProjection.threeYears,
          5 => HorizonProjection.fiveYears,
          _ => throw const FormatException('Invalid projection year.'),
        },
        label: value['label'] as String,
        probability: value['probability'] as num,
        type: _nodeType(value['nodeType']),
        risks: HorizonRiskVector.fromJson(
          Map<String, dynamic>.from(value['vectors'] as Map),
        ),
        rippleTargetIds: [branch.divergenceNodeId],
      );
    }).toList();
    return lab.addProjections(branch.id, projections);
  }

  Map<String, Object> buildAnonymizedPayload({
    required TimelineBranch branch,
    required List<SemanticCluster> clusters,
    required HorizonSimulationParameters parameters,
  }) {
    final divergence = branch.overlay.nodes
        .where((node) => node.id == branch.divergenceNodeId)
        .first;
    return {
      'divergence': {
        'typeToken': divergence.type.name,
        'confidence': divergence.confidence,
        'degree': branch.overlay.edges
            .where(
              (edge) =>
                  edge.sourceNodeId == divergence.id ||
                  edge.targetNodeId == divergence.id,
            )
            .length,
      },
      'clusters': [
        for (final cluster in clusters.take(24))
          {
            'token': 'c_${_randomToken()}',
            'category': cluster.category.wireName,
            'size': cluster.nodeIds.length.clamp(0, 500),
            'velocity': cluster.activityVelocity,
            'confidence': cluster.confidenceScore,
          },
      ],
      'parameters': parameters.toJson(),
    };
  }

  String _randomToken() =>
      List.generate(8, (_) => _random.nextInt(16).toRadixString(16)).join();

  static NodeType _nodeType(Object? value) => switch (value) {
    'decision' => NodeType.decision,
    'goal' => NodeType.goal,
    'project' => NodeType.project,
    'emotion' => NodeType.emotion,
    'outcome' => NodeType.outcome,
    'habit' => NodeType.habit,
    _ => NodeType.outcome,
  };
}

double _unit(num value) => value.toDouble().clamp(0, 1);
