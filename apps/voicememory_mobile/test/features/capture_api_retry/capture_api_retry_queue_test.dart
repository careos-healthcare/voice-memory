import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/api/api_exceptions.dart';
import 'package:voicememory_mobile/features/capture_api_retry/capture_api_retry_queue.dart';
import 'package:voicememory_mobile/features/processing_preferences/processing_preferences.dart';
import 'package:voicememory_mobile/features/processing_preferences/processing_preferences_store.dart';
import 'package:voicememory_mobile/features/remote_transcription/remote_transcription_disclosure.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/capture_attest_service.dart';
import 'package:voicememory_mobile/services/capture_pipeline_service.dart';
import 'package:voicememory_mobile/storage/capture_token_cache.dart';
import 'package:voicememory_mobile/storage/device_id.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  late Directory root;
  late File manifest;
  late JournalStore journal;
  late InMemoryPrivateDataEncryptionKeyStore keyStore;
  late _FakeApi api;
  late _FakeAttest attest;
  late DateTime now;
  final queues = <CaptureApiRetryQueue>[];

  setUp(() async {
    root = await Directory.systemTemp.createTemp('capture_api_retry_test_');
    manifest = File('${root.path}/capture_api_retry_queue.enc');
    journal = await JournalStore.open(
      '${root.path}/journal.json',
      ownerArchiveId: 'local',
      encryptAtRest: false,
    );
    keyStore = InMemoryPrivateDataEncryptionKeyStore(
      seedKey: List<int>.generate(32, (index) => index),
    );
    api = _FakeApi();
    attest = _FakeAttest(api);
    now = DateTime.utc(2026, 7, 25, 12);
  });

  tearDown(() async {
    for (final queue in queues.reversed) {
      await queue.dispose();
    }
    if (await root.exists()) await root.delete(recursive: true);
  });

  CaptureApiRetryQueue createQueue({
    CaptureApiRetryAuthorizationCheck? isRemoteOperationAuthorized,
  }) {
    var nextId = 0;
    final queue = CaptureApiRetryQueue(
      manifestFile: manifest,
      keyStore: keyStore,
      api: api,
      attest: attest,
      journalStore: journal,
      connectivityChanges: const Stream.empty(),
      isOnline: () async => true,
      isRemoteOperationAuthorized:
          isRemoteOperationAuthorized ?? (_) async => true,
      clock: () => now,
      idFactory: () => 'job-${nextId++}',
      baseBackoff: const Duration(seconds: 1),
      maxBackoff: const Duration(seconds: 2),
    );
    queues.add(queue);
    return queue;
  }

  test('encrypted manifest omits payload and token and deduplicates', () async {
    final queue = createQueue();
    final audio = File('${root.path}/private.m4a')
      ..writeAsBytesSync(List<int>.generate(64, (index) => index));
    await journal.save(_entry(id: 'entry-1'));

    expect(
      await queue.enqueueTranscribe(
        entryId: 'entry-1',
        audioFile: audio,
        durationSeconds: 8,
        idempotencyKey: 'stable-private-key',
      ),
      isTrue,
    );
    expect(
      await queue.enqueueTranscribe(
        entryId: 'entry-1',
        audioFile: audio,
        durationSeconds: 8,
        idempotencyKey: 'stable-private-key',
      ),
      isFalse,
    );

    final raw = await manifest.readAsString();
    expect(raw, isNot(contains('stable-private-key')));
    expect(raw, isNot(contains('audioBase64')));
    expect(raw, isNot(contains('capture-token')));
    final decrypted =
        await EncryptedJsonFileStore(
              file: manifest,
              keyStore: keyStore,
            ).readJson()
            as Map<String, dynamic>;
    expect(decrypted['jobs'], hasLength(1));
  });

  test('clear removes every encrypted retry payload', () async {
    final queue = createQueue();
    await queue.enqueueAnalyze(
      entryId: 'entry-1',
      transcript: 'private thought',
      idempotencyKey: 'analyze-clear',
    );

    await queue.clear();

    expect(await queue.jobs, isEmpty);
    final decrypted =
        await EncryptedJsonFileStore(
              file: manifest,
              keyStore: keyStore,
            ).readJson()
            as Map<String, dynamic>;
    expect(decrypted['jobs'], isEmpty);
  });

  test('classifies only transient failures as retryable', () {
    expect(
      classifyCaptureApiRetryFailure(BackendNotConfiguredException()),
      CaptureApiRetryFailure.backendNotConfigured,
    );
    expect(
      classifyCaptureApiRetryFailure(const SocketException('drop')),
      CaptureApiRetryFailure.retryable,
    );
    expect(
      classifyCaptureApiRetryFailure(TimeoutException('slow')),
      CaptureApiRetryFailure.retryable,
    );
    expect(
      classifyCaptureApiRetryFailure(http.ClientException('transport')),
      CaptureApiRetryFailure.retryable,
    );
    expect(
      classifyCaptureApiRetryFailure(ConnectivityException()),
      CaptureApiRetryFailure.retryable,
    );
    expect(
      classifyCaptureApiRetryFailure(RequestTimeoutException()),
      CaptureApiRetryFailure.retryable,
    );
    expect(
      classifyCaptureApiRetryFailure(ApiException('busy', statusCode: 503)),
      CaptureApiRetryFailure.retryable,
    );
    expect(
      classifyCaptureApiRetryFailure(ApiException('bad', statusCode: 422)),
      CaptureApiRetryFailure.permanent,
    );
    expect(
      classifyCaptureApiRetryFailure(AuthRequiredException()),
      CaptureApiRetryFailure.permanent,
    );
  });

  test('retains backend-not-configured job then drains successfully', () async {
    final queue = createQueue();
    await journal.save(_entry(id: 'entry-1', transcript: 'private thought'));
    attest.configured = false;
    await queue.enqueueAnalyze(
      entryId: 'entry-1',
      transcript: 'private thought',
      idempotencyKey: 'analyze-1',
    );

    await queue.drain();
    expect(await queue.jobs, hasLength(1));
    expect((await queue.jobs).single.attempts, 1);

    attest.configured = true;
    now = now.add(const Duration(seconds: 3));
    await queue.drain();
    expect(await queue.jobs, isEmpty);
    expect((await journal.getById('entry-1'))!.reflection.mood, 'neutral');
  });

  test(
    'typed capture saves locally and queues when backend is absent',
    () async {
      final queue = createQueue();
      attest.configured = false;
      final pipeline = CapturePipelineService(
        api: api,
        attest: attest,
        journalStore: journal,
        retryQueue: queue,
        processingPreferences: const FixedProcessingPreferences(
          ProcessingPreferences(
            interpretation: InterpretationPreference.generatePossibleRead,
          ),
        ),
        remoteDisclosure: const _AcceptedDisclosureGate(),
      );

      final result = await pipeline.saveTextThought(
        transcript: 'keep this private thought',
      );

      expect(result.localSaved, isTrue);
      expect(result.syncSucceeded, isFalse);
      final job = (await queue.jobs).single;
      expect(job.operation, CaptureApiRetryOperation.analyze);
      expect(job.entryId, result.entry.id);
      expect(job.transcript, 'keep this private thought');
    },
  );

  test(
    'capture pipeline sends no prior for first entry and bounded prior for second',
    () async {
      final queue = createQueue();
      final pipeline = CapturePipelineService(
        api: api,
        attest: attest,
        journalStore: journal,
        retryQueue: queue,
        processingPreferences: const FixedProcessingPreferences(
          ProcessingPreferences(
            interpretation: InterpretationPreference.generatePossibleRead,
          ),
        ),
        remoteDisclosure: const _AcceptedDisclosureGate(),
      );

      await pipeline.saveTextThought(
        transcript:
            'When a request arrives late, I say yes before checking my calendar.',
      );
      await pipeline.saveTextThought(
        transcript:
            'Today I said yes before checking my calendar when another request arrived.',
      );

      expect(api.priorEvidenceCalls.first, isEmpty);
      expect(api.priorEvidenceCalls.last, hasLength(1));
      expect(
        api.priorEvidenceCalls.last.single.containsKey('transcript'),
        isFalse,
      );
    },
  );

  test('analysis retry job preserves the same safe prior evidence', () async {
    await journal.save(
      _entry(
        id: 'prior-entry',
        transcript:
            'When a request arrives late, I say yes before checking my calendar.',
        phrase: 'say yes before checking my calendar',
      ),
    );
    final queue = createQueue();
    attest.configured = false;
    final pipeline = CapturePipelineService(
      api: api,
      attest: attest,
      journalStore: journal,
      retryQueue: queue,
      processingPreferences: const FixedProcessingPreferences(
        ProcessingPreferences(
          interpretation: InterpretationPreference.generatePossibleRead,
        ),
      ),
      remoteDisclosure: const _AcceptedDisclosureGate(),
    );

    await pipeline.saveTextThought(
      transcript:
          'Today I said yes before checking my calendar when work called again.',
    );

    final job = (await queue.jobs).single;
    expect(job.priorEvidence, hasLength(1));
    expect(job.priorEvidence.single['id'], 'prior-entry');
    expect(job.priorEvidence.single.containsKey('transcript'), isFalse);
  });

  test('network failure remains queued and later updates reflection', () async {
    final queue = createQueue();
    await journal.save(
      _entry(id: 'entry-1', transcript: 'hello', pinned: true),
    );
    api.analyzeError = const SocketException('network down');
    await queue.enqueueAnalyze(
      entryId: 'entry-1',
      transcript: 'hello',
      idempotencyKey: 'analyze-1',
    );

    await queue.drain();
    expect(await queue.jobs, hasLength(1));

    api.analyzeError = null;
    now = now.add(const Duration(seconds: 3));
    await queue.drain();
    final updated = (await journal.getById('entry-1'))!;
    expect(
      updated.reflection.concreteObservation,
      startsWith('Your words include'),
    );
    expect(updated.isPinned, isTrue);
  });

  test(
    'withdrawn interpretation consent drops retry without remote call',
    () async {
      var authorized = true;
      final queue = createQueue(
        isRemoteOperationAuthorized: (operation) async =>
            operation != CaptureApiRetryOperation.analyze || authorized,
      );
      const original = 'The saved original must survive consent withdrawal.';
      await journal.save(_entry(id: 'entry-1', transcript: original));
      await queue.enqueueAnalyze(
        entryId: 'entry-1',
        transcript: original,
        idempotencyKey: 'analyze-revoked',
      );
      authorized = false;

      await queue.drain();

      expect(api.analyzeTokens, isEmpty);
      expect(await queue.jobs, isEmpty);
      final saved = await journal.getById('entry-1');
      expect(saved, isNotNull);
      expect(saved!.transcript, original);
      expect(saved.reflection.concreteObservation, isEmpty);
    },
  );

  test(
    'stale queued analysis is dropped before authorization or API',
    () async {
      var authorizationChecks = 0;
      final queue = createQueue(
        isRemoteOperationAuthorized: (_) async {
          authorizationChecks++;
          return true;
        },
      );
      await journal.save(
        _entry(id: 'entry-1', transcript: 'The transcript was edited later.'),
      );
      await queue.enqueueAnalyze(
        entryId: 'entry-1',
        transcript: 'The original queued transcript.',
        idempotencyKey: 'analyze-stale',
      );

      await queue.drain();

      expect(await queue.jobs, isEmpty);
      expect(authorizationChecks, 0);
      expect(api.analyzeTokens, isEmpty);
      expect(
        (await journal.getById('entry-1'))!.transcript,
        'The transcript was edited later.',
      );
    },
  );

  test(
    'queued analysis with an existing conclusion is dropped before API',
    () async {
      var authorizationChecks = 0;
      const transcript = 'This moment already has a supported conclusion.';
      final queue = createQueue(
        isRemoteOperationAuthorized: (_) async {
          authorizationChecks++;
          return true;
        },
      );
      await journal.save(
        _entry(
          id: 'entry-1',
          transcript: transcript,
          reflection: Reflection.deterministicTranscriptOnly(
            transcript: transcript,
            entryId: 'entry-1',
          ),
        ),
      );
      await queue.enqueueAnalyze(
        entryId: 'entry-1',
        transcript: transcript,
        idempotencyKey: 'analyze-redundant',
      );

      await queue.drain();

      expect(await queue.jobs, isEmpty);
      expect(authorizationChecks, 0);
      expect(api.analyzeTokens, isEmpty);
      expect(
        (await journal.getById('entry-1'))!.reflection.explainableConclusion,
        isNotNull,
      );
    },
  );

  test(
    'in-flight analysis cannot attach after the entry revision changes',
    () async {
      final queue = createQueue();
      const transcript = 'I checked the same words before sending.';
      await journal.save(_entry(id: 'entry-1', transcript: transcript));
      api.analyzeCompleter = Completer<Reflection>();
      await queue.enqueueAnalyze(
        entryId: 'entry-1',
        transcript: transcript,
        idempotencyKey: 'analyze-in-flight',
      );

      final draining = queue.drain();
      while (api.analyzeTokens.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      final beforeEdit = (await journal.getById('entry-1'))!;
      await journal.save(
        JournalEntry.fromJson({
          ...beforeEdit.toJson(),
          'updatedAt': beforeEdit.updatedAt
              .add(const Duration(seconds: 1))
              .toIso8601String(),
        }),
      );
      api.analyzeCompleter!.complete(
        const Reflection(
          mood: 'steady',
          emotionalIntensity: 2,
          recurringThemes: ['recovery'],
          exactLanguagePattern: 'clear',
          concreteObservation: 'stale cloud reflection',
          repeatedSignal: '',
        ),
      );

      await draining;

      expect(await queue.jobs, isEmpty);
      expect(api.analyzeTokens, ['capture-token']);
      expect(
        (await journal.getById('entry-1'))!.reflection.concreteObservation,
        isEmpty,
      );
    },
  );

  test('transcription recovery waits for review before analysis', () async {
    final queue = createQueue();
    final audio = File('${root.path}/voice.wav')
      ..writeAsBytesSync(List<int>.filled(128, 7));
    await journal.save(_entry(id: 'entry-1', transcript: '[draft]'));
    api.transcript = 'recovered transcript';
    await queue.enqueueTranscribe(
      entryId: 'entry-1',
      audioFile: audio,
      durationSeconds: 10,
      idempotencyKey: 'transcribe-1',
    );

    await queue.drain();

    expect(await queue.jobs, isEmpty);
    final updated = (await journal.getById('entry-1'))!;
    expect(updated.transcript, 'recovered transcript');
    expect(updated.reflection.concreteObservation, isEmpty);
    expect(api.transcribeTokens, ['capture-token']);
    expect(
      api.analyzeTokens,
      isEmpty,
      reason:
          'A recovered transcript must be reviewed before the canonical '
          'interpretation handoff can authorize analysis.',
    );
  });
}

