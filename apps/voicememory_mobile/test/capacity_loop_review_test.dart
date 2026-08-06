import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/loop_mode/loop_mode_coordinator.dart';
import 'package:voicememory_mobile/features/loop_mode/loop_mode_engine.dart';
import 'package:voicememory_mobile/features/loop_mode/loop_mode_model.dart';
import 'package:voicememory_mobile/features/signal_review/signal_review_coordinator.dart';
import 'package:voicememory_mobile/features/signal_review/signal_review_engine.dart';
import 'package:voicememory_mobile/features/signal_review/signal_review_model.dart';
import 'package:voicememory_mobile/features/signal_review/signal_review_store.dart';
import 'package:voicememory_mobile/models/entitlement.dart'
    show BillingTier, PremiumEntitlements;
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/product/loop_mode_copy.dart';
import 'package:archiveme_research/screens/signal_review_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/widgets/loop_mode/loop_paywall_teaser_card.dart';
import 'package:voicememory_mobile/widgets/signal/signal_review_card.dart';

import 'signal_review_engine_test.dart' show entry, journey;

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_capacity_review_journal_$stamp.json',
    prefsPath: '/tmp/vm_capacity_review_prefs_$stamp.json',
  );
}

SignalReview _capacityReview({
  SignalReviewStatus status = SignalReviewStatus.ready,
}) {
  return SignalReview(
    id: 'sr1',
    journeyId: 'j1',
    signalTitle: 'Saying yes before checking capacity',
    reviewStatus: status,
    evidenceCount: 3,
    whatRepeated:
        'Across 3 moments, agreeing, helping, or taking something on before checking room or capacity may be repeating.',
    whatChanged: 'The same pressure may be repeating across these moments.',
    evidenceLines: const [
      'I said yes again even though I was already stretched thin.',
      'Another yes while already full from earlier commitments.',
    ],
    possibleContradictions: LoopModeCopy.reviewProveWrongCapacity,
    whatToWatchNext: LoopModeCopy.capacityNextPrompts.first,
    nextEvidencePrompt: LoopModeCopy.capacityNextPrompts.first,
    createdAt: DateTime(2026, 6, 3),
    updatedAt: DateTime(2026, 6, 3),
    loopModeId: LoopModeIds.capacityYes,
    loopTitle: LoopModeCopy.capacityReviewTitle,
    reviewSubtitle: LoopModeCopy.capacityReviewSubtitle,
    whatItSeemedToCost: 'pressure may have shown up afterward',
    commonTrigger: 'So far, this may involve pressure.',
    whatWouldProveThisWrong: LoopModeCopy.reviewProveWrongCapacity,
    reviewConfidenceLabel: LoopModeCopy.reviewConfidenceWorthWatching,
  );
}

