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

/// One OS microphone request through permission_handler.
/// The record plugin is not asked to show its own permission dialog.
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

  bool _osAllowsCapture(PermissionStatus status) =>
      status.isGranted || status == PermissionStatus.provisional;

  /// One OS status, with no recorder-plugin prompt and no simulator override.
  Future<MicPermissionResolution> _resolutionFor(
    PermissionStatus status, {
    String logPrefix = 'check',
  }) async {
    final state = MicrophonePermissionResolver.resolve(
      status: status,
      hasRecorder: _osAllowsCapture(status),
    );
    final platform = await MicrophonePermissionEnvironment.platformLabel();
    MicrophonePermissionResolver.logPermissionSource(
      permissionHandler: status,
      recordHasPermission: _osAllowsCapture(status),
      preferRecorderOnIosSimulator: false,
      allowPhysicalRecorderMismatch: false,
      resolved: state,
      platform: platform,
    );
    final phase = MicrophonePermissionResolver.toRecordingPhase(state);
    RecordPipelineLog.micPermissionResult(
      channel: 'permission_handler',
      detail:
          'status=$status phase=$phase resolved=$state '
          'recorderPluginPrompt=false '
          'recorderBound=${_recorder != null} '
          'recorderOverride=${_hasRecorderOverride != null}',
    );
    RecordPipelineLog.microphonePermission(
      before: '$status',
      after: '$state',
      prefix: logPrefix,
    );
    final resolution = MicPermissionResolution(
      phase: phase,
      state: state,
      hasRecorder: _osAllowsCapture(status),
      permissionHandlerStatus: status,
    );
    if (!resolution.isRecordable) {
      RecordPipelineLog.microphonePermissionBlocked(blocked: true);
    }
    return resolution;
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
    return _resolutionFor(status);
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
    if (_osAllowsCapture(beforeStatus)) {
      final ready = await _resolutionFor(beforeStatus, logPrefix: 'already');
      return ready.phase;
    }
    if (beforeStatus.isPermanentlyDenied || beforeStatus.isRestricted) {
      final blocked = await _resolutionFor(
        beforeStatus,
        logPrefix: 'settings-fallback',
      );
      return blocked.phase;
    }

    RecordPipelineLog.microphonePermissionRequestShown(shown: true);
    final result = await _permissionGateway.request();
    final resolution = await _resolutionFor(result, logPrefix: 'after-request');
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
    if (!_osAllowsCapture(status)) {
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
