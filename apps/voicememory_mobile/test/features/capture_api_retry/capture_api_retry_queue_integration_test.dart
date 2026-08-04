import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/api/api_exceptions.dart';
import 'package:voicememory_mobile/features/capture_api_retry/capture_api_retry_queue.dart';
import 'package:voicememory_mobile/features/processing_preferences/processing_preferences.dart';
import 'package:voicememory_mobile/features/remote_transcription/remote_transcription_disclosure.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/local_capture_context.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/security/api_usage_guard.dart';
import 'package:voicememory_mobile/services/capture_attest_service.dart';
import 'package:voicememory_mobile/services/capture_pipeline_service.dart';
import 'package:voicememory_mobile/services/privacy/audio_vault_service.dart';
import 'package:voicememory_mobile/storage/capture_token_cache.dart';
import 'package:voicememory_mobile/storage/device_id.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late File manifestFile;
  late JournalStore journal;
  late InMemoryPrivateDataEncryptionKeyStore keyStore;
  late _DeterministicApi api;
  late _FakeAttest attest;
  late AudioVaultService audioVault;
  late Directory audioWorkingDirectory;
  late DateTime now;
  late bool online;
  late int nextJobId;
  final queues = <CaptureApiRetryQueue>[];
  final connectivityControllers =
      <StreamController<List<ConnectivityResult>>>[];

  setUp(() async {
    root = await Directory.systemTemp.createTemp(
      'capture_api_retry_integration_',
    );
    manifestFile = File('${root.path}/capture_retry.enc');
    keyStore = InMemoryPrivateDataEncryptionKeyStore(
      seedKey: List<int>.generate(32, (index) => index + 1),
    );
    journal = await JournalStore.open(
      '${root.path}/journal.json',
      ownerArchiveId: 'local',
      keyStore: keyStore,
    );
    api = _DeterministicApi();
    attest = _FakeAttest(api);
    audioWorkingDirectory = Directory('${root.path}/audio-working');
    audioVault = AudioVaultService(
      keyStore: InMemoryAudioVaultKeyStore(),
      vaultDirectory: () async => Directory('${root.path}/audio-vault'),
      temporaryDirectory: () async => audioWorkingDirectory,
    );
    now = DateTime.utc(2026, 7, 25, 12);
    online = false;
    nextJobId = 0;
  });

  tearDown(() async {
    for (final queue in queues.reversed) {
      await queue.dispose();
    }
    for (final controller in connectivityControllers) {
      await controller.close();
    }
    ApiUsageGuard.resetForTest();
    if (await root.exists()) await root.delete(recursive: true);
  });

  CaptureApiRetryQueue createQueue(
    StreamController<List<ConnectivityResult>> connectivity,
  ) {
    connectivityControllers.add(connectivity);
    final queue = CaptureApiRetryQueue(
      manifestFile: manifestFile,
      keyStore: keyStore,
      api: api,
      attest: attest,
      journalStore: journal,
      audioVault: audioVault,
      connectivityChanges: connectivity.stream,
      isOnline: () async => online,
      isRemoteOperationAuthorized: (_) async => true,
      clock: () => now,
      idFactory: () => 'job-${nextJobId++}',
      baseBackoff: const Duration(seconds: 1),
      maxBackoff: const Duration(seconds: 1),
    );
    queues.add(queue);
    return queue;
  }

  test(
    'offline typed capture survives encrypted queue and reconnect enrichment',
    () async {
      final connectivity = StreamController<List<ConnectivityResult>>.broadcast(
        sync: true,
      );
      final queue = createQueue(connectivity);
      final pipeline = CapturePipelineService(
        api: api,
        attest: attest,
        journalStore: journal,
        retryQueue: queue,
        remoteDisclosure: const _AcceptedDisclosureGate(),
        usageGuard: ApiUsageGuard(
          cooldownBetweenRetries: Duration.zero,
          baseBackoff: Duration.zero,
        ),
      );
      const transcript = 'Keep this exact local-first identity.';
      final capturedAt = DateTime.utc(2026, 7, 25, 11, 59);
      api.analyzeFailures.add(ConnectivityException());

      final result = await pipeline.saveTextThought(
        transcript: transcript,
        currentInterpretationChoice:
            InterpretationPreference.generatePossibleRead,
        localCaptureContext: LocalCaptureContext(
          capturedAt: capturedAt,
          locationLabel: 'Kitchen',
        ),
      );

      expect(result.localSaved, isTrue);
      expect(result.syncSucceeded, isFalse);
      final local = await journal.getById(result.entry.id);
      expect(local, isNotNull);
      expect(local!.transcript, transcript);
      expect(local.localCaptureContext?.capturedAt, capturedAt);
      expect(local.localCaptureContext?.locationLabel, 'Kitchen');
      expect(await queue.jobs, hasLength(1));
      expect(await manifestFile.readAsString(), isNot(contains(transcript)));

      connectivity.add(const [ConnectivityResult.none]);
      await pumpEventQueue(times: 5);
      expect(api.analyzeCalls, 1);
      expect(await queue.jobs, hasLength(1));

      online = true;
      connectivity.add(const [
        ConnectivityResult.wifi,
        ConnectivityResult.mobile,
      ]);
      await _eventually(() async => (await queue.jobs).isEmpty);

      final enriched = (await journal.getById(result.entry.id))!;
      expect(enriched.id, result.entry.id);
      expect(enriched.transcript, transcript);
      expect(
        enriched.reflection.concreteObservation,
        startsWith('Your words include'),
      );
      expect(enriched.localCaptureContext?.capturedAt, capturedAt);
      expect(enriched.localCaptureContext?.locationLabel, 'Kitchen');
      expect(api.analyzeCalls, 2);
    },
  );

  test(
    'interrupted audio retry persists across restart and completes once',
    () async {
      final audioBytes = List<int>.generate(4096, (index) => index % 251);
      final sourceAudio = File('${root.path}/source.wav');
      await sourceAudio.writeAsBytes(audioBytes, flush: true);
      final sealed = await audioVault.sealCapture('voice-entry', sourceAudio);
      await audioVault.secureDeletePlaintext(sourceAudio);
      final pinnedAt = DateTime.utc(2026, 7, 20);
      const entryId = 'voice-entry';
      const idempotencyKey = 'stable-transcription-key';
      await journal.save(
        JournalEntry(
          id: entryId,
          createdAt: DateTime.utc(2026, 7, 25),
          transcript: '[draft] local transcript',
          durationSeconds: 12,
          reflection: _emptyReflection,
          syncStatus: SyncStatus.localOnly,
          localAudioVaultRef: sealed.reference,
          isPinned: true,
          pinnedAt: pinnedAt,
          keepExactDetails: true,
        ),
      );

      final firstConnectivity =
          StreamController<List<ConnectivityResult>>.broadcast(sync: true);
      final firstQueue = createQueue(firstConnectivity);
      api.transcribeFailures.add(RequestTimeoutException());
      await firstQueue.enqueueTranscribeVault(
        entryId: entryId,
        vaultReference: sealed.reference,
        durationSeconds: 12,
        idempotencyKey: idempotencyKey,
      );

      online = true;
      firstConnectivity.add(const [ConnectivityResult.wifi]);
      await _eventually(() async {
        final jobs = await firstQueue.jobs;
        return jobs.length == 1 && jobs.single.attempts == 1;
      });

      final failedJob = (await firstQueue.jobs).single;
      expect(failedJob.nextAttemptAt, isNotNull);
      expect(failedJob.nextAttemptAt!.isAfter(now), isTrue);
      expect(await sourceAudio.exists(), isFalse);
      final unchanged = (await journal.getById(entryId))!;
      expect(unchanged.transcript, '[draft] local transcript');
      expect(unchanged.localAudioVaultRef, sealed.reference);
      expect(unchanged.isPinned, isTrue);
      expect(api.transcribeBytes.single, audioBytes);
      expect(api.transcribeIdempotencyKeys, [idempotencyKey]);

      await firstQueue.dispose();
      now = now.add(const Duration(seconds: 2));
      online = false;
      final restartConnectivity =
          StreamController<List<ConnectivityResult>>.broadcast(sync: true);
      final restartedQueue = createQueue(restartConnectivity);
      expect((await restartedQueue.jobs).single.attempts, 1);

      restartConnectivity.add(const [ConnectivityResult.none]);
      await pumpEventQueue(times: 5);
      expect(api.transcribeCalls, 1);

      online = true;
      restartConnectivity.add(const [ConnectivityResult.mobile]);
      await _eventually(() async => (await restartedQueue.jobs).isEmpty);

      final recovered = (await journal.getById(entryId))!;
      expect(recovered.id, entryId);
      expect(recovered.transcript, 'recovered audio transcript');
      expect(
        recovered.reflection.concreteObservation,
        startsWith('Your words include'),
      );
      expect(recovered.localAudioVaultRef, sealed.reference);
      expect(recovered.isPinned, isTrue);
      expect(recovered.pinnedAt, pinnedAt);
      expect(recovered.keepExactDetails, isTrue);
      expect(await sourceAudio.exists(), isFalse);
      expect(await audioVault.exists(sealed.reference), isTrue);
      if (await audioWorkingDirectory.exists()) {
        expect(await audioWorkingDirectory.list().toList(), isEmpty);
      }
      expect(api.transcribeCalls, 2);
      expect(api.transcribeBytes, [audioBytes, audioBytes]);
      expect(api.transcribeIdempotencyKeys, [idempotencyKey, idempotencyKey]);
      expect(api.analyzeCalls, 1);
      expect(api.analyzeIdempotencyKeys, ['$idempotencyKey:analyze']);
    },
  );
}

