import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph_store.dart';
import 'package:voicememory_mobile/features/semantic_clusters/semantic_cluster.dart';
import 'package:voicememory_mobile/features/semantic_clusters/semantic_cluster_engine.dart';
import 'package:voicememory_mobile/features/semantic_clusters/semantic_cluster_rebuild_coordinator.dart';
import 'package:voicememory_mobile/features/semantic_clusters/semantic_cluster_store.dart';
import 'package:voicememory_mobile/services/ai/local_semantic_store.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  group('SemanticCluster', () {
    test('round-trips portable JSON and accepts legacy wire keys', () {
      final cluster = SemanticCluster(
        id: 'cluster-a',
        title: 'Core people',
        category: SemanticClusterCategory.peopleNetwork,
        nodeIds: const ['b', 'a', 'a'],
        activityVelocity: 0.5,
        confidenceScore: 0.8,
        summary: 'A safe summary',
        pinned: true,
        updatedAt: DateTime.utc(2026, 7, 1),
        userEdited: true,
      );

      expect(
        SemanticCluster.fromJson(cluster.toJson()).toJson(),
        cluster.toJson(),
      );
      expect(cluster.nodeIds, ['a', 'b']);
      expect(cluster.toPortableJson()['category'], 'people_network');
      expect(
        SemanticCluster.fromJson({
          'id': 'legacy',
          'title': 'Legacy',
          'category': 'habitCluster',
          'node_ids': ['a', 'b'],
          'activity_velocity': 0.2,
          'confidence_score': 0.7,
        }).category,
        SemanticClusterCategory.habitCluster,
      );
      expect(
        () => SemanticCluster.fromJson({
          'id': 'bad',
          'title': 'Bad',
          'nodeIds': [1],
        }),
        throwsFormatException,
      );
    });
  });

  group('SemanticClusterEngine', () {
    late Directory directory;
    late EncryptedJsonFileStore semanticStorage;
    late LocalSemanticStore semanticStore;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('semantic_clusters');
      semanticStorage = EncryptedJsonFileStore(
        file: File('${directory.path}/semantic.enc'),
        keyStore: InMemoryPrivateDataEncryptionKeyStore(),
      );
      semanticStore = LocalSemanticStore(storage: semanticStorage);
      await _writeVectors(semanticStorage, {
        'p1': [1, 0],
        'p2': [0.99, 0.01],
        'p3': [0.98, 0.02],
        'h1': [-1, 0],
        'h2': [-0.99, 0.01],
        'h3': [-0.98, 0.02],
        'outlier': [-1, 0],
      });
    });

    tearDown(() async {
      await directory.delete(recursive: true);
    });

    test(
      'finds dense communities, refines by vectors, and drops outliers',
      () async {
        final graph = _fixtureGraph();
        final engine = SemanticClusterEngine(
          semanticStore: semanticStore,
          clock: () => DateTime.utc(2026, 7, 27),
        );

        final clusters = await engine.build(graph);
        final reversed = await engine.build(
          PersonalKnowledgeGraph(
            nodes: graph.nodes.reversed,
            edges: graph.edges.reversed,
          ),
        );

        expect(clusters, hasLength(2));
        expect(clusters.map((item) => item.nodeIds.toSet()).toSet(), {
          {'p1', 'p2', 'p3'},
          {'h1', 'h2', 'h3'},
        });
        expect(
          clusters.expand((item) => item.nodeIds),
          isNot(contains('outlier')),
        );
        expect(
          reversed.map((item) => item.id),
          clusters.map((item) => item.id),
        );
        expect(
          clusters.singleWhere((item) => item.nodeIds.contains('p1')).category,
          SemanticClusterCategory.project,
        );
        final habits = clusters.singleWhere(
          (item) => item.nodeIds.contains('h1'),
        );
        expect(habits.category, SemanticClusterCategory.habitCluster);
        expect(habits.activityVelocity, closeTo(2 / 3, 0.0001));
        expect(habits.confidenceScore, inInclusiveRange(0.5, 1));
      },
    );

    test('applies stored rename, pin, merge, and split overrides', () async {
      final engine = SemanticClusterEngine(
        semanticStore: semanticStore,
        clock: () => DateTime.utc(2026, 7, 27),
      );
      final initial = await engine.build(_fixtureGraph());
      final merged = SemanticCluster(
        id: stableGraphId('semantic-cluster', [
          'h1',
          'h2',
          'h3',
          'p1',
          'p2',
          'p3',
        ]),
        title: 'My combined focus',
        category: SemanticClusterCategory.theme,
        nodeIds: initial.expand((item) => item.nodeIds),
        activityVelocity: 0,
        confidenceScore: 0,
        pinned: true,
        updatedAt: DateTime.utc(2026, 7, 27),
        userEdited: true,
      );

      final overridden = await engine.build(
        _fixtureGraph(),
        storedClusters: [merged],
      );

      expect(overridden, hasLength(1));
      expect(overridden.single.title, 'My combined focus');
      expect(overridden.single.pinned, isTrue);
      expect(overridden.single.nodeIds, hasLength(6));
    });

    test('exposes only aggregated vectors and safe timestamps', () async {
      final vectors = await semanticStore.readAggregatedNodeVectors(
        nodeIds: const ['p1'],
      );

      expect(vectors, hasLength(1));
      expect(vectors.single.nodeId, 'p1');
      expect(vectors.single.sampleCount, 1);
      expect(vectors.single.vector.length, 2);
      expect(vectors.single.updatedAt.isUtc, isTrue);
    });

    test('normalizes record means and reports aggregate metadata', () async {
      await semanticStorage.writeJson({
        'schemaVersion': 2,
        'dimensions': 2,
        'records': [
          {
            'entryId': 'older',
            'revision': 'one',
            'vector': [1, 0],
            'nodeIds': ['shared'],
            'tags': const <String>[],
            'updatedAt': DateTime.utc(2026, 7, 1).toIso8601String(),
          },
          {
            'entryId': 'newer',
            'revision': 'two',
            'vector': [0, 1],
            'nodeIds': ['shared'],
            'tags': const <String>[],
            'updatedAt': DateTime.utc(2026, 7, 22).toIso8601String(),
          },
        ],
      });

      final aggregate = (await semanticStore.readAggregatedNodeVectors(
        nodeIds: const ['shared'],
      )).single;

      expect(aggregate.sampleCount, 2);
      expect(aggregate.vector[0], closeTo(1 / sqrt(2), 0.0001));
      expect(aggregate.vector[1], closeTo(1 / sqrt(2), 0.0001));
      expect(aggregate.updatedAt, DateTime.utc(2026, 7, 22));
    });

    test('coalesces rebuild requests into encrypted cluster state', () async {
      final graphStore = PersonalKnowledgeGraphStore(
        storage: EncryptedJsonFileStore(
          file: File('${directory.path}/graph.enc'),
          keyStore: InMemoryPrivateDataEncryptionKeyStore(),
        ),
      );
      final clusterStore = SemanticClusterStore(
        storage: EncryptedJsonFileStore(
          file: File('${directory.path}/clusters.enc'),
          keyStore: InMemoryPrivateDataEncryptionKeyStore(),
        ),
      );
      await graphStore.save(_fixtureGraph());
      expect((await graphStore.load()).nodes, hasLength(7));
      var labelsRequested = 0;
      var snapshotsChanged = 0;
      final coordinator = SemanticClusterRebuildCoordinator(
        graphStore: graphStore,
        clusterStore: clusterStore,
        engine: SemanticClusterEngine(
          semanticStore: semanticStore,
          clock: () => DateTime.utc(2026, 7, 27),
        ),
        labelCluster: (cluster, graph) async {
          labelsRequested++;
          expect(graph.nodes, isNotEmpty);
          return cluster.copyWith(summary: 'Cloud-labeled structure');
        },
        onClustersChanged: () async {
          snapshotsChanged++;
        },
        debounce: Duration.zero,
      );

      await Future.wait([coordinator.rebuildNow(), coordinator.rebuildNow()]);

      final clusters = await clusterStore.list();
      expect(clusters, hasLength(2));
      expect(
        clusters,
        everyElement(
          isA<SemanticCluster>().having(
            (cluster) => cluster.summary,
            'summary',
            'Cloud-labeled structure',
          ),
        ),
      );
      expect(labelsRequested, 2);
      expect(snapshotsChanged, 2);
      await coordinator.dispose();
      clusterStore.dispose();
      await graphStore.dispose();
    });
  });

  group('SemanticClusterStore', () {
    late Directory directory;
    late SemanticClusterStore store;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('cluster_store');
      store = SemanticClusterStore(
        storage: EncryptedJsonFileStore(
          file: File('${directory.path}/clusters.enc'),
          keyStore: InMemoryPrivateDataEncryptionKeyStore(),
        ),
        clock: () => DateTime.utc(2026, 7, 27),
      );
    });

    tearDown(() async {
      store.dispose();
      await directory.delete(recursive: true);
    });

    test('persists serialized edits and publishes revisions', () async {
      final revisions = <int>[];
      final subscription = store.revisions.listen(revisions.add);
      await store.replace([
        _cluster('left', ['a', 'b']),
        _cluster('right', ['c', 'd']),
      ]);
      await store.rename('left', 'Renamed');
      await store.pin('left');
      final merged = await store.merge(const [
        'left',
        'right',
      ], title: 'Merged');

      expect((await store.list()).single.title, 'Merged');
      expect((await store.list()).single.pinned, isTrue);
      final split = await store.split(merged.id, const [
        ['a', 'b'],
        ['c', 'd'],
      ]);
      expect(split, hasLength(2));
      expect((await store.list()).every((item) => item.userEdited), isTrue);
      expect(store.revision, 5);
      expect(revisions, [1, 2, 3, 4, 5]);

      await store.clear();
      expect(await store.list(), isEmpty);
      await subscription.cancel();
    });
  });
}

