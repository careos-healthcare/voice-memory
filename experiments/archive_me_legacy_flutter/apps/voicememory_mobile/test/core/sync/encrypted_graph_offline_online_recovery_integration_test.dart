import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/sync/encrypted_graph_sync_engine.dart';
import 'package:voicememory_mobile/core/sync/encrypted_graph_sync_queue.dart';
import 'package:voicememory_mobile/core/sync/google_drive_graph_sync_transport.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

import '../../support/scripted_sync_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'offline coalescing survives slow stale completion and retry backoff',
    () async {
      final root = await Directory.systemTemp.createTemp('graph_recovery_e2e_');
      final manifest = File('${root.path}/graph_queue.enc');
      final connectivity = ConnectivityHarness();
      final clock = FakeSyncClock(DateTime.utc(2026, 7, 26, 13));
      final delay = FakeDelay(clock);
      final slowGate = CompleterGate();
      const older = 'AQ==';
      const middle = 'Ag==';
      const newest = 'Aw==';
      final script = ScriptedTransport<_Upload, void>([
        ScriptedFailure<void>(
          TimeoutException('accepted upload response was lost'),
          gate: slowGate,
        ),
        const ScriptedFailure<void>(
          GoogleDriveGraphSyncException(
            GoogleDriveGraphSyncErrorCode.retryable,
            'transient one',
          ),
        ),
        const ScriptedFailure<void>(
          GoogleDriveGraphSyncException(
            GoogleDriveGraphSyncErrorCode.retryable,
            'transient two',
          ),
        ),
        const ScriptedSuccess<void>(null),
      ]);
      final transport = _ScriptedGraphTransport(script);
      var nextId = 0;
      final queue = EncryptedGraphSyncQueue(
        manifestFile: manifest,
        keyStore: InMemoryPrivateDataEncryptionKeyStore(
          seedKey: List<int>.generate(32, (index) => index + 7),
        ),
        transport: transport,
        connectivityChanges: connectivity.stream,
        foregroundUnlocked: () async => true,
        isOnline: connectivity.isOnline,
        clock: clock.call,
        delay: delay.call,
        idFactory: () => 'graph-${nextId++}',
        random: _ZeroRandom(),
        baseBackoff: const Duration(seconds: 2),
        maxBackoff: const Duration(seconds: 8),
      );
      addTearDown(() async {
        slowGate.open();
        await queue.dispose();
        await connectivity.dispose();
        if (await root.exists()) await root.delete(recursive: true);
      });

      connectivity.emitOffline();
      await queue.upload(
        target: EncryptedGraphSyncTarget.googleDrive,
        path: 'ArchiveMe_Sync/graph.enc',
        encryptedEnvelope: _envelope(older),
      );
      await queue.upload(
        target: EncryptedGraphSyncTarget.googleDrive,
        path: 'ArchiveMe_Sync/graph.enc',
        encryptedEnvelope: _envelope(middle),
      );
      expect(await queue.items, hasLength(1));
      expect((await queue.items).single.encryptedEnvelope, _envelope(middle));

      connectivity.emitWifi();
      await slowGate.entered;
      final newestUpload = queue.upload(
        target: EncryptedGraphSyncTarget.googleDrive,
        path: 'ArchiveMe_Sync/graph.enc',
        encryptedEnvelope: _envelope(newest),
      );
      await pumpUntil(
        () async =>
            (await queue.items).single.encryptedEnvelope == _envelope(newest),
      );
      slowGate.open();
      await newestUpload;

      final retained = (await queue.items).single;
      expect(retained.encryptedEnvelope, _envelope(newest));
      expect(retained.attemptCount, 2);
      expect(retained.lastFailure, EncryptedGraphSyncQueueFailure.retryable);
      clock.advance(const Duration(seconds: 3));
      final firstDrain = queue.drain();
      final concurrentDrain = queue.drain();
      await Future.wait(<Future<void>>[firstDrain, concurrentDrain]);

      expect(await queue.items, isEmpty);
      expect(delay.calls, <Duration>[
        const Duration(milliseconds: 1500),
        const Duration(milliseconds: 1500),
      ]);
      expect(transport.maxActive, 1);
      expect(script.requests.map((request) => request.envelope), <String>[
        _envelope(middle),
        _envelope(newest),
        _envelope(newest),
        _envelope(newest),
      ]);
      final raw = await manifest.readAsString();
      expect(raw, isNot(contains('private transcript needle')));
      expect(raw, isNot(contains('raw audio needle')));
      expect(raw, isNot(contains('encryptedEnvelope')));
    },
  );
}

String _envelope(String ciphertext) =>
    '{"version":1,"algorithm":"AES-256-GCM",'
    '"kdf":"PBKDF2-HMAC-SHA256","mode":"portable",'
    '"salt":"AAAAAAAAAAAAAAAAAAAAAA==","iterations":210000,'
    '"nonce":"AAAAAAAAAAAAAAAA","ciphertext":"$ciphertext",'
    '"mac":"AAAAAAAAAAAAAAAAAAAAAA=="}';

final class _Upload {
  const _Upload(this.path, this.envelope);

  final String path;
  final String envelope;
}

final class _ScriptedGraphTransport implements EncryptedGraphSyncTransport {
  _ScriptedGraphTransport(this.script);

  final ScriptedTransport<_Upload, void> script;
  int active = 0;
  int maxActive = 0;

  @override
  Future<String> download({
    required EncryptedGraphSyncTarget target,
    required String path,
  }) async => _envelope('AQ==');

  @override
  Future<void> upload({
    required EncryptedGraphSyncTarget target,
    required String path,
    required String encryptedEnvelope,
  }) async {
    active++;
    if (active > maxActive) maxActive = active;
    try {
      await script.send(_Upload(path, encryptedEnvelope));
    } finally {
      active--;
    }
  }
}

final class _ZeroRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => 0;
}
