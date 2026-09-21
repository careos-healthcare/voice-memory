import 'package:archiveme_mobile/features/voice_capture/voice_capture_copy.dart';

/// Optional remote-processing status shown beneath the local save receipt.
enum MomentSaveRemoteStatus {
  /// Remote work not attempted or not applicable (local-only consent).
  none,

  /// Remote transcription or reflection still in progress.
  pending,

  /// Remote work failed after consent; local save succeeded.
  failedRetryable,
}

/// Maps capture pipeline outcomes to receipt remote status.
MomentSaveRemoteStatus resolveMomentSaveRemoteStatus({
  required bool analysisSucceeded,
  required String? syncNote,
}) {
  final note = syncNote?.trim() ?? '';
  if (analysisSucceeded || note.isEmpty) {
    return MomentSaveRemoteStatus.none;
  }
  if (note == VoiceCaptureCopy.remoteProcessingConsentPausedNote ||
      note.contains('Turn on remote analysis') ||
      note.contains('stays on this device only') ||
      note.contains('was not sent for a deeper read')) {
    return MomentSaveRemoteStatus.none;
  }
  if (note == VoiceCaptureCopy.analysisUnavailableNote) {
    return MomentSaveRemoteStatus.failedRetryable;
  }
  if (note.contains('still running')) {
    return MomentSaveRemoteStatus.pending;
  }
  return MomentSaveRemoteStatus.failedRetryable;
}
