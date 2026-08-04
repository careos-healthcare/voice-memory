import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/core/sync/encrypted_graph_sync_engine.dart';
import 'package:voicememory_mobile/core/sync/encrypted_graph_sync_queue.dart';
import 'package:voicememory_mobile/features/capture_api_retry/capture_api_retry_queue.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/capture_attest_service.dart';
import 'package:voicememory_mobile/storage/capture_token_cache.dart';
import 'package:voicememory_mobile/storage/device_id.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

import 'support/scripted_sync_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ChaosFixture fixture;

  setUp(() async {
    fixture = await _ChaosFixture.create();
  });

  tearDown(() => fixture.dispose());

  test(
    'high latency survives carrier flaps while both calls are in flight',
    () async {
      final captureGate = CompleterGate();
      final graphGate = CompleterGate();
      fixture.captureNetwork.add(
        NetworkSuccess<Reflection>(_reflection, gate: captureGate),
      );
      fixture.graphNetwork.add(NetworkSuccess<void>(null, gate: graphGate));
      await fixture.enqueueCapture('latency');
      await fixture.enqueueGraph('latency');

      fixture.carrier.emitWifi();
      await Future.wait(<Future<void>>[captureGate.entered, graphGate.entered]);
      fixture.carrier.emitMobile();
      fixture.carrier.emitOffline();
      fixture.carrier.emitWifi();

      expect(await fixture.capture.jobs, hasLength(1));
      expect(await fixture.graph.items, hasLength(1));
      expect(fixture.captureNetwork.recorder.maxConcurrency, 1);
      expect(fixture.graphNetwork.recorder.maxConcurrency, 1);

      captureGate.open();
      graphGate.open();
      await pumpUntil(
        () async =>
            (await fixture.capture.jobs).isEmpty &&
            (await fixture.graph.items).isEmpty,
      );
      expect(fixture.captureNetwork.recorder.calls, hasLength(1));
      expect(fixture.graphNetwork.recorder.calls, hasLength(1));
    },
  );

  test('accepted response retry reuses key and commits one mutation', () async {
    fixture.captureNetwork
      ..add(const NetworkTimeoutAfterAccept<Reflection>(_reflection))
      ..add(const NetworkSuccess<Reflection>(_reflection));
    final original = await fixture.enqueueCapture('ambiguous');

    fixture.carrier.emitWifi();
    await fixture.capture.drain();
    final failed = (await fixture.capture.jobs).single;
    expect(failed.id, original.id);
    expect(failed.idempotencyKey, original.idempotencyKey);
    expect(failed.attempts, 1);

    fixture.clock.advance(const Duration(hours: 72));
    await fixture.capture.drain();
    expect(await fixture.capture.jobs, isEmpty);
    expect(fixture.captureNetwork.recorder.attemptsByKey, <String, int>{
      original.idempotencyKey: 2,
    });
    expect(fixture.captureNetwork.recorder.commitsByKey, <String, int>{
      original.idempotencyKey: 1,
    });
    expect(
      (await fixture.journal.loadAll()).map((entry) => entry.id).toList(),
      <String>['entry-ambiguous'],
    );
  });

  test(
    'byte windows throttle large payloads without attempt inflation',
    () async {
      final captureThrottle = ByteBudgetThrottle(
        clock: fixture.clock,
        bytesPerWindow: 4096,
        window: const Duration(milliseconds: 25),
      );
      final graphThrottle = ByteBudgetThrottle(
        clock: fixture.clock,
        bytesPerWindow: 8192,
        window: const Duration(milliseconds: 20),
      );
      fixture.captureNetwork.add(
        NetworkSuccess<Reflection>(_reflection, throttle: captureThrottle),
      );
      fixture.graphNetwork.add(
        NetworkSuccess<void>(null, throttle: graphThrottle),
      );
      final transcript = 'large-private-payload-' * 5000;
      final envelope = _envelope(
        List<int>.generate(128 * 1024, (i) => i % 251),
      );
      final captureJob = await fixture.enqueueCapture(
        'bandwidth',
        transcript: transcript,
      );
      final graphItem = await fixture.enqueueGraph(
        'bandwidth',
        envelope: envelope,
      );

      fixture.carrier.emitWifi();
      await pumpUntil(
        () async =>
            (await fixture.capture.jobs).isEmpty &&
            (await fixture.graph.items).isEmpty,
      );

      expect(captureThrottle.consumedBytes, utf8.encode(transcript).length);
      expect(graphThrottle.consumedBytes, utf8.encode(envelope).length);
      expect(
        fixture.captureNetwork.recorder.calls.single.idempotencyKey,
        captureJob.idempotencyKey,
      );
      expect(
        fixture.graphNetwork.recorder.calls.single.request.hash,
        sha256.convert(utf8.encode(graphItem.encryptedEnvelope)).toString(),
      );
      expect(fixture.captureNetwork.recorder.calls, hasLength(1));
      expect(fixture.graphNetwork.recorder.calls, hasLength(1));
    },
  );

  test(
    'duplicate reconnect storm and concurrent drains remain single-flight',
    () async {
      final captureGate = CompleterGate();
      final graphGate = CompleterGate();
      fixture.captureNetwork.add(
        NetworkSuccess<Reflection>(_reflection, gate: captureGate),
      );
      fixture.graphNetwork.add(NetworkSuccess<void>(null, gate: graphGate));
      await fixture.enqueueCapture('storm');
      await fixture.enqueueGraph('storm');

      fixture.carrier.emitWifi();
      await Future.wait(<Future<void>>[captureGate.entered, graphGate.entered]);
      fixture.carrier.emitDuplicateWifiStorm(20);
      final drains = <Future<void>>[
        for (var i = 0; i < 20; i++) fixture.capture.drain(),
        for (var i = 0; i < 20; i++) fixture.graph.drain(),
      ];
      expect(fixture.captureNetwork.recorder.calls, hasLength(1));
      expect(fixture.graphNetwork.recorder.calls, hasLength(1));

      captureGate.open();
      graphGate.open();
      await Future.wait(drains);
      expect(await fixture.capture.jobs, isEmpty);
      expect(await fixture.graph.items, isEmpty);
      expect(fixture.captureNetwork.recorder.maxConcurrency, 1);
      expect(fixture.graphNetwork.recorder.maxConcurrency, 1);
      expect(fixture.captureNetwork.recorder.commitsByKey.values.single, 1);
      expect(fixture.graphNetwork.recorder.commitsByKey.values.single, 1);
    },
  );

  test('captive portal retains work until stable Wi-Fi', () async {
    fixture.captureNetwork.add(const NetworkSuccess<Reflection>(_reflection));
    fixture.graphNetwork.add(const NetworkSuccess<void>(null));
    await fixture.enqueueCapture('portal');
    await fixture.enqueueGraph('portal');

    fixture.carrier.emitCaptivePortal();
    await pumpEventQueue();
    expect(await fixture.capture.jobs, hasLength(1));
    expect(await fixture.graph.items, hasLength(1));
    expect(fixture.captureNetwork.recorder.calls, isEmpty);
    expect(fixture.graphNetwork.recorder.calls, isEmpty);

    fixture.carrier.emitOffline();
    fixture.carrier.emitWifi();
    await pumpUntil(
      () async =>
          (await fixture.capture.jobs).isEmpty &&
          (await fixture.graph.items).isEmpty,
    );
    expect(fixture.captureNetwork.recorder.calls, hasLength(1));
    expect(fixture.graphNetwork.recorder.calls, hasLength(1));
  });

  test('stale graph completion cannot remove newest envelope', () async {
    final staleGate = CompleterGate();
    fixture.graphNetwork
      ..add(NetworkOutOfOrder<void>(null, release: staleGate))
      ..add(const NetworkSuccess<void>(null));
    fixture.carrier.emitWifi();
    final oldEnvelope = _envelope(const <int>[1]);
    final newestEnvelope = _envelope(const <int>[2, 3]);
    final oldUpload = fixture.graph.upload(
      target: EncryptedGraphSyncTarget.googleDrive,
      path: 'ArchiveMe_Sync/coalesced.enc',
      encryptedEnvelope: oldEnvelope,
    );
    await staleGate.entered;
    final newestUpload = fixture.graph.upload(
      target: EncryptedGraphSyncTarget.googleDrive,
      path: 'ArchiveMe_Sync/coalesced.enc',
      encryptedEnvelope: newestEnvelope,
    );
    await pumpUntil(
      () async =>
          (await fixture.graph.items).single.encryptedEnvelope ==
          newestEnvelope,
    );

    staleGate.open();
    await Future.wait(<Future<void>>[oldUpload, newestUpload]);
    final retained = (await fixture.graph.items).single;
    expect(retained.encryptedEnvelope, newestEnvelope);
    expect(retained.attemptCount, 0);

    await fixture.graph.drain();
    expect(await fixture.graph.items, isEmpty);
    expect(
      fixture.graphNetwork.recorder.calls.map((call) => call.request.hash),
      <String>[
        sha256.convert(utf8.encode(oldEnvelope)).toString(),
        sha256.convert(utf8.encode(newestEnvelope)).toString(),
      ],
    );
  });

  test(
    'restart reopens encrypted manifests and drains after 72 hours',
    () async {
      fixture.captureNetwork.add(const NetworkPacketDrop<Reflection>());
      fixture.graphNetwork.add(const NetworkPacketDrop<void>());
      await fixture.enqueueCapture('restart');
      await fixture.enqueueGraph('restart');
      fixture.carrier.emitWifi();
      await Future.wait(<Future<void>>[
        fixture.capture.drain(),
        fixture.graph.drain(),
      ]);
      expect((await fixture.capture.jobs).single.attempts, 1);
      expect((await fixture.graph.items).single.attemptCount, 1);
      final captureBefore = (await fixture.capture.jobs).single;
      final graphBefore = (await fixture.graph.items).single;

      fixture.carrier.emitOffline();
      await fixture.restartQueues();
      fixture.clock.advance(const Duration(hours: 72));
      fixture.captureNetwork.add(const NetworkSuccess<Reflection>(_reflection));
      fixture.graphNetwork.add(const NetworkSuccess<void>(null));
      fixture.carrier.emitWifi();
      await Future.wait(<Future<void>>[
        fixture.capture.drain(),
        fixture.graph.drain(),
      ]);
      expect(await fixture.capture.jobs, isEmpty);
      expect(await fixture.graph.items, isEmpty);

      expect(
        fixture.captureNetwork.recorder.calls.last.idempotencyKey,
        captureBefore.idempotencyKey,
      );
      expect(
        fixture.graphNetwork.recorder.calls.last.request.hash,
        sha256.convert(utf8.encode(graphBefore.encryptedEnvelope)).toString(),
      );
      expect(
        await fixture.captureManifest.readAsString(),
        isNot(contains('private-restart')),
      );
      expect(
        await fixture.graphManifest.readAsString(),
        isNot(contains('ArchiveMe_Sync/restart.enc')),
      );
    },
  );

  test(
    'large mixed backlog is accounted exactly once after partial failures',
    () async {
      const count = 12;
      for (var i = 0; i < count; i++) {
        fixture.captureNetwork.add(
          i.isEven
              ? const NetworkPacketDrop<Reflection>()
              : const NetworkSuccess<Reflection>(_reflection),
        );
        fixture.graphNetwork.add(
          i.isEven
              ? const NetworkPacketDrop<void>()
              : const NetworkSuccess<void>(null),
        );
        await fixture.enqueueCapture('backlog-$i');
        await fixture.enqueueGraph('backlog-$i');
      }
      fixture.carrier.emitWifi();
      await pumpUntil(
        () async =>
            (await fixture.capture.jobs).length == count ~/ 2 &&
            (await fixture.graph.items).length == count ~/ 2,
      );
      expect(
        (await fixture.capture.jobs).every((job) => job.attempts == 1),
        isTrue,
      );
      expect(
        (await fixture.graph.items).every((item) => item.attemptCount == 1),
        isTrue,
      );

      fixture.clock.advance(const Duration(hours: 72));
      for (var i = 0; i < count; i += 2) {
        fixture.captureNetwork.add(
          const NetworkSuccess<Reflection>(_reflection),
        );
        fixture.graphNetwork.add(const NetworkSuccess<void>(null));
      }
      await Future.wait(<Future<void>>[
        fixture.capture.drain(),
        fixture.capture.drain(),
        fixture.graph.drain(),
        fixture.graph.drain(),
      ]);

      expect(await fixture.capture.jobs, isEmpty);
      expect(await fixture.graph.items, isEmpty);
      final journalIds = (await fixture.journal.loadAll())
          .map((entry) => entry.id)
          .toList();
      expect(journalIds.toSet(), hasLength(count));
      expect(journalIds, hasLength(count));
      expect(fixture.captureNetwork.recorder.commitsByKey, hasLength(count));
      expect(fixture.graphNetwork.recorder.commitsByKey, hasLength(count));
      expect(fixture.captureNetwork.recorder.maxConcurrency, 1);
      expect(fixture.graphNetwork.recorder.maxConcurrency, 1);
      expect(
        await fixture.captureManifest.readAsString(),
        isNot(contains('private-backlog')),
      );
      expect(
        await fixture.graphManifest.readAsString(),
        isNot(contains('ArchiveMe_Sync/backlog')),
      );
    },
  );
}

