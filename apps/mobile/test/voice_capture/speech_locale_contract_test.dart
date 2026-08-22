import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/repo_file_scan.dart';

const _transcriptionDir = 'lib/features/voice_capture/transcription';

const _speechLocale = '$_transcriptionDir/speech_locale.dart';
const _speechLocaleStore = '$_transcriptionDir/speech_locale_store.dart';
const _nativeSpeech = '$_transcriptionDir/native_speech_transcription.dart';
const _transcriptionService = '$_transcriptionDir/transcription_service.dart';
const _availability = '$_transcriptionDir/local_transcription_availability.dart';
const _captureHandler =
    'lib/services/capture_pipeline/voice_capture_handler.dart';
const _appServices = 'lib/services/app_services.dart';
const _swiftHandler = 'apps/mobile/ios/Runner/IosNativeSpeechTranscription.swift';

String _source(String path) {
  final file = resolveRepoScanFile(path);
  expect(file.existsSync(), isTrue, reason: 'missing $path');
  return file.readAsStringSync();
}

/// [path]'s source with comments removed.
///
/// The bans below are on what the code does, not on prose that explains why it
/// must not: these files name `Locale.current` and `fromDeviceLocale` precisely
/// to say they are forbidden.
String _code(String path) {
  return _source(path)
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');
}

void main() {
  group('the locale cannot be omitted', () {
    test('every declaration of transcribeFile requires a locale', () {
      // A required parameter of a non-nullable type. `transcribeFile(audioPath:
      // ..., preferOnDevice: ...)` — the message that shipped, and that the
      // Swift handler answers `locale_not_specified` to — no longer compiles.
      final source = _source(_nativeSpeech);

      final declarations = RegExp(
        r'transcribeFile\(\{([\s\S]*?)\}\)',
      ).allMatches(source);
      expect(
        declarations.length,
        greaterThanOrEqualTo(2),
        reason: 'expected the interface and the method-channel implementation',
      );
      for (final match in declarations) {
        final params = match.group(1)!;
        expect(
          params,
          contains('required ConfirmedSpeechLocale locale'),
          reason: 'optional or nullable locale in: $params',
        );
        expect(
          params,
          isNot(contains('ConfirmedSpeechLocale? locale')),
        );
      }
    });

    test('the static entry point requires a locale too', () {
      final source = _source(_nativeSpeech);
      final entry = RegExp(
        r'static Future<String\?> transcribeFile\(([\s\S]*?)\)\s*async',
      ).firstMatch(source);
      expect(entry, isNotNull);
      expect(
        entry!.group(1),
        contains('required ConfirmedSpeechLocale locale'),
      );
    });

    test('the service makes each caller state an answer', () {
      // Required-but-nullable: null is a legitimate answer meaning "do not run
      // recognition", but no caller gets it by saying nothing.
      expect(
        _source(_transcriptionService),
        contains('required ConfirmedSpeechLocale? speechLocale'),
      );
    });

    test('the key the Swift handler reads is the one Dart sends', () {
      final swift = _source(_swiftHandler);
      expect(swift, contains('args["localeIdentifier"] as? String'));
      expect(_source(_nativeSpeech), contains("'localeIdentifier': locale.identifier"));
    });
  });

  group('no language is inferred from the device', () {
    const deviceLocaleReads = [
      'Platform.localeName',
      'Locale.current',
      'PlatformDispatcher.instance.locale',
      'window.locale',
      'ui.window.locale',
      'View.of(',
      'Localizations.localeOf',
      'systemLocale',
    ];

    test('the locale type and its store read nothing off the device', () {
      for (final path in [_speechLocale, _speechLocaleStore]) {
        final source = _code(path);
        for (final read in deviceLocaleReads) {
          expect(
            source,
            isNot(contains(read)),
            reason: '$path reads the device locale via $read',
          );
        }
      }
    });

    test('nothing on the transcription path substitutes a device locale', () {
      for (final path in [
        _nativeSpeech,
        _transcriptionService,
        _availability,
        _captureHandler,
      ]) {
        final source = _code(path);
        for (final read in deviceLocaleReads) {
          expect(
            source,
            isNot(contains(read)),
            reason: '$path reads the device locale via $read',
          );
        }
      }
    });

    test('there is no default and no fallback identifier in the type', () {
      final source = _code(_speechLocale);
      // The only public way to build one is `confirmed`, whose argument comes
      // from a catalogue entry the customer picked.
      expect(source, contains('const ConfirmedSpeechLocale._('));
      expect(source, isNot(contains('fromDeviceLocale')));
      expect(source, isNot(contains('defaultLocale')));
      expect(source, isNot(RegExp(r'ConfirmedSpeechLocale\.confirmed\(.+\)\s*\?\?')));
    });

    test('the catalogue is a list of choices, all of them valid identifiers',
        () {
      expect(SpeechLocaleCatalog.offered, isNotEmpty);
      for (final entry in SpeechLocaleCatalog.offered) {
        expect(
          ConfirmedSpeechLocale.confirmed(entry.identifier),
          isNotNull,
          reason: 'unofferable identifier ${entry.identifier}',
        );
        expect(entry.displayName.trim(), isNotEmpty);
        expect(entry.endonym.trim(), isNotEmpty);
      }
    });

    test('underscored identifiers normalise rather than being rejected', () {
      // Stored preferences from older code and some platform APIs use `en_GB`.
      expect(ConfirmedSpeechLocale.confirmed('en_GB')?.identifier, 'en-GB');
      expect(
        ConfirmedSpeechLocale.confirmed('en_GB'),
        ConfirmedSpeechLocale.confirmed('en-GB'),
      );
    });

    test('the primary subtag matches what the Swift comparison uses', () {
      // `IosNativeSpeechTranscription.primaryLanguageSubtag` lowercases the
      // first `-`-separated component after replacing `_`. A disagreement here
      // shows up as `locale_mismatch` on a device and nowhere in a test.
      expect(
        ConfirmedSpeechLocale.confirmed('EN-gb')!.primaryLanguageSubtag,
        'en',
      );
      expect(
        ConfirmedSpeechLocale.confirmed('pt-BR')!.primaryLanguageSubtag,
        'pt',
      );
    });
  });

  group('the production wiring supplies a locale reader', () {
    test('the capture pipeline is given the store, not left null', () {
      // The reader is nullable so an unwired pipeline degrades to "no
      // transcript" rather than to a guess — but the shipped one must be wired,
      // or on-device transcription is off for everybody again.
      expect(
        _source(_appServices),
        contains('speechLocale: SpeechLocaleStore(s.prefs).read'),
      );
    });

    test('the availability check is given the store too', () {
      expect(
        _source('lib/features/capture_flow/adapters/pipeline_capture_adapters.dart'),
        contains('confirmedLocale: speechLocaleStore.read'),
      );
    });
  });
}
