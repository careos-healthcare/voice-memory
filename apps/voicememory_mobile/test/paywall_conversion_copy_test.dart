import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/billing/paywall_route_args.dart';
import 'package:voicememory_mobile/billing/paywall_source.dart';
import 'package:voicememory_mobile/billing/revenuecat_service.dart';
import 'package:voicememory_mobile/features/paywall_alignment/paywall_alignment_copy.dart';
import 'package:voicememory_mobile/features/pro_value/pro_value_copy.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/paywall_screen.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_research/screens/pressure_insights_screen.dart';
import 'package:voicememory_mobile/widgets/billing/plan_selection_confidence_block.dart';

PressureCheckInRecord _record({
  required String id,
  int daysAgo = 0,
  String optionId = 'could_not_stop',
  List<String> contextIds = const [],
  bool choseToStop = false,
}) {
  return PressureCheckInRecord(
    entryId: id,
    createdAt: DateTime(2026, 6, 8, 12).subtract(Duration(days: daysAgo)),
    optionId: optionId,
    contextIds: contextIds,
    choseToStop: choseToStop,
    transcript: 'pressure moment',
  );
}

List<PressureCheckInRecord> _fiveRecords() => [
  for (var i = 0; i < 5; i++)
    _record(id: 'r$i', daysAgo: i, contextIds: const ['work']),
];

/// Pumps the paywall screen with optional [args]; billing is not configured
/// in tests, so the source-aware copy renders on the unavailable fallback.
Future<void> _pumpPaywall(WidgetTester tester, {PaywallRouteArgs? args}) async {
  await tester.binding.setSurfaceSize(const Size(390, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => PaywallScreen(
              triggerArgs: args,
              delayedPaywallProofGateOverride: () => true,
            ),
          ),
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (find
        .byKey(const Key('paywall_unavailable_body'))
        .evaluate()
        .isNotEmpty) {
      break;
    }
  }
}

