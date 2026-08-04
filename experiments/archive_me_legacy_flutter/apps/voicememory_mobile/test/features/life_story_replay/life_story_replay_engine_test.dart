import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph_store.dart';
import 'package:voicememory_mobile/features/life_simulator/life_simulator_models.dart';
import 'package:voicememory_mobile/features/life_simulator/life_simulator_store.dart';
import 'package:voicememory_mobile/features/life_story_replay/life_story_models.dart';
import 'package:voicememory_mobile/features/life_story_replay/life_story_replay_engine.dart';
import 'package:voicememory_mobile/features/semantic_clusters/semantic_cluster_store.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  test(
    'SQLite aggregation returns graph history in chronological order',
    () async {
      final harness = await _Harness.create();
      addTearDown(harness.dispose);
      await harness.graphStore.save(
        PersonalKnowledgeGraph(
          nodes: [
            _node('third', DateTime.utc(2025, 9)),
            _node('first', DateTime.utc(2024, 1)),
            _node('second', DateTime.utc(2025, 2)),
          ],
        ),
      );

      final timeline = await harness.engine.generate();

      expect(
        timeline.points.map((point) => point.timestamp).toList(),
        orderedEquals([
          DateTime.utc(2024, 1),
          DateTime.utc(2025, 2),
          DateTime.utc(2025, 9),
        ]),
      );
    },
  );

  test(
    'identity shift and long temporal gap create documentary chapters',
    () async {
      final harness = await _Harness.create();
      addTearDown(harness.dispose);
      final points = [
        for (var index = 0; index < 3; index++)
          _point('origin-$index', DateTime.utc(2020, 1, index + 1)),
        _point(
          'pivot',
          DateTime.utc(2021),
          kind: LifeStoryPointKind.identityShift,
          significance: 1,
        ),
        _point('after-1', DateTime.utc(2021, 1, 2)),
        _point('after-2', DateTime.utc(2021, 1, 3)),
        _point('horizon', DateTime.utc(2022)),
      ];

      final chapters = harness.engine.segmentChapters(points);

      expect(chapters, hasLength(3));
      expect(chapters.first.title, 'Genesis');
      expect(chapters[1].title, 'The Great Pivot');
      expect(
        chapters.expand((chapter) => chapter.points),
        orderedEquals(points),
      );
    },
  );

  test(
    'simulation milestones align to generated timestamp plus horizon',
    () async {
      final harness = await _Harness.create();
      addTearDown(harness.dispose);
      await harness.graphStore.save(
        PersonalKnowledgeGraph(nodes: [_node('focus', DateTime.utc(2026, 1))]),
      );
      final generatedAt = DateTime.utc(2026, 2, 1);
      await harness.simulatorStore.upsert(
        CounterfactualScenario(
          continueTrajectory: _trajectory(
            SimulationPath.continueTrajectory,
            generatedAt,
          ),
          alternativeTrajectory: _trajectory(
            SimulationPath.pivotTrajectory,
            generatedAt,
          ),
        ),
      );

      final timeline = await harness.engine.generate();
      final projected = timeline.points
          .where(
            (point) => point.kind == LifeStoryPointKind.simulationMilestone,
          )
          .toList();

      expect(projected, hasLength(6));
      expect(
        projected.first.timestamp,
        generatedAt.add(const Duration(days: 30)),
      );
      expect(
        projected.last.timestamp,
        generatedAt.add(const Duration(days: 365)),
      );
      expect(projected.every((point) => point.projected), isTrue);
    },
  );
}

GraphNode _node(String id, DateTime createdAt) => GraphNode(
  id: id,
  type: NodeType.memory,
  label: id,
  confidence: .8,
  createdAt: createdAt,
  evidence: [
    GraphNodeEvidence(
      entryId: 'entry-$id',
      observedAt: createdAt,
      confidence: .8,
      excerpt: id,
      startUtf16: 0,
      endUtf16: id.length,
    ),
  ],
);

LifeStoryPoint _point(
  String id,
  DateTime timestamp, {
  LifeStoryPointKind kind = LifeStoryPointKind.node,
  double significance = .5,
}) => LifeStoryPoint(
  id: id,
  kind: kind,
  timestamp: timestamp,
  significance: significance,
  sentiment: 0,
  nodeIds: [id],
);

SimulationTrajectory _trajectory(SimulationPath path, DateTime generatedAt) =>
    SimulationTrajectory(
      id: 'trajectory-${path.name}',
      target: SimulationTarget.graphNode('focus'),
      path: path,
      generatedAt: generatedAt,
      milestones: [
        for (final days in const [30, 90, 365])
          ProjectedMilestone(
            days: days,
            projectedConfidence: .7,
            stressImpactScore: .1,
            narrativeSummary: 'An anonymous projected horizon.',
            affectedNodeIds: const ['focus'],
          ),
      ],
    );

final class _Harness {
  const _Harness(
    this.root,
    this.graphStore,
    this.clusterStore,
    this.simulatorStore,
    this.index,
    this.engine,
  );

  final Directory root;
  final PersonalKnowledgeGraphStore graphStore;
  final SemanticClusterStore clusterStore;
  final LifeSimulatorStore simulatorStore;
  final LifeStoryReplayIndex index;
  final LifeStoryReplayEngine engine;

  static Future<_Harness> create() async {
    final root = await Directory.systemTemp.createTemp('life-story-engine-');
    final keys = InMemoryPrivateDataEncryptionKeyStore();
    EncryptedJsonFileStore encrypted(String name) => EncryptedJsonFileStore(
      file: File('${root.path}/$name.enc'),
      keyStore: keys,
    );
    final graph = PersonalKnowledgeGraphStore(storage: encrypted('graph'));
    final clusters = SemanticClusterStore(storage: encrypted('clusters'));
    final simulator = LifeSimulatorStore(storage: encrypted('simulator'));
    final index = LifeStoryReplayIndex.open('${root.path}/replay.db');
    final engine = LifeStoryReplayEngine(
      graphStore: graph,
      clusterStore: clusters,
      simulatorStore: simulator,
      index: index,
      clock: () => DateTime.utc(2026, 7, 28),
    );
    return _Harness(root, graph, clusters, simulator, index, engine);
  }

  Future<void> dispose() async {
    clusterStore.dispose();
    await graphStore.dispose();
    index.close();
    if (await root.exists()) await root.delete(recursive: true);
  }
}
