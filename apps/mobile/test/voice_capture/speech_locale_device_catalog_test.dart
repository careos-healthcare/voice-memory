import 'package:archiveme_mobile/features/capture_flow/ui/speech_language_choice_card.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/native_speech_transcription.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A sample of what `SFSpeechRecognizer.supportedLocales()` actually reports,
/// read off the Speech framework rather than assumed. The device answers 63
/// identifiers; these are the ones the hand-maintained catalogue has no entry
/// for, which is the population this change exists for.
const _deviceOnlyIdentifiers = [
  'ar-SA',
  'ko-KR',
  'ru-RU',
  'tr-TR',
  'vi-VN',
  'th-TH',
  'pl-PL',
  'nl-NL',
  'id-ID',
  'he-IL',
  'uk-UA',
  'yue-CN',
  'el-GR',
  'sv-SE',
  'zh-TW',
];

/// The curated identifiers, which the device also reports — except `gu-IN`.
const _curatedIdentifiers = [
  'en-US',
  'en-GB',
  'en-IN',
  'es-ES',
  'es-MX',
  'fr-FR',
  'de-DE',
  'it-IT',
  'pt-BR',
  'hi-IN',
  'ja-JP',
  'zh-CN',
];

List<String> get _deviceAnswer => [
  ..._curatedIdentifiers,
  ..._deviceOnlyIdentifiers,
];

class _StubPlatform implements NativeSpeechTranscriptionPlatform {
  _StubPlatform({this.identifiers = const [], this.throws = false});

  final List<String> identifiers;
  final bool throws;

  @override
  Future<List<String>> supportedLocales() async {
    if (throws) throw MissingPluginException('supportedLocales');
    return identifiers;
  }

  @override
  Future<Map<Object?, Object?>?> transcribeFile({
    required String audioPath,
    required bool preferOnDevice,
    required ConfirmedSpeechLocale locale,
  }) async => null;

  @override
  Future<bool> supportsOnDeviceRecognition({
    required ConfirmedSpeechLocale locale,
  }) async => true;
}

