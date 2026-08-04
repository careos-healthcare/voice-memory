import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/features/life_simulator/life_simulator_engine.dart';
import 'package:voicememory_mobile/features/life_simulator/life_simulator_models.dart';
import 'package:voicememory_mobile/features/life_simulator/life_simulator_store.dart';
import 'package:voicememory_mobile/features/semantic_clusters/semantic_cluster.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  group('LifeSimulatorEngine', () {
    test('extrapolates momentum and never mutates the source graph', () {
      final graph = _graph();
      final before = graph.toJson();
      final engine = LifeSimulatorEngine(clock: () => DateTime.utc(2026, 3, 2));

      final continuing = engine.simulate(
        graph: graph,
        target: SimulationTarget.habit('habit'),
        path: SimulationPath.continueTrajectory,
        clusters: [_cluster],
      );
      final stopping = engine.simulate(
        graph: graph,
        target: SimulationTarget.habit('habit'),
        path: SimulationPath.stopTrajectory,
        clusters: [_cluster],
      );

      expect(continuing.milestones.map((item) => item.days), [30, 90, 365]);
      expect(
        continuing.milestones.last.projectedConfidence,
        greaterThan(continuing.milestones.first.projectedConfidence),
      );
      expect(
        stopping.milestones.last.projectedConfidence,
        lessThan(stopping.milestones.first.projectedConfidence),
      );
      expect(graph.toJson(), before);
      expect(
        continuing.milestones.every(
          (item) => item.narrativeSummary.contains('non-diagnostic'),
        ),
        isTrue,
      );
    });

    test(
      'strengthens, prunes, and pivots incident edges deterministically',
      () {
        final graph = _graph();
        const engine = LifeSimulatorEngine();
        final target = SimulationTarget.habit('habit');

        final continuing = engine.simulate(
          graph: graph,
          target: target,
          path: SimulationPath.continueTrajectory,
          clusters: [_cluster],
        );
        final stopping = engine.simulate(
          graph: graph,
          target: target,
          path: SimulationPath.stopTrajectory,
          clusters: [_cluster],
        );
        final pivoting = engine.simulate(
          graph: graph,
          target: target,
          path: SimulationPath.pivotTrajectory,
          clusters: [_cluster],
        );

        expect(
          continuing.milestones.last.projectedEdgeWeights['causal'],
          greaterThan(.8),
        );
        expect(stopping.milestones.last.projectedEdgeWeights['causal'], 0);
        expect(
          pivoting.milestones.last.projectedEdgeWeights['positive'],
          greaterThan(.55),
        );
        expect(
          pivoting.milestones.last.projectedEdgeWeights['negative'],
          lessThan(.7),
        );
      },
    );

    test('bounds every projection and propagates graph ripple scores', () {
      final trajectory = const LifeSimulatorEngine().simulate(
        graph: _graph(),
        target: SimulationTarget.semanticCluster('cluster'),
        path: SimulationPath.continueTrajectory,
        clusters: [_cluster],
      );

      for (final milestone in trajectory.milestones) {
        expect(milestone.projectedConfidence, inInclusiveRange(0, 1));
        expect(milestone.stressImpactScore, inInclusiveRange(-1, 1));
        expect(
          milestone.projectedNodeScores.values,
          everyElement(inInclusiveRange(0, 1)),
        );
        expect(
          milestone.projectedEdgeWeights.values,
          everyElement(inInclusiveRange(0, 1)),
        );
      }
      expect(
        trajectory.milestones.last.affectedNodeIds,
        contains('positive-node'),
      );
    });

    test('reports Health and Spotify correlations only with external data', () {
      final graph = _graph(includeExternal: true);
      final milestone = const LifeSimulatorEngine()
          .simulate(
            graph: graph,
            target: SimulationTarget.habit('habit'),
            path: SimulationPath.continueTrajectory,
            clusters: [_cluster],
          )
          .milestones
          .first;

      expect(milestone.healthCorrelation, closeTo(1, .0001));
      expect(milestone.externalCorrelations['spotify'], closeTo(-1, .0001));

      final withoutExternal = const LifeSimulatorEngine()
          .simulate(
            graph: _graph(),
            target: SimulationTarget.habit('habit'),
            path: SimulationPath.continueTrajectory,
          )
          .milestones
          .first;
      expect(withoutExternal.healthCorrelation, isNull);
    });
  });

  group('Life simulator models and store', () {
    test('round-trips immutable JSON and accepts legacy keys strictly', () {
      final scenario = _scenario('private-habit');
      final restored = CounterfactualScenario.fromJson(scenario.toJson());
      expect(restored.toJson(), scenario.toJson());
      expect(
        SimulationTarget.fromJson({
          'type': 'semanticCluster',
          'targetId': 'legacy-cluster',
          'label': 'Legacy cluster',
        }).kind,
        SimulationTargetKind.semanticCluster,
      );
      expect(
        ProjectedMilestone.fromJson({
          'horizon_days': 30,
          'projected_confidence': .5,
          'stress_impact_score': -.2,
          'narrative_summary': 'Conditional summary.',
        }).healthCorrelation,
        isNull,
      );
      expect(
        () => ProjectedMilestone.fromJson({
          'days': 31,
          'projectedConfidence': .5,
          'stressImpactScore': 0,
          'narrativeSummary': 'Invalid horizon.',
        }),
        throwsArgumentError,
      );
      expect(
        () =>
            SimulationTarget.fromJson({'kind': 'graph_node', 'referenceId': 4}),
        throwsFormatException,
      );
      expect(
        () => restored.continueTrajectory.milestones.add(
          restored.continueTrajectory.milestones.first,
        ),
        throwsUnsupportedError,
      );
    });

    test('serializes writes and keeps scenario content encrypted', () async {
      final directory = await Directory.systemTemp.createTemp('life_simulator');
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });
      final file = File('${directory.path}/simulations.enc');
      final store = LifeSimulatorStore(
        storage: EncryptedJsonFileStore(
          file: file,
          keyStore: InMemoryPrivateDataEncryptionKeyStore(),
        ),
      );

      await Future.wait([
        for (var index = 0; index < 8; index++)
          store.upsert(_scenario('private-habit-$index')),
      ]);

      expect(await store.list(), hasLength(8));
      expect(await file.readAsString(), isNot(contains('private-habit')));
      expect(
        await EncryptedJsonFileStore.fileOmitsPlaintextNeedle(
          file,
          'Conditional private-habit',
        ),
        isTrue,
      );
    });
  });
}

