import 'package:archiveme_mobile/features/activation/first_three_session_gates.dart';
import 'package:archiveme_mobile/features/beta/archive_beta_mission_gates.dart';
import 'package:archiveme_mobile/features/repeat_return_check/pattern_changed_engine.dart';
import 'package:archiveme_mobile/features/voice_capture/record_cta_policy.dart';

/// Visibility gates for the pattern-changed celebration card.
abstract final class PatternChangedGates {
  PatternChangedGates._();

  static bool shouldShow({
    required bool loaded,
    required int entryCount,
    required bool isReady,
    required bool isRecording,
    required bool isPostSave,
    required bool viewingConfirmedRepeat,
    required PatternChangedResult? patternChanged,
    required bool dismissed,
  }) =>
      loaded &&
      isReady &&
      !isRecording &&
      !isPostSave &&
      entryCount > FirstThreeSessionGates.minEntriesForUsefulArchive &&
      viewingConfirmedRepeat &&
      patternChanged != null &&
      !dismissed;

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