final class _ChaosFixture {
  _ChaosFixture._({
    required this.root,
    required this.captureManifest,
    required this.graphManifest,
    required this.keyStore,
    required this.journal,
    required this.carrier,
    required this.clock,
    required this.captureNetwork,
    required this.graphNetwork,
  });

  static Future<_ChaosFixture> create() async {
    final root = await Directory.systemTemp.createTemp('offline_chaos_');
    final keyStore = InMemoryPrivateDataEncryptionKeyStore(
      seedKey: List<int>.generate(32, (index) => index),
    );
    final fixture = _ChaosFixture._(
      root: root,
      captureManifest: File('${root.path}/capture.enc'),
      graphManifest: File('${root.path}/graph.enc'),
      keyStore: keyStore,
      journal: await JournalStore.open(
        '${root.path}/journal.enc',
        keyStore: keyStore,
      ),
      carrier: ConnectivityHarness(),
      clock: FakeSyncClock(DateTime.utc(2026, 7, 26)),
      captureNetwork: DeterministicNetwork<String, Reflection>(),
      graphNetwork: DeterministicNetwork<_GraphRequest, void>(),
    );
    fixture._openQueues();
    fixture.carrier.emitOffline();
    return fixture;
  }

  final Directory root;
  final File captureManifest;
  final File graphManifest;
  final InMemoryPrivateDataEncryptionKeyStore keyStore;
  final JournalStore journal;
  final ConnectivityHarness carrier;
  final FakeSyncClock clock;
  final DeterministicNetwork<String, Reflection> captureNetwork;
  final DeterministicNetwork<_GraphRequest, void> graphNetwork;
  late CaptureApiRetryQueue capture;
  late EncryptedGraphSyncQueue graph;
  int _captureIds = 0;
  int _graphIds = 0;
  final List<CaptureApiRetryQueue> _captures = <CaptureApiRetryQueue>[];
  final List<EncryptedGraphSyncQueue> _graphs = <EncryptedGraphSyncQueue>[];

