import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/first_session/first_session_pattern_category.dart';
import 'package:voicememory_mobile/features/first_session/first_session_pattern_model.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/widgets/record/post_save_insight_choice_card.dart';

FirstSessionPattern _samplePattern() {
  return FirstSessionPattern(
    id: 'widget_test',
    createdAt: DateTime(2026, 6, 1),
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
    createdAt: DateTime(2026, 6, 1),
    transcript:
        'I said yes to help again because I did not want to disappoint them and now I feel pressure.',
    durationSeconds: 30,
    reflection: Reflection(
      mood: 'neutral',
      emotionalIntensity: 2,
      recurringThemes: const [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
    syncStatus: SyncStatus.localOnly,
  );
}

Future<void> _pumpCard(
  WidgetTester tester, {
  Future<void> Function(String prompt)? onUsePrompt,
  JournalEntry? entry,
  List<JournalEntry> priorEntries = const [],
  int reflectionCount = 1,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 1400));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PostSaveInsightChoiceCard(
            pattern: _samplePattern(),
            entry: entry ?? _sampleEntry(),
            priorEntries: priorEntries,
            reflectionCount: reflectionCount,
            onSaveSignal: (_) async {},
            onRecordNext: () {},
            onRecordNextEvidence: onUsePrompt == null
                ? null
                : (prompt) {
                    onUsePrompt(prompt);
                  },
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('two related moments show one auditable comparison and question', (
    tester,
  ) async {
    final prior = JournalEntry(
      id: 'prior',
      createdAt: DateTime(2026, 6, 1),
      transcript:
          'I paused before answering the message because I wanted to check first.',
      durationSeconds: 20,
      reflection: _sampleEntry().reflection,
    );
    final latest = JournalEntry(
      id: 'latest',
      createdAt: DateTime(2026, 6, 2),
      transcript:
          'Again I paused before answering the message and checked my calendar.',
      durationSeconds: 20,
      reflection: _sampleEntry().reflection,
    );
    await _pumpCard(
      tester,
      entry: latest,
      priorEntries: [prior],
      reflectionCount: 2,
    );

    expect(find.byKey(const Key('impossible_insight_card')), findsNothing);
    expect(find.text('Possible change'), findsOneWidget);
    expect(find.textContaining('Then ·'), findsOneWidget);
    expect(find.textContaining('Now ·'), findsOneWidget);
    expect(find.text('Why ArchiveMe noticed this'), findsOneWidget);
    expect(find.text('Alternatives'), findsOneWidget);
    expect(
      find.byKey(const Key('post_save_auditable_next_question')),
      findsOneWidget,
    );
    await tester.tap(find.text('Alternatives'));
    await tester.pumpAndSettle();
    expect(find.text('Other explanations'), findsOneWidget);
  });

  testWidgets('starts with one validated evidence receipt', (tester) async {
    await _pumpCard(tester);

    expect(
      find.text(ConsumerUiCopy.postSaveInsightAbChoiceTitle),
      findsNothing,
    );
    expect(find.text('Why ArchiveMe noticed this'), findsOneWidget);
    expect(
      find.text(ConsumerUiCopy.postSaveInsightAbFeelsCloserA),
      findsNothing,
    );
    expect(
      find.byKey(const Key('explainable_conclusion_card')),
      findsOneWidget,
    );
    expect(find.textContaining('VoiceMemory'), findsNothing);
  });

  testWidgets('sharpness check hidden until meaningful action', (tester) async {
    await _pumpCard(tester);
    expect(
      find.text(ConsumerUiCopy.firstInsightSharpnessQuestion),
      findsNothing,
    );
  });

  testWidgets('first insight is one cautious possible read', (tester) async {
    await _pumpCard(tester);
    expect(find.text('Possible read'), findsOneWidget);
    expect(find.textContaining('specific to this moment'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets('receipt shows correction controls and exactly one next action', (
    tester,
  ) async {
    await _pumpCard(tester);
    expect(find.text('Accurate'), findsOneWidget);
    expect(find.text('Wrong angle'), findsOneWidget);
    expect(find.text('Too generic'), findsOneWidget);
    expect(find.text('Hide'), findsOneWidget);
    expect(
      find.byKey(const Key('post_save_auditable_record_next')),
      findsOneWidget,
    );
    expect(find.text(ConsumerUiCopy.postSaveInsightFeelsTrue), findsNothing);
  });

  testWidgets('Wrong angle opens the optional correction prompt', (
    tester,
  ) async {
    await _pumpCard(tester);

    await tester.ensureVisible(find.text('Wrong angle'));
    await tester.tap(find.text('Wrong angle'));
    await tester.pumpAndSettle();

    expect(find.text('What did ArchiveMe misunderstand?'), findsOneWidget);
    expect(
      find.byKey(const Key('explainable_correction_input')),
      findsOneWidget,
    );
  });

  testWidgets('does not manufacture rotating prompts or alternate reads', (
    tester,
  ) async {
    await _pumpCard(tester);
    expect(
      find.byKey(const Key('post_save_auditable_next_question')),
      findsOneWidget,
    );
    expect(
      find.text(ConsumerUiCopy.postSaveInsightChooseAnotherPrompt),
      findsNothing,
    );
    expect(find.text(ConsumerUiCopy.postSaveInsightNotMe), findsNothing);
  });

  testWidgets('record next invokes the single next-question callback', (
    tester,
  ) async {
    String? savedPrompt;
    await _pumpCard(
      tester,
      onUsePrompt: (prompt) async {
        savedPrompt = prompt;
      },
    );
    await tester.ensureVisible(find.text('Record another moment'));
    await tester.tap(find.text('Record another moment'));
    await tester.pump();

    expect(savedPrompt, isNotNull);
  });

  testWidgets('uncertainty and alternative stay inline without a deeper flow', (
    tester,
  ) async {
    await _pumpCard(tester);
    expect(find.byKey(const Key('explainable_uncertainty')), findsOneWidget);
    expect(
      find.byKey(const Key('explainable_alternative_inline')),
      findsOneWidget,
    );
    expect(find.text(ConsumerUiCopy.postSaveInsightGoDeeper), findsNothing);
  });

  testWidgets('strength labels avoid percentages', (tester) async {
    await _pumpCard(tester);

    expect(find.textContaining('%'), findsNothing);
    expect(find.textContaining('confidence'), findsNothing);
  });
}