SemanticCluster _cluster(String id, List<String> nodeIds) => SemanticCluster(
  id: id,
  title: id,
  category: SemanticClusterCategory.theme,
  nodeIds: nodeIds,
  activityVelocity: 0.2,
  confidenceScore: 0.7,
  updatedAt: DateTime.utc(2026, 7, 1),
);

PersonalKnowledgeGraph _fixtureGraph() {
  final recent = DateTime.utc(2026, 7, 20);
  final old = DateTime.utc(2026, 1, 1);
  final nodes = [
    _node('p1', NodeType.project, recent),
    _node('p2', NodeType.goal, recent),
    _node('p3', NodeType.project, old),
    _node('h1', NodeType.habit, recent),
    _node('h2', NodeType.habit, recent),
    _node('h3', NodeType.habit, old),
    _node('outlier', NodeType.topic, recent),
  ];
  final edges = <GraphEdge>[
    ..._clique(['p1', 'p2', 'p3']),
    ..._clique(['h1', 'h2', 'h3']),
    _edge('p1', 'outlier', 0.9),
    _edge('p3', 'h1', 0.7),
  ];
  return PersonalKnowledgeGraph(nodes: nodes, edges: edges);
}

GraphNode _node(String id, NodeType type, DateTime createdAt) => GraphNode(
  id: id,
  type: type,
  label: id.toUpperCase(),
  confidence: 0.9,
  createdAt: createdAt,
  evidence: [
    GraphNodeEvidence(
      entryId: 'entry-$id',
      observedAt: createdAt,
      confidence: 0.9,
      excerpt: id,
      startUtf16: 0,
      endUtf16: id.length,
    ),
  ],
);

