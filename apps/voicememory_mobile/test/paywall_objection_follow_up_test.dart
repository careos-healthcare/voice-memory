import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/billing/paywall_attribution_event.dart';
import 'package:voicememory_mobile/billing/paywall_attribution_store.dart';
import 'package:voicememory_mobile/billing/paywall_objection_follow_up.dart';
import 'package:voicememory_mobile/billing/paywall_rejection_reason.dart';
import 'package:voicememory_mobile/billing/paywall_route_args.dart';
import 'package:voicememory_mobile/billing/paywall_source.dart';
import 'package:voicememory_mobile/billing/revenuecat_service.dart';
import 'package:voicememory_mobile/features/pro_bridge_visibility/delayed_paywall_proof_store.dart';
import 'package:voicememory_mobile/screens/paywall_screen.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

import 'support/memory_pressure_stores.dart';

MobilePrefsStore _dummyPrefs() =>
    MobilePrefsStore(file: File('test/tmp/objection/unused_prefs.json'));

/// In-memory prefs — keeps store IO out of the widget test zone.
class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs() : super(file: File('test/tmp/objection/unused.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

class _MemoryAttributionStore extends PaywallAttributionStore {
  _MemoryAttributionStore() : super(_dummyPrefs());

  @override
  Future<void> record(
    PaywallAttributionEventType type, {
    required PaywallSource source,
    String? sourceRoute,
    DateTime? now,
  }) async {}

  @override
  Future<List<PaywallAttributionEvent>> events() async => const [];
}

void main() {
  late List<({String event, Map<String, Object> properties})> captured;

  List<({String event, Map<String, Object> properties})> eventsNamed(
    String name,
  ) => captured.where((e) => e.event == name).toList();

  setUp(() {
    captured = [];
    DelayedPaywallProofStore.bypassGateForTest = true;
    ActivationFunnelAnalytics.resetForTest();
    ActivationFunnelAnalytics.captureForTest(
      (event, properties) =>
          captured.add((event: event, properties: properties)),
    );
    PaywallRejectionCapture.resetSessionForTest();
    PaywallObjectionFollowUp.resetSessionForTest();
  });

  tearDown(() {
    DelayedPaywallProofStore.bypassGateForTest = false;
    ActivationFunnelAnalytics.resetForTest();
    PaywallRejectionCapture.resetSessionForTest();
    PaywallObjectionFollowUp.resetSessionForTest();
  });

  Future<void> pumpPaywall(
    WidgetTester tester, {
    required PaywallObjectionStore store,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => PaywallScreen(
                triggerArgs: const PaywallRouteArgs(
                  source: PaywallSource.valueMoment,
                ),
                attributionStore: _MemoryAttributionStore(),
                suggestionAttributionStore: MemorySuggestionAttributionStore(),
                objectionStore: store,
                delayedPaywallProofGateOverride: () => true,
                billingReadyOverride: () => false,
              ),
            ),
            GoRoute(
              path: '/record',
              builder: (context, state) =>
                  const Scaffold(body: Text('RECORD HOME')),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byKey(const Key('paywall_objection_follow_up')).evaluate().isNotEmpty) {
        break;
      }
    }
  }

  group('Objection follow-up copy', () {
    test('each reason renders its exact title and body', () {
      final notEnoughProof = PaywallObjectionFollowUpCopy.forReason(
        PaywallRejectionReason.notEnoughProof,
      );
      expect(notEnoughProof.title, 'More proof before you decide');
      expect(
        notEnoughProof.body,
        'Your archive can now show connected recordings, returned threads, '
        'and exact evidence before you choose Pro.',
      );

      final unclearProValue = PaywallObjectionFollowUpCopy.forReason(
        PaywallRejectionReason.unclearProValue,
      );
      expect(unclearProValue.title, 'What Pro adds');
      expect(
        unclearProValue.body,
        'Free keeps today\u2019s save. Pro keeps the thread connected as it '
        'returns, fades, or changes.',
      );

      final wantToTryLonger = PaywallObjectionFollowUpCopy.forReason(
        PaywallRejectionReason.wantToTryLonger,
      );
      expect(wantToTryLonger.title, 'Try longer first');
      expect(
        wantToTryLonger.body,
        'Keep using ArchiveMe for free. Pro is for when you want the '
        'archive to keep connecting over time.',
      );

      final tooExpensive = PaywallObjectionFollowUpCopy.forReason(
        PaywallRejectionReason.tooExpensive,
      );
      expect(tooExpensive.title, 'Only if the continuity is worth it');
      expect(
        tooExpensive.body,
        'Your saves stay free. Pro adds the longer-term thread history.',
      );

      final noMoreSubscriptions = PaywallObjectionFollowUpCopy.forReason(
        PaywallRejectionReason.noMoreSubscriptions,
      );
      expect(
        noMoreSubscriptions.title,
        'No pressure to add another subscription',
      );
      expect(
        noMoreSubscriptions.body,
        'Today\u2019s archive stays free. Pro is only for ongoing '
        'continuity, and you can manage it through the App Store.',
      );
    });

    test('no VoiceMemory and no banned words in any variant', () {
      final all = [
        for (final reason in PaywallRejectionReason.values) ...[
          PaywallObjectionFollowUpCopy.forReason(reason).title,
          PaywallObjectionFollowUpCopy.forReason(reason).body,
        ],
      ].join(' ').toLowerCase();
      for (final banned in const [
        'voicememory',
        'must',
        'should',
        'task',
        'homework',
        'failure',
        'lazy',
        'weak',
        'diagnose',
        'definitely',
        'therapy',
        'treatment',
        'urgency',
        'limited time',
        'offer ends',
        'lose access',
        'locked out',
      ]) {
        expect(
          all,
          isNot(contains(banned)),
          reason: 'follow-up copy must not contain "$banned"',
        );
      }
    });
  });

  group('Objection store', () {
    test('records and round-trips every stable reason id', () async {
      for (final reason in PaywallRejectionReason.values) {
        final store = PaywallObjectionStore(prefs: _MemoryPrefs());
        expect(await store.lastReason(), isNull);
        await store.recordRejection(reason, source: 'value_moment');
        expect(await store.lastReason(), reason);
      }
    });

    test(
      'stores only reason_id, created_at, and source — never content',
      () async {
        final prefs = _MemoryPrefs();
        final store = PaywallObjectionStore(
          prefs: prefs,
          now: () => DateTime(2026, 6, 11, 12),
        );
        await store.recordRejection(
          PaywallRejectionReason.tooExpensive,
          source: 'general_pro',
        );

        final data = prefs.maps[PaywallObjectionStore.prefsKey]!;
        expect(data.keys.toSet(), {'reason_id', 'created_at', 'source'});
        expect(data['reason_id'], 'too_expensive');
        expect(data['created_at'], DateTime(2026, 6, 11, 12).toIso8601String());
        expect(data['source'], 'general_pro');
      },
    );

    test('unknown stored id and missing prefs read as no reason', () async {
      final prefs = _MemoryPrefs();
      prefs.maps[PaywallObjectionStore.prefsKey] = {
        'reason_id': 'I always ruin things at work',
      };
      expect(await PaywallObjectionStore(prefs: prefs).lastReason(), isNull);
      // No persistence available (e.g. services not initialized) — silent.
      final detached = PaywallObjectionStore();
      await detached.recordRejection(PaywallRejectionReason.notEnoughProof);
      expect(await detached.lastReason(), isNull);
    });
  });

  group('Objection follow-up gate', () {
    test('never for Pro users', () {
      expect(
        PaywallObjectionFollowUp.shouldShow(
          isPro: true,
          reason: PaywallRejectionReason.notEnoughProof,
        ),
        isFalse,
      );
    });

    test('nothing without a reason', () {
      expect(
        PaywallObjectionFollowUp.shouldShow(isPro: false, reason: null),
        isFalse,
      );
    });

    test('at most once per session', () {
      expect(
        PaywallObjectionFollowUp.shouldShow(
          isPro: false,
          reason: PaywallRejectionReason.tooExpensive,
        ),
        isTrue,
      );
      PaywallObjectionFollowUp.shownThisSession = true;
      expect(
        PaywallObjectionFollowUp.shouldShow(
          isPro: false,
          reason: PaywallRejectionReason.tooExpensive,
        ),
        isFalse,
      );
    });
  });

  group('Paywall screen integration', () {
    testWidgets('a stored reason renders its block below the clarity block', (
      tester,
    ) async {
      final store = PaywallObjectionStore(prefs: _MemoryPrefs());
      await store.recordRejection(
        PaywallRejectionReason.notEnoughProof,
        source: 'value_moment',
      );
      await pumpPaywall(tester, store: store);

      final followUp = find.byKey(const Key('paywall_objection_follow_up'));
      expect(followUp, findsOneWidget);
      expect(find.text('More proof before you decide'), findsOneWidget);
      expect(
        find.text(
          'Your archive can now show connected recordings, returned '
          'threads, and exact evidence before you choose Pro.',
        ),
        findsOneWidget,
      );
      // Below the above-fold clarity block.
      final clarity = find.byKey(const Key('paywall_above_fold_clarity'));
      expect(clarity, findsOneWidget);
      expect(
        tester.getTopLeft(followUp).dy,
        greaterThan(tester.getTopLeft(clarity).dy),
        reason: 'follow-up must sit below the above-fold clarity block',
      );
    });

    test('follow-up sits below the clarity block and above plan cards in '
        'the purchase body', () {
      // The purchase body only renders with live offerings, which widget
      // tests cannot fabricate — so pin the structure at the source.
      final source = File('lib/screens/paywall_screen.dart').readAsStringSync();
      final clarityIdx = source.indexOf(
        '// Objection follow-up: below the clarity block, above plan cards.',
      );
      expect(clarityIdx, greaterThan(-1));
      final followUpIdx = source.indexOf(
        '_objectionFollowUpSection(),',
        clarityIdx,
      );
      final planCardsIdx = source.indexOf(
        '...orderedPaywallPlans(',
        followUpIdx,
      );
      expect(
        followUpIdx,
        greaterThan(clarityIdx),
        reason: 'follow-up must come after the clarity block',
      );
      expect(
        planCardsIdx,
        greaterThan(followUpIdx),
        reason: 'follow-up must come before the plan cards',
      );
    });

    testWidgets('no stored reason renders nothing', (tester) async {
      await pumpPaywall(
        tester,
        store: PaywallObjectionStore(prefs: _MemoryPrefs()),
      );
      expect(
        find.byKey(const Key('paywall_objection_follow_up')),
        findsNothing,
      );
      expect(
        eventsNamed(ActivationFunnelAnalytics.paywallObjectionFollowUpSeen),
        isEmpty,
      );
    });

    testWidgets('the dismissal flow that captures the reason never shows the '
        'follow-up — only a later paywall does', (tester) async {
      final prefs = _MemoryPrefs();
      final store = PaywallObjectionStore(prefs: prefs);
      await pumpPaywall(tester, store: store);
      expect(
        find.byKey(const Key('paywall_objection_follow_up')),
        findsNothing,
      );

      // Back out and answer the rejection prompt.
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('paywall_rejection_too_expensive')),
      );
      await tester.pump();
      // The reason is now persisted, but this flow still shows no follow-up.
      expect(
        find.byKey(const Key('paywall_objection_follow_up')),
        findsNothing,
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('RECORD HOME'), findsOneWidget);
      expect(
        prefs.maps[PaywallObjectionStore.prefsKey]?['reason_id'],
        'too_expensive',
      );

      // The next paywall visit answers the objection.
      await pumpPaywall(tester, store: store);
      expect(
        find.byKey(const Key('paywall_objection_follow_up')),
        findsOneWidget,
      );
      expect(find.text('Only if the continuity is worth it'), findsOneWidget);
    });

    testWidgets('shows at most once per session', (tester) async {
      final store = PaywallObjectionStore(prefs: _MemoryPrefs());
      await store.recordRejection(PaywallRejectionReason.unclearProValue);
      await pumpPaywall(tester, store: store);
      expect(
        find.byKey(const Key('paywall_objection_follow_up')),
        findsOneWidget,
      );

      // A second paywall in the same session shows nothing.
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpPaywall(tester, store: store);
      expect(
        find.byKey(const Key('paywall_objection_follow_up')),
        findsNothing,
      );
      expect(
        eventsNamed(ActivationFunnelAnalytics.paywallObjectionFollowUpSeen),
        hasLength(1),
      );
    });

    testWidgets('seen event fires once with reason and source only', (
      tester,
    ) async {
      final store = PaywallObjectionStore(prefs: _MemoryPrefs());
      await store.recordRejection(
        PaywallRejectionReason.wantToTryLonger,
        source: 'value_moment',
      );
      await pumpPaywall(tester, store: store);
      await tester.pump();

      final seen = eventsNamed(
        ActivationFunnelAnalytics.paywallObjectionFollowUpSeen,
      );
      expect(seen, hasLength(1), reason: 'rebuilds never spam the event');
      expect(seen.single.properties, {
        'reason': 'want_to_try_longer',
        'source': 'value_moment',
      });
    });

    testWidgets('no raw notes, snippets, or source terms in any payload', (
      tester,
    ) async {
      final store = PaywallObjectionStore(prefs: _MemoryPrefs());
      await store.recordRejection(PaywallRejectionReason.notEnoughProof);
      await pumpPaywall(tester, store: store);

      const allowed = {'reason', 'source'};
      final safeValue = RegExp(r'^[a-z0-9_]{1,40}$');
      final followUpEvents = eventsNamed(
        ActivationFunnelAnalytics.paywallObjectionFollowUpSeen,
      );
      expect(followUpEvents, isNotEmpty);
      for (final e in followUpEvents) {
        expect(e.properties.keys.toSet().difference(allowed), isEmpty);
        for (final value in e.properties.values) {
          expect(
            safeValue.hasMatch('$value'),
            isTrue,
            reason: '${e.event} carries unsafe value "$value"',
          );
        }
      }
    });

    test('RevenueCat identifiers and purchase logic are unchanged', () {
      expect(RevenueCatService.proEntitlementId, 'pro');
      final source = File('lib/screens/paywall_screen.dart').readAsStringSync();
      expect(
        RegExp(
          r'FilledButton\(\s*onPressed: _busy \? null : _continue,',
        ).hasMatch(source),
        isTrue,
        reason: 'the purchase CTA must still call _continue',
      );
    });
  });
}
