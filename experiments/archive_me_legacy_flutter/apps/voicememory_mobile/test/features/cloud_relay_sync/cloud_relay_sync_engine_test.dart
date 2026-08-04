import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph_store.dart';
import 'package:voicememory_mobile/features/cloud_relay_sync/cloud_relay_api_transport.dart';
import 'package:voicememory_mobile/features/cloud_relay_sync/cloud_relay_sync_engine.dart';
import 'package:voicememory_mobile/features/sync/e2ee_sync_models.dart';
import 'package:voicememory_mobile/features/sync/encrypted_sync_engine.dart';
import 'package:voicememory_mobile/features/sync/sync_outbox.dart';
import 'package:voicememory_mobile/services/ai/local_semantic_store.dart';
import 'package:voicememory_mobile/services/security/sync_identity_service.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  test(
    'keeps encrypted SQLite outbox queued through network dropout',
    () async {
      final harness = await _harness(online: false);
      addTearDown(harness.dispose);
      await harness.syncEngine.record(
        entityKind: CrdtEntityKind.confidence,
        entityId: 'node-a',
        mutation: CrdtMutation.upsert,
        payload: const {'confidence': .8},
      );

      await harness.cloud.syncNow();

      expect(harness.cloud.state, CloudRelayConnectionState.offlineQueue);
      expect(harness.outbox.pendingCount, 1);
      expect(harness.transport.pushed, isEmpty);
      expect(
        latin1.decode(File(harness.outbox.databasePath).readAsBytesSync()),
        isNot(contains('"confidence":0.8')),
      );
    },
  );

  test(
    'retries with exponential jitter and drains encrypted batches',
    () async {
      final delays = <Duration>[];
      final harness = await _harness(
        online: true,
        failuresBeforeSuccess: 2,
        delay: (duration) async => delays.add(duration),
      );
      addTearDown(harness.dispose);
      await harness.syncEngine.record(
        entityKind: CrdtEntityKind.confidence,
        entityId: 'node-a',
        mutation: CrdtMutation.upsert,
        payload: const {'confidence': .8},
      );

      await harness.cloud.syncNow();

      expect(
        harness.cloud.state,
        CloudRelayConnectionState.encryptedRelayConnected,
      );
      expect(harness.outbox.pendingCount, 0);
      expect(delays, hasLength(2));
      expect(delays[1], greaterThan(delays[0]));
      expect(harness.transport.pushed, hasLength(1));
    },
  );

  test('chunks outbox and decrypts every delivered CRDT operation', () async {
    final harness = await _harness(online: true);
    addTearDown(harness.dispose);
    final enqueueKey = await harness.identity.requireKey();
    try {
      for (var index = 0; index < 35; index++) {
        await harness.outbox.enqueue(
          CrdtOperation(
            id: 'device-a-${index + 1}',
            deviceId: 'device-a',
            entityKind: CrdtEntityKind.confidence,
            entityId: 'node-$index',
            mutation: CrdtMutation.upsert,
            vectorClock: {'device-a': index + 1},
            timestamp: DateTime.utc(2026, 7, 28, 0, 0, index),
            payload: {'confidence': index / 100},
          ),
          key: enqueueKey,
          keyEpoch: 1,
        );
      }
    } finally {
      enqueueKey.destroy();
    }

    await harness.cloud.syncNow();

    expect(harness.transport.pushed, hasLength(2));
    final key = await harness.identity.requireKey();
    final operations = <CrdtOperation>[];
    try {
      for (final envelope in harness.transport.pushed) {
        operations.addAll(
          await const E2EESyncCipher().decrypt(envelope, key: key),
        );
      }
    } finally {
      key.destroy();
    }
    expect(operations, hasLength(35));
    expect(operations.map((item) => item.entityId).toSet(), hasLength(35));
  });
}

Future<_Harness> _harness({
  required bool online,
  int failuresBeforeSuccess = 0,
  CloudRelayDelay? delay,
}) async {
  final root = await Directory.systemTemp.createTemp('cloud-relay-sync-');
  final keyStore = InMemoryPrivateDataEncryptionKeyStore();
  final identity = SyncIdentityService(store: MemorySyncIdentityStore());
  await identity.installRecoveryPhrase(
    'abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon about',
  );
  final outbox = SyncOutbox.open(databasePath: '${root.path}/outbox.db');
  final transport = _RelayTransport(failuresBeforeSuccess);
  final graphStore = PersonalKnowledgeGraphStore(
    storage: EncryptedJsonFileStore(
      file: File('${root.path}/graph.enc'),
      keyStore: keyStore,
    ),
  );
  final syncEngine = EncryptedSyncEngine(
    deviceId: 'device-a',
    identity: identity,
    outbox: outbox,
    transport: transport,
    graphStore: graphStore,
    semanticStore: LocalSemanticStore(
      storage: EncryptedJsonFileStore(
        file: File('${root.path}/semantic.enc'),
        keyStore: keyStore,
      ),
    ),
    isOnline: () => online,
    clock: () => DateTime.utc(2026, 7, 28),
  );
  final cloud = CloudRelaySyncEngine(
    syncEngine: syncEngine,
    outbox: outbox,
    transport: transport,
    isOnline: () => online,
    delay: delay,
    random: Random(4),
    baseBackoff: const Duration(milliseconds: 100),
  );
  return _Harness(root, identity, outbox, transport, syncEngine, cloud);
}

final class _RelayTransport
    implements E2EERelayTransport, CloudRelayDeviceDirectory {
  _RelayTransport(this.failuresRemaining);

  int failuresRemaining;
  final List<E2EESyncEnvelope> pushed = [];
  final StreamController<List<CloudRelayDevicePresence>> _devices =
      StreamController<List<CloudRelayDevicePresence>>.broadcast();

  @override
  List<CloudRelayDevicePresence> get relayDevices => const [];

  @override
  Stream<List<CloudRelayDevicePresence>> get relayDeviceChanges =>
      _devices.stream;

  @override
  Future<List<E2EESyncEnvelope>> pull() async => const [];

  @override
  Future<void> push(E2EESyncEnvelope envelope) async {
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw const CloudRelayTransportException(
        'temporary network failure',
        retryable: true,
        statusCode: 503,
      );
    }
    pushed.add(envelope);
  }

  @override
  Future<void> revokeRelayDevice(String deviceId) async {}

  Future<void> dispose() => _devices.close();
}

final class _Harness {
  const _Harness(
    this.root,
    this.identity,
    this.outbox,
    this.transport,
    this.syncEngine,
    this.cloud,
  );

  final Directory root;
  final SyncIdentityService identity;
  final SyncOutbox outbox;
  final _RelayTransport transport;
  final EncryptedSyncEngine syncEngine;
  final CloudRelaySyncEngine cloud;

  Future<void> dispose() async {
    cloud.dispose();
    await syncEngine.dispose();
    await transport.dispose();
    outbox.close();
    if (await root.exists()) await root.delete(recursive: true);
  }
}
