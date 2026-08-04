import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/recording/domain/services/transcription_timeout_wrapper.dart';

void main() {
  group('ResilientTranscriptionExecutor', () {
    const audioPath = '/private/audio/moment.m4a';

    test('returns successful transcription with its audio reference', () async {
      final executor = ResilientTranscriptionExecutor();

      final result = await executor.executeWithTimeout(
        transcriptionTask: () async => 'I noticed this pattern sooner.',
        savedAudioFilePath: audioPath,
      );

      expect(result.text, 'I noticed this pattern sooner.');
      expect(result.isFallbackDraft, isFalse);
      expect(result.audioPath, audioPath);
    });

    test('returns a recoverable draft when transcription stalls', () async {
      final executor = ResilientTranscriptionExecutor(
        timeoutLimit: Duration(milliseconds: 1),
      );
      final stalledTask = Completer<String>();

      final result = await executor.executeWithTimeout(
        transcriptionTask: () => stalledTask.future,
        savedAudioFilePath: audioPath,
      );

      expect(result.text, ResilientTranscriptionExecutor.pendingTranscript);
      expect(result.isFallbackDraft, isTrue);
      expect(result.audioPath, audioPath);
    });

    test('treats a task TimeoutException as pending transcription', () async {
      final executor = ResilientTranscriptionExecutor();

      final result = await executor.executeWithTimeout(
        transcriptionTask: () => throw TimeoutException('native timeout'),
        savedAudioFilePath: audioPath,
      );

      expect(result.text, ResilientTranscriptionExecutor.pendingTranscript);
      expect(result.isFallbackDraft, isTrue);
      expect(result.audioPath, audioPath);
    });

    test('preserves audio after an unexpected transcription failure', () async {
      final executor = ResilientTranscriptionExecutor();

      final result = await executor.executeWithTimeout(
        transcriptionTask: () => throw StateError('decoder unavailable'),
        savedAudioFilePath: audioPath,
      );

      expect(result.text, ResilientTranscriptionExecutor.failedTranscript);
      expect(result.isFallbackDraft, isTrue);
      expect(result.audioPath, audioPath);
    });

    test('timeout exception has a useful diagnostic string', () {
      const exception = TranscriptionTimeoutException();

      expect(exception.message, contains('12 seconds'));
      expect(exception.toString(), contains(exception.message));
    });
  });
}
