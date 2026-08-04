import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/config/app_config.dart';
import 'package:voicememory_mobile/features/processing_preferences/processing_preferences.dart';
import 'package:voicememory_mobile/features/processing_preferences/processing_preferences_store.dart';
import 'package:voicememory_mobile/features/recording/domain/application/on_device_transcription_availability.dart';
import 'package:voicememory_mobile/features/recording/domain/application/post_capture_disposition_coordinator.dart';
import 'package:voicememory_mobile/features/recording/domain/application/vault_persistence_coordinator.dart';
import 'package:voicememory_mobile/features/remote_transcription/remote_transcription_disclosure.dart';
import 'package:voicememory_mobile/features/transcription_queue/transcription_ledger.dart';
import 'package:voicememory_mobile/features/transcription_queue/transcription_queue_executor.dart';
import 'package:voicememory_mobile/features/voice_capture/transcription/on_device_transcription_engine.dart';
import 'package:voicememory_mobile/features/voice_capture/transcription/transcription_connectivity.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/security/api_usage_guard.dart';
import 'package:voicememory_mobile/security/private_data_service.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/capture_attest_service.dart';
import 'package:voicememory_mobile/services/capture_pipeline_service.dart';
import 'package:voicememory_mobile/services/privacy/audio_vault_service.dart';
import 'package:voicememory_mobile/services/privacy/sensitive_temporary_audio_store.dart';
import 'package:voicememory_mobile/storage/capture_token_cache.dart';
import 'package:voicememory_mobile/storage/device_id.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

