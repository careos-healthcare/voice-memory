import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:archiveme_mobile/audio/hardware_audio_config.dart';
import 'package:archiveme_mobile/audio/microphone_permission_manager.dart';
import 'package:archiveme_mobile/audio/record_capture_events.dart';
import 'package:archiveme_mobile/audio/recording_path_resolver.dart';
import 'package:archiveme_mobile/audio/recording_types.dart';
import 'package:archiveme_mobile/audio/silence_retry_policy.dart';
import 'package:archiveme_mobile/core/di/hardware_audio_providers.dart';
import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/capture/vad/vad_models.dart';
import 'package:archiveme_mobile/features/capture/vad/vad_segmented_recording_coordinator.dart';
import 'package:archiveme_mobile/core/di/app_provider_container.dart';
import 'package:archiveme_mobile/features/voice_capture/audio/audio_capture_diagnostics.dart';
import 'package:archiveme_mobile/features/voice_capture/audio/audio_diag_log.dart';
import 'package:archiveme_mobile/features/voice_capture/audio/audio_level_monitor.dart';
import 'package:archiveme_mobile/features/voice_capture/audio/ios_audio_session.dart';
import 'package:archiveme_mobile/features/voice_capture/microphone_permission_gateway.dart';
import 'package:archiveme_mobile/services/record_pipeline_log.dart';
import 'package:archiveme_mobile/storage/app_storage_paths.dart';
import 'package:archiveme_mobile/widgets/record/recording_waveform_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

export 'microphone_permission_manager.dart' show MicPermissionResolution;
export 'recording_types.dart';

void _recordLog(String message) => AudioDiagLog.recordingMessage(message);

/// Injectable configuration for [recordingServiceProvider].
class RecordingServiceConfig {
  const RecordingServiceConfig({
    this.testMode = false,
    this.recorder,
    this.permissionGateway,
    this.permissionManager,
    this.pathResolver,
    this.hardwareAudioConfig,
    this.silenceRetryPolicy,
    this.hasRecorderOverride,
  });

  final bool testMode;
  final AudioRecorder? recorder;
  final MicrophonePermissionGateway? permissionGateway;
  final MicrophonePermissionManager? permissionManager;
  final RecordingPathResolver? pathResolver;
  final HardwareAudioConfig? hardwareAudioConfig;
  final SilenceRetryPolicy? silenceRetryPolicy;
  final bool? hasRecorderOverride;
}

final recordingServiceConfigProvider = Provider<RecordingServiceConfig>(
  (ref) => const RecordingServiceConfig(),
);

/// Shared Riverpod container for capture — set by [RecordingService.create] or AppServices.
ProviderContainer get recordingProviderContainer => appProviderContainer;

void bindRecordingProviderContainer(ProviderContainer container) {
  bindAppProviderContainer(container);
}

/// Cross-platform microphone capture via the `record` package.
class RecordingService extends Notifier<RecordingState> {
  static RecordingService create({
    bool testMode = false,
    AudioRecorder? recorder,
    MicrophonePermissionGateway? permissionGateway,
    MicrophonePermissionManager? permissionManager,
    RecordingPathResolver? pathResolver,
    HardwareAudioConfig? hardwareAudioConfig,
    SilenceRetryPolicy? silenceRetryPolicy,
    bool? hasRecorderOverride,
  }) {
    final container = createAppChildProviderContainer(
      overrides: [
        if (hardwareAudioConfig != null)
          hardwareAudioConfigProvider.overrideWithValue(hardwareAudioConfig),
        recordingServiceConfigProvider.overrideWithValue(
          RecordingServiceConfig(
            testMode: testMode,
            recorder: recorder,
            permissionGateway: permissionGateway,
            permissionManager: permissionManager,
            pathResolver: pathResolver,
            hardwareAudioConfig: hardwareAudioConfig,
            silenceRetryPolicy: silenceRetryPolicy,
            hasRecorderOverride: hasRecorderOverride,
          ),
        ),
      ],
    );
    bindRecordingProviderContainer(container);
    return container.read(recordingServiceProvider.notifier);
  }

  late final bool _testMode;
  late final AudioRecorder? _recorder;
  late final MicrophonePermissionManager _permissionManager;
  late final RecordingPathResolver _pathResolver;
  late final HardwareAudioConfig _hardwareAudioConfig;
  late final SilenceRetryPolicy _silenceRetryPolicy;
  late final RecordCaptureEvents? _captureEvents;
  final RecordingWaveformController waveformController =
      RecordingWaveformController();

