import 'package:voicememory_mobile/features/voice_capture/record_microphone_permission_ui.dart';
import 'record_view_state.dart';

/// Maps legacy [RecordUiState] to the V1 [RecordViewPhase] machine.
abstract final class RecordViewStateMapper {
  RecordViewStateMapper._();

  static RecordViewPhase phaseFromUi(
    RecordUiState ui, {
    bool hasVerifiedProof = false,
    String? savedEntryId,
    String? errorMessage,
  }) {
    return switch (ui) {
      RecordUiState.idle => RecordViewPhase.idle,
      RecordUiState.requestingPermission => RecordViewPhase.requestingPermission,
      RecordUiState.permissionBlocked => RecordViewPhase.requestingPermission,
      RecordUiState.ready => RecordViewPhase.ready,
      RecordUiState.recording => RecordViewPhase.recording,
      RecordUiState.processing => RecordViewPhase.processing,
      RecordUiState.done when hasVerifiedProof => RecordViewPhase.verifiedResultAvailable,
      RecordUiState.done => savedEntryId != null
          ? RecordViewPhase.locallySaved
          : RecordViewPhase.localOnlyResult,
      RecordUiState.error => RecordViewPhase.recoverableError,
    };
  }

  static RecordViewState fromUi({
    required RecordUiState ui,
    Duration recordingDuration = Duration.zero,
    String? statusMessage,
    String? errorMessage,
    String? savedEntryId,
    bool hasVerifiedProof = false,
  }) {
    return RecordViewState(
      phase: phaseFromUi(
        ui,
        hasVerifiedProof: hasVerifiedProof,
        savedEntryId: savedEntryId,
        errorMessage: errorMessage,
      ),
      recordingDuration: recordingDuration,
      statusMessage: statusMessage,
      errorMessage: errorMessage,
      savedEntryId: savedEntryId,
      hasVerifiedProof: hasVerifiedProof,
    );
  }
}
