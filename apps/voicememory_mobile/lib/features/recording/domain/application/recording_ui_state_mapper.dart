import '../../../voice_capture/record_microphone_permission_ui.dart';
import '../../../../audio/recording_service.dart';
import '../../../../services/capture_save_messages.dart';
import '../../../voice_capture/voice_capture_copy.dart';

enum RecordingFailureKind {
  permission,
  capture,
  insufficientAudio,
  persistence,
  transcription,
}

final class RecordingUiError {
  const RecordingUiError(this.kind, this.message);

  final RecordingFailureKind kind;
  final String message;
}

abstract final class RecordingUiStateMapper {
  static RecordUiState forPermission(
    RecordingPhase phase, {
    required bool deniedByUser,
  }) {
    return RecordMicrophonePermissionUi.uiForMicPhase(
      phase: phase,
      userDeniedThisSession: deniedByUser,
    );
  }

  static RecordingUiError failure(Object error) {
    if (error is RecordingException) {
      return const RecordingUiError(
        RecordingFailureKind.capture,
        VoiceCaptureCopy.recordingFailed,
      );
    }
    if (error is RecordingAudioTooShort) {
      return const RecordingUiError(
        RecordingFailureKind.insufficientAudio,
        VoiceCaptureCopy.notEnoughAudio,
      );
    }
    if (error is RecordingPersistenceFailure) {
      return const RecordingUiError(
        RecordingFailureKind.persistence,
        VoiceCaptureCopy.saveFailed,
      );
    }
    return const RecordingUiError(
      RecordingFailureKind.transcription,
      CaptureSaveMessages.recordingSavedLocally,
    );
  }
}

final class RecordingAudioTooShort implements Exception {
  const RecordingAudioTooShort();
}

final class RecordingPersistenceFailure implements Exception {
  const RecordingPersistenceFailure([this.cause]);

  final Object? cause;
}