  void _openQueues() {
    final api = _ChaosCaptureApi(captureNetwork);
    capture = CaptureApiRetryQueue(
      manifestFile: captureManifest,
      keyStore: keyStore,
      api: api,
      attest: _Attest(api),
      journalStore: journal,
      connectivityChanges: carrier.stream,
      isOnline: carrier.isOnline,
      clock: clock.call,
      idFactory: () => 'capture-${_captureIds++}',
      baseBackoff: const Duration(seconds: 1),
      maxBackoff: const Duration(seconds: 2),
    );
    graph = EncryptedGraphSyncQueue(
      manifestFile: graphManifest,
      keyStore: keyStore,
      transport: _ChaosGraphTransport(graphNetwork),
      connectivityChanges: carrier.stream,
      foregroundUnlocked: () async => true,
      isOnline: carrier.isOnline,
      clock: clock.call,
      delay: FakeDelay(clock).call,
      idFactory: () => 'graph-${_graphIds++}',
      maxRetryAttemptsPerDrain: 1,
      baseBackoff: const Duration(seconds: 1),
      maxBackoff: const Duration(seconds: 2),
    );
    _captures.add(capture);
    _graphs.add(graph);
  }

  Future<CaptureApiRetryJob> enqueueCapture(
    String suffix, {
    String? transcript,
  }) async {
    final text = transcript ?? 'private-$suffix';
    await journal.save(_entry('entry-$suffix', text));
    await capture.enqueueAnalyze(
      entryId: 'entry-$suffix',
      transcript: text,
      idempotencyKey: 'capture-key-$suffix',
    );
    return (await capture.jobs).singleWhere(
      (job) => job.entryId == 'entry-$suffix',
    );
  }

