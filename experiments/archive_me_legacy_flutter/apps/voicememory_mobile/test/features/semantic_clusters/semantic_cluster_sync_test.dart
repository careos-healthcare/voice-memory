import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph_store.dart';
import 'package:voicememory_mobile/features/semantic_clusters/semantic_cluster.dart';
import 'package:voicememory_mobile/features/semantic_clusters/semantic_cluster_store.dart';
import 'package:voicememory_mobile/features/semantic_clusters/semantic_cluster_sync_coordinator.dart';
import 'package:voicememory_mobile/features/sync/e2ee_sync_models.dart';
import 'package:voicememory_mobile/features/sync/encrypted_sync_engine.dart';
import 'package:voicememory_mobile/features/sync/sync_outbox.dart';
import 'package:voicememory_mobile/services/ai/local_semantic_store.dart';
import 'package:voicememory_mobile/services/security/sync_identity_service.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  const phrase =
      'abandon abandon abandon abandon abandon abandon abandon abandon '
      'abandon abandon abandon about';

  test(
    'cluster snapshot stays encrypted and uses a strict portable payload',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'cluster_sync_outbox_',
      );
      final relay = _MemoryRelay();
      final harness = await _harness(root, 'device-a', phrase, relay);
      addTearDown(() async {
        await harness.dispose();
        if (await root.exists()) await root.delete(recursive: true);
      });
      await harness.clusterStore.replace([
        _cluster(
          title: 'Permitted cluster title',
          summary: 'Permitted model summary',
        ),
      ]);

      await harness.coordinator.recordCurrent(harness.engine);

      expect(harness.outbox.pendingCount, 1);
      final databaseBytes = latin1.decode(
        File(harness.outbox.databasePath).readAsBytesSync(),
      );
      expect(databaseBytes, isNot(contains('Permitted cluster title')));
      expect(databaseBytes, isNot(contains('private transcript words')));
      expect(databaseBytes, isNot(contains('/private/audio/path.m4a')));

      final key = await harness.engine.identity.requireKey();
      try {
        final operation = (await harness.outbox.pending(key: key)).single;
        expect(operation.entityKind, CrdtEntityKind.semanticCluster);
        expect(operation.payload.keys, hasLength(10));
        expect(
          operation.payload.keys,
          containsAll(const [
            'id',
            'title',
            'category',
            'nodeIds',
            'activityVelocity',
            'confidenceScore',
            'summary',
            'pinned',
            'updatedAt',
            'userEdited',
          ]),
        );
        final clearPayload = jsonEncode(operation.payload);
        expect(clearPayload, isNot(contains('private transcript words')));
        expect(clearPayload, isNot(contains('private evidence excerpt')));
        expect(clearPayload, isNot(contains('/private/audio/path.m4a')));
        expect(clearPayload, isNot(contains('Private graph node label')));
      } finally {
        key.destroy();
      }
    },
  );

  test(
    'remote apply restores the full user-edited cluster definition',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'cluster_sync_remote_',
      );
      final relay = _MemoryRelay();
      final sender = await _harness(root, 'sender', phrase, relay);
      final receiver = await _harness(root, 'receiver', phrase, relay);
      addTearDown(() async {
        await sender.dispose();
        await receiver.dispose();
        if (await root.exists()) await root.delete(recursive: true);
      });
      final cluster = _cluster(
        title: 'Renamed and merged',
        summary: 'Portable model summary',
        nodeIds: const ['node-a', 'node-b', 'node-c'],
        pinned: true,
        userEdited: true,
      );
      await sender.clusterStore.replace([cluster]);
      await sender.coordinator.recordCurrent(sender.engine);

      await sender.engine.syncNow();
      await receiver.engine.syncNow();

      expect(
        (await receiver.clusterStore.list()).single.toJson(),
        cluster.toJson(),
      );

      final split = [
        _cluster(
          id: 'split-left',
          title: 'Renamed and merged 1',
          nodeIds: const ['node-a', 'node-b'],
          pinned: true,
          userEdited: true,
        ),
        _cluster(
          id: 'split-right',
          title: 'Renamed and merged 2',
          nodeIds: const ['node-c', 'node-d'],
          pinned: true,
          userEdited: true,
        ),
      ];
      await sender.clusterStore.replace(split);
      await sender.coordinator.recordCurrent(sender.engine);
      await sender.engine.syncNow();
      await receiver.engine.syncNow();

      final receivedSplit = await receiver.clusterStore.list();
      expect(receivedSplit.map((item) => item.id), {
        'split-left',
        'split-right',
      });
      expect(receivedSplit.every((item) => item.userEdited), isTrue);
    },
  );

  test(
    'concurrent definitions converge on the deterministic CRDT winner',
    () async {
      final root = await Directory.systemTemp.createTemp('cluster_sync_lww_');
      final relay = _MemoryRelay();
      final generated = await _harness(root, 'device-a', phrase, relay);
      final edited = await _harness(root, 'device-z', phrase, relay);
      addTearDown(() async {
        await generated.dispose();
        await edited.dispose();
        if (await root.exists()) await root.delete(recursive: true);
      });
      await generated.clusterStore.replace([
        _cluster(title: 'Generated title'),
      ]);
      await edited.clusterStore.replace([
        _cluster(title: 'My pinned rename', pinned: true, userEdited: true),
      ]);
      await generated.coordinator.recordCurrent(generated.engine);
      await edited.coordinator.recordCurrent(edited.engine);

      await generated.engine.syncNow();
      await edited.engine.syncNow();
      await generated.engine.syncNow();

      for (final harness in [generated, edited]) {
        final winner = (await harness.clusterStore.list()).single;
        expect(winner.title, 'My pinned rename');
        expect(winner.pinned, isTrue);
        expect(winner.userEdited, isTrue);
      }
    },
  );
}

