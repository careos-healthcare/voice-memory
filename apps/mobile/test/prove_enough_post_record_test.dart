import 'dart:io';

import 'package:archiveme_mobile/features/first_session/first_session_pattern_category.dart';
import 'package:archiveme_mobile/features/first_session/first_session_pattern_model.dart';
import 'package:archiveme_mobile/features/loop_mode/loop_mode_engine.dart';
import 'package:archiveme_mobile/features/loop_mode/loop_mode_model.dart';
import 'package:archiveme_mobile/features/prove_enough/prove_enough_post_record_engine.dart';
import 'package:archiveme_mobile/features/prove_enough/prove_enough_post_record_model.dart';
import 'package:archiveme_mobile/features/prove_enough/prove_enough_stop_cost_store.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/prove_enough/choice_vs_pressure_card.dart';
import 'package:archiveme_mobile/widgets/prove_enough/enoughness_score_card.dart';
import 'package:archiveme_mobile/widgets/prove_enough/stop_cost_prompt_card.dart';
import 'package:archiveme_mobile/widgets/record/post_save_insight_choice_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry(String id, String transcript) {
  return JournalEntry(
    id: id,
    createdAt: DateTime(2026, 6),
    transcript: transcript,
    durationSeconds: 45,
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

FirstSessionPattern _pattern() {
  return FirstSessionPattern(
    id: 'prove_test',
    createdAt: DateTime(2026, 6),
    title: 'Trying to prove enough',
    whyNoticed: 'Pressure language showed up.',
    watchForText: 'whether pressure keeps showing up',
    chips: const ['pressure', 'prove'],
    confidenceLabel: FirstSessionConfidenceLabel.early,
    sourceTextPreview: 'I kept going.',
    matchReason: 'Your words pointed toward pressure.',
    confidenceScore: 0.6,
    categoryId: 'prove_enough',
    category: FirstSessionPatternCategory.responsibility,
  );
}

ProveEnoughPostRecordModel _postRecord({
  required LoopMode loop,
  required String entryId,
  required String transcript,
}) {
  const engine = ProveEnoughPostRecordEngine();
  return engine.analyze(
    entryId: entryId,
    transcript: transcript,
    interpretationReads: const [],
    activeLoop: loop,
  );
}

Future<MobilePrefsStore> _openPrefs(String stamp) async {
  final dir = Directory('test/tmp/prove_post_record');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  final path = '${dir.path}/prefs_$stamp.json';
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
  return MobilePrefsStore.open(path);
}

Future<void> _pumpBounded(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 300));
}

/// Mirrors prove_enough post-record card stack without services or async side effects.
Widget _proveEnoughPostRecordCards({
  required ProveEnoughPostRecordModel model,
  required String entryId,
  ProveEnoughStopCostStore? stopCostStore,
  bool skipStopCostInitialLoad = true,
}) {
  return Column(
    key: const Key('prove_enough_post_record_payoff'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      EnoughnessScoreCard(model: model),
      const SizedBox(height: AppSpacing.sm),
      ChoiceVsPressureCard(model: model),
      const SizedBox(height: AppSpacing.sm),
      StopCostPromptCard(
        entryId: entryId,
        stopCostStore: stopCostStore,
        skipInitialLoad: skipStopCostInitialLoad,
      ),
    ],
  );
}

