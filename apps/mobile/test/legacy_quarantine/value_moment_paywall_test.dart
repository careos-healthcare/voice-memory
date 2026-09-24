import 'package:archiveme_mobile/billing/archive_entitlement_reader.dart';
import 'package:archiveme_mobile/billing/paywall_route_args.dart';
import 'package:archiveme_mobile/billing/paywall_source.dart';
import 'package:archiveme_mobile/billing/value_moment_paywall_trigger.dart';
import 'package:archiveme_mobile/features/memory/current_intent_signal.dart';
import 'package:archiveme_mobile/features/memory/entry_memory_mode.dart';
import 'package:archiveme_mobile/features/memory/memory_governance_policy.dart';
import 'package:archiveme_mobile/features/memory/memory_priority_governance.dart';
import 'package:archiveme_mobile/features/memory/memory_scope_policy.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:archiveme_mobile/features/pro_bridge_visibility/delayed_paywall_proof_store.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/widgets/billing/value_moment_pro_bridge.dart';
import 'support/localized_test_app.dart';
import 'package:archiveme_research/screens/pressure_insights_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final DateTime _base = DateTime(2026, 6, 9, 12);

PressureCheckInRecord _record({
  required String id,
  int daysAgo = 0,
  String optionId = 'could_not_stop',
  List<String> contextIds = const [],
  String? fear,
  String transcript = 'pressure moment',
}) {
  return PressureCheckInRecord(
    entryId: id,
    createdAt: _base.subtract(Duration(days: daysAgo)),
    optionId: optionId,
    contextIds: contextIds,
    fear: fear,
    transcript: transcript,
  );
}

/// Three work-context entries → thread return evidence (3 appearances).
List<PressureCheckInRecord> _workThread3() => [
  _record(id: 'a', daysAgo: 7, contextIds: const ['work']),
  _record(id: 'b', daysAgo: 3, contextIds: const ['work']),
  _record(id: 'c', contextIds: const ['work']),
];

/// Two related entries → 2 connected recordings, no "returned before" yet.
List<PressureCheckInRecord> _workThread2() => [
  _record(id: 'a', daysAgo: 5, contextIds: const ['work']),
  _record(id: 'b', contextIds: const ['work']),
];

/// Enough archive depth for governance, without a 3-entry thread return.
List<PressureCheckInRecord> _checkingBeliefForPaywall() => [
  _record(
    id: 'd0',
    daysAgo: 4,
    fear: 'I have to keep checking messages',
    transcript: 'work pressure note a',
  ),
  _record(
    id: 'd1',
    optionId: 'guilty_resting',
    fear: 'Checking messages again tonight',
    transcript: 'home pressure note b',
  ),
  _record(
    id: 'd2',
    daysAgo: 10,
    optionId: 'had_to_prove_enough',
    fear: 'Unrelated note about lunch plans tomorrow',
    transcript: 'lunch plans note c',
  ),
];

/// Three recent unconnected entries → a weekly review, nothing else.
List<PressureCheckInRecord> _unrelatedRecentRecords() => [
  _record(id: 'u0', daysAgo: 2),
  _record(id: 'u1', daysAgo: 1, optionId: 'guilty_resting'),
  _record(id: 'u2', optionId: 'had_to_prove_enough'),
];

String _bridgeCopy() => [
  ValueMomentBridge.title,
  ValueMomentBridge.ctaLabel,
  ValueMomentBridge.dismissLabel,
  ValueMomentBridge.threadReturnBody,
  ValueMomentBridge.beliefBody,
  ValueMomentBridge.weeklyBody,
  ValueMomentBridge.proofCounterBody,
  ValueMomentBridge.fallbackBody,
].join(' ');

