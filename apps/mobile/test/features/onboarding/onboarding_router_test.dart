import 'dart:io';

import 'package:archiveme_mobile/features/onboarding/onboarding_pipeline.dart';
import 'package:archiveme_mobile/features/onboarding/onboarding_router.dart';
import 'package:archiveme_mobile/features/onboarding/sample_graph_preview.dart';
import 'package:archiveme_mobile/features/onboarding/trial_completion_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('paywall follows the value steps only after the trial', () {
    expect(
      OnboardingRouter.next(
        current: OnboardingStep.valueWelcome,
        hasCompletedTrial: false,
      ),
      OnboardingStep.valueTrust,
    );
    expect(
      OnboardingRouter.next(
        current: OnboardingStep.valueTrust,
        hasCompletedTrial: false,
      ),
      OnboardingStep.trialVoice,
    );
    expect(
      OnboardingRouter.visibleSteps(
        hasCompletedTrial: false,
        saveBeyondTrialBounds: false,
      ),
      isNot(contains(OnboardingStep.paywall)),
    );
    expect(
      OnboardingRouter.next(
        current: OnboardingStep.sampleGraph,
        hasCompletedTrial: true,
      ),
      OnboardingStep.paywall,
    );
    expect(
      OnboardingRouter.next(
        current: OnboardingStep.trialVoice,
        hasCompletedTrial: false,
        saveBeyondTrialBounds: true,
      ),
      OnboardingStep.paywall,
    );
    expect(OnboardingRouter.trialWindowClosed(const Duration(seconds: 30)), isTrue);
    expect(OnboardingRouter.trialWindowClosed(const Duration(seconds: 29)), isFalse);
  });

  test('has_completed_trial is stored in local prefs', () async {
    final file = File(
      '${Directory.systemTemp.path}/trial-${DateTime.now().microsecondsSinceEpoch}.json',
    );
    final prefs = MobilePrefsStore(file: file);
    final store = PrefsTrialCompletionStore(prefs);
    expect(await store.hasCompletedTrial(), isFalse);
    await store.markTrialCompleted();
    expect(await store.hasCompletedTrial(), isTrue);
    expect(await prefs.readBool(PrefsTrialCompletionStore.key), isTrue);
    await prefs.drainPendingWrites();
    if (file.existsSync()) file.deleteSync();
  });

  test('sample search links a neighbor through the shared place', () {
    final hits = SampleGraphPreview.search('Ada');
    expect(hits.first.moment.id, 'sample-ada');
    expect(hits.map((hit) => hit.moment.id), contains('sample-sam'));
    expect(hits.first.direct, isTrue);
    expect(
      hits.singleWhere((hit) => hit.moment.id == 'sample-sam').direct,
      isFalse,
    );
  });

  testWidgets('finishing the trial opens the paywall after the sample graph', (
    tester,
  ) async {
    final store = MemoryTrialCompletionStore();
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingPipeline(
          store: store,
          paywall: const Text('Paywall step', key: Key('onboarding_paywall')),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('onboarding_value_continue')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('onboarding_value_continue')));
    await tester.pump();

    expect(find.byKey(const Key('trial_voice_prompt')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('trial_voice_field')),
      'Evenings feel quieter at the harbor.',
    );
    await tester.pump();
    expect(find.textContaining('Heard that.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('trial_voice_finish')));
    await tester.pump();
    expect(store.completed, isTrue);
    expect(find.byKey(const Key('onboarding_paywall')), findsNothing);

    await tester.tap(find.byKey(const Key('trial_voice_finish')));
    await tester.pump();
    expect(find.byKey(const Key('sample_graph_title')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('sample_graph_query')), 'Ada');
    await tester.pump();
    expect(find.byKey(const Key('sample_graph_hit_sample-ada')), findsOneWidget);

    await tester.tap(find.byKey(const Key('sample_graph_continue')));
    await tester.pump();
    expect(find.byKey(const Key('onboarding_paywall')), findsOneWidget);
  });

  testWidgets('saving during the trial opens the paywall immediately', (
    tester,
  ) async {
    final store = MemoryTrialCompletionStore();
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingPipeline(
          store: store,
          paywall: const Text('Paywall step', key: Key('onboarding_paywall')),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('onboarding_value_continue')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('onboarding_value_continue')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('trial_voice_save')));
    await tester.pump();
    expect(store.completed, isFalse);
    expect(find.byKey(const Key('onboarding_paywall')), findsOneWidget);
  });
}
