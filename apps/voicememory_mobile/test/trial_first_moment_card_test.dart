import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/config/trial_mode.dart';
import 'package:voicememory_mobile/features/record/record_stack_policy.dart';
import 'package:voicememory_mobile/widgets/trial/trial_first_moment_card.dart';

/// Mirrors [decideRecordStack] trial first-moment visibility.
bool shouldShowTrialFirstMomentCard({
  required bool trialEnabled,
  required int reflectionCount,
}) {
  final d = decideRecordStack(
    hasDueCheck: false,
    isFirstRun: reflectionCount == 0,
    isTrialMode: trialEnabled,
    isRecording: false,
    hasSavedReflection: false,
    inputQualityNeedsCoach: false,
    hasCompletedResult: false,
    hasResultNextCheck: false,
    hasRoutineAnchorOffer: false,
    hasArchiveProof: false,
    archiveMemoryDemoEligible: false,
  );
  return d.showTrialFirstMomentCard;
}

void main() {
  test('shown only in trial mode before first save', () {
    expect(
      shouldShowTrialFirstMomentCard(trialEnabled: true, reflectionCount: 0),
      isTrue,
    );
    expect(
      shouldShowTrialFirstMomentCard(trialEnabled: true, reflectionCount: 1),
      isFalse,
    );
    expect(
      shouldShowTrialFirstMomentCard(trialEnabled: false, reflectionCount: 0),
      isFalse,
    );
  });

  testWidgets('trial card shows copy and start recording CTA', (tester) async {
    var started = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrialFirstMomentCard(
            onStartRecording: () => started = true,
          ),
        ),
      ),
    );

    expect(find.text('Try this once'), findsOneWidget);
    expect(find.text('Start recording'), findsOneWidget);
    expect(
      find.textContaining('pattern showed up again'),
      findsOneWidget,
    );

    await tester.tap(find.text('Start recording'));
    await tester.pump();
    expect(started, isTrue);
  });

  test('trial mode flag is compile-time (default false in tests)', () {
    expect(TrialMode.enabled, isFalse);
  });
}
