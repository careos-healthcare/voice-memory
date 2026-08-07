import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence_quality.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence_quality_gate.dart';
import 'package:voicememory_mobile/features/early_archive/first_proof_moment_engine.dart';
import 'package:voicememory_mobile/features/retention/return_tomorrow_cue_engine.dart';
import 'package:voicememory_mobile/features/retention/yesterday_watch_copy.dart';
import 'package:voicememory_mobile/features/retention/yesterday_watch_engine.dart';
import 'package:voicememory_mobile/features/retention/yesterday_watch_model.dart';
import 'package:voicememory_mobile/features/retention/yesterday_watch_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/widgets/record/yesterday_watch_card.dart';

const _placeholder =
    '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected';
const _genericTest = 'This is a test to check function';
const _strongRepeat =
    'I had no capacity but I said yes again to the extra meeting today.';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs() : super(file: File('test/tmp/yesterday_watch/unused.json'));

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
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
  syncStatus: SyncStatus.localOnly,
);

void main() {
  tearDown(() async {
    ActivationFunnelAnalytics.resetForTest();
    await YesterdayWatchStore.resetForTest(null);
  });

  group('YesterdayWatchEngine', () {
    test('shows next day after first proof context', () {
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
      final watch = YesterdayWatchEngine.build(entries: entries, now: now);

      expect(watch, isNotNull);
      expect(FirstProofMomentEngine.build(entries: entries), isNotNull);
      expect(watch!.daysSinceLastEntry, 1);
      expect(watch.title, contains('said yes'));
      expect(watch.body, YesterdayWatchCopy.phraseBody);
    });

    test('shows next day after return-tomorrow eligible archive', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final watch = YesterdayWatchEngine.build(
        entries: [_entry('1', _strongRepeat, createdAt: yesterday)],
        now: now,
      );

      expect(watch, isNotNull);
      expect(watch!.title, contains('said yes'));
    });

    test('shows grounded phrase only when quality gate allows it', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final entries = [
        _entry(
          '1',
          _strongRepeat,
          createdAt: yesterday.subtract(const Duration(days: 1)),
        ),
        _entry(
          '2',
          'Same thing — said yes when I had no capacity for one more thing.',
          createdAt: yesterday,
        ),
      ];
      final watch = YesterdayWatchEngine.build(entries: entries, now: now);

      expect(watch, isNotNull);
      expect(watch!.hasGroundedPhrase, isTrue);
      expect(
        watch.title,
        YesterdayWatchCopy.titleWithPhrase(watch.watchingPhrase!),
      );
      expect(watch.body, YesterdayWatchCopy.phraseBody);
    });

    test('uses default body when no grounded phrase', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final watch = YesterdayWatchEngine.build(
        entries: [
          _entry(
            '1',
            'A quiet moment about lunch with a friend today.',
            createdAt: yesterday,
          ),
        ],
        now: now,
      );

      expect(watch, isNotNull);
      expect(watch!.hasGroundedPhrase, isFalse);
      expect(watch.title, YesterdayWatchCopy.defaultTitle);
      expect(watch.body, YesterdayWatchCopy.defaultBody);
    });

    test('generic test text does not show', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final entries = [_entry('1', _genericTest, createdAt: yesterday)];
      expect(
        ArchiveEvidenceQualityGate.showsGenericTestEvidenceFallback(entries),
        isTrue,
      );
      expect(YesterdayWatchEngine.build(entries: entries), isNull);
    });

    test('placeholder does not show', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(
        YesterdayWatchEngine.build(
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
        YesterdayWatchEngine.build(
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
      expect(YesterdayWatchEngine.build(entries: [weak]), isNull);
    });

    test('does not show same day', () {
      final today = DateTime.now();
      expect(
        YesterdayWatchEngine.build(
          entries: [_entry('1', _strongRepeat, createdAt: today)],
          now: today,
        ),
        isNull,
      );
    });

    test('does not show after user already recorded today', () {
      final now = DateTime.now();
      final today = now;
      final yesterday = now.subtract(const Duration(days: 1));
      expect(
        YesterdayWatchEngine.build(
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

    test('does not duplicate ReturnTomorrowCueCard on ready', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final entries = [_entry('1', _strongRepeat, createdAt: yesterday)];
      final watch = YesterdayWatchEngine.build(entries: entries, now: now);
      final returnCue = ReturnTomorrowCueEngine.buildReady(
        entries: entries,
        now: now,
      );

      expect(watch, isNotNull);
      expect(returnCue, isNotNull);
      final showYesterday = YesterdayWatchGates.shouldShow(
        isReady: true,
        isRecording: false,
        isPostSave: false,
        watch: watch,
        dismissedToday: false,
      );
      final showReturnTomorrow =
          ReturnTomorrowCueGates.shouldShowReady(
            isReady: true,
            isRecording: false,
            isPostSave: false,
            cue: returnCue,
          ) &&
          !showYesterday;
      expect(showYesterday, isTrue);
      expect(showReturnTomorrow, isFalse);
    });
  });

  group('YesterdayWatchStore', () {
    late _MemoryPrefs prefs;

    setUp(() async {
      prefs = _MemoryPrefs();
      await YesterdayWatchStore.resetForTest(prefs);
    });

    test('dismiss hides for the day', () async {
      final store = YesterdayWatchStore.forPrefs(prefs);
      await store.saveTodayAnswer(YesterdayWatchAnswer.notToday);
      await YesterdayWatchStore.ensureLoaded();
      expect(YesterdayWatchStore.isDismissedToday, isTrue);
      expect(YesterdayWatchEngine.shouldHideForDismissal(), isTrue);
    });
  });

  group('YesterdayWatchCard', () {
    testWidgets('Yes, it came back shows helper and prefill callback', (
      tester,
    ) async {
      var cameBack = false;
      const watch = YesterdayWatch(
        title: YesterdayWatchCopy.defaultTitle,
        body: YesterdayWatchCopy.defaultBody,
        daysSinceLastEntry: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: YesterdayWatchCard.test(
              watch: watch,
              entryCount: 2,
              onCameBack: () => cameBack = true,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('yesterday_watch_yes')));
      await tester.pump();

      expect(cameBack, isTrue);
      expect(find.text(YesterdayWatchCopy.helperCameBack), findsOneWidget);
      expect(find.byKey(const Key('yesterday_watch_yes')), findsNothing);
      expect(find.text(ConsumerUiCopy.recordMomentCta), findsNothing);
    });

    testWidgets('Not today hides card', (tester) async {
      const watch = YesterdayWatch(
        title: YesterdayWatchCopy.defaultTitle,
        body: YesterdayWatchCopy.defaultBody,
        daysSinceLastEntry: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: YesterdayWatchCard.test(
              watch: watch,
              entryCount: 2,
              store: YesterdayWatchStore.forPrefs(_MemoryPrefs()),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('yesterday_watch_not_today')));
      await tester.pump();

      expect(find.byKey(const Key('yesterday_watch_card')), findsNothing);
    });

    testWidgets('Different this time shows helper and callback', (
      tester,
    ) async {
      var different = false;
      final watch = YesterdayWatch(
        title: YesterdayWatchCopy.titleWithPhrase('said yes again'),
        body: YesterdayWatchCopy.phraseBody,
        daysSinceLastEntry: 2,
        watchingPhrase: 'said yes again',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: YesterdayWatchCard.test(
              watch: watch,
              entryCount: 3,
              onDifferent: () => different = true,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('yesterday_watch_different')));
      await tester.pump();

      expect(different, isTrue);
      expect(find.text(YesterdayWatchCopy.helperDifferent), findsOneWidget);
    });

    testWidgets('Record CTA is not duplicated inside card', (tester) async {
      const watch = YesterdayWatch(
        title: YesterdayWatchCopy.defaultTitle,
        body: YesterdayWatchCopy.defaultBody,
        daysSinceLastEntry: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: YesterdayWatchCard.test(watch: watch, entryCount: 1),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.text(ConsumerUiCopy.recordMomentCta), findsNothing);
    });

    testWidgets('analytics excludes phrase text', (tester) async {
      final captured = <({String event, Map<String, Object> properties})>[];
      ActivationFunnelAnalytics.captureForTest(
        (event, properties) =>
            captured.add((event: event, properties: properties)),
      );

      final watch = YesterdayWatch(
        title: YesterdayWatchCopy.titleWithPhrase('said yes again'),
        body: YesterdayWatchCopy.phraseBody,
        daysSinceLastEntry: 1,
        watchingPhrase: 'said yes again',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: YesterdayWatchCard.test(watch: watch, entryCount: 2),
          ),
        ),
      );
      await tester.pump();

      final seen = captured
          .where((e) => e.event == ActivationFunnelAnalytics.yesterdayWatchSeen)
          .toList();
      expect(seen, isNotEmpty);
      final blob = seen.first.properties.entries
          .map((e) => '${e.key}:${e.value}')
          .join(' ');
      expect(blob.toLowerCase(), isNot(contains('said yes')));
    });
  });
}
