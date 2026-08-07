import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence_quality_gate.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/come_back_tomorrow/come_back_tomorrow_v2_engine.dart';
import 'package:voicememory_mobile/features/come_back_tomorrow/come_back_tomorrow_v2_model.dart';
import 'package:voicememory_mobile/features/come_back_tomorrow/come_back_tomorrow_v2_store.dart';
import 'package:voicememory_mobile/features/daily_archive_memory/daily_archive_memory_engine.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/pattern_detail/pattern_detail_engine.dart';
import 'package:voicememory_mobile/features/pattern_detail/pattern_detail_model.dart';
import 'package:voicememory_mobile/features/pattern_lifecycle/pattern_lifecycle_copy.dart';
import 'package:voicememory_mobile/features/pattern_lifecycle/pattern_lifecycle_engine.dart';
import 'package:voicememory_mobile/features/pattern_lifecycle/pattern_lifecycle_model.dart';
import 'package:voicememory_mobile/features/private_report/private_report_builder.dart';
import 'package:voicememory_mobile/features/private_report/private_report_copy.dart';
import 'package:voicememory_mobile/features/quiet_signal/quiet_signal_analytics.dart';
import 'package:voicememory_mobile/features/quiet_signal/quiet_signal_copy.dart';
import 'package:voicememory_mobile/features/quiet_signal/quiet_signal_engine.dart';
import 'package:voicememory_mobile/features/return_day/return_day_flow_engine.dart';
import 'package:voicememory_mobile/features/weekly_review/weekly_archive_review_model.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/widgets/patterns/pattern_detail_sheet.dart';
import 'package:voicememory_mobile/widgets/patterns/quiet_signal_card.dart';
import 'package:voicememory_mobile/widgets/record/quiet_signal_record_card.dart';
import 'package:voicememory_mobile/widgets/weekly_review/weekly_archive_review_sheet.dart';

const _placeholder =
    '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected';
const _genericTest = 'This is a test to check function';
const _strongRepeat =
    'I had no capacity but I said yes again to the extra meeting today.';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs() : super(file: File('test/tmp/quiet_signal/unused.json'));

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
        mood: 'neutral',
        emotionalIntensity: 2,
        recurringThemes: ['work'],
        exactLanguagePattern: '',
        concreteObservation: 'Work pressure showed up in this moment.',
        repeatedSignal: '',
      ),
    );

void _seedWatch({required String createdDateKey}) {
  ComeBackTomorrowV2Store.seedForTest(
    ActiveWatchTarget(
      watchKey: 'said yes again',
      groundedPhrase: 'said yes again',
      createdDateKey: createdDateKey,
      source: 'second_related_save',
    ),
  );
}

