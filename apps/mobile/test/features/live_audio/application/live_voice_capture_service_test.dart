import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/capture_api_client.dart';
import 'package:archiveme_mobile/data/repositories/capture_repository.dart';
import 'package:archiveme_mobile/features/live_audio/application/live_audio_session_coordinator.dart';
import 'package:archiveme_mobile/features/live_audio/application/live_voice_capture_service.dart';
import 'package:archiveme_mobile/features/live_audio/domain/models/live_audio_session_config.dart';
import 'package:archiveme_mobile/features/live_audio/domain/models/live_voice_error_state.dart';
import 'package:archiveme_mobile/features/live_audio/domain/models/live_voice_session_fault.dart';
import 'package:archiveme_mobile/features/live_audio/domain/models/offline_vault_manifest.dart';
import 'package:archiveme_mobile/features/live_audio/domain/services/live_pcm16_capture_source.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/isolate_audio_pipeline.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/live_audio_session_api_client.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/live_audio_socket_connection.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/live_audio_websocket_client.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/local_audio_vault.dart';
import 'package:archiveme_mobile/features/live_audio/live_audio_constants.dart';
import 'package:archiveme_mobile/features/live_audio/presentation/controllers/live_audio_session_controller.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/models/attest_result.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/security/api_usage_guard.dart';
import 'package:archiveme_mobile/services/capture_attest_service.dart';
import 'package:archiveme_mobile/services/capture_pipeline_service.dart';
import 'package:archiveme_mobile/storage/capture_token_cache.dart';
import 'package:archiveme_mobile/storage/device_id.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:archiveme_mobile/storage/private_data_encryption_key_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_path_provider.dart';
import '../../../helpers/silent_playback_service.dart';
import '../live_audio_consent_test_gate.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory pathProviderRoot;

  setUp(() {
    pathProviderRoot = Directory.systemTemp.createTempSync('vm_capture_path_');
    installFakePathProvider(root: pathProviderRoot);
  });

  tearDown(() {
    if (pathProviderRoot.existsSync()) {
      pathProviderRoot.deleteSync(recursive: true);
    }
  });

  group('LiveVoiceCaptureService + IsolateAudioPipeline Bridge Tests', () {
    late StreamController<dynamic> sinkController;
    late _CountingSessionApi sessionApi;
    late LiveVoiceCaptureService captureService;
    late _RecordingPipeline journalPipeline;
    late File journalFile;
    late List<List<int>> pcmSent;

    setUp(() {
      ApiUsageGuard.resetForTest(
        replacement: ApiUsageGuard(maxAttemptsPerScope: 5),
      );
      pcmSent = <List<int>>[];
      journalFile = File(
        '${Directory.systemTemp.path}/live_voice_bridge_${DateTime.now().microsecondsSinceEpoch}.json',
      );
      sinkController = StreamController<dynamic>();
      sessionApi = _CountingSessionApi();
      journalPipeline = _RecordingPipeline(
        captureRepository: CaptureRepository(
          api: _FakeCaptureApiClient(),
          requestScope: NetworkRequestScope(),
        ),
        attest: _attestForTest(),
        journalStore: JournalStore(file: journalFile),
        consentStore: RemoteProcessingConsentStore(_prefsFor(journalFile)),
      );

      captureService = _buildBridgeCaptureService(
        sessionApi: sessionApi,
        sinkController: sinkController,
        journalPipeline: journalPipeline,
        pcmSent: pcmSent,
      );
    });

    tearDown(() async {
      await captureService.terminateActiveSession();
      await captureService.dispose();
      await sinkController.close();
      if (journalFile.existsSync()) {
        await journalFile.delete();
      }
      ApiUsageGuard.resetForTest();
    });

    Future<void> startConnected({
      int hardwareSampleRate = liveInputSampleRateHz,
      bool? enableIsolatePipeline,
    }) async {
      final startFuture = captureService.start(
        hardwareSampleRate: hardwareSampleRate,
        enableIsolatePipeline: enableIsolatePipeline,
      );
      await Future<void>.delayed(Duration.zero);
      sinkController.add(jsonEncode({'setupComplete': {}}));
      await startFuture;
    }

    test(
      'cycles gracefully through pipeline initialization to active state',
      () async {
        expect(captureService.captureState, LiveVoiceCaptureState.idle);
        expect(captureService.isPipelineActive, isFalse);

        await startConnected(hardwareSampleRate: 48000);

        expect(captureService.captureState, LiveVoiceCaptureState.active);
        expect(captureService.isRecording, isTrue);
        expect(captureService.isPipelineActive, isTrue);
        expect(captureService.hardwareSampleRate, 48000);
      },
    );

    test('ignores raw hardware chunks while paused by audio focus', () async {
      await startConnected(hardwareSampleRate: 48000);
      final beforeCount = pcmSent.length;

      await captureService.pauseLiveCapture();
      expect(captureService.captureState, LiveVoiceCaptureState.paused);

      captureService.handleRawHardwareChunk(
        Int16List.fromList(List<int>.generate(320, (_) => 5)),
      );
      await pumpEventQueue(times: 5);

      expect(pcmSent.length, beforeCount);
      expect(captureService.isPipelineActive, isTrue);
    });

    test(
      'safely routes raw hardware chunks through isolate processing',
      () async {
        await startConnected(
          enableIsolatePipeline: true,
        );
        expect(captureService.isRecording, isTrue);
        expect(captureService.isPipelineActive, isTrue);

        final rawHardwareBlock = Int16List.fromList(
          List<int>.generate(320, (_) => 5),
        );

        expect(
          () => captureService.handleRawHardwareChunk(rawHardwareBlock),
          returnsNormally,
        );

        await pumpEventQueue(times: 5);

        expect(pcmSent, hasLength(1));
        expect(pcmSent.first, hasLength(640));
      },
    );

    test(
      'handles high-throughput raw buffers without main-thread faults',
      () async {
        await startConnected(hardwareSampleRate: 48000);

        final stressBlock = Int16List.fromList(
          List<int>.generate(320 * 4, (i) => i & 0x7fff),
        );

        for (var i = 0; i < 50; i++) {
          captureService.handleRawHardwareChunk(stressBlock);
        }

        await Future<void>.delayed(const Duration(milliseconds: 150));

        expect(captureService.isRecording, isTrue);
        expect(captureService.isPipelineActive, isTrue);
        expect(captureService.captureState, LiveVoiceCaptureState.active);
        expect(pcmSent, isNotEmpty);
        expect(pcmSent.every((chunk) => chunk.length == 640), isTrue);
      },
    );

    test(
      'executes clean pipeline teardown on explicit session termination',
      () async {
        await startConnected(hardwareSampleRate: 48000);
        expect(captureService.captureState, LiveVoiceCaptureState.active);
        expect(captureService.isPipelineActive, isTrue);

        await captureService.terminateActiveSession();

        expect(captureService.captureState, LiveVoiceCaptureState.idle);
        expect(captureService.isActive, isFalse);
        expect(captureService.isPipelineActive, isFalse);
        expect(journalPipeline.saveCalls, 0);
      },
    );

    test(
      'networkTimeout vaults processed PCM instead of streaming to websocket',
      () async {
        final vaultDirectory = await Directory.systemTemp.createTemp(
          'capture_vault_',
        );
        final vault = LocalAudioVault(
          keyStore: InMemoryPrivateDataEncryptionKeyStore(),
          resolveCacheDirectory: () async => vaultDirectory,
        );

        final bridgeService = _buildBridgeCaptureService(
          sessionApi: sessionApi,
          sinkController: sinkController,
          journalPipeline: journalPipeline,
          pcmSent: pcmSent,
          offlineAudioVault: vault,
        );

        try {
          final startFuture = bridgeService.start(hardwareSampleRate: 48000);
          await Future<void>.delayed(Duration.zero);
          sinkController.add(jsonEncode({'setupComplete': {}}));
          await startFuture;

          final sentBeforeFault = pcmSent.length;

          await bridgeService.handleSessionFailure(
            LiveVoiceErrorState.networkTimeout,
            reason: 'unrecoverable_timeout',
          );

          expect(bridgeService.isOfflineVaultActive, isTrue);
          expect(bridgeService.hasError, isTrue);
          expect(bridgeService.captureState, LiveVoiceCaptureState.active);
          expect(bridgeService.isPausedByAudioFocus, isFalse);

          bridgeService.handleRawHardwareChunk(
            Int16List.fromList(
              List<int>.generate(1920, (i) => (i % 1000) - 500),
            ),
          );
          await pumpEventQueue(times: 10);

          expect(pcmSent.length, sentBeforeFault);
          expect(bridgeService.vaultedFrameCount, greaterThan(0));
          expect(bridgeService.offlineVaultFile, isNotNull);

          await bridgeService.terminateActiveSession();
          await bridgeService.dispose();
        } finally {
          if (vaultDirectory.existsSync()) {
            await vaultDirectory.delete(recursive: true);
          }
        }
      },
    );
  });

  group('LiveVoiceCaptureService', () {
    late StreamController<dynamic> sinkController;
    late _CountingSessionApi sessionApi;
    late LiveVoiceCaptureService service;
    late _RecordingPipeline pipeline;
    late File journalFile;
    late Directory vaultDirectory;

    setUp(() async {
      ApiUsageGuard.resetForTest(
        replacement: ApiUsageGuard(maxAttemptsPerScope: 5),
      );
      vaultDirectory = await Directory.systemTemp.createTemp(
        'live_voice_vault_',
      );
      journalFile = File(
        '${Directory.systemTemp.path}/live_voice_test_${DateTime.now().microsecondsSinceEpoch}.json',
      );
      sinkController = StreamController<dynamic>();
      sessionApi = _CountingSessionApi();
      pipeline = _RecordingPipeline(
        captureRepository: CaptureRepository(
          api: _FakeCaptureApiClient(),
          requestScope: NetworkRequestScope(),
        ),
        attest: _attestForTest(),
        journalStore: JournalStore(file: journalFile),
        consentStore: RemoteProcessingConsentStore(_prefsFor(journalFile)),
      );

      final vaultKeyStore = InMemoryPrivateDataEncryptionKeyStore();
      await vaultKeyStore.ensureKey();

      service = LiveVoiceCaptureService(
        controller: LiveAudioSessionController(
          LiveAudioSessionCoordinator(
            sessionApi: sessionApi,
            attest: _attestForTest(),
            consentGate: PermittingLiveAudioConsentGate(),
            webSocketClient: LiveAudioWebSocketClient(
              connectionFactory: (_, {headers}) =>
                  _FakeSocketConnection(sinkController),
            ),
            captureSource: _FakeCapture(),
            usageGuard: ApiUsageGuard.shared,
          ),
        ),
        pipeline: pipeline,
        playback: silentPlaybackService(),
        offlineAudioVault: LocalAudioVault(
          keyStore: vaultKeyStore,
          resolveCacheDirectory: () async => vaultDirectory,
        ),
      );
    });

    tearDown(() async {
      await service.dispose();
      await sinkController.close();
      if (journalFile.existsSync()) {
        await journalFile.delete();
      }
      if (vaultDirectory.existsSync()) {
        await vaultDirectory.delete(recursive: true);
      }
      ApiUsageGuard.resetForTest();
    });

    Future<void> startConnected() async {
      final startFuture = service.start();
      await Future<void>.delayed(Duration.zero);
      sinkController.add(jsonEncode({'setupComplete': {}}));
      await startFuture;
    }

    test('stopAndSave persists accumulated transcript', () async {
      await startConnected();
      sinkController.add(
        jsonEncode({
          'serverContent': {
            'inputTranscription': {'text': 'hello live voice'},
          },
        }),
      );
      await Future<void>.delayed(Duration.zero);

      final result = await service.stopAndSave();
      expect(result.entry.transcript, 'hello live voice');
      expect(pipeline.lastTranscript, 'hello live voice');
    });

    test('cancel does not save', () async {
      await startConnected();
      await service.cancel();
      expect(pipeline.saveCalls, 0);
      expect(service.isActive, isFalse);
    });

    test('emits session fault after reconnect failure', () async {
      sessionApi.failReconnectMint = true;
      final faults = <LiveVoiceSessionFault>[];
      final sub = service.sessionFaults.listen(faults.add);

      await startConnected();
      await sinkController.close();

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(faults, hasLength(1));
      expect(faults.first.errorState, LiveVoiceErrorState.networkTimeout);
      expect(faults.first.recoverable, isTrue);
      expect(service.isActive, isTrue);
      expect(service.hasError, isTrue);
      expect(service.isOfflineVaultActive, isTrue);
      expect(service.isPausedByAudioFocus, isFalse);
      expect(service.captureState, LiveVoiceCaptureState.active);

      await sub.cancel();
    });

    test(
      'retrySessionRecovery clears error when proxy session is still streamable',
      () async {
        await startConnected();
        await service.handleSessionFailure(
          LiveVoiceErrorState.networkTimeout,
          reason: 'socket_closed',
        );
        expect(service.hasError, isTrue);
        expect(service.isOfflineVaultActive, isTrue);
        expect(service.isPausedByAudioFocus, isFalse);

        await service.retrySessionRecovery();

        expect(service.hasError, isFalse);
        expect(service.isOfflineVaultActive, isFalse);
        expect(service.isActive, isTrue);
        expect(service.controller.isCapturingMicrophone, isTrue);
      },
    );

    test(
      'pauseLiveCapture and resumeLiveCapture keep session active',
      () async {
        final capture = service.controller;
        await startConnected();
        expect(service.isActive, isTrue);

        await service.pauseLiveCapture();
        expect(service.isPausedByAudioFocus, isTrue);
        expect(service.isActive, isTrue);
        expect(capture.isCapturingMicrophone, isFalse);
        expect(capture.isPausedByAudioFocus, isTrue);

        await service.resumeLiveCapture();
        expect(service.isPausedByAudioFocus, isFalse);
        expect(service.isActive, isTrue);
        expect(capture.isCapturingMicrophone, isTrue);
      },
    );

    test(
      'resumeLiveCaptureIfActive skips when session is not streamable',
      () async {
        await startConnected();
        await service.pauseLiveCapture();
        await service.controller.disconnect();

        await service.resumeLiveCaptureIfActive();
        expect(service.isPausedByAudioFocus, isTrue);
        expect(service.isActive, isTrue);
      },
    );

    test('terminateActiveSession cancels without saving', () async {
      await startConnected();
      await service.terminateActiveSession();
      expect(service.isActive, isFalse);
      expect(service.isPipelineActive, isFalse);
      expect(pipeline.saveCalls, 0);
    });

    test(
      'routes microphone capture through isolate pipeline when enabled',
      () async {
        final capture = _FakeCapture();
        final pcmSent = <List<int>>[];
        service = _buildBridgeCaptureService(
          sessionApi: sessionApi,
          sinkController: sinkController,
          journalPipeline: pipeline,
          pcmSent: pcmSent,
          captureSource: capture,
        );

        final startFuture = service.start(enableIsolatePipeline: true);
        await Future<void>.delayed(Duration.zero);
        sinkController.add(jsonEncode({'setupComplete': {}}));
        await startFuture;

        expect(service.isPipelineActive, isTrue);
        expect(service.captureState, LiveVoiceCaptureState.active);

        capture.emitChunk(List<int>.generate(640, (i) => i % 256));
        await pumpEventQueue(times: 5);

        expect(pcmSent, isNotEmpty);
        expect(pcmSent.first, hasLength(640));
      },
    );

    test(
      'handleRawHardwareChunk bypasses capture when pipeline is active',
      () async {
        final pcmSent = <List<int>>[];
        service = _buildBridgeCaptureService(
          sessionApi: sessionApi,
          sinkController: sinkController,
          journalPipeline: pipeline,
          pcmSent: pcmSent,
        );

        final startFuture = service.start(hardwareSampleRate: 48000);
        await Future<void>.delayed(Duration.zero);
        sinkController.add(jsonEncode({'setupComplete': {}}));
        await startFuture;

        service.handleRawHardwareChunk(
          Int16List.fromList(List<int>.generate(1920, (i) => (i % 1000) - 500)),
        );
        await pumpEventQueue(times: 5);

        expect(pcmSent, hasLength(2));
        expect(pcmSent.every((chunk) => chunk.length == 640), isTrue);
      },
    );
  });
}

