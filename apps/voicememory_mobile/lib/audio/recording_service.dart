import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../features/voice_capture/audio/audio_capture_diagnostics.dart';
import '../features/voice_capture/audio/audio_diag_log.dart';
import '../features/voice_capture/audio/audio_level_monitor.dart';
import '../features/voice_capture/audio/ios_audio_session.dart';
import '../features/voice_capture/audio/ios_native_recorder.dart';
import '../features/voice_capture/audio/ios_native_recorder_config.dart';
import '../features/voice_capture/audio/mic_capture_input_health.dart';
import '../features/voice_capture/microphone_permission_environment.dart';
import '../features/voice_capture/microphone_permission_gateway.dart';
import '../features/voice_capture/microphone_permission_state.dart';
import '../services/record_pipeline_log.dart';
import '../storage/app_storage_paths.dart';

void _recordLog(String message) {
  debugPrint('RECORD: $message');
}

String _testRecordingPath({
  required bool native,
  IosRecordingFormat format = IosRecordingFormat.wav,
}) {
  if (!native) {
    return '${Directory.systemTemp.path}/vm_rec_test.m4a';
  }
  final ext = IosNativeRecorderConfig.fileExtensionFor(format);
  return '${Directory.systemTemp.path}/vm_rec_test_native.$ext';
}

Future<String> _nativeRecordingPath(String directoryPath) async {
  final format = await IosNativeRecorderConfig.recordingFormatForDevice();
  final ext = IosNativeRecorderConfig.fileExtensionFor(format);
  return '$directoryPath/vm_rec_${DateTime.now().millisecondsSinceEpoch}.$ext';
}

enum RecordingPhase {
  idle,
  requestingPermission,
  permissionDenied,
  permissionPermanentlyDenied,
  ready,
  recording,
  error,
}

class RecordingResult {
  const RecordingResult({
    required this.file,
    required this.durationSeconds,
    this.likelySilentInput = false,
    this.audioLevelSummary,
    this.captureInputPortName,
    this.captureInputPortType,
  });

  final File file;
  final int durationSeconds;
  final bool likelySilentInput;
  final AudioLevelSummary? audioLevelSummary;
  final String? captureInputPortName;
  final String? captureInputPortType;
}

/// Normalized microphone permission for voice capture.
class MicPermissionResolution {
  const MicPermissionResolution({
    required this.phase,
    required this.state,
    required this.hasRecorder,
    this.permissionHandlerStatus,
    this.nativePermissionStatus,
  });

  final RecordingPhase phase;
  final MicrophonePermissionState state;
  final bool hasRecorder;
  final PermissionStatus? permissionHandlerStatus;
  final String? nativePermissionStatus;

  bool get isRecordable => MicrophonePermissionResolver.isRecordable(state);
}

/// Real microphone capture via `record` package.
class RecordingService {
  RecordingService({
    AudioRecorder? recorder,
    bool testMode = false,
    MicrophonePermissionGateway? permissionGateway,
    bool? hasRecorderOverride,
    @visibleForTesting bool? useNativeRecorderOverride,
  }) : _testMode = testMode,
       _recorder = testMode ? null : (recorder ?? AudioRecorder()),
       _permissionGateway =
           permissionGateway ?? PermissionHandlerMicrophoneGateway(),
       _hasRecorderOverride = hasRecorderOverride,
       _useNativeRecorderOverride = useNativeRecorderOverride;

  final bool _testMode;
  final AudioRecorder? _recorder;
  final MicrophonePermissionGateway _permissionGateway;
  final bool? _hasRecorderOverride;
  final bool? _useNativeRecorderOverride;
  final AudioLevelMonitor _audioLevelMonitor = AudioLevelMonitor();

  IosCaptureAudioMode _captureAudioMode = IosCaptureAudioMode.spokenAudio;
  bool _silenceRetryAttempted = false;
  Timer? _silenceRetryTimer;
  bool _usingNativeRecorder = false;

  @visibleForTesting
  bool get usingNativeRecorder => _usingNativeRecorder;

  @visibleForTesting
  int nativeStartCallCount = 0;

  @visibleForTesting
  bool get silenceRetryAttempted => _silenceRetryAttempted;

  @visibleForTesting
  IosCaptureAudioMode get captureAudioMode => _captureAudioMode;

  @visibleForTesting
  int recorderStartCallCount = 0;

