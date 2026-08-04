import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph_store.dart';
import 'package:voicememory_mobile/features/cloud_relay_sync/cloud_relay_api_transport.dart';
import 'package:voicememory_mobile/features/cloud_relay_sync/cloud_relay_sync_engine.dart';
import 'package:voicememory_mobile/features/cloud_relay_sync/ui/cloud_sync_settings_sheet.dart';
import 'package:voicememory_mobile/features/sync/e2ee_sync_models.dart';
import 'package:voicememory_mobile/features/sync/encrypted_sync_engine.dart';
import 'package:voicememory_mobile/features/sync/sync_outbox.dart';
import 'package:voicememory_mobile/services/ai/local_semantic_store.dart';
import 'package:voicememory_mobile/services/security/sync_identity_service.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  testWidgets('shows offline queue and encrypted sync toggle state', (
    tester,
  ) async {
    final harness = await _uiHarness(online: false);
    addTearDown(harness.dispose);
    await harness.cloud.syncNow();

    await tester.pumpWidget(_host(harness));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Offline Queue'), findsOneWidget);
    expect(find.text('0 encrypted changes waiting'), findsOneWidget);
    final toggle = tester.widget<SwitchListTile>(
      find.byKey(const Key('cloud-sync-enabled-toggle')),
    );
    expect(toggle.value, isTrue);
  });

  testWidgets('connected telemetry exposes manual sync and device revoke', (
    tester,
  ) async {
    final harness = await _uiHarness(
      online: true,
      initialState: CloudRelayConnectionState.encryptedRelayConnected,
    );
    addTearDown(harness.dispose);
    await tester.pumpWidget(_host(harness));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Encrypted Relay Connected'), findsOneWidget);
    expect(find.byKey(const Key('cloud-sync-now')), findsOneWidget);
    expect(find.byKey(const Key('cloud-sync-device-device-b')), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('revoke-cloud-sync-device-device-b')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Revoke device-b?'), findsOneWidget);
    expect(
      find.byKey(const Key('confirm-cloud-device-revoke')),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Widget _host(_UiHarness harness) => MaterialApp(
  home: Scaffold(
    body: CloudSyncSettingsSheet(
      identity: harness.identity,
      engine: harness.cloud,
    ),
  ),
);

Future<_UiHarness> _uiHarness({
  required bool online,
  CloudRelayConnectionState initialState = CloudRelayConnectionState.disabled,
}) async {
  final root = Directory.systemTemp.createTempSync('cloud-relay-ui-');
  final keyStore = InMemoryPrivateDataEncryptionKeyStore();
  final identity = SyncIdentityService(store: MemorySyncIdentityStore());
  await identity.installRecoveryPhrase(
    'abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon about',
  );
  final outbox = SyncOutbox.open(databasePath: '${root.path}/outbox.db');
  final transport = _UiRelayTransport();
  final syncEngine = EncryptedSyncEngine(
    deviceId: 'device-a',
    identity: identity,
    outbox: outbox,
    transport: transport,
    graphStore: PersonalKnowledgeGraphStore(
      storage: EncryptedJsonFileStore(
        file: File('${root.path}/graph.enc'),
        keyStore: keyStore,
      ),
    ),
    semanticStore: LocalSemanticStore(
      storage: EncryptedJsonFileStore(
        file: File('${root.path}/semantic.enc'),
        keyStore: keyStore,
      ),
    ),
    isOnline: () => online,
  );
  final cloud = CloudRelaySyncEngine(
    syncEngine: syncEngine,
    outbox: outbox,
    transport: transport,
    isOnline: () => online,
    initialState: initialState,
  );
  return _UiHarness(root, identity, outbox, transport, syncEngine, cloud);
}

final class _UiRelayTransport
    implements E2EERelayTransport, CloudRelayDeviceDirectory {
  final StreamController<List<CloudRelayDevicePresence>> _changes =
      StreamController<List<CloudRelayDevicePresence>>.broadcast();

  @override
  List<CloudRelayDevicePresence> get relayDevices => [
    CloudRelayDevicePresence(
      id: 'device-a',
      lastActiveAt: DateTime.utc(2026, 7, 28),
    ),
    CloudRelayDevicePresence(
      id: 'device-b',
      lastActiveAt: DateTime.utc(2026, 7, 27),
    ),
  ];

  @override
  Stream<List<CloudRelayDevicePresence>> get relayDeviceChanges =>
      _changes.stream;

  @override
  Future<List<E2EESyncEnvelope>> pull() async => const [];

  @override
  Future<void> push(E2EESyncEnvelope envelope) async {}

  @override
  Future<void> revokeRelayDevice(String deviceId) async {}

  Future<void> dispose() => _changes.close();
}

final class _UiHarness {
  const _UiHarness(
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
  final _UiRelayTransport transport;
  final EncryptedSyncEngine syncEngine;
  final CloudRelaySyncEngine cloud;

  Future<void> dispose() async {
    cloud.dispose();
    await syncEngine.dispose();
    await transport.dispose();
    outbox.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}