final _cluster = SemanticCluster(
  id: 'cluster',
  title: 'Habit and support',
  category: SemanticClusterCategory.habitCluster,
  nodeIds: const ['habit', 'positive-node'],
  activityVelocity: .75,
  confidenceScore: .8,
);

PersonalKnowledgeGraph _graph({bool includeExternal = false}) {
  final dates = [
    DateTime.utc(2026, 1, 1),
    DateTime.utc(2026, 2, 1),
    DateTime.utc(2026, 3, 1),
  ];
  final targetEvidence = [
    _nodeEvidence('target-1', dates[0], .4),
    _nodeEvidence('target-2', dates[1], .5),
    _nodeEvidence('target-3', dates[2], .6),
  ];
  final nodes = <GraphNode>[
    GraphNode(
      id: 'habit',
      type: NodeType.habit,
      label: 'Evening reflection',
      confidence: .6,
      evidence: targetEvidence,
    ),
    GraphNode(
      id: 'positive-node',
      type: NodeType.goal,
      label: 'Calm progress',
      confidence: .65,
      evidence: [_nodeEvidence('positive', dates.last, .65)],
    ),
    GraphNode(
      id: 'stress-node',
      type: NodeType.fear,
      label: 'Stress about falling behind',
      confidence: .7,
      evidence: [_nodeEvidence('stress', dates.last, .7)],
    ),
    if (includeExternal) ...[
      _externalNode(
        'health-1',
        'Sleep: 2.0h',
        dates[0],
        ExternalSource.appleHealth,
      ),
      _externalNode(
        'health-2',
        'Sleep: 5.0h',
        dates[1],
        ExternalSource.appleHealth,
      ),
      _externalNode(
        'health-3',
        'Sleep: 8.0h',
        dates[2],
        ExternalSource.appleHealth,
      ),
      _externalNode(
        'spotify-1',
        'Music valence: 80%',
        dates[0],
        ExternalSource.spotify,
      ),
      _externalNode(
        'spotify-2',
        'Music valence: 50%',
        dates[1],
        ExternalSource.spotify,
      ),
      _externalNode(
        'spotify-3',
        'Music valence: 20%',
        dates[2],
        ExternalSource.spotify,
      ),
    ],
  ];
  return PersonalKnowledgeGraph(
    nodes: nodes,
    edges: [
      _edge(
        id: 'causal',
        targetId: 'stress-node',
        type: EdgeType.influences,
        weight: .8,
        valence: -.8,
      ),
      _edge(
        id: 'positive',
        targetId: 'positive-node',
        type: EdgeType.associatedWith,
        weight: .55,
        valence: .9,
      ),
      _edge(
        id: 'negative',
        targetId: 'stress-node',
        type: EdgeType.associatedWith,
        weight: .7,
        valence: -.9,
      ),
    ],
  );
}

