import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/live_audio/application/vault_sync_manager.dart';
import 'package:voicememory_mobile/features/live_audio/domain/retry_policy.dart';
import 'package:voicememory_mobile/features/live_audio/domain/vault_chunk_payload.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/emergency_vault_storage.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/vault_upload_api_client.dart';

void main() {
  group('VaultSyncManager', () {
    late Directory tempDir;
    late EmergencyVaultStorage storage;
    late _RecordingUploadClient uploadClient;
    late VaultSyncManager manager;
    late List<SyncState> states;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('vault_sync_manager_');
      storage = EmergencyVaultStorage(
        manifestFile: File('${tempDir.path}/queue.json'),
        resolveChunkDirectory: () async => Directory('${tempDir.path}/chunks'),
      );
      uploadClient = _RecordingUploadClient();
      manager = VaultSyncManager(
        vaultStorage: storage,
        apiClient: uploadClient,
        enableConnectivityListener: false,
        retryPolicy: RetryPolicy(
          maxAttempts: 2,
          initialDelay: Duration.zero,
          maxDelay: Duration.zero,
        ),
      );
      states = <SyncState>[];
      manager.syncStateStream.listen(states.add);
    });

    tearDown(() async {
      await manager.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'processPendingVaultQueue uploads chunks and returns to idle',
      () async {
        await storage.enqueueChunk(sessionId: 'session_1', bytes: [1, 2, 3]);
        await storage.enqueueChunk(sessionId: 'session_1', bytes: [4, 5, 6]);

        await manager.processPendingVaultQueue();

        expect(uploadClient.uploads, hasLength(2));
        expect(await storage.getUnsyncedChunks(), isEmpty);
        expect(manager.currentState, SyncState.idle);
        expect(states, contains(SyncState.syncing));
        expect(states.last, SyncState.idle);
      },
    );

    test(
      'processPendingVaultQueue stops on upload failure and enters error',
      () async {
        uploadClient.alwaysFail = true;
        await storage.enqueueChunk(sessionId: 'session_1', bytes: [9, 9, 9]);

        await manager.processPendingVaultQueue();

        expect(uploadClient.uploads, hasLength(2));
        expect(await storage.getUnsyncedChunks(), hasLength(1));
        expect(manager.currentState, SyncState.error);
      },
    );

    test('processPendingVaultQueue is single-flight', () async {
      final gate = Completer<void>();
      final entered = Completer<void>();
      uploadClient.gate = gate;
      uploadClient.entered = entered;
      await storage.enqueueChunk(sessionId: 'session_1', bytes: [7]);

      final first = manager.processPendingVaultQueue();
      await entered.future;
      final second = manager.processPendingVaultQueue();
      gate.complete();
      await Future.wait([first, second]);

      expect(uploadClient.uploads, hasLength(1));
    });

    test(
      'slow upload drop remains durable and Wi-Fi reconnect drains',
      () async {
        await manager.dispose();
        final connectivity =
            StreamController<List<ConnectivityResult>>.broadcast(sync: true);
        addTearDown(connectivity.close);
        final gate = Completer<void>();
        final entered = Completer<void>();
        uploadClient
          ..gate = gate
          ..entered = entered
          ..failNext = true;
        manager = VaultSyncManager(
          vaultStorage: storage,
          apiClient: uploadClient,
          connectivityChanges: connectivity.stream,
          retryPolicy: const RetryPolicy(maxAttempts: 1),
          retryDelay: (_) async {},
        );
        await storage.enqueueChunk(
          sessionId: 'offline-session',
          bytes: [8, 8],
          idempotencyKey: 'stable-vault-key',
        );

        connectivity.add(const <ConnectivityResult>[ConnectivityResult.none]);
        expect(manager.currentState, SyncState.offline);
        connectivity.add(const <ConnectivityResult>[ConnectivityResult.wifi]);
        await entered.future;
        connectivity.add(const <ConnectivityResult>[ConnectivityResult.none]);
        gate.complete();
        for (var index = 0; index < 40; index++) {
          if (manager.currentState == SyncState.error) break;
          await pumpEventQueue();
        }
        expect(manager.currentState, SyncState.error);
        expect(await storage.getUnsyncedChunks(), hasLength(1));

        uploadClient
          ..gate = null
          ..entered = null;
        connectivity.add(const <ConnectivityResult>[ConnectivityResult.none]);
        connectivity.add(const <ConnectivityResult>[ConnectivityResult.wifi]);
        for (var index = 0; index < 40; index++) {
          if ((await storage.getUnsyncedChunks()).isEmpty) break;
          await pumpEventQueue();
        }
        expect(await storage.getUnsyncedChunks(), isEmpty);
        expect(uploadClient.uploads.map((chunk) => chunk.idempotencyKey), [
          'stable-vault-key',
          'stable-vault-key',
        ]);
      },
    );

    test(
      'throttled multi-chunk drain includes chunks appended in flight',
      () async {
        final firstGate = Completer<void>();
        final firstEntered = Completer<void>();
        uploadClient
          ..gate = firstGate
          ..entered = firstEntered;
        final initial = await storage.enqueueChunk(
          sessionId: 'latency',
          bytes: [1, 1],
        );

        final drain = manager.processPendingVaultQueue();
        await firstEntered.future;
        final appended = await Future.wait([
          storage.enqueueChunk(sessionId: 'latency', bytes: [2, 2]),
          storage.enqueueChunk(sessionId: 'latency', bytes: [3, 3]),
        ]);
        uploadClient
          ..gate = null
          ..entered = null;
        firstGate.complete();
        await drain;

        expect(uploadClient.uploads.map((chunk) => chunk.id), [
          initial.id,
          ...appended.map((chunk) => chunk.id),
        ]);
        expect(uploadClient.uploads.map((chunk) => chunk.bytes), [
          [1, 1],
          [2, 2],
          [3, 3],
        ]);
        expect(await storage.getUnsyncedChunks(), isEmpty);
      },
    );

    test(
      'timeout after server accept retries immutable key and accepts duplicate ACK',
      () async {
        uploadClient.scriptedResults.addAll([
          TimeoutException('ACK packet dropped'),
          true,
        ]);
        final chunk = await storage.enqueueChunk(
          sessionId: 'packet-drop',
          bytes: [4, 5, 6],
          idempotencyKey: 'same-key-across-timeout',
        );

        await manager.processPendingVaultQueue();

        expect(uploadClient.uploads.map((item) => item.id), [
          chunk.id,
          chunk.id,
        ]);
        expect(uploadClient.uploads.map((item) => item.idempotencyKey), [
          'same-key-across-timeout',
          'same-key-across-timeout',
        ]);
        expect(await storage.getUnsyncedChunks(), isEmpty);
      },
    );

    test(
      'ACK-before-mark crash restart reuses the same idempotency key',
      () async {
        await manager.dispose();
        uploadClient.scriptedResults.add(
          TimeoutException('client died before ACK'),
        );
        manager = VaultSyncManager(
          vaultStorage: storage,
          apiClient: uploadClient,
          enableConnectivityListener: false,
          retryPolicy: const RetryPolicy(maxAttempts: 1),
        );
        await storage.enqueueChunk(
          sessionId: 'restart',
          bytes: [12, 13],
          idempotencyKey: 'restart-stable-key',
        );
        await manager.processPendingVaultQueue();
        expect(manager.currentState, SyncState.error);
        await manager.dispose();

        storage = EmergencyVaultStorage(
          manifestFile: File('${tempDir.path}/queue.json'),
          resolveChunkDirectory: () async =>
              Directory('${tempDir.path}/chunks'),
        );
        manager = VaultSyncManager(
          vaultStorage: storage,
          apiClient: uploadClient,
          enableConnectivityListener: false,
          retryPolicy: const RetryPolicy(maxAttempts: 1),
        );
        await manager.processPendingVaultQueue();

        expect(uploadClient.uploads.map((chunk) => chunk.idempotencyKey), [
          'restart-stable-key',
          'restart-stable-key',
        ]);
        expect(await storage.getUnsyncedChunks(), isEmpty);
      },
    );

    test('head-of-line failure leaves failed and tail bytes exact', () async {
      uploadClient.alwaysFail = true;
      final first = await storage.enqueueChunk(
        sessionId: 'hol',
        bytes: [0, 1, 2, 255],
      );
      final tail = await storage.enqueueChunk(
        sessionId: 'hol',
        bytes: [255, 2, 1, 0],
      );

      await manager.processPendingVaultQueue();

      expect(uploadClient.uploads.map((chunk) => chunk.id), [
        first.id,
        first.id,
      ]);
      final retained = await storage.getUnsyncedChunks();
      expect(retained.map((chunk) => chunk.id), [first.id, tail.id]);
      expect(retained.map((chunk) => chunk.bytes), [
        [0, 1, 2, 255],
        [255, 2, 1, 0],
      ]);
    });

    test(
      'carrier flap duplicate reconnect storm stays single-flight from error',
      () async {
        await manager.dispose();
        final connectivity =
            StreamController<List<ConnectivityResult>>.broadcast(sync: true);
        addTearDown(connectivity.close);
        final gate = Completer<void>();
        final entered = Completer<void>();
        uploadClient.alwaysFail = true;
        manager = VaultSyncManager(
          vaultStorage: storage,
          apiClient: uploadClient,
          connectivityChanges: connectivity.stream,
          retryPolicy: const RetryPolicy(maxAttempts: 1),
          retryDelay: (_) async {},
        );
        await storage.enqueueChunk(sessionId: 'flaps', bytes: [7, 8, 9]);

        await manager.processPendingVaultQueue();
        expect(manager.currentState, SyncState.error);
        uploadClient
          ..alwaysFail = false
          ..gate = gate
          ..entered = entered;
        connectivity.add(const [ConnectivityResult.wifi]);
        connectivity.add(const [ConnectivityResult.mobile]);
        connectivity.add(const [ConnectivityResult.wifi]);
        await entered.future;
        gate.complete();
        await manager.processPendingVaultQueue();

        expect(await storage.getUnsyncedChunks(), isEmpty);
        expect(uploadClient.uploads, hasLength(2));
        expect(manager.currentState, SyncState.idle);
      },
    );

    test('concurrent drain calls acknowledge each key exactly once', () async {
      final chunks = await Future.wait(
        List.generate(
          12,
          (index) => storage.enqueueChunk(
            sessionId: 'single-flight',
            bytes: [index],
            idempotencyKey: 'once-$index',
          ),
        ),
      );

      await Future.wait(
        List<Future<void>>.generate(
          20,
          (_) => manager.processPendingVaultQueue(),
        ),
      );

      final counts = <String, int>{};
      for (final upload in uploadClient.uploads) {
        counts.update(
          upload.idempotencyKey,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
      expect(counts.keys, chunks.map((chunk) => chunk.idempotencyKey).toSet());
      expect(counts.values.every((count) => count == 1), isTrue);
    });

    test(
      'integrity failure invokes recovery backstop and retains record',
      () async {
        await manager.dispose();
        var backstopCalls = 0;
        manager = VaultSyncManager(
          vaultStorage: storage,
          apiClient: uploadClient,
          enableConnectivityListener: false,
          integrityRecoveryBackstop: () async {
            backstopCalls++;
          },
        );
        final chunk = await storage.enqueueChunk(
          sessionId: 'missing',
          bytes: [99],
        );
        await File('${tempDir.path}/chunks/${chunk.id}.bin').delete();

        await manager.processPendingVaultQueue();

        expect(manager.currentState, SyncState.error);
        expect(backstopCalls, 1);
        expect(await storage.hasUncommittedChunks(), isTrue);
        expect(uploadClient.uploads, isEmpty);
      },
    );
  });
}

class _RecordingUploadClient implements VaultUploadApiClient {
  final uploads = <VaultChunkPayload>[];
  var failNext = false;
  var alwaysFail = false;
  Completer<void>? gate;
  Completer<void>? entered;
  final scriptedResults = <Object>[];

  @override
  Future<bool> uploadVaultChunk(VaultChunkPayload chunk) async {
    uploads.add(chunk);
    final enteredCompleter = entered;
    if (enteredCompleter != null && !enteredCompleter.isCompleted) {
      enteredCompleter.complete();
    }
    await gate?.future;

    if (scriptedResults.isNotEmpty) {
      final result = scriptedResults.removeAt(0);
      if (result is bool) return result;
      throw result;
    }
    if (failNext) {
      failNext = false;
      return false;
    }
    if (alwaysFail) {
      return false;
    }
    return true;
  }
}
