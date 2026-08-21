import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_failure_mapper.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/transcription_service.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_copy.dart';
import 'package:archiveme_mobile/services/capture_save_messages.dart';

/// Normalizes capture-pipeline API errors through [ApiFailure].
abstract final class CapturePipelineApiErrors {
  CapturePipelineApiErrors._();

  static ApiFailure normalize(Object error) =>
      error is ApiFailure ? error : ApiFailureMapper.fromException(error);

  static String syncNoteFor(Object error) {
    final failure = normalize(error);
    if (failure is ApiFailureInvalidResponse) {
      return VoiceCaptureCopy.transcriptionFailedDegraded;
    }
    return CaptureSaveMessages.syncNoteFor(failure.toApiException());
  }

  static bool isInvalidResponse(Object error) =>
      normalize(error) is ApiFailureInvalidResponse;

  static String? invalidResponseMessage(Object error) {
    final failure = normalize(error);
    if (failure is ApiFailureInvalidResponse) {
      return failure.message;
    }
    return null;
  }

  static String failureReason(Object error) =>
      TranscriptionService.classifyFailureReason(
        normalize(error).toApiException(),
      );
}