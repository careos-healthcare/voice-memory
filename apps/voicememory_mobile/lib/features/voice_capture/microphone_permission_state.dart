import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../audio/recording_service.dart';
import 'audio/native_audio_recorder.dart';

/// Microphone permission state for voice capture — factual, no overclaiming.
enum MicrophonePermissionState {
  unknown,
  granted,

  /// iOS physical device: Settings/recorder say mic is available but
  /// permission_handler disagrees — record with audio-level validation.
  grantedWithPermissionHandlerMismatch,
  deniedCanAskAgain,
  deniedOpenSettings,
  unavailable,
}

abstract class MicrophonePermissionResolver {
  MicrophonePermissionResolver._();

  /// Resolves permission_handler status + [record.hasPermission()] into one state.
  ///
  /// [preferRecorderOnIosSimulator] — simulator-only override to granted.
  /// [allowPhysicalRecorderMismatch] — physical iOS when recorder confirms access
  /// but permission_handler is wrong.
  /// Physical iOS: [NativeMicrophonePermission] from AVAudioApplication.
  static MicrophonePermissionState resolveFromNative(
    NativeMicrophonePermission native,
  ) {
    if (native.granted) {
      return MicrophonePermissionState.granted;
    }
    if (native.canRequest) {
      return MicrophonePermissionState.deniedCanAskAgain;
    }
    final status = native.status.toLowerCase();
    if (status == 'undetermined' || status == 'notdetermined') {
      return MicrophonePermissionState.deniedCanAskAgain;
    }
    if (status == 'denied' || status == 'restricted') {
      return MicrophonePermissionState.deniedOpenSettings;
    }
    return MicrophonePermissionState.unavailable;
  }

  static MicrophonePermissionState resolve({
    required PermissionStatus status,
    required bool hasRecorder,
    bool preferRecorderOnIosSimulator = false,
    bool allowPhysicalRecorderMismatch = false,
  }) {
    if (preferRecorderOnIosSimulator && hasRecorder) {
      return MicrophonePermissionState.granted;
    }
    if (status.isGranted && hasRecorder) {
      return MicrophonePermissionState.granted;
    }
    if (allowPhysicalRecorderMismatch && hasRecorder && !status.isGranted) {
      return MicrophonePermissionState.grantedWithPermissionHandlerMismatch;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return MicrophonePermissionState.deniedOpenSettings;
    }
    if (status.isLimited) {
      return MicrophonePermissionState.deniedOpenSettings;
    }
    if (status.isDenied || !hasRecorder) {
      return MicrophonePermissionState.deniedCanAskAgain;
    }
    return MicrophonePermissionState.unavailable;
  }

  static RecordingPhase toRecordingPhase(MicrophonePermissionState state) {
    switch (state) {
      case MicrophonePermissionState.granted:
      case MicrophonePermissionState.grantedWithPermissionHandlerMismatch:
        return RecordingPhase.ready;
      case MicrophonePermissionState.deniedOpenSettings:
        return RecordingPhase.permissionPermanentlyDenied;
      case MicrophonePermissionState.deniedCanAskAgain:
      case MicrophonePermissionState.unknown:
        return RecordingPhase.permissionDenied;
      case MicrophonePermissionState.unavailable:
        return RecordingPhase.error;
    }
  }

  static bool isRecordable(MicrophonePermissionState state) =>
      state == MicrophonePermissionState.granted ||
      state == MicrophonePermissionState.grantedWithPermissionHandlerMismatch;

  static String resolvedLogName(MicrophonePermissionState state) {
    if (state ==
        MicrophonePermissionState.grantedWithPermissionHandlerMismatch) {
      return 'grantedWithMismatch';
    }
    return state.name;
  }

  static String trustedPermissionSource({
    required PermissionStatus status,
    required bool hasRecorder,
    required bool preferRecorderOnIosSimulator,
    required bool allowPhysicalRecorderMismatch,
  }) {
    if (preferRecorderOnIosSimulator && hasRecorder && !status.isGranted) {
      return 'record_simulator_override';
    }
    if (allowPhysicalRecorderMismatch && hasRecorder && !status.isGranted) {
      return 'record_physical_mismatch';
    }
    return 'permission_handler';
  }

  static void logPermissionSource({
    required PermissionStatus permissionHandler,
    required bool recordHasPermission,
    required bool preferRecorderOnIosSimulator,
    required bool allowPhysicalRecorderMismatch,
    required MicrophonePermissionState resolved,
    String? platform,
  }) {
    final resolvedPlatform = platform ?? 'unknown';
    final trusted = trustedPermissionSource(
      status: permissionHandler,
      hasRecorder: recordHasPermission,
      preferRecorderOnIosSimulator: preferRecorderOnIosSimulator,
      allowPhysicalRecorderMismatch: allowPhysicalRecorderMismatch,
    );
    debugPrint(
      'ARCHIVEME_MIC_PERMISSION_SOURCE platform=$resolvedPlatform '
      'permission_handler=$permissionHandler '
      'record_has_permission=$recordHasPermission trusted=$trusted '
      'resolved=${resolvedLogName(resolved)}',
    );
  }

  static void logNativePermissionSource({
    required String nativeStatus,
    required bool granted,
    required MicrophonePermissionState resolved,
    String? platform,
  }) {
    final resolvedPlatform = platform ?? 'unknown';
    debugPrint(
      'ARCHIVEME_MIC_PERMISSION_SOURCE platform=$resolvedPlatform '
      'native_status=$nativeStatus native_granted=$granted '
      'trusted=native_ios resolved=${resolvedLogName(resolved)}',
    );
  }
}