  Timer? _testWaveformTimer;
  VadSegmentedRecordingCoordinator? _vadCoordinator;

  IosCaptureAudioMode _captureAudioMode = IosCaptureAudioMode.spokenAudio;

  @override
  RecordingState build() {
    final config = ref.read(recordingServiceConfigProvider);
    final sharedRecorder = config.testMode
        ? null
        : (config.recorder ?? AudioRecorder());
    _testMode = config.testMode;
    _recorder = sharedRecorder;
    _permissionManager =
        config.permissionManager ??
        MicrophonePermissionManager(
          permissionGateway:
              config.permissionGateway ?? PermissionHandlerMicrophoneGateway(),
          recorder: sharedRecorder,
          testMode: config.testMode,
          hasRecorderOverride: config.hasRecorderOverride,
        );
    _pathResolver = config.pathResolver ?? RecordingPathResolver();
    _hardwareAudioConfig =
        config.hardwareAudioConfig ?? ref.read(hardwareAudioConfigProvider);
    _silenceRetryPolicy =
        config.silenceRetryPolicy ?? SilenceRetryPolicy(_hardwareAudioConfig);
    final levelMonitor = AudioLevelMonitor(
      silentThresholdDb: _hardwareAudioConfig.captureSilentThresholdDb,
    );
    _captureEvents = sharedRecorder == null
        ? null
        : RecordCaptureEvents(
            recorder: sharedRecorder,
            levelMonitor: levelMonitor,
          );
    ref.onDispose(_tearDown);
    return const RecordingState();
  }

  /// Emits thought chunks as VAD closes them during an active capture session.
  Stream<VadSegmentEvent>? get thoughtSegmentEvents =>
      _vadCoordinator?.segmentEvents;

  @visibleForTesting
  bool get silenceRetryAttempted => _silenceRetryPolicy.retryAttempted;

  @visibleForTesting
  IosCaptureAudioMode get captureAudioMode => _captureAudioMode;

  @visibleForTesting
  int recorderStartCallCount = 0;

  AudioRecorder get _activeRecorder {
    final recorder = _recorder;
    if (recorder == null) {
      throw RecordingException('Recorder not available in test mode.');
    }
    return recorder;
  }

  Timer? _durationTimer;

  Future<MicPermissionResolution> evaluateMicrophonePermission() =>
      _permissionManager.evaluateMicrophonePermission();

  Future<RecordingPhase> checkMicrophone() =>
      _permissionManager.checkMicrophone();

  Future<RecordingPhase> requestMicrophone() =>
      _permissionManager.requestMicrophone();

