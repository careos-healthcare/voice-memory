import 'package:archiveme_mobile/features/input_quality/input_quality_engine.dart';
import 'package:archiveme_mobile/features/language/localized_copy.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/record/input_quality_coach_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    required String originalText,
    required Future<void> Function(String) onAddSentence,
    required VoidCallback onUseAnyway,
    String languageCode = 'en',
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: InputQualityCoachCard(
              result: assessReflectionQuality(originalText),
              originalText: originalText,
              onAddSentence: onAddSentence,
              onUseAnyway: onUseAnyway,
              languageCode: languageCode,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('coach card shows the make-more-useful coaching', (tester) async {
    await pumpCard(
      tester,
      originalText: 'Today was stressful.',
      onAddSentence: (_) async {},
      onUseAnyway: () {},
    );

    expect(find.text(ConsumerUiCopy.inputQualityCoachTitle), findsOneWidget);
    expect(find.text(ConsumerUiCopy.inputQualityCoachBody), findsOneWidget);
    expect(
      find.text(ConsumerUiCopy.inputQualityCoachAddSentenceCta),
      findsOneWidget,
    );
    expect(
      find.text(ConsumerUiCopy.inputQualityCoachUseAnywayCta),
      findsOneWidget,
    );
    expect(find.textContaining('Example:'), findsOneWidget);
  });

  testWidgets('coach card shows localized buttons in Spanish', (tester) async {
    await pumpCard(
      tester,
      originalText: 'Today was stressful.',
      onAddSentence: (_) async {},
      onUseAnyway: () {},
      languageCode: 'es',
    );

    expect(
      find.text(localized('inputQualityCoachTitle', 'es')),
      findsOneWidget,
    );
    expect(find.text(localized('addOneSentence', 'es')), findsOneWidget);
    expect(find.text(localized('useItAnyway', 'es')), findsOneWidget);
    // English copy must not leak through when Spanish is active.
    expect(
      find.text(ConsumerUiCopy.inputQualityCoachUseAnywayCta),
      findsNothing,
    );
  });

  testWidgets('Add one sentence combines text and continues', (tester) async {
    String? combined;
    await pumpCard(
      tester,
      originalText: 'Today was stressful.',
      onAddSentence: (text) async => combined = text,
      onUseAnyway: () {},
    );

    // First tap reveals the text field.
    await tester.tap(find.text(ConsumerUiCopy.inputQualityCoachAddSentenceCta));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      'I said yes before checking what I needed',
    );
    await tester.pump();

    // Second tap submits the combined reflection.
    await tester.tap(find.text(ConsumerUiCopy.inputQualityCoachAddSentenceCta));
    await tester.pump();

    expect(
      combined,
      'Today was stressful. I said yes before checking what I needed',
    );
  });

  testWidgets('Use it anyway continues with the original text', (tester) async {
    var used = false;
    await pumpCard(
      tester,
      originalText: 'Today was stressful.',
      onAddSentence: (_) async {},
      onUseAnyway: () => used = true,
    );

    await tester.tap(find.text(ConsumerUiCopy.inputQualityCoachUseAnywayCta));
    await tester.pump();

    expect(used, isTrue);
  });
}