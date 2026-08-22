import 'package:archiveme_mobile/features/beta/archive_beta_mission_gates.dart';
import 'package:archiveme_mobile/features/voice_capture/record_cta_policy.dart';

/// Visibility gates for the daily return reason card.
abstract final class DailyReturnReasonGates {
  DailyReturnReasonGates._();

  static const minEntryCount = 3;

  static bool shouldShow({
    required bool loaded,
    required int entryCount,
    required bool isReady,
    required bool isRecording,
    required bool viewingConfirmedRepeatOrTimeline,
    required bool hasReason,
  }) =>
      loaded &&
      isReady &&
      !isRecording &&
      entryCount >= minEntryCount &&
      viewingConfirmedRepeatOrTimeline &&
      hasReason;

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