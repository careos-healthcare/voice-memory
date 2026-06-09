import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/billing/paywall_attribution_event.dart';
import 'package:voicememory_mobile/billing/paywall_attribution_store.dart';
import 'package:voicememory_mobile/billing/paywall_route_args.dart';
import 'package:voicememory_mobile/billing/paywall_source.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/paywall_screen.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

MobilePrefsStore _dummyPrefs() =>
    MobilePrefsStore(file: File('test/tmp/attribution/unused_prefs.json'));

/// In-memory attribution store — keeps widget tests deterministic by avoiding
/// real file IO inside the fake-async test zone.
class _MemoryAttributionStore extends PaywallAttributionStore {
  _MemoryAttributionStore() : super(_dummyPrefs());

  final List<PaywallAttributionEvent> recorded = [];

  @override
  Future<void> record(
    PaywallAttributionEventType type, {
    required PaywallSource source,
    String? sourceRoute,
    DateTime? now,
  }) async {
    recorded.add(
      PaywallAttributionEvent(
        type: type,
        source: source,
        sourceRoute: sourceRoute,
        at: now ?? DateTime(2026, 6, 9),
      ),
    );
  }

  @override
  Future<List<PaywallAttributionEvent>> events() async => List.of(recorded);
}

Future<PaywallAttributionStore> _openFileStore(String name) async {
  final path = 'test/tmp/attribution/$name.json';
  final file = File(path);
  if (await file.exists()) await file.delete();
  return PaywallAttributionStore.forPrefs(await MobilePrefsStore.open(path));
}

Future<_MemoryAttributionStore> _pumpPaywall(
  WidgetTester tester, {
  PaywallRouteArgs? args,
}) async {
  final store = _MemoryAttributionStore();
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
              attributionStore: store,
            ),
          ),
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

