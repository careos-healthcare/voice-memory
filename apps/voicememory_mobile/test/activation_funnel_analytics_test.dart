import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/billing/paywall_attribution_event.dart';
import 'package:voicememory_mobile/billing/value_moment_paywall_trigger.dart';
import 'package:voicememory_mobile/features/first_session/first_save_rescue.dart';
import 'package:voicememory_mobile/features/first_session/two_day_activation_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/archive_proof_counter_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/belief_distance_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/done_for_today_receipt_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/one_small_recording_model.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/features/pressure_retention/thread_return_evidence_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/weekly_thread_review_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/screens/pressure_insights_screen.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/widgets/billing/value_moment_pro_bridge.dart';
import 'package:voicememory_mobile/widgets/first_session/first_save_rescue_card.dart';
import 'package:voicememory_mobile/widgets/first_session/first_session_explanation_card.dart';
import 'package:voicememory_mobile/widgets/first_session/two_day_activation_card.dart';
import 'package:voicememory_mobile/widgets/pressure_retention/archive_proof_counter_card.dart';
import 'package:voicememory_mobile/widgets/pressure_retention/belief_distance_card.dart';
import 'package:voicememory_mobile/widgets/pressure_retention/thread_return_evidence_card.dart';
import 'package:voicememory_mobile/widgets/pressure_retention/weekly_thread_review_card.dart';
import 'package:voicememory_mobile/widgets/record/done_for_today_receipt_card.dart';
import 'package:voicememory_mobile/widgets/record/one_small_recording_card.dart';

import 'support/memory_pressure_stores.dart';

final DateTime _base = DateTime(2026, 6, 9, 12);

/// Sensitive note text — must never leak into any analytics payload.
const String _sensitiveNote = 'I kept checking messages after I wanted to stop';

PressureCheckInRecord _record({
  required String id,
  int daysAgo = 0,
  String optionId = 'could_not_stop',
  List<String> contextIds = const [],
  String? fear,
}) {
  return PressureCheckInRecord(
    entryId: id,
    createdAt: _base.subtract(Duration(days: daysAgo)),
    optionId: optionId,
    contextIds: contextIds,
    fear: fear,
    transcript: 'pressure moment transcript text',
  );
}

List<PressureCheckInRecord> _workThread3() => [
      _record(id: 'a', daysAgo: 7, contextIds: const ['work']),
      _record(id: 'b', daysAgo: 3, contextIds: const ['work']),
      _record(
        id: 'c',
        daysAgo: 0,
        contextIds: const ['work'],
        fear: _sensitiveNote,
      ),
    ];

