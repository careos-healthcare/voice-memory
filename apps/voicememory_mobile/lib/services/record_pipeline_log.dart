import 'package:flutter/foundation.dart';

/// Debug logging for the voice capture pipeline — filter logs with
/// `ARCHIVEME_RECORD_PIPELINE:`.
abstract class RecordPipelineLog {
  RecordPipelineLog._();

  static void log(String message) {
    debugPrint('ARCHIVEME_RECORD_PIPELINE: $message');
  }

  static void permission({required String status}) {
    log('permission status=$status');
  }

  static void microphonePermission({
    required String before,
    required String after,
    String prefix = 'check',
  }) {
    log('microphone permission $prefix before=$before after=$after');
  }

  static void microphonePermissionRequestShown({required bool shown}) {
    log('microphone permission request shown=$shown');
  }

  static void microphonePermissionBlocked({required bool blocked}) {
    log('microphone permission blocked recording=$blocked');
  }

  static void recorderStart({required bool success, String? detail}) {
    log(
      'recorder start success=$success'
      '${detail == null ? '' : ' detail=$detail'}',
    );
  }

  static void audioFile({
    required String path,
    required bool exists,
    required int byteLength,
  }) {
    log('audio file pathProvided=${path.trim().isNotEmpty}');
    log('audio file exists=$exists');
    log('audio file byteLength=$byteLength');
  }

  static void transcriptLengths({
    required int transcriptLength,
    required int bodyLength,
    required int observationLength,
    required int exactLanguageLength,
  }) {
    log('transcript length=$transcriptLength');
    log('body length=$bodyLength');
    log('observation length=$observationLength');
    log('exactLanguage length=$exactLanguageLength');
  }

  static void savedEntry({
    required String entryId,
    required int displayTextLength,
  }) {
    log('saved entry id=$entryId');
    log('saved entry display text length=$displayTextLength');
  }

  static void rejectInsufficientAudio({required int byteLength}) {
    log('rejecting capture — insufficient audio byteLength=$byteLength');
  }

  static void apiGuardBlocked({
    required String operation,
    required String reason,
  }) {
    log('api guard blocked operation=$operation reason=$reason');
  }

  static void preSaveFinalTranscript({required int length}) {
    log('pre_save final_transcript length=$length');
  }

  static void persistedCaptureText({
    required int transcriptLength,
    required int bodyLength,
    required String displayTextSource,
  }) {
    log('persisted transcript length=$transcriptLength');
    log('persisted body length=$bodyLength');
    log('saved entry display text source=$displayTextSource');
  }

  static void voiceSavedTranscriptMissing() {
    log('voice_saved_transcript_missing=true');
  }

  static void voiceSavedTranscriptPresent() {
    log('voice_saved_transcript_missing=false');
  }

  static void typedTextAttachedToVoiceEntry({required String entryId}) {
    log('typed_text_attached_to_voice_entry=true entry_id=$entryId');
  }

  static void typedFallbackInsightShown() {
    log('typed_fallback_insight_shown=true');
  }

  static void transcriptionFallback({
    required String reason,
    required String audioPath,
  }) {
    log(
      'transcription_fallback reason=${_reasonCode(reason)} '
      'audio_path_provided=${audioPath.trim().isNotEmpty}',
    );
  }

  static void analysisFailed({required String reason}) {
    log('analysis_failed reason=${_reasonCode(reason)}');
  }

  static void analysisFallback({
    required String reason,
    required String audioPath,
  }) {
    log(
      'analysis_fallback reason=${_reasonCode(reason)} '
      'audio_path_provided=${audioPath.trim().isNotEmpty}',
    );
  }

  static void postSaveComparisonSkipped({required String reason}) {
    log('post_save_comparison skipped reason=$reason');
  }

  static String _reasonCode(String value) {
    final category = value.split(':').first;
    final normalized = category
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '_')
        .replaceAll(RegExp('^_+|_+\$'), '');
    if (normalized.isEmpty) return 'unknown';
    return normalized.substring(0, normalized.length.clamp(0, 64));
  }
}
