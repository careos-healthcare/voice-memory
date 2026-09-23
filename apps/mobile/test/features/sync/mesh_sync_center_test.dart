import 'package:archiveme_mobile/features/sync/mesh_conflict_resolver.dart';
import 'package:archiveme_mobile/features/sync/mesh_key_verifier.dart';
import 'package:archiveme_mobile/features/sync/mesh_sync_manager.dart';
import 'package:archiveme_mobile/features/sync/mesh_sync_state.dart';
import 'package:archiveme_mobile/features/sync/sync_status_center_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const localKey = <int>[
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
    17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32,
  ];

  test('AES-GCM 256 handshake opens with the same key and fails with another', () async {
    final check = await MeshKeyVerifier.verifyLocal(localKey);
    expect(check.valid, isTrue);
    expect(check.fingerprint, hasLength(8));

    final handshake = await MeshKeyVerifier.seal(localKey);
    expect(await MeshKeyVerifier.open(key: localKey, handshake: handshake), isTrue);

    final other = List<int>.from(localKey)..[0] = 9;
    expect(await MeshKeyVerifier.open(key: other, handshake: handshake), isFalse);
  });

  test('last write wins on the moment time and keeps local graph edits', () {
    final local = MeshEntryVersion(
      entryId: 'moment-1',
      updatedAt: DateTime.utc(2026, 9, 23, 10),
      vectorGeneration: 2,
      entityEdgeIds: const ['people:ada', 'locations:harbor'],
    );
    final remote = MeshEntryVersion(
      entryId: 'moment-1',
      updatedAt: DateTime.utc(2026, 9, 23, 12),
      vectorGeneration: 5,
      entityEdgeIds: const ['people:sam'],
    );

    final resolved = MeshConflictResolver.resolve(local: local, remote: remote);
    expect(resolved.vectorGeneration, 5);
    expect(resolved.updatedAt, remote.updatedAt);
    expect(resolved.entityEdgeIds, local.entityEdgeIds);

    final olderRemote = remote.copyWith(
      updatedAt: DateTime.utc(2026, 9, 23, 9),
    );
    expect(
      MeshConflictResolver.resolve(local: local, remote: olderRemote).vectorGeneration,
      2,
    );
  });

  test('scan stays empty while mesh discovery is off', () async {
    final container = ProviderContainer(
      overrides: [
        meshSyncManagerProvider.overrideWith(
          () => MeshSyncManager(
            meshEnabled: false,
            keyStore: MemoryMeshKeyStore(localKey),
            discoverPeers: () async => [
              const MeshPeer(
                id: 'phone',
                name: 'Kitchen phone',
                ping: Duration(milliseconds: 40),
                sync: MeshPeerSync.inSync,
              ),
            ],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(meshSyncManagerProvider, (_, _) {});
    await container.read(meshSyncManagerProvider.future);

    await container.read(meshSyncManagerProvider.notifier).scan();
    container.read(meshSyncManagerProvider.notifier).setVectorQueue(
      pending: 3,
      completed: 1,
    );
    final state = container.read(meshSyncManagerProvider).requireValue;
    expect(state.peers, isEmpty);
    expect(state.meshEnabled, isFalse);
    expect(state.keyValid, isTrue);
    expect(state.pendingVectors, 3);
  });

  testWidgets('status center shows peers, the queue, and key actions', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        meshSyncManagerProvider.overrideWith(
          () => MeshSyncManager(
            meshEnabled: true,
            keyStore: MemoryMeshKeyStore(localKey),
            discoverPeers: () async => [
              const MeshPeer(
                id: 'phone',
                name: 'Kitchen phone',
                ping: Duration(milliseconds: 42),
                sync: MeshPeerSync.catchingUp,
                bytesPerSecondIn: 120,
                bytesPerSecondOut: 80,
              ),
            ],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SyncStatusCenterScreen()),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    expect(find.textContaining('Keys match'), findsOneWidget);
    expect(find.text('Rotate Master Keys'), findsOneWidget);
    expect(find.text('Trigger Mesh Scan'), findsOneWidget);

    container.read(meshSyncManagerProvider.notifier).setVectorQueue(
      pending: 3,
      completed: 1,
    );
    await tester.pump();
    expect(
      container.read(meshSyncManagerProvider).requireValue.pendingVectors,
      3,
    );
    expect(find.text('3 embeddings waiting'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mesh_trigger_scan')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    expect(find.text('Kitchen phone'), findsOneWidget);
    expect(find.textContaining('42 ms'), findsOneWidget);
    expect(find.textContaining('Catching up'), findsOneWidget);
    expect(find.textContaining('In 120 B/s'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mesh_log_toggle')));
    await tester.pump();
    expect(find.text('Mesh log on.'), findsOneWidget);
  });
}
