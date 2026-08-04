import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/sync/encrypted_graph_sync_engine.dart';
import 'package:voicememory_mobile/core/sync/encrypted_graph_sync_queue.dart';
import 'package:voicememory_mobile/core/sync/google_drive_graph_sync_transport.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  late Directory tempDirectory;
  late File manifestFile;
  late InMemoryPrivateDataEncryptionKeyStore keyStore;
  late StreamController<List<ConnectivityResult>> connectivity;
  final queues = <EncryptedGraphSyncQueue>[];

  setUp(() {
    tempDirectory = Directory.systemTemp.createTempSync('graph_sync_queue_');
    manifestFile = File('${tempDirectory.path}/queue.json.enc');
    keyStore = InMemoryPrivateDataEncryptionKeyStore(
      seedKey: List<int>.generate(32, (index) => index),
    );
    connectivity = StreamController<List<ConnectivityResult>>.broadcast(
      sync: true,
    );
  });

  tearDown(() async {
    for (final queue in queues.reversed) {
      await queue.dispose();
    }
    await connectivity.close();
    tempDirectory.deleteSync(recursive: true);
  });

  EncryptedGraphSyncQueue createQueue({
    _RecordingTransport? transport,
    Future<bool> Function()? foregroundUnlocked,
    Future<bool> Function()? isOnline,
    _FakeClock? clock,
    Future<void> Function(Duration)? delay,
    int maxRetryAttemptsPerDrain = 3,
    String Function()? idFactory,
  }) {
    final queue = EncryptedGraphSyncQueue(
      manifestFile: manifestFile,
      keyStore: keyStore,
      transport: transport ?? _RecordingTransport(),
      connectivityChanges: connectivity.stream,
      foregroundUnlocked: foregroundUnlocked ?? () async => true,
      isOnline: isOnline ?? () async => true,
      clock: clock?.call,
      delay: delay,
      maxRetryAttemptsPerDrain: maxRetryAttemptsPerDrain,
      idFactory: idFactory,
    );
    queues.add(queue);
    return queue;
  }

  test('manifest is encrypted at rest and omits private needles', () async {
    final queue = createQueue(foregroundUnlocked: () async => false);

    await queue.upload(
      target: EncryptedGraphSyncTarget.googleDrive,
      path: 'ArchiveMe_Sync/Alice-private-project.enc',
      encryptedEnvelope: _envelope('AQ=='),
    );

    final raw = await manifestFile.readAsString();
    expect(raw, isNot(contains('Alice-private-project')));
    expect(raw, isNot(contains('encryptedEnvelope')));
    expect(raw, isNot(contains('node')));
    final decrypted = await EncryptedJsonFileStore(
      file: manifestFile,
      keyStore: keyStore,
    ).readJson();
    expect(decrypted, isA<Map>());
  });

  test('persists and reloads immutable queue item fields', () async {
    final clock = _FakeClock(DateTime.utc(2026, 7, 23, 12));
    final first = createQueue(
      foregroundUnlocked: () async => false,
      clock: clock,
      idFactory: () => 'stable-id',
    );
    await first.upload(
      target: EncryptedGraphSyncTarget.iCloudDrive,
      path: 'Documents/ArchiveMe_Sync/graph.enc',
      encryptedEnvelope: _envelope('Ag=='),
    );
    await first.dispose();
    queues.remove(first);

    final restarted = createQueue(
      foregroundUnlocked: () async => false,
      clock: clock,
    );
    final item = (await restarted.items).single;
    expect(item.id, 'stable-id');
    expect(item.target, EncryptedGraphSyncTarget.iCloudDrive);
    expect(item.path, 'Documents/ArchiveMe_Sync/graph.enc');
    expect(item.enqueuedAt, DateTime.utc(2026, 7, 23, 12));
    expect(item.attemptCount, 0);
    expect(item.lastFailure, isNull);
    expect(item.nextAttemptAt, isNull);
  });

  test('coalesces latest snapshot by target and path', () async {
    var nextId = 0;
    final queue = createQueue(
      foregroundUnlocked: () async => false,
      idFactory: () => 'id-${nextId++}',
    );
    await queue.upload(
      target: EncryptedGraphSyncTarget.googleDrive,
      path: 'ArchiveMe_Sync/graph.enc',
      encryptedEnvelope: _envelope('AQ=='),
    );
    final original = (await queue.items).single;
    await queue.upload(
      target: EncryptedGraphSyncTarget.googleDrive,
      path: 'ArchiveMe_Sync/graph.enc',
      encryptedEnvelope: _envelope('Ag=='),
    );

    final retained = (await queue.items).single;
    expect(retained.id, original.id);
    expect(retained.encryptedEnvelope, _envelope('Ag=='));
  });

  test('successful immediate drain uploads and removes item', () async {
    final transport = _RecordingTransport();
    final queue = createQueue(transport: transport);

    await queue.upload(
      target: EncryptedGraphSyncTarget.googleDrive,
      path: 'ArchiveMe_Sync/graph.enc',
      encryptedEnvelope: _envelope('AQ=='),
    );

    expect(transport.uploadCalls, 1);
    expect(await queue.items, isEmpty);
  });

  test('offline upload remains queued and reconnect drains it', () async {
    var online = false;
    final uploaded = Completer<void>();
    final transport = _RecordingTransport(
      onUpload: () async {
        if (!uploaded.isCompleted) uploaded.complete();
      },
    );
    final queue = createQueue(
      transport: transport,
      isOnline: () async => online,
    );
    connectivity.add(const <ConnectivityResult>[ConnectivityResult.none]);

    await queue.upload(
      target: EncryptedGraphSyncTarget.googleDrive,
      path: 'ArchiveMe_Sync/graph.enc',
      encryptedEnvelope: _envelope('AQ=='),
    );
    final offlineItem = (await queue.items).single;
    expect(offlineItem.lastFailure, EncryptedGraphSyncQueueFailure.offline);
    expect(offlineItem.attemptCount, 0);
    expect(transport.uploadCalls, 0);

    online = true;
    connectivity.add(const <ConnectivityResult>[ConnectivityResult.wifi]);
    await uploaded.future.timeout(const Duration(seconds: 1));
    await queue.drain();
    expect(await queue.items, isEmpty);
  });

  test('locked/background gate blocks every attempt', () async {
    final transport = _RecordingTransport();
    final queue = createQueue(
      transport: transport,
      foregroundUnlocked: () async => false,
    );

    await queue.upload(
      target: EncryptedGraphSyncTarget.googleDrive,
      path: 'ArchiveMe_Sync/graph.enc',
      encryptedEnvelope: _envelope('AQ=='),
    );
    await queue.drain();

    expect(transport.uploadCalls, 0);
    expect(await queue.items, hasLength(1));
  });

  test('retryable failures use bounded persisted backoff', () async {
    final clock = _FakeClock(DateTime.utc(2026, 7, 23));
    final delays = <Duration>[];
    final transport = _RecordingTransport(
      errors: <Object>[
        const GoogleDriveGraphSyncException(
          GoogleDriveGraphSyncErrorCode.retryable,
          'temporary',
        ),
        const GoogleDriveGraphSyncException(
          GoogleDriveGraphSyncErrorCode.retryable,
          'temporary',
        ),
        const GoogleDriveGraphSyncException(
          GoogleDriveGraphSyncErrorCode.retryable,
          'temporary',
        ),
      ],
    );
    final queue = createQueue(
      transport: transport,
      clock: clock,
      delay: (duration) async {
        delays.add(duration);
        clock.advance(duration);
      },
    );

    await queue.upload(
      target: EncryptedGraphSyncTarget.googleDrive,
      path: 'ArchiveMe_Sync/graph.enc',
      encryptedEnvelope: _envelope('AQ=='),
    );

    final retained = (await queue.items).single;
    expect(transport.uploadCalls, 3);
    expect(delays, hasLength(2));
    expect(retained.attemptCount, 3);
    expect(retained.lastFailure, EncryptedGraphSyncQueueFailure.retryable);
    expect(retained.nextAttemptAt, isNotNull);

    clock.advance(const Duration(hours: 1));
    await queue.drain();
    expect(transport.uploadCalls, 4);
    expect(await queue.items, isEmpty);
  });

  test('authorization and configuration failures do not loop', () async {
    for (final error in <Object>[
      const GoogleDriveGraphSyncException(
        GoogleDriveGraphSyncErrorCode.authorizationRequired,
        'auth',
      ),
      const GoogleDriveGraphSyncException(
        GoogleDriveGraphSyncErrorCode.notConfigured,
        'config',
      ),
    ]) {
      final localManifest = File(
        '${tempDirectory.path}/${error.runtimeType}-$error.enc',
      );
      final transport = _RecordingTransport(errors: <Object>[error]);
      final queue = EncryptedGraphSyncQueue(
        manifestFile: localManifest,
        keyStore: keyStore,
        transport: transport,
        connectivityChanges: connectivity.stream,
        foregroundUnlocked: () async => true,
        isOnline: () async => true,
      );
      queues.add(queue);
      await queue.upload(
        target: EncryptedGraphSyncTarget.googleDrive,
        path: 'ArchiveMe_Sync/graph.enc',
        encryptedEnvelope: _envelope('AQ=='),
      );
      expect(transport.uploadCalls, 1);
      expect((await queue.items).single.nextAttemptAt, isNull);
    }
  });

  test('nonretryable failure is typed and retained for inspection', () async {
    final queue = createQueue(
      transport: _RecordingTransport(errors: <Object>[ArgumentError('bad')]),
    );

    await expectLater(
      queue.upload(
        target: EncryptedGraphSyncTarget.googleDrive,
        path: 'ArchiveMe_Sync/graph.enc',
        encryptedEnvelope: _envelope('AQ=='),
      ),
      throwsA(isA<EncryptedGraphSyncQueuedFailureException>()),
    );
    final retained = (await queue.items).single;
    expect(retained.lastFailure, EncryptedGraphSyncQueueFailure.nonRetryable);
    expect(retained.nextAttemptAt, isNull);
  });

  test('concurrent drains are single-flight', () async {
    final release = Completer<void>();
    final entered = Completer<void>();
    final transport = _RecordingTransport(
      onUpload: () async {
        if (!entered.isCompleted) entered.complete();
        await release.future;
      },
    );
    final queue = createQueue(
      transport: transport,
      foregroundUnlocked: () async => false,
    );
    await queue.upload(
      target: EncryptedGraphSyncTarget.googleDrive,
      path: 'ArchiveMe_Sync/graph.enc',
      encryptedEnvelope: _envelope('AQ=='),
    );
    var unlocked = true;
    await queue.dispose();
    queues.remove(queue);
    final activeQueue = createQueue(
      transport: transport,
      foregroundUnlocked: () async => unlocked,
    );

    final first = activeQueue.drain();
    await entered.future;
    final second = activeQueue.drain();
    expect(transport.uploadCalls, 1);
    release.complete();
    await Future.wait(<Future<void>>[first, second]);
    expect(transport.uploadCalls, 1);
    expect(await activeQueue.items, isEmpty);
    unlocked = false;
  });

  test('dispose cancels reconnect listener', () async {
    var online = false;
    final transport = _RecordingTransport();
    final queue = createQueue(
      transport: transport,
      isOnline: () async => online,
    );
    connectivity.add(const <ConnectivityResult>[ConnectivityResult.none]);
    await queue.upload(
      target: EncryptedGraphSyncTarget.googleDrive,
      path: 'ArchiveMe_Sync/graph.enc',
      encryptedEnvelope: _envelope('AQ=='),
    );

    await queue.dispose();
    queues.remove(queue);
    online = true;
    connectivity.add(const <ConnectivityResult>[ConnectivityResult.wifi]);
    await Future<void>.delayed(Duration.zero);

    expect(transport.uploadCalls, 0);
  });

  test('malformed manifest fails closed without overwrite', () async {
    final store = EncryptedJsonFileStore(
      file: manifestFile,
      keyStore: keyStore,
    );
    await store.writeJson(<String, Object>{
      'version': 999,
      'items': <Object>[],
    });
    final before = await manifestFile.readAsString();
    final queue = createQueue();

    await expectLater(
      queue.items,
      throwsA(isA<EncryptedGraphSyncQueueManifestException>()),
    );
    await expectLater(
      queue.upload(
        target: EncryptedGraphSyncTarget.googleDrive,
        path: 'ArchiveMe_Sync/graph.enc',
        encryptedEnvelope: _envelope('AQ=='),
      ),
      throwsA(isA<EncryptedGraphSyncQueueManifestException>()),
    );
    expect(await manifestFile.readAsString(), before);
  });
}

String _envelope(String ciphertext) =>
    '{"version":1,"algorithm":"AES-256-GCM",'
    '"kdf":"PBKDF2-HMAC-SHA256","mode":"portable",'
    '"salt":"AAAAAAAAAAAAAAAAAAAAAA==","iterations":210000,'
    '"nonce":"AAAAAAAAAAAAAAAA","ciphertext":"$ciphertext",'
    '"mac":"AAAAAAAAAAAAAAAAAAAAAA=="}';

class _FakeClock {
  _FakeClock(this.value);

  DateTime value;

  DateTime call() => value;

  void advance(Duration duration) {
    value = value.add(duration);
  }
}

class _RecordingTransport implements EncryptedGraphSyncTransport {
  _RecordingTransport({List<Object>? errors, this.onUpload})
    : _errors = errors ?? <Object>[];

  final List<Object> _errors;
  final Future<void> Function()? onUpload;
  int uploadCalls = 0;

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
    uploadCalls++;
    if (_errors.isNotEmpty) throw _errors.removeAt(0);
    await onUpload?.call();
  }
}
