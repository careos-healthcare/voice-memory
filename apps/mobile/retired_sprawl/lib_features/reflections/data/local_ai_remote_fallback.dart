import 'dart:io';

import 'package:archiveme_mobile/api/models/capture_dto.dart';
import 'package:archiveme_mobile/api/retrofit/voice_memory_capture_api.dart';

/// Remote Retrofit fallback when on-device confidence is below threshold.
class LocalAiRemoteFallback {
  LocalAiRemoteFallback(this._captureApi);

  final VoiceMemoryCaptureApi _captureApi;

  Future<LocalAiRemoteResult> transcribeAndAnalyze({
    required File audioFile,
    required int durationSeconds,
    required String captureToken,
    String? idempotencyKey,
  }) async {
    final transcribe = await _captureApi.transcribe(
      durationSeconds: '$durationSeconds',
      audio: audioFile,
      captureToken: captureToken,
      idempotencyKey: idempotencyKey,
    );

    final analyze = await _captureApi.analyze(
      {
        'transcript': transcribe.transcript,
        'durationSeconds': durationSeconds,
      },
      captureToken: captureToken,
      idempotencyKey: idempotencyKey,
    );

    return LocalAiRemoteResult(
      transcript: transcribe.transcript,
      reflection: analyze.reflection,
      confidence: 0.95,
    );
  }

  Future<LocalAiRemoteResult> analyzeTranscript({
    required String transcript,
    required int durationSeconds,
    required String captureToken,
    String? idempotencyKey,
  }) async {
    final analyze = await _captureApi.analyze(
      {
        'transcript': transcript,
        'durationSeconds': durationSeconds,
      },
      captureToken: captureToken,
      idempotencyKey: idempotencyKey,
    );

    return LocalAiRemoteResult(
      transcript: transcript,
      reflection: analyze.reflection,
      confidence: 0.95,
    );
  }
}

class LocalAiRemoteResult {
  const LocalAiRemoteResult({
    required this.transcript,
    required this.reflection,
    required this.confidence,
  });

  final String transcript;
  final ReflectionDto reflection;
  final double confidence;
}