void main() {
  late List<({String event, Map<String, Object> properties})> captured;

  List<String> eventsNamed(String name) =>
      captured.where((e) => e.event == name).map((e) => e.event).toList();

  Map<String, Object>? firstPayload(String name) {
    for (final e in captured) {
      if (e.event == name) return e.properties;
    }
    return null;
  }

  setUp(() {
    captured = [];
    ActivationFunnelAnalytics.resetForTest();
    ActivationFunnelAnalytics.captureForTest(
      (event, properties) =>
          captured.add((event: event, properties: properties)),
    );
    ValueMomentPaywallTrigger.resetSessionForTest();
  });

  tearDown(ActivationFunnelAnalytics.resetForTest);

  Future<void> pumpCard(WidgetTester tester, Widget child) async {
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
    );
    await tester.pump();
  }

  group('Funnel tracker', () {
    test('only whitelisted property keys ever appear', () {
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.recordCtaTapped,
        entryCount: 2,
        hasConnectedThread: true,
        source: 'record',
        stage: 'day_1',
        cardType: 'pro_bridge',
      );
      final payload = firstPayload(ActivationFunnelAnalytics.recordCtaTapped)!;
      expect(
        payload.keys.toSet().difference(
              ActivationFunnelAnalytics.allowedPropertyKeys,
            ),
        isEmpty,
      );
      expect(payload['entry_count'], 2);
      expect(payload['has_connected_thread'], 1);
      expect(payload['source'], 'record');
      expect(payload['stage'], 'day_1');
      expect(payload['card_type'], 'pro_bridge');
    });

    test('free text never survives as a property value', () {
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.recordCtaTapped,
        source: _sensitiveNote,
        stage: 'Checking Messages Again',
        cardType: 'belief: $_sensitiveNote',
      );
      final payload = firstPayload(ActivationFunnelAnalytics.recordCtaTapped)!;
      expect(payload, isEmpty);
    });

    test('seen events de-dupe within a session', () {
      for (var i = 0; i < 3; i++) {
        ActivationFunnelAnalytics.track(
          ActivationFunnelAnalytics.doneForTodaySeen,
          oncePerSession: true,
        );
      }
      expect(eventsNamed(ActivationFunnelAnalytics.doneForTodaySeen), hasLength(1));
    });

    test('event names match the funnel spec and contain no VoiceMemory', () {
      const names = [
        ActivationFunnelAnalytics.firstSessionCardSeen,
        ActivationFunnelAnalytics.twoDayActivationSeen,
        ActivationFunnelAnalytics.oneSmallRecordingSeen,
        ActivationFunnelAnalytics.recordCtaTapped,
        ActivationFunnelAnalytics.firstRecordingSaved,
        ActivationFunnelAnalytics.firstSaveRescueSeen,
        ActivationFunnelAnalytics.firstSaveRescueTapped,
        ActivationFunnelAnalytics.firstSaveRescueSaved,
        ActivationFunnelAnalytics.firstRecordingSampleSeen,
        ActivationFunnelAnalytics.firstRecordingSampleTapped,
        ActivationFunnelAnalytics.firstRecordingSampleSaved,
        ActivationFunnelAnalytics.firstSaveConfidenceSeen,
        ActivationFunnelAnalytics.doneForTodaySeen,
        ActivationFunnelAnalytics.day1CompleteSeen,
        ActivationFunnelAnalytics.day1ReturnReasonSeen,
        ActivationFunnelAnalytics.day7ContinuitySeen,
        ActivationFunnelAnalytics.day7ContinuityWeeklyReviewTapped,
        ActivationFunnelAnalytics.day2ReturnSeen,
        ActivationFunnelAnalytics.day2ReminderPromptSeen,
        ActivationFunnelAnalytics.day2ReminderAccepted,
        ActivationFunnelAnalytics.day2ReminderDeclined,
        ActivationFunnelAnalytics.day2ReminderPermissionDenied,
        ActivationFunnelAnalytics.day2ReminderOpened,
        ActivationFunnelAnalytics.day2ReturnPreviewSeen,
        ActivationFunnelAnalytics.threadReturnEvidenceSeen,
        ActivationFunnelAnalytics.beliefDistanceSeen,
        ActivationFunnelAnalytics.weeklyThreadReviewSeen,
        ActivationFunnelAnalytics.archiveProofCounterSeen,
        ActivationFunnelAnalytics.valueMomentProBridgeSeen,
        ActivationFunnelAnalytics.valueMomentProBridgeTapped,
        ActivationFunnelAnalytics.purchaseReassuranceSeen,
        ActivationFunnelAnalytics.paywallAboveFoldClaritySeen,
        ActivationFunnelAnalytics.priceConfidenceSeen,
        ActivationFunnelAnalytics.paywallObjectionFollowUpSeen,
        ActivationFunnelAnalytics.planSelectionConfidenceSeen,
        ActivationFunnelAnalytics.paywallPlanSelected,
        ActivationFunnelAnalytics.purchaseIntentReturnCueSeen,
        ActivationFunnelAnalytics.purchaseIntentReturnCueTapped,
        ActivationFunnelAnalytics.purchaseIntentReturnCueDismissed,
        ActivationFunnelAnalytics.proRetentionCheckSeen,
        ActivationFunnelAnalytics.proRetentionCheckYes,
        ActivationFunnelAnalytics.proRetentionCheckNotYet,
        ActivationFunnelAnalytics.paywallSeen,
        ActivationFunnelAnalytics.purchaseStarted,
        ActivationFunnelAnalytics.purchaseCompleted,
      ];
      expect(names, [
        'first_session_card_seen',
        'two_day_activation_seen',
        'one_small_recording_seen',
        'record_cta_tapped',
        'first_recording_saved',
        'first_save_rescue_seen',
        'first_save_rescue_tapped',
        'first_save_rescue_saved',
        'first_recording_sample_seen',
        'first_recording_sample_tapped',
        'first_recording_sample_saved',
        'first_save_confidence_seen',
        'done_for_today_seen',
        'day_1_complete_seen',
        'day_1_return_reason_seen',
        'day_7_continuity_seen',
        'day_7_continuity_weekly_review_tapped',
        'day_2_return_seen',
        'day_2_reminder_prompt_seen',
        'day_2_reminder_accepted',
        'day_2_reminder_declined',
        'day_2_reminder_permission_denied',
        'day_2_reminder_opened',
        'day_2_return_preview_seen',
        'thread_return_evidence_seen',
        'belief_distance_seen',
        'weekly_thread_review_seen',
        'archive_proof_counter_seen',
        'value_moment_pro_bridge_seen',
        'value_moment_pro_bridge_tapped',
        'purchase_reassurance_seen',
        'paywall_above_fold_clarity_seen',
        'price_confidence_seen',
        'paywall_objection_follow_up_seen',
        'plan_selection_confidence_seen',
        'paywall_plan_selected',
        'purchase_intent_return_cue_seen',
        'purchase_intent_return_cue_tapped',
        'purchase_intent_return_cue_dismissed',
        'pro_retention_check_seen',
        'pro_retention_check_yes',
        'pro_retention_check_not_yet',
        'paywall_seen',
        'purchase_started',
        'purchase_completed',
      ]);
      for (final name in names) {
        expect(name.toLowerCase(), isNot(contains('voicememory')));
      }
    });

    test('paywall and purchase funnel ids still match the attribution flow',
        () {
      expect(PaywallAttributionEventType.paywallSeen.id, 'paywall_seen');
      expect(
        PaywallAttributionEventType.purchaseStarted.id,
        'purchase_started',
      );
      expect(
        PaywallAttributionEventType.purchaseCompleted.id,
        'purchase_completed',
      );
    });
  });

  group('Cards fire seen events', () {
    testWidgets('first-session card', (tester) async {
      await pumpCard(
        tester,
        FirstSessionExplanationCard(onLogPressure: () {}, onRecord: () {}),
      );
      expect(
        eventsNamed(ActivationFunnelAnalytics.firstSessionCardSeen),
        hasLength(1),
      );
      expect(
        firstPayload(ActivationFunnelAnalytics.firstSessionCardSeen),
        {'entry_count': 0},
      );
    });

    testWidgets('day 1 plan fires stage day_1 and no day-2 event',
        (tester) async {
      const engine = TwoDayActivationEngine();
      await pumpCard(
        tester,
        TwoDayActivationCard(
          path: engine.build(entryCount: 0, now: DateTime(2026, 6, 11)),
        ),
      );
      expect(
        firstPayload(ActivationFunnelAnalytics.twoDayActivationSeen),
        {'stage': 'day_1'},
      );
      expect(eventsNamed(ActivationFunnelAnalytics.day2ReturnSeen), isEmpty);
      expect(eventsNamed(ActivationFunnelAnalytics.day1CompleteSeen), isEmpty);
    });

    testWidgets('day 2 return fires only for the return state', (tester) async {
      const engine = TwoDayActivationEngine();
      await pumpCard(
        tester,
        TwoDayActivationCard(
          path: engine.build(
            entryCount: 1,
            entryDates: [DateTime(2026, 6, 10, 18)],
            now: DateTime(2026, 6, 11, 9),
          ),
        ),
      );
      expect(
        eventsNamed(ActivationFunnelAnalytics.day2ReturnSeen),
        hasLength(1),
      );
      expect(
        firstPayload(ActivationFunnelAnalytics.twoDayActivationSeen),
        {'stage': 'day_2_return'},
      );
    });

    testWidgets('day 1 complete fires after the first save card renders',
        (tester) async {
      const engine = TwoDayActivationEngine();
      await pumpCard(
        tester,
        TwoDayActivationCard(path: engine.buildPostSave(entryCount: 1)),
      );
      expect(
        eventsNamed(ActivationFunnelAnalytics.day1CompleteSeen),
        hasLength(1),
      );
      // The concrete return reason renders with day-1 closure.
      expect(
        eventsNamed(ActivationFunnelAnalytics.day1ReturnReasonSeen),
        hasLength(1),
      );
    });

    testWidgets('first save rescue card fires seen once, tap fires tapped',
        (tester) async {
      addTearDown(FirstSaveRescue.resetForTest);
      await pumpCard(tester, FirstSaveRescueCard(onStart: () {}));
      expect(
        eventsNamed(ActivationFunnelAnalytics.firstSaveRescueSeen),
        hasLength(1),
      );
      expect(
        firstPayload(ActivationFunnelAnalytics.firstSaveRescueSeen),
        {'entry_count': 0},
      );

      await tester.tap(find.byKey(const Key('first_save_rescue_cta')));
      expect(
        eventsNamed(ActivationFunnelAnalytics.firstSaveRescueTapped),
        hasLength(1),
      );
      expect(
        firstPayload(ActivationFunnelAnalytics.firstSaveRescueTapped),
        {'entry_count': 0},
      );
    });

    testWidgets('one small recording card', (tester) async {
      await pumpCard(
        tester,
        OneSmallRecordingCard(
          recording: const OneSmallRecording(
            hasRecording: true,
            prompt: 'Record what happened with work today.',
          ),
          onRecordThis: (_) {},
        ),
      );
      expect(
        eventsNamed(ActivationFunnelAnalytics.oneSmallRecordingSeen),
        hasLength(1),
      );
    });

    testWidgets('done for today receipt', (tester) async {
      final receipt = const DoneForTodayReceiptEngine()
          .build(saved: true, records: _workThread3(), now: _base);
      await pumpCard(tester, DoneForTodayReceiptCard(receipt: receipt));
      expect(
        eventsNamed(ActivationFunnelAnalytics.doneForTodaySeen),
        hasLength(1),
      );
      expect(
        firstPayload(ActivationFunnelAnalytics.doneForTodaySeen),
        {'has_connected_thread': 1},
      );
    });

    testWidgets('value cards fire their seen events', (tester) async {
      final records = _workThread3();
      final evidence = const ThreadReturnEvidenceEngine()
          .build(records, now: _base);
      final counter =
          const ArchiveProofCounterEngine().build(records, now: _base);
      final review =
          const WeeklyThreadReviewEngine().build(records, now: _base);
      final belief = const BeliefDistanceEngine().build([
        _record(id: 'b0', daysAgo: 4, fear: 'I have to keep checking messages'),
        _record(id: 'b1', daysAgo: 0, fear: 'Checking messages again tonight'),
      ]);
      await pumpCard(
        tester,
        Column(
          children: [
            ThreadReturnEvidenceCard(evidence: evidence),
            ArchiveProofCounterCard(counter: counter),
            WeeklyThreadReviewCard(review: review),
            BeliefDistanceCard(belief: belief),
          ],
        ),
      );

      expect(
        firstPayload(ActivationFunnelAnalytics.threadReturnEvidenceSeen),
        {'entry_count': 3, 'has_connected_thread': 1},
      );
      expect(
        firstPayload(ActivationFunnelAnalytics.archiveProofCounterSeen),
        {'has_connected_thread': 1},
      );
      expect(
        eventsNamed(ActivationFunnelAnalytics.weeklyThreadReviewSeen),
        hasLength(1),
      );
      expect(
        eventsNamed(ActivationFunnelAnalytics.beliefDistanceSeen),
        hasLength(1),
      );
    });

    testWidgets('value moment bridge fires seen and tapped', (tester) async {
      final bridge = const ValueMomentPaywallTrigger()
          .build(_workThread3(), isPro: false, now: _base);
      await pumpCard(
        tester,
        ValueMomentProBridge(
          bridge: bridge,
          onSeePro: () {},
          onDismiss: () {},
        ),
      );
      expect(
        eventsNamed(ActivationFunnelAnalytics.valueMomentProBridgeSeen),
        hasLength(1),
      );

      await tester.tap(find.byKey(const Key('value_moment_cta')));
      expect(
        eventsNamed(ActivationFunnelAnalytics.valueMomentProBridgeTapped),
        hasLength(1),
      );
    });
  });

  group('Save funnel', () {
    test('first_recording_saved fires only for the very first save', () async {
      final dir = Directory.systemTemp.createTempSync('vm_funnel_save_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final store = await JournalStore.open('${dir.path}/journal.json');

      JournalEntry entry(String id) => JournalEntry(
            id: id,
            createdAt: DateTime(2026, 6, 11, 9),
            transcript: 'A saved reflection with private words in it.',
            durationSeconds: 30,
            reflection: const Reflection(
              mood: 'thoughtful',
              emotionalIntensity: 2,
              recurringThemes: ['work'],
              exactLanguagePattern: 'pattern',
              concreteObservation: 'observation',
              repeatedSignal: 'signal',
            ),
          );

      await store.save(entry('e1'));
      expect(
        eventsNamed(ActivationFunnelAnalytics.firstRecordingSaved),
        hasLength(1),
      );
      expect(
        firstPayload(ActivationFunnelAnalytics.firstRecordingSaved),
        {'entry_count': 1},
      );

      await store.save(entry('e2'));
      expect(
        eventsNamed(ActivationFunnelAnalytics.firstRecordingSaved),
        hasLength(1),
        reason: 'second save is not the first recording',
      );
    });

    test('first_save_rescue_saved fires only for a rescue-started first save',
        () async {
      addTearDown(FirstSaveRescue.resetForTest);

      JournalEntry entry(String id) => JournalEntry(
            id: id,
            createdAt: DateTime(2026, 6, 11, 9),
            transcript: 'What has been repeating lately is private text.',
            durationSeconds: 10,
            reflection: const Reflection(
              mood: 'thoughtful',
              emotionalIntensity: 2,
              recurringThemes: ['work'],
              exactLanguagePattern: 'pattern',
              concreteObservation: 'observation',
              repeatedSignal: 'signal',
            ),
          );

      // First save without a rescue tap: no rescue event.
      final plainDir = Directory.systemTemp.createTempSync('vm_rescue_plain_');
      addTearDown(() => plainDir.deleteSync(recursive: true));
      final plainStore = await JournalStore.open('${plainDir.path}/j.json');
      FirstSaveRescue.startedFromRescueThisSession = false;
      await plainStore.save(entry('e1'));
      expect(
        eventsNamed(ActivationFunnelAnalytics.firstSaveRescueSaved),
        isEmpty,
      );

      // Rescue-started recording: the first save logs the rescue event.
      final dir = Directory.systemTemp.createTempSync('vm_rescue_save_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final store = await JournalStore.open('${dir.path}/j.json');
      FirstSaveRescue.startedFromRescueThisSession = true;
      await store.save(entry('e1'));

      final payload =
          firstPayload(ActivationFunnelAnalytics.firstSaveRescueSaved);
      expect(payload, {'entry_count': 1});
      expect(
        eventsNamed(ActivationFunnelAnalytics.firstSaveRescueSaved),
        hasLength(1),
      );
      // The flag is consumed — later saves never re-attribute.
      expect(FirstSaveRescue.startedFromRescueThisSession, isFalse);
      await store.save(entry('e2'));
      expect(
        eventsNamed(ActivationFunnelAnalytics.firstSaveRescueSaved),
        hasLength(1),
      );

      // Counts only — never recording content.
      for (final e in captured) {
        final flat = '${e.event} ${e.properties.values.join(' ')}'.toLowerCase();
        expect(flat, isNot(contains('repeating lately')));
        expect(flat, isNot(contains('private text')));
      }
    });
  });

  group('Privacy safeguards', () {
    testWidgets('no private text in any payload from the insights screen',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 6500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: PressureInsightsScreen(
            entitlementReader: FakeArchiveEntitlementReader(pro: false),
            microExperimentStore: MemoryExperimentStore(),
            returnTriggerStore: MemoryReturnTriggerStore(),
            records: _workThread3(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(captured, isNotEmpty);
      for (final e in captured) {
        expect(
          e.properties.keys.toSet().difference(
                ActivationFunnelAnalytics.allowedPropertyKeys,
              ),
          isEmpty,
          reason: '${e.event} carries a non-whitelisted key',
        );
        final flat = '${e.event} ${e.properties.values.join(' ')}'.toLowerCase();
        for (final word in const [
          'checking',
          'messages',
          'transcript text',
          'voicememory',
        ]) {
          expect(flat, isNot(contains(word)),
              reason: '${e.event} payload must not contain "$word"');
        }
      }
      // The value surfaces all reported through the funnel.
      expect(
        eventsNamed(ActivationFunnelAnalytics.threadReturnEvidenceSeen),
        hasLength(1),
      );
      expect(
        eventsNamed(ActivationFunnelAnalytics.archiveProofCounterSeen),
        hasLength(1),
      );
      expect(
        eventsNamed(ActivationFunnelAnalytics.valueMomentProBridgeSeen),
        hasLength(1),
      );
    });
  });
}