void main() {
  const engine = ProveEnoughPostRecordEngine();
  const loopEngine = LoopModeEngine();

  group('ProveEnoughPostRecordEngine', () {
    late LoopMode proveLoop;

    setUp(() {
      proveLoop = loopEngine.activate(LoopModeIds.proveEnough);
    });

    test('high pressure transcript gives high score', () {
      final model = engine.analyze(
        entryId: 'e-pressure',
        transcript:
            'I kept going even though I was tired but kept going because I felt behind and it was still not done. I had to prove I was productive and impressive. I cannot stop when I feel not enough and guilty about rest.',
        interpretationReads: const [],
        activeLoop: proveLoop,
      );

      expect(model.transcriptWeak, isFalse);
      expect(model.enoughnessScore, greaterThanOrEqualTo(66));
      expect(model.enoughnessLabel, 'Pressure looks high');
      expect(model.pressureLevel, ProveEnoughLevel.high);
      expect(model.whatLookedLikePressure, isNotEmpty);
    });

    test('choice transcript gives lower score', () {
      final model = engine.analyze(
        entryId: 'e-choice',
        transcript:
            'I wanted to finish this because I enjoyed the work and had a clear reason. I chose to stay late because it felt meaningful and I was satisfied with what I decided.',
        interpretationReads: const [],
        activeLoop: proveLoop,
      );

      expect(model.transcriptWeak, isFalse);
      expect(model.enoughnessScore, lessThanOrEqualTo(35));
      expect(model.enoughnessLabel, 'Mostly choice');
      expect(model.choiceLevel, isNot(ProveEnoughLevel.low));
      expect(model.whatLookedLikeChoice, isNotEmpty);
    });

    test('rest guilt detected', () {
      final model = engine.analyze(
        entryId: 'e-rest',
        transcript:
            'I stopped for a minute and felt guilt about rest. I thought I was being lazy and uncomfortable stopping when I should be doing more.',
        interpretationReads: const [],
        activeLoop: proveLoop,
      );

      expect(model.restGuiltPresent, isTrue);
      expect(model.restGuiltLabel, 'Present');
      expect(model.detectedStopCostTags, isNotEmpty);
    });

    test('weak transcript does not overclaim', () {
      final model = engine.analyze(
        entryId: 'e-weak',
        transcript: 'It was fine.',
        interpretationReads: const [],
        activeLoop: proveLoop,
      );

      expect(model.transcriptWeak, isTrue);
      expect(
        model.enoughnessLabel,
        'ArchiveMe needs a clearer moment to score this well.',
      );
      expect(model.whatLookedLikeChoice, isEmpty);
      expect(model.whatLookedLikePressure, isEmpty);
    });
    test('stop-cost answer persists in prefs store', () async {
      final prefs = await _openPrefs('store');
      final store = ProveEnoughStopCostStore.forPrefs(prefs);

      await store.save(entryId: 'e-stop', answer: 'I would fall behind.');

      expect(await store.load('e-stop'), 'I would fall behind.');
    });
  });

  group('prove_enough post-record UI', () {
    testWidgets('cards render for prove_enough', (tester) async {
      final loop = loopEngine.activate(LoopModeIds.proveEnough);
      const entryId = 'e-ui';
      final model = _postRecord(
        loop: loop,
        entryId: entryId,
        transcript:
            'I kept going because I felt behind and had to prove I was productive.',
      );

      await tester.binding.setSurfaceSize(const Size(390, 1600));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: _proveEnoughPostRecordCards(
                model: model,
                entryId: entryId,
              ),
            ),
          ),
        ),
      );
      await _pumpBounded(tester);

      expect(
        find.byKey(const Key('prove_enough_post_record_payoff')),
        findsOneWidget,
      );
      expect(find.text('Enoughness score'), findsOneWidget);
      expect(find.text('Choice vs pressure'), findsOneWidget);
      expect(
        find.text('What would have happened if you stopped?'),
        findsOneWidget,
      );
      expect(find.byType(EnoughnessScoreCard), findsOneWidget);
      expect(find.byType(ChoiceVsPressureCard), findsOneWidget);
      expect(find.byType(StopCostPromptCard), findsOneWidget);
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });

    testWidgets('cards do not render for capacity_yes in post-save card', (
      tester,
    ) async {
      final capacityLoop = loopEngine.activate(LoopModeIds.capacityYes);
      final entry = _entry(
        'e-capacity',
        'I said yes again even though I was already stretched thin.',
      );

      await tester.binding.setSurfaceSize(const Size(390, 1400));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PostSaveInsightChoiceCard(
                pattern: _pattern(),
                entry: entry,
                activeLoop: capacityLoop,
                onSaveSignal: (_) async {},
                onRecordNext: () {},
              ),
            ),
          ),
        ),
      );
      await _pumpBounded(tester);

      expect(
        find.byKey(const Key('prove_enough_post_record_payoff')),
        findsNothing,
      );
      expect(find.text('Enoughness score'), findsNothing);
      expect(find.text('Choice vs pressure'), findsNothing);
      expect(
        find.text('What would have happened if you stopped?'),
        findsNothing,
      );
    });

    testWidgets('stop-cost prompt tap is wired', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StopCostPromptCard(entryId: 'e-stop', skipInitialLoad: true),
          ),
        ),
      );
      await _pumpBounded(tester);

      await tester.tap(find.byKey(const Key('stop_cost_answer_cta')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Save answer'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(
        find.text('What would have happened if you stopped?'),
        findsWidgets,
      );
    });
  });
}