import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_models.dart';

/// Capture labels for the on-device Whisper path.
abstract final class OfflineTranscriptionCopy {
  OfflineTranscriptionCopy._();

  static const downloadingLocalModel = 'Downloading local model';
  static const processingOnDevice = 'Processing on-device';
}

/// Stage label for capture, including the two on-device Whisper states.
String offlineTranscriptionStageLabel(PipelineStage stage) {
  return switch (stage) {
    PipelineStage.downloadingLocalModel =>
      OfflineTranscriptionCopy.downloadingLocalModel,
    PipelineStage.processingOnDevice =>
      OfflineTranscriptionCopy.processingOnDevice,
    PipelineStage.attesting => 'Uploading audio…',
    PipelineStage.transcribing => 'Transcribing…',
    PipelineStage.analyzing => 'Reviewing your moment…',
    PipelineStage.saving => 'Saving…',
    PipelineStage.done => 'Done',
  };
}