  AudioRecorder get _activeRecorder {
    final r = _recorder;
    if (r == null) {
      throw RecordingException('Recorder not available in test mode.');
    }
    return r;
  }

  DateTime? _startedAt;
  String? _activePath;
  Timer? _durationTimer;
  int _elapsedSeconds = 0;

  final StreamController<int> _durationController =
      StreamController<int>.broadcast();

  Stream<int> get durationSeconds => _durationController.stream;

  Future<bool> _shouldUseNativeRecorder() async {
    final override = _useNativeRecorderOverride;
    if (override != null) return override;
    return IosNativeRecorder.shouldUseOnDevice();
  }

  Future<bool> _hasRecorderPermission({bool request = false}) async {
    final override = _hasRecorderOverride;
    if (override != null) return override;
    if (_testMode) return true;
    return _activeRecorder.hasPermission(request: request);
  }

  Future<void> _logMicDiag(PermissionStatus permissionHandler) async {
    final recordHasPermission = await _hasRecorderPermission();
    final platform = await MicrophonePermissionEnvironment.platformLabel();
    MicrophonePermissionEnvironment.logMicDiag(
      permissionHandler: permissionHandler,
      recordHasPermission: recordHasPermission,
      platform: platform,
    );
  }

  Future<MicPermissionResolution> _resolveFromPlatform({
    required PermissionStatus status,
    required bool hasRecorder,
    required bool preferRecorderOnIosSimulator,
    required bool allowPhysicalRecorderMismatch,
    String logPrefix = 'check',
  }) async {
    final platform = await MicrophonePermissionEnvironment.platformLabel();
    if (hasRecorder && preferRecorderOnIosSimulator && !status.isGranted) {
      MicrophonePermissionEnvironment.logMicDiagMismatch(
        permissionHandler: status,
        platform: platform,
      );
    }
    if (allowPhysicalRecorderMismatch) {
      MicrophonePermissionEnvironment.logPhysicalMismatchWarning(status: status);
    }
    final state = MicrophonePermissionResolver.resolve(
      status: status,
      hasRecorder: hasRecorder,
      preferRecorderOnIosSimulator: preferRecorderOnIosSimulator,
      allowPhysicalRecorderMismatch: allowPhysicalRecorderMismatch,
    );
    MicrophonePermissionResolver.logPermissionSource(
      permissionHandler: status,
      recordHasPermission: hasRecorder,
      preferRecorderOnIosSimulator: preferRecorderOnIosSimulator,
      allowPhysicalRecorderMismatch: allowPhysicalRecorderMismatch,
      resolved: state,
      platform: platform,
    );
    final phase = MicrophonePermissionResolver.toRecordingPhase(state);
    _recordLog(
      'permission result hasRecorder=$hasRecorder status=$status phase=$phase',
    );
    RecordPipelineLog.microphonePermission(
      before: '$status hasRecorder=$hasRecorder',
      after: '$state',
      prefix: logPrefix,
    );
    if (!MicPermissionResolution(
      phase: phase,
      state: state,
      hasRecorder: hasRecorder,
      permissionHandlerStatus: status,
    ).isRecordable) {
      RecordPipelineLog.microphonePermissionBlocked(blocked: true);
    }
    return MicPermissionResolution(
      phase: phase,
      state: state,
      hasRecorder: hasRecorder,
      permissionHandlerStatus: status,
    );
  }

  Future<bool> _allowPhysicalRecorderMismatch({
    required PermissionStatus status,
    required bool hasRecorder,
  }) {
    return MicrophonePermissionEnvironment.allowPhysicalRecorderMismatch(
      status: status,
      hasRecorder: hasRecorder,
    );
  }

  Future<bool> _preferSimulatorRecorderOverride({
    required PermissionStatus status,
    required bool hasRecorder,
  }) {
    return MicrophonePermissionEnvironment.preferRecorderOnPlatformMismatch(
      status: status,
      hasRecorder: hasRecorder,
    );
  }

  Future<bool> _usesNativeMicPermission() async {
    return MicrophonePermissionEnvironment.isIosPhysicalDevice();
  }

