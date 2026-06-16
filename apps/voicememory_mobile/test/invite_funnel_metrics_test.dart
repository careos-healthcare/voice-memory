import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/first_session/two_day_activation_engine.dart';
import 'package:voicememory_mobile/features/referral/invite_attribution.dart';
import 'package:voicememory_mobile/features/referral/invite_funnel_metrics.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/widgets/first_session/two_day_activation_card.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs() : super(file: File('test/tmp/invite_funnel/unused.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

InviteAttributionStore _storeWith({String? source, String? ref}) {
  final prefs = _MemoryPrefs();
  if (source != null) {
    prefs.maps[InviteAttributionStore.prefsKey] = {
      'ref': ref ?? 'archive_invite',
      'source': source,
    };
  }
  return InviteAttributionStore(prefs: prefs);
}

void main() {
  late List<({String event, Map<String, Object> properties})> captured;

  List<({String event, Map<String, Object> properties})> eventsNamed(
    String name,
  ) => captured.where((e) => e.event == name).toList();

  void fireAllHooks() {
    InviteFunnelMetrics.appOpened();
    InviteFunnelMetrics.recordCtaTapped(entryCount: 0);
    InviteFunnelMetrics.firstSave();
    InviteFunnelMetrics.dayTwoReturnSeen();
    InviteFunnelMetrics.valueMomentSeen('weekly_review');
    InviteFunnelMetrics.proBridgeTapped('thread_return_evidence');
    InviteFunnelMetrics.paywallSeen();
    InviteFunnelMetrics.purchaseStarted();
    InviteFunnelMetrics.purchaseCompleted();
  }

  setUp(() {
    captured = [];
    ActivationFunnelAnalytics.resetForTest();
    ActivationFunnelAnalytics.captureForTest(
      (event, properties) =>
          captured.add((event: event, properties: properties)),
    );
    InviteFunnelMetrics.resetForTest();
  });

  tearDown(() {
    ActivationFunnelAnalytics.resetForTest();
    InviteFunnelMetrics.resetForTest();
  });

  group('Attribution gate', () {
    test('invited events never fire without attribution', () async {
      InviteFunnelMetrics.overrideStoreForTest(_storeWith());
      fireAllHooks();
      await pumpEventQueue();
      expect(captured, isEmpty);
    });

    test(
      'invited app opened fires with attribution, once per session',
      () async {
        InviteFunnelMetrics.overrideStoreForTest(
          _storeWith(source: 'weekly_review'),
        );
        InviteFunnelMetrics.appOpened();
        InviteFunnelMetrics.appOpened();
        await pumpEventQueue();

        final events = eventsNamed(ActivationFunnelAnalytics.invitedAppOpened);
        expect(events, hasLength(1));
        expect(events.single.properties, {'source': 'weekly_review'});
      },
    );

    test('invited record CTA fires with attribution and entry count', () async {
      InviteFunnelMetrics.overrideStoreForTest(
        _storeWith(source: 'thread_return'),
      );
      InviteFunnelMetrics.recordCtaTapped(entryCount: 0);
      await pumpEventQueue();

      final events = eventsNamed(
        ActivationFunnelAnalytics.invitedRecordCtaTapped,
      );
      expect(events, hasLength(1));
      expect(events.single.properties, {
        'source': 'thread_return',
        'entry_count': 0,
      });
    });

    test('invited first save fires only once', () async {
      InviteFunnelMetrics.overrideStoreForTest(
        _storeWith(source: 'proof_counter'),
      );
      InviteFunnelMetrics.firstSave();
      InviteFunnelMetrics.firstSave();
      await pumpEventQueue();

      final events = eventsNamed(ActivationFunnelAnalytics.invitedFirstSave);
      expect(events, hasLength(1));
      expect(events.single.properties, {
        'source': 'proof_counter',
        'entry_count': 1,
      });
    });

    test('corrupt or unknown invite source falls back to default', () async {
      InviteFunnelMetrics.overrideStoreForTest(
        _storeWith(source: 'Garbage Source!!'),
      );
      InviteFunnelMetrics.appOpened();
      await pumpEventQueue();

      final events = eventsNamed(ActivationFunnelAnalytics.invitedAppOpened);
      expect(events, hasLength(1));
      expect(events.single.properties, {'source': 'default'});
    });

    test('a wrong ref means no attribution and no events', () async {
      InviteFunnelMetrics.overrideStoreForTest(
        _storeWith(source: 'weekly_review', ref: 'other_channel'),
      );
      fireAllHooks();
      await pumpEventQueue();
      expect(captured, isEmpty);
    });
  });

  group('Value moments and bridge', () {
    setUp(() async {
      InviteFunnelMetrics.overrideStoreForTest(
        _storeWith(source: 'belief_distance'),
      );
      await InviteFunnelMetrics.currentSource();
    });

    test('value moment fires with a safe card_type, once per card type', () {
      InviteFunnelMetrics.valueMomentSeen('weekly_review');
      InviteFunnelMetrics.valueMomentSeen('weekly_review');
      InviteFunnelMetrics.valueMomentSeen('thread_return');

      final events = eventsNamed(
        ActivationFunnelAnalytics.invitedValueMomentSeen,
      );
      expect(events, hasLength(2));
      expect(events[0].properties, {
        'source': 'belief_distance',
        'card_type': 'weekly_review',
      });
      expect(events[1].properties, {
        'source': 'belief_distance',
        'card_type': 'thread_return',
      });
    });

    test('feedback-style card ids normalize to stable card types', () {
      InviteFunnelMetrics.valueMomentSeen('thread_return_evidence');
      InviteFunnelMetrics.valueMomentSeen('archive_proof_counter');
      InviteFunnelMetrics.valueMomentSeen('weekly_thread_review');
      InviteFunnelMetrics.valueMomentSeen('belief_distance');

      final cardTypes = eventsNamed(
        ActivationFunnelAnalytics.invitedValueMomentSeen,
      ).map((e) => e.properties['card_type']).toList();
      expect(cardTypes, [
        'thread_return',
        'proof_counter',
        'weekly_review',
        'belief_distance',
      ]);
    });

    test('unknown card types are dropped entirely', () {
      InviteFunnelMetrics.valueMomentSeen('something_else');
      expect(
        eventsNamed(ActivationFunnelAnalytics.invitedValueMomentSeen),
        isEmpty,
      );
    });

    test('pro bridge tap carries the normalized card type', () {
      InviteFunnelMetrics.proBridgeTapped('weekly_thread_review');
      final events = eventsNamed(
        ActivationFunnelAnalytics.invitedProBridgeTapped,
      );
      expect(events, hasLength(1));
      expect(events.single.properties, {
        'source': 'belief_distance',
        'card_type': 'weekly_review',
      });
    });
  });

  group('Paywall and purchase mirror', () {
    test('paywall and purchase events carry the invite source only', () async {
      InviteFunnelMetrics.overrideStoreForTest(
        _storeWith(source: 'pro_retention_yes'),
      );
      InviteFunnelMetrics.paywallSeen();
      InviteFunnelMetrics.purchaseStarted();
      InviteFunnelMetrics.purchaseCompleted();
      await pumpEventQueue();

      for (final name in [
        ActivationFunnelAnalytics.invitedPaywallSeen,
        ActivationFunnelAnalytics.invitedPurchaseStarted,
        ActivationFunnelAnalytics.invitedPurchaseCompleted,
      ]) {
        final events = eventsNamed(name);
        expect(events, hasLength(1), reason: name);
        expect(events.single.properties, {'source': 'pro_retention_yes'});
      }
    });
  });

  group('Day 2 return', () {
    const engine = TwoDayActivationEngine();
    final now = DateTime(2026, 6, 11, 9);
    final yesterday = DateTime(2026, 6, 10, 18);

    Future<void> pumpCard(WidgetTester tester, TwoDayActivationPath path) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TwoDayActivationCard(path: path),
            ),
          ),
        ),
      );
    }

    testWidgets('fires only in the Day 2 return state', (tester) async {
      InviteFunnelMetrics.overrideStoreForTest(
        _storeWith(source: 'weekly_review'),
      );
      await InviteFunnelMetrics.currentSource();

      // Day 1 intro: no invited day-2 event.
      await pumpCard(tester, engine.build(entryCount: 0, now: now));
      expect(
        eventsNamed(ActivationFunnelAnalytics.invitedDay2ReturnSeen),
        isEmpty,
      );

      // The Day 2 return state fires it — alongside the normal event.
      await pumpCard(
        tester,
        engine.build(entryCount: 1, entryDates: [yesterday], now: now),
      );
      final invited = eventsNamed(
        ActivationFunnelAnalytics.invitedDay2ReturnSeen,
      );
      expect(invited, hasLength(1));
      expect(invited.single.properties, {
        'source': 'weekly_review',
        'stage': 'day_2',
      });
      // Normal funnel events still fire — invited is additive.
      expect(
        eventsNamed(ActivationFunnelAnalytics.day2ReturnSeen),
        hasLength(1),
      );
    });

    testWidgets('no invited day-2 event without attribution', (tester) async {
      InviteFunnelMetrics.overrideStoreForTest(_storeWith());
      await InviteFunnelMetrics.currentSource();
      await pumpCard(
        tester,
        engine.build(entryCount: 1, entryDates: [yesterday], now: now),
      );
      expect(
        eventsNamed(ActivationFunnelAnalytics.invitedDay2ReturnSeen),
        isEmpty,
      );
      // The normal funnel event is untouched.
      expect(
        eventsNamed(ActivationFunnelAnalytics.day2ReturnSeen),
        hasLength(1),
      );
    });
  });

  group('Privacy safeguards', () {
    test('payload keys are whitelisted and carry no private content', () async {
      InviteFunnelMetrics.overrideStoreForTest(
        _storeWith(source: 'weekly_review'),
      );
      fireAllHooks();
      await pumpEventQueue();

      expect(captured, isNotEmpty);
      for (final e in captured) {
        expect(e.event, startsWith('invited_'));
        expect(
          e.properties.keys.toSet().difference(const {
            'source',
            'entry_count',
            'stage',
            'card_type',
          }),
          isEmpty,
          reason: '${e.event} carries a non-whitelisted key',
        );
        final flat = '${e.event} ${e.properties.values.join(' ')}'
            .toLowerCase();
        // No invite URL, referrer identity, email shape, or branding.
        expect(flat, isNot(contains('https://')));
        expect(flat, isNot(contains('archiveme.app')));
        expect(flat, isNot(contains('@')));
        expect(flat, isNot(contains('voicememory')));
        // No archive content fragments.
        for (final fragment in const ['deadline', 'emails', 'work']) {
          expect(flat, isNot(contains(fragment)));
        }
      }
    });

    test('event names match the spec exactly', () {
      expect(InviteFunnelMetrics.invitedAppOpened, 'invited_app_opened');
      expect(
        InviteFunnelMetrics.invitedRecordCtaTapped,
        'invited_record_cta_tapped',
      );
      expect(InviteFunnelMetrics.invitedFirstSave, 'invited_first_save');
      expect(
        InviteFunnelMetrics.invitedDay2ReturnSeen,
        'invited_day_2_return_seen',
      );
      expect(
        InviteFunnelMetrics.invitedValueMomentSeen,
        'invited_value_moment_seen',
      );
      expect(
        InviteFunnelMetrics.invitedProBridgeTapped,
        'invited_pro_bridge_tapped',
      );
      expect(InviteFunnelMetrics.invitedPaywallSeen, 'invited_paywall_seen');
      expect(
        InviteFunnelMetrics.invitedPurchaseStarted,
        'invited_purchase_started',
      );
      expect(
        InviteFunnelMetrics.invitedPurchaseCompleted,
        'invited_purchase_completed',
      );
    });
  });
}