final class _Harness {
  const _Harness({
    required this.engine,
    required this.outbox,
    required this.graphStore,
    required this.clusterStore,
    required this.coordinator,
  });

  final EncryptedSyncEngine engine;
  final SyncOutbox outbox;
  final PersonalKnowledgeGraphStore graphStore;
  final SemanticClusterStore clusterStore;
  final SemanticClusterSyncCoordinator coordinator;

  Future<void> dispose() async {
    await engine.dispose();
    await graphStore.dispose();
    clusterStore.dispose();
    outbox.close();
  }
}

Future<_Harness> _harness(
  Directory root,
  String deviceId,
  String phrase,
  _MemoryRelay relay,
) async {
  final directory = Directory('${root.path}/$deviceId')..createSync();
  final identity = SyncIdentityService(store: MemorySyncIdentityStore());
  await identity.installRecoveryPhrase(phrase);
  final keyStore = InMemoryPrivateDataEncryptionKeyStore();
  EncryptedJsonFileStore storage(String name) => EncryptedJsonFileStore(
    file: File('${directory.path}/$name.enc'),
    keyStore: keyStore,
  );
  final graphStore = PersonalKnowledgeGraphStore(storage: storage('graph'));
  final clusterStore = SemanticClusterStore(storage: storage('clusters'));
  final coordinator = SemanticClusterSyncCoordinator(store: clusterStore);
  final outbox = SyncOutbox.open(databasePath: '${directory.path}/outbox.db');
  final engine = EncryptedSyncEngine(
    deviceId: deviceId,
    identity: identity,
    outbox: outbox,
    transport: relay,
    graphStore: graphStore,
    semanticStore: LocalSemanticStore(storage: storage('semantic')),
    isOnline: () => true,
    clock: () => DateTime.utc(2026, 7, 27),
    applyAuxiliaryOperation: coordinator.handler(),
  );
  return _Harness(
    engine: engine,
    outbox: outbox,
    graphStore: graphStore,
    clusterStore: clusterStore,
    coordinator: coordinator,
  );
}

final class _MemoryRelay implements E2EERelayTransport {
  final List<E2EESyncEnvelope> envelopes = [];

  @override
  Future<List<E2EESyncEnvelope>> pull() async => List.of(envelopes);

  @override
  Future<void> push(E2EESyncEnvelope envelope) async {
    envelopes.removeWhere((item) => item.id == envelope.id);
    envelopes.add(envelope);
  }
}

SemanticCluster _cluster({
  String id = 'shared-cluster',
  String title = 'Cluster title',
  String summary = '',
  List<String> nodeIds = const ['opaque-node-a', 'opaque-node-b'],
  bool pinned = false,
  bool userEdited = false,
}) => SemanticCluster(
  id: id,
  title: title,
  category: SemanticClusterCategory.theme,
  nodeIds: nodeIds,
  activityVelocity: 0.4,
  confidenceScore: 0.8,
  summary: summary,
  pinned: pinned,
  updatedAt: DateTime.utc(2026, 7, 27),
  userEdited: userEdited,
);