  Future<MicPermissionResolution> _evaluateNativeMicrophonePermission({
    String logPrefix = 'check',
  }) async {
    final native = await IosNativeRecorder.microphonePermission();
    final platform = await MicrophonePermissionEnvironment.platformLabel();
    debugPrint(
      'ARCHIVEME_NATIVE_MIC_PERMISSION status=${native.status} '
      'granted=${native.granted}',
    );
    final state = MicrophonePermissionResolver.resolveFromNative(native);
    debugPrint(
      'ARCHIVEME_MIC_PERMISSION_REFRESH native_status=${native.status} '
      'resolved=${MicrophonePermissionResolver.resolvedLogName(state)}',
    );
    MicrophonePermissionResolver.logNativePermissionSource(
      nativeStatus: native.status,
      granted: native.granted,
      resolved: state,
      platform: platform,
    );
    final phase = MicrophonePermissionResolver.toRecordingPhase(state);
    _recordLog(
      'native permission result status=${native.status} granted=${native.granted} phase=$phase',
    );
    RecordPipelineLog.microphonePermission(
      before: 'native_status=${native.status}',
      after: '$state',
      prefix: logPrefix,
    );
    if (!MicPermissionResolution(
      phase: phase,
      state: state,
      hasRecorder: native.granted,
      nativePermissionStatus: native.status,
    ).isRecordable) {
      RecordPipelineLog.microphonePermissionBlocked(blocked: true);
    }
    return MicPermissionResolution(
      phase: phase,
      state: state,
      hasRecorder: native.granted,
      nativePermissionStatus: native.status,
    );
  }

  Future<RecordingPhase> _requestNativeMicrophone() async {
    debugPrint('ARCHIVEME_MIC_PERMISSION_ACTION request_native_permission');
    RecordPipelineLog.microphonePermissionRequestShown(shown: true);
    final native = await IosNativeRecorder.requestMicrophonePermission();
    debugPrint(
      'ARCHIVEME_NATIVE_MIC_PERMISSION_REQUEST_RESULT '
      'granted=${native.granted} status=${native.status}',
    );
    final resolution = await _evaluateNativeMicrophonePermission(
      logPrefix: 'after-request',
    );
    return resolution.phase;
  }

  Future<MicPermissionResolution> evaluateMicrophonePermission() async {
    if (_testMode &&
        _permissionGateway is! FakeMicrophonePermissionGateway &&
        _hasRecorderOverride == null &&
        !await _usesNativeMicPermission()) {
      return const MicPermissionResolution(
        phase: RecordingPhase.ready,
        state: MicrophonePermissionState.granted,
        hasRecorder: true,
        permissionHandlerStatus: PermissionStatus.granted,
      );
    }
    if (await _usesNativeMicPermission()) {
      return _evaluateNativeMicrophonePermission();
    }
    final status = await _permissionGateway.status;
    await _logMicDiag(status);
    final hasRecorder = await _hasRecorderPermission();
    final preferSimulator = await _preferSimulatorRecorderOverride(
      status: status,
      hasRecorder: hasRecorder,
    );
    final allowPhysical = await _allowPhysicalRecorderMismatch(
      status: status,
      hasRecorder: hasRecorder,
    );
    return _resolveFromPlatform(
      status: status,
      hasRecorder: hasRecorder,
      preferRecorderOnIosSimulator: preferSimulator,
      allowPhysicalRecorderMismatch: allowPhysical,
    );
  }

  Future<RecordingPhase> checkMicrophone() async {
    final resolution = await evaluateMicrophonePermission();
    return resolution.phase;
  }

