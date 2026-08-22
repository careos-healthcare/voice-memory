import 'dart:io';

import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/capture_api_client.dart';
import 'package:archiveme_mobile/data/repositories/capture_repository.dart';
import 'package:archiveme_mobile/features/voice_capture/audio/capture_audio_compressor.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/native_speech_transcription.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/transcription_service.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_quality.dart';
import 'package:archiveme_mobile/security/api_usage_guard.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_path_provider.dart';
import '../../support/repo_file_scan.dart';
import '../../support/swift_native_speech_double.dart';

const _androidSpeechKotlin =
    'android/app/src/main/kotlin/com/voicememory/mobile/'
    'NativeSpeechTranscription.kt';

class _FakeCompressorPlatform implements CaptureAudioCompressorPlatform {
  @override
  Future<Map<Object?, Object?>?> compress({
    required String inputPath,
    required String outputPath,
  }) async {
    await File(outputPath).writeAsBytes(List.filled(1200, 7));
    return {'path': outputPath, 'compressed': true, 'bytes': 1200};
  }
}

/// The double is [SwiftContractNativeSpeechPlatform] rather than a local fake.
///
/// The local fake this replaces implemented `transcribeFile({audioPath,
/// preferOnDevice})` — the Dart signature as it then was, which omitted the
/// locale the Swift handler requires. It agreed with the caller about a message
/// iOS rejects, so it passed while no device could ever produce a transcript.
SwiftContractNativeSpeechPlatform _spyPlatform() =>
    SwiftContractNativeSpeechPlatform();

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
    NativeSpeechTranscription.debugPlatformOverride = null;
  });

  test('native speech transcription is unsupported on Android', () {
    NativeSpeechTranscription.debugPlatformOverride = 'android';
    expect(NativeSpeechTranscription.isSupported, isFalse);

    // A registered test platform must not be able to re-open the Android path.
    NativeSpeechTranscription.testPlatform = _spyPlatform();
    expect(NativeSpeechTranscription.isSupported, isFalse);
  });

  test('native speech transcription stays supported on iOS', () {
    NativeSpeechTranscription.debugPlatformOverride = 'ios';
    expect(NativeSpeechTranscription.isSupported, isTrue);
  });

  test('transcribeFile refuses to invoke the platform channel on Android',
      () async {
    NativeSpeechTranscription.debugPlatformOverride = 'android';
    final platform = _spyPlatform();
    NativeSpeechTranscription.testPlatform = platform;

    final audio = File(
      '${Directory.systemTemp.createTempSync('vm_android_stt_').path}/v.m4a',
    )..writeAsBytesSync(List.filled(VoiceCaptureQuality.minAudioBytes, 3));

    expect(
      await NativeSpeechTranscription.transcribeFile(
        audio,
        locale: ConfirmedSpeechLocale.confirmed('en-GB')!,
      ),
      isNull,
    );
    expect(platform.callCount, 0);
  });

  test('offline server failure does not fall back to native STT on Android',
      () async {
    NativeSpeechTranscription.debugPlatformOverride = 'android';
    CaptureAudioCompressor.testPlatform = _FakeCompressorPlatform();
    final platform = _spyPlatform();
    NativeSpeechTranscription.testPlatform = platform;

    final audio = File(
      '${Directory.systemTemp.createTempSync('vm_android_off_').path}/v.m4a',
    )..writeAsBytesSync(List.filled(VoiceCaptureQuality.minAudioBytes, 2));

    final outcome = await TranscriptionService.transcribeRecording(
      audioFile: audio,
      durationSeconds: 12,
      captureRepository: CaptureRepository(
        api: _OfflineTranscribeApi(),
        requestScope: NetworkRequestScope(),
      ),
      ensureCaptureToken: ({forceRefresh = false}) async => 'token',
      scopeKey: 'android-offline-native',
      usageGuard: ApiUsageGuard.shared,
      speechLocale: ConfirmedSpeechLocale.confirmed('en-GB'),
      onDeviceOnly: false,
    );

    expect(platform.callCount, 0);
    expect(outcome.succeeded, isFalse);
    expect(outcome.isProvisional, isFalse);
    expect(outcome.mode, isNot(TranscriptionMode.local));
  });

  test('android native speech source contains no acoustic loopback', () {
    final file = resolveRepoScanFile(_androidSpeechKotlin);
    expect(file.existsSync(), isTrue, reason: 'missing $_androidSpeechKotlin');
    final source = file.readAsStringSync();

    // Playing the recording out loud so the microphone recognizer can hear it
    // exposes a private reflection to the room and (without an installed
    // offline recognizer) streams it to Google. Never reintroduce either half.
    expect(source, isNot(contains('MediaPlayer')));
    expect(source, isNot(contains('startListening')));
    expect(source, isNot(contains('createSpeechRecognizer')));
    expect(source, isNot(contains('EXTRA_PREFER_OFFLINE')));
  });
}
