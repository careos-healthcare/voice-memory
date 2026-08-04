import 'dart:io';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph_store.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/features/p2p_mesh/sync/mesh_sync_checkpoint.dart';
import 'package:voicememory_mobile/features/p2p_mesh/sync/mesh_sync_reconciler.dart';
import 'package:voicememory_mobile/features/p2p_mesh/sync/mesh_sync_engine.dart';
import 'package:voicememory_mobile/features/p2p_mesh/sync/peer_sync_channel.dart';
import 'package:voicememory_mobile/features/sync/e2ee_sync_models.dart';
import 'package:voicememory_mobile/features/sync/encrypted_sync_engine.dart';
import 'package:voicememory_mobile/features/sync/sync_outbox.dart';
import 'package:voicememory_mobile/services/ai/local_semantic_store.dart';
import 'package:voicememory_mobile/services/security/sync_identity_service.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  test(
    'bounded chunks reconcile out of order and preserve cloud pending rows',
    () async {
      final root = await Directory.systemTemp.createTemp('mesh_sync_');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final sender = await _harness(root, 'sender');
      final receiver = await _harness(root, 'receiver');
      addTearDown(sender.dispose);
      addTearDown(receiver.dispose);

      await sender.engine.record(
        entityKind: CrdtEntityKind.node,
        entityId: 'a',
        mutation: CrdtMutation.upsert,
        payload: _node('a').toJson(),
      );
      await sender.engine.record(
        entityKind: CrdtEntityKind.node,
        entityId: 'b',
        mutation: CrdtMutation.upsert,
        payload: _node('b').toJson(),
      );
      expect(sender.outbox.pendingCount, 2);

      final senderCheckpoints = _MemoryCheckpoints();
      final receiverCheckpoints = _MemoryCheckpoints();
      var senderSync = MeshSyncReconciler(
        engine: sender.engine,
        checkpoints: senderCheckpoints,
        maxOperationsPerChunk: 1,
      );
      final receiverSync = MeshSyncReconciler(
        engine: receiver.engine,
        checkpoints: receiverCheckpoints,
      );
      final receiverSummary = await receiverSync.createHeadSummary();
      final first = await senderSync.exportNextChunk(
        peerId: 'receiver',
        exchangeId: 'exchange-1',
        sequence: 0,
        peerSummary: receiverSummary,
      );

      // Recreate the reconciler to prove the encrypted checkpoint abstraction
      // carries the differential cursor across a reconnect.
      senderSync = MeshSyncReconciler(
        engine: sender.engine,
        checkpoints: senderCheckpoints,
        maxOperationsPerChunk: 1,
      );
      final retriedFirst = await senderSync.exportNextChunk(
        peerId: 'receiver',
        exchangeId: 'exchange-1',
        sequence: 0,
        peerSummary: receiverSummary,
      );
      expect(retriedFirst, first);
      final second = await senderSync.exportNextChunk(
        peerId: 'receiver',
        exchangeId: 'exchange-1',
        sequence: 1,
        peerSummary: receiverSummary,
      );
      expect(first['isLast'], isFalse);
      expect(second['isLast'], isTrue);

      final secondResult = await receiverSync.applyAuthenticatedChunk(
        authenticatedPeerId: 'sender',
        chunk: second,
      );
      final firstResult = await receiverSync.applyAuthenticatedChunk(
        authenticatedPeerId: 'sender',
        chunk: first,
      );
      expect(secondResult.appliedWinnerCount, 1);
      expect(firstResult.appliedWinnerCount, 1);

      final duplicate = await receiverSync.applyAuthenticatedChunk(
        authenticatedPeerId: 'sender',
        chunk: first,
      );
      expect(duplicate.wasDuplicate, isTrue);
      await senderSync.applyAcknowledgement(
        authenticatedPeerId: 'receiver',
        acknowledgement: firstResult.acknowledgement,
      );

      final graph = await receiver.graphStore.load();
      expect(graph.nodes.map((node) => node.id), containsAll(['a', 'b']));
      expect(sender.outbox.pendingCount, 2);
    },
  );

  test('head summaries export only the missing LWW winner', () async {
    final root = await Directory.systemTemp.createTemp('mesh_diff_');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final sender = await _harness(root, 'sender');
    final receiver = await _harness(root, 'receiver');
    addTearDown(sender.dispose);
    addTearDown(receiver.dispose);

    await sender.engine.record(
      entityKind: CrdtEntityKind.node,
      entityId: 'shared',
      mutation: CrdtMutation.upsert,
      payload: _node('shared').toJson(),
    );
    final initial = await sender.engine.exportMissingWinners(
      await receiver.engine.summarizeHeads(),
    );
    await receiver.engine.applyAuthenticatedPeerEnvelopes(
      (initial['envelopes'] as List).cast<Map>().map(
        (item) => Map<String, dynamic>.from(item),
      ),
      authenticatedPeerId: 'sender',
    );
    await sender.engine.record(
      entityKind: CrdtEntityKind.node,
      entityId: 'sender-only',
      mutation: CrdtMutation.upsert,
      payload: _node('sender-only').toJson(),
    );

    final page = await sender.engine.exportMissingWinners(
      await receiver.engine.summarizeHeads(),
    );
    expect(page['envelopes'], hasLength(1));
  });

  test(
    'MeshSyncEngine converges both peers without consuming cloud rows',
    () async {
      final root = await Directory.systemTemp.createTemp('mesh_engine_');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final sender = await _harness(root, 'sender');
      final receiver = await _harness(root, 'receiver');
      addTearDown(sender.dispose);
      addTearDown(receiver.dispose);
      await sender.graphStore.save(
        PersonalKnowledgeGraph(nodes: [_node('sender-node')]),
      );
      await receiver.graphStore.save(
        PersonalKnowledgeGraph(nodes: [_node('receiver-node')]),
      );
      await sender.engine.record(
        entityKind: CrdtEntityKind.node,
        entityId: 'sender-node',
        mutation: CrdtMutation.upsert,
        payload: _node('sender-node').toJson(),
      );
      await receiver.engine.record(
        entityKind: CrdtEntityKind.node,
        entityId: 'receiver-node',
        mutation: CrdtMutation.upsert,
        payload: _node('receiver-node').toJson(),
      );
      final senderCheckpoints = _MemoryCheckpoints();
      final receiverCheckpoints = _MemoryCheckpoints();
      final senderMesh = MeshSyncEngine(
        reconciler: MeshSyncReconciler(
          engine: sender.engine,
          checkpoints: senderCheckpoints,
        ),
        checkpoints: senderCheckpoints,
      );
      final receiverMesh = MeshSyncEngine(
        reconciler: MeshSyncReconciler(
          engine: receiver.engine,
          checkpoints: receiverCheckpoints,
        ),
        checkpoints: receiverCheckpoints,
      );
      addTearDown(senderMesh.dispose);
      addTearDown(receiverMesh.dispose);
      final channels = _MemoryPeerChannel.pair(
        firstPeerId: 'receiver',
        secondPeerId: 'sender',
      );

      await Future.wait([
        senderMesh.synchronize(channels.$1, initiator: true),
        receiverMesh.synchronize(channels.$2, initiator: false),
      ]);

      expect(
        (await sender.graphStore.load()).nodes.map((node) => node.id),
        containsAll(['sender-node', 'receiver-node']),
      );
      expect(
        (await receiver.graphStore.load()).nodes.map((node) => node.id),
        containsAll(['sender-node', 'receiver-node']),
      );
      expect(sender.outbox.pendingCount, 1);
      expect(receiver.outbox.pendingCount, 1);
    },
  );
}