/// Pumps a free-tier Pressure Insights screen with a `/subscription` route
/// that captures the [PaywallRouteArgs] it was opened with.
Future<PaywallRouteArgs? Function()> _pumpInsightsWithPaywallCapture(
  WidgetTester tester, {
  required List<PressureCheckInRecord> records,
}) async {
  PaywallRouteArgs? captured;

  await tester.binding.setSurfaceSize(const Size(390, 4200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => PressureInsightsScreen(
          entitlementReader: FakeArchiveEntitlementReader(pro: false),
          records: records,
        ),
      ),
      GoRoute(
        path: '/subscription',
        builder: (context, state) {
          captured = state.extra as PaywallRouteArgs?;
          return const Scaffold(
            body: Center(child: Text('SUBSCRIPTION_MARKER')),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return () => captured;
}

void main() {
  group('Paywall source copy variants', () {
    test('pressure pattern history shows pressure-specific copy', () {
      final copy = PaywallSourceCopy.forSource(
        PaywallSource.pressurePatternHistory,
      );
      expect(copy.headline, 'See more of your pressure pattern');
      expect(
        copy.subheadline,
        'See where this keeps repeating, what it may be costing you, '
        'and what changed over time.',
      );
      expect(copy.bullets, const [
        'Full pressure pattern history',
        'Your first pressure review',
        'Evidence confidence',
        'Ask your archive where this repeats',
        'Return triggers for the real-life pressure moment',
      ]);
      expect(copy.cta, ConsumerUiCopy.paywallPrimaryCta);
    });

    test('full pressure review shares the pressure-specific copy', () {
      final copy = PaywallSourceCopy.forSource(PaywallSource.pressureReview);
      expect(copy.headline, 'See more of your pressure pattern');
      expect(copy.cta, ConsumerUiCopy.paywallPrimaryCta);
      expect(copy.bullets, contains('Your first pressure review'));
    });

    test('Ask the Archive shows archive question copy', () {
      final copy = PaywallSourceCopy.forSource(PaywallSource.askArchive);
      expect(copy.headline, 'Ask your archive what keeps repeating');
      expect(
        copy.subheadline,
        'ArchiveMe uses your saved moments to show patterns with '
        'evidence, not generic advice.',
      );
      expect(copy.bullets, const [
        'Ask where this pressure repeats',
        'See the evidence behind the answer',
        'Track how the pattern changes',
        'Full pressure reviews over time',
      ]);
    });

    test('start here today shows thread-connection copy', () {
      final copy = PaywallSourceCopy.forSource(PaywallSource.startHereToday);
      expect(copy.headline, 'Keep the thread connected');
      expect(
        copy.subheadline,
        'Free keeps today\u2019s save. Pro connects what returns, '
        'fades, and changes over time.',
      );
      expect(copy.bullets, const [
        'See when a thread returns',
        'Notice when a pattern starts fading',
        'Track belief-like phrases that show up again',
        'Open the exact evidence behind each insight',
      ]);
      expect(copy.cta, ConsumerUiCopy.paywallPrimaryCta);
    });

    test('daily suggestion shares the thread-connection copy', () {
      final copy = PaywallSourceCopy.forSource(PaywallSource.dailySuggestion);
      expect(copy.headline, 'Keep the thread connected');
      expect(copy.cta, ConsumerUiCopy.paywallPrimaryCta);
      expect(copy.bullets, contains('See when a thread returns'));
    });

    test('daily-prompt copy avoids overclaiming language', () {
      final copy = PaywallSourceCopy.forSource(PaywallSource.startHereToday);
      final all = [
        copy.headline,
        copy.subheadline,
        copy.cta,
        ...copy.bullets,
      ].join(' ').toLowerCase();
      for (final banned in ['ai therapist', 'diagnosis', 'fix yourself']) {
        expect(all, isNot(contains(banned)));
      }
    });

    test(
      'continuity copy names returned, faded, changed, and exact evidence',
      () {
        for (final source in [
          PaywallSource.startHereToday,
          PaywallSource.dailySuggestion,
        ]) {
          final copy = PaywallSourceCopy.forSource(source);
          final all = '${copy.subheadline} ${copy.bullets.join(' ')}'
              .toLowerCase();
          expect(all, contains('returns'));
          expect(all, contains('fad')); // fades / fading
          expect(all, contains('changes'));
          expect(all, contains('exact evidence'));
          expect(all, contains('belief-like phrases'));
        }
      },
    );

    test('continuity confidence copy keeps free saves and exit clear', () {
      final lines = PaywallConfidenceCopy.forSource(
        PaywallSource.startHereToday,
      );
      expect(lines, contains('Your saves stay free.'));
      expect(lines, contains('Pro only adds continuity over time.'));
      expect(lines, contains('Manage or cancel anytime in the App Store.'));
    });

    test('Pro is continuity, never advanced AI or therapy', () {
      final allCopy = [
        for (final source in PaywallSource.values) ...[
          PaywallSourceCopy.forSource(source).headline,
          PaywallSourceCopy.forSource(source).subheadline,
          ...PaywallSourceCopy.forSource(source).bullets,
          ...PaywallConfidenceCopy.forSource(source),
        ],
        PaywallAboveFoldClarity.title,
        ...PaywallAboveFoldClarity.lines,
        PaywallAboveFoldClarity.freeReassuranceLine,
        PaywallProofPreview.heading,
        ...PaywallProofPreview.rows,
        PaywallAnnualValueCopy.longTermLine,
        PaywallAnnualValueCopy.yearlyHelper,
        PaywallAnnualValueCopy.monthlyHelper,
      ].join(' ');
      final lower = allCopy.toLowerCase();

      expect(lower, isNot(contains('advanced ai')));
      for (final banned in const [
        'therapy',
        'therapist',
        'diagnos',
        'treatment',
        'anxiety',
        'trauma',
        'disorder',
        'cure',
        'heal',
      ]) {
        expect(
          lower,
          isNot(contains(banned)),
          reason: 'paywall copy must not contain "$banned"',
        );
      }
      expect(allCopy, isNot(contains('VoiceMemory')));
      // Free users are never told they lose their own saves.
      expect(lower, isNot(contains('lose your')));
      expect(lower, isNot(contains('locked out')));
    });

    test('general Pro fallback copy', () {
      final copy = PaywallSourceCopy.forSource(PaywallSource.generalPro);
      expect(copy.headline, PaywallAlignmentCopy.headline);
      expect(copy.subheadline, PaywallAlignmentCopy.body);
      expect(copy.bullets, isNotEmpty);
    });

    test('source ids round-trip through fromId', () {
      for (final source in PaywallSource.values) {
        expect(PaywallSource.fromId(source.id), source);
      }
      expect(PaywallSource.fromId('unknown'), isNull);
      expect(PaywallSource.fromId(null), isNull);
    });

    test('no VoiceMemory in any source copy variant', () {
      for (final source in PaywallSource.values) {
        final copy = PaywallSourceCopy.forSource(source);
        final all = [
          copy.headline,
          copy.subheadline,
          copy.cta,
          ...copy.bullets,
        ].join(' ');
        expect(
          all,
          isNot(contains('VoiceMemory')),
          reason: '${source.id} copy must not mention VoiceMemory',
        );
      }
    });
  });

  group('Paywall screen source-aware headline', () {
    testWidgets('pressure pattern source shows pressure headline/subheadline', (
      tester,
    ) async {
      await _pumpPaywall(
        tester,
        args: const PaywallRouteArgs(
          source: PaywallSource.pressurePatternHistory,
        ),
      );
      expect(find.text('See more of your pressure pattern'), findsOneWidget);
      expect(find.byKey(const Key('paywall_unavailable_body')), findsOneWidget);
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });

    testWidgets('review source shows pressure-specific copy', (tester) async {
      await _pumpPaywall(
        tester,
        args: const PaywallRouteArgs(source: PaywallSource.pressureReview),
      );
      expect(find.text('See more of your pressure pattern'), findsOneWidget);
    });

    testWidgets('Ask the Archive source shows archive question copy', (
      tester,
    ) async {
      await _pumpPaywall(
        tester,
        args: const PaywallRouteArgs(source: PaywallSource.askArchive),
      );
      expect(
        find.text('Ask your archive what keeps repeating'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('paywall_unavailable_body')), findsOneWidget);
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });

    testWidgets('start here today source shows thread headline', (
      tester,
    ) async {
      await _pumpPaywall(
        tester,
        args: const PaywallRouteArgs(source: PaywallSource.startHereToday),
      );
      expect(find.text('Keep the thread connected'), findsOneWidget);
      expect(find.byKey(const Key('paywall_unavailable_body')), findsOneWidget);
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });

    testWidgets('daily suggestion source shows thread headline', (
      tester,
    ) async {
      await _pumpPaywall(
        tester,
        args: const PaywallRouteArgs(source: PaywallSource.dailySuggestion),
      );
      expect(find.text('Keep the thread connected'), findsOneWidget);
    });

    testWidgets('general Pro source shows fallback headline', (tester) async {
      await _pumpPaywall(
        tester,
        args: const PaywallRouteArgs(source: PaywallSource.generalPro),
      );
      expect(find.text(ConsumerUiCopy.paywallHeadline), findsOneWidget);
      expect(find.byKey(const Key('paywall_unavailable_body')), findsOneWidget);
      // Unavailable fallback shows one headline line; subhead is omitted when it
      // matches the headline copy.
      if (ConsumerUiCopy.paywallHeadline != ConsumerUiCopy.paywallSubhead) {
        expect(find.text(ConsumerUiCopy.paywallSubhead), findsNothing);
      } else {
        expect(find.text(ConsumerUiCopy.paywallHeadline), findsOneWidget);
      }
    });

    testWidgets('no source keeps the existing default headline', (
      tester,
    ) async {
      await _pumpPaywall(tester);
      expect(find.text(ConsumerUiCopy.paywallHeadline), findsOneWidget);
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });
  });

  group('Purchase confidence layer', () {
    test('suggestion sources get the continuity confidence lines', () {
      expect(
        PaywallConfidenceCopy.forSource(PaywallSource.startHereToday),
        PaywallConfidenceCopy.suggestion,
      );
      expect(
        PaywallConfidenceCopy.forSource(PaywallSource.dailySuggestion),
        PaywallConfidenceCopy.suggestion,
      );
      expect(
        PaywallConfidenceCopy.suggestion,
        contains('Your saves stay free.'),
      );
      expect(
        PaywallConfidenceCopy.suggestion,
        contains('Manage or cancel anytime in the App Store.'),
      );
    });

    test('generic and non-suggestion sources get the default lines', () {
      expect(
        PaywallConfidenceCopy.forSource(null),
        PaywallConfidenceCopy.generic,
      );
      expect(
        PaywallConfidenceCopy.forSource(PaywallSource.generalPro),
        PaywallConfidenceCopy.generic,
      );
      expect(
        PaywallConfidenceCopy.forSource(PaywallSource.pressureReview),
        PaywallConfidenceCopy.generic,
      );
      expect(PaywallConfidenceCopy.generic, contains('Your saves stay free.'));
      expect(
        PaywallConfidenceCopy.generic,
        contains('Manage or cancel anytime in the App Store.'),
      );
    });

    test('confidence copy has no scarcity, loss framing, or VoiceMemory', () {
      final all = [
        ...PaywallConfidenceCopy.generic,
        ...PaywallConfidenceCopy.suggestion,
      ].join(' ').toLowerCase();
      for (final banned in [
        'limited time',
        'last chance',
        'expires',
        'lose access',
        'deleted',
        'disappear',
        'removed',
        'voicememory',
      ]) {
        expect(
          all,
          isNot(contains(banned)),
          reason: 'confidence copy must not contain "$banned"',
        );
      }
    });

    testWidgets('confidence copy is wired for source-specific purchase body', (
      tester,
    ) async {
      await _pumpPaywall(
        tester,
        args: const PaywallRouteArgs(source: PaywallSource.startHereToday),
      );

      expect(find.text('Keep the thread connected'), findsOneWidget);
      expect(find.text('Your saves stay free.'), findsNothing);
      expect(find.text(ConsumerUiCopy.restorePurchases), findsOneWidget);
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });

    testWidgets(
      'generic unavailable paywall stays compact without confidence stack',
      (tester) async {
        await _pumpPaywall(tester);

        expect(find.text('Your saves stay free.'), findsNothing);
        expect(find.text('Pro only adds continuity over time.'), findsNothing);
        expect(find.text(ConsumerUiCopy.paywallHeadline), findsOneWidget);
        expect(
          find.byKey(const Key('paywall_unavailable_body')),
          findsOneWidget,
        );
        expect(find.textContaining('VoiceMemory'), findsNothing);
      },
    );
  });

  group('Pro trial explainer', () {
    test('trial line appears only when a free trial is actually detected', () {
      for (final source in [null, PaywallSource.startHereToday]) {
        final withoutTrial = PaywallConfidenceCopy.linesFor(
          source,
          hasFreeTrial: false,
        );
        expect(withoutTrial, isNot(contains(PaywallConfidenceCopy.trialLine)));
        expect(withoutTrial.join(' ').toLowerCase(), isNot(contains('trial')));
        expect(withoutTrial.join(' '), isNot(contains('Try Pro free')));

        final withTrial = PaywallConfidenceCopy.linesFor(
          source,
          hasFreeTrial: true,
        );
        expect(
          withTrial.where((l) => l == PaywallConfidenceCopy.trialLine),
          hasLength(1),
        );
        // Base confidence lines stay intact in both cases.
        expect(withTrial.take(withoutTrial.length).toList(), withoutTrial);
      }
    });

    test('trial line copy is exact and pressure-free', () {
      expect(
        PaywallConfidenceCopy.trialLine,
        'Try Pro free, then continue only if it feels useful.',
      );
    });

    testWidgets('no trial mention when no trial offer is configured', (
      tester,
    ) async {
      // Billing is unconfigured in widget tests — no products, no intro
      // offers — so the paywall must not mention a trial anywhere.
      await _pumpPaywall(tester);
      expect(find.textContaining('Try Pro free'), findsNothing);
      expect(find.textContaining('free trial'), findsNothing);
    });

    test('confidence and trial copy avoid lockout and pressure language', () {
      final all = [
        ...PaywallConfidenceCopy.generic,
        ...PaywallConfidenceCopy.suggestion,
        PaywallConfidenceCopy.trialLine,
      ].join(' ').toLowerCase();
      for (final banned in [
        'limited time',
        'last chance',
        'expires',
        'act now',
        'must upgrade',
        'required to keep',
        'lose access',
        'lose your',
        'locked out',
        'deleted',
        'disappear',
        'removed',
        'voicememory',
      ]) {
        expect(
          all,
          isNot(contains(banned)),
          reason: 'paywall copy must not contain "$banned"',
        );
      }
    });

    test('RevenueCat identifiers are unchanged', () {
      expect(RevenueCatService.proEntitlementId, 'pro');
    });
  });

  group('Paywall above-fold clarity', () {
    test('clarity copy is exact — four lines plus free reassurance', () {
      expect(PaywallAboveFoldClarity.title, 'What Pro keeps');
      expect(
        PaywallAboveFoldClarity.lines,
        PaywallAlignmentCopy.benefitBullets,
      );
      expect(
        PaywallAboveFoldClarity.freeReassuranceLine,
        'Free keeps today\u2019s save. Pro keeps the thread connected over '
        'time.',
      );
    });

    testWidgets(
      'unavailable paywall does not show purchase-body clarity stack',
      (tester) async {
        await _pumpPaywall(tester);

        expect(
          find.byKey(const Key('paywall_primary_value_block')),
          findsNothing,
        );
        expect(find.text(ConsumerUiCopy.paywallBackupLine), findsNothing);
        expect(find.text(PaywallConfidenceCopy.generic.first), findsNothing);
        expect(
          find.byKey(const Key('paywall_unavailable_body')),
          findsOneWidget,
        );
      },
    );

    test(
      'source-specific purchase body keeps clarity before plan cards; packaging path stays compact',
      () {
        final source = File(
          'lib/screens/paywall_screen.dart',
        ).readAsStringSync();
        final paywallBody = source.substring(
          source.indexOf('Widget _paywallBody()'),
        );
        final packagingIdx = paywallBody.indexOf('if (showPackagingSection)');
        final generalClarityIdx = paywallBody.indexOf(
          '_generalConversionClaritySection(',
        );
        final aboveFoldClarityIdx = paywallBody.indexOf(
          '_aboveFoldClaritySection()',
        );
        final clarityIdx = generalClarityIdx > -1
            ? generalClarityIdx
            : aboveFoldClarityIdx;
        final planCardsIdx = paywallBody.indexOf('...orderedPaywallPlans(');
        expect(packagingIdx, greaterThan(-1));
        expect(clarityIdx, greaterThan(-1));
        expect(planCardsIdx, greaterThan(clarityIdx));
        expect(
          paywallBody.indexOf('ProValueCopy.headline', packagingIdx),
          greaterThan(packagingIdx),
        );
        expect(
          paywallBody
              .substring(
                packagingIdx,
                paywallBody.indexOf('] else', packagingIdx),
              )
              .contains('_aboveFoldClaritySection()'),
          isFalse,
          reason: 'packaging path must not render the clarity block',
        );
      },
    );

    test('clarity block logs paywall_above_fold_clarity_seen in source', () {
      final source = File('lib/screens/paywall_screen.dart').readAsStringSync();
      expect(
        source,
        contains('ActivationFunnelAnalytics.paywallAboveFoldClaritySeen'),
      );
    });

    test('no advanced AI, VoiceMemory, lockout, or urgency language', () {
      final all = [
        PaywallAboveFoldClarity.title,
        ...PaywallAboveFoldClarity.lines,
        PaywallAboveFoldClarity.freeReassuranceLine,
      ].join(' ').toLowerCase();
      for (final banned in const [
        'advanced ai',
        'voicememory',
        'limited time',
        'last chance',
        'only today',
        'act now',
        'hurry',
        'expires',
        'before it',
        'must upgrade',
        'required to keep',
        'lose access',
        'lose your',
        'locked out',
        'unlock your saves',
        'deleted',
        'disappear',
        'removed',
        'trial',
      ]) {
        expect(
          all,
          isNot(contains(banned)),
          reason: 'clarity copy must not contain "$banned"',
        );
      }
    });
  });

  group('Plan selection confidence', () {
    test('copy is exact and plan ids are stable', () {
      expect(
        PaywallPlanSelectionConfidence.title,
        'Choose how you want to continue',
      );
      expect(
        PaywallPlanSelectionConfidence.monthlyHelper,
        'Monthly keeps it flexible.',
      );
      expect(
        PaywallPlanSelectionConfidence.yearlyHelper,
        'Yearly is for people who want ArchiveMe to keep connecting '
        'patterns over time.',
      );
      expect(
        PaywallPlanSelectionConfidence.manageLine,
        'You can manage or cancel this anytime through the App Store.',
      );
      expect(PaywallPlanSelectionConfidence.monthlyPlanId, 'monthly');
      expect(PaywallPlanSelectionConfidence.yearlyPlanId, 'yearly');
      expect(
        PaywallPlanSelectionConfidence.helperForPlanId('monthly'),
        PaywallPlanSelectionConfidence.monthlyHelper,
      );
      expect(
        PaywallPlanSelectionConfidence.helperForPlanId('yearly'),
        PaywallPlanSelectionConfidence.yearlyHelper,
      );
    });

    Future<void> pumpBlock(WidgetTester tester, String planId) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlanSelectionConfidenceBlock(
              selectedPlanId: planId,
              source: 'general_pro',
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('monthly selected shows the monthly helper', (tester) async {
      await pumpBlock(tester, 'monthly');
      expect(
        find.byKey(const Key('paywall_plan_selection_confidence')),
        findsOneWidget,
      );
      expect(find.text(PaywallPlanSelectionConfidence.title), findsOneWidget);
      expect(
        find.text(PaywallPlanSelectionConfidence.monthlyHelper),
        findsOneWidget,
      );
      expect(
        find.text(PaywallPlanSelectionConfidence.yearlyHelper),
        findsNothing,
      );
      expect(
        find.text(PaywallPlanSelectionConfidence.manageLine),
        findsOneWidget,
      );
    });

    testWidgets('yearly selected shows the yearly helper, and the helper '
        'updates when the selection changes', (tester) async {
      await pumpBlock(tester, 'yearly');
      expect(
        find.text(PaywallPlanSelectionConfidence.yearlyHelper),
        findsOneWidget,
      );
      expect(
        find.text(PaywallPlanSelectionConfidence.monthlyHelper),
        findsNothing,
      );

      // Selection change re-renders the helper line.
      await pumpBlock(tester, 'monthly');
      expect(
        find.text(PaywallPlanSelectionConfidence.monthlyHelper),
        findsOneWidget,
      );
      expect(
        find.text(PaywallPlanSelectionConfidence.yearlyHelper),
        findsNothing,
      );
      expect(
        find.text(PaywallPlanSelectionConfidence.manageLine),
        findsOneWidget,
      );
    });

    testWidgets('seen event fires once per session with source only', (
      tester,
    ) async {
      final captured = <({String event, Map<String, Object> properties})>[];
      ActivationFunnelAnalytics.resetForTest();
      ActivationFunnelAnalytics.captureForTest(
        (event, properties) =>
            captured.add((event: event, properties: properties)),
      );
      addTearDown(ActivationFunnelAnalytics.resetForTest);

      await pumpBlock(tester, 'yearly');
      // Rebuild with a different selection — still one seen event.
      await pumpBlock(tester, 'monthly');

      final seen = captured
          .where(
            (e) =>
                e.event ==
                ActivationFunnelAnalytics.planSelectionConfidenceSeen,
          )
          .toList();
      expect(seen, hasLength(1), reason: 'rebuilds never spam the event');
      expect(seen.single.properties, {'source': 'general_pro'});
    });

    test('paywall_plan_selected carries only stable plan and source', () {
      final captured = <({String event, Map<String, Object> properties})>[];
      ActivationFunnelAnalytics.resetForTest();
      ActivationFunnelAnalytics.captureForTest(
        (event, properties) =>
            captured.add((event: event, properties: properties)),
      );
      addTearDown(ActivationFunnelAnalytics.resetForTest);

      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.paywallPlanSelected,
        source: 'general_pro',
        plan: 'yearly',
      );
      expect(captured.single.event, 'paywall_plan_selected');
      expect(captured.single.properties, {
        'source': 'general_pro',
        'plan': 'yearly',
      });
    });

    test('plan card taps log paywall_plan_selected, and the block renders '
        'between the plan cards and the purchase CTA', () {
      final source = File('lib/screens/paywall_screen.dart').readAsStringSync();
      // The tap handler fires the funnel event with the stable plan id —
      // and only the tap handler, never the purchase path.
      expect(
        RegExp(
          r'setState\(\(\) => _selected = plan\);\s*'
          r'_trackPlanSelected\(plan\);\s*'
          r'// Funnel event with the stable plan id only[\s\S]{0,120}?'
          r'ActivationFunnelAnalytics\.track\(\s*'
          r'ActivationFunnelAnalytics\.paywallPlanSelected,\s*'
          r'source: _attributionSource\.id,\s*'
          r'plan: _planIdFor\(plan\),\s*'
          r'\);',
        ).hasMatch(source),
        isTrue,
        reason: 'selecting a plan card must log paywall_plan_selected',
      );
      expect(
        RegExp(
          r'paywallPlanSelected,[\s\S]{0,400}_continue\(\)',
        ).hasMatch(source.substring(source.indexOf('Future<void> _continue'))),
        isFalse,
        reason: 'the purchase path must not log paywall_plan_selected',
      );
      // Placement: plan cards → confidence block → purchase CTA.
      final planCardsIdx = source.indexOf('...orderedPaywallPlans(');
      final blockIdx = source.indexOf(
        'PlanSelectionConfidenceBlock(',
        planCardsIdx,
      );
      final ctaIdx = source.indexOf(
        'onPressed: _busy ? null : _continue,',
        planCardsIdx,
      );
      expect(planCardsIdx, greaterThan(-1));
      expect(
        blockIdx,
        greaterThan(planCardsIdx),
        reason: 'the helper must render after the plan cards',
      );
      expect(
        ctaIdx,
        greaterThan(blockIdx),
        reason: 'the helper must render before the purchase CTA',
      );
    });

    test('no savings claim, no VoiceMemory, no pressure or lockout words', () {
      final all = [
        PaywallPlanSelectionConfidence.title,
        PaywallPlanSelectionConfidence.monthlyHelper,
        PaywallPlanSelectionConfidence.yearlyHelper,
        PaywallPlanSelectionConfidence.manageLine,
      ].join(' ').toLowerCase();
      // The paywall computes no real savings, so no savings language at all.
      expect(all, isNot(contains('%')));
      expect(all, isNot(contains('save ')));
      expect(all, isNot(contains('best deal')));
      expect(all, isNot(contains('best value')));
      for (final banned in const [
        'voicememory',
        'must',
        'should',
        'limited time',
        'offer ends',
        'hurry',
        'lose access',
        'locked out',
        'failure',
        'problem',
        'fix',
        'diagnose',
        'therapy',
        'treatment',
      ]) {
        expect(
          all,
          isNot(contains(banned)),
          reason: 'plan-selection copy must not contain "$banned"',
        );
      }
    });
  });

  group('Price confidence', () {
    test('price-confidence copy is exact', () {
      expect(
        PaywallPriceConfidenceCopy.manageLine,
        'You can manage this anytime in the App Store.',
      );
      expect(
        PaywallPriceConfidenceCopy.trialHandlingLine,
        'Trial details are handled by the App Store before you confirm.',
      );
      expect(
        PaywallPriceConfidenceCopy.confirmLine,
        'The App Store will confirm before anything is charged.',
      );
    });

    test('trial handling line renders only when a trial is detected', () {
      expect(PaywallPriceConfidenceCopy.planLines(hasFreeTrial: false), [
        PaywallPriceConfidenceCopy.manageLine,
      ]);
      expect(PaywallPriceConfidenceCopy.planLines(hasFreeTrial: true), [
        PaywallPriceConfidenceCopy.manageLine,
        PaywallPriceConfidenceCopy.trialHandlingLine,
      ]);
    });

    testWidgets('unavailable paywall hides price-confidence purchase stack', (
      tester,
    ) async {
      await _pumpPaywall(tester);

      expect(find.byKey(const Key('paywall_price_confidence')), findsNothing);
      expect(find.text(PaywallPriceConfidenceCopy.manageLine), findsNothing);
      expect(find.text(PaywallPriceConfidenceCopy.confirmLine), findsNothing);
      expect(
        find.text(PaywallPriceConfidenceCopy.trialHandlingLine),
        findsNothing,
      );
      expect(find.textContaining('free trial'), findsNothing);
    });

    test(
      'price confidence sits below the plan cards for source-specific purchase body',
      () {
        final source = File(
          'lib/screens/paywall_screen.dart',
        ).readAsStringSync();
        expect(
          RegExp(
            r'if \(!showPackagingSection\) \.\.\.\[\s*'
            r'// Plan-selection confidence: follows the selected plan, before '
            r'the\s*// purchase CTA\.\s*'
            r'const SizedBox\(height: 14\),\s*'
            r'PlanSelectionConfidenceBlock\(\s*'
            r'selectedPlanId: _planIdFor\(_selected\),\s*'
            r'source: widget\.triggerArgs\?\.source\?\.id,\s*'
            r'\),\s*'
            r'// Price confidence directly below the plan cards\.\s*'
            r'const SizedBox\(height: 10\),\s*'
            r'_priceConfidenceLines\(\),\s*'
            r'\],',
          ).hasMatch(source),
          isTrue,
          reason:
              'source-specific purchase body keeps plan and price confidence '
              'below plan cards',
        );
        expect(
          RegExp(
            r'if \(!showPackagingSection\) \.\.\.\[\s*'
            r'// Final price-confidence line directly before the purchase CTA\.\s*'
            r'const SizedBox\(height: 10\),\s*'
            r'_appStoreConfirmLine\(\),\s*'
            r'\],\s*'
            r'const SizedBox\(height: 16\),\s*'
            r'_subscriptionDetailsSection\(plansAvailable: _purchasePlansAvailable\),',
          ).hasMatch(source),
          isTrue,
          reason:
              'source-specific confidence stack stays above shared subscription '
              'details before purchase',
        );
      },
    );

    test('price confidence logs price_confidence_seen in source', () {
      final source = File('lib/screens/paywall_screen.dart').readAsStringSync();
      expect(source, contains('ActivationFunnelAnalytics.priceConfidenceSeen'));
    });

    test('no pressure, scarcity, lockout, or VoiceMemory language', () {
      // The non-trial lines additionally must never mention a trial.
      final nonTrial = [
        PaywallPriceConfidenceCopy.manageLine,
        PaywallPriceConfidenceCopy.confirmLine,
      ].join(' ').toLowerCase();
      expect(nonTrial, isNot(contains('trial')));

      final all = '$nonTrial ${PaywallPriceConfidenceCopy.trialHandlingLine}'
          .toLowerCase();
      for (final banned in const [
        'limited time',
        'offer ends',
        'last chance',
        'only today',
        'act now',
        'hurry',
        'expires',
        'before it',
        'must upgrade',
        'required to keep',
        'lose access',
        'lose your',
        'locked out',
        'unlock your saves',
        'deleted',
        'disappear',
        'removed',
        'free trial',
        'voicememory',
      ]) {
        expect(
          all,
          isNot(contains(banned)),
          reason: 'price-confidence copy must not contain "$banned"',
        );
      }
    });
  });

  group('Purchase completion reassurance', () {
    test('reassurance copy is exact', () {
      expect(PaywallConfidenceCopy.generic, const [
        'Your saves stay free.',
        'Pro only adds continuity over time.',
        'Manage or cancel anytime in the App Store.',
      ]);
      // Suggestion sources show the same reassurance plus the explicit
      // no-pressure line — never less.
      expect(PaywallConfidenceCopy.suggestion, const [
        'Your saves stay free.',
        'Pro only adds continuity over time.',
        'Manage or cancel anytime in the App Store.',
        PaywallConfidenceCopy.suggestionReassurance,
      ]);
    });

    test(
      'reassurance sits above purchase CTA for source-specific purchase body',
      () {
        final source = File(
          'lib/screens/paywall_screen.dart',
        ).readAsStringSync();
        expect(
          RegExp(
            r'if \(!showPackagingSection\) \.\.\.\[\s*'
            r'const SizedBox\(height: 18\),\s*'
            r'_confidenceSection\(\),\s*'
            r'\],',
          ).hasMatch(source),
          isTrue,
          reason:
              'source-specific purchase body keeps reassurance above the CTA',
        );
        expect(
          RegExp(
            r'const SizedBox\(height: 16\),\s*'
            r'_subscriptionDetailsSection\(plansAvailable: _purchasePlansAvailable\),\s*'
            r'const SizedBox\(height: 14\),\s*'
            r'FilledButton\(',
          ).hasMatch(source),
          isTrue,
          reason:
              'subscription details and legal links render before the purchase CTA',
        );
      },
    );

    test('reassurance logs purchase_reassurance_seen in source', () {
      final source = File('lib/screens/paywall_screen.dart').readAsStringSync();
      expect(
        source,
        contains('ActivationFunnelAnalytics.purchaseReassuranceSeen'),
      );
    });

    test(
      'no lockout, urgency, or scarcity language anywhere near purchase',
      () {
        final all = [
          ...PaywallConfidenceCopy.generic,
          ...PaywallConfidenceCopy.suggestion,
          PaywallConfidenceCopy.trialLine,
        ].join(' ').toLowerCase();
        for (final banned in const [
          'limited time',
          'last chance',
          'only today',
          'act now',
          'hurry',
          'expires',
          'before it',
          'must upgrade',
          'required to keep',
          'lose access',
          'lose your',
          'locked out',
          'unlock your saves',
          'deleted',
          'disappear',
          'removed',
          'voicememory',
        ]) {
          expect(
            all,
            isNot(contains(banned)),
            reason: 'reassurance copy must not contain "$banned"',
          );
        }
      },
    );
  });

  group('What Pro keeps is centralized in the clarity block', () {
    // The old suggestion-only "Pro thread preview" was folded into the
    // above-fold clarity block, so the heading is never duplicated and the
    // generic paywall gets the same paid-promise clarity.
    testWidgets('suggestion unavailable paywall keeps restore visible', (
      tester,
    ) async {
      await _pumpPaywall(
        tester,
        args: const PaywallRouteArgs(source: PaywallSource.startHereToday),
      );

      expect(find.text('What Pro keeps'), findsNothing);
      expect(find.byKey(const Key('paywall_pro_thread_preview')), findsNothing);
      expect(find.text('Your saves stay free.'), findsNothing);
      expect(find.text(ConsumerUiCopy.restorePurchases), findsOneWidget);
      expect(find.text('Keep the thread connected'), findsOneWidget);
    });

    testWidgets('generic unavailable paywall stays compact', (tester) async {
      await _pumpPaywall(tester);

      expect(
        find.byKey(const Key('paywall_primary_value_block')),
        findsNothing,
      );
      expect(find.byKey(const Key('paywall_pro_thread_preview')), findsNothing);
      expect(find.text(ConsumerUiCopy.paywallHeadline), findsOneWidget);
      expect(find.text('Your saves stay free.'), findsNothing);
      expect(find.byKey(const Key('paywall_unavailable_body')), findsOneWidget);
    });
  });

  group('Pro proof and annual value framing', () {
    test('annual-value framing shows only for suggestion sources', () {
      expect(
        PaywallAnnualValueCopy.showFor(PaywallSource.startHereToday),
        isTrue,
      );
      expect(
        PaywallAnnualValueCopy.showFor(PaywallSource.dailySuggestion),
        isTrue,
      );
      expect(PaywallAnnualValueCopy.showFor(PaywallSource.generalPro), isFalse);
      expect(PaywallAnnualValueCopy.showFor(null), isFalse);
    });

    test('long-term line and plan helpers carry the archive framing', () {
      expect(
        PaywallAnnualValueCopy.longTermLine,
        'This works best as a long-term archive, not a one-off feature.',
      );
      expect(
        PaywallAnnualValueCopy.yearlyHelper,
        'Best if you want your archive to build over time.',
      );
      expect(PaywallAnnualValueCopy.monthlyHelper, 'Try it month to month.');
    });

    test('proof preview shows only for suggestion sources', () {
      expect(PaywallProofPreview.showFor(PaywallSource.startHereToday), isTrue);
      expect(
        PaywallProofPreview.showFor(PaywallSource.dailySuggestion),
        isTrue,
      );
      expect(PaywallProofPreview.showFor(PaywallSource.generalPro), isFalse);
      expect(PaywallProofPreview.showFor(PaywallSource.askArchive), isFalse);
      expect(PaywallProofPreview.showFor(null), isFalse);
    });

    test('proof preview lists observable checks', () {
      expect(PaywallProofPreview.heading, 'Proof you can look for');
      expect(PaywallProofPreview.rows, const [
        'Do prompts get sharper after a few saves?',
        'Does the same thread return tomorrow?',
        'Does your archive show what changed?',
      ]);
    });

    test('suggestion confidence copy includes the reassurance line', () {
      expect(
        PaywallConfidenceCopy.suggestion,
        contains(
          'Upgrade only if you want the archive to keep building over time.',
        ),
      );
      // Existing lines stay.
      expect(
        PaywallConfidenceCopy.suggestion,
        contains('Your saves stay free.'),
      );
      expect(
        PaywallConfidenceCopy.suggestion,
        contains('Pro only adds continuity over time.'),
      );
      expect(
        PaywallConfidenceCopy.suggestion,
        contains('Manage or cancel anytime in the App Store.'),
      );
      // Generic confidence copy is unchanged.
      expect(
        PaywallConfidenceCopy.generic,
        isNot(
          contains(
            'Upgrade only if you want the archive to keep building over time.',
          ),
        ),
      );
    });

    test('new copy avoids banned, scarcity, and loss wording', () {
      final all = [
        PaywallAnnualValueCopy.longTermLine,
        PaywallAnnualValueCopy.yearlyHelper,
        PaywallAnnualValueCopy.monthlyHelper,
        PaywallProofPreview.heading,
        ...PaywallProofPreview.rows,
        PaywallConfidenceCopy.suggestionReassurance,
      ].join(' ').toLowerCase();
      for (final banned in [
        'must',
        'should',
        'problem',
        'unresolved',
        'failure',
        'lazy',
        'weak',
        'diagnose',
        'fix yourself',
        'limited time',
        'last chance',
        'don\u2019t miss out',
        'expires',
        'lose access',
        'deleted',
        'disappear',
        'removed',
        'voicememory',
      ]) {
        expect(
          all,
          isNot(contains(banned)),
          reason: 'framing copy must not contain "$banned"',
        );
      }
    });

    testWidgets(
      'long-term archive line stays on source-specific purchase body',
      (tester) async {
        await _pumpPaywall(
          tester,
          args: const PaywallRouteArgs(source: PaywallSource.startHereToday),
        );
        expect(
          find.text(
            'This works best as a long-term archive, not a one-off feature.',
          ),
          findsNothing,
        );
        expect(find.text('Keep the thread connected'), findsOneWidget);
      },
    );

    testWidgets('proof preview stays on source-specific purchase body', (
      tester,
    ) async {
      await _pumpPaywall(
        tester,
        args: const PaywallRouteArgs(source: PaywallSource.startHereToday),
      );

      expect(find.text('Proof you can look for'), findsNothing);
      expect(
        find.text('Do prompts get sharper after a few saves?'),
        findsNothing,
      );
      expect(find.text(ConsumerUiCopy.restorePurchases), findsOneWidget);
    });

    testWidgets('proof preview does not render while plans are unavailable', (
      tester,
    ) async {
      await _pumpPaywall(
        tester,
        args: const PaywallRouteArgs(source: PaywallSource.dailySuggestion),
      );
      expect(find.text('Proof you can look for'), findsNothing);
      expect(find.byKey(const Key('paywall_proof_preview')), findsNothing);
    });

    testWidgets(
      'suggestion reassurance stays on source-specific purchase body',
      (tester) async {
        await _pumpPaywall(
          tester,
          args: const PaywallRouteArgs(source: PaywallSource.dailySuggestion),
        );
        expect(
          find.text(
            'Upgrade only if you want the archive to keep building over time.',
          ),
          findsNothing,
        );
        expect(find.text('Keep the thread connected'), findsOneWidget);
      },
    );

    testWidgets(
      'framing and proof preview do not render on unavailable generic paywall',
      (tester) async {
        await _pumpPaywall(tester);

        expect(find.text('Proof you can look for'), findsNothing);
        expect(
          find.byKey(const Key('paywall_pro_thread_preview')),
          findsNothing,
        );
        expect(
          find.text(
            'This works best as a long-term archive, not a one-off feature.',
          ),
          findsNothing,
        );
        expect(
          find.text(
            'Upgrade only if you want the archive to keep building over time.',
          ),
          findsNothing,
        );
        expect(find.text(ConsumerUiCopy.paywallHeadline), findsOneWidget);
        expect(find.text('Your saves stay free.'), findsNothing);
        expect(
          find.byKey(const Key('paywall_unavailable_body')),
          findsOneWidget,
        );
        expect(find.textContaining('VoiceMemory'), findsNothing);
      },
    );
  });

  group('Locked CTAs route with the right paywall source', () {
    testWidgets('locked pattern history row passes pattern history source', (
      tester,
    ) async {
      final captured = await _pumpInsightsWithPaywallCapture(
        tester,
        records: _fiveRecords(),
      );

      final row = find.byKey(const Key('pressure_pattern_locked_history'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(find.text('SUBSCRIPTION_MARKER'), findsOneWidget);
      expect(captured()?.source, PaywallSource.pressurePatternHistory);
      expect(captured()?.sourceRoute, '/pressure-insights');
    });

    testWidgets('locked review row passes pressure review source', (
      tester,
    ) async {
      final captured = await _pumpInsightsWithPaywallCapture(
        tester,
        records: _fiveRecords(),
      );

      final row = find.byKey(const Key('pressure_pattern_review_locked'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(find.text('SUBSCRIPTION_MARKER'), findsOneWidget);
      expect(captured()?.source, PaywallSource.pressureReview);
    });

    testWidgets('locked Ask the Archive question passes archive source', (
      tester,
    ) async {
      final captured = await _pumpInsightsWithPaywallCapture(
        tester,
        records: _fiveRecords(),
      );

      final question = find.text('Where does this repeat?');
      await tester.ensureVisible(question);
      await tester.pumpAndSettle();
      await tester.tap(question);
      await tester.pumpAndSettle();

      expect(find.text('SUBSCRIPTION_MARKER'), findsOneWidget);
      expect(captured()?.source, PaywallSource.askArchive);
    });
  });
}
