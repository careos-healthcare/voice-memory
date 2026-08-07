import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../features/voice_capture/audio/ios_native_recorder.dart';
import '../features/voice_capture/microphone_permission_environment.dart';
import '../features/voice_capture/microphone_permission_gateway.dart';
import '../features/voice_capture/microphone_permission_state.dart';
import '../services/record_pipeline_log.dart';
import 'recording_types.dart';

void _permissionLog(String message) {
  debugPrint('RECORD: $message');
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

/// Evaluates, requests, and resolves microphone permission across OS gateways.
class MicrophonePermissionManager {
  MicrophonePermissionManager({
    MicrophonePermissionGateway? permissionGateway,
    AudioRecorder? recorder,
    bool testMode = false,
    bool? hasRecorderOverride,
  }) : _permissionGateway =
           permissionGateway ?? PermissionHandlerMicrophoneGateway(),
       _recorder = recorder,
       _testMode = testMode,
       _hasRecorderOverride = hasRecorderOverride;

  final MicrophonePermissionGateway _permissionGateway;
  final AudioRecorder? _recorder;
  final bool _testMode;
  final bool? _hasRecorderOverride;

  Future<bool> _hasRecorderPermission({bool request = false}) async {
    final override = _hasRecorderOverride;
    if (override != null) return override;
    if (_testMode) return true;
    final recorder = _recorder;
    if (recorder == null) {
      throw RecordingException('Recorder not available in test mode.');
    }
    return recorder.hasPermission(request: request);
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
      MicrophonePermissionEnvironment.logPhysicalMismatchWarning(
        status: status,
      );
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
    _permissionLog(
      'permission result hasRecorder=$hasRecorder status=$status phase=$phase',
    );
    RecordPipelineLog.microphonePermission(
      before: '$status hasRecorder=$hasRecorder',
      after: '$state',
      prefix: logPrefix,
    );
    final resolution = MicPermissionResolution(
      phase: phase,
      state: state,
      hasRecorder: hasRecorder,
      permissionHandlerStatus: status,
    );
    if (!resolution.isRecordable) {
      RecordPipelineLog.microphonePermissionBlocked(blocked: true);
    }
    return resolution;
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
    _permissionLog(
      'native permission result status=${native.status} granted=${native.granted} phase=$phase',
    );
    RecordPipelineLog.microphonePermission(
      before: 'native_status=${native.status}',
      after: '$state',
      prefix: logPrefix,
    );
    final resolution = MicPermissionResolution(
      phase: phase,
      state: state,
      hasRecorder: native.granted,
      nativePermissionStatus: native.status,
    );
    if (!resolution.isRecordable) {
      RecordPipelineLog.microphonePermissionBlocked(blocked: true);
    }
    return resolution;
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

  Future<bool> _hasRecorderPermissionAfterGrant() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      if (await _hasRecorderPermission()) return true;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return _hasRecorderPermission();
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
      _permissionLog('permission result ready (test mode)');
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
      _permissionLog(
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
    _permissionLog('permission result request=$result hasRecorder=$afterHas');
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

  /// Verifies microphone access before capture starts.
  Future<void> assertCanStartRecording({
    required bool permissionVerified,
  }) async {
    if (!permissionVerified) {
      final resolution = await evaluateMicrophonePermission();
      if (!resolution.isRecordable) {
        _permissionLog('start failed — microphone phase=${resolution.phase}');
        RecordPipelineLog.microphonePermissionBlocked(blocked: true);
        throw RecordingException(
          'Microphone not available: ${resolution.phase}',
        );
      }
      return;
    }

    if (await _usesNativeMicPermission()) {
      final resolution = await evaluateMicrophonePermission();
      if (!resolution.isRecordable) {
        _permissionLog(
          'start failed — native microphone phase=${resolution.phase}',
        );
        RecordPipelineLog.microphonePermissionBlocked(blocked: true);
        throw RecordingException(
          'Microphone not available: ${resolution.phase}',
        );
      }
      return;
    }

    final status = await _permissionGateway.status;
    await _logMicDiag(status);
    final hasRecorder = await _hasRecorderPermission();
    if (!status.isGranted && !hasRecorder) {
      _permissionLog('start failed — microphone not granted');
      RecordPipelineLog.microphonePermissionBlocked(blocked: true);
      throw RecordingException(
        'Microphone not available: ${RecordingPhase.permissionDenied}',
      );
    }
  }
}