  Future<RecordingPhase> requestMicrophone() async {
    if (_testMode &&
        _permissionGateway is! FakeMicrophonePermissionGateway &&
        _hasRecorderOverride == null &&
        !await _usesNativeMicPermission()) {
      _recordLog('permission result ready (test mode)');
      return RecordingPhase.ready;
    }
    if (await _usesNativeMicPermission()) {
      return _requestNativeMicrophone();
    }
    final beforeStatus = await _permissionGateway.status;
    await _logMicDiag(beforeStatus);
    final beforeHas = await _hasRecorderPermission();

    if (await MicrophonePermissionEnvironment.shouldSkipPermissionRequest(
      status: beforeStatus,
      hasRecorder: beforeHas,
    )) {
      _recordLog(
        'permission request skipped — physical iOS recorder verified',
      );
      final preferSimulator = await _preferSimulatorRecorderOverride(
        status: beforeStatus,
        hasRecorder: beforeHas,
      );
      final allowPhysical = await _allowPhysicalRecorderMismatch(
        status: beforeStatus,
        hasRecorder: beforeHas,
      );
      final resolution = await _resolveFromPlatform(
        status: beforeStatus,
        hasRecorder: beforeHas,
        preferRecorderOnIosSimulator: preferSimulator,
        allowPhysicalRecorderMismatch: allowPhysical,
        logPrefix: 'skip-request',
      );
      return resolution.phase;
    }

    RecordPipelineLog.microphonePermissionRequestShown(shown: true);
    final result = await _permissionGateway.request();
    var afterHas = await _hasRecorderPermission();
    if (result.isGranted && !afterHas) {
      afterHas = await _hasRecorderPermissionAfterGrant();
    }
    await _logMicDiag(result);
    _recordLog('permission result request=$result hasRecorder=$afterHas');
    RecordPipelineLog.microphonePermission(
      before: '$beforeStatus hasRecorder=$beforeHas',
      after: '$result hasRecorder=$afterHas',
      prefix: 'request',
    );
    final preferSimulator = await _preferSimulatorRecorderOverride(
      status: result,
      hasRecorder: afterHas,
    );
    final allowPhysical = await _allowPhysicalRecorderMismatch(
      status: result,
      hasRecorder: afterHas,
    );
    final resolution = await _resolveFromPlatform(
      status: result,
      hasRecorder: afterHas,
      preferRecorderOnIosSimulator: preferSimulator,
      allowPhysicalRecorderMismatch: allowPhysical,
      logPrefix: 'after-request',
    );
    return resolution.phase;
  }

