import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

import '../core/di/app_provider_container.dart';
import '../features/voice_capture/audio/audio_capture_diagnostics.dart';
import '../features/voice_capture/audio/audio_diag_log.dart';
import '../features/voice_capture/audio/audio_level_monitor.dart';
import '../features/voice_capture/audio/ios_audio_session.dart';
import '../features/voice_capture/audio/ios_native_recorder.dart';
import '../features/voice_capture/audio/ios_native_recorder_config.dart';
import '../features/voice_capture/audio/mic_capture_input_health.dart';
import '../features/voice_capture/microphone_permission_environment.dart';
import '../features/voice_capture/microphone_permission_gateway.dart';
import '../services/record_pipeline_log.dart';
import '../storage/app_storage_paths.dart';
import 'microphone_permission_manager.dart';
import 'recording_path_resolver.dart';
import 'recording_types.dart';
import 'silence_retry_policy.dart';

export 'microphone_permission_manager.dart' show MicPermissionResolution;
export 'recording_types.dart';

void _recordLog(String message) {
  debugPrint('RECORD: $message');
}

/// Injectable configuration for [recordingServiceProvider].
class RecordingServiceConfig {
  const RecordingServiceConfig({
    this.testMode = false,
    this.recorder,
    this.permissionGateway,
    this.permissionManager,
    this.pathResolver,
    this.silenceRetryPolicy,
    this.hasRecorderOverride,
    this.useNativeRecorderOverride,
  });

  final bool testMode;
  final AudioRecorder? recorder;
  final MicrophonePermissionGateway? permissionGateway;
  final MicrophonePermissionManager? permissionManager;
  final RecordingPathResolver? pathResolver;
  final SilenceRetryPolicy? silenceRetryPolicy;
  final bool? hasRecorderOverride;
  final bool? useNativeRecorderOverride;
}

final recordingServiceConfigProvider = Provider<RecordingServiceConfig>(
  (ref) => const RecordingServiceConfig(),
);

/// Shared Riverpod container for capture — set by [RecordingService.create] or AppServices.
ProviderContainer get recordingProviderContainer => appProviderContainer;

void bindRecordingProviderContainer(ProviderContainer container) {
  bindAppProviderContainer(container);
}

