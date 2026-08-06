import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/features/live_audio/application/live_audio_session_coordinator.dart';
import 'package:voicememory_mobile/features/live_audio/application/live_voice_capture_service.dart';
import 'package:voicememory_mobile/features/live_audio/domain/models/live_audio_session_config.dart';
import 'package:voicememory_mobile/features/live_audio/domain/models/live_voice_error_state.dart';
import 'package:voicememory_mobile/features/live_audio/domain/models/live_voice_session_fault.dart';
import 'package:voicememory_mobile/features/live_audio/domain/services/live_pcm16_capture_source.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/isolate_audio_pipeline.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/local_audio_vault.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/live_audio_session_api_client.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/live_audio_socket_connection.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/live_audio_websocket_client.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/live_pcm24_playback_engine.dart';
import 'package:voicememory_mobile/features/live_audio/live_audio_constants.dart';
import 'package:voicememory_mobile/features/live_audio/presentation/controllers/live_audio_session_controller.dart';
import 'package:voicememory_mobile/features/live_audio/presentation/controllers/throttled_telemetry_view_model.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/security/api_usage_guard.dart';
import 'package:voicememory_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:voicememory_mobile/services/capture_attest_service.dart';
import 'package:voicememory_mobile/services/capture_pipeline_service.dart';
import 'package:voicememory_mobile/storage/capture_token_cache.dart';
import 'package:voicememory_mobile/storage/device_id.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

IsolateAudioPipeline _inlineIsolatePipeline(PipelineConfig config) {
  return IsolateAudioPipeline(
    config,
    spawnIsolate: (entryPoint, mainSendPort) async {
      entryPoint(mainSendPort);
      return null;
    },
  );
}

void main() {
  group('ArchiveMe Complete End-to-End Resiliency Suite', () {
    late Directory vaultDirectory;
    late InMemoryPrivateDataEncryptionKeyStore vaultKeyStore;

    setUp(() async {
      ApiUsageGuard.resetForTest(
        replacement: ApiUsageGuard(maxAttemptsPerScope: 5),
      );
      vaultKeyStore = InMemoryPrivateDataEncryptionKeyStore();
      await vaultKeyStore.ensureKey();
      vaultDirectory = await Directory.systemTemp.createTemp(
        'resilient_pipeline_vault_',
      );
    });

    tearDown(() async {
      ApiUsageGuard.resetForTest();
      if (vaultDirectory.existsSync()) {
        await vaultDirectory.delete(recursive: true);
      }
    });

    test(
      'Should seamlessly pivot to local disk vaulting when pipeline encounters network dropout',
      () async {
        final vault = LocalAudioVault(
          keyStore: vaultKeyStore,
          resolveCacheDirectory: () async => vaultDirectory,
        );
        final dummyFrame = Int16List.fromList(
          List.generate(320, (i) => i % 100),
        );

        await vault.initializeVault('session_fallback_test');
        expect(vault.isActive, isTrue);

        vault.appendFrame(dummyFrame);

        final savedFile = await vault.closeVault();
        expect(savedFile, isNotNull);
        expect(await savedFile!.exists(), isTrue);
        expect(vault.frameCount, 1);
        expect(savedFile.path.endsWith('.vault.enc'), isTrue);
      },
    );

    test(
      'capture service routes processed PCM to vault after unrecoverable networkTimeout',
      () async {
        final pcmSent = <List<int>>[];
        final harness = _ResilientPipelineHarness(
          vaultDirectory: vaultDirectory,
          vaultKeyStore: vaultKeyStore,
          pcmSent: pcmSent,
        );

        try {
          await harness.startConnected(hardwareSampleRate: 48000);
          final sentBeforeFault = pcmSent.length;

          await harness.captureService.handleSessionFailure(
            LiveVoiceErrorState.networkTimeout,
            reason: 'unrecoverable_timeout',
          );

          expect(harness.captureService.isOfflineVaultActive, isTrue);
          expect(harness.captureService.hasError, isTrue);
          expect(
            harness.captureService.captureState,
            LiveVoiceCaptureState.active,
          );

          harness.captureService.handleRawHardwareChunk(
            Int16List.fromList(
              List<int>.generate(1920, (i) => (i % 1000) - 500),
            ),
          );
          await pumpEventQueue(times: 10);

          expect(pcmSent.length, sentBeforeFault);
          expect(harness.captureService.vaultedFrameCount, greaterThan(0));
          expect(harness.captureService.localVault.isActive, isTrue);
        } finally {
          await harness.dispose();
        }
      },
    );

    test(
      'socket reconnect exhaustion deploys emergency vault instead of dropping audio',
      () async {
        final pcmSent = <List<int>>[];
        final harness = _ResilientPipelineHarness(
          vaultDirectory: vaultDirectory,
          vaultKeyStore: vaultKeyStore,
          pcmSent: pcmSent,
          failReconnectMint: true,
        );
        final faults = <LiveVoiceSessionFault>[];
        final faultSub = harness.captureService.sessionFaults.listen(
          faults.add,
        );

        try {
          await harness.startConnected(hardwareSampleRate: 48000);
          await harness.sinkController.close();
          await Future<void>.delayed(const Duration(milliseconds: 100));

          expect(faults, hasLength(1));
          expect(faults.first.errorState, LiveVoiceErrorState.networkTimeout);
          expect(harness.captureService.isOfflineVaultActive, isTrue);
          expect(
            harness.captureService.captureState,
            LiveVoiceCaptureState.active,
          );

          final sentBeforeFault = pcmSent.length;
          harness.captureService.handleIncomingPipelineFrame(
            Int16List.fromList(List<int>.generate(320, (i) => i & 0xff)),
          );
          await pumpEventQueue(times: 5);

          expect(pcmSent.length, sentBeforeFault);
          expect(harness.captureService.vaultedFrameCount, greaterThan(0));
        } finally {
          await faultSub.cancel();
          await harness.dispose();
        }
      },
    );

    test(
      'throttled telemetry stays bounded while vaulting continues under network failure',
      () async {
        final harness = _ResilientPipelineHarness(
          vaultDirectory: vaultDirectory,
          vaultKeyStore: vaultKeyStore,
          pcmSent: <List<int>>[],
        );
        final telemetry = ThrottledTelemetryViewModel(
          captureService: harness.captureService,
          refreshInterval: const Duration(milliseconds: 100),
        );
        var notifyCount = 0;
        telemetry.addListener(() => notifyCount++);

        try {
          await harness.startConnected(hardwareSampleRate: 48000);
          await harness.captureService.handleSessionFailure(
            LiveVoiceErrorState.networkTimeout,
            reason: 'network_dropout',
          );

          expect(telemetry.engineState, LiveVoiceCaptureState.active);

          for (var i = 0; i < 40; i++) {
            harness.captureService.handleIncomingPipelineFrame(
              Int16List.fromList(
                List<int>.generate(320, (j) => (i + j) & 0xff),
              ),
            );
          }

          await Future<void>.delayed(const Duration(milliseconds: 20));
          final immediateCount = notifyCount;

          await Future<void>.delayed(const Duration(milliseconds: 120));
          final afterWindowCount = notifyCount;

          expect(immediateCount, lessThanOrEqualTo(3));
          expect(afterWindowCount, lessThan(15));
          expect(harness.captureService.isOfflineVaultActive, isTrue);
          expect(harness.captureService.vaultedFrameCount, greaterThan(0));
          expect(telemetry.engineState, LiveVoiceCaptureState.active);
        } finally {
          telemetry.dispose();
          await harness.dispose();
        }
      },
    );
  });
}