JournalEntry _entry({
  required String id,
  String transcript = 'draft',
  bool pinned = false,
  String phrase = '',
  Reflection? reflection,
}) => JournalEntry(
  id: id,
  createdAt: DateTime.utc(2026, 7, 25),
  transcript: transcript,
  durationSeconds: 4,
  reflection:
      reflection ??
      Reflection(
        mood: 'neutral',
        emotionalIntensity: 0,
        recurringThemes: [],
        exactLanguagePattern: phrase,
        concreteObservation: '',
        repeatedSignal: '',
      ),
  isPinned: pinned,
);

final class _FakeApi extends VoiceCaptureApiClient {
  _FakeApi() : super(ApiTransport(baseUrl: 'https://example.test'));

  Object? analyzeError;
  Completer<Reflection>? analyzeCompleter;
  String transcript = 'server transcript';
  final transcribeTokens = <String>[];
  final analyzeTokens = <String>[];
  final priorEvidenceCalls = <List<Map<String, dynamic>>>[];

  @override
  Future<String> postTranscribe({
    required File audioFile,
    required int durationSeconds,
    required String captureToken,
    String? idempotencyKey,
  }) async {
    transcribeTokens.add(captureToken);
    return transcript;
  }

  @override
  Future<Reflection> postAnalyze({
    required String transcript,
    required String captureToken,
    List<Map<String, dynamic>> priorEvidence = const [],
    String? idempotencyKey,
    String? entryId,
  }) async {
    analyzeTokens.add(captureToken);
    priorEvidenceCalls.add(
      priorEvidence.map((item) => Map<String, dynamic>.from(item)).toList(),
    );
    final error = analyzeError;
    if (error != null) throw error;
    final completer = analyzeCompleter;
    if (completer != null) return completer.future;
    return const Reflection(
      mood: 'steady',
      emotionalIntensity: 2,
      recurringThemes: ['recovery'],
      exactLanguagePattern: 'clear',
      concreteObservation: 'cloud reflection',
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

  bool configured = true;

  @override
  Future<String> ensureCaptureToken({bool forceRefresh = false}) async {
    if (!configured) throw BackendNotConfiguredException();
    return 'capture-token';
  }
}

final class _FakeDeviceIdStore extends DeviceIdStore {
  @override
  Future<String> getOrCreate() async => 'device-id';
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