void main() {
  late Directory root;
  late Directory vaultDirectory;
  late Directory workingDirectory;
  late Directory protectedDirectory;
  late AudioVaultService vault;
  late JournalStore journal;
  late MobilePrefsStore prefs;
  late RemoteTranscriptionDisclosureStore disclosure;
  late SensitiveTemporaryAudioStore temporaryAudio;
  late TranscriptionLedger ledger;
  late TranscriptionQueueExecutor executor;
  late _SpyVoiceCaptureApi api;
  late int rawHttpRequests;

  setUpAll(AppConfig.initApiResolution);

  setUp(() async {
    // Keeps funnel events off the production analytics sink, which rejects
    // unknown ids from an unrelated registry.
    ActivationFunnelAnalytics.resetForTest();
    ActivationFunnelAnalytics.captureForTest((_, _) {});
    root = await Directory.systemTemp.createTemp('post_capture_disposition_');
    vaultDirectory = Directory('${root.path}/vault');
    workingDirectory = Directory('${root.path}/working');
    protectedDirectory = Directory('${root.path}/protected');
    await protectedDirectory.create(recursive: true);
    temporaryAudio = SensitiveTemporaryAudioStore(
      directory: () async => protectedDirectory,
      legacyDirectories: const [],
    );
    vault = AudioVaultService(
      keyStore: InMemoryAudioVaultKeyStore(),
      vaultDirectory: () async => vaultDirectory,
      temporaryDirectory: () async => workingDirectory,
    );
    journal = JournalStore(
      file: File('${root.path}/journal.json'),
      ownerArchiveId: 'local',
    );
    prefs = await MobilePrefsStore.open('${root.path}/prefs.json');
    disclosure = RemoteTranscriptionDisclosureStore(() => prefs);
    rawHttpRequests = 0;
    api = _SpyVoiceCaptureApi(
      ApiTransport(
        baseUrl: 'https://example.test',
        httpClient: MockClient((_) async {
          rawHttpRequests++;
          return http.Response('{}', 500);
        }),
      ),
    );
    ledger = await TranscriptionLedger.open(
      directory: Directory('${root.path}/queue'),
    );
    executor = TranscriptionQueueExecutor(
      ledger: ledger,
      pipeline: CapturePipelineService(
        api: api,
        attest: _FakeAttest(api),
        journalStore: journal,
        audioVault: vault,
        processingPreferences: const FixedProcessingPreferences(
          ProcessingPreferences(
            transcription: TranscriptionPreference.online,
            interpretation: InterpretationPreference.saveWithoutInterpretation,
          ),
        ),
        remoteDisclosure: disclosure,
        onDeviceTranscription: const _UnavailableOnDeviceEngine(),
        transcriptionConnectivity: const FixedTranscriptionConnectivity(true),
        usageGuard: ApiUsageGuard(
          cooldownBetweenRetries: Duration.zero,
          baseBackoff: Duration.zero,
        ),
      ),
      journal: journal,
    );
  });

  tearDown(() async {
    ActivationFunnelAnalytics.resetForTest();
    await executor.dispose();
    await ledger.close();
    ApiUsageGuard.resetForTest();
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<File> capturedAudio([String name = 'capture.m4a']) async {
    final file = await temporaryAudio.create(
      ownerId: 'voice-capture',
      extension: 'm4a',
    );
    final bytes = List<int>.generate(
      4096,
      (index) => (index + name.length) % 251,
    )..setRange(4, 8, 'ftyp'.codeUnits);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  PostCaptureDispositionCoordinator coordinator({
    OnDeviceTranscriptionEngine? onDeviceEngine,
    bool onDeviceSupported = true,
    bool onlineOnly = false,
  }) {
    return PostCaptureDispositionCoordinator(
      vault: vault,
      journal: () => journal,
      onDeviceEngine: onDeviceEngine ?? _FakeOnDeviceEngine(),
      disclosure: disclosure,
      remoteQueue: VaultPersistenceCoordinator(ledger),
      startRemoteQueue: () async {
        await executor.drain();
      },
      onDeviceSupport: FixedOnDeviceTranscriptionSupport(onDeviceSupported),
      onlineOnlyPreference: FixedOnlineOnlyTranscriptionPreference(onlineOnly),
      temporaryAudio: temporaryAudio,
    );
  }

  Future<bool> refuse() async => false;
  Future<bool> accept() async => true;

  Future<List<File>> vaultObjects() async {
    if (!await vaultDirectory.exists()) return const [];
    return vaultDirectory
        .list()
        .where((entity) => entity.path.endsWith('.enc'))
        .cast<File>()
        .toList();
  }

  test(
    'audio enters the encrypted vault before the transcription choice is presented',
    () async {
      final audio = await capturedAudio();
      final original = await audio.readAsBytes();
      var vaultedObjectsWhenAsked = 0;
      String? referenceWhenAsked;

      final outcome = await coordinator().resolve(
        audio: audio,
        durationSeconds: 12,
        requestChoice: (_) async {
          vaultedObjectsWhenAsked = (await vaultObjects()).length;
          referenceWhenAsked =
              (await journal.loadAll()).single.localAudioVaultRef;
          return PostCaptureDisposition.saveAudioOnly;
        },
        requestRemoteDisclosure: refuse,
        confirmDelete: refuse,
      );

      expect(vaultedObjectsWhenAsked, 1);
      expect(referenceWhenAsked, startsWith(AudioVaultService.referencePrefix));
      expect(await audio.exists(), isFalse);
      expect(outcome.audioRetained, isTrue);
      expect(await vault.readPlaintextBytes(referenceWhenAsked!), original);
    },
  );

  test('declining online transcription keeps the recording', () async {
    final audio = await capturedAudio();
    final original = await audio.readAsBytes();

    final outcome = await coordinator().resolve(
      audio: audio,
      durationSeconds: 9,
      requestChoice: (_) async => PostCaptureDisposition.transcribeOnline,
      requestRemoteDisclosure: refuse,
      confirmDelete: refuse,
    );

    expect(outcome.kind, PostCaptureOutcomeKind.savedAudioOnly);
    expect(outcome.audioRetained, isTrue);
    expect(outcome.note, PostCaptureCopy.remoteDeclinedNote);
    expect(api.transcribeCalls, 0);
    expect(rawHttpRequests, 0);
    expect(ledger.jobs, isEmpty);
    final entry = (await journal.loadAll()).single;
    expect(await vault.readPlaintextBytes(entry.localAudioVaultRef!), original);
  });

  test('on-device transcription makes no network request', () async {
    final engine = _FakeOnDeviceEngine(transcript: 'I paused before replying.');
    final audio = await capturedAudio();

    final outcome = await coordinator(onDeviceEngine: engine).resolve(
      audio: audio,
      durationSeconds: 14,
      requestChoice: (_) async => PostCaptureDisposition.transcribeOnDevice,
      requestRemoteDisclosure: refuse,
      confirmDelete: refuse,
    );

    expect(outcome.kind, PostCaptureOutcomeKind.transcribedOnDevice);
    expect(engine.transcribeCalls, 1);
    expect(api.transcribeCalls, 0);
    expect(api.analyzeCalls, 0);
    expect(rawHttpRequests, 0);
    expect(ledger.jobs, isEmpty);
    final entry = (await journal.loadAll()).single;
    expect(entry.transcript, 'I paused before replying.');
    expect(await vault.exists(entry.localAudioVaultRef!), isTrue);
  });

  test(
    'save audio without a transcript stays playable, exportable and deletable',
    () async {
      final audio = await capturedAudio();
      final original = await audio.readAsBytes();

      final outcome = await coordinator().resolve(
        audio: audio,
        durationSeconds: 7,
        requestChoice: (_) async => PostCaptureDisposition.saveAudioOnly,
        requestRemoteDisclosure: refuse,
        confirmDelete: refuse,
      );

      final entry = outcome.entry!;
      expect(entry.transcript, PostCaptureCopy.audioOnlyTranscript);
      // Playback uses the vault reference exactly as the entry screen does.
      expect(entry.localAudioVaultRef?.isNotEmpty, isTrue);
      expect(
        await vault.readPlaintextBytes(entry.localAudioVaultRef!),
        original,
      );
      expect(await journal.exportJson(), contains(entry.id));

      final deletion = await PrivateDataService(
        journalStore: journal,
        audioVault: vault,
        tempDirProvider: () async => workingDirectory,
      ).deleteEntrySecurely(entry.id);

      expect(deletion.deleted, isTrue);
      expect(deletion.audioFileRemoved, isTrue);
      expect(await journal.loadAll(), isEmpty);
      expect(await vault.exists(entry.localAudioVaultRef!), isFalse);
    },
  );

  test('delete removes the audio only after confirmation', () async {
    final declined = await coordinator().resolve(
      audio: await capturedAudio('first.m4a'),
      durationSeconds: 5,
      requestChoice: (_) async => PostCaptureDisposition.deleteRecording,
      requestRemoteDisclosure: refuse,
      confirmDelete: refuse,
    );

    expect(declined.kind, PostCaptureOutcomeKind.savedAudioOnly);
    expect(declined.audioRetained, isTrue);
    expect(await vaultObjects(), hasLength(1));

    final confirmed = await coordinator().resolve(
      audio: await capturedAudio('second.m4a'),
      durationSeconds: 5,
      requestChoice: (_) async => PostCaptureDisposition.deleteRecording,
      requestRemoteDisclosure: refuse,
      confirmDelete: accept,
    );

    expect(confirmed.kind, PostCaptureOutcomeKind.deleted);
    expect(confirmed.audioRetained, isFalse);
    expect(await vaultObjects(), hasLength(1));
    expect(await journal.loadAll(), hasLength(1));
  });

  test(
    'online transcription requires a current disclosure acceptance',
    () async {
      final audio = await capturedAudio();
      var disclosureRequests = 0;

      final accepted = await coordinator().resolve(
        audio: audio,
        durationSeconds: 11,
        requestChoice: (_) async => PostCaptureDisposition.transcribeOnline,
        requestRemoteDisclosure: () async {
          disclosureRequests++;
          expect(api.transcribeCalls, 0, reason: 'no upload before acceptance');
          await disclosure.acceptCurrent();
          return true;
        },
        confirmDelete: refuse,
      );

      expect(disclosureRequests, 1);
      expect(
        accepted.kind,
        PostCaptureOutcomeKind.queuedForOnlineTranscription,
      );
      expect(api.transcribeCalls, 1);
      final entry = (await journal.loadAll()).single;
      expect(entry.transcript, contains('remote transcript'));
      expect(entry.localAudioVaultRef?.isNotEmpty, isTrue);
    },
  );

  test(
    'queued transcription re-checks withdrawn consent before upload',
    () async {
      final delayed = PostCaptureDispositionCoordinator(
        vault: vault,
        journal: () => journal,
        onDeviceEngine: const _UnavailableOnDeviceEngine(),
        disclosure: disclosure,
        remoteQueue: VaultPersistenceCoordinator(ledger),
        startRemoteQueue: () async {},
        onDeviceSupport: const FixedOnDeviceTranscriptionSupport(false),
        temporaryAudio: temporaryAudio,
      );
      final queued = await delayed.resolve(
        audio: await capturedAudio(),
        durationSeconds: 8,
        requestChoice: (_) async => PostCaptureDisposition.transcribeOnline,
        requestRemoteDisclosure: () async {
          await disclosure.acceptCurrent();
          return true;
        },
        confirmDelete: refuse,
      );
      expect(queued.kind, PostCaptureOutcomeKind.queuedForOnlineTranscription);
      expect(api.transcribeCalls, 0);

      await disclosure.revoke();
      await executor.drain();

      expect(api.transcribeCalls, 0);
      expect((await journal.loadAll()).single.localAudioVaultRef, isNotNull);
    },
  );

  test('a stale disclosure acceptance cannot start a remote request', () async {
    await prefs.writeJsonMap(RemoteTranscriptionDisclosureStore.storageKey, {
      'acceptedVersion': 'stale-version',
    });

    final outcome = await coordinator().resolve(
      audio: await capturedAudio(),
      durationSeconds: 6,
      requestChoice: (_) async => PostCaptureDisposition.transcribeOnline,
      // A UI that reports approval without persisting it must not authorize
      // the upload.
      requestRemoteDisclosure: accept,
      confirmDelete: refuse,
    );

    expect(outcome.kind, PostCaptureOutcomeKind.savedAudioOnly);
    expect(api.transcribeCalls, 0);
    expect(ledger.jobs, isEmpty);
  });

  test('failed transcription never destroys the audio', () async {
    final audio = await capturedAudio();
    final original = await audio.readAsBytes();
    final engine = _FakeOnDeviceEngine(
      failure: const OnDeviceTranscriptionUnavailable('model_not_ready'),
    );

    final outcome = await coordinator(onDeviceEngine: engine).resolve(
      audio: audio,
      durationSeconds: 8,
      requestChoice: (_) async => PostCaptureDisposition.transcribeOnDevice,
      requestRemoteDisclosure: refuse,
      confirmDelete: refuse,
    );

    expect(outcome.kind, PostCaptureOutcomeKind.savedAudioOnly);
    expect(outcome.audioRetained, isTrue);
    expect(outcome.note, PostCaptureCopy.onDeviceFailedNote);
    final entry = (await journal.loadAll()).single;
    expect(await vault.readPlaintextBytes(entry.localAudioVaultRef!), original);

    // The saved audio remains available for a later online attempt.
    await disclosure.acceptCurrent();
    final retried = await coordinator().transcribeOnline(
      ProtectedCapture(
        entryId: entry.id,
        vaultReference: entry.localAudioVaultRef!,
        durationSeconds: 8,
      ),
      requestDisclosure: refuse,
    );
    expect(retried.audioRetained, isTrue);
  });

  test(
    'a background interruption leaves exactly one protected recoverable copy',
    () async {
      final audio = await capturedAudio();

      // Backgrounded while the choice is on screen: nothing answers it.
      final capture = await coordinator().protect(
        audio: audio,
        durationSeconds: 10,
      );

      expect(await vaultObjects(), hasLength(1));
      expect(await audio.exists(), isFalse);
      expect(
        await temporaryAudio.list(ownerId: 'voice-capture'),
        isEmpty,
        reason: 'plaintext must not survive alongside the vault object',
      );
      final entry = (await journal.loadAll()).single;
      expect(entry.localAudioVaultRef, capture.vaultReference);
      expect(await vault.exists(capture.vaultReference), isTrue);
    },
  );

  test('recovered audio goes through the same choice flow', () async {
    final recovered = await temporaryAudio.create(
      ownerId: 'archive:local',
      extension: 'm4a',
    );
    final bytes = List<int>.generate(4096, (index) => index % 241)
      ..setRange(4, 8, 'ftyp'.codeUnits);
    await recovered.writeAsBytes(bytes, flush: true);
    await temporaryAudio.markRecoverable(
      file: recovered,
      ownerId: 'archive:local',
    );

    PostCaptureChoiceOptions? presented;
    var vaultedWhenAsked = 0;
    final recoveryCoordinator = PostCaptureDispositionCoordinator(
      vault: vault,
      journal: () => journal,
      onDeviceEngine: _FakeOnDeviceEngine(),
      disclosure: disclosure,
      remoteQueue: VaultPersistenceCoordinator(ledger),
      startRemoteQueue: () async {
        await executor.drain();
      },
      onDeviceSupport: const FixedOnDeviceTranscriptionSupport(true),
      temporaryAudio: temporaryAudio,
      temporaryAudioOwnerId: 'archive:local',
    );

    final outcome = await recoveryCoordinator.resolve(
      audio: recovered,
      durationSeconds: 20,
      requestChoice: (options) async {
        presented = options;
        vaultedWhenAsked = (await vaultObjects()).length;
        return PostCaptureDisposition.saveAudioOnly;
      },
      requestRemoteDisclosure: refuse,
      confirmDelete: refuse,
    );

    expect(vaultedWhenAsked, 1);
    expect(presented!.available, [
      PostCaptureDisposition.transcribeOnDevice,
      PostCaptureDisposition.transcribeOnline,
      PostCaptureDisposition.saveAudioOnly,
      PostCaptureDisposition.deleteRecording,
    ]);
    expect(outcome.audioRetained, isTrue);
    expect(
      await temporaryAudio.list(ownerId: 'archive:local'),
      isEmpty,
      reason: 'the recovered plaintext is consumed by the vault',
    );
    final entry = (await journal.loadAll()).single;
    expect(await vault.readPlaintextBytes(entry.localAudioVaultRef!), bytes);
  });

  test('on-device is offered and recommended only where it works', () async {
    final ready = await coordinator().options();
    expect(ready.offersOnDeviceTranscription, isTrue);
    expect(ready.recommended, PostCaptureDisposition.transcribeOnDevice);

    final onlineOnly = await coordinator(onlineOnly: true).options();
    expect(onlineOnly.offersOnDeviceTranscription, isTrue);
    expect(onlineOnly.recommended, PostCaptureDisposition.transcribeOnline);

    final unsupported = await coordinator(onDeviceSupported: false).options();
    expect(unsupported.offersOnDeviceTranscription, isFalse);
    expect(unsupported.available, [
      PostCaptureDisposition.transcribeOnline,
      PostCaptureDisposition.saveAudioOnly,
      PostCaptureDisposition.deleteRecording,
    ]);
    expect(unsupported.recommended, PostCaptureDisposition.transcribeOnline);

    final modelMissing = await coordinator(
      onDeviceEngine: _FakeOnDeviceEngine(ready: false),
    ).options();
    expect(modelMissing.offersOnDeviceTranscription, isFalse);
    expect(modelMissing.recommended, PostCaptureDisposition.transcribeOnline);
  });
}

final class _FakeOnDeviceEngine implements OnDeviceTranscriptionEngine {
  _FakeOnDeviceEngine({
    this.ready = true,
    this.transcript = 'A local transcript that never left the device.',
    this.failure,
  });

  final bool ready;
  final String transcript;
  final Object? failure;
  int transcribeCalls = 0;

  @override
  Future<bool> isReady() async => ready;

  @override
  Future<void> prepare() async {}

  @override
  Future<String> transcribe(File audioFile) async {
    transcribeCalls++;
    expect(await audioFile.exists(), isTrue);
    final error = failure;
    if (error != null) throw error;
    return transcript;
  }
}

final class _UnavailableOnDeviceEngine implements OnDeviceTranscriptionEngine {
  const _UnavailableOnDeviceEngine();

  @override
  Future<bool> isReady() async => false;

  @override
  Future<void> prepare() async {}

  @override
  Future<String> transcribe(File audioFile) async =>
      throw const OnDeviceTranscriptionUnavailable('not_ready');
}

final class _SpyVoiceCaptureApi extends VoiceCaptureApiClient {
  _SpyVoiceCaptureApi(super.transport);

  static const transcript = 'A remote transcript produced after acceptance.';

  int transcribeCalls = 0;
  int analyzeCalls = 0;

  @override
  Future<String> postTranscribe({
    required File audioFile,
    required int durationSeconds,
    required String captureToken,
    String? idempotencyKey,
  }) async {
    transcribeCalls++;
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
    analyzeCalls++;
    return const Reflection(
      mood: 'steady',
      emotionalIntensity: 2,
      recurringThemes: ['pausing'],
      exactLanguagePattern: 'a quiet pause',
      concreteObservation: 'A quiet pause may have supported a careful choice.',
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