class _ResilientPipelineHarness {
  _ResilientPipelineHarness({
    required this.vaultDirectory,
    required this.vaultKeyStore,
    required List<List<int>> pcmSent,
    this.failReconnectMint = false,
  }) : sinkController = StreamController<dynamic>(),
       sessionApi = _CountingSessionApi(failReconnectMint: failReconnectMint) {
    final journalPath =
        '${Directory.systemTemp.path}/resilient_pipeline_${DateTime.now().microsecondsSinceEpoch}.json';
    journalFile = File(journalPath);
    journalPipeline = _RecordingPipeline(
      api: _FakeApiClientWithAttest(),
      attest: CaptureAttestService(
        api: _FakeApiClientWithAttest(),
        deviceIds: _FakeDeviceIdStore(),
        tokenCache: CaptureTokenCache()
          ..setToken('capture-token', expiresInSeconds: 3600),
      ),
      journalStore: JournalStore(file: journalFile),
      consentStore: RemoteProcessingConsentStore(_prefsFor(journalFile)),
    );
    captureService = LiveVoiceCaptureService(
      controller: LiveAudioSessionController(
        LiveAudioSessionCoordinator(
          sessionApi: sessionApi,
          attest: CaptureAttestService(
            api: _FakeApiClientWithAttest(),
            deviceIds: _FakeDeviceIdStore(),
            tokenCache: CaptureTokenCache()
              ..setToken('capture-token', expiresInSeconds: 3600),
          ),
          webSocketClient: _InstrumentedWebSocketClient(
            socketEvents: sinkController,
            onPcmSent: pcmSent.add,
          ),
          captureSource: _FakeCapture(),
          usageGuard: ApiUsageGuard.shared,
        ),
      ),
      pipeline: journalPipeline,
      playback: _SilentPlayback(),
      useIsolateAudioPipeline: true,
      pipelineFactory: _inlineIsolatePipeline,
      maxReconnectAttempts: 1,
      offlineAudioVault: LocalAudioVault(
        keyStore: vaultKeyStore,
        resolveCacheDirectory: () async => vaultDirectory,
      ),
    );
  }

