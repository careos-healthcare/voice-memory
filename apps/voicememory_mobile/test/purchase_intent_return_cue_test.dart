import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/billing/paywall_route_args.dart';
import 'package:voicememory_mobile/billing/paywall_source.dart';
import 'package:voicememory_mobile/billing/purchase_intent_return_cue.dart';
import 'package:voicememory_mobile/billing/revenuecat_service.dart';
import 'package:voicememory_mobile/dev/visual_audit_overrides.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/billing/purchase_intent_return_cue_card.dart';

import 'support/memory_pressure_stores.dart';

/// In-memory prefs — keeps store IO out of the widget test zone.
class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs() : super(file: File('test/tmp/purchase_intent/unused.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
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
    PurchaseIntentReturnCue.resetSessionForTest();
  });

  tearDown(() {
    ActivationFunnelAnalytics.resetForTest();
    PurchaseIntentReturnCue.resetSessionForTest();
  });

  group('Copy guardrails', () {
    test('copy is exact', () {
      expect(PurchaseIntentReturnCue.title, 'Still want Pro to continue this?');
      expect(
        PurchaseIntentReturnCue.body,
        'Your saves stay free. Pro keeps the thread connected over time.',
      );
      expect(PurchaseIntentReturnCue.ctaLabel, 'See Pro');
      expect(PurchaseIntentReturnCue.dismissLabel, 'Not now');
    });

    test('no pressure, guilt, or VoiceMemory language', () {
      final all = [
        PurchaseIntentReturnCue.title,
        PurchaseIntentReturnCue.body,
        PurchaseIntentReturnCue.ctaLabel,
        PurchaseIntentReturnCue.dismissLabel,
      ].join(' ').toLowerCase();
      for (final banned in const [
        'voicememory',
        'complete your purchase',
        'you left',
        'failed',
        'failure',
        'almost there',
        'finish',
        'must',
        'should',
        'hurry',
        'limited time',
        'last chance',
        'offer ends',
        'expires',
        'lose access',
        'locked out',
        'missed',
        'don\u2019t miss',
      ]) {
        expect(
          all,
          isNot(contains(banned)),
          reason: 'cue copy must not contain "$banned"',
        );
      }
    });
  });

  group('Purchase intent store', () {
    test('purchase start persists only the fixed-shape payload', () async {
      final prefs = _MemoryPrefs();
      final store = PurchaseIntentStore(
        prefs: prefs,
        now: () => DateTime(2026, 6, 11, 12),
      );
      await store.recordPurchaseStarted(source: 'value_moment', plan: 'yearly');

      final data = prefs.maps[PurchaseIntentStore.prefsKey]!;
      expect(data.keys.toSet(), {
        'last_purchase_started_at',
        'source',
        'plan',
        'completed',
      });
      expect(
        data['last_purchase_started_at'],
        DateTime(2026, 6, 11, 12).toIso8601String(),
      );
      expect(data['source'], 'value_moment');
      expect(data['plan'], 'yearly');
      expect(data['completed'], isFalse);
    });

    test(
      'pending intent exists only after a start without completion',
      () async {
        final store = PurchaseIntentStore(prefs: _MemoryPrefs());
        // Before any purchase start: nothing.
        expect(await store.pendingIntent(), isNull);

        await store.recordPurchaseStarted(
          source: 'general_pro',
          plan: 'monthly',
        );
        final pending = await store.pendingIntent();
        expect(pending, isNotNull);
        expect(pending!.source, 'general_pro');
        expect(pending.plan, 'monthly');

        // After completion: gone for good.
        await store.recordPurchaseCompleted();
        expect(await store.pendingIntent(), isNull);
      },
    );

    test('unsafe source or plan values are dropped, never surfaced', () async {
      final prefs = _MemoryPrefs();
      final store = PurchaseIntentStore(prefs: prefs);
      await store.recordPurchaseStarted(
        source: 'I always ruin things at work',
        plan: 'Belief: checking my phone',
      );
      final data = prefs.maps[PurchaseIntentStore.prefsKey]!;
      expect(data.containsKey('source'), isFalse);
      expect(data.containsKey('plan'), isFalse);

      final pending = await store.pendingIntent();
      expect(pending, isNotNull);
      expect(pending!.source, isNull);
      expect(pending.plan, isNull);
    });

    test('detached store (no persistence) stays silent', () async {
      final store = PurchaseIntentStore();
      await store.recordPurchaseStarted(source: 'general_pro');
      await store.recordPurchaseCompleted();
      expect(await store.pendingIntent(), isNull);
    });
  });

  group('Session gate', () {
    test('requires a pending intent and a free user', () {
      expect(
        PurchaseIntentReturnCue.shouldShow(
          isPro: false,
          hasPendingIntent: true,
        ),
        isTrue,
      );
      expect(
        PurchaseIntentReturnCue.shouldShow(isPro: true, hasPendingIntent: true),
        isFalse,
      );
      expect(
        PurchaseIntentReturnCue.shouldShow(
          isPro: false,
          hasPendingIntent: false,
        ),
        isFalse,
      );
    });

    test('never in the same session that started the purchase', () {
      PurchaseIntentReturnCue.purchaseStartedThisSession = true;
      expect(
        PurchaseIntentReturnCue.shouldShow(
          isPro: false,
          hasPendingIntent: true,
        ),
        isFalse,
        reason:
            'cancelling the App Store sheet must not trigger the cue '
            'in the same flow',
      );
    });

    test('at most once per session', () {
      PurchaseIntentReturnCue.shownThisSession = true;
      expect(
        PurchaseIntentReturnCue.shouldShow(
          isPro: false,
          hasPendingIntent: true,
        ),
        isFalse,
      );
    });
  });

  group('Cue card widget', () {
    Future<void> pumpCard(
      WidgetTester tester, {
      VoidCallback? onSeePro,
      VoidCallback? onDismiss,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PurchaseIntentReturnCueCard(
              intent: const PendingPurchaseIntent(
                source: 'value_moment',
                plan: 'yearly',
              ),
              onSeePro: onSeePro ?? () {},
              onDismiss: onDismiss ?? () {},
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders the exact copy with both actions', (tester) async {
      await pumpCard(tester);
      expect(find.text(PurchaseIntentReturnCue.title), findsOneWidget);
      expect(find.text(PurchaseIntentReturnCue.body), findsOneWidget);
      expect(find.text(PurchaseIntentReturnCue.ctaLabel), findsOneWidget);
      expect(find.text(PurchaseIntentReturnCue.dismissLabel), findsOneWidget);
    });

    testWidgets('seen fires once per session; tapped and dismissed carry '
        'only source and plan', (tester) async {
      await pumpCard(tester);
      await pumpCard(tester); // Rebuild — seen must not repeat.

      final seen = eventsNamed(
        ActivationFunnelAnalytics.purchaseIntentReturnCueSeen,
      );
      expect(seen, hasLength(1));
      expect(seen.single.properties, {
        'source': 'value_moment',
        'plan': 'yearly',
      });

      await tester.tap(find.byKey(const Key('purchase_intent_return_cue_cta')));
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('purchase_intent_return_cue_dismiss')),
      );
      await tester.pump();

      for (final name in [
        ActivationFunnelAnalytics.purchaseIntentReturnCueTapped,
        ActivationFunnelAnalytics.purchaseIntentReturnCueDismissed,
      ]) {
        final events = eventsNamed(name);
        expect(events, hasLength(1), reason: name);
        expect(events.single.properties, {
          'source': 'value_moment',
          'plan': 'yearly',
        });
      }
      // No private content anywhere in the cue payloads.
      for (final e in captured) {
        expect(e.properties.keys, everyElement(isIn(['source', 'plan'])));
      }
    });
  });

  group('Record screen integration', () {
    late Directory tempDir;
    late _MemoryPrefs prefs;
    PaywallRouteArgs? capturedArgs;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_purchase_intent_');
      prefs = _MemoryPrefs();
      capturedArgs = null;
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
        skipRevenueCat: true,
      );
      VisualAuditOverrides.setRecordPresentation(
        const RecordAuditPresentation(ui: RecordUiState.ready),
      );
    });

    tearDown(() {
      VisualAuditOverrides.setRecordPresentation(null);
    });

    Future<void> pumpRecordScreen(
      WidgetTester tester, {
      bool pro = false,
    }) async {
      await tester.binding.setSurfaceSize(const Size(390, 3200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: RecordScreen(
                suggestionAttributionStore: MemorySuggestionAttributionStore(),
                entitlementReader: FakeArchiveEntitlementReader(pro: pro),
                purchaseIntentStore: PurchaseIntentStore(prefs: prefs),
              ),
            ),
          ),
          GoRoute(
            path: '/subscription',
            builder: (context, state) {
              capturedArgs = state.extra as PaywallRouteArgs?;
              return const Scaffold(
                body: Center(child: Text('SUBSCRIPTION_MARKER')),
              );
            },
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> pumpUntilPurchaseCue(WidgetTester tester) async {
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byKey(const Key('purchase_intent_return_cue')).evaluate().isNotEmpty) {
          return;
        }
      }
    }

    Future<void> seedPendingIntent() async {
      await PurchaseIntentStore(
        prefs: prefs,
      ).recordPurchaseStarted(source: 'value_moment', plan: 'yearly');
    }

    Future<void> seedComparisonEntries() async {
      await AppServices.instance.journalStore.save(
        JournalEntry(
          id: 'e1',
          createdAt: DateTime(2026, 6, 10),
          transcript: 'First saved moment with enough transcript length here.',
          durationSeconds: 20,
          reflection: const Reflection(
            mood: 'thoughtful',
            emotionalIntensity: 2,
            recurringThemes: ['work'],
            exactLanguagePattern: '',
            concreteObservation: 'Observation.',
            repeatedSignal: '',
          ),
        ),
      );
      await AppServices.instance.journalStore.save(
        JournalEntry(
          id: 'e2',
          createdAt: DateTime(2026, 6, 11),
          transcript: 'Second saved moment with enough transcript length here.',
          durationSeconds: 20,
          reflection: const Reflection(
            mood: 'thoughtful',
            emotionalIntensity: 2,
            recurringThemes: ['work'],
            exactLanguagePattern: '',
            concreteObservation: 'Observation.',
            repeatedSignal: '',
          ),
        ),
      );
    }

    testWidgets('cue suppressed at zero entries even with pending intent', (
      tester,
    ) async {
      await tester.runAsync(seedPendingIntent);
      await pumpRecordScreen(tester);
      expect(find.byKey(const Key('purchase_intent_return_cue')), findsNothing);
    });

    testWidgets('cue appears after purchase start without completion', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await seedPendingIntent();
        await seedComparisonEntries();
      });
      await pumpRecordScreen(tester);
      await pumpUntilPurchaseCue(tester);
      expect(
        find.byKey(const Key('purchase_intent_return_cue')),
        findsOneWidget,
      );
      expect(find.text(PurchaseIntentReturnCue.title), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no cue before any purchase start', (tester) async {
      await pumpRecordScreen(tester);
      expect(find.byKey(const Key('purchase_intent_return_cue')), findsNothing);
    });

    testWidgets('no cue after the purchase completed', (tester) async {
      await tester.runAsync(() async {
        await seedPendingIntent();
        await PurchaseIntentStore(prefs: prefs).recordPurchaseCompleted();
      });
      await pumpRecordScreen(tester);
      expect(find.byKey(const Key('purchase_intent_return_cue')), findsNothing);
    });

    testWidgets('no cue for Pro users', (tester) async {
      await tester.runAsync(seedPendingIntent);
      await pumpRecordScreen(tester, pro: true);
      expect(find.byKey(const Key('purchase_intent_return_cue')), findsNothing);
    });

    testWidgets('dismiss hides the cue for the rest of the session', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await seedPendingIntent();
        await seedComparisonEntries();
      });
      await pumpRecordScreen(tester);
      await pumpUntilPurchaseCue(tester);
      await tester.ensureVisible(
        find.byKey(const Key('purchase_intent_return_cue_dismiss')),
      );
      await tester.tap(
        find.byKey(const Key('purchase_intent_return_cue_dismiss')),
      );
      await tester.pump();
      expect(find.byKey(const Key('purchase_intent_return_cue')), findsNothing);
      expect(
        eventsNamed(ActivationFunnelAnalytics.purchaseIntentReturnCueDismissed),
        hasLength(1),
      );

      // A fresh screen in the same session still shows nothing.
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpRecordScreen(tester);
      expect(find.byKey(const Key('purchase_intent_return_cue')), findsNothing);
    });

    testWidgets('CTA routes to the existing paywall', (tester) async {
      await tester.runAsync(() async {
        await seedPendingIntent();
        await seedComparisonEntries();
      });
      await pumpRecordScreen(tester);
      await pumpUntilPurchaseCue(tester);
      await tester.ensureVisible(
        find.byKey(const Key('purchase_intent_return_cue_cta')),
      );
      await tester.tap(find.byKey(const Key('purchase_intent_return_cue_cta')));
      await tester.pumpAndSettle();

      expect(find.text('SUBSCRIPTION_MARKER'), findsOneWidget);
      // The original purchase source carries through to the paywall.
      expect(capturedArgs?.source, PaywallSource.valueMoment);
      expect(capturedArgs?.sourceRoute, '/record');
      expect(
        eventsNamed(ActivationFunnelAnalytics.purchaseIntentReturnCueTapped),
        hasLength(1),
      );
    });
  });

  group('Purchase logic unchanged', () {
    test('RevenueCat identifiers and the purchase path are untouched', () {
      expect(RevenueCatService.proEntitlementId, 'pro');
      final source = File('lib/screens/paywall_screen.dart').readAsStringSync();
      expect(
        RegExp(
          r'FilledButton\(\s*onPressed: _busy \? null : _continue,',
        ).hasMatch(source),
        isTrue,
      );
      expect(
        source.contains(
          'await AppServices.instance.billing.purchaseNative(package);',
        ),
        isTrue,
        reason: 'the native purchase call must be unchanged',
      );
      // The intent is recorded around the purchase, never replacing it.
      expect(
        RegExp(
          r'PurchaseIntentReturnCue\.purchaseStartedThisSession = true;[\s\S]{0,2000}'
          r'purchaseNative\(package\)',
        ).hasMatch(source),
        isTrue,
      );
    });
  });
}