  Future<void> startRecording({bool permissionVerified = false}) async {
    _recordLog('start requested');
    await _permissionManager.assertCanStartRecording(
      permissionVerified: permissionVerified,
    );

    if (_testMode) {
      recorderStartCallCount++;
      final path = _pathResolver.testRecordingPath();
      state = state.copyWith(
        phase: RecordingPhase.recording,
        activePath: path,
        currentDuration: Duration.zero,
        clearError: true,
      );
      _startTestWaveformSimulation();
      _recordLog('start success (test mode)');
      return;
    }

    final dir = await AppStoragePaths.temporaryDirectory();
    final path = _pathResolver.productionRecordingPath(dir.path);
    _captureAudioMode = _hardwareAudioConfig.primaryCaptureAudioMode;
    _silenceRetryPolicy.resetForNewCapture();
    state = state.copyWith(
      phase: RecordingPhase.recording,
      activePath: path,
      currentDuration: Duration.zero,
      clearError: true,
    );
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(
        currentDuration: state.currentDuration + const Duration(seconds: 1),
      );
    });
    try {
      recorderStartCallCount++;
      AudioCaptureDiagnostics.logRecorderConfig();
      await _startCaptureAtPath(path);
      await _startThoughtSegmentation();
      _recordLog('start success path=$path');
      RecordPipelineLog.recorderStart(success: true, detail: 'path=$path');
    } catch (e, stackTrace) {
      _durationTimer?.cancel();
      _durationTimer = null;
      unawaited(_stopThoughtSegmentation());
      _silenceRetryPolicy.cancelScheduledCheck();
      _captureEvents?.stop(clearLevelSummary: false);
      waveformController.reset();
      _recordLog('start failed $e');
      RecordPipelineLog.recorderStart(success: false, detail: '$e');
      if (kDebugMode) {
        AudioDiagLog.operationStackTrace(
          operation: 'start_recording',
          stackTrace: stackTrace,
        );
      }
      final message = 'Could not start recording: $e';
      state = state.copyWith(
        phase: RecordingPhase.error,
        error: message,
        clearActivePath: true,
        currentDuration: Duration.zero,
      );
      throw RecordingException(message);
    }
  }

  Future<RecordingResult> stopRecording() async {
    if (_testMode) {
      final path = state.activePath ?? _pathResolver.testRecordingPath();
      final file = File(path);
      if (!file.existsSync()) {
        await file.writeAsBytes(const [0, 1, 2, 3, 4]);
      }
      final result = RecordingResult(file: file, durationSeconds: 1);
      unawaited(_stopThoughtSegmentation());
      _stopTestWaveformSimulation();
      waveformController.reset();
      state = const RecordingState();
      return result;
    }

    _silenceRetryPolicy.cancelScheduledCheck();
    final thoughtSegments = await _stopThoughtSegmentation();

    final levelSummary = _captureEvents?.stop() ??
        const AudioLevelSummary(
          minDb: double.negativeInfinity,
          maxDb: double.negativeInfinity,
          avgDb: double.negativeInfinity,
          sampleCount: 0,
          likelySilent: true,
        );
    waveformController.reset();
    final path = await _activeRecorder.stop();
    _durationTimer?.cancel();
    _durationTimer = null;
    final finalPath = path ?? state.activePath;
    if (finalPath == null || !File(finalPath).existsSync()) {
      throw RecordingException('Recording file missing after stop.');
    }
    final duration = state.currentDuration.inSeconds;
    final durationMs = state.currentDuration.inMilliseconds;
    final file = File(finalPath);
    final byteLength = file.lengthSync();
    RecordPipelineLog.audioFile(
      path: finalPath,
      exists: true,
      byteLength: byteLength,
    );
    AudioCaptureDiagnostics.logCapturedFile(file, durationMs: durationMs);
    state = RecordingState(
      recordingCompletion: RecordingCompletion(
        file: file,
        durationMs: durationMs,
      ),
    );
    return RecordingResult(
      file: file,
      durationSeconds: duration < 1 ? 1 : duration,
      likelySilentInput: levelSummary.likelySilent,
      audioLevelSummary: levelSummary,
      thoughtSegments: thoughtSegments,
    );
  }

  Future<void> _startThoughtSegmentation() async {
    if (_testMode) return;
    _vadCoordinator ??= VadSegmentedRecordingCoordinator();
    if (_vadCoordinator!.isActive) return;
    try {
      await _vadCoordinator!.start(config: _hardwareAudioConfig.vadStreamConfig);
    } catch (e, stackTrace) {
      _recordLog('VAD start failed: $e');
      if (kDebugMode) {
        AudioDiagLog.operationStackTrace(
          operation: 'start_recording',
          stackTrace: stackTrace,
        );
      }
    }
  }

  Future<List<VoiceThoughtSegment>> _stopThoughtSegmentation() async {
    final coordinator = _vadCoordinator;
    if (coordinator == null || !coordinator.isActive) {
      return const [];
    }
    try {
      return await coordinator.stop();
    } catch (e, stackTrace) {
      _recordLog('VAD stop failed: $e');
      if (kDebugMode) {
        AudioDiagLog.operationStackTrace(
          operation: 'start_recording',
          stackTrace: stackTrace,
        );
      }
      return coordinator.segments;
    }
  }

  Future<void> _startCaptureAtPath(
    String path, {
    bool scheduleSilenceRetry = true,
  }) async {
    await IosAudioSessionConfigurator.configureForCapture(
      _activeRecorder,
      mode: _captureAudioMode,
    );
    await _activeRecorder.start(
      AudioCaptureDiagnostics.iosCaptureConfig,
      path: path,
    );
    final captureEvents = _captureEvents;
    if (captureEvents == null) return;
    captureEvents.levelMonitor.resetStats();
    captureEvents.start(
      onAmplitudeSample: waveformController.pushDb,
      onState: _handleRecordState,
    );
    if (scheduleSilenceRetry) {
      _silenceRetryPolicy.scheduleInitialSilenceCheck(_maybeRetrySilentCapture);
    }
  }

  void _handleRecordState(RecordState recordState) {
    switch (recordState) {
      case RecordState.record:
        if (state.phase != RecordingPhase.recording) {
          state = state.copyWith(
            phase: RecordingPhase.recording,
            clearError: true,
          );
        }
      case RecordState.pause:
        return;
      case RecordState.stop:
        if (state.phase == RecordingPhase.recording) {
          _recordLog('recorder state stopped unexpectedly');
          state = state.copyWith(
            phase: RecordingPhase.error,
            error: 'Recording stopped unexpectedly',
          );
        }
    }
  }

  Future<void> _maybeRetrySilentCapture() async {
    if (_testMode) return;
    final captureEvents = _captureEvents;
    if (captureEvents == null) return;
    if (!await _silenceRetryPolicy.shouldRetryForInitialSilence(
      maxDbInInitialWindow: captureEvents.levelMonitor.currentMaxDb,
    )) {
      return;
    }
    if (!_silenceRetryPolicy.commitRetryAttempt()) return;

    final oldMaxDb = captureEvents.levelMonitor.currentMaxDb;
    AudioDiagLog.silenceRetry(reason: 'low_initial_db', oldMaxDb: oldMaxDb);

    captureEvents.stop(clearLevelSummary: false);
    final partialPath = await _activeRecorder.stop();
    final discardPath = partialPath ?? state.activePath;
    if (discardPath != null) {
      try {
        final partial = File(discardPath);
        if (partial.existsSync()) {
          await partial.delete();
        }
      } catch (e, stackTrace) {
        AppLogger.error('Unhandled error caught', error: e, stackTrace: stackTrace);
      }
    }

    _captureAudioMode = _hardwareAudioConfig.silenceRetryCaptureAudioMode;
    AudioDiagLog.silenceRetryStarted(mode: _captureAudioMode.value);

    final dir = await AppStoragePaths.temporaryDirectory();
    final retryPath = _pathResolver.retryRecordingPath(dir.path);
    state = state.copyWith(
      activePath: retryPath,
      currentDuration: Duration.zero,
      clearError: true,
    );

    try {
      await _startCaptureAtPath(retryPath, scheduleSilenceRetry: false);
      await _startThoughtSegmentation();
      _recordLog('silence retry started path=$retryPath mode=measurement');
    } catch (e, stackTrace) {
      _recordLog('silence retry failed $e');
      state = state.copyWith(
        phase: RecordingPhase.error,
        error: 'Silence retry failed: $e',
      );
      if (kDebugMode) {
        AudioDiagLog.operationStackTrace(
          operation: 'start_recording',
          stackTrace: stackTrace,
        );
      }
    }
  }

  void acknowledgeRecordingCompletion() {
    if (state.recordingCompletion == null) return;
    state = state.copyWith(clearRecordingCompletion: true);
  }

  Future<bool> get isRecording {
    if (_testMode) {
      return Future.value(state.phase == RecordingPhase.recording);
    }
    return _activeRecorder.isRecording();
  }

  void dispose() => _tearDown();

  void _startTestWaveformSimulation() {
    _stopTestWaveformSimulation();
    if (!_testMode) return;
    var tick = 0;
    _testWaveformTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      tick += 1;
      final t = tick / 20.0;
      final level = 0.25 + 0.55 * (0.5 + 0.5 * math.sin(t * 2.7));
      waveformController.pushNormalized(level);
    });
  }

  void _stopTestWaveformSimulation() {
    _testWaveformTimer?.cancel();
    _testWaveformTimer = null;
  }

  void _tearDown() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _stopTestWaveformSimulation();
    unawaited(_vadCoordinator?.dispose());
    _vadCoordinator = null;
    _silenceRetryPolicy.dispose();
    _captureEvents?.stop(clearLevelSummary: false);
    waveformController.reset();
    final recorder = _recorder;
    if (recorder != null) unawaited(recorder.dispose());
  }
}

final recordingServiceProvider =
    NotifierProvider<RecordingService, RecordingState>(RecordingService.new);

final recordingDurationSecondsProvider = Provider<int>((ref) {
  return ref.watch(recordingServiceProvider).currentDuration.inSeconds;
});

final recordingWaveformControllerProvider = Provider<RecordingWaveformController>(
  (ref) {
    ref.watch(recordingServiceProvider);
    return ref.read(recordingServiceProvider.notifier).waveformController;
  },
);
