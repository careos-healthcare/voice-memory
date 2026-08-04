import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph_store.dart';
import 'package:voicememory_mobile/core/search/local_vector_search_engine.dart';
import 'package:voicememory_mobile/features/action_plans/action_plan_store.dart';
import 'package:voicememory_mobile/features/autonomous_muse/autonomous_muse_models.dart';
import 'package:voicememory_mobile/features/autonomous_muse/autonomous_muse_service.dart';
import 'package:voicememory_mobile/features/autonomous_muse/autonomous_muse_store.dart';
import 'package:voicememory_mobile/features/semantic_clusters/semantic_cluster.dart';
import 'package:voicememory_mobile/features/semantic_clusters/semantic_cluster_store.dart';
import 'package:voicememory_mobile/services/ai/local_semantic_store.dart';
import 'package:voicememory_mobile/services/ai/sqlite_vec_vector_store.dart';
import 'package:voicememory_mobile/services/local_storage/encrypted_sqlite_text_codec.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';
import 'package:voicememory_mobile/ui/screens/life_os/graph_painter.dart';

void main() {
  test('schedules governance and rejects unavailable resources', () async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);

    await harness.service.updateGovernance(
      const MuseGovernance(
        minimumBatteryPercent: 60,
        frequency: MuseFrequency.everyTwoDays,
      ),
    );
    expect(harness.scheduler.scheduled?.frequency, MuseFrequency.everyTwoDays);

    final result = await harness.service.runSweep(
      resources: const MuseResourceState(
        isCharging: false,
        isWifiConnected: true,
        isIdle: true,
        batteryPercent: 90,
      ),
    );
    expect(result.status, MuseSweepStatus.skippedResources);
  });

  test('SQLite transaction rolls back partial Muse state', () async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);

    expect(
      () => harness.museStore.transaction(() {
        harness.museStore.writeGovernance(const MuseGovernance(enabled: false));
        throw StateError('interrupt');
      }),
      throwsStateError,
    );
    expect(harness.museStore.readGovernance().enabled, isTrue);
  });

  test(
    'dormant cross-cluster vectors create suggested dashed bridges',
    () async {
      final harness = await _Harness.create();
      addTearDown(harness.dispose);
      await harness.seedDormantGraph();

      final result = await harness.service.runSweep(force: true);
      expect(result.status, MuseSweepStatus.completed);
      expect(result.createdBridgeCount, 1);
      expect(result.briefing?.serendipity, isNotNull);

      final graph = await harness.graphStore.load();
      final edge = graph.edges.single;
      expect(edge.origin, NodeOrigin.autonomousMuse);
      expect(knowledgeGraphEdgeIsDashed(edge), isTrue);
      expect(edge.sourceNodeId, isNot(edge.targetNodeId));
      expect(harness.museStore.latestBriefing()?.discoveries, hasLength(1));
    },
  );
}

final class _Harness {
  _Harness({
    required this.root,
    required this.museStore,
    required this.graphStore,
    required this.clusterStore,
    required this.semanticStore,
    required this.actionPlanStore,
    required this.scheduler,
    required this.service,
  });

  final Directory root;
  final AutonomousMuseStore museStore;
  final PersonalKnowledgeGraphStore graphStore;
  final SemanticClusterStore clusterStore;
  final LocalSemanticStore semanticStore;
  final ActionPlanStore actionPlanStore;
  final _Scheduler scheduler;
  final AutonomousMuseService service;

  static Future<_Harness> create() async {
    final root = await Directory.systemTemp.createTemp('autonomous_muse_');
    EncryptedJsonFileStore encrypted(String name) => EncryptedJsonFileStore(
      file: File('${root.path}/$name.enc'),
      keyStore: InMemoryPrivateDataEncryptionKeyStore(),
    );
    final museStore = AutonomousMuseStore.open(
      databasePath: '${root.path}/muse.sqlite3',
      codec: EncryptedSqliteTextCodec(
        () => Uint8List.fromList(List<int>.filled(32, 7)),
      ),
    );
    final graphStore = PersonalKnowledgeGraphStore(storage: encrypted('graph'));
    final clusterStore = SemanticClusterStore(storage: encrypted('clusters'));
    final vectorStore = await SqliteVecVectorStore.open(
      databasePath: '${root.path}/semantic.sqlite3',
      dimensions: const HashedLocalEmbeddingDriver().dimensions,
    );
    final semanticStore = LocalSemanticStore(
      storage: encrypted('semantic'),
      vectorStore: vectorStore,
    );
    final actionPlanStore = ActionPlanStore(storage: encrypted('plans'));
    final scheduler = _Scheduler();
    final service = AutonomousMuseService(
      store: museStore,
      graphStore: graphStore,
      clusterStore: clusterStore,
      semanticStore: semanticStore,
      actionPlanStore: actionPlanStore,
      scheduler: scheduler,
      clock: () => DateTime(2026, 7, 28, 3),
    );
    return _Harness(
      root: root,
      museStore: museStore,
      graphStore: graphStore,
      clusterStore: clusterStore,
      semanticStore: semanticStore,
      actionPlanStore: actionPlanStore,
      scheduler: scheduler,
      service: service,
    );
  }

  Future<void> seedDormantGraph() async {
    final first = _node(
      'first',
      'Learning to listen',
      DateTime.utc(2019, 4, 10),
    );
    final second = _node(
      'second',
      'Listening as leadership',
      DateTime.utc(2024, 9, 12),
    );
    await graphStore.save(PersonalKnowledgeGraph(nodes: [first, second]));
    await clusterStore.replace([
      SemanticCluster(
        id: 'old-journal',
        title: 'Old journal',
        category: SemanticClusterCategory.theme,
        nodeIds: [first.id],
        activityVelocity: .1,
        confidenceScore: .9,
        updatedAt: DateTime.utc(2025),
      ),
      SemanticCluster(
        id: 'voice-reflections',
        title: 'Voice reflections',
        category: SemanticClusterCategory.belief,
        nodeIds: [second.id],
        activityVelocity: .1,
        confidenceScore: .9,
        updatedAt: DateTime.utc(2025),
      ),
    ]);
    await semanticStore.upsertMediaMemory(
      sourceNodeId: 'journal-source',
      searchableText: 'deep listening creates trust patient leadership',
      nodeIds: [first.id],
      tags: const ['journal'],
    );
    await semanticStore.upsertMediaMemory(
      sourceNodeId: 'voice-source',
      searchableText: 'patient leadership creates trust through deep listening',
      nodeIds: [second.id],
      tags: const ['voice'],
    );
  }

  Future<void> dispose() async {
    museStore.close();
    await semanticStore.dispose();
    clusterStore.dispose();
    actionPlanStore.dispose();
    await graphStore.dispose();
    if (await root.exists()) await root.delete(recursive: true);
  }
}

final class _Scheduler implements MuseBackgroundScheduler {
  MuseGovernance? scheduled;
  bool cancelled = false;

  @override
  Future<void> cancel() async => cancelled = true;

  @override
  Future<void> schedule(MuseGovernance governance) async {
    scheduled = governance;
  }
}

GraphNode _node(String id, String label, DateTime observedAt) => GraphNode(
  id: id,
  type: NodeType.belief,
  label: label,
  confidence: .9,
  createdAt: observedAt,
  evidence: [
    GraphNodeEvidence(
      entryId: 'entry-$id',
      observedAt: observedAt,
      confidence: .9,
      excerpt: label,
      startUtf16: 0,
      endUtf16: label.length,
    ),
  ],
);