class _Harness {
  const _Harness(this.engine, this.graphStore, this.outbox);

  final EncryptedSyncEngine engine;
  final PersonalKnowledgeGraphStore graphStore;
  final SyncOutbox outbox;

  Future<void> dispose() async {
    await engine.dispose();
    await graphStore.dispose();
    outbox.close();
  }
}

Future<_Harness> _harness(Directory root, String deviceId) async {
  const phrase =
      'abandon abandon abandon abandon abandon abandon abandon abandon '
      'abandon abandon abandon about';
  final directory = Directory('${root.path}/$deviceId')..createSync();
  final identity = SyncIdentityService(store: MemorySyncIdentityStore());
  await identity.installRecoveryPhrase(phrase);
  final keyStore = InMemoryPrivateDataEncryptionKeyStore();
  final graphStore = PersonalKnowledgeGraphStore(
    storage: EncryptedJsonFileStore(
      file: File('${directory.path}/graph.enc'),
      keyStore: keyStore,
    ),
  );
  final semanticStore = LocalSemanticStore(
    storage: EncryptedJsonFileStore(
      file: File('${directory.path}/semantic.enc'),
      keyStore: keyStore,
    ),
  );
  final outbox = SyncOutbox.open(databasePath: '${directory.path}/outbox.db');
  final engine = EncryptedSyncEngine(
    deviceId: deviceId,
    identity: identity,
    outbox: outbox,
    transport: _UnusedRelay(),
    graphStore: graphStore,
    semanticStore: semanticStore,
    isOnline: () => false,
    clock: () => DateTime.utc(2026, 7, 27),
  );
  return _Harness(engine, graphStore, outbox);
}

class _UnusedRelay implements E2EERelayTransport {
  @override
  Future<List<E2EESyncEnvelope>> pull() async => const [];

  @override
  Future<void> push(E2EESyncEnvelope envelope) async {}
}

class _MemoryCheckpoints implements EncryptedMeshCheckpointStore {
  final _values = <String, Map<String, dynamic>>{};

  @override
  Future<MeshSyncCheckpoint?> load(String peerId) async {
    final value = _values[peerId];
    return value == null ? null : MeshSyncCheckpoint.fromJson(value);
  }

  @override
  Future<void> remove(String peerId) async {
    _values.remove(peerId);
  }

  @override
  Future<void> save(String peerId, MeshSyncCheckpoint checkpoint) async {
    _values[peerId] = checkpoint.toJson();
  }
}

class _MemoryPeerChannel implements AuthenticatedPeerSyncChannel {
  _MemoryPeerChannel(this.peerId);

  static (_MemoryPeerChannel, _MemoryPeerChannel) pair({
    required String firstPeerId,
    required String secondPeerId,
  }) {
    final first = _MemoryPeerChannel(firstPeerId);
    final second = _MemoryPeerChannel(secondPeerId);
    first._remote = second;
    second._remote = first;
    return (first, second);
  }

  @override
  final String peerId;
  final _packets = StreamController<Map<String, dynamic>>.broadcast();
  late final _MemoryPeerChannel _remote;

  @override
  Stream<Map<String, dynamic>> get packets => _packets.stream;

  @override
  Future<void> send(Map<String, dynamic> packet) async {
    _remote._packets.add(Map<String, dynamic>.from(packet));
  }
}

GraphNode _node(String id) => GraphNode(
  id: id,
  type: NodeType.person,
  label: id,
  confidence: .8,
  evidence: [
    GraphNodeEvidence(
      entryId: 'entry-$id',
      observedAt: DateTime.utc(2026),
      confidence: .8,
      excerpt: id,
      startUtf16: 0,
      endUtf16: id.length,
    ),
  ],
);