List<GraphEdge> _clique(List<String> ids) => [
  for (var left = 0; left < ids.length; left++)
    for (var right = left + 1; right < ids.length; right++)
      _edge(ids[left], ids[right], 0.9),
];

GraphEdge _edge(String left, String right, double weight) => GraphEdge(
  sourceNodeId: left,
  targetNodeId: right,
  type: EdgeType.associatedWith,
  isDirected: false,
  weight: weight,
  evidence: [
    GraphEdgeEvidence(
      entryId: 'edge-$left-$right',
      observedAt: DateTime.utc(2026, 7, 20),
      confidence: weight,
      excerpt: '$left $right',
      startUtf16: 0,
      endUtf16: left.length + right.length + 1,
    ),
  ],
);

Future<void> _writeVectors(
  EncryptedJsonFileStore storage,
  Map<String, List<double>> vectors,
) => storage.writeJson({
  'schemaVersion': 2,
  'dimensions': 2,
  'records': [
    for (final entry in vectors.entries)
      {
        'entryId': 'entry-${entry.key}',
        'revision': 'revision-${entry.key}',
        'vector': entry.value,
        'nodeIds': [entry.key],
        'tags': const <String>[],
        'updatedAt': DateTime.utc(2026, 7, 20).toIso8601String(),
      },
  ],
});