LiveVoiceCaptureService _buildBridgeCaptureService({
  required _CountingSessionApi sessionApi,
  required StreamController<dynamic> sinkController,
  required _RecordingPipeline journalPipeline,
  required List<List<int>> pcmSent,
  LivePcm16CaptureSource? captureSource,
  LocalAudioVault? offlineAudioVault,
}) {
  return LiveVoiceCaptureService(
    controller: LiveAudioSessionController(
      LiveAudioSessionCoordinator(
        sessionApi: sessionApi,
        attest: _attestForTest(),
        consentGate: PermittingLiveAudioConsentGate(),
        webSocketClient: _InstrumentedWebSocketClient(
          socketEvents: sinkController,
          onPcmSent: pcmSent.add,
        ),
        captureSource: captureSource ?? _FakeCapture(),
        usageGuard: ApiUsageGuard.shared,
      ),
    ),
    pipeline: journalPipeline,
    playback: silentPlaybackService(),
    useIsolateAudioPipeline: true,
    pipelineFactory: _inlineIsolatePipeline,
    offlineAudioVault: offlineAudioVault,
  );
}

class _CountingSessionApi implements LiveAudioSessionApiClient {
  int mintCalls = 0;
  bool failReconnectMint = false;

  @override
  Future<LiveAudioSessionConfig> mintSession({
    required String captureToken,
    String? idempotencyKey,
    String? systemInstruction,
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
    required super.captureRepository,
    required super.attest,
    required super.journalStore,
    required super.consentStore,
  });

