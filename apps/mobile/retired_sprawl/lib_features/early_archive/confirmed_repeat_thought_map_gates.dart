import 'package:archiveme_mobile/features/beta/archive_beta_mission_gates.dart';
import 'package:archiveme_mobile/features/voice_capture/record_cta_policy.dart';

/// Visibility gates for the post-proof Thought Map card.
abstract final class ConfirmedRepeatThoughtMapGates {
  ConfirmedRepeatThoughtMapGates._();

  static const minEntryCount = 3;

  static bool shouldShow({
    required bool loaded,
    required bool viewingConfirmedRepeatOrTimeline,
    required int entryCount,
    required bool isReady,
    required bool isRecording,
    required bool hasThoughtMap,
  }) =>
      loaded &&
      isReady &&
      !isRecording &&
      entryCount >= minEntryCount &&
      viewingConfirmedRepeatOrTimeline &&
      hasThoughtMap;

  static bool showRecordMissingPieceCta({
    required RecordCtaPolicyResolution policy,
    required bool hideCardRecordButtons,
    required bool promoteMicCaptureActions,
  }) => !ArchiveBetaMissionGates.capturePrimaryCtaVisible(
    policy: policy,
    hideCardRecordButtons: hideCardRecordButtons,
    promoteMicCaptureActions: promoteMicCaptureActions,
  );
}