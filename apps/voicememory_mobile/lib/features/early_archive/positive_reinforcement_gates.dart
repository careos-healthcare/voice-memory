import '../beta/archive_beta_mission_gates.dart';
import '../voice_capture/record_cta_policy.dart';

/// Visibility gates for the positive reinforcement loop card.
abstract final class PositiveReinforcementGates {
  PositiveReinforcementGates._();

  static const minEntryCount = 3;

  static bool shouldShow({
    required bool loaded,
    required int entryCount,
    required bool isReady,
    required bool isRecording,
    required bool hasPositivePattern,
  }) =>
      loaded &&
      isReady &&
      !isRecording &&
      entryCount >= minEntryCount &&
      hasPositivePattern;

  static bool showRecordAgainCta({
    required RecordCtaPolicyResolution policy,
    required bool hideCardRecordButtons,
    required bool promoteMicCaptureActions,
    required bool isCompletion,
  }) =>
      !isCompletion &&
      !ArchiveBetaMissionGates.capturePrimaryCtaVisible(
        policy: policy,
        hideCardRecordButtons: hideCardRecordButtons,
        promoteMicCaptureActions: promoteMicCaptureActions,
      );
}
