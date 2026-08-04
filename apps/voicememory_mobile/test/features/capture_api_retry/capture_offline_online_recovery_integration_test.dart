import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/features/capture_api_retry/capture_api_retry_queue.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/services/capture_attest_service.dart';
import 'package:voicememory_mobile/storage/capture_token_cache.dart';
import 'package:voicememory_mobile/storage/device_id.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

import '../../support/scripted_sync_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'drop during slow accepted request recovers once with stable idempotency',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'capture_recovery_e2e_',
      );
      final connectivity = ConnectivityHarness();
      final clock = FakeSyncClock(DateTime.utc(2026, 7, 26, 12));
      final manifest = File('${root.path}/capture_queue.enc');
      final keyStore = InMemoryPrivateDataEncryptionKeyStore(
        seedKey: List<int>.generate(32, (index) => index + 1),
      );
      final journal = await JournalStore.open(
        '${root.path}/journal.json',
        ownerArchiveId: 'local',
        keyStore: keyStore,
      );
      const transcriptNeedle = 'private accepted capture transcript';
      const audioNeedle = 'raw-audio-needle';
      const entryId = 'entry-accepted';
      const idempotencyKey = 'capture-idempotency-stable';
      await journal.save(
        JournalEntry(
          id: entryId,
          createdAt: clock.now,
          transcript: transcriptNeedle,
          durationSeconds: 4,
          reflection: _emptyReflection,
          syncStatus: SyncStatus.localOnly,
        ),
      );

      final slowGate = CompleterGate();
      Reflection? serverCache;
      const accepted = Reflection(
        mood: 'steady',
        emotionalIntensity: 2,
        recurringThemes: <String>['recovery'],
        exactLanguagePattern: 'accepted',
        concreteObservation: 'accepted exactly once',
        repeatedSignal: '',
      );
      final script = ScriptedTransport<String, Reflection>([
        ScriptedFailure<Reflection>(
          TimeoutException('response lost after server acceptance'),
          gate: slowGate,
          onEntered: () => serverCache = accepted,
        ),
        ScriptedSuccess<Reflection>(accepted),
      ]);
      final api = _ScriptedCaptureApi(script, () => serverCache);
      final queue = CaptureApiRetryQueue(
        manifestFile: manifest,
        keyStore: keyStore,
        api: api,
        attest: _FakeAttest(api),
        journalStore: journal,
        connectivityChanges: connectivity.stream,
        isOnline: connectivity.isOnline,
        isRemoteOperationAuthorized: (_) async => true,
        clock: clock.call,
        idFactory: () => 'job-accepted',
        random: _ZeroRandom(),
        baseBackoff: const Duration(seconds: 1),
        maxBackoff: const Duration(seconds: 1),
      );
      addTearDown(() async {
        slowGate.open();
        await queue.dispose();
        await connectivity.dispose();
        if (await root.exists()) await root.delete(recursive: true);
      });

      await queue.enqueueAnalyze(
        entryId: entryId,
        transcript: transcriptNeedle,
        idempotencyKey: idempotencyKey,
      );
      expect((await queue.jobs).single.idempotencyKey, idempotencyKey);
      final rawQueue = await manifest.readAsString();
      expect(rawQueue, isNot(contains(transcriptNeedle)));
      expect(rawQueue, isNot(contains(audioNeedle)));

      connectivity.emitWifi();
      await slowGate.entered;
      expect(api.activeCalls, 1);
      connectivity.emitOffline();
      expect((await queue.jobs).single.idempotencyKey, idempotencyKey);
      slowGate.open();
      await pumpUntil(() async => (await queue.jobs).single.attempts == 1);

      var journalMutations = 0;
      journal.configurePostPersistHook((_) async => journalMutations++);
      clock.advance(const Duration(seconds: 2));
      connectivity.emitWifi();
      final firstDrain = queue.drain();
      final concurrentDrain = queue.drain();
      await Future.wait(<Future<void>>[firstDrain, concurrentDrain]);
      await pumpUntil(() async => (await queue.jobs).isEmpty);

      expect(await queue.jobs, isEmpty);
      expect(script.requests, <String>[idempotencyKey, idempotencyKey]);
      expect(api.maxActiveCalls, 1);
      expect(journalMutations, 1);
      expect(
        (await journal.getById(entryId))!.reflection.concreteObservation,
        startsWith('Your words include'),
      );
    },
  );
}

const _emptyReflection = Reflection(
  mood: 'neutral',
  emotionalIntensity: 0,
  recurringThemes: <String>[],
  exactLanguagePattern: '',
  concreteObservation: '',
  repeatedSignal: '',
);

final class _ScriptedCaptureApi extends VoiceCaptureApiClient {
  _ScriptedCaptureApi(this.script, this.cached)
    : super(ApiTransport(baseUrl: 'https://example.test'));

  final ScriptedTransport<String, Reflection> script;
  final Reflection? Function() cached;
  int activeCalls = 0;
  int maxActiveCalls = 0;

  @override
  Future<Reflection> postAnalyze({
    required String transcript,
    required String captureToken,
    List<Map<String, dynamic>> priorEvidence = const [],
    String? idempotencyKey,
    String? entryId,
  }) async {
    activeCalls++;
    if (activeCalls > maxActiveCalls) maxActiveCalls = activeCalls;
    try {
      final result = await script.send(idempotencyKey!);
      return cached() ?? result;
    } finally {
      activeCalls--;
    }
  }
}

final class _FakeAttest extends CaptureAttestService {
  _FakeAttest(VoiceCaptureApiClient api)
    : super(
        api: api,
        deviceIds: _FakeDeviceIdStore(),
        tokenCache: CaptureTokenCache(),
      );

  @override
  Future<String> ensureCaptureToken({bool forceRefresh = false}) async =>
      'capture-token';
}

final class _FakeDeviceIdStore extends DeviceIdStore {
  @override
  Future<String> getOrCreate() async => 'device-id';
}

final class _ZeroRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => 0;
}
