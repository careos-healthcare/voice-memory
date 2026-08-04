import 'dart:async';

class TranscriptionTimeoutException implements Exception {
  const TranscriptionTimeoutException([
    this.message = 'Speech transcription timed out after 12 seconds.',
  ]);

  final String message;

  @override
  String toString() => 'TranscriptionTimeoutException: $message';
}

class TranscriptionResult {
  const TranscriptionResult({
    required this.text,
    this.isFallbackDraft = false,
    this.audioPath,
  });

  final String text;
  final bool isFallbackDraft;
  final String? audioPath;
}

/// Wraps speech-to-text execution with a bounded wait.
///
/// The saved audio reference is retained when transcription times out or
/// fails, allowing the caller to continue with a recoverable local draft.
class ResilientTranscriptionExecutor {
  ResilientTranscriptionExecutor({this.timeoutLimit = defaultTimeoutLimit}) {
    if (timeoutLimit.isNegative) {
      throw ArgumentError.value(
        timeoutLimit,
        'timeoutLimit',
        'must not be negative',
      );
    }
  }

  static const Duration defaultTimeoutLimit = Duration(seconds: 12);
  static const String pendingTranscript =
      '[Audio recorded — transcription pending]';
  static const String failedTranscript =
      '[Audio saved locally — unable to process text]';

  final Duration timeoutLimit;

  Future<TranscriptionResult> executeWithTimeout({
    required Future<String> Function() transcriptionTask,
    required String savedAudioFilePath,
  }) async {
    try {
      final transcribedText = await transcriptionTask().timeout(
        timeoutLimit,
        onTimeout: () => throw const TranscriptionTimeoutException(),
      );

      return TranscriptionResult(
        text: transcribedText,
        audioPath: savedAudioFilePath,
      );
    } on TranscriptionTimeoutException {
      return TranscriptionResult(
        text: pendingTranscript,
        isFallbackDraft: true,
        audioPath: savedAudioFilePath,
      );
    } on TimeoutException {
      return TranscriptionResult(
        text: pendingTranscript,
        isFallbackDraft: true,
        audioPath: savedAudioFilePath,
      );
    } catch (_) {
      return TranscriptionResult(
        text: failedTranscript,
        isFallbackDraft: true,
        audioPath: savedAudioFilePath,
      );
    }
  }
}
