import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/come_back_tomorrow/come_back_tomorrow_v2_analytics.dart';
import 'package:voicememory_mobile/features/come_back_tomorrow/come_back_tomorrow_v2_copy.dart';
import 'package:voicememory_mobile/features/come_back_tomorrow/come_back_tomorrow_v2_engine.dart';
import 'package:voicememory_mobile/features/come_back_tomorrow/come_back_tomorrow_v2_model.dart';
import 'package:voicememory_mobile/features/come_back_tomorrow/come_back_tomorrow_v2_store.dart';
import 'package:voicememory_mobile/features/daily_archive_memory/daily_archive_memory_engine.dart';
import 'package:voicememory_mobile/features/early_archive/first_proof_moment_engine.dart';
import 'package:voicememory_mobile/features/what_changed/what_changed_v2_engine.dart';
import 'package:voicememory_mobile/features/quiet_signal/quiet_signal_copy.dart';
import 'package:voicememory_mobile/features/quiet_signal/quiet_signal_engine.dart';
import 'package:voicememory_mobile/features/record_capture_modes/record_capture_mode_engine.dart';
import 'package:voicememory_mobile/features/return_day/return_day_flow_engine.dart';
import 'package:voicememory_mobile/features/what_changed/what_changed_v2_model.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/features/return_day/return_day_flow_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/widgets/record/come_back_tomorrow_card.dart';
import 'package:voicememory_mobile/widgets/record/quiet_signal_record_card.dart';
import 'package:voicememory_mobile/widgets/record/return_watch_question_card.dart';

const _placeholder =
    '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected';
const _genericTest = 'This is a test to check function';
const _strongRepeat =
    'I had no capacity but I said yes again to the extra meeting today.';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs()
    : super(file: File('test/tmp/come_back_tomorrow_v2/unused.json'));

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
      localAudioPath: '/tmp/$id.m4a',
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
    recurringThemes: [],
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

List<JournalEntry> _fourRelatedEntries({DateTime? lastCreatedAt}) => [
  ..._threeRelatedEntries(),
  _entry(
    '4',
    'The meeting invite came in and I said yes again with no capacity left for it.',
    createdAt: lastCreatedAt ?? DateTime(2026, 6, 13, 12),
  ),
];

