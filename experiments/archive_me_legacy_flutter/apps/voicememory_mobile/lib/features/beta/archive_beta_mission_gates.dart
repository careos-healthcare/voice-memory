import '../../product/consumer_ui_copy.dart';
import '../archive_proof/visible_archive_proof_copy.dart';
import '../voice_capture/record_cta_policy.dart';
import '../voice_capture/record_microphone_permission_ui.dart';
import 'archive_beta_mission_gate.dart';

/// Visibility rules for the beta mission card on Record.
abstract final class ArchiveBetaMissionGates {
  ArchiveBetaMissionGates._();

  static const confirmedRepeatEntryThreshold = 3;

  static bool shouldShow({
    required bool dismissed,
    required RecordUiState ui,
    required bool entryCountLoaded,
    required int entryCount,
    required bool isRecording,
  }) =>
      ArchiveBetaMissionGate.isEnabled &&
      !dismissed &&
      entryCountLoaded &&
      ui == RecordUiState.ready &&
      !isRecording &&
      entryCount < confirmedRepeatEntryThreshold;

  /// True when Record already exposes Save one moment / Record moment.
  static bool capturePrimaryCtaVisible({
    required RecordCtaPolicyResolution policy,
    required bool hideCardRecordButtons,
    required bool promoteMicCaptureActions,
  }) {
    if (!isDuplicateCaptureCtaLabel(policy.primaryLabel)) return false;
    if (policy.showMainBottomCta) return true;
    return !hideCardRecordButtons && promoteMicCaptureActions;
  }

  static bool isDuplicateCaptureCtaLabel(String? label) =>
      label == VisibleArchiveProofCopy.firstUseCaptureCta ||
      label == ConsumerUiCopy.recordMomentCta ||
      label == ConsumerUiCopy.recordOneMomentCta;

  static bool showMissionStartCta({
    required RecordCtaPolicyResolution policy,
    required bool hideCardRecordButtons,
    required bool promoteMicCaptureActions,
  }) => !capturePrimaryCtaVisible(
    policy: policy,
    hideCardRecordButtons: hideCardRecordButtons,
    promoteMicCaptureActions: promoteMicCaptureActions,
  );
}
