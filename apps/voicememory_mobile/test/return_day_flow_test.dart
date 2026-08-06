import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence_quality.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence_quality_gate.dart';
import 'package:voicememory_mobile/features/early_archive/first_proof_moment_engine.dart';
import 'package:voicememory_mobile/features/record_capture_modes/record_capture_mode_engine.dart';
import 'package:voicememory_mobile/features/retention/first_week_progress_engine.dart';
import 'package:voicememory_mobile/features/retention/return_tomorrow_cue_engine.dart';
import 'package:voicememory_mobile/features/come_back_tomorrow/come_back_tomorrow_v2_analytics.dart';
import 'package:voicememory_mobile/features/come_back_tomorrow/come_back_tomorrow_v2_copy.dart';
import 'package:voicememory_mobile/features/return_day/return_day_flow_copy.dart';
import 'package:voicememory_mobile/features/return_day/return_day_flow_engine.dart';
import 'package:voicememory_mobile/features/return_day/return_day_flow_model.dart';
import 'package:voicememory_mobile/features/return_day/return_day_flow_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/widgets/record/return_day_flow_card.dart';

const _placeholder =
    '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected';
const _genericTest = 'This is a test to check function';
const _strongRepeat =
    'I had no capacity but I said yes again to the extra meeting today.';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs() : super(file: File('test/tmp/return_day_flow/unused.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

JournalEntry _entry(String id, String transcript, {DateTime? createdAt}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt ?? DateTime(2026, 6, 12, 10),
      transcript: transcript,
      durationSeconds: 24,
      reflection: const Reflection(
        mood: 'thoughtful',
        emotionalIntensity: 2,
        recurringThemes: ['work'],
        exactLanguagePattern: '',
        concreteObservation: 'Work pressure showed up again today.',
        repeatedSignal: '',
      ),
      syncStatus: SyncStatus.localOnly,
    );

JournalEntry _voiceEntry({
  required String id,
  String transcript = '',
  DateTime? createdAt,
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 12, 10),
  transcript: transcript,
  durationSeconds: 24,
  localAudioPath: '/tmp/$id.m4a',
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 2,
    recurringThemes: const [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
  syncStatus: SyncStatus.localOnly,
);

List<JournalEntry> _threeRelatedEntries({DateTime? lastCreatedAt}) => [
  _entry('1', _strongRepeat, createdAt: DateTime(2026, 6, 10, 12)),
  _entry(
    '2',
    'Same thing — said yes when I had no capacity for one more thing.',
    createdAt: DateTime(2026, 6, 11, 12),
  ),
  _entry(
    '3',
    'I said yes again even though I had no capacity for one more ask.',
    createdAt: lastCreatedAt ?? DateTime(2026, 6, 12, 12),
  ),
];

void main() {
  tearDown(() async {
    ActivationFunnelAnalytics.resetForTest();
    ComeBackTomorrowV2Analytics.resetForTest();
    await ReturnDayFlowStore.resetForTest(null);
  });

  group('ReturnDayFlowEngine', () {
    test('shows next day after grounded watch target', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final entries = [
        _entry(
          '1',
          _strongRepeat,
          createdAt: yesterday.subtract(const Duration(days: 2)),
        ),
        _entry(
          '2',
          'Same thing — said yes when I had no capacity for one more thing.',
          createdAt: yesterday.subtract(const Duration(days: 1)),
        ),
        _entry(
          '3',
          'I said yes again even though I had no capacity for one more ask.',
          createdAt: yesterday,
        ),
      ];
      final flow = ReturnDayFlowEngine.build(entries: entries, now: now);

      expect(flow, isNotNull);
      expect(flow!.title, ReturnDayFlowCopy.title);
      expect(flow.body, ReturnDayFlowCopy.defaultBody);
      expect(flow.watchingPhrase?.toLowerCase(), contains('said yes'));
      expect(flow.hasGroundedPhrase, isTrue);
    });

    test('shows next day with single grounded entry', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final flow = ReturnDayFlowEngine.build(
        entries: [_entry('1', _strongRepeat, createdAt: yesterday)],
        now: now,
      );

      expect(flow, isNotNull);
      expect(flow!.title, ReturnDayFlowCopy.title);
      expect(flow.body, ReturnDayFlowCopy.defaultBody);
      expect(flow.watchingPhrase, isNotNull);
    });

    test('hides same day', () {
      final today = DateTime.now();
      expect(
        ReturnDayFlowEngine.build(
          entries: [_entry('1', _strongRepeat, createdAt: today)],
          now: today,
        ),
        isNull,
      );
    });

    test('hides after user already recorded today', () {
      final now = DateTime.now();
      final today = now;
      final yesterday = now.subtract(const Duration(days: 1));
      expect(
        ReturnDayFlowEngine.build(
          entries: [
            _entry('1', _strongRepeat, createdAt: yesterday),
            _entry(
              '2',
              'Another moment saved earlier today.',
              createdAt: today,
            ),
          ],
          now: now,
        ),
        isNull,
      );
    });

    test('generic test text does not show', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final entries = [_entry('1', _genericTest, createdAt: yesterday)];
      expect(
        ArchiveEvidenceQualityGate.showsGenericTestEvidenceFallback(entries),
        isTrue,
      );
      expect(ReturnDayFlowEngine.build(entries: entries), isNull);
    });

    test('placeholder does not show', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(
        ReturnDayFlowEngine.build(
          entries: [
            _voiceEntry(
              id: 'p',
              transcript: _placeholder,
              createdAt: yesterday,
            ),
          ],
        ),
        isNull,
      );
    });

    test('pending transcript does not show', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(
        ReturnDayFlowEngine.build(
          entries: [_voiceEntry(id: 'p', createdAt: yesterday)],
        ),
        isNull,
      );
    });

    test('weak evidence does not show', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final weak = _entry('1', 'ok', createdAt: yesterday);
      expect(
        ArchiveEvidenceQuality.assess(weak).level,
        ArchiveEvidenceQualityLevel.weak,
      );
      expect(ReturnDayFlowEngine.build(entries: [weak]), isNull);
    });

    test('quiet-only history does not show', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final quiet = 'Nothing much today.';
      expect(RecordCaptureModeEngine.isQuietDayText(quiet), isTrue);
      expect(
        ReturnDayFlowEngine.build(
          entries: [_entry('1', quiet, createdAt: yesterday)],
          now: now,
        ),
        isNull,
      );
    });

    test('non-grounded single entry does not show', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      expect(
        ReturnDayFlowEngine.build(
          entries: [
            _entry(
              '1',
              'A quiet moment about lunch with a friend today.',
              createdAt: yesterday,
            ),
          ],
          now: now,
        ),
        isNull,
      );
    });

    test('does not duplicate ReturnTomorrowCueCard on ready', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final entries = [_entry('1', _strongRepeat, createdAt: yesterday)];
      final flow = ReturnDayFlowEngine.build(entries: entries, now: now);
      final returnCue = ReturnTomorrowCueEngine.buildReady(
        entries: entries,
        now: now,
      );

      expect(flow, isNotNull);
      expect(returnCue, isNotNull);
      final showReturnDay = ReturnDayFlowGates.shouldShow(
        isReady: true,
        isRecording: false,
        isPostSave: false,
        flow: flow,
        dismissedToday: false,
      );
      final showReturnTomorrow =
          ReturnTomorrowCueGates.shouldShowReady(
            isReady: true,
            isRecording: false,
            isPostSave: false,
            cue: returnCue,
          ) &&
          !showReturnDay;
      expect(showReturnDay, isTrue);
      expect(showReturnTomorrow, isFalse);
    });

    test('first proof still works independently', () {
      final entries = _threeRelatedEntries();
      expect(FirstProofMomentEngine.build(entries: entries), isNotNull);
    });
  });

  group('ReturnDayFlowStore', () {
    late _MemoryPrefs prefs;

    setUp(() async {
      prefs = _MemoryPrefs();
      await ReturnDayFlowStore.resetForTest(prefs);
    });

    test('not today dismiss hides for the day on reload', () async {
      final store = ReturnDayFlowStore.forPrefs(prefs);
      await store.saveTodayAnswer(ReturnDayFlowAnswer.notToday);
      await ReturnDayFlowStore.ensureLoaded();
      expect(ReturnDayFlowStore.isDismissedToday, isTrue);
      expect(ReturnDayFlowEngine.shouldHideForDismissal(), isTrue);
    });
  });

  group('ReturnDayFlowCard', () {
    testWidgets('Yes routes to capture helper and callback', (tester) async {
      var cameBack = false;
      const flow = ReturnDayFlow(
        title: ReturnDayFlowCopy.title,
        body: ReturnDayFlowCopy.defaultBody,
        daysSinceLastEntry: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReturnDayFlowCard.test(
              flow: flow,
              entryCount: 2,
              onCameBack: () => cameBack = true,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('return_watch_question_yes')));
      await tester.pump();

      expect(cameBack, isTrue);
      expect(find.text(ReturnDayFlowCopy.helperCameBack), findsOneWidget);
      expect(find.byKey(const Key('return_watch_question_yes')), findsNothing);
      expect(find.text(ConsumerUiCopy.recordMomentCta), findsNothing);
    });

    testWidgets('Not today shows acknowledgment and dismisses for today', (
      tester,
    ) async {
      const flow = ReturnDayFlow(
        title: ReturnDayFlowCopy.title,
        body: ReturnDayFlowCopy.defaultBody,
        daysSinceLastEntry: 1,
      );
      final prefs = _MemoryPrefs();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReturnDayFlowCard.test(
              flow: flow,
              entryCount: 2,
              store: ReturnDayFlowStore.forPrefs(prefs),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const Key('return_watch_question_not_today')),
      );
      await tester.pumpAndSettle();

      expect(find.text(ReturnDayFlowCopy.helperNotToday), findsOneWidget);
      expect(
        find.byKey(const Key('return_watch_question_not_today')),
        findsNothing,
      );
      expect(ReturnDayFlowStore.isDismissedToday, isTrue);
    });

    testWidgets('Different routes to capture helper and callback', (
      tester,
    ) async {
      var different = false;
      final flow = ReturnDayFlow(
        title: ReturnDayFlowCopy.title,
        body: ReturnDayFlowCopy.bodyWithPhrase('said yes again'),
        daysSinceLastEntry: 2,
        watchingPhrase: 'said yes again',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReturnDayFlowCard.test(
              flow: flow,
              entryCount: 3,
              onDifferent: () => different = true,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const Key('return_watch_question_different')),
      );
      await tester.pump();

      expect(different, isTrue);
      expect(find.text(ReturnDayFlowCopy.helperDifferent), findsOneWidget);
    });

    testWidgets('Record CTA is not duplicated inside card', (tester) async {
      const flow = ReturnDayFlow(
        title: ReturnDayFlowCopy.title,
        body: ReturnDayFlowCopy.defaultBody,
        daysSinceLastEntry: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReturnDayFlowCard.test(flow: flow, entryCount: 1),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.text(ConsumerUiCopy.recordMomentCta), findsNothing);
    });

    testWidgets('analytics excludes phrase text', (tester) async {
      final captured = <({String event, Map<String, Object> properties})>[];
      ComeBackTomorrowV2Analytics.captureForTest = (event, properties) =>
          captured.add((event: event, properties: properties));

      final flow = ReturnDayFlow(
        title: ReturnDayFlowCopy.title,
        body: ReturnDayFlowCopy.defaultBody,
        daysSinceLastEntry: 1,
        watchingPhrase: 'said yes again',
        source: 'first_grounded_save',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReturnDayFlowCard.test(flow: flow, entryCount: 2),
          ),
        ),
      );
      await tester.pump();

      final seen = captured
          .where(
            (e) => e.event == ComeBackTomorrowV2Analytics.questionSeenEvent,
          )
          .toList();
      expect(seen, isNotEmpty);
      expect(seen.first.properties['days_since_set'], isA<int>());
      final blob = seen.first.properties.entries
          .map((e) => '${e.key}:${e.value}')
          .join(' ');
      expect(blob.toLowerCase(), isNot(contains('said yes')));
    });
  });

  group('FirstWeekProgressGates dedup with Return Day Flow', () {
    test('does not show with Return Day Flow on ready', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final entries = [_entry('1', _strongRepeat, createdAt: yesterday)];
      final progress = FirstWeekProgressEngine.buildReady(
        entries: entries,
        now: now,
      );
      final flow = ReturnDayFlowEngine.build(entries: entries, now: now);

      expect(progress, isNotNull);
      expect(flow, isNotNull);
      expect(
        FirstWeekProgressGates.shouldShowReady(
          isReady: true,
          isRecording: false,
          isPostSave: false,
          progress: progress,
          showReturnDayFlow: true,
          showReturnTomorrowCue: false,
        ),
        isFalse,
      );
    });
  });
}