void main() {
  const engine = SignalReviewEngine();
  const loopEngine = LoopModeEngine();

  test('capacity_yes review uses loop-specific title', () {
    final loop = loopEngine.activate(LoopModeIds.capacityYes);
    final review = engine.build(
      journey: journey(),
      entries: [
        entry(
          'e0',
          'I said yes again even though I was already stretched thin.',
        ),
        entry('e1', 'Another yes while already full from earlier commitments.'),
        entry('e2', 'Said yes before checking whether I had capacity left.'),
      ],
      activeLoop: loop,
    );

    expect(review, isNotNull);
    expect(review!.isCapacityLoopReview, isTrue);
    expect(review.loopTitle, LoopModeCopy.capacityReviewTitle);
    expect(review.reviewSubtitle, LoopModeCopy.capacityReviewSubtitle);
  });

  test('cost section appears from evidence', () {
    final loop = loopEngine.activate(LoopModeIds.capacityYes);
    final review = engine.build(
      journey: journey(),
      entries: [
        entry('e0', 'I said yes under pressure and felt tired afterward.'),
        entry('e1', 'Agreed to help and felt guilt about disappointing them.'),
        entry('e2', 'Said yes before checking time and fell behind.'),
      ],
      activeLoop: loop,
    );

    expect(review!.whatItSeemedToCost, isNotEmpty);
    expect(review.whatItSeemedToCost, isNot(LoopModeCopy.reviewCostFallback));
  });

  test('cost fallback when evidence thin', () {
    final sections = loopEngine.buildCapacityReviewSections(
      journey: journey(),
      entries: [
        entry('e0', 'yes ok'),
        entry('e1', 'sure thing'),
        entry('e2', 'agreed again'),
      ],
    );
    expect(sections.whatItSeemedToCost, LoopModeCopy.reviewCostFallback);
  });

  test('trigger section appears from evidence', () {
    final loop = loopEngine.activate(LoopModeIds.capacityYes);
    final review = engine.build(
      journey: journey(),
      entries: [
        entry('e0', 'I did not want to disappoint my manager so I said yes.'),
        entry('e1', 'Took responsibility automatically and agreed to help.'),
        entry('e2', 'Hard to say no so I agreed before checking capacity.'),
      ],
      activeLoop: loop,
    );

    expect(review!.commonTrigger, contains('disappoint'));
  });

  test('contradiction section is loop-specific', () {
    final loop = loopEngine.activate(LoopModeIds.capacityYes);
    final review = engine.build(
      journey: journey(),
      entries: [
        entry(
          'e0',
          'I said yes again even though I was already stretched thin.',
        ),
        entry('e1', 'Another yes while already full from earlier commitments.'),
        entry('e2', 'Said yes before checking whether I had capacity left.'),
      ],
      activeLoop: loop,
    );

    expect(
      review!.whatWouldProveThisWrong,
      LoopModeCopy.reviewProveWrongCapacity,
    );
  });

  test('next prompt is capacity-specific', () {
    final loop = loopEngine.activate(LoopModeIds.capacityYes);
    final review = engine.build(
      journey: journey(),
      entries: [
        entry(
          'e0',
          'I said yes again even though I was already stretched thin.',
        ),
        entry('e1', 'Another yes while already full from earlier commitments.'),
        entry('e2', 'Said yes before checking whether I had capacity left.'),
      ],
      activeLoop: loop,
    );

    expect(
      LoopModeCopy.capacityNextPrompts,
      contains(review!.nextEvidencePrompt),
    );
  });

  test('confirm saves loop completion', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await LoopModeCoordinator.activate(LoopModeIds.capacityYes);

    final store = SignalReviewStore.instance();
    final review = _capacityReview();
    await store.saveActive(review);

    final confirmed = await SignalReviewCoordinator.confirm(
      reviewId: review.id,
    );
    expect(confirmed!.reviewStatus, SignalReviewStatus.confirmed);

    final loop = await LoopModeCoordinator.loadActive();
    expect(loop?.completed, isTrue);
  });

  test('correct shows loop-specific alternatives', () {
    final alts = engine.correctionAlternatives(
      review: _capacityReview(),
      feedback: const [],
    );
    expect(alts, LoopModeCopy.capacityCorrectionAlternatives);
  });

  test('keep watching sets next prompt', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await LoopModeCoordinator.activate(LoopModeIds.capacityYes);

    final store = SignalReviewStore.instance();
    await store.saveActive(_capacityReview());

    final watching = await SignalReviewCoordinator.keepWatching(
      reviewId: 'sr1',
    );
    expect(watching!.reviewStatus, SignalReviewStatus.watching);
    expect(
      LoopModeCopy.capacityNextPrompts,
      contains(watching.nextEvidencePrompt),
    );
  });

  test('soft paywall teaser appears only after confirmed review', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);

    expect(
      await SignalReviewCoordinator.shouldShowLoopPaywallTeaser(
        review: _capacityReview(),
        entitlements: null,
      ),
      isFalse,
    );

    final store = SignalReviewStore.instance();
    await store.saveActive(
      _capacityReview(status: SignalReviewStatus.confirmed),
    );

    expect(
      await SignalReviewCoordinator.shouldShowLoopPaywallTeaser(
        review: _capacityReview(status: SignalReviewStatus.confirmed),
        entitlements: null,
      ),
      isTrue,
    );
  });

  test('teaser hidden for Pro', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);

    expect(
      await SignalReviewCoordinator.shouldShowLoopPaywallTeaser(
        review: _capacityReview(status: SignalReviewStatus.confirmed),
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

  testWidgets('capacity review screen shows loop labels', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(home: SignalReviewScreen(initialReview: _capacityReview())),
    );
    await tester.pump();

    expect(find.text(LoopModeCopy.capacityReviewTitle), findsOneWidget);
    expect(find.text(LoopModeCopy.reviewWhatRepeated), findsOneWidget);
    expect(find.text(LoopModeCopy.reviewWhatItCost), findsOneWidget);
    expect(find.text(LoopModeCopy.reviewWhatTriggeredYes), findsOneWidget);
    expect(find.text(LoopModeCopy.reviewKeepWatchingLoop), findsOneWidget);
  });

  testWidgets('paywall teaser hidden before confirmation', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(home: SignalReviewScreen(initialReview: _capacityReview())),
    );
    await tester.pump();

    expect(find.text(LoopModeCopy.paywallAfterLoopHeadline), findsNothing);
  });

  testWidgets('paywall teaser widget renders when should show', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoopPaywallTeaserCard(
            shouldShow: true,
            entitlements: null,
            onDismissed: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(LoopModeCopy.paywallAfterLoopHeadline), findsOneWidget);
    expect(find.text(LoopModeCopy.paywallAfterLoopSeePro), findsOneWidget);
  });

  testWidgets('capacity review card uses loop CTA', (tester) async {
    var keptWatching = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SignalReviewCard(
            review: _capacityReview(),
            onConfirm: () {},
            onCorrect: () {},
            onKeepWatching: () => keptWatching = true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(LoopModeCopy.reviewKeepWatchingLoop), findsOneWidget);
    await tester.tap(find.text(LoopModeCopy.reviewKeepWatchingLoop));
    expect(keptWatching, isTrue);
  });

  test('no banned copy in loop review strings', () {
    const banned = [
      'therapy',
      'coach',
      'diagnosis',
      'VoiceMemory Pro',
      'VoiceMemory listens',
      'AI friend',
    ];
    for (final s in [
      LoopModeCopy.capacityReviewTitle,
      LoopModeCopy.capacityReviewSubtitle,
      LoopModeCopy.reviewConfirmSaved,
      LoopModeCopy.reviewKeepWatchingSaved,
      LoopModeCopy.paywallAfterLoopHeadline,
      LoopModeCopy.paywallAfterLoopBody,
      LoopModeCopy.reviewProveWrongCapacity,
      ...LoopModeCopy.capacityCorrectionAlternatives,
      ...LoopModeCopy.capacityReviewNextPrompts,
    ]) {
      for (final word in banned) {
        expect(s.toLowerCase(), isNot(contains(word.toLowerCase())));
      }
    }
  });
}