void main() {
  tearDown(() {
    NativeSpeechTranscription.testPlatform = null;
    NativeSpeechTranscription.debugPlatformOverride = null;
  });

  group('the hand-maintained catalogue is the defect', () {
    test('it offers 13 languages and excludes most of what the device knows',
        () {
      expect(SpeechLocaleCatalog.offered, hasLength(13));

      // Each of these is a language in which this build offered no private
      // transcription at all: the customer had to upload audio or keep no
      // text.
      for (final identifier in _deviceOnlyIdentifiers) {
        expect(
          SpeechLocaleCatalog.entryFor(identifier),
          isNull,
          reason: '$identifier was expected to be missing from the 13',
        );
      }
    });

    test('it offers gu-IN, which the recogniser does not support', () {
      // Not merely narrow — wrong in the other direction too. A Gujarati
      // speaker can pick this and gets `locale_unsupported` and no transcript.
      // `SFSpeechRecognizer.supportedLocales()` reports no `gu` locale.
      expect(SpeechLocaleCatalog.entryFor('gu-IN'), isNotNull);
      expect(
        _deviceAnswer.any((id) => id.startsWith('gu')),
        isFalse,
        reason: 'the device reports no Gujarati recogniser',
      );
      expect(
        SpeechLocaleCatalog.offeredForDevice(_deviceAnswer)
            .map((entry) => entry.identifier),
        isNot(contains('gu-IN')),
        reason: 'the device list drops a language the recogniser lacks',
      );
    });
  });

  group('the device answer widens what is offered', () {
    test('every language the device knows becomes selectable', () {
      final offered = SpeechLocaleCatalog.offeredForDevice(_deviceAnswer);
      final identifiers = offered.map((entry) => entry.identifier).toList();

      expect(offered.length, greaterThan(SpeechLocaleCatalog.offered.length));
      for (final identifier in _deviceOnlyIdentifiers) {
        expect(identifiers, contains(identifier));
      }
    });

    test('curated names survive, so the 13 keep their endonyms', () {
      final offered = SpeechLocaleCatalog.offeredForDevice(_deviceAnswer);
      final french = offered.firstWhere((e) => e.identifier == 'fr-FR');
      expect(french.endonym, 'Français');
      expect(french.displayName, 'French');
    });

    test('a language with no curated name is still offerable', () {
      final offered = SpeechLocaleCatalog.offeredForDevice(_deviceAnswer);
      final korean = offered.firstWhere((e) => e.identifier == 'ko-KR');
      expect(korean.displayName.trim(), isNotEmpty);
      expect(korean.endonym.trim(), isNotEmpty);
      expect(korean.locale.identifier, 'ko-KR');
    });

    test('an empty answer falls back to the curated list, not an empty picker',
        () {
      expect(
        SpeechLocaleCatalog.offeredForDevice(const []),
        same(SpeechLocaleCatalog.offered),
      );
    });

    test('identifiers Dart cannot confirm are dropped rather than offered', () {
      final offered = SpeechLocaleCatalog.offeredForDevice(const [
        'en-US',
        '',
        '!!',
        'x',
      ]);
      expect(offered.map((e) => e.identifier), ['en-US']);
    });

    test('duplicates collapse', () {
      final offered = SpeechLocaleCatalog.offeredForDevice(const [
        'en-US',
        'en_US',
        'en-US',
      ]);
      expect(offered, hasLength(1));
    });
  });

  group('widening what is offered does not weaken confirmation', () {
    test('the result is a list of choices, with nothing chosen', () {
      final offered = SpeechLocaleCatalog.offeredForDevice(_deviceAnswer);
      // There is no "selected", "default", or "current" on the catalogue — the
      // only way to a ConfirmedSpeechLocale is still an entry the customer
      // taps, and each entry still has to build one through `confirmed`.
      for (final entry in offered) {
        expect(ConfirmedSpeechLocale.confirmed(entry.identifier), isNotNull);
      }
    });

    test('a device that cannot answer degrades rather than breaking', () async {
      NativeSpeechTranscription.debugPlatformOverride = 'ios';
      NativeSpeechTranscription.testPlatform = _StubPlatform(throws: true);

      expect(
        await NativeSpeechTranscription.supportedLocaleIdentifiers(),
        isEmpty,
      );
    });

    test('an unsupported platform reports no opinion', () async {
      NativeSpeechTranscription.debugPlatformOverride = 'android';
      NativeSpeechTranscription.testPlatform = _StubPlatform(
        identifiers: _deviceAnswer,
      );

      expect(
        await NativeSpeechTranscription.supportedLocaleIdentifiers(),
        isEmpty,
      );
    });

    test('a device that answers is passed through unfiltered', () async {
      NativeSpeechTranscription.debugPlatformOverride = 'ios';
      NativeSpeechTranscription.testPlatform = _StubPlatform(
        identifiers: _deviceAnswer,
      );

      expect(
        await NativeSpeechTranscription.supportedLocaleIdentifiers(),
        _deviceAnswer,
      );
    });
  });

  group('the picker offers what the device knows', () {
    Widget card({
      required Future<List<String>> Function() deviceLocales,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SpeechLanguageChoiceCard(
            onConfirmed: (_) {},
            deviceLocales: deviceLocales,
          ),
        ),
      );
    }

    testWidgets('a language outside the 13 can be selected', (tester) async {
      await tester.pumpWidget(card(deviceLocales: () async => _deviceAnswer));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('speech_language_choice_picker')));
      await tester.pumpAndSettle();

      // Korean is not in the hand-maintained catalogue, so before this change
      // there was no way to pick it and no way to get a private transcript.
      // `skipOffstage: false` because the widened menu scrolls.
      expect(find.text('ko-KR', skipOffstage: false), findsWidgets);
    });

    testWidgets('the curated list stands when the device cannot answer', (
      tester,
    ) async {
      await tester.pumpWidget(card(deviceLocales: () async => const []));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('speech_language_choice_picker')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Français'), findsWidgets);
      expect(find.text('ko-KR', skipOffstage: false), findsNothing);
    });

    testWidgets('nothing is preselected and confirm stays disabled', (
      tester,
    ) async {
      await tester.pumpWidget(card(deviceLocales: () async => _deviceAnswer));
      await tester.pumpAndSettle();

      // A wider list must not turn into a preselected one: the whole point of
      // ConfirmedSpeechLocale is that the answer is the customer's.
      final confirm = tester.widget<OutlinedButton>(
        find.byKey(const Key('speech_language_confirm')),
      );
      expect(confirm.onPressed, isNull);
    });
  });
}
