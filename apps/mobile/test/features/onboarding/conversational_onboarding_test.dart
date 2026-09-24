import 'dart:async';

import 'package:archiveme_mobile/features/onboarding/presentation/conversational_onboarding_screen.dart';
import 'package:archiveme_mobile/features/onboarding/providers/onboarding_provider.dart';
import 'package:archiveme_mobile/features/voice/data/voice_journal_pipeline.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/widgets/archive/view_evidence_inline_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('voice answers finish onboarding and fill the home baseline', (
    tester,
  ) async {
    final speech = StreamController<String>();
    final store = MemoryOnboardingCompletionStore();
    final saved = <JournalEntry>[];
    final indexed = <List<String>>[];
    final previous = VoiceInsightHooks.index;
    VoiceInsightHooks.index = (entry, patterns) async {
      indexed.add(patterns);
    };
    addTearDown(() async {
      VoiceInsightHooks.index = previous;
      await speech.close();
    });
    final session = OnboardingSession(
      speech: speech.stream,
      store: store,
      pace: null,
      markGateComplete: () {},
      saveEntry: (entry) async => saved.add(entry),
      idFactory: _ids(),
    );
    OnboardingBaseline? finished;
    final watch = Stopwatch()..start();
    await tester.pumpWidget(
      MaterialApp(
        home: ConversationalOnboardingScreen(
          session: session,
          onFinished: (baseline) => finished = baseline,
        ),
      ),
    );
    await tester.pump();
    expect(find.text(onboardingPrompts.first), findsOneWidget);
    expect(await store.isComplete(), isFalse);

    speech.add('I want a quieter place to keep what matters.');
    await tester.pump();
    speech.add('I would like to feel settled and clear.');
    await tester.pump();
    speech.add('This baseline is a calmer evening routine.');
    await tester.pump();
    await tester.pump();
    watch.stop();

    expect(watch.elapsed, lessThan(const Duration(seconds: 30)));
    expect(finished, isNotNull);
    expect(finished!.isOnboardingBaseline, isTrue);
    expect(await store.isComplete(), isTrue);
    expect(saved, hasLength(2));
    expect(
      saved.every(
        (entry) => entry.display.captureContextTag == onboardingBaselineTag,
      ),
      isTrue,
    );
    expect(saved.first.captureSource, 'onboarding_core_memory');
    expect(saved.last.captureSource, 'onboarding_life_patterns');
    expect(indexed, isNotEmpty);
    expect(finished!.lifePatterns, isNotEmpty);

    var sawEvidence = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingBaselineHome(
          baseline: finished!,
          onViewEvidence: () => sawEvidence = true,
        ),
      ),
    );
    expect(find.text('Core Memory'), findsOneWidget);
    expect(find.text('Life Patterns'), findsOneWidget);
    expect(find.textContaining('quieter place'), findsWidgets);
    await tester.tap(find.byType(ViewEvidenceInlineLink));
    await tester.pump();
    expect(sawEvidence, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: ConversationalOnboardingScreen(
          session: OnboardingSession(
            store: store,
            pace: null,
            markGateComplete: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('onboarding_prompt')), findsNothing);
    expect(find.byKey(const Key('onboarding_home')), findsOneWidget);
  });

  testWidgets('skip or type records a baseline without the microphone', (
    tester,
  ) async {
    final store = MemoryOnboardingCompletionStore();
    final saved = <JournalEntry>[];
    final session = OnboardingSession(
      store: store,
      pace: null,
      markGateComplete: () {},
      saveEntry: (entry) async => saved.add(entry),
      idFactory: _ids(),
    );
    OnboardingBaseline? finished;
    final watch = Stopwatch()..start();
    await tester.pumpWidget(
      MaterialApp(
        home: ConversationalOnboardingScreen(
          session: session,
          onFinished: (baseline) => finished = baseline,
        ),
      ),
    );
    await tester.pump();

    await _typeStep(tester, 'Work has been loud and I need a quieter evening.');
    await _typeStep(tester, 'I would like to feel calm when the day ends.');
    await _typeStep(tester, 'Keep this as the starting baseline.');
    await tester.pump();
    watch.stop();

    expect(watch.elapsed, lessThan(const Duration(seconds: 30)));
    expect(finished, isNotNull);
    expect(finished!.coreMemory, contains('quieter evening'));
    expect(finished!.lifePatterns, isNotEmpty);
    expect(saved, hasLength(2));
    expect(
      saved.every(
        (entry) => entry.display.captureContextTag == 'is_onboarding_baseline',
      ),
      isTrue,
    );
    expect(await store.isComplete(), isTrue);
    expect(find.byKey(const Key('onboarding_home')), findsOneWidget);
    expect(find.text('Life Patterns'), findsOneWidget);
  });
}

Future<void> _typeStep(WidgetTester tester, String line) async {
  await tester.tap(find.byKey(const Key('onboarding_skip_type')));
  await tester.pump();
  await tester.enterText(find.byKey(const Key('onboarding_type_field')), line);
  await tester.tap(find.byKey(const Key('onboarding_type_submit')));
  await tester.pump();
}

String Function() _ids() {
  var count = 0;
  return () {
    count += 1;
    return 'baseline-$count';
  };
}
