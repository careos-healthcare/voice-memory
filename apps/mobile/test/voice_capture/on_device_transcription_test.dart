import 'dart:io';

import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/capture_api_client.dart';
import 'package:archiveme_mobile/data/repositories/capture_repository.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/native_speech_transcription.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale_store.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/transcription_service.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_quality.dart';
import 'package:archiveme_mobile/security/api_usage_guard.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_path_provider.dart';
import '../support/swift_native_speech_double.dart';

/// Fails the test if anything reaches the network.
///
/// On-device-only mode has no legitimate reason to build a request, so a call
/// here is the defect rather than a wrong answer about one.
class _ForbiddenTranscribeApi implements CaptureApiClient {
  bool wasCalled = false;

  @override
  Future<ApiResult<String>> postTranscribe({
    required File audioFile,
    required int durationSeconds,
    required String captureToken,
    String? idempotencyKey,
    NetworkCancelToken? cancelToken,
  }) async {
    wasCalled = true;
    fail('on-device-only mode posted audio to /api/transcribe');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// The channel as it behaved before the locale was part of the contract.
///
/// The Dart caller sent `{audioPath, preferOnDevice}` and nothing else, so the
/// Swift guard at the top of `IosNativeSpeechTranscription.transcribe` took the
/// `localeNotSpecified` arm and returned an empty transcript for every
/// recording on every device in every locale. Kept as a double so the shape of
/// that failure stays described and asserted rather than remembered.
class _LocaleBlindNativeSpeechPlatform
    implements NativeSpeechTranscriptionPlatform {
  int callCount = 0;

  @override
  Future<Map<Object?, Object?>?> transcribeFile({
    required String audioPath,
    required bool preferOnDevice,
    required ConfirmedSpeechLocale locale,
  }) async {
    callCount += 1;
    return const {
      'transcript': '',
      'reason': 'locale_not_specified',
      'localeIdentifier': '',
    };
  }

  @override
  Future<bool> supportsOnDeviceRecognition({
    required ConfirmedSpeechLocale locale,
  }) async => true;

  @override
  Future<List<String>> supportedLocales() async => const [];
}

File _recording(String prefix) {
  return File('${Directory.systemTemp.createTempSync(prefix).path}/v.m4a')
    ..writeAsBytesSync(List.filled(VoiceCaptureQuality.minAudioBytes, 4));
}

Future<TranscriptionOutcome> _transcribe({
  required File audio,
  required ConfirmedSpeechLocale? speechLocale,
  required bool onDeviceOnly,
  required CaptureApiClient api,
}) {
  return TranscriptionService.transcribeRecording(
    audioFile: audio,
    durationSeconds: 12,
    captureRepository: CaptureRepository(
      api: api,
      requestScope: NetworkRequestScope(),
    ),
    ensureCaptureToken: ({forceRefresh = false}) async => 'token',
    scopeKey: 'on-device-${DateTime.now().microsecondsSinceEpoch}',
    usageGuard: ApiUsageGuard.shared,
    speechLocale: speechLocale,
    onDeviceOnly: onDeviceOnly,
  );
}

void main() {
  installFakePathProvider();

  final english = ConfirmedSpeechLocale.confirmed('en-GB')!;

  tearDown(() {
    NativeSpeechTranscription.testPlatform = null;
    NativeSpeechTranscription.debugPlatformOverride = null;
  });

  group('on-device-only mode produces a transcript', () {
    test('the recording is transcribed without any request', () async {
      // The regression this suite exists for. Against the previous code the
      // native path was reachable only after a remote request had already
      // failed with ApiFailureOffline, and the call it then made carried no
      // locale, so the Swift handler answered `locale_not_specified` and the
      // caller read the empty transcript as "no transcript available".
      final platform = SwiftContractNativeSpeechPlatform();
      NativeSpeechTranscription.debugPlatformOverride = 'ios';
      NativeSpeechTranscription.testPlatform = platform;
      final api = _ForbiddenTranscribeApi();

      final outcome = await _transcribe(
        audio: _recording('vm_on_device_ok_'),
        speechLocale: english,
        onDeviceOnly: true,
        api: api,
      );

      expect(outcome.succeeded, isTrue);
      expect(outcome.transcript, platform.transcript);
      expect(outcome.mode, TranscriptionMode.local);
      expect(api.wasCalled, isFalse);
    });

    test('the locale the customer confirmed is what crosses the channel',
        () async {
      final platform = SwiftContractNativeSpeechPlatform();
      NativeSpeechTranscription.debugPlatformOverride = 'ios';
      NativeSpeechTranscription.testPlatform = platform;

      await _transcribe(
        audio: _recording('vm_on_device_locale_'),
        speechLocale: ConfirmedSpeechLocale.confirmed('gu-IN'),
        onDeviceOnly: true,
        api: _ForbiddenTranscribeApi(),
      );

      expect(platform.calls.single['localeIdentifier'], 'gu-IN');
      expect(platform.calls.single['preferOnDevice'], isTrue);
    });

    test('a locale_not_specified answer yields no transcript, as it did',
        () async {
      // The defect, pinned. This is what every iOS install returned: the
      // handler refused for want of a language, the empty transcript read as
      // "unavailable", and the entry saved with no text. The fix is the locale
      // now being on the wire; the handling of a refusal is unchanged and must
      // stay a non-answer rather than becoming an empty quotation.
      final platform = _LocaleBlindNativeSpeechPlatform();
      NativeSpeechTranscription.debugPlatformOverride = 'ios';
      NativeSpeechTranscription.testPlatform = platform;

      final outcome = await _transcribe(
        audio: _recording('vm_locale_blind_'),
        speechLocale: english,
        onDeviceOnly: true,
        api: _ForbiddenTranscribeApi(),
      );

      expect(platform.callCount, 1);
      expect(outcome.succeeded, isFalse);
      expect(outcome.transcript, isNull);
      expect(outcome.failureReason, 'native_stt_unavailable');
    });

    test('the transcript is final, not provisional', () async {
      // Provisional means "the server will send a better one". In this mode no
      // request is ever made, so a provisional stamp would leave every entry
      // permanently waiting on a reconcile that cannot happen.
      NativeSpeechTranscription.debugPlatformOverride = 'ios';
      NativeSpeechTranscription.testPlatform =
          SwiftContractNativeSpeechPlatform();

      final outcome = await _transcribe(
        audio: _recording('vm_on_device_final_'),
        speechLocale: english,
        onDeviceOnly: true,
        api: _ForbiddenTranscribeApi(),
      );

      expect(outcome.isProvisional, isFalse);
    });
  });

  group('no language is ever inferred from the device', () {
    test('an unconfirmed language skips recognition instead of guessing',
        () async {
      final platform = SwiftContractNativeSpeechPlatform();
      NativeSpeechTranscription.debugPlatformOverride = 'ios';
      NativeSpeechTranscription.testPlatform = platform;

      final outcome = await _transcribe(
        audio: _recording('vm_on_device_nolocale_'),
        speechLocale: null,
        onDeviceOnly: true,
        api: _ForbiddenTranscribeApi(),
      );

      expect(outcome.succeeded, isFalse);
      expect(outcome.skippedReason, 'speech_language_not_confirmed');
      expect(
        platform.callCount,
        0,
        reason: 'the channel must not be asked to guess a language',
      );
    });

    test('an unconfirmed language does not open the network either', () async {
      // The tempting "fix" is to upload when the device cannot help. That
      // silently overrides the setting that says never to.
      NativeSpeechTranscription.debugPlatformOverride = 'ios';
      NativeSpeechTranscription.testPlatform =
          SwiftContractNativeSpeechPlatform();
      final api = _ForbiddenTranscribeApi();

      await _transcribe(
        audio: _recording('vm_on_device_nolocale_net_'),
        speechLocale: null,
        onDeviceOnly: true,
        api: api,
      );

      expect(api.wasCalled, isFalse);
    });

    test('an empty stored preference is not a language', () async {
      for (final raw in ['', '   ', 'not a locale', '123', 'e']) {
        expect(
          ConfirmedSpeechLocale.confirmed(raw),
          isNull,
          reason: 'accepted "$raw" as a confirmed language',
        );
      }
      expect(ConfirmedSpeechLocale.confirmed(null), isNull);
    });

    test('an unanswered store reads as null, not as a platform default',
        () async {
      final dir = await Directory.systemTemp.createTemp('vm_speech_locale_');
      addTearDown(() async {
        if (dir.existsSync()) await dir.delete(recursive: true);
      });
      final store = SpeechLocaleStore(
        await MobilePrefsStore.open('${dir.path}/prefs.json'),
      );

      expect(await store.read(), isNull);
      expect(await store.hasConfirmed(), isFalse);

      await store.confirm(ConfirmedSpeechLocale.confirmed('hi-IN')!);
      expect((await store.read())?.identifier, 'hi-IN');
      expect(await store.hasConfirmed(), isTrue);

      await store.clear();
      expect(await store.read(), isNull);
    });

    test('an unreadable store reads as unanswered, not as a guess', () async {
      final dir = await Directory.systemTemp.createTemp('vm_speech_locale_bad_');
      addTearDown(() async {
        if (dir.existsSync()) await dir.delete(recursive: true);
      });
      // A directory where the prefs file should be: every read throws.
      final failing = SpeechLocaleStore(MobilePrefsStore(file: File(dir.path)));
      expect(await failing.read(), isNull);
    });

    test('a stored identifier this build no longer offers reads as unanswered',
        () async {
      final dir = await Directory.systemTemp.createTemp('vm_speech_locale_old_');
      addTearDown(() async {
        if (dir.existsSync()) await dir.delete(recursive: true);
      });
      final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
      await prefs.writeJsonMap(SpeechLocaleStore.prefsKey, {
        'localeIdentifier': 'xx-YY',
      });

      expect(await SpeechLocaleStore(prefs).read(), isNull);
    });
  });

  group('uncertain recognition never becomes quotable text', () {
    Future<TranscriptionOutcome> outcomeFor(
      SwiftContractNativeSpeechPlatform platform,
      String prefix,
    ) {
      NativeSpeechTranscription.debugPlatformOverride = 'ios';
      NativeSpeechTranscription.testPlatform = platform;
      return _transcribe(
        audio: _recording(prefix),
        speechLocale: english,
        onDeviceOnly: true,
        api: _ForbiddenTranscribeApi(),
      );
    }

    test('a truncated recognition yields no transcript at all', () async {
      final outcome = await outcomeFor(
        SwiftContractNativeSpeechPlatform(
          coverage: NativeSpeechCoverageVerdict.truncated,
        ),
        'vm_trunc_',
      );

      expect(outcome.succeeded, isFalse);
      expect(outcome.transcript, isNull);
    });

    test('an unverifiable recognition yields no transcript at all', () async {
      final outcome = await outcomeFor(
        SwiftContractNativeSpeechPlatform(
          coverage: NativeSpeechCoverageVerdict.unverifiable,
        ),
        'vm_unver_',
      );

      expect(outcome.succeeded, isFalse);
      expect(outcome.transcript, isNull);
    });

    test('a timed-out recognition yields no transcript at all', () async {
      final outcome = await outcomeFor(
        SwiftContractNativeSpeechPlatform(
          coverage: NativeSpeechCoverageVerdict.timedOut,
        ),
        'vm_timeout_',
      );

      expect(outcome.succeeded, isFalse);
      expect(outcome.transcript, isNull);
    });

    test('a recogniser answering in another language yields nothing', () async {
      // `locale_mismatch`: the requested language and the recogniser's own
      // differ. This is precisely the fluent-nonsense case, and the only safe
      // response is silence.
      final outcome = await outcomeFor(
        SwiftContractNativeSpeechPlatform(resolvedLocaleOverride: 'de-DE'),
        'vm_mismatch_',
      );

      expect(outcome.succeeded, isFalse);
      expect(outcome.transcript, isNull);
    });

    test('a locale with no on-device recogniser yields nothing', () async {
      final outcome = await outcomeFor(
        SwiftContractNativeSpeechPlatform(onDeviceLanguages: const {'fr'}),
        'vm_no_on_device_',
      );

      expect(outcome.succeeded, isFalse);
      expect(outcome.transcript, isNull);
    });

    test('an unavailable recogniser yields nothing', () async {
      final outcome = await outcomeFor(
        SwiftContractNativeSpeechPlatform(recognizerAvailable: false),
        'vm_unavailable_',
      );

      expect(outcome.succeeded, isFalse);
      expect(outcome.transcript, isNull);
    });

    test('the channel is asked exactly once per recording', () async {
      // The Swift gate guarantees one delivery; nothing on this side may turn
      // a single recording into a retry loop that could deliver two answers.
      final platform = SwiftContractNativeSpeechPlatform(
        coverage: NativeSpeechCoverageVerdict.truncated,
      );
      await outcomeFor(platform, 'vm_once_');

      expect(platform.callCount, 1);
    });
  });

  group('the toggle decides the mode', () {
    test('on-device-only on an unsupported platform is disabled, not server',
        () {
      NativeSpeechTranscription.debugPlatformOverride = 'android';

      expect(
        TranscriptionService.activeMode(onDeviceOnly: true),
        TranscriptionMode.disabled,
        reason: 'the setting says never send; silence is the honest answer',
      );
    });

    test('on-device-only off keeps the server path', () {
      NativeSpeechTranscription.debugPlatformOverride = 'ios';

      expect(
        TranscriptionService.activeMode(),
        TranscriptionMode.server,
      );
    });

    test('on-device-only on iOS selects the local path', () {
      NativeSpeechTranscription.debugPlatformOverride = 'ios';

      expect(
        TranscriptionService.activeMode(onDeviceOnly: true),
        TranscriptionMode.local,
      );
    });
  });
}
