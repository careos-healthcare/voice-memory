import 'package:archiveme_mobile/audio/recording_types.dart';
import 'package:archiveme_mobile/features/voice_capture/microphone_permission_environment.dart';
import 'package:archiveme_mobile/features/voice_capture/microphone_permission_gateway.dart';
import 'package:archiveme_mobile/features/voice_capture/microphone_permission_state.dart';
import 'package:archiveme_mobile/services/record_pipeline_log.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Normalized microphone permission for voice capture.
class MicPermissionResolution {
  const MicPermissionResolution({
    required this.phase,
    required this.state,
    required this.hasRecorder,
    this.permissionHandlerStatus,
  });

  final RecordingPhase phase;
  final MicrophonePermissionState state;
  final bool hasRecorder;
  final PermissionStatus? permissionHandlerStatus;

  bool get isRecordable => MicrophonePermissionResolver.isRecordable(state);
}

/// Evaluates and requests microphone permission via permission_handler + record.
class MicrophonePermissionManager {
  MicrophonePermissionManager({
    MicrophonePermissionGateway? permissionGateway,
    this._recorder,
    this._testMode = false,
    this._hasRecorderOverride,
  }) : _permissionGateway =
           permissionGateway ?? PermissionHandlerMicrophoneGateway();

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
    RecordPipelineLog.micPermissionResult(
      channel: 'platform',
      detail:
          'hasRecorder=$hasRecorder status=$status phase=$phase resolved=$state',
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

  Future<bool> _hasRecorderPermissionAfterGrant() async {
    if (await _hasRecorderPermission()) return true;

    const pollInterval = Duration(milliseconds: 16);
    const maxWait = Duration(milliseconds: 250);
    final deadline = DateTime.now().add(maxWait);

    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(pollInterval);
      final status = await _permissionGateway.status;
      if (!status.isGranted) continue;
      if (await _hasRecorderPermission()) return true;
    }

    return _hasRecorderPermission();
  }

  Future<MicPermissionResolution> evaluateMicrophonePermission() async {
    if (_testMode &&
        _permissionGateway is! FakeMicrophonePermissionGateway &&
        _hasRecorderOverride == null) {
      return const MicPermissionResolution(
        phase: RecordingPhase.ready,
        state: MicrophonePermissionState.granted,
        hasRecorder: true,
        permissionHandlerStatus: PermissionStatus.granted,
      );
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
        _hasRecorderOverride == null) {
      RecordPipelineLog.micPermissionResult(
        channel: 'test',
        detail: 'permission result ready',
      );
      return RecordingPhase.ready;
    }

    final beforeStatus = await _permissionGateway.status;
    await _logMicDiag(beforeStatus);
    final beforeHas = await _hasRecorderPermission();

    if (await MicrophonePermissionEnvironment.shouldSkipPermissionRequest(
      status: beforeStatus,
      hasRecorder: beforeHas,
    )) {
      RecordPipelineLog.micPermissionResult(
        channel: 'platform',
        detail: 'permission request skipped — recorder verified',
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
    RecordPipelineLog.micPermissionResult(
      channel: 'platform',
      detail: 'permission request=$result hasRecorder=$afterHas',
    );
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
        RecordPipelineLog.micPermissionResult(
          channel: 'start',
          detail: 'failed phase=${resolution.phase}',
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
      RecordPipelineLog.micPermissionResult(
        channel: 'start',
        detail: 'failed microphone not granted',
      );
      RecordPipelineLog.microphonePermissionBlocked(blocked: true);
      throw RecordingException(
        'Microphone not available: ${RecordingPhase.permissionDenied}',
      );
    }
  }
}
