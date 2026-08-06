import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/loop_mode/loop_mode_engine.dart';
import 'package:voicememory_mobile/features/loop_mode/loop_mode_model.dart';
import 'package:voicememory_mobile/features/signal_review/signal_review_coordinator.dart';
import 'package:voicememory_mobile/features/signal_review/signal_review_engine.dart';
import 'package:voicememory_mobile/features/signal_review/signal_review_model.dart';
import 'package:voicememory_mobile/models/entitlement.dart'
    show BillingTier, PremiumEntitlements;
import 'package:voicememory_mobile/product/loop_mode_copy.dart';
import 'package:archiveme_research/screens/signal_review_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/widgets/loop_mode/loop_paywall_teaser_card.dart';

import 'signal_review_engine_test.dart' show entry, journey;

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_prove_review_journal_$stamp.json',
    prefsPath: '/tmp/vm_prove_review_prefs_$stamp.json',
  );
}

SignalReview _proveReview({
  SignalReviewStatus status = SignalReviewStatus.ready,
}) {
  return SignalReview(
    id: 'sr1',
    journeyId: 'j1',
    signalTitle: 'Trying to prove you are doing enough',
    reviewStatus: status,
    evidenceCount: 3,
    whatRepeated:
        'Across 3 moments, doing more because stopping felt unsafe or not enough may be repeating.',
    whatChanged: 'The same pressure to be productive may be repeating.',
    evidenceLines: const [
      'I kept working late because stopping made me feel behind.',
      'Did more tasks to prove I was doing enough even though I was tired.',
    ],
    possibleContradictions: LoopModeCopy.reviewProveWrongProveEnough,
    whatToWatchNext: LoopModeCopy.proveEnoughNextPrompts.first,
    nextEvidencePrompt: LoopModeCopy.proveEnoughNextPrompts.first,
    createdAt: DateTime(2026, 6, 3),
    updatedAt: DateTime(2026, 6, 3),
    loopModeId: LoopModeIds.proveEnough,
    loopTitle: LoopModeCopy.proveEnoughReviewTitle,
    reviewSubtitle: LoopModeCopy.proveEnoughReviewSubtitle,
    whatItSeemedToCost: 'tiredness or overload may have followed',
    commonTrigger: 'So far, this may involve feeling behind.',
    whatWouldProveThisWrong: LoopModeCopy.reviewProveWrongProveEnough,
    reviewConfidenceLabel: LoopModeCopy.reviewConfidenceWorthWatching,
  );
}

void main() {
  const engine = SignalReviewEngine();
  const loopEngine = LoopModeEngine();

  test('prove review title is loop-specific', () {
    final loop = loopEngine.activate(LoopModeIds.proveEnough);
    final review = engine.build(
      journey: journey(),
      entries: [
        entry(
          'e0',
          'I kept working late because stopping made me feel behind.',
        ),
        entry(
          'e1',
          'Did more to prove I was doing enough even though I was tired.',
        ),
        entry('e2', 'Pushed through more work because rest felt unsafe.'),
      ],
      activeLoop: loop,
    );

    expect(review, isNotNull);
    expect(review!.isProveEnoughLoopReview, isTrue);
    expect(review.loopTitle, LoopModeCopy.proveEnoughReviewTitle);
  });

  test('cost section appears from evidence', () {
    final loop = loopEngine.activate(LoopModeIds.proveEnough);
    final review = engine.build(
      journey: journey(),
      entries: [
        entry(
          'e0',
          'I was tired and kept going under pressure to be productive.',
        ),
        entry('e1', 'Felt behind and guilty about rest so I did more work.'),
        entry('e2', 'Never felt done even after a long day of output.'),
      ],
      activeLoop: loop,
    );

    expect(review!.whatItSeemedToCost, isNotEmpty);
    expect(review.whatItSeemedToCost, isNot(LoopModeCopy.reviewCostFallback));
  });

  test('trigger section appears from evidence', () {
    final loop = loopEngine.activate(LoopModeIds.proveEnough);
    final review = engine.build(
      journey: journey(),
      entries: [
        entry('e0', 'I felt behind and needed to be impressive at work.'),
        entry(
          'e1',
          'Kept going because stopping felt unsafe and unproductive.',
        ),
        entry('e2', 'Pressure to prove enough made me override rest.'),
      ],
      activeLoop: loop,
    );

    expect(review!.commonTrigger, contains('behind'));
  });

  test('prove-wrong section is specific', () {
    final loop = loopEngine.activate(LoopModeIds.proveEnough);
    final review = engine.build(
      journey: journey(),
      entries: [
        entry(
          'e0',
          'I kept working late because stopping made me feel behind.',
        ),
        entry(
          'e1',
          'Did more to prove I was doing enough even though I was tired.',
        ),
        entry('e2', 'Pushed through more work because rest felt unsafe.'),
      ],
      activeLoop: loop,
    );

    expect(
      review!.whatWouldProveThisWrong,
      LoopModeCopy.reviewProveWrongProveEnough,
    );
  });

  testWidgets('teaser copy adapts to prove_enough', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoopPaywallTeaserCard(
            shouldShow: true,
            entitlements: null,
            loopModeId: LoopModeIds.proveEnough,
            onDismissed: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text(LoopModeCopy.paywallHeadlineForLoop(LoopModeIds.proveEnough)),
      findsOneWidget,
    );
    expect(find.textContaining('proving-enough loop'), findsOneWidget);
    expect(find.textContaining('proving-enough moments'), findsOneWidget);
  });

  test('teaser hidden before confirmation', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);

    expect(
      await SignalReviewCoordinator.shouldShowLoopPaywallTeaser(
        review: _proveReview(),
        entitlements: null,
      ),
      isFalse,
    );
  });

  test('teaser hidden for Pro', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);

    expect(
      await SignalReviewCoordinator.shouldShowLoopPaywallTeaser(
        review: _proveReview(status: SignalReviewStatus.confirmed),
        entitlements: const PremiumEntitlements(
          tier: BillingTier.pro,
          entitlementIds: ['pro'],
          billingConnected: true,
          source: 'test',
        ),
      ),
      isFalse,
    );
  });

  testWidgets('prove review screen shows loop labels', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(home: SignalReviewScreen(initialReview: _proveReview())),
    );
    await tester.pump();

    expect(find.text(LoopModeCopy.proveEnoughReviewTitle), findsOneWidget);
    expect(find.text(LoopModeCopy.reviewWhatTriggeredEffort), findsOneWidget);
    expect(find.text(LoopModeCopy.reviewKeepWatchingLoop), findsOneWidget);
  });
}
