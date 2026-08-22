import 'dart:io';

import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/capture_api_client.dart';
import 'package:archiveme_mobile/data/repositories/capture_repository.dart';
import 'package:archiveme_mobile/features/voice_capture/audio/capture_audio_compressor.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/native_speech_transcription.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/transcription_service.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_quality.dart';
import 'package:archiveme_mobile/security/api_usage_guard.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_path_provider.dart';

const _spokenTranscript = 'I felt pressure before saying yes again today.';

class _FakeCompressorPlatform implements CaptureAudioCompressorPlatform {
  @override
  Future<Map<Object?, Object?>?> compress({
    required String inputPath,
    required String outputPath,
  }) async {
    await File(outputPath).writeAsBytes(List.filled(1200, 7));
    return {
      'path': outputPath,
      'compressed': true,
      'bytes': 1200,
    };
  }
}

class _FakeNativeSpeechPlatform implements NativeSpeechTranscriptionPlatform {
  @override
  Future<Map<Object?, Object?>?> transcribeFile({
    required String audioPath,
    required bool preferOnDevice,
  }) async {
    return {'transcript': _spokenTranscript, 'reason': ''};
  }
}

class _OfflineTranscribeApi implements CaptureApiClient {
  @override
  Future<ApiResult<String>> postTranscribe({
    required File audioFile,
    required int durationSeconds,
    required String captureToken,
    String? idempotencyKey,
    NetworkCancelToken? cancelToken,
  }) async {
    return const ApiFailureResult(ApiFailureOffline());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  installFakePathProvider();

  tearDown(() {
    CaptureAudioCompressor.testPlatform = null;
    NativeSpeechTranscription.testPlatform = null;
  });

  test('compressForUpload uses platform output when supported', () async {
    CaptureAudioCompressor.testPlatform = _FakeCompressorPlatform();
    final input = File(
      '${Directory.systemTemp.createTempSync('vm_compress_').path}/in.m4a',
    )..writeAsBytesSync(List.filled(VoiceCaptureQuality.minAudioBytes, 1));

    final result = await CaptureAudioCompressor.compressForUpload(input);
    expect(result.wasCompressed, isTrue);
    expect(result.file.path, isNot(input.path));
    expect(result.outputBytes, greaterThanOrEqualTo(1000));
  });

  test('offline server failure falls back to native provisional transcript', () async {
    CaptureAudioCompressor.testPlatform = _FakeCompressorPlatform();
    NativeSpeechTranscription.testPlatform = _FakeNativeSpeechPlatform();

    final audio = File(
      '${Directory.systemTemp.createTempSync('vm_offline_stt_').path}/voice.m4a',
    )..writeAsBytesSync(List.filled(VoiceCaptureQuality.minAudioBytes, 2));

    final outcome = await TranscriptionService.transcribeRecording(
      audioFile: audio,
      durationSeconds: 12,
      captureRepository: CaptureRepository(
        api: _OfflineTranscribeApi(),
        requestScope: NetworkRequestScope(),
      ),
      ensureCaptureToken: ({forceRefresh = false}) async => 'token',
      scopeKey: 'offline-native',
      usageGuard: ApiUsageGuard.shared,
    );

    expect(outcome.succeeded, isTrue);
    expect(outcome.isProvisional, isTrue);
    expect(outcome.mode, TranscriptionMode.local);
    expect(outcome.transcript, _spokenTranscript);
  });
}