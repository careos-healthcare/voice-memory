import 'dart:io';

import 'package:archiveme_mobile/billing/paywall_attribution_event.dart';
import 'package:archiveme_mobile/billing/paywall_attribution_store.dart';
import 'package:archiveme_mobile/billing/paywall_rejection_reason.dart';
import 'package:archiveme_mobile/billing/paywall_route_args.dart';
import 'package:archiveme_mobile/billing/paywall_source.dart';
import 'package:archiveme_mobile/screens/paywall_screen.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:archiveme_mobile/widgets/billing/paywall_rejection_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/memory_pressure_stores.dart';

MobilePrefsStore _dummyPrefs() =>
    MobilePrefsStore(file: File('test/tmp/rejection/unused_prefs.json'));

/// In-memory attribution store — avoids file IO in the widget test zone.
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
    ActivationFunnelAnalytics.resetForTest();
    ActivationFunnelAnalytics.captureForTest(
      (event, properties) =>
          captured.add((event: event, properties: properties)),
    );
    PaywallRejectionCapture.resetSessionForTest();
  });

  tearDown(() {
    ActivationFunnelAnalytics.resetForTest();
    PaywallRejectionCapture.resetSessionForTest();
  });

  Future<void> pumpPaywall(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1800));
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
    await tester.pumpAndSettle();
  }

  Future<void> pumpPromptOnly(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PaywallRejectionPrompt(source: 'general_pro'),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('Rejection reasons', () {
    test('reason ids are stable snake_case', () {
      expect(PaywallRejectionReason.notEnoughProof.id, 'not_enough_proof');
      expect(PaywallRejectionReason.tooExpensive.id, 'too_expensive');
      expect(
        PaywallRejectionReason.noMoreSubscriptions.id,
        'no_more_subscriptions',
      );
      expect(PaywallRejectionReason.unclearProValue.id, 'unclear_pro_value');
      expect(PaywallRejectionReason.wantToTryLonger.id, 'want_to_try_longer');
      for (final reason in PaywallRejectionReason.values) {
        expect(RegExp(r'^[a-z0-9_]+$').hasMatch(reason.id), isTrue);
      }
    });

    test(
      'prompt never shows for Pro users — covers the post-purchase state',
      () {
        expect(PaywallRejectionCapture.shouldPrompt(isPro: true), isFalse);
        expect(PaywallRejectionCapture.shouldPrompt(isPro: false), isTrue);
        PaywallRejectionCapture.promptShownThisSession = true;
        expect(PaywallRejectionCapture.shouldPrompt(isPro: false), isFalse);
      },
    );

    test('copy has no guilt, pressure, or VoiceMemory words', () {
      final copy = [
        PaywallRejectionPromptCopy.title,
        PaywallRejectionPromptCopy.subtitle,
        PaywallRejectionPromptCopy.skipLabel,
        PaywallRejectionPromptCopy.thanksLine,
        for (final reason in PaywallRejectionReason.values) reason.label,
      ].join(' ').toLowerCase();
      const banned = [
        'must',
        'should',
        'task',
        'homework',
        'failure',
        'lazy',
        'weak',
        'problem',
        'fix',
        'diagnose',
        'definitely',
        'voicememory',
        'therapy',
        'treatment',
      ];
      for (final word in banned) {
        expect(copy, isNot(contains(word)), reason: 'banned word: $word');
      }
    });
  });

  group('Prompt widget', () {
    testWidgets('each reason logs its stable reason id', (tester) async {
      for (final reason in PaywallRejectionReason.values) {
        captured.clear();
        // Tear down the previous instance so each reason gets fresh state.
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpPromptOnly(tester);

        await tester.tap(find.byKey(Key('paywall_rejection_${reason.id}')));
        await tester.pump();

        final events = eventsNamed(
          ActivationFunnelAnalytics.paywallRejectionReasonSelected,
        );
        expect(events, hasLength(1), reason: 'reason: ${reason.id}');
        expect(events.single.properties, {
          'reason': reason.id,
          'source': 'general_pro',
        });
        expect(
          find.text(PaywallRejectionPromptCopy.thanksLine),
          findsOneWidget,
        );
        // Flush the brief auto-close timer.
        await tester.pump(const Duration(seconds: 1));
      }
    });

    testWidgets('one tap only — options disappear after answering', (
      tester,
    ) async {
      await pumpPromptOnly(tester);
      await tester.tap(
        find.byKey(const Key('paywall_rejection_too_expensive')),
      );
      await tester.pump();

      for (final reason in PaywallRejectionReason.values) {
        expect(find.byKey(Key('paywall_rejection_${reason.id}')), findsNothing);
      }
      expect(
        eventsNamed(ActivationFunnelAnalytics.paywallRejectionReasonSelected),
        hasLength(1),
      );
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('skip logs the skipped event', (tester) async {
      await pumpPromptOnly(tester);
      await tester.tap(find.byKey(const Key('paywall_rejection_skip')));
      await tester.pump();

      expect(
        eventsNamed(ActivationFunnelAnalytics.paywallRejectionPromptSkipped),
        hasLength(1),
      );
      expect(
        eventsNamed(ActivationFunnelAnalytics.paywallRejectionReasonSelected),
        isEmpty,
      );
    });
  });

  group('Paywall screen flow', () {
    testWidgets('prompt appears after backing out of the paywall', (
      tester,
    ) async {
      await pumpPaywall(tester);
      expect(find.text(PaywallRejectionPromptCopy.title), findsNothing);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text(PaywallRejectionPromptCopy.title), findsOneWidget);
      expect(find.text(PaywallRejectionPromptCopy.subtitle), findsOneWidget);
      final seen = eventsNamed(
        ActivationFunnelAnalytics.paywallRejectionPromptSeen,
      );
      expect(seen, hasLength(1));
      expect(seen.single.properties, {'source': 'value_moment'});
    });

    testWidgets('answering closes the sheet and leaves the paywall', (
      tester,
    ) async {
      await pumpPaywall(tester);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('paywall_rejection_not_enough_proof')),
      );
      await tester.pump();
      expect(find.text(PaywallRejectionPromptCopy.thanksLine), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('RECORD HOME'), findsOneWidget);
      final selected = eventsNamed(
        ActivationFunnelAnalytics.paywallRejectionReasonSelected,
      );
      expect(selected, hasLength(1));
      expect(selected.single.properties, {
        'reason': 'not_enough_proof',
        'source': 'value_moment',
      });
      // No skip event when a reason was given.
      expect(
        eventsNamed(ActivationFunnelAnalytics.paywallRejectionPromptSkipped),
        isEmpty,
      );
    });

    testWidgets('prompt appears only once per session', (tester) async {
      await pumpPaywall(tester);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('paywall_rejection_skip')));
      await tester.pumpAndSettle();
      expect(find.text('RECORD HOME'), findsOneWidget);

      // A second paywall visit in the same session: no prompt, direct exit.
      await pumpPaywall(tester);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text(PaywallRejectionPromptCopy.title), findsNothing);
      expect(find.text('RECORD HOME'), findsOneWidget);
      expect(
        eventsNamed(ActivationFunnelAnalytics.paywallRejectionPromptSeen),
        hasLength(1),
      );
      expect(
        eventsNamed(ActivationFunnelAnalytics.paywallRejectionPromptSkipped),
        hasLength(1),
      );
    });

    testWidgets('no private content in any rejection payload', (tester) async {
      await pumpPaywall(tester);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('paywall_rejection_want_to_try_longer')),
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final rejectionEvents = captured.where(
        (e) => e.event.startsWith('paywall_rejection'),
      );
      expect(rejectionEvents, isNotEmpty);
      const allowed = {
        'source',
        'reason',
        'entry_count',
        'has_connected_thread',
      };
      final safeValue = RegExp(r'^[a-z0-9_]{1,40}$');
      for (final e in rejectionEvents) {
        expect(e.properties.keys.toSet().difference(allowed), isEmpty);
        for (final value in e.properties.values) {
          expect(
            value is int || safeValue.hasMatch('$value'),
            isTrue,
            reason: '${e.event} carries unsafe value "$value"',
          );
        }
      }
    });
  });
}