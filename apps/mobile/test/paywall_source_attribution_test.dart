import 'dart:io';

import 'package:archiveme_mobile/billing/paywall_attribution_event.dart';
import 'package:archiveme_mobile/billing/paywall_attribution_store.dart';
import 'package:archiveme_mobile/billing/paywall_route_args.dart';
import 'package:archiveme_mobile/billing/paywall_source.dart';
import 'package:archiveme_mobile/billing/suggestion_attribution_event.dart';
import 'package:archiveme_mobile/billing/suggestion_attribution_store.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/billing/screens/paywall_screen.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/memory_pressure_stores.dart';

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
  MemorySuggestionAttributionStore? suggestionStore,
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
              suggestionAttributionStore:
                  suggestionStore ?? MemorySuggestionAttributionStore(),
            ),
          ),
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

Future<SuggestionAttributionStore> _openSuggestionFileStore(String name) async {
  final path = 'test/tmp/attribution/suggestion_$name.json';
  final file = File(path);
  if (await file.exists()) await file.delete();
  return SuggestionAttributionStore.forPrefs(await MobilePrefsStore.open(path));
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

      final completed = await store.eventsOfType(
        PaywallAttributionEventType.purchaseCompleted,
      );
      expect(completed, hasLength(1));
      expect(completed.single.source, PaywallSource.pressureReview);
    });

    test(
      'restore_started and restore_completed record correct source',
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
      },
    );

    test('events persist across store reopen, oldest first', () async {
      const path = 'test/tmp/attribution/reopen.json';
      final file = File(path);
      if (await file.exists()) await file.delete();

      final store = PaywallAttributionStore.forPrefs(
        await MobilePrefsStore.open(path),
      );
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

      final reopened = PaywallAttributionStore.forPrefs(
        await MobilePrefsStore.open(path),
      );
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
          now: DateTime(2026).add(Duration(minutes: i)),
        );
      }
      final events = await store.events();
      expect(events, hasLength(PaywallAttributionStore.maxEvents));
      // Oldest entries were dropped.
      expect(
        events.first.at,
        DateTime(2026).add(const Duration(minutes: 5)),
      );
    });
  });

  group('Paywall screen attribution', () {
    testWidgets('paywall_seen records the source it was opened from', (
      tester,
    ) async {
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

    testWidgets('paywall_seen falls back to generalPro without a source', (
      tester,
    ) async {
      final store = await _pumpPaywall(tester);

      final seen = store.recorded
          .where((e) => e.type == PaywallAttributionEventType.paywallSeen)
          .toList();
      expect(seen, hasLength(1));
      expect(seen.single.source, PaywallSource.generalPro);
    });

    testWidgets('restore tap records restore_started with the right source', (
      tester,
    ) async {
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

    testWidgets('no VoiceMemory consumer copy on attributed paywall', (
      tester,
    ) async {
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

  group('Suggestion attribution events', () {
    test('event types use stable ids and round-trip through fromId', () {
      expect(
        SuggestionAttributionEventType.dailySuggestionsSeen.id,
        'daily_suggestions_seen',
      );
      expect(
        SuggestionAttributionEventType.startHereTapped.id,
        'start_here_tapped',
      );
      expect(
        SuggestionAttributionEventType.dailySuggestionTapped.id,
        'daily_suggestion_tapped',
      );
      expect(
        SuggestionAttributionEventType.startHereRecordingSaved.id,
        'start_here_recording_saved',
      );
      expect(
        SuggestionAttributionEventType.dailySuggestionRecordingSaved.id,
        'daily_suggestion_recording_saved',
      );
      expect(
        SuggestionAttributionEventType.suggestionToPaywallSeen.id,
        'suggestion_to_paywall_seen',
      );
      expect(
        SuggestionAttributionEventType.suggestionToPurchaseStarted.id,
        'suggestion_to_purchase_started',
      );
      expect(
        SuggestionAttributionEventType.suggestionToPurchaseCompleted.id,
        'suggestion_to_purchase_completed',
      );
      for (final type in SuggestionAttributionEventType.values) {
        expect(SuggestionAttributionEventType.fromId(type.id), type);
      }
      expect(SuggestionAttributionEventType.fromId('unknown'), isNull);
    });

    test('tap and save events map to the right surface', () {
      expect(
        SuggestionAttributionEventType.tappedFor(PaywallSource.startHereToday),
        SuggestionAttributionEventType.startHereTapped,
      );
      expect(
        SuggestionAttributionEventType.tappedFor(PaywallSource.dailySuggestion),
        SuggestionAttributionEventType.dailySuggestionTapped,
      );
      expect(
        SuggestionAttributionEventType.savedFor(PaywallSource.startHereToday),
        SuggestionAttributionEventType.startHereRecordingSaved,
      );
      expect(
        SuggestionAttributionEventType.savedFor(PaywallSource.dailySuggestion),
        SuggestionAttributionEventType.dailySuggestionRecordingSaved,
      );
    });

    test('event json round-trips type, suggestion id, and timestamp', () {
      final event = SuggestionAttributionEvent(
        type: SuggestionAttributionEventType.startHereTapped,
        suggestionId: 'recent_option_could_not_stop',
        at: DateTime(2026, 6, 10, 9, 15),
      );
      final restored = SuggestionAttributionEvent.fromJson(event.toJson());
      expect(restored, isNotNull);
      expect(restored!.type, SuggestionAttributionEventType.startHereTapped);
      expect(restored.suggestionId, 'recent_option_could_not_stop');
      expect(restored.at, DateTime(2026, 6, 10, 9, 15));
    });
  });

  group('Suggestion attribution store (prefs-backed)', () {
    test('start-here tap event is recorded with the suggestion id', () async {
      final store = await _openSuggestionFileStore('start_here_tap');
      await store.record(
        SuggestionAttributionEventType.startHereTapped,
        suggestionId: 'recent_option_guilty_resting',
      );

      final events = await store.events();
      expect(events, hasLength(1));
      expect(events.single.type.id, 'start_here_tapped');
      expect(events.single.suggestionId, 'recent_option_guilty_resting');
    });

    test('daily suggestion tap event is recorded', () async {
      final store = await _openSuggestionFileStore('daily_tap');
      await store.record(
        SuggestionAttributionEventType.dailySuggestionTapped,
        suggestionId: 'term_deadline',
      );

      final tapped = await store.eventsOfType(
        SuggestionAttributionEventType.dailySuggestionTapped,
      );
      expect(tapped, hasLength(1));
      expect(tapped.single.suggestionId, 'term_deadline');
    });

    test('recording saved from start-here records attribution', () async {
      final store = await _openSuggestionFileStore('start_here_saved');
      await store.record(
        SuggestionAttributionEventType.savedFor(PaywallSource.startHereToday),
      );

      final saved = await store.eventsOfType(
        SuggestionAttributionEventType.startHereRecordingSaved,
      );
      expect(saved, hasLength(1));
      expect(saved.single.type.id, 'start_here_recording_saved');
    });

    test('event log is capped at maxEvents', () async {
      final store = await _openSuggestionFileStore('cap');
      for (var i = 0; i < SuggestionAttributionStore.maxEvents + 5; i++) {
        await store.record(
          SuggestionAttributionEventType.dailySuggestionsSeen,
          now: DateTime(2026).add(Duration(minutes: i)),
        );
      }
      final events = await store.events();
      expect(events, hasLength(SuggestionAttributionStore.maxEvents));
      expect(
        events.first.at,
        DateTime(2026).add(const Duration(minutes: 5)),
      );
    });
  });

  group('Suggestion-to-Pro paywall funnel', () {
    testWidgets(
      'start-here sourced paywall records suggestion_to_paywall_seen',
      (tester) async {
        final suggestionStore = MemorySuggestionAttributionStore();
        await _pumpPaywall(
          tester,
          args: const PaywallRouteArgs(
            source: PaywallSource.startHereToday,
            sourceRoute: '/record',
          ),
          suggestionStore: suggestionStore,
        );

        final seen = suggestionStore.recorded
            .where(
              (e) =>
                  e.type ==
                  SuggestionAttributionEventType.suggestionToPaywallSeen,
            )
            .toList();
        expect(seen, hasLength(1));
      },
    );

    testWidgets(
      'daily suggestion sourced paywall records suggestion_to_paywall_seen',
      (tester) async {
        final suggestionStore = MemorySuggestionAttributionStore();
        await _pumpPaywall(
          tester,
          args: const PaywallRouteArgs(source: PaywallSource.dailySuggestion),
          suggestionStore: suggestionStore,
        );

        expect(
          suggestionStore.recorded.map((e) => e.type),
          contains(SuggestionAttributionEventType.suggestionToPaywallSeen),
        );
      },
    );

    testWidgets('non-suggestion sources record no suggestion funnel events', (
      tester,
    ) async {
      final suggestionStore = MemorySuggestionAttributionStore();
      await _pumpPaywall(
        tester,
        args: const PaywallRouteArgs(source: PaywallSource.pressureReview),
        suggestionStore: suggestionStore,
      );

      expect(suggestionStore.recorded, isEmpty);
    });
  });

  group('Suggestion Pro trigger rule', () {
    test('Pro users are never shown the suggestion-trigger paywall', () {
      expect(
        SuggestionProTrigger.shouldShow(
          isPro: true,
          entryCount: 10,
          alreadyShownThisSession: false,
        ),
        isFalse,
      );
    });

    test('requires at least three entries', () {
      expect(
        SuggestionProTrigger.shouldShow(
          isPro: false,
          entryCount: 2,
          alreadyShownThisSession: false,
        ),
        isFalse,
      );
      expect(
        SuggestionProTrigger.shouldShow(
          isPro: false,
          entryCount: 3,
          alreadyShownThisSession: false,
        ),
        isTrue,
      );
    });

    test('shows at most once per session', () {
      expect(
        SuggestionProTrigger.shouldShow(
          isPro: false,
          entryCount: 5,
          alreadyShownThisSession: true,
        ),
        isFalse,
      );
    });
  });
}