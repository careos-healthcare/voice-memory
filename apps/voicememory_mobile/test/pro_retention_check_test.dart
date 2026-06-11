import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/billing/pro_retention_check.dart';
import 'package:voicememory_mobile/billing/revenuecat_service.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/screens/pressure_insights_screen.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/widgets/billing/pro_retention_check_card.dart';

PressureCheckInRecord _checkIn({
  required String id,
  required int daysAgo,
  String? fear,
}) {
  return PressureCheckInRecord(
    entryId: id,
    createdAt: DateTime.now().subtract(Duration(days: daysAgo)),
    optionId: 'could_not_stop',
    contextIds: const ['work'],
    fear: fear,
    transcript: 'pressure moment',
  );
}

/// A connected work thread — produces the weekly review, thread evidence,
/// and a connected proof counter (every Pro-value surface).
List<PressureCheckInRecord> _proValueRecords() => [
      _checkIn(id: 'a', daysAgo: 6),
      _checkIn(id: 'b', daysAgo: 3, fear: 'The deadline slipping'),
      _checkIn(id: 'c', daysAgo: 0, fear: 'Late emails piling up'),
    ];

/// Unrelated, stale entries — no thread, no review, no Pro-value surface.
List<PressureCheckInRecord> _noValueRecords() => [
      PressureCheckInRecord(
        entryId: 'u0',
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
        optionId: 'could_not_stop',
        contextIds: const [],
        fear: null,
        transcript: 'pressure moment',
      ),
    ];