final class _AcceptedDisclosureGate
    implements RemoteTranscriptionDisclosureGate {
  const _AcceptedDisclosureGate();

  @override
  Future<RemoteTranscriptionDisclosureResult> check({
    RemoteProcessingPurpose purpose = RemoteProcessingPurpose.transcription,
  }) async => const RemoteTranscriptionDisclosureResult.accepted(
    remoteTranscriptionDisclosureVersion,
  );
}

const _emptyReflection = Reflection(
  mood: 'neutral',
  emotionalIntensity: 0,
  recurringThemes: [],
  exactLanguagePattern: '',
  concreteObservation: '',
  repeatedSignal: '',
);

Future<void> _eventually(
  Future<bool> Function() predicate, {
  int maxPumps = 200,
}) async {
  for (var index = 0; index < maxPumps; index++) {
    if (await predicate()) return;
    await pumpEventQueue();
  }
  throw TestFailure('Condition was not reached after $maxPumps event pumps.');
}

final class _DeterministicApi extends VoiceCaptureApiClient {
  _DeterministicApi() : super(ApiTransport(baseUrl: 'https://example.test'));

  final analyzeFailures = <Object>[];
  final transcribeFailures = <Object>[];
  final transcribeBytes = <List<int>>[];
  final transcribeIdempotencyKeys = <String?>[];
  final analyzeIdempotencyKeys = <String?>[];
  var transcribeCalls = 0;
  var analyzeCalls = 0;

  @override
  Future<String> postTranscribe({
    required File audioFile,
    required int durationSeconds,
    required String captureToken,
    String? idempotencyKey,
  }) async {
    transcribeCalls++;
    transcribeBytes.add(await audioFile.readAsBytes());
    transcribeIdempotencyKeys.add(idempotencyKey);
    if (transcribeFailures.isNotEmpty) throw transcribeFailures.removeAt(0);
    return 'recovered audio transcript';
  }

  @override
  Future<Reflection> postAnalyze({
    required String transcript,
    required String captureToken,
    List<Map<String, dynamic>> priorEvidence = const [],
    String? idempotencyKey,
    String? entryId,
  }) async {
    analyzeCalls++;
    analyzeIdempotencyKeys.add(idempotencyKey);
    if (analyzeFailures.isNotEmpty) throw analyzeFailures.removeAt(0);
    return const Reflection(
      mood: 'steady',
      emotionalIntensity: 2,
      recurringThemes: ['recovery'],
      exactLanguagePattern: 'exact',
      concreteObservation: 'recovered reflection',
      repeatedSignal: '',
    );
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