List<JournalEntry> _baseWithTwoUnrelatedAfterWatch() => [
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

void main() {
  setUp(() {
    QuietSignalAnalytics.resetForTest();
    ComeBackTomorrowV2Store.seedForTest(null);
  });

  group('QuietSignalCopy', () {
    test('exact v1 copy', () {
      expect(QuietSignalCopy.title, 'This has not shown up recently');
      expect(
        QuietSignalCopy.body,
        'ArchiveMe was watching this thread, but your recent moments did not show it.',
      );
      expect(QuietSignalCopy.footer, 'That may matter too.');
      expect(QuietSignalCopy.ctaKeepWatching, 'Keep watching');
      expect(QuietSignalCopy.patternDetailHeading, 'Last seen');
      expect(QuietSignalCopy.weeklyReviewHeading, 'Quiet signal');
    });

    test('does not claim solved healed fixed cured or gone', () {
      final blob = QuietSignalCopy.allVisibleStrings().join(' ').toLowerCase();
      expect(blob, isNot(contains('heal')));
      expect(blob, isNot(contains('cure')));
      expect(blob, isNot(contains('fixed')));
      expect(blob, isNot(contains('gone')));
      expect(blob, isNot(contains('solved')));
      expect(blob, contains('may'));
      expect(blob, isNot(contains('%')));
    });

    test('passes proof surface advice guard', () {
      final blob = QuietSignalCopy.allVisibleStrings().join(' ');
      expect(ProofSurfaceAdviceGuard.passes(blob), isTrue);
    });
  });

  group('QuietSignalEngine detection', () {
    test('hidden when no active watch target', () {
      final signal = QuietSignalEngine.build(
        entries: _baseWithTwoUnrelatedAfterWatch(),
        now: DateTime(2026, 6, 15, 12),
      );
      expect(signal, isNull);
    });

    test('hidden same day', () {
      final now = DateTime(2026, 6, 10, 18);
      _seedWatch(createdDateKey: '2026-06-10');
      final entries = [
        _entry('1', _strongRepeat, createdAt: DateTime(2026, 6, 10, 12)),
        _entry(
          '2',
          'A quiet lunch with a friend — nothing about work.',
          createdAt: DateTime(2026, 6, 10, 16),
        ),
      ];
      expect(QuietSignalEngine.build(entries: entries, now: now), isNull);
    });

    test('hidden after only one later unrelated entry', () {
      _seedWatch(createdDateKey: '2026-06-10');
      final entries = [
        _entry('1', _strongRepeat, createdAt: DateTime(2026, 6, 10, 12)),
        _entry(
          '2',
          'A quiet lunch with a friend — nothing about work.',
          createdAt: DateTime(2026, 6, 11, 12),
        ),
      ];
      expect(
        QuietSignalEngine.build(
          entries: entries,
          now: DateTime(2026, 6, 12, 12),
        ),
        isNull,
      );
    });

    test('appears after 2 later unrelated usable entries', () {
      _seedWatch(createdDateKey: '2026-06-10');
      final signal = QuietSignalEngine.build(
        entries: _baseWithTwoUnrelatedAfterWatch(),
        now: DateTime(2026, 6, 15, 12),
      );
      expect(signal, isNotNull);
      expect(signal!.title, QuietSignalCopy.title);
      expect(signal.unrelatedSaveCount, 2);
    });

    test('appears after 3 later days if still unseen', () {
      _seedWatch(createdDateKey: '2026-06-10');
      final entries = [
        _entry('1', _strongRepeat, createdAt: DateTime(2026, 6, 10, 12)),
        _entry(
          '2',
          'A quiet lunch with a friend — nothing about work.',
          createdAt: DateTime(2026, 6, 11, 12),
        ),
      ];
      final signal = QuietSignalEngine.build(
        entries: entries,
        now: DateTime(2026, 6, 14, 12),
      );
      expect(signal, isNotNull);
    });

    test('hidden if watched thread returns', () {
      _seedWatch(createdDateKey: '2026-06-10');
      final entries = [
        _entry('1', _strongRepeat, createdAt: DateTime(2026, 6, 10, 12)),
        _entry(
          '2',
          'A quiet lunch with a friend — nothing about work.',
          createdAt: DateTime(2026, 6, 13, 12),
        ),
        _entry(
          '3',
          'I said yes again even though I had no capacity for one more ask.',
          createdAt: DateTime(2026, 6, 14, 12),
        ),
      ];
      expect(
        QuietSignalEngine.build(
          entries: entries,
          now: DateTime(2026, 6, 15, 12),
        ),
        isNull,
      );
    });

    test('hidden for generic test-only archive', () {
      _seedWatch(createdDateKey: '2026-06-10');
      final entries = [
        _entry('1', _genericTest, createdAt: DateTime(2026, 6, 10, 12)),
        _entry('2', _genericTest, createdAt: DateTime(2026, 6, 13, 12)),
        _entry('3', _genericTest, createdAt: DateTime(2026, 6, 14, 12)),
      ];
      expect(
        ArchiveEvidenceQualityGate.showsGenericTestEvidenceFallback(entries),
        isTrue,
      );
      expect(
        QuietSignalEngine.build(
          entries: entries,
          now: DateTime(2026, 6, 15, 12),
        ),
        isNull,
      );
    });

    test('hidden for pending-only archive', () {
      _seedWatch(createdDateKey: '2026-06-10');
      final entries = [
        _entry('1', _placeholder, createdAt: DateTime(2026, 6, 10, 12)),
        _entry('2', _placeholder, createdAt: DateTime(2026, 6, 13, 12)),
        _entry('3', _placeholder, createdAt: DateTime(2026, 6, 14, 12)),
      ];
      expect(
        ArchiveEvidenceQualityGate.showsPendingTranscriptFallback(entries),
        isTrue,
      );
      expect(
        QuietSignalEngine.build(
          entries: entries,
          now: DateTime(2026, 6, 15, 12),
        ),
        isNull,
      );
    });

    test('hidden when dismissed', () {
      ComeBackTomorrowV2Store.seedForTest(
        const ActiveWatchTarget(
          watchKey: 'said yes again',
          groundedPhrase: 'said yes again',
          createdDateKey: '2026-06-10',
          source: 'second_related_save',
          quietSignalDismissed: true,
        ),
      );
      expect(
        QuietSignalEngine.build(
          entries: _baseWithTwoUnrelatedAfterWatch(),
          now: DateTime(2026, 6, 15, 12),
        ),
        isNull,
      );
    });

    test('ComeBackTomorrowV2Engine delegates to QuietSignalEngine', () {
      _seedWatch(createdDateKey: '2026-06-10');
      final delegated = ComeBackTomorrowV2Engine.buildQuietSignal(
        entries: _baseWithTwoUnrelatedAfterWatch(),
        now: DateTime(2026, 6, 15, 12),
      );
      final direct = QuietSignalEngine.build(
        entries: _baseWithTwoUnrelatedAfterWatch(),
        now: DateTime(2026, 6, 15, 12),
      );
      expect(delegated?.title, direct?.title);
    });
  });

  group('Record ready hierarchy', () {
    test('return-day question beats quiet card', () {
      final now = DateTime(2026, 6, 15, 12);
      _seedWatch(createdDateKey: '2026-06-10');
      final entries = _baseWithTwoUnrelatedAfterWatch();
      final returnFlow = ReturnDayFlowEngine.build(entries: entries, now: now);
      final quiet = QuietSignalEngine.build(entries: entries, now: now);
      expect(returnFlow, isNotNull);
      expect(quiet, isNotNull);
      expect(
        QuietSignalGates.shouldShowOnRecordReady(
          isReady: true,
          isRecording: false,
          isPostSave: false,
          signal: quiet,
          showReturnDayFlow: true,
        ),
        isFalse,
      );
    });

    test('quiet card beats Daily Archive Memory Card', () {
      _seedWatch(createdDateKey: '2026-06-10');
      final entries = _baseWithTwoUnrelatedAfterWatch();
      final quiet = QuietSignalEngine.build(
        entries: entries,
        now: DateTime(2026, 6, 15, 12),
      );
      final memory = DailyArchiveMemoryEngine.build(entries: entries);
      final showQuiet = QuietSignalGates.shouldShowOnRecordReady(
        isReady: true,
        isRecording: false,
        isPostSave: false,
        signal: quiet,
        showReturnDayFlow: false,
      );
      expect(showQuiet, isTrue);
      expect(memory, isNotNull);
      expect(
        DailyArchiveMemoryGates.shouldShow(
          loaded: true,
          entryCount: entries.length,
          isReady: true,
          isRecording: false,
          isPostSave: false,
          memory: memory,
          showReturnDayFlow: false,
          showReturnTomorrowCueReady: false,
          showLowEvidenceGuidance: false,
          showWeeklyArchiveReview: false,
          firstProofLoopActive: false,
          showComeBackTomorrowQuietSignal: showQuiet,
        ),
        isFalse,
      );
    });
  });

  group('Pattern Lifecycle', () {
    test('resolves Quiet when quiet signal exists', () {
      _seedWatch(createdDateKey: '2026-06-10');
      final lifecycle = PatternLifecycleEngine.build(
        entries: _baseWithTwoUnrelatedAfterWatch(),
        viewingConfirmedRepeatOrTimeline: true,
        now: DateTime(2026, 6, 15, 12),
      );
      expect(lifecycle?.state, PatternLifecycleState.quiet);
      expect(lifecycle?.label, PatternLifecycleCopy.quietLabel);
    });
  });

  group('Private Report', () {
    test('includes quiet signal without diagnosis', () {
      _seedWatch(createdDateKey: '2026-06-10');
      final entries = [
        _entry('1', _strongRepeat, createdAt: DateTime(2026, 6, 8, 12)),
        _entry(
          '2',
          'Same thing — said yes when I had no capacity for one more thing.',
          createdAt: DateTime(2026, 6, 9, 12),
        ),
        _entry(
          '3',
          'I said yes again even though I had no capacity for one more ask.',
          createdAt: DateTime(2026, 6, 10, 12),
        ),
        _entry(
          '4',
          'A quiet lunch with a friend — nothing about work.',
          createdAt: DateTime(2026, 6, 13, 12),
        ),
        _entry(
          '5',
          'Went for a walk and noticed the weather.',
          createdAt: DateTime(2026, 6, 14, 12),
        ),
      ];
      final report = PrivateReportBuilder.build(
        entries: entries,
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(report, isNotNull);
      final watchSection = report!.sections.firstWhere(
        (section) =>
            section.heading == PrivateReportCopy.whatToWatchNextHeading,
      );
      expect(watchSection.lines, contains(QuietSignalCopy.privateReportLine));
      final blob = watchSection.lines.join(' ').toLowerCase();
      expect(blob, isNot(contains('diagnos')));
    });
  });

  group('QuietSignalRecordCard', () {
    testWidgets('keep watching dismisses active watch quiet state', (
      tester,
    ) async {
      final prefs = _MemoryPrefs();
      _seedWatch(createdDateKey: '2026-06-10');
      final signal = QuietSignalEngine.build(
        entries: _baseWithTwoUnrelatedAfterWatch(),
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

    testWidgets('analytics metadata only', (tester) async {
      final captured = <({String event, Map<String, Object> properties})>[];
      QuietSignalAnalytics.captureForTest = (event, properties) =>
          captured.add((event: event, properties: properties));
      _seedWatch(createdDateKey: '2026-06-10');
      final signal = QuietSignalEngine.build(
        entries: _baseWithTwoUnrelatedAfterWatch(),
        now: DateTime(2026, 6, 15, 12),
      )!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuietSignalRecordCard.test(signal: signal, entryCount: 3),
          ),
        ),
      );
      await tester.pump();

      final seen = captured.where(
        (e) => e.event == QuietSignalAnalytics.seenEvent,
      );
      expect(seen, isNotEmpty);
      expect(seen.first.properties['days_since_seen'], isA<int>());
      final blob = seen.first.properties.entries
          .map((e) => '${e.key}:${e.value}')
          .join(' ');
      expect(blob.toLowerCase(), isNot(contains('said yes')));
    });
  });

  group('QuietSignalCard', () {
    testWidgets('view pattern details fires analytics', (tester) async {
      final captured = <({String event, Map<String, Object> properties})>[];
      QuietSignalAnalytics.captureForTest = (event, properties) =>
          captured.add((event: event, properties: properties));
      _seedWatch(createdDateKey: '2026-06-10');
      final signal = QuietSignalEngine.build(
        entries: _baseWithTwoUnrelatedAfterWatch(),
        now: DateTime(2026, 6, 15, 12),
      )!;
      var opened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuietSignalCard.test(
              signal: signal,
              entryCount: 3,
              source: 'patterns',
              showViewPatternDetails: true,
              onViewPatternDetails: () => opened = true,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const Key('quiet_signal_card_cta_view_details')),
      );
      await tester.pump();
      expect(opened, isTrue);
      final tapped = captured
          .where((e) => e.event == QuietSignalAnalytics.ctaTappedEvent)
          .last;
      expect(tapped.properties['action_type'], 'view_pattern_details');
    });
  });

  group('Pattern Detail sheet', () {
    testWidgets('shows Last seen section when quiet signal exists', (
      tester,
    ) async {
      _seedWatch(createdDateKey: '2026-06-10');
      final entries = [
        _entry('1', _strongRepeat, createdAt: DateTime(2026, 6, 8, 12)),
        _entry(
          '2',
          'Same thing — said yes when I had no capacity for one more thing.',
          createdAt: DateTime(2026, 6, 9, 12),
        ),
        _entry(
          '3',
          'I said yes again even though I had no capacity for one more ask.',
          createdAt: DateTime(2026, 6, 10, 12),
        ),
        _entry(
          '4',
          'A quiet lunch with a friend — nothing about work.',
          createdAt: DateTime(2026, 6, 13, 12),
        ),
        _entry(
          '5',
          'Went for a walk and noticed the weather.',
          createdAt: DateTime(2026, 6, 14, 12),
        ),
      ];
      final confirmed = EarlyFirstSignalEngine.build(entries: entries);
      final detail = PatternDetailEngine.build(
        entries: entries,
        confirmedRepeat: confirmed,
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(detail, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PatternDetailSheet(
              detail: detail!,
              buildInput: PatternDetailBuildInput(
                entries: entries,
                confirmedRepeat: confirmed,
                viewingConfirmedRepeatOrTimeline: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('pattern_detail_quiet_signal_heading')),
        findsOneWidget,
      );
      expect(find.text(QuietSignalCopy.patternDetailHeading), findsOneWidget);
      expect(find.text(QuietSignalCopy.patternDetailBody), findsOneWidget);
    });
  });

  group('Weekly Review sheet', () {
    testWidgets('shows quiet signal section when present', (tester) async {
      _seedWatch(createdDateKey: '2026-06-10');
      final signal = QuietSignalEngine.build(
        entries: _baseWithTwoUnrelatedAfterWatch(),
        now: DateTime(2026, 6, 15, 12),
      );
      const review = WeeklyArchiveReviewResult(
        state: WeeklyArchiveReviewState.full,
        title: 'Weekly review',
        whatRepeated: null,
        whatChanged: null,
        whatHelped: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeeklyArchiveReviewSheet(review: review, quietSignal: signal),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('weekly_archive_review_quiet_signal_label')),
        findsOneWidget,
      );
      expect(find.text(QuietSignalCopy.weeklyReviewHeading), findsOneWidget);
      expect(find.text(QuietSignalCopy.weeklyReviewBody), findsOneWidget);
    });
  });

  group('Analytics safety', () {
    test('keep_watching is allowed action_type', () {
      expect(
        ActivationFunnelAnalytics.allowedActionTypeValues.contains(
          'keep_watching',
        ),
        isTrue,
      );
    });

    test('cta tapped uses metadata only', () {
      final captured = <String, Object>{};
      QuietSignalAnalytics.captureForTest = (event, properties) {
        captured.addAll(properties);
      };
      QuietSignalAnalytics.ctaTapped(
        source: 'patterns',
        entryCount: 3,
        actionType: 'keep_watching',
      );
      expect(captured['action_type'], 'keep_watching');
      expect(captured.containsKey('grounded_phrase'), isFalse);
    });
  });
}