  Future<EncryptedGraphSyncQueueItem> enqueueGraph(
    String suffix, {
    String? envelope,
  }) async {
    await graph.upload(
      target: EncryptedGraphSyncTarget.googleDrive,
      path: 'ArchiveMe_Sync/$suffix.enc',
      encryptedEnvelope: envelope ?? _envelope(utf8.encode(suffix)),
    );
    return (await graph.items).singleWhere(
      (item) => item.path == 'ArchiveMe_Sync/$suffix.enc',
    );
  }

  Future<void> restartQueues() async {
    await capture.dispose();
    await graph.dispose();
    _captures.remove(capture);
    _graphs.remove(graph);
    _openQueues();
  }

  Future<void> dispose() async {
    for (final queue in _captures.reversed) {
      await queue.dispose();
    }
    for (final queue in _graphs.reversed) {
      await queue.dispose();
    }
    await carrier.dispose();
    if (await root.exists()) await root.delete(recursive: true);
  }
}

final class _ChaosCaptureApi extends VoiceCaptureApiClient {
  _ChaosCaptureApi(this.network)
    : super(ApiTransport(baseUrl: 'https://example.test'));

  final DeterministicNetwork<String, Reflection> network;

  @override
  Future<Reflection> postAnalyze({
    required String transcript,
    required String captureToken,
    List<Map<String, dynamic>> priorEvidence = const [],
    String? idempotencyKey,
    String? entryId,
  }) => network.send(
    request: transcript,
    idempotencyKey: idempotencyKey!,
    payloadBytes: utf8.encode(transcript).length,
  );
}