GraphNode _externalNode(
  String id,
  String label,
  DateTime date,
  ExternalSource source,
) => GraphNode(
  id: id,
  type: NodeType.habit,
  label: label,
  confidence: 1,
  evidence: [_nodeEvidence(id, date, 1, excerpt: label)],
  origin: NodeOrigin.external,
  externalSource: source,
  createdAt: date,
);

GraphEdge _edge({
  required String id,
  required String targetId,
  required EdgeType type,
  required double weight,
  required double valence,
}) => GraphEdge(
  id: id,
  sourceNodeId: 'habit',
  targetNodeId: targetId,
  type: type,
  isDirected: false,
  weight: weight,
  emotionalValenceScore: valence,
  intensity: weight,
  evidence: [_edgeEvidence(id, DateTime.utc(2026, 3, 1), weight)],
);

GraphNodeEvidence _nodeEvidence(
  String id,
  DateTime date,
  double confidence, {
  String? excerpt,
}) {
  final text = excerpt ?? 'Evidence $id';
  return GraphNodeEvidence(
    entryId: id,
    observedAt: date,
    confidence: confidence,
    excerpt: text,
    startUtf16: 0,
    endUtf16: text.length,
  );
}

GraphEdgeEvidence _edgeEvidence(String id, DateTime date, double confidence) {
  final text = 'Edge evidence $id';
  return GraphEdgeEvidence(
    entryId: id,
    observedAt: date,
    confidence: confidence,
    excerpt: text,
    startUtf16: 0,
    endUtf16: text.length,
  );
}

CounterfactualScenario _scenario(String targetId) {
  final target = SimulationTarget.habit(targetId, displayLabel: targetId);
  return CounterfactualScenario(
    continueTrajectory: _trajectory(target, SimulationPath.continueTrajectory),
    alternativeTrajectory: _trajectory(target, SimulationPath.stopTrajectory),
  );
}

SimulationTrajectory _trajectory(
  SimulationTarget target,
  SimulationPath path,
) => SimulationTrajectory(
  target: target,
  path: path,
  generatedAt: DateTime.utc(2026, 7, 27),
  milestones: [
    for (final days in const [30, 90, 365])
      ProjectedMilestone(
        days: days,
        projectedConfidence: .5,
        stressImpactScore: 0,
        narrativeSummary: 'Conditional ${target.referenceId} scenario.',
        localCitationHandles: const ['entry:0:8'],
      ),
  ],
);