  final Directory vaultDirectory;
  final InMemoryPrivateDataEncryptionKeyStore vaultKeyStore;
  final bool failReconnectMint;
  final StreamController<dynamic> sinkController;
  late final File journalFile;
  final _CountingSessionApi sessionApi;
  late final _RecordingPipeline journalPipeline;
  late final LiveVoiceCaptureService captureService;

  Future<void> startConnected({
    int hardwareSampleRate = liveInputSampleRateHz,
  }) async {
    final startFuture = captureService.start(
      hardwareSampleRate: hardwareSampleRate,
      enableIsolatePipeline: true,
    );
    await Future<void>.delayed(Duration.zero);
    sinkController.add(jsonEncode({'setupComplete': {}}));
    await startFuture;
  }

  Future<void> dispose() async {
    await captureService.terminateActiveSession();
    await captureService.dispose();
    await sinkController.close();
    if (journalFile.existsSync()) {
      await journalFile.delete();
    }
  }
}

class _CountingSessionApi implements LiveAudioSessionApiClient {
  _CountingSessionApi({this.failReconnectMint = false});

  final bool failReconnectMint;
  var mintCalls = 0;

  @override
  Future<LiveAudioSessionConfig> mintSession({
    required String captureToken,
    String? idempotencyKey,
  }) async {
    mintCalls++;
    if (failReconnectMint && mintCalls > 1) {
      throw StateError('mint blocked for reconnect test');
    }
    return LiveAudioSessionConfig(
      sessionId: 'session_$mintCalls',
      sessionToken: 'token_$mintCalls',
      proxyWebSocketUrl: 'wss://example.test/api/live-audio/ws',
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      model: 'gemini-2.5-flash-native-audio-preview-12-2025',
      inputAudioMimeType: liveInputAudioMime,
      outputAudioMimeType: liveOutputAudioMime,
    );
  }
}

class _RecordingPipeline extends CapturePipelineService {
  _RecordingPipeline({
    required super.api,
    required super.attest,
    required super.journalStore,
    required super.consentStore,
  });

  @override
  Future<CapturePipelineResult> saveLiveVoiceTranscript({
    required String transcript,
    required int durationSeconds,
    void Function(PipelineStage stage)? onStage,
  }) async {
    onStage?.call(PipelineStage.done);
    return CapturePipelineResult(
      entry: JournalEntry(
        id: 'entry_test',
        createdAt: DateTime.now(),
        transcript: transcript,
        durationSeconds: durationSeconds,
        reflection: const Reflection(
          mood: 'neutral',
          emotionalIntensity: 1,
          recurringThemes: [],
          exactLanguagePattern: 'test',
          concreteObservation: 'test',
          repeatedSignal: 'test',
        ),
        captureContextTag: 'live_voice_capture',
      ),
      localSaved: true,
      syncSucceeded: false,
      analysisSucceeded: true,
    );
  }
}

class _SilentPlayback extends LivePcm24PlaybackEngine {
  @override
  Future<void> prepare() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

class _InstrumentedWebSocketClient extends LiveAudioWebSocketClient {
  _InstrumentedWebSocketClient({
    required StreamController<dynamic> socketEvents,
    this.onPcmSent,
  }) : super(
         connectionFactory: (_, {headers}) =>
             _FakeSocketConnection(socketEvents),
       );

  final void Function(List<int> chunk)? onPcmSent;

  @override
  void sendPcm16kChunk(List<int> pcm16kBytes) {
    onPcmSent?.call(pcm16kBytes);
    super.sendPcm16kChunk(pcm16kBytes);
  }
}

class _FakeSocketConnection implements LiveAudioSocketConnection {
  _FakeSocketConnection(this._events);

  final StreamController<dynamic> _events;

  @override
  Stream<dynamic> get stream => _events.stream;

  @override
  Sink<dynamic> get sink => _events.sink;

  @override
  Future<void> get ready => Future.value();

  @override
  Future<void> close([int? code, String? reason]) async {}
}

class _FakeCapture implements LivePcm16CaptureSource {
  @override
  bool isCapturing = false;

  @override
  Future<void> start({required void Function(List<int> chunk) onChunk}) async {
    isCapturing = true;
  }

  @override
  Future<void> stop() async {
    isCapturing = false;
  }

  @override
  void dispose() {}
}

class _FakeApiClientWithAttest extends ApiClient {
  _FakeApiClientWithAttest() : super(baseUrl: 'http://test.invalid');

  @override
  Future<AttestResult> postCaptureAttest(String deviceId) async {
    return AttestResult.capture(token: 'capture-token', expiresInSeconds: 3600);
  }
}

class _FakeDeviceIdStore extends DeviceIdStore {
  @override
  Future<String> getOrCreate() async => '00000000-0000-4000-8000-000000000001';
}

MobilePrefsStore _prefsFor(File journalFile) {
  final prefsFile = File('${journalFile.path}.prefs.json');
  if (!prefsFile.existsSync()) {
    prefsFile.writeAsStringSync('{}');
  }
  return MobilePrefsStore(file: prefsFile);
}