final class _GraphRequest {
  const _GraphRequest(this.path, this.hash);

  final String path;
  final String hash;
}

final class _ChaosGraphTransport implements EncryptedGraphSyncTransport {
  _ChaosGraphTransport(this.network);

  final DeterministicNetwork<_GraphRequest, void> network;

  @override
  Future<String> download({
    required EncryptedGraphSyncTarget target,
    required String path,
  }) async => _envelope(const <int>[0]);

  @override
  Future<void> upload({
    required EncryptedGraphSyncTarget target,
    required String path,
    required String encryptedEnvelope,
  }) {
    final hash = sha256.convert(utf8.encode(encryptedEnvelope)).toString();
    return network.send(
      request: _GraphRequest(path, hash),
      idempotencyKey: '$path:$hash',
      payloadBytes: utf8.encode(encryptedEnvelope).length,
    );
  }
}

final class _Attest extends CaptureAttestService {
  _Attest(VoiceCaptureApiClient api)
    : super(api: api, deviceIds: _DeviceIds(), tokenCache: CaptureTokenCache());

  @override
  Future<String> ensureCaptureToken({bool forceRefresh = false}) async =>
      'capture-token';
}

final class _DeviceIds extends DeviceIdStore {
  @override
  Future<String> getOrCreate() async => 'device';
}

JournalEntry _entry(String id, String transcript) => JournalEntry(
  id: id,
  createdAt: DateTime.utc(2026, 7, 26),
  transcript: transcript,
  durationSeconds: 1,
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 0,
    recurringThemes: <String>[],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
);

const _reflection = Reflection(
  mood: 'steady',
  emotionalIntensity: 1,
  recurringThemes: <String>[],
  exactLanguagePattern: '',
  concreteObservation: 'recovered',
  repeatedSignal: '',
);

String _envelope(List<int> bytes) =>
    '{"version":1,"algorithm":"AES-256-GCM",'
    '"kdf":"PBKDF2-HMAC-SHA256","mode":"portable",'
    '"salt":"AAAAAAAAAAAAAAAAAAAAAA==","iterations":210000,'
    '"nonce":"AAAAAAAAAAAAAAAA","ciphertext":"${base64Encode(bytes)}",'
    '"mac":"AAAAAAAAAAAAAAAAAAAAAA=="}';