void main() {
  late List<({String event, Map<String, Object> properties})> captured;

  List<({String event, Map<String, Object> properties})> eventsNamed(
    String name,
  ) =>
      captured.where((e) => e.event == name).toList();

  setUp(() {
    captured = [];
    ActivationFunnelAnalytics.resetForTest();
    ActivationFunnelAnalytics.captureForTest(
      (event, properties) =>
          captured.add((event: event, properties: properties)),
    );
    ProRetentionCheck.resetSessionForTest();
  });

  tearDown(() {
    ActivationFunnelAnalytics.resetForTest();
    ProRetentionCheck.resetSessionForTest();
  });

  group('Copy guardrails', () {
    test('copy is exact', () {
      expect(ProRetentionCheck.title, 'Is Pro helping?');
      expect(
        ProRetentionCheck.question,
        'Is the connected archive still useful?',
      );
      expect(ProRetentionCheck.yesLabel, 'Yes');
      expect(ProRetentionCheck.notYetLabel, 'Not yet');
      expect(
        ProRetentionCheck.yesAck,
        'Thanks \u2014 we\u2019ll keep the archive focused on what changes '
        'over time.',
      );
      expect(
        ProRetentionCheck.notYetAck,
        'Thanks \u2014 we\u2019ll keep this clearer and lighter.',
      );
    });

    test('no guilt, dark-pattern, or VoiceMemory language', () {
      final copy = [
        ProRetentionCheck.title,
        ProRetentionCheck.question,
        ProRetentionCheck.yesLabel,
        ProRetentionCheck.notYetLabel,
        ProRetentionCheck.yesAck,
        ProRetentionCheck.notYetAck,
      ].join(' ').toLowerCase();
      for (final banned in const [
        'voicememory',
        'cancel',
        'don\u2019t leave',
        'dont leave',
        'before you go',
        'lose',
        'losing',
        'miss out',
        'wasted',
        'guilt',
        'failed',
        'last chance',
        'are you sure',
        'discount',
        'offer',
      ]) {
        expect(copy, isNot(contains(banned)),
            reason: 'retention check copy must not contain "$banned"');
      }
    });
  });

  group('Gate', () {
    test('free users never see the check', () {
      expect(
        ProRetentionCheck.shouldShow(isPro: false, cardType: 'weekly_review'),
        isFalse,
      );
    });

    test('Pro users need a real Pro-value surface', () {
      expect(
        ProRetentionCheck.shouldShow(isPro: true, cardType: null),
        isFalse,
      );
      expect(
        ProRetentionCheck.shouldShow(isPro: true, cardType: 'weekly_review'),
        isTrue,
      );
    });

    test('at most once per session', () {
      ProRetentionCheck.shownThisSession = true;
      expect(
        ProRetentionCheck.shouldShow(isPro: true, cardType: 'weekly_review'),
        isFalse,
      );
    });

    test('card type prefers the strongest surface, stable ids only', () {
      expect(
        ProRetentionCheck.valueSurfaceCardType(
          hasWeeklyReview: true,
          hasBeliefDistance: true,
          hasThreadReturnEvidence: true,
          hasConnectedProofCounter: true,
        ),
        'weekly_review',
      );
      expect(
        ProRetentionCheck.valueSurfaceCardType(
          hasWeeklyReview: false,
          hasBeliefDistance: true,
          hasThreadReturnEvidence: true,
          hasConnectedProofCounter: true,
        ),
        'belief_distance',
      );
      expect(
        ProRetentionCheck.valueSurfaceCardType(
          hasWeeklyReview: false,
          hasBeliefDistance: false,
          hasThreadReturnEvidence: true,
          hasConnectedProofCounter: true,
        ),
        'thread_return',
      );
      expect(
        ProRetentionCheck.valueSurfaceCardType(
          hasWeeklyReview: false,
          hasBeliefDistance: false,
          hasThreadReturnEvidence: false,
          hasConnectedProofCounter: true,
        ),
        'proof_counter',
      );
      expect(
        ProRetentionCheck.valueSurfaceCardType(
          hasWeeklyReview: false,
          hasBeliefDistance: false,
          hasThreadReturnEvidence: false,
          hasConnectedProofCounter: false,
        ),
        isNull,
      );
    });
  });

  group('Check card widget', () {
    Future<void> pumpCard(WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProRetentionCheckCard(
              cardType: 'weekly_review',
              entryCount: 3,
              hasConnectedThread: true,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders the question with two equal options, no text input',
        (tester) async {
      await pumpCard(tester);
      expect(find.text(ProRetentionCheck.title), findsOneWidget);
      expect(find.text(ProRetentionCheck.question), findsOneWidget);
      expect(find.text(ProRetentionCheck.yesLabel), findsOneWidget);
      expect(find.text(ProRetentionCheck.notYetLabel), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      // Seen fired once with safe properties, and the session is marked.
      expect(ProRetentionCheck.shownThisSession, isTrue);
      final seen =
          eventsNamed(ActivationFunnelAnalytics.proRetentionCheckSeen);
      expect(seen, hasLength(1));
      expect(seen.single.properties, {
        'entry_count': 3,
        'has_connected_thread': 1,
        'card_type': 'weekly_review',
      });
    });

    testWidgets('Yes logs the event and shows the calm acknowledgement',
        (tester) async {
      await pumpCard(tester);
      await tester.tap(find.byKey(const Key('pro_retention_check_yes')));
      await tester.pump();

      final yes = eventsNamed(ActivationFunnelAnalytics.proRetentionCheckYes);
      expect(yes, hasLength(1));
      expect(yes.single.properties, {
        'entry_count': 3,
        'has_connected_thread': 1,
        'card_type': 'weekly_review',
      });
      expect(find.text(ProRetentionCheck.yesAck), findsOneWidget);
      // The question is answered — options retire, nothing else appears.
      expect(find.text(ProRetentionCheck.question), findsNothing);
      expect(
        eventsNamed(ActivationFunnelAnalytics.proRetentionCheckNotYet),
        isEmpty,
      );
    });

    testWidgets('Not yet logs the event and shows the calm acknowledgement',
        (tester) async {
      await pumpCard(tester);
      await tester.tap(find.byKey(const Key('pro_retention_check_not_yet')));
      await tester.pump();

      final notYet =
          eventsNamed(ActivationFunnelAnalytics.proRetentionCheckNotYet);
      expect(notYet, hasLength(1));
      expect(notYet.single.properties, {
        'entry_count': 3,
        'has_connected_thread': 1,
        'card_type': 'weekly_review',
      });
      expect(find.text(ProRetentionCheck.notYetAck), findsOneWidget);
      expect(
        eventsNamed(ActivationFunnelAnalytics.proRetentionCheckYes),
        isEmpty,
      );
    });

    testWidgets('no private content in any retention payload',
        (tester) async {
      await pumpCard(tester);
      await tester.tap(find.byKey(const Key('pro_retention_check_yes')));
      await tester.pump();

      expect(captured, isNotEmpty);
      for (final e in captured) {
        expect(
          e.properties.keys.toSet().difference(
                ActivationFunnelAnalytics.allowedPropertyKeys,
              ),
          isEmpty,
        );
        final flat =
            '${e.event} ${e.properties.values.join(' ')}'.toLowerCase();
        expect(flat, isNot(contains('deadline')));
        expect(flat, isNot(contains('voicememory')));
      }
    });
  });

  group('Insights screen integration', () {
    Future<void> pumpInsights(
      WidgetTester tester, {
      required bool pro,
      required List<PressureCheckInRecord> records,
    }) async {
      await tester.binding.setSurfaceSize(const Size(390, 6000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: PressureInsightsScreen(
            entitlementReader: FakeArchiveEntitlementReader(pro: pro),
            records: records,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('appears for Pro users once a Pro-value surface exists',
        (tester) async {
      await pumpInsights(tester, pro: true, records: _proValueRecords());
      expect(
        find.byKey(const Key('pro_retention_check_card')),
        findsOneWidget,
      );
      // The Pro-value surfaces themselves stay visible.
      expect(
        find.byKey(const Key('weekly_thread_review_card')),
        findsOneWidget,
      );
      final seen =
          eventsNamed(ActivationFunnelAnalytics.proRetentionCheckSeen);
      expect(seen, hasLength(1));
      expect(seen.single.properties['card_type'], 'weekly_review');
    });

    testWidgets('never appears for free users, even with the same evidence',
        (tester) async {
      await pumpInsights(tester, pro: false, records: _proValueRecords());
      expect(
        find.byKey(const Key('pro_retention_check_card')),
        findsNothing,
      );
      expect(
        eventsNamed(ActivationFunnelAnalytics.proRetentionCheckSeen),
        isEmpty,
      );
    });

    testWidgets('never appears for Pro users without a Pro-value surface',
        (tester) async {
      await pumpInsights(tester, pro: true, records: _noValueRecords());
      expect(
        find.byKey(const Key('pro_retention_check_card')),
        findsNothing,
      );
    });

    testWidgets('only one appearance per session', (tester) async {
      await pumpInsights(tester, pro: true, records: _proValueRecords());
      expect(
        find.byKey(const Key('pro_retention_check_card')),
        findsOneWidget,
      );

      // A fresh screen in the same session shows nothing.
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpInsights(tester, pro: true, records: _proValueRecords());
      expect(
        find.byKey(const Key('pro_retention_check_card')),
        findsNothing,
      );
    });

    testWidgets('answering keeps the card calm — ack only, no follow-up',
        (tester) async {
      await pumpInsights(tester, pro: true, records: _proValueRecords());
      final yes = find.byKey(const Key('pro_retention_check_yes'));
      await tester.ensureVisible(yes);
      await tester.pump();
      await tester.tap(yes);
      await tester.pump();
      expect(find.text(ProRetentionCheck.yesAck), findsOneWidget);
      expect(
        eventsNamed(ActivationFunnelAnalytics.proRetentionCheckYes),
        hasLength(1),
      );
    });
  });

  group('Subscription safety unchanged', () {
    test('RevenueCat identifiers are untouched', () {
      expect(RevenueCatService.proEntitlementId, 'pro');
    });

    test('manage/cancel information stays where it already is', () {
      final paywallSource =
          File('lib/billing/paywall_source.dart').readAsStringSync();
      expect(
        paywallSource.contains(
          'You can manage or cancel this anytime through the App Store.',
        ),
        isTrue,
      );
      expect(
        paywallSource.contains('Manage or cancel anytime in the App Store.'),
        isTrue,
      );
      // The retention check never references cancellation at all.
      final check =
          File('lib/billing/pro_retention_check.dart').readAsStringSync();
      final card = File('lib/widgets/billing/pro_retention_check_card.dart')
          .readAsStringSync();
      for (final source in [check, card]) {
        expect(source.toLowerCase(), isNot(contains('purchasenative')));
        expect(source.toLowerCase(), isNot(contains('revenuecat')));
      }
    });
  });
}