/// Real microphone capture via `record` package — Riverpod [Notifier] boundary.
class RecordingService extends Notifier<RecordingState> {
  static RecordingService create({
    bool testMode = false,
    AudioRecorder? recorder,
    MicrophonePermissionGateway? permissionGateway,
    MicrophonePermissionManager? permissionManager,
    RecordingPathResolver? pathResolver,
    SilenceRetryPolicy? silenceRetryPolicy,
    bool? hasRecorderOverride,
    @visibleForTesting bool? useNativeRecorderOverride,
  }) {
    final container = ProviderContainer(
      overrides: [
        recordingServiceConfigProvider.overrideWithValue(
          RecordingServiceConfig(
            testMode: testMode,
            recorder: recorder,
            permissionGateway: permissionGateway,
            permissionManager: permissionManager,
            pathResolver: pathResolver,
            silenceRetryPolicy: silenceRetryPolicy,
            hasRecorderOverride: hasRecorderOverride,
            useNativeRecorderOverride: useNativeRecorderOverride,
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
  late final SilenceRetryPolicy _silenceRetryPolicy;
  final AudioLevelMonitor _audioLevelMonitor = AudioLevelMonitor();

  IosCaptureAudioMode _captureAudioMode = IosCaptureAudioMode.spokenAudio;
  bool _usingNativeRecorder = false;

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
    _pathResolver =
        config.pathResolver ??
        RecordingPathResolver(
          useNativeRecorderOverride: config.useNativeRecorderOverride,
        );
    _silenceRetryPolicy = config.silenceRetryPolicy ?? SilenceRetryPolicy();
    ref.onDispose(_tearDown);
    return const RecordingState();
  }

  @visibleForTesting
  bool get usingNativeRecorder => _usingNativeRecorder;

  @visibleForTesting
  int nativeStartCallCount = 0;

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
      String? path;
      if (await _pathResolver.shouldUseNativeRecorder()) {
        _usingNativeRecorder = true;
        nativeStartCallCount++;
        path = _pathResolver.testRecordingPath(native: true);
        path = await _pathResolver.resolveTestNativeStartPath(path);
      }
      state = state.copyWith(
        phase: RecordingPhase.recording,
        activePath: path,
        currentDuration: Duration.zero,
        clearError: true,
      );
      _recordLog('start success (test mode)');
      return;
    }

    _usingNativeRecorder = await _pathResolver.shouldUseNativeRecorder();
    final dir = await AppStoragePaths.temporaryDirectory();
    final path = await _pathResolver.productionRecordingPath(dir.path);
    _captureAudioMode = IosCaptureAudioMode.spokenAudio;
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
      if (_usingNativeRecorder) {
        nativeStartCallCount++;
        final format = await IosNativeRecorderConfig.recordingFormatForDevice();
        final resolvedPath = await IosNativeRecorder.startRecording(
          path,
          format: format,
        );
        state = state.copyWith(activePath: resolvedPath);
        _recordLog(
          'native recorder start success path=$resolvedPath '
          'format=${IosNativeRecorderConfig.fileExtensionFor(format)}',
        );
      } else {
        await _startPluginCaptureAtPath(path);
      }
      _recordLog('start success path=$path');
      RecordPipelineLog.recorderStart(success: true, detail: 'path=$path');
    } catch (e, st) {
      _durationTimer?.cancel();
      _durationTimer = null;
      _usingNativeRecorder = false;
      _silenceRetryPolicy.cancelScheduledCheck();
      _audioLevelMonitor.stop(logSummary: false);
      if (e is NativeRecorderException) {
        _recordLog('native start failed step=${e.step} reason=${e.reason}');
        RecordPipelineLog.recorderStart(
          success: false,
          detail: 'step=${e.step} reason=${e.reason}',
        );
      } else {
        _recordLog('start failed $e');
        RecordPipelineLog.recorderStart(success: false, detail: '$e');
      }
      if (kDebugMode) {
        debugPrint('$st');
      }
      final message = e is NativeRecorderException
          ? 'Could not start native recording (${e.step}): ${e.reason}'
          : 'Could not start recording: $e';
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
      final path =
          state.activePath ??
          _pathResolver.testRecordingPath(native: _usingNativeRecorder);
      final file = File(path);
      if (!file.existsSync()) {
        await file.writeAsBytes(const [0, 1, 2, 3, 4]);
      }
      RecordingResult result;
      if (_usingNativeRecorder && IosNativeRecorder.hasInjectedTestPlatform) {
        final nativeResult = await IosNativeRecorder.stopRecording();
        result = RecordingResult(
          file: File(nativeResult.path),
          durationSeconds: (nativeResult.durationMs / 1000).ceil().clamp(
            1,
            9999,
          ),
          likelySilentInput: nativeResult.likelySilent,
          audioLevelSummary: nativeResult.toAudioLevelSummary(),
          captureInputPortName: nativeResult.inputPortName,
          captureInputPortType: nativeResult.inputPortType,
        );
      } else {
        result = RecordingResult(file: file, durationSeconds: 1);
      }
      _usingNativeRecorder = false;
      state = const RecordingState();
      return result;
    }

    _silenceRetryPolicy.cancelScheduledCheck();

    if (_usingNativeRecorder) {
      final nativeResult = await IosNativeRecorder.stopRecording();
      _durationTimer?.cancel();
      _durationTimer = null;
      final file = File(nativeResult.path);
      if (!file.existsSync()) {
        throw RecordingException('Native recording file missing after stop.');
      }
      final durationSeconds = nativeResult.durationMs <= 0
          ? 1
          : (nativeResult.durationMs / 1000).round().clamp(1, 999999);
      RecordPipelineLog.audioFile(
        path: nativeResult.path,
        exists: true,
        byteLength: nativeResult.bytes,
      );
      AudioCaptureDiagnostics.logCapturedFile(
        file,
        durationMs: nativeResult.durationMs,
      );
      final summary = nativeResult.toAudioLevelSummary();
      AudioDiagLog.levelSummary(
        minDb: summary.minDb,
        maxDb: summary.maxDb,
        avgDb: summary.avgDb,
        sampleCount: summary.sampleCount,
        likelySilent: summary.likelySilent,
      );
      MicCaptureInputHealth.log(
        likelySilent: nativeResult.likelySilent,
        portName: nativeResult.inputPortName,
        portType: nativeResult.inputPortType,
      );
      _usingNativeRecorder = false;
      state = const RecordingState();
      return RecordingResult(
        file: file,
        durationSeconds: durationSeconds,
        likelySilentInput: nativeResult.likelySilent,
        audioLevelSummary: summary,
        captureInputPortName: nativeResult.inputPortName,
        captureInputPortType: nativeResult.inputPortType,
      );
    }

    final levelSummary = _audioLevelMonitor.stop();
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
    _usingNativeRecorder = false;
    state = const RecordingState();
    return RecordingResult(
      file: file,
      durationSeconds: duration < 1 ? 1 : duration,
      likelySilentInput: levelSummary.likelySilent,
      audioLevelSummary: levelSummary,
    );
  }

  Future<void> _startPluginCaptureAtPath(
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
    _audioLevelMonitor.resetStats();
    _audioLevelMonitor.start(_activeRecorder);
    if (scheduleSilenceRetry) {
      _silenceRetryPolicy.scheduleInitialSilenceCheck(_maybeRetrySilentCapture);
    }
  }

  Future<void> _maybeRetrySilentCapture() async {
    if (_testMode || _usingNativeRecorder) return;
    if (!await MicrophonePermissionEnvironment.isIosPhysicalDevice()) return;
    if (!_silenceRetryPolicy.shouldRetryForInitialSilence(
      isIosPhysical: true,
      maxDbInInitialWindow: _audioLevelMonitor.currentMaxDb,
    )) {
      return;
    }
    if (!_silenceRetryPolicy.commitRetryAttempt()) return;

    final oldMaxDb = _audioLevelMonitor.currentMaxDb;
    AudioDiagLog.silenceRetry(reason: 'low_initial_db', oldMaxDb: oldMaxDb);

    _audioLevelMonitor.stop(logSummary: false);
    final partialPath = await _activeRecorder.stop();
    final discardPath = partialPath ?? state.activePath;
    if (discardPath != null) {
      try {
        final partial = File(discardPath);
        if (partial.existsSync()) {
          await partial.delete();
        }
      } catch (_) {}
    }

    _captureAudioMode = IosCaptureAudioMode.measurement;
    AudioDiagLog.silenceRetryStarted(mode: _captureAudioMode.value);

    final dir = await AppStoragePaths.temporaryDirectory();
    final retryPath = _pathResolver.retryRecordingPath(dir.path);
    state = state.copyWith(
      activePath: retryPath,
      currentDuration: Duration.zero,
      clearError: true,
    );

    try {
      await _startPluginCaptureAtPath(retryPath, scheduleSilenceRetry: false);
      _recordLog('silence retry started path=$retryPath mode=measurement');
    } catch (e, st) {
      _recordLog('silence retry failed $e');
      state = state.copyWith(
        phase: RecordingPhase.error,
        error: 'Silence retry failed: $e',
      );
      if (kDebugMode) {
        debugPrint('$st');
      }
    }
  }

  Future<bool> get isRecording {
    if (_testMode) {
      return Future.value(
        _usingNativeRecorder || state.phase == RecordingPhase.recording,
      );
    }
    if (_usingNativeRecorder) {
      return Future.value(state.phase == RecordingPhase.recording);
    }
    return _activeRecorder.isRecording();
  }

  void dispose() => _tearDown();

  void _tearDown() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _silenceRetryPolicy.dispose();
    _audioLevelMonitor.stop(logSummary: false);
    _recorder?.dispose();
  }
}

final recordingServiceProvider =
    NotifierProvider<RecordingService, RecordingState>(RecordingService.new);

final recordingDurationSecondsProvider = Provider<int>((ref) {
  return ref.watch(recordingServiceProvider).currentDuration.inSeconds;
});
