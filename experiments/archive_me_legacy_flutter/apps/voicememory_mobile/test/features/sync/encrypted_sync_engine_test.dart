import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph_store.dart';
import 'package:voicememory_mobile/features/sync/e2ee_sync_models.dart';
import 'package:voicememory_mobile/features/sync/encrypted_sync_engine.dart';
import 'package:voicememory_mobile/features/sync/sync_outbox.dart';
import 'package:voicememory_mobile/services/ai/local_semantic_store.dart';
import 'package:voicememory_mobile/services/security/sync_identity_service.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  test('BIP39 phrase derives the same 256-bit key on another device', () async {
    final source = SyncIdentityService(store: MemorySyncIdentityStore());
    final phrase = await source.enable();
    expect(phrase.split(' '), hasLength(12));

    final destination = SyncIdentityService(store: MemorySyncIdentityStore());
    await destination.installRecoveryPhrase(phrase);
    final sourceKey = await source.requireKey();
    final destinationKey = await destination.requireKey();
    expect(sourceKey.bytes, destinationKey.bytes);
    sourceKey.destroy();
    destinationKey.destroy();
  });

  test(
    'pairing QR payload is encrypted and requires its separate code',
    () async {
      final source = SyncIdentityService(store: MemorySyncIdentityStore());
      final phrase = await source.enable();
      final payload = await source.createPairingPayload('314159');
      expect(payload, isNot(contains(phrase)));

      final destination = SyncIdentityService(store: MemorySyncIdentityStore());
      await expectLater(
        destination.acceptPairingPayload(payload, pairingCode: '000000'),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      await destination.acceptPairingPayload(payload, pairingCode: '314159');
      expect(await destination.recoveryPhrase(), phrase);
    },
  );

  test(
    'encrypted CRDT blob cannot be parsed or decrypted without key',
    () async {
      final operation = _operation('device-a', 'Private relationship note');
      final key = SyncEncryptionKey(List<int>.generate(32, (index) => index));
      final envelope = await const E2EESyncCipher().encrypt(
        id: 'batch-a',
        deviceId: 'device-a',
        vectorClock: operation.vectorClock,
        operations: [operation],
        key: key,
        keyEpoch: 1,
      );
      expect(
        envelope.encryptedBlob,
        isNot(contains('Private relationship note')),
      );
      expect(
        () => E2EESyncEnvelope.fromRelayBlob(envelope.toRelayBlob()),
        returnsNormally,
      );
      final wrongKey = SyncEncryptionKey(List<int>.filled(32, 7));
      await expectLater(
        const E2EESyncCipher().decrypt(envelope, key: wrongKey),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      key.destroy();
      wrongKey.destroy();
    },
  );

  test('concurrent offline node writes resolve deterministically', () async {
    final root = await Directory.systemTemp.createTemp('e2ee_crdt_');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    const phrase =
        'abandon abandon abandon abandon abandon abandon abandon abandon '
        'abandon abandon abandon about';
    final relay = _MemoryRelay();
    final a = await _harness(root, 'device-a', phrase, relay);
    final b = await _harness(root, 'device-b', phrase, relay);
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    final nodeA = _node('Shared node', 'Alpha from A');
    final nodeB = _node('Shared node', 'Beta from B');
    await a.graphStore.save(PersonalKnowledgeGraph(nodes: [nodeA]));
    await b.graphStore.save(PersonalKnowledgeGraph(nodes: [nodeB]));
    await a.engine.record(
      entityKind: CrdtEntityKind.node,
      entityId: nodeA.id,
      mutation: CrdtMutation.upsert,
      payload: nodeA.toJson(),
    );
    await b.engine.record(
      entityKind: CrdtEntityKind.node,
      entityId: nodeB.id,
      mutation: CrdtMutation.upsert,
      payload: nodeB.toJson(),
    );

    await a.engine.syncNow();
    await b.engine.syncNow();
    await a.engine.syncNow();

    expect((await a.graphStore.load()).nodes.single.label, 'Beta from B');
    expect((await b.graphStore.load()).nodes.single.label, 'Beta from B');
    expect(a.engine.state, EncryptedSyncState.upToDate);

    final rotatedPhrase = await a.engine.revokeDevice('device-b');
    expect(rotatedPhrase, isNot(phrase));
    expect(await a.engine.identity.keyEpoch, 2);
    expect(a.outbox.pendingCount, greaterThan(0));
  });

  test(
    'offline mutations remain encrypted in outbox until reconnect',
    () async {
      final root = await Directory.systemTemp.createTemp('e2ee_offline_');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      const phrase =
          'abandon abandon abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon about';
      var online = false;
      final relay = _MemoryRelay();
      final harness = await _harness(
        root,
        'offline-device',
        phrase,
        relay,
        isOnline: () => online,
      );
      addTearDown(harness.dispose);
      final node = _node('offline', 'Queued privately');
      await harness.engine.record(
        entityKind: CrdtEntityKind.node,
        entityId: node.id,
        mutation: CrdtMutation.upsert,
        payload: node.toJson(),
      );

      await harness.engine.syncNow();
      expect(harness.engine.state, EncryptedSyncState.offline);
      expect(harness.outbox.pendingCount, 1);
      expect(
        latin1.decode(File(harness.outbox.databasePath).readAsBytesSync()),
        isNot(contains('Queued privately')),
      );

      online = true;
      await harness.engine.syncNow();
      expect(harness.outbox.pendingCount, 0);
      expect(relay.envelopes, hasLength(1));
    },
  );

  test(
    'dispatches transcript and media operations through auxiliary handler',
    () async {
      final root = await Directory.systemTemp.createTemp('e2ee_auxiliary_');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      const phrase =
          'abandon abandon abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon about';
      final relay = _MemoryRelay();
      final received = <CrdtEntityKind>[];
      final sender = await _harness(root, 'sender', phrase, relay);
      final receiver = await _harness(
        root,
        'receiver',
        phrase,
        relay,
        applyAuxiliaryOperation: (operation) async {
          received.add(operation.entityKind);
        },
      );
      addTearDown(sender.dispose);
      addTearDown(receiver.dispose);

      for (final kind in [
        CrdtEntityKind.transcript,
        CrdtEntityKind.mediaManifest,
        CrdtEntityKind.mediaChunk,
      ]) {
        await sender.engine.record(
          entityKind: kind,
          entityId: '${kind.name}-1',
          mutation: CrdtMutation.upsert,
          payload: const {},
        );
      }
      await sender.engine.syncNow();
      await receiver.engine.syncNow();

      expect(
        received,
        containsAll([
          CrdtEntityKind.transcript,
          CrdtEntityKind.mediaManifest,
          CrdtEntityKind.mediaChunk,
        ]),
      );
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

Future<_Harness> _harness(
  Directory root,
  String deviceId,
  String phrase,
  _MemoryRelay relay, {
  FutureOr<bool> Function()? isOnline,
  Future<void> Function(CrdtOperation operation)? applyAuxiliaryOperation,
}) async {
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
  final semantic = LocalSemanticStore(
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
    transport: relay,
    graphStore: graphStore,
    semanticStore: semantic,
    isOnline: isOnline ?? () => true,
    clock: () => DateTime.utc(2026, 7, 27),
    applyAuxiliaryOperation: applyAuxiliaryOperation,
  );
  return _Harness(engine, graphStore, outbox);
}

class _MemoryRelay implements E2EERelayTransport {
  final List<E2EESyncEnvelope> envelopes = [];

  @override
  Future<List<E2EESyncEnvelope>> pull() async => List.of(envelopes);

  @override
  Future<void> push(E2EESyncEnvelope envelope) async {
    envelopes.removeWhere((item) => item.id == envelope.id);
    envelopes.add(envelope);
  }
}

CrdtOperation _operation(String device, String label) => CrdtOperation(
  id: '$device-1',
  deviceId: device,
  entityKind: CrdtEntityKind.node,
  entityId: 'shared',
  mutation: CrdtMutation.upsert,
  vectorClock: {device: 1},
  timestamp: DateTime.utc(2026),
  payload: {'label': label},
);

GraphNode _node(String seed, String label) => GraphNode(
  id: 'shared-node',
  type: NodeType.person,
  label: label,
  confidence: .8,
  evidence: [
    GraphNodeEvidence(
      entryId: 'entry-$seed',
      observedAt: DateTime.utc(2026),
      confidence: .8,
      excerpt: seed,
      startUtf16: 0,
      endUtf16: seed.length,
    ),
  ],
);
