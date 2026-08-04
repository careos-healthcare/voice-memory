import 'package:permission_handler/permission_handler.dart';

import '../../../../audio/recording_service.dart';
import '../../../voice_capture/microphone_permission_gateway.dart';
import '../../../voice_capture/microphone_permission_state.dart';
import '../../../voice_capture/onboarding_microphone_state.dart';

final class RecordingPermissionResult {
  const RecordingPermissionResult({
    required this.phase,
    required this.state,
    required this.deniedByUser,
    required this.requiresSettings,
  });

  final RecordingPhase phase;
  final MicrophonePermissionState state;
  final bool deniedByUser;
  final bool requiresSettings;

  bool get canRecord => phase == RecordingPhase.ready;
}

final class RecordingPermissionCoordinator {
  RecordingPermissionCoordinator({
    required this.recording,
    required this.gateway,
    required this.stateStore,
  });

  final RecordingService recording;
  final MicrophonePermissionGateway gateway;
  final OnboardingMicStateStore stateStore;

  Future<RecordingPermissionResult> refresh({
    bool requestedByUser = false,
  }) async {
    final resolution = await recording.evaluateMicrophonePermission();
    return _persist(resolution, requestedByUser: requestedByUser);
  }

  Future<RecordingPermissionResult> request() async {
    await recording.requestMicrophone();
    return refresh(requestedByUser: true);
  }

  Future<RecordingPermissionResult> refreshAfterResume() async {
    final status = await gateway.status;
    if (status.isGranted) return refresh();
    if (status.isPermanentlyDenied || status.isRestricted || status.isLimited) {
      await stateStore.write(OnboardingMicState.permanentlyDenied);
    }
    return refresh();
  }

  Future<RecordingPermissionResult> _persist(
    MicPermissionResolution resolution, {
    required bool requestedByUser,
  }) async {
    final denied = resolution.phase == RecordingPhase.permissionDenied;
    final permanentlyDenied =
        resolution.phase == RecordingPhase.permissionPermanentlyDenied;
    await stateStore.write(
      resolution.phase == RecordingPhase.ready
          ? OnboardingMicState.granted
          : permanentlyDenied
          ? OnboardingMicState.permanentlyDenied
          : OnboardingMicState.denied,
    );
    return RecordingPermissionResult(
      phase: resolution.phase,
      state: resolution.state,
      deniedByUser: requestedByUser && denied,
      requiresSettings: permanentlyDenied || (requestedByUser && denied),
    );
  }
}
