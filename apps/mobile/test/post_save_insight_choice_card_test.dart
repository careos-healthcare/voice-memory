import 'package:archiveme_mobile/features/first_session/first_session_pattern_category.dart';
import 'package:archiveme_mobile/features/first_session/first_session_pattern_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/widgets/record/next_evidence_prompt_card.dart';
import 'package:archiveme_mobile/widgets/record/post_save_insight_choice_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FirstSessionPattern _samplePattern() {
  return FirstSessionPattern(
    id: 'widget_test',
    createdAt: DateTime(2026, 6),
    title: 'Taking responsibility before asking for help',
    whyNoticed: 'You mentioned pressure or responsibility.',
    watchForText: 'whether you take responsibility before asking for help',
    chips: const ['saying yes fast', 'pressure'],
    confidenceLabel: FirstSessionConfidenceLabel.early,
    sourceTextPreview: 'I said yes again.',
    matchReason: 'Your words pointed toward pressure in this moment.',
    confidenceScore: 0.55,
    categoryId: 'responsibility',
    category: FirstSessionPatternCategory.responsibility,
    alternativePatterns: const [
      FirstSessionPatternAlternative(
        title: 'Fear of disappointing someone',
        whyNoticed: 'You mentioned not wanting to disappoint someone.',
        watchForText: 'whether fear of disappointing someone shows up again',
        chips: ['disappoint'],
        confidenceScore: 0.4,
        categoryId: 'relationship',
      ),
    ],
  );
}

JournalEntry _sampleEntry() {
  return JournalEntry(
    id: 'widget_test_entry',
    createdAt: DateTime(2026, 6),
    transcript:
        'I said yes to help again because I did not want to disappoint them and now I feel pressure.',
    durationSeconds: 30,
    reflection: const Reflection(
      mood: 'neutral',
      emotionalIntensity: 2,
      recurringThemes: [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
  );
}

Future<void> _pumpCard(
  WidgetTester tester, {
  Future<void> Function(String prompt)? onUsePrompt,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 1400));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PostSaveInsightChoiceCard(
            pattern: _samplePattern(),
            entry: _sampleEntry(),
            onSaveSignal: (_) async {},
            onRecordNext: () {},
            onUsePrompt: onUsePrompt,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _selectA(WidgetTester tester) async {
  await tester.tap(find.text(ConsumerUiCopy.postSaveInsightAbFeelsCloserA));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('starts with A/B read choice', (tester) async {
    await _pumpCard(tester);

    expect(
      find.text(ConsumerUiCopy.postSaveInsightAbChoiceTitle),
      findsOneWidget,
    );
    expect(
      find.text(ConsumerUiCopy.postSaveInsightAbFeelsCloserA),
      findsOneWidget,
    );
    expect(
      find.text(ConsumerUiCopy.postSaveInsightAbFeelsCloserB),
      findsOneWidget,
    );
    expect(find.text(ConsumerUiCopy.postSaveInsightAbNeither), findsOneWidget);
    expect(find.text(ConsumerUiCopy.postSaveInsightWhySuggested), findsWidgets);
    expect(find.textContaining('VoiceMemory'), findsNothing);
  });

  testWidgets('sharpness check hidden until meaningful action', (tester) async {
    await _pumpCard(tester);
    expect(
      find.text(ConsumerUiCopy.firstInsightSharpnessQuestion),
      findsNothing,
    );
  });

  testWidgets('first insight shows wedge-specific title', (tester) async {
    await _pumpCard(tester);
    expect(find.textContaining('loop'), findsOneWidget);
    expect(find.text(ConsumerUiCopy.firstInsightDisclaimer), findsOneWidget);
  });

  testWidgets('A selection shows evidence ack and next prompt card', (
    tester,
  ) async {
    await _pumpCard(tester);
    await _selectA(tester);

    expect(
      find.text(ConsumerUiCopy.firstInsightSharpnessQuestion),
      findsOneWidget,
    );
    expect(
      find.text(ConsumerUiCopy.postSaveInsightUseAsEvidence),
      findsOneWidget,
    );
    expect(
      find.text(ConsumerUiCopy.postSaveInsightRecordThisNext),
      findsOneWidget,
    );
    expect(find.text(ConsumerUiCopy.postSaveInsightGoDeeper), findsOneWidget);
  });

  testWidgets('Neither opens alternative angles', (tester) async {
    await _pumpCard(tester);

    await tester.ensureVisible(
      find.text(ConsumerUiCopy.postSaveInsightAbNeither),
    );
    await tester.tap(find.text(ConsumerUiCopy.postSaveInsightAbNeither));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text(ConsumerUiCopy.postSaveInsightAlternativeTitle),
      findsOneWidget,
    );
    expect(
      find.text(ConsumerUiCopy.postSaveInsightRecordNextEvidence),
      findsOneWidget,
    );
  });

  testWidgets('choose another prompt cycles alternatives', (tester) async {
    await _pumpCard(tester);
    await _selectA(tester);

    final promptFinder = find.descendant(
      of: find.byType(NextEvidencePromptCard),
      matching: find.byType(Text),
    );
    expect(promptFinder, findsWidgets);
    final first = tester.widget<Text>(promptFinder.at(1)).data!;

    await tester.tap(
      find.text(ConsumerUiCopy.postSaveInsightChooseAnotherPrompt),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final second = tester.widget<Text>(promptFinder.at(1)).data!;
    expect(second, isNot(equals(first)));
  });

  testWidgets('use this prompt invokes callback', (tester) async {
    String? savedPrompt;
    await _pumpCard(
      tester,
      onUsePrompt: (prompt) async {
        savedPrompt = prompt;
      },
    );
    await _selectA(tester);

    await tester.tap(find.text(ConsumerUiCopy.postSaveInsightUseThisPrompt));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(savedPrompt, isNotNull);
    expect(
      find.text(ConsumerUiCopy.postSaveInsightNextPromptSaved),
      findsOneWidget,
    );
  });

  testWidgets('go deeper shows confirm and contradict sections', (
    tester,
  ) async {
    await _pumpCard(tester);
    await _selectA(tester);

    await tester.tap(find.text(ConsumerUiCopy.postSaveInsightGoDeeper));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(ConsumerUiCopy.postSaveInsightMightMean), findsOneWidget);
    expect(
      find.text(ConsumerUiCopy.postSaveInsightWouldConfirm),
      findsOneWidget,
    );
    expect(
      find.text(ConsumerUiCopy.postSaveInsightWouldContradict),
      findsOneWidget,
    );
  });

  testWidgets('strength labels avoid percentages', (tester) async {
    await _pumpCard(tester);

    expect(find.textContaining('%'), findsNothing);
    expect(find.textContaining('confidence'), findsNothing);
  });
}