void main() {
  const trigger = ValueMomentPaywallTrigger();

  setUp(() {
    ValueMomentPaywallTrigger.resetSessionForTest();
    MemoryScopePolicy.resetForTest();
    MemoryGovernancePolicy.resetForTest();
    MemoryPriorityGovernance.resetForTest();
    CurrentIntentSignal.resetSessionForTest();
    EntryMemoryModeSession.selectedMode = EntryMemoryMode.useArchiveContext;
    DelayedPaywallProofStore.seedForTest(
      hasSeenFirstRepeat: true,
      hasOpenedEvidenceTrail: true,
    );
  });

  group('Value moment trigger — eligibility', () {
    test('no bridge before proof-first milestones are met', () {
      DelayedPaywallProofStore.seedForTest(
        
      );
      expect(
        trigger.build(_workThread3(), isPro: false, now: _base).show,
        isFalse,
      );
    });

    test('no bridge before the first save', () {
      expect(trigger.build(const [], isPro: false, now: _base).show, isFalse);
    });

    test('no bridge for an unconnected single entry', () {
      final bridge = trigger.build(
        [_record(id: 'a')],
        isPro: false,
        now: _base,
      );
      expect(bridge.show, isFalse);
    });

    test('no bridge for Pro users', () {
      expect(
        trigger.build(_workThread3(), isPro: true, now: _base).show,
        isFalse,
      );
    });

    test('no bridge again in the same session after dismissal', () {
      expect(
        trigger.build(_workThread3(), isPro: false, now: _base).show,
        isTrue,
      );
      ValueMomentPaywallTrigger.dismissedThisSession = true;
      expect(
        trigger.build(_workThread3(), isPro: false, now: _base).show,
        isFalse,
      );
    });
  });

  group('Value moment trigger — moment-specific bodies', () {
    test('thread return evidence uses the thread-specific body', () {
      final bridge = trigger.build(_workThread3(), isPro: false, now: _base);
      expect(bridge.show, isTrue);
      expect(bridge.body, ValueMomentBridge.threadReturnBody);
      expect(bridge.cardType, 'thread_return');
    });

    test('belief distance uses the belief-specific body', () {
      final bridge = trigger.build(
        _checkingBeliefForPaywall(),
        isPro: false,
        now: _base,
      );
      expect(bridge.show, isTrue);
      expect(bridge.body, ValueMomentBridge.beliefBody);
      expect(bridge.cardType, 'belief_distance');
    });

    test('2 connected recordings alone stay below paywall threshold', () {
      final bridge = trigger.build(_workThread2(), isPro: false, now: _base);
      expect(bridge.show, isFalse);
    });

    test('proof-counter body copy stays evidence-framed', () {
      const bridge = ValueMomentBridge(
        show: true,
        body: ValueMomentBridge.proofCounterBody,
        cardType: 'archive_proof_counter',
      );
      expect(bridge.body, ValueMomentBridge.proofCounterBody);
      expect(bridge.cardType, 'archive_proof_counter');
    });

    test('a weekly review alone uses the weekly body', () {
      final bridge = trigger.build(
        _unrelatedRecentRecords(),
        isPro: false,
        now: _base,
      );
      expect(bridge.show, isTrue);
      expect(bridge.body, ValueMomentBridge.weeklyBody);
      expect(bridge.cardType, 'weekly_thread_review');
    });

    test('the fallback body still works as the default', () {
      const bridge = ValueMomentBridge(show: true);
      expect(bridge.body, ValueMomentBridge.fallbackBody);
      expect(bridge.cardType, isEmpty);
    });

    test('no raw user snippets or source terms in any bridge body', () {
      // Fixture transcripts, contexts, and belief phrases must never leak
      // into the fixed bridge copy.
      final lower = _bridgeCopy().toLowerCase();
      for (final private in const [
        'work',
        'checking',
        'messages',
        'pressure moment',
        'could_not_stop',
        'guilty',
        'prove',
      ]) {
        expect(
          lower,
          isNot(contains(private)),
          reason: 'bridge copy must not contain source term "$private"',
        );
      }
    });
  });

  group('Value moment paywall copy', () {
    test('value moment routes to the continuity paywall copy', () {
      final copy = PaywallSourceCopy.forSource(PaywallSource.valueMoment);
      expect(copy.headline, 'You saw the first useful repeat.');
      expect(copy.subheadline, ConsumerUiCopy.paywallSubhead);
      final all = '${copy.subheadline} ${copy.bullets.join(' ')}'.toLowerCase();
      expect(all, contains('proof'));
      expect(all, contains('trail'));
    });

    test('free users keep today\u2019s save', () {
      final lines = PaywallConfidenceCopy.forSource(PaywallSource.valueMoment);
      expect(lines, contains('Your saves stay free.'));
      expect(lines, contains('Manage or cancel anytime in the App Store.'));
    });

    test('continuity previews render for the value-moment source', () {
      // "What Pro keeps" is now the above-fold clarity block, which
      // renders for every source including value moment.
      expect(PaywallProofPreview.showFor(PaywallSource.valueMoment), isTrue);
      expect(PaywallAnnualValueCopy.showFor(PaywallSource.valueMoment), isTrue);
      // The suggestion-to-Pro funnel attribution is untouched.
      expect(
        PaywallSourceCopy.isSuggestionSource(PaywallSource.valueMoment),
        isFalse,
      );
    });

    test('stable source id round-trips', () {
      expect(PaywallSource.valueMoment.id, 'value_moment');
      expect(PaywallSource.fromId('value_moment'), PaywallSource.valueMoment);
    });
  });

  group('Value moment copy guardrails', () {
    test('no banned, therapy, or pressure words anywhere', () {
      final paywall = PaywallSourceCopy.forSource(PaywallSource.valueMoment);
      final copy = [
        _bridgeCopy(),
        paywall.headline,
        paywall.subheadline,
        ...paywall.bullets,
        ...PaywallConfidenceCopy.forSource(PaywallSource.valueMoment),
      ].join(' ');
      final lower = copy.toLowerCase();
      for (final banned in const [
        'must',
        'should',
        'task',
        'homework',
        'fix',
        'problem',
        'failure',
        'lazy',
        'weak',
        'diagnose',
        'definitely',
        'therapy',
        'treatment',
        'anxiety',
        'trauma',
        'disorder',
        'cure',
        'heal',
        'advanced ai',
        'streak',
      ]) {
        expect(
          lower,
          isNot(contains(banned)),
          reason: 'value-moment copy must not contain "$banned"',
        );
      }
      expect(copy, isNot(contains('VoiceMemory')));
    });
  });

  group('Value moment Pro bridge widget', () {
    testWidgets('renders the copy with dismiss and CTA', (tester) async {
      final bridge = trigger.build(_workThread3(), isPro: false, now: _base);
      var dismissed = false;
      var sawPro = false;
      await tester.pumpWidget(
        LocalizedTestApp(
          child: ValueMomentProBridge(
            bridge: bridge,
            onSeePro: () => sawPro = true,
            onDismiss: () => dismissed = true,
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('value_moment_pro_bridge')), findsOneWidget);
      expect(find.text(ValueMomentBridge.title), findsOneWidget);
      // The body is the moment-specific one — not the generic fallback.
      expect(find.text(ValueMomentBridge.threadReturnBody), findsOneWidget);
      expect(
        find.textContaining('ArchiveMe has started connecting'),
        findsNothing,
      );
      expect(find.text('See Pro'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
      expect(find.textContaining('VoiceMemory'), findsNothing);

      await tester.tap(find.byKey(const Key('value_moment_dismiss')));
      expect(dismissed, isTrue);
      await tester.tap(find.byKey(const Key('value_moment_cta')));
      expect(sawPro, isTrue);
    });

    testWidgets('seen and tapped carry only safe source and card_type', (
      tester,
    ) async {
      final captured = <({String event, Map<String, Object> properties})>[];
      ActivationFunnelAnalytics.resetForTest();
      ActivationFunnelAnalytics.captureForTest(
        (event, properties) =>
            captured.add((event: event, properties: properties)),
      );
      addTearDown(ActivationFunnelAnalytics.resetForTest);

      final bridge = trigger.build(_workThread3(), isPro: false, now: _base);
      await tester.pumpWidget(
        LocalizedTestApp(
          child: ValueMomentProBridge(
            bridge: bridge,
            onSeePro: () {},
            onDismiss: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('value_moment_cta')));

      final seen = captured
          .where((e) => e.event == 'value_moment_pro_bridge_seen')
          .toList();
      final tapped = captured
          .where((e) => e.event == 'value_moment_pro_bridge_tapped')
          .toList();
      expect(seen, hasLength(1));
      expect(seen.single.properties, {
        'source': 'value_moment',
        'card_type': 'thread_return',
      });
      expect(tapped, hasLength(1));
      expect(tapped.single.properties, {
        'source': 'value_moment',
        'card_type': 'thread_return',
      });
      // No private content in any payload.
      for (final e in captured) {
        final flat = '${e.event} ${e.properties.values.join(' ')}'
            .toLowerCase();
        expect(flat, isNot(contains('pressure moment')));
        expect(flat, isNot(contains('voicememory')));
      }
    });

    testWidgets('renders nothing without a value moment', (tester) async {
      await tester.pumpWidget(
        LocalizedTestApp(
          child: ValueMomentProBridge(
            bridge: ValueMomentBridge.none(),
            onSeePro: () {},
            onDismiss: () {},
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('value_moment_pro_bridge')), findsNothing);
    });
  });

  group('Pressure Insights integration', () {
    Future<PaywallRouteArgs?> pumpInsights(
      WidgetTester tester, {
      required List<PressureCheckInRecord> records,
    }) async {
      PaywallRouteArgs? captured;
      await tester.binding.setSurfaceSize(const Size(390, 6500));
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
              return const Scaffold(body: Center(child: Text('PAYWALL')));
            },
          ),
        ],
      );
      await tester.pumpWidget(localizedMaterialAppRouter(routerConfig: router));
      await tester.pumpAndSettle();
      return captured;
    }

    testWidgets('bridge appears after thread return evidence', (tester) async {
      await pumpInsights(tester, records: _workThread3());
      expect(find.byKey(const Key('value_moment_pro_bridge')), findsOneWidget);
      // Free evidence cards stay fully visible above it.
      expect(
        find.byKey(const Key('thread_return_evidence_card')),
        findsOneWidget,
      );
    });

    testWidgets('no bridge for an unconnected single entry', (tester) async {
      await pumpInsights(tester, records: [_record(id: 'a')]);
      expect(find.byKey(const Key('value_moment_pro_bridge')), findsNothing);
    });

    testWidgets('dismiss hides the bridge for the rest of the session', (
      tester,
    ) async {
      await pumpInsights(tester, records: _workThread3());
      final dismiss = find.byKey(const Key('value_moment_dismiss'));
      await tester.ensureVisible(dismiss);
      await tester.pump();
      await tester.tap(dismiss);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('value_moment_pro_bridge')), findsNothing);
      expect(ValueMomentPaywallTrigger.dismissedThisSession, isTrue);

      // A fresh screen in the same session still shows no bridge.
      await pumpInsights(tester, records: _workThread3());
      expect(find.byKey(const Key('value_moment_pro_bridge')), findsNothing);
    });

    testWidgets('CTA opens the existing paywall with the value-moment source', (
      tester,
    ) async {
      PaywallRouteArgs? captured;
      await tester.binding.setSurfaceSize(const Size(390, 6500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => PressureInsightsScreen(
              entitlementReader: FakeArchiveEntitlementReader(pro: false),
              records: _workThread3(),
            ),
          ),
          GoRoute(
            path: '/subscription',
            builder: (context, state) {
              captured = state.extra as PaywallRouteArgs?;
              return const Scaffold(body: Center(child: Text('PAYWALL')));
            },
          ),
        ],
      );
      await tester.pumpWidget(localizedMaterialAppRouter(routerConfig: router));
      await tester.pumpAndSettle();

      final cta = find.byKey(const Key('value_moment_cta'));
      await tester.ensureVisible(cta);
      await tester.pump();
      await tester.tap(cta);
      await tester.pumpAndSettle();

      expect(find.text('PAYWALL'), findsOneWidget);
      expect(captured, isNotNull);
      expect(captured!.source, PaywallSource.valueMoment);
      expect(captured!.sourceRoute, '/pressure-insights');
    });
  });
}