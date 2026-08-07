import '../app_review/archive_app_review_access_gate.dart';
import '../voice_capture/record_microphone_permission_ui.dart';
import 'archive_beta_mission_gate.dart';

/// Visibility rules for the beta tester mission card on Record.
abstract final class TesterMissionGates {
  TesterMissionGates._();

  static bool shouldShow({
    required bool dismissed,
    required RecordUiState ui,
    required bool entryCountLoaded,
    required bool isRecording,
    required bool isPostSave,
  }) =>
      ArchiveBetaMissionGate.isEnabled &&
      !ArchiveAppReviewAccessGate.isEnabled &&
      !dismissed &&
      entryCountLoaded &&
      ui == RecordUiState.ready &&
      !isRecording &&
      !isPostSave;

  /// Compact strip when the first-use prompt already carries step-one guidance.
  static bool useCompactPresentation({
    required int entryCount,
    required bool firstUseSimplifiedRecord,
  }) => entryCount == 0 && firstUseSimplifiedRecord;
}