  Future<bool> _hasRecorderPermissionAfterGrant() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      if (await _hasRecorderPermission()) return true;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return _hasRecorderPermission();
  }

  Future<void> startRecording({bool permissionVerified = false}) async {
    _recordLog('start requested');
    if (!permissionVerified) {
      final resolution = await evaluateMicrophonePermission();
      if (!resolution.isRecordable) {
        _recordLog('start failed — microphone phase=${resolution.phase}');
        RecordPipelineLog.microphonePermissionBlocked(blocked: true);
        throw RecordingException('Microphone not available: ${resolution.phase}');
      }
    } else {
      if (await _usesNativeMicPermission()) {
        final resolution = await evaluateMicrophonePermission();
        if (!resolution.isRecordable) {
          _recordLog('start failed — native microphone phase=${resolution.phase}');
          RecordPipelineLog.microphonePermissionBlocked(blocked: true);
          throw RecordingException(
            'Microphone not available: ${resolution.phase}',
          );
        }
      } else {
        final status = await _permissionGateway.status;
        await _logMicDiag(status);
        final hasRecorder = await _hasRecorderPermission();
        if (!status.isGranted && !hasRecorder) {
          _recordLog('start failed — microphone not granted');
          RecordPipelineLog.microphonePermissionBlocked(blocked: true);
          throw RecordingException(
            'Microphone not available: ${RecordingPhase.permissionDenied}',
          );
        }
      }
    }
    if (_testMode) {
      recorderStartCallCount++;
      if (await _shouldUseNativeRecorder()) {
        _usingNativeRecorder = true;
        nativeStartCallCount++;
        _activePath = _testRecordingPath(native: true);
        if (IosNativeRecorder.testPlatform != null) {
          _activePath = await IosNativeRecorder.startRecording(_activePath!);
        }
      }
      _recordLog('start success (test mode)');
      return;
    }
    _usingNativeRecorder = await _shouldUseNativeRecorder();
    final dir = await AppStoragePaths.temporaryDirectory();
    final path = await _nativeRecordingPath(dir.path);
    _activePath = path;
    _startedAt = DateTime.now();
    _elapsedSeconds = 0;
    _captureAudioMode = IosCaptureAudioMode.spokenAudio;
    _silenceRetryAttempted = false;
    _durationController.add(0);
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds += 1;
      _durationController.add(_elapsedSeconds);
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
        _activePath = resolvedPath;
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
      _startedAt = null;
      _activePath = null;
      _usingNativeRecorder = false;
      _silenceRetryTimer?.cancel();
      _silenceRetryTimer = null;
      _audioLevelMonitor.stop(logSummary: false);
      if (e is NativeRecorderException) {
        _recordLog(
          'native start failed step=${e.step} reason=${e.reason}',
        );
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
      throw RecordingException(message);
    }
  }

  Future<RecordingResult> stopRecording() async {
    if (_testMode) {
      final path = _activePath ?? _testRecordingPath(native: _usingNativeRecorder);
      final file = File(path);
      if (!file.existsSync()) {
        await file.writeAsBytes(const [0, 1, 2, 3, 4]);
      }
      if (_usingNativeRecorder && IosNativeRecorder.testPlatform != null) {
        final nativeResult = await IosNativeRecorder.stopRecording();
        return RecordingResult(
          file: File(nativeResult.path),
          durationSeconds: (nativeResult.durationMs / 1000).ceil().clamp(1, 9999),
          likelySilentInput: nativeResult.likelySilent,
          audioLevelSummary: nativeResult.toAudioLevelSummary(),
          captureInputPortName: nativeResult.inputPortName,
          captureInputPortType: nativeResult.inputPortType,
        );
      }
      return RecordingResult(file: file, durationSeconds: 1);
    }

    _silenceRetryTimer?.cancel();
    _silenceRetryTimer = null;

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
      _startedAt = null;
      _activePath = null;
      _usingNativeRecorder = false;
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
    final finalPath = path ?? _activePath;
    if (finalPath == null || !File(finalPath).existsSync()) {
      throw RecordingException('Recording file missing after stop.');
    }
    final duration = _startedAt == null
        ? _elapsedSeconds
        : DateTime.now().difference(_startedAt!).inSeconds;
    final durationMs = _startedAt == null
        ? _elapsedSeconds * 1000
        : DateTime.now().difference(_startedAt!).inMilliseconds;
    final file = File(finalPath);
    final byteLength = file.lengthSync();
    RecordPipelineLog.audioFile(
      path: finalPath,
      exists: true,
      byteLength: byteLength,
    );
    AudioCaptureDiagnostics.logCapturedFile(
      file,
      durationMs: durationMs,
    );
    _startedAt = null;
    _activePath = null;
    _usingNativeRecorder = false;
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
      _scheduleSilenceRetryCheck();
    }
  }

  void _scheduleSilenceRetryCheck() {
    _silenceRetryTimer?.cancel();
    _silenceRetryTimer = Timer(AudioLevelMonitor.silenceRetryWindow, () {
      unawaited(_maybeRetrySilentCapture());
    });
  }

  Future<void> _maybeRetrySilentCapture() async {
    if (_testMode || _silenceRetryAttempted || _usingNativeRecorder) return;
    if (!await MicrophonePermissionEnvironment.isIosPhysicalDevice()) return;
    if (!_audioLevelMonitor.shouldRetryForInitialSilence(
      isIosPhysical: true,
    )) {
      return;
    }

    _silenceRetryAttempted = true;
    final oldMaxDb = _audioLevelMonitor.currentMaxDb;
    AudioDiagLog.silenceRetry(
      reason: 'low_initial_db',
      oldMaxDb: oldMaxDb,
    );

    _audioLevelMonitor.stop(logSummary: false);
    final partialPath = await _activeRecorder.stop();
    final discardPath = partialPath ?? _activePath;
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
    final retryPath =
        '${dir.path}/vm_rec_retry_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _activePath = retryPath;
    _startedAt = DateTime.now();
    _elapsedSeconds = 0;
    _durationController.add(0);

    try {
      await _startPluginCaptureAtPath(retryPath, scheduleSilenceRetry: false);
      _recordLog('silence retry started path=$retryPath mode=measurement');
    } catch (e, st) {
      _recordLog('silence retry failed $e');
      if (kDebugMode) {
        debugPrint('$st');
      }
    }
  }

  Future<bool> get isRecording {
    if (_testMode) {
      return Future.value(_usingNativeRecorder || _activePath != null);
    }
    if (_usingNativeRecorder) {
      return Future.value(_activePath != null);
    }
    return _activeRecorder.isRecording();
  }

  void dispose() {
    _durationTimer?.cancel();
    _silenceRetryTimer?.cancel();
    _audioLevelMonitor.stop(logSummary: false);
    if (!_durationController.isClosed) {
      _durationController.close();
    }
    _recorder?.dispose();
  }
}

class RecordingException implements Exception {
  RecordingException(this.message);
  final String message;
  @override
  String toString() => message;
}
