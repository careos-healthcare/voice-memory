import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph_store.dart';
import 'package:voicememory_mobile/features/action_plans/action_plan_models.dart';
import 'package:voicememory_mobile/features/action_plans/action_plan_store.dart';
import 'package:voicememory_mobile/features/action_plans/action_plan_sync_coordinator.dart';
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

  test('offline recording queues encrypted completion history', () async {
    final root = await Directory.systemTemp.createTemp('action_plan_offline_');
    final harness = await _harness(root, 'offline', phrase, _Relay(), false);
    addTearDown(() => harness.dispose(root));
    await harness.store.upsert(_plan(7));

    await harness.coordinator.recordCurrent(harness.engine);
    await harness.engine.syncNow();

    expect(harness.engine.state, EncryptedSyncState.offline);
    expect(harness.outbox.pendingCount, 1);
    final disk = latin1.decode(
      File(harness.outbox.databasePath).readAsBytesSync(),
    );
    expect(disk, isNot(contains('2026-07-07')));
    final key = await harness.engine.identity.requireKey();
    try {
      final operation = (await harness.outbox.pending(key: key)).single;
      expect(operation.entityKind, CrdtEntityKind.actionPlan);
      expect(
        operation.payload['steps'][0]['completionHistory']['2026-07-07'],
        isTrue,
      );
    } finally {
      key.destroy();
    }
  });

  test(
    'remote action plan upsert and delete merge into encrypted store',
    () async {
      final root = await Directory.systemTemp.createTemp('action_plan_remote_');
      final relay = _Relay();
      final sender = await _harness(root, 'sender', phrase, relay, true);
      final receiver = await _harness(root, 'receiver', phrase, relay, true);
      addTearDown(() async {
        await sender.dispose();
        await receiver.dispose(root);
      });
      await sender.store.upsert(_plan(14));
      await sender.coordinator.recordCurrent(sender.engine);
      await sender.engine.syncNow();
      await receiver.engine.syncNow();

      final received = (await receiver.store.list()).single;
      expect(received.steps.single.streakCount, 14);
      expect(received.steps.single.completionHistory, hasLength(14));

      await sender.store.remove('plan');
      await sender.coordinator.recordCurrent(sender.engine);
      await sender.engine.syncNow();
      await receiver.engine.syncNow();
      expect(await receiver.store.list(), isEmpty);
    },
  );

  test('restored outbox rehydrates vector clock without ID reuse', () async {
    final root = await Directory.systemTemp.createTemp('restored_clock_');
    final relay = _Relay();
    final first = await _harness(root, 'same-device', phrase, relay, false);
    final firstOperation = await first.engine.record(
      entityKind: CrdtEntityKind.confidence,
      entityId: 'node',
      mutation: CrdtMutation.upsert,
      payload: const {'confidence': 0.5},
    );
    expect(firstOperation.id, 'same-device-1');
    await first.dispose();

    final restored = await _harness(root, 'same-device', phrase, relay, false);
    addTearDown(() => restored.dispose(root));
    await restored.engine.reinitializeVectorClockFromOutbox();
    final nextOperation = await restored.engine.record(
      entityKind: CrdtEntityKind.confidence,
      entityId: 'node',
      mutation: CrdtMutation.upsert,
      payload: const {'confidence': 0.6},
    );
    expect(nextOperation.id, 'same-device-2');
  });
}

final class _Harness {
  const _Harness({
    required this.engine,
    required this.outbox,
    required this.graphStore,
    required this.store,
    required this.coordinator,
  });

  final EncryptedSyncEngine engine;
  final SyncOutbox outbox;
  final PersonalKnowledgeGraphStore graphStore;
  final ActionPlanStore store;
  final ActionPlanSyncCoordinator coordinator;

  Future<void> dispose([Directory? root]) async {
    await engine.dispose();
    await graphStore.dispose();
    store.dispose();
    outbox.close();
    if (root != null && await root.exists()) {
      await root.delete(recursive: true);
    }
  }
}

Future<_Harness> _harness(
  Directory root,
  String deviceId,
  String phrase,
  _Relay relay,
  bool online,
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
  final store = ActionPlanStore(storage: storage('plans'));
  final coordinator = ActionPlanSyncCoordinator(store: store);
  final outbox = SyncOutbox.open(databasePath: '${directory.path}/outbox.db');
  final engine = EncryptedSyncEngine(
    deviceId: deviceId,
    identity: identity,
    outbox: outbox,
    transport: relay,
    graphStore: graphStore,
    semanticStore: LocalSemanticStore(storage: storage('semantic')),
    isOnline: () => online,
    clock: () => DateTime.utc(2026, 7, 27),
    applyAuxiliaryOperation: coordinator.handler(),
  );
  return _Harness(
    engine: engine,
    outbox: outbox,
    graphStore: graphStore,
    store: store,
    coordinator: coordinator,
  );
}

final class _Relay implements E2EERelayTransport {
  final List<E2EESyncEnvelope> envelopes = [];

  @override
  Future<List<E2EESyncEnvelope>> pull() async => List.of(envelopes);

  @override
  Future<void> push(E2EESyncEnvelope envelope) async {
    envelopes.removeWhere((item) => item.id == envelope.id);
    envelopes.add(envelope);
  }
}

ActionPlan _plan(int streak) {
  final history = {
    for (var day = 1; day <= streak; day++)
      '2026-07-${day.toString().padLeft(2, '0')}': true,
  };
  return ActionPlan(
    id: 'plan',
    simulationId: 'simulation',
    title: 'Synced plan',
    targetOutcome: 'Synced outcome',
    createdAt: DateTime.utc(2026, 7, 1),
    steps: [
      MicroHabitStep(
        id: 'step',
        planId: 'plan',
        title: 'Synced step',
        frequency: ActionPlanFrequency.daily(),
        targetNodeId: 'opaque-node',
        streakCount: streak,
        completionHistory: history,
      ),
    ],
  );
}
