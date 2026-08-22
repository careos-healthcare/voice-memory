import 'package:archiveme_mobile/features/beta/archive_beta_mission_gates.dart';
import 'package:archiveme_mobile/features/early_archive/first_week_loop_model.dart';
import 'package:archiveme_mobile/features/voice_capture/record_cta_policy.dart';

/// Visibility gates for the first-week return loop on Record ready state.
abstract final class FirstWeekLoopGates {
  FirstWeekLoopGates._();

  static bool isProRequirementGated({
    required bool valueMomentProBridgeVisible,
    required bool purchaseIntentReturnCueVisible,
  }) => valueMomentProBridgeVisible || purchaseIntentReturnCueVisible;

  static bool shouldShow({
    required bool loaded,
    required int entryCount,
    required bool isReady,
    required bool isRecording,
    required bool isPostSave,
    required bool isProRequirementGated,
    required bool policyAllows,
    FirstWeekLoop? loop,
  }) =>
      loaded &&
      isReady &&
      !isRecording &&
      !isPostSave &&
      !isProRequirementGated &&
      entryCount >= 3 &&
      policyAllows &&
      loop != null;

  static bool showRecordCta({
    required RecordCtaPolicyResolution policy,
    required bool hideCardRecordButtons,
    required bool promoteMicCaptureActions,
  }) => !ArchiveBetaMissionGates.capturePrimaryCtaVisible(
    policy: policy,
    hideCardRecordButtons: hideCardRecordButtons,
    promoteMicCaptureActions: promoteMicCaptureActions,
  );
}