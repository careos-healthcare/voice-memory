import 'package:archiveme_mobile/features/voice_capture/recording_locale_picker.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale.dart';
import 'package:archiveme_mobile/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('device locale becomes the STT locale and sherpa model', () {
    final selection = RecordingLocalePickerLogic.selection(
      device: const Locale('zh', 'CN'),
      offered: SpeechLocaleCatalog.offered,
      supportedOnDevice: {'zh-CN', 'en-US'},
    );

    expect(selection.locale?.identifier, 'zh-CN');
    expect(selection.sherpaModelId, 'vits-zh');
    expect(selection.canTranscribeOnDevice, isTrue);
  });

  test('an unsupported device locale stays unselected', () {
    final selection = RecordingLocalePickerLogic.selection(
      device: const Locale('ta', 'SG'),
      offered: SpeechLocaleCatalog.offered,
      supportedOnDevice: {'en-US', 'zh-CN', 'hi-IN'},
    );

    expect(selection.locale, isNull);
    expect(selection.sherpaModelId, isNull);
    expect(selection.unsupportedMessage, contains('ta-SG'));
    expect(
      selection.unsupportedMessage,
      'ta-SG is not supported for on-device transcription. Pick another language.',
    );
  });

  testWidgets('locale switch changes the UI string in one text widget', (
    tester,
  ) async {
    Future<void> pump(Locale locale) {
      return tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              return Directionality(
                textDirection: TextDirection.rtl,
                child: Text(l10n.appTitle),
              );
            },
          ),
        ),
      );
    }

    await pump(const Locale('en'));
    expect(find.text('Thoughtprint'), findsOneWidget);
    final english = tester.widget<Text>(find.text('Thoughtprint'));
    expect(english.data, 'Thoughtprint');

    await pump(const Locale('zh', 'Hans'));
    expect(find.byType(Text), findsOneWidget);
    final chinese = tester.widget<Text>(find.byType(Text));
    expect(chinese.data, isNotNull);
    expect(chinese.data!.contains(' + '), isFalse);
  });

  testWidgets('unsupported message is one run of text', (tester) async {
    const selection = RecordingLocaleSelection(
      unsupportedMessage:
          'ta-SG is not supported for on-device transcription. Pick another language.',
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: RecordingLocaleMessage(selection: selection),
        ),
      ),
    );
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.data, selection.unsupportedMessage);
  });
}