  int saveCalls = 0;
  String? lastTranscript;

  @override
  Future<CapturePipelineResult> saveLiveVoiceTranscript({
    required String transcript,
    required int durationSeconds,
  }) async {
    saveCalls++;
    lastTranscript = transcript;
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

class _FakeCapture implements LivePcm16CaptureSource {
  void Function(List<int> chunk)? _onChunk;

  @override
  bool isCapturing = false;

  @override
  Future<void> start({required void Function(List<int> chunk) onChunk}) async {
    isCapturing = true;
    _onChunk = onChunk;
  }

  void emitChunk(List<int> chunk) {
    _onChunk?.call(chunk);
  }

  @override
  Future<void> stop() async {
    isCapturing = false;
    _onChunk = null;
  }

  @override
  void dispose() {}
}

class _FakeCaptureApiClient implements CaptureApiClient {
  @override
  Future<ApiResult<AttestResult>> postCaptureAttest(
    String deviceId, {
    NetworkCancelToken? cancelToken,
  }) async {
    return ApiSuccess(
      AttestResult.capture(token: 'capture-token', expiresInSeconds: 3600),
    );
  }

  @override
  Future<ApiResult<RawModelResponse>> postAnalyzeRaw({
    required String transcript,
    required String captureToken,
    List<Map<String, dynamic>> priorEvidence = const [],
    String? idempotencyKey,
    NetworkCancelToken? cancelToken,
  }) async {
    throw UnimplementedError('postAnalyzeRaw');
  }

  @override
  Future<ApiResult<String>> postTranscribe({
    required File audioFile,
    required int durationSeconds,
    required String captureToken,
    String? idempotencyKey,
    NetworkCancelToken? cancelToken,
  }) async {
    throw UnimplementedError('postTranscribe');
  }

  @override
  Future<ApiResult<VaultRecoveryServerResult>> postVaultRecovery({
    required File vaultFile,
    required String sessionId,
    required int durationSeconds,
    required String captureToken,
    required String idempotencyKey,
    List<int>? recoverySecretKeyBytes,
    NetworkCancelToken? cancelToken,
  }) async {
    throw UnimplementedError('postVaultRecovery');
  }
}

CaptureAttestService _attestForTest() {
  return CaptureAttestService(
    captureRepository: CaptureRepository(
      api: _FakeCaptureApiClient(),
      requestScope: NetworkRequestScope(),
    ),
    deviceIds: _FakeDeviceIdStore(),
    tokenCache: CaptureTokenCache()
      ..setToken('capture-token', expiresInSeconds: 3600),
  );
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