void main() {
  tearDown(() async {
    ActivationFunnelAnalytics.resetForTest();
    ComeBackTomorrowV2Analytics.resetForTest();
    await ComeBackTomorrowV2Store.resetForTest(null);
  });

  group('ComeBackTomorrowV2Copy', () {
    test('uses required v2 strings', () {
      expect(ComeBackTomorrowV2Copy.all, contains('Watch this tomorrow'));
      expect(ComeBackTomorrowV2Copy.all, contains('Did this come back?'));
      expect(ComeBackTomorrowV2Copy.all, contains('That may matter too.'));
      expect(ComeBackTomorrowV2Copy.all, isNot(contains('healed')));
      expect(ComeBackTomorrowV2Copy.all, isNot(contains('cured')));
      expect(ComeBackTomorrowV2Copy.all, isNot(contains('solved')));
    });
  });

  group('ComeBackTomorrowV2Engine post-save', () {
    test('appears after real grounded save', () {
      final watch = ComeBackTomorrowV2Engine.buildPostSaveWatch(
        entries: [_entry('1', _strongRepeat)],
        firstProofUnlocked: false,
      );
      expect(watch, isNotNull);
      expect(watch!.title, ComeBackTomorrowV2Copy.postSaveTitle);
      expect(watch.groundedPhrase.toLowerCase(), contains('said yes'));
    });

    test('hidden for generic test-only entry', () {
      expect(
        ComeBackTomorrowV2Engine.buildPostSaveWatch(
          entries: [_entry('1', _genericTest)],
          firstProofUnlocked: false,
        ),
        isNull,
      );
    });

    test('hidden for pending transcript', () {
      expect(
        ComeBackTomorrowV2Engine.buildPostSaveWatch(
          entries: [_voiceEntry(id: 'p')],
          firstProofUnlocked: false,
        ),
        isNull,
      );
    });

    test('hidden for degraded placeholder transcript', () {
      expect(
        ComeBackTomorrowV2Engine.buildPostSaveWatch(
          entries: [_voiceEntry(id: 'p', transcript: _placeholder)],
          firstProofUnlocked: false,
        ),
        isNull,
      );
    });

    test('hidden for quiet-day-only save', () {
      final quiet = 'Nothing much today.';
      expect(RecordCaptureModeEngine.isQuietDayText(quiet), isTrue);
      expect(
        ComeBackTomorrowV2Engine.buildPostSaveWatch(
          entries: [_entry('1', quiet)],
          firstProofUnlocked: false,
        ),
        isNull,
      );
    });

    test('first proof payoff beats come-back-tomorrow card', () {
      final entries = _threeRelatedEntries();
      final watch = ComeBackTomorrowV2Engine.buildPostSaveWatch(
        entries: entries,
        firstProofUnlocked: true,
      );
      expect(FirstProofMomentEngine.build(entries: entries), isNotNull);
      expect(watch, isNotNull);
      expect(
        ComeBackTomorrowV2Gates.shouldShowPostSave(
          isPostSaveDone: true,
          isDegradedPostSave: false,
          watch: watch,
          showFirstProofPayoff: true,
          showFirstProofTruth: false,
          showFirstProofActionLoop: false,
          showWhatChangedV2Display: false,
          showHelpedTracking: false,
        ),
        isFalse,
      );
    });

    test('What Changed v2 beats come-back-tomorrow on 4th related save', () {
      final entries = _fourRelatedEntries();
      final watch = ComeBackTomorrowV2Engine.buildPostSaveWatch(
        entries: entries,
        firstProofUnlocked: true,
      );
      const display = WhatChangedV2Prompt(
        entryId: 'e4',
        entryCount: 4,
        hasConfirmedRepeat: true,
        options: WhatChangedV2Option.values,
        comparison: WhatChangedV2Comparison(
          thenSnippet: 'said yes again',
          nowSnippet: 'said yes again with no capacity',
        ),
      );
      expect(watch, isNotNull);
      expect(
        WhatChangedV2Engine.shouldShowPostSaveDisplay(
          isPostSaveDone: true,
          isDegradedPostSave: false,
          showFirstProofMoment: false,
          display: display,
        ),
        isTrue,
      );
      expect(
        ComeBackTomorrowV2Gates.shouldShowPostSave(
          isPostSaveDone: true,
          isDegradedPostSave: false,
          watch: watch,
          showFirstProofPayoff: false,
          showFirstProofTruth: false,
          showFirstProofActionLoop: false,
          showWhatChangedV2Display: true,
          showHelpedTracking: false,
        ),
        isFalse,
      );
    });

    test('helped tracking beats come-back-tomorrow card', () {
      final entries = _fourRelatedEntries();
      final watch = ComeBackTomorrowV2Engine.buildPostSaveWatch(
        entries: entries,
        firstProofUnlocked: true,
      );
      expect(watch, isNotNull);
      expect(
        ComeBackTomorrowV2Gates.shouldShowPostSave(
          isPostSaveDone: true,
          isDegradedPostSave: false,
          watch: watch,
          showFirstProofPayoff: false,
          showFirstProofTruth: false,
          showFirstProofActionLoop: false,
          showWhatChangedV2Display: false,
          showHelpedTracking: true,
        ),
        isFalse,
      );
    });
  });

  group('ComeBackTomorrowV2Engine return day', () {
    test('question appears on later day with active phrase', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final entries = [_entry('1', _strongRepeat, createdAt: yesterday)];
      final question = ComeBackTomorrowV2Engine.buildReturnQuestion(
        entries: entries,
        now: now,
      );

      expect(question, isNotNull);
      expect(question!.title, ComeBackTomorrowV2Copy.returnQuestionTitle);
      expect(question.groundedPhrase.toLowerCase(), contains('said yes'));
    });

    test('question does not appear same day', () {
      final today = DateTime.now();
      expect(
        ComeBackTomorrowV2Engine.buildReturnQuestion(
          entries: [_entry('1', _strongRepeat, createdAt: today)],
          now: today,
        ),
        isNull,
      );
    });
  });

  group('ReturnWatchQuestionCard', () {
    testWidgets('Yes opens record flow with came-back helper', (tester) async {
      var cameBack = false;
      const question = ComeBackTomorrowReturnQuestion(
        title: ComeBackTomorrowV2Copy.returnQuestionTitle,
        body: ComeBackTomorrowV2Copy.returnQuestionBody,
        groundedPhrase: 'said yes again',
        daysSinceSet: 1,
        source: 'first_grounded_save',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReturnWatchQuestionCard.test(
              question: question,
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
      expect(find.text(ComeBackTomorrowV2Copy.helperCameBack), findsOneWidget);
    });

    testWidgets('Not today stores answer and shows acknowledgement', (
      tester,
    ) async {
      final prefs = _MemoryPrefs();
      final returnDayPrefs = _MemoryPrefs();
      const question = ComeBackTomorrowReturnQuestion(
        title: ComeBackTomorrowV2Copy.returnQuestionTitle,
        body: ComeBackTomorrowV2Copy.returnQuestionBody,
        groundedPhrase: 'said yes again',
        daysSinceSet: 1,
        source: 'first_grounded_save',
      );

      ComeBackTomorrowV2Store.seedForTest(
        const ActiveWatchTarget(
          watchKey: 'said yes again',
          groundedPhrase: 'said yes again',
          createdDateKey: '2026-06-11',
          source: 'first_grounded_save',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReturnWatchQuestionCard.test(
              question: question,
              entryCount: 2,
              store: ComeBackTomorrowV2Store.forPrefs(prefs),
              returnDayStore: ReturnDayFlowStore.forPrefs(returnDayPrefs),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const Key('return_watch_question_not_today')),
      );
      await tester.pumpAndSettle();

      expect(find.text(ComeBackTomorrowV2Copy.helperNotToday), findsOneWidget);
      expect(ComeBackTomorrowV2Store.active?.lastResponseType, 'not_today');
    });

    testWidgets('Different opens record flow with changed helper', (
      tester,
    ) async {
      var different = false;
      const question = ComeBackTomorrowReturnQuestion(
        title: ComeBackTomorrowV2Copy.returnQuestionTitle,
        body: ComeBackTomorrowV2Copy.returnQuestionBody,
        groundedPhrase: 'said yes again',
        daysSinceSet: 2,
        source: 'second_related_save',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReturnWatchQuestionCard.test(
              question: question,
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
      expect(find.text(ComeBackTomorrowV2Copy.helperDifferent), findsOneWidget);
    });
  });

  group('ComeBackTomorrowV2Engine quiet signal', () {
    test('appears after active target is not seen recently', () {
      final now = DateTime(2026, 6, 15, 12);
      ComeBackTomorrowV2Store.seedForTest(
        const ActiveWatchTarget(
          watchKey: 'said yes again',
          groundedPhrase: 'said yes again',
          createdDateKey: '2026-06-10',
          source: 'second_related_save',
        ),
      );
      final entries = [
        _entry('1', _strongRepeat, createdAt: DateTime(2026, 6, 10, 12)),
        _entry(
          '2',
          'A quiet lunch with a friend — nothing about work.',
          createdAt: DateTime(2026, 6, 13, 12),
        ),
        _entry(
          '3',
          'Went for a walk and noticed the weather.',
          createdAt: DateTime(2026, 6, 14, 12),
        ),
      ];
      final signal = ComeBackTomorrowV2Engine.buildQuietSignal(
        entries: entries,
        now: now,
      );

      expect(signal, isNotNull);
      expect(signal!.title, QuietSignalCopy.title);
    });

    test('does not claim improvement or diagnosis', () {
      final blob = ComeBackTomorrowV2Copy.all.join(' ').toLowerCase();
      expect(blob, isNot(contains('improv')));
      expect(blob, isNot(contains('heal')));
      expect(blob, isNot(contains('cure')));
      expect(blob, isNot(contains('diagnos')));
      expect(blob, contains('may'));
    });
  });

  group('ComeBackTomorrowCard', () {
    testWidgets('has no duplicate CTAs', (tester) async {
      const watch = ComeBackTomorrowPostSaveWatch(
        title: ComeBackTomorrowV2Copy.postSaveTitle,
        body: ComeBackTomorrowV2Copy.postSaveBody,
        groundedPhrase: 'said yes again',
        footer: ComeBackTomorrowV2Copy.postSaveFooter,
        source: 'first_grounded_save',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ComeBackTomorrowCard.test(watch: watch, entryCount: 1),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.text('Done'), findsNothing);
      expect(find.text('Record another'), findsNothing);
    });

    testWidgets('analytics metadata only', (tester) async {
      final captured = <({String event, Map<String, Object> properties})>[];
      ComeBackTomorrowV2Analytics.captureForTest = (event, properties) =>
          captured.add((event: event, properties: properties));

      const watch = ComeBackTomorrowPostSaveWatch(
        title: ComeBackTomorrowV2Copy.postSaveTitle,
        body: ComeBackTomorrowV2Copy.postSaveBody,
        groundedPhrase: 'said yes again',
        footer: ComeBackTomorrowV2Copy.postSaveFooter,
        source: 'first_grounded_save',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ComeBackTomorrowCard.test(watch: watch, entryCount: 1),
          ),
        ),
      );
      await tester.pump();

      final seen = captured
          .where((e) => e.event == ComeBackTomorrowV2Analytics.watchSetEvent)
          .toList();
      expect(seen, isNotEmpty);
      expect(seen.first.properties['has_watch_target'], 1);
      final blob = seen.first.properties.entries
          .map((e) => '${e.key}:${e.value}')
          .join(' ');
      expect(blob.toLowerCase(), isNot(contains('said yes')));
    });
  });

  group('Daily Archive Memory dedup', () {
    test('does not duplicate return-day question', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final entries = [_entry('1', _strongRepeat, createdAt: yesterday)];
      final flow = ReturnDayFlowEngine.build(entries: entries, now: now);
      final memory = DailyArchiveMemoryEngine.build(entries: entries);

      expect(flow, isNotNull);
      expect(memory, isNotNull);
      expect(
        DailyArchiveMemoryGates.shouldShow(
          loaded: true,
          entryCount: entries.length,
          isReady: true,
          isRecording: false,
          isPostSave: false,
          memory: memory,
          showReturnDayFlow: true,
          showReturnTomorrowCueReady: false,
          showLowEvidenceGuidance: false,
          showWeeklyArchiveReview: false,
          firstProofLoopActive: false,
        ),
        isFalse,
      );
    });
  });

  group('QuietSignalRecordCard', () {
    testWidgets('keep watching dismisses signal', (tester) async {
      final prefs = _MemoryPrefs();
      ComeBackTomorrowV2Store.seedForTest(
        const ActiveWatchTarget(
          watchKey: 'said yes again',
          groundedPhrase: 'said yes again',
          createdDateKey: '2026-06-10',
          source: 'second_related_save',
        ),
      );
      final signal = QuietSignalEngine.build(
        entries: [
          _entry('1', _strongRepeat, createdAt: DateTime(2026, 6, 10, 12)),
          _entry(
            '2',
            'A quiet lunch with a friend — nothing about work.',
            createdAt: DateTime(2026, 6, 13, 12),
          ),
          _entry(
            '3',
            'Went for a walk and noticed the weather.',
            createdAt: DateTime(2026, 6, 14, 12),
          ),
        ],
        now: DateTime(2026, 6, 15, 12),
      )!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuietSignalRecordCard.test(
              signal: signal,
              entryCount: 3,
              store: ComeBackTomorrowV2Store.forPrefs(prefs),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('quiet_signal_record_cta')));
      await tester.pump();

      expect(ComeBackTomorrowV2Store.active?.quietSignalDismissed, isTrue);
    });
  });
}