void main() {
  group('Attribution event model', () {
    test('event types use stable ids', () {
      expect(PaywallAttributionEventType.paywallSeen.id, 'paywall_seen');
      expect(
        PaywallAttributionEventType.purchaseStarted.id,
        'purchase_started',
      );
      expect(
        PaywallAttributionEventType.purchaseCompleted.id,
        'purchase_completed',
      );
      expect(PaywallAttributionEventType.restoreStarted.id, 'restore_started');
      expect(
        PaywallAttributionEventType.restoreCompleted.id,
        'restore_completed',
      );
      for (final type in PaywallAttributionEventType.values) {
        expect(PaywallAttributionEventType.fromId(type.id), type);
      }
      expect(PaywallAttributionEventType.fromId('unknown'), isNull);
    });

    test('event json round-trips source, route, and timestamp', () {
      final event = PaywallAttributionEvent(
        type: PaywallAttributionEventType.purchaseCompleted,
        source: PaywallSource.pressureReview,
        sourceRoute: '/pressure-insights',
        at: DateTime(2026, 6, 9, 21, 30),
      );
      final restored = PaywallAttributionEvent.fromJson(event.toJson());
      expect(restored, isNotNull);
      expect(restored!.type, PaywallAttributionEventType.purchaseCompleted);
      expect(restored.source, PaywallSource.pressureReview);
      expect(restored.sourceRoute, '/pressure-insights');
      expect(restored.at, DateTime(2026, 6, 9, 21, 30));
    });
  });

  group('Attribution store (prefs-backed)', () {
    test('purchase_started records correct source', () async {
      final store = await _openFileStore('purchase_started');
      await store.record(
        PaywallAttributionEventType.purchaseStarted,
        source: PaywallSource.pressurePatternHistory,
        sourceRoute: '/pressure-insights',
      );

      final events = await store.events();
      expect(events, hasLength(1));
      expect(events.single.type.id, 'purchase_started');
      expect(events.single.source.id, 'pressure_pattern_history');
      expect(events.single.sourceRoute, '/pressure-insights');
    });

    test('purchase_completed records correct source', () async {
      final store = await _openFileStore('purchase_completed');
      await store.record(
        PaywallAttributionEventType.purchaseStarted,
        source: PaywallSource.pressureReview,
      );
      await store.record(
        PaywallAttributionEventType.purchaseCompleted,
        source: PaywallSource.pressureReview,
      );

      final completed = await store
          .eventsOfType(PaywallAttributionEventType.purchaseCompleted);
      expect(completed, hasLength(1));
      expect(completed.single.source, PaywallSource.pressureReview);
    });

    test('restore_started and restore_completed record correct source',
        () async {
      final store = await _openFileStore('restore');
      await store.record(
        PaywallAttributionEventType.restoreStarted,
        source: PaywallSource.askArchive,
      );
      await store.record(
        PaywallAttributionEventType.restoreCompleted,
        source: PaywallSource.askArchive,
      );

      final events = await store.events();
      expect(events, hasLength(2));
      expect(events[0].type, PaywallAttributionEventType.restoreStarted);
      expect(events[1].type, PaywallAttributionEventType.restoreCompleted);
      expect(events.map((e) => e.source).toSet(), {PaywallSource.askArchive});
    });

    test('events persist across store reopen, oldest first', () async {
      final path = 'test/tmp/attribution/reopen.json';
      final file = File(path);
      if (await file.exists()) await file.delete();

      final store =
          PaywallAttributionStore.forPrefs(await MobilePrefsStore.open(path));
      await store.record(
        PaywallAttributionEventType.paywallSeen,
        source: PaywallSource.generalPro,
        now: DateTime(2026, 6, 9, 10),
      );
      await store.record(
        PaywallAttributionEventType.purchaseStarted,
        source: PaywallSource.generalPro,
        now: DateTime(2026, 6, 9, 11),
      );

      final reopened =
          PaywallAttributionStore.forPrefs(await MobilePrefsStore.open(path));
      final events = await reopened.events();
      expect(events, hasLength(2));
      expect(events[0].type, PaywallAttributionEventType.paywallSeen);
      expect(events[1].type, PaywallAttributionEventType.purchaseStarted);
    });

    test('event log is capped at maxEvents', () async {
      final store = await _openFileStore('cap');
      for (var i = 0; i < PaywallAttributionStore.maxEvents + 5; i++) {
        await store.record(
          PaywallAttributionEventType.paywallSeen,
          source: PaywallSource.generalPro,
          now: DateTime(2026, 1, 1).add(Duration(minutes: i)),
        );
      }
      final events = await store.events();
      expect(events, hasLength(PaywallAttributionStore.maxEvents));
      // Oldest entries were dropped.
      expect(events.first.at, DateTime(2026, 1, 1).add(const Duration(minutes: 5)));
    });
  });

  group('Paywall screen attribution', () {
    testWidgets('paywall_seen records the source it was opened from',
        (tester) async {
      final store = await _pumpPaywall(
        tester,
        args: const PaywallRouteArgs(
          source: PaywallSource.pressureReview,
          sourceRoute: '/pressure-insights',
        ),
      );

      final seen = store.recorded
          .where((e) => e.type == PaywallAttributionEventType.paywallSeen)
          .toList();
      expect(seen, hasLength(1));
      expect(seen.single.source, PaywallSource.pressureReview);
      expect(seen.single.sourceRoute, '/pressure-insights');
    });

    testWidgets('paywall_seen falls back to generalPro without a source',
        (tester) async {
      final store = await _pumpPaywall(tester);

      final seen = store.recorded
          .where((e) => e.type == PaywallAttributionEventType.paywallSeen)
          .toList();
      expect(seen, hasLength(1));
      expect(seen.single.source, PaywallSource.generalPro);
    });

    testWidgets('restore tap records restore_started with the right source',
        (tester) async {
      final store = await _pumpPaywall(
        tester,
        args: const PaywallRouteArgs(source: PaywallSource.askArchive),
      );

      await tester.ensureVisible(find.text(ConsumerUiCopy.restorePurchases));
      await tester.tap(
        find.text(ConsumerUiCopy.restorePurchases),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      final started = store.recorded
          .where((e) => e.type == PaywallAttributionEventType.restoreStarted)
          .toList();
      expect(started, hasLength(1));
      expect(started.single.source, PaywallSource.askArchive);
    });

    testWidgets('no VoiceMemory consumer copy on attributed paywall',
        (tester) async {
      await _pumpPaywall(
        tester,
        args: const PaywallRouteArgs(
          source: PaywallSource.pressurePatternHistory,
        ),
      );
      expect(find.textContaining('VoiceMemory'), findsNothing);

      for (final type in PaywallAttributionEventType.values) {
        expect(type.id, isNot(contains('VoiceMemory')));
      }
      for (final source in PaywallSource.values) {
        expect(source.id, isNot(contains('VoiceMemory')));
      }
    });
  });
}
