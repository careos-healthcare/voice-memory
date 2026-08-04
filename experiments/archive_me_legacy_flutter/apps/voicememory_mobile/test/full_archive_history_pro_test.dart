import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/paywall_timing_gates.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_belief_thread_copy.dart';
import 'package:voicememory_mobile/features/early_archive/archive_summary_gates.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/early_archive/weekly_archive_review_gates.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/widgets/patterns/archive_intelligence_pro_bridge_card.dart';

JournalEntry _entry(String id, String transcript) {
  return JournalEntry(
    id: id,
    createdAt: DateTime(2026, 6, 12, 10),
    transcript: transcript,
    durationSeconds: 30,
    reflection: const Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 2,
      recurringThemes: ['work'],
      exactLanguagePattern: '',
      concreteObservation: 'Work pressure showed up again today.',
      repeatedSignal: '',
    ),
  );
}

List<JournalEntry> get _confirmedThreeEntries => [
  _entry(
    '1',
    'I had no capacity but I said yes again to the extra meeting today.',
  ),
  _entry(
    '2',
    'Same thing — said yes when I had no capacity for one more thing.',
  ),
  _entry(
    '3',
    'I said yes again even though I had no capacity for one more ask.',
  ),
];

List<JournalEntry> get _fiveRelatedEntries => [
  ..._confirmedThreeEntries,
  _entry(
    '4',
    'I said yes again even though I had no capacity for one more ask today.',
  ),
  _entry(
    '5',
    'Same yes pattern came back but it felt less urgent and easier to stop.',
  ),
];

void main() {
  group('PaywallTimingGates.showFullArchiveHistoryProBoundary', () {
    test('hidden before first proof', () {
      expect(
        PaywallTimingGates.showFullArchiveHistoryProBoundary(
          entryCount: 2,
          resolved: false,
          isPro: false,
          isPostSave: false,
          hasConfirmedRepeat: false,
          hasArchiveSummary: false,
          hasWeeklyArchiveReview: false,
        ),
        isFalse,
      );
    });

    test('hidden on first save', () {
      expect(
        PaywallTimingGates.showFullArchiveHistoryProBoundary(
          entryCount: 3,
          resolved: false,
          isPro: false,
          isPostSave: true,
          hasConfirmedRepeat: true,
          hasArchiveSummary: false,
          hasWeeklyArchiveReview: false,
        ),
        isFalse,
      );
    });

    test('hidden before entry count 3', () {
      expect(
        PaywallTimingGates.showFullArchiveHistoryProBoundary(
          entryCount: 2,
          resolved: false,
          isPro: false,
          isPostSave: false,
          hasConfirmedRepeat: true,
          hasArchiveSummary: false,
          hasWeeklyArchiveReview: false,
        ),
        isFalse,
      );
    });

    test('visible after confirmed repeat', () {
      expect(
        PaywallTimingGates.showFullArchiveHistoryProBoundary(
          entryCount: 3,
          resolved: false,
          isPro: false,
          isPostSave: false,
          hasConfirmedRepeat: true,
          hasArchiveSummary: false,
          hasWeeklyArchiveReview: false,
        ),
        isTrue,
      );
    });

    test('visible after Archive Summary', () {
      expect(
        PaywallTimingGates.showFullArchiveHistoryProBoundary(
          entryCount: 3,
          resolved: false,
          isPro: false,
          isPostSave: false,
          hasConfirmedRepeat: false,
          hasArchiveSummary: true,
          hasWeeklyArchiveReview: false,
        ),
        isTrue,
      );
    });

    test('visible after Weekly Review when available', () {
      expect(
        PaywallTimingGates.showFullArchiveHistoryProBoundary(
          entryCount: 5,
          resolved: false,
          isPro: false,
          isPostSave: false,
          hasConfirmedRepeat: false,
          hasArchiveSummary: false,
          hasWeeklyArchiveReview: true,
        ),
        isTrue,
      );
    });

    test('visible after Private Archive Report preview', () {
      expect(
        PaywallTimingGates.showFullArchiveHistoryProBoundary(
          entryCount: 3,
          resolved: false,
          isPro: false,
          isPostSave: false,
          hasConfirmedRepeat: false,
          hasArchiveSummary: false,
          hasWeeklyArchiveReview: false,
          hasPrivateArchiveReportPreview: true,
        ),
        isTrue,
      );
    });

    test('visible after Pattern Changed', () {
      expect(
        PaywallTimingGates.showFullArchiveHistoryProBoundary(
          entryCount: 4,
          resolved: false,
          isPro: false,
          isPostSave: false,
          hasConfirmedRepeat: false,
          hasArchiveSummary: false,
          hasWeeklyArchiveReview: false,
          hasPatternChanged: true,
        ),
        isTrue,
      );
    });

    test('visible after return check answered', () {
      expect(
        PaywallTimingGates.showFullArchiveHistoryProBoundary(
          entryCount: 4,
          resolved: false,
          isPro: false,
          isPostSave: false,
          hasConfirmedRepeat: false,
          hasArchiveSummary: false,
          hasWeeklyArchiveReview: false,
          hasReturnCheckAnswered: true,
        ),
        isTrue,
      );
    });

    test('respects resolved and Pro user flags', () {
      expect(
        PaywallTimingGates.showFullArchiveHistoryProBoundary(
          entryCount: 4,
          resolved: true,
          isPro: false,
          isPostSave: false,
          hasConfirmedRepeat: true,
          hasArchiveSummary: false,
          hasWeeklyArchiveReview: false,
        ),
        isFalse,
      );
      expect(
        PaywallTimingGates.showFullArchiveHistoryProBoundary(
          entryCount: 4,
          resolved: false,
          isPro: true,
          isPostSave: false,
          hasConfirmedRepeat: true,
          hasArchiveSummary: false,
          hasWeeklyArchiveReview: false,
        ),
        isFalse,
      );
    });
  });

  group('Full archive history integration gates', () {
    test(
      'confirmed repeat at three entries qualifies archive summary and boundary',
      () {
        final entries = _confirmedThreeEntries;
        expect(
          EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries),
          isTrue,
        );
        expect(
          ArchiveSummaryGates.shouldShow(
            loaded: true,
            entryCount: 3,
            isReady: true,
            isRecording: false,
            viewingConfirmedRepeatOrTimeline: true,
            hasSummary: true,
          ),
          isTrue,
        );
        expect(
          PaywallTimingGates.showPostProofProBridge(
            entryCount: 3,
            resolved: false,
            isPro: false,
            hasArchiveProof: true,
            viewingConfirmedRepeatOrTimeline: true,
            hasChangeOverTimeProof: false,
            hasArchiveSummary: true,
            hasWeeklyArchiveReview: false,
          ),
          isTrue,
        );
      },
    );

    test('weekly review gate can qualify boundary at five entries', () {
      expect(
        WeeklyArchiveWeekReviewGates.shouldShow(
          loaded: true,
          entryCount: 5,
          isReady: true,
          isRecording: false,
          entries: _fiveRelatedEntries,
        ),
        isTrue,
      );
      expect(
        PaywallTimingGates.showFullArchiveHistoryProBoundary(
          entryCount: 5,
          resolved: false,
          isPro: false,
          isPostSave: false,
          hasConfirmedRepeat: false,
          hasArchiveSummary: false,
          hasWeeklyArchiveReview: true,
        ),
        isTrue,
      );
    });

    test('free confirmed repeat proof remains visible for non-Pro users', () {
      final entries = _confirmedThreeEntries;
      expect(
        EarlyFirstSignalEngine.build(entries: entries)?.showsConfirmedRepeat,
        isTrue,
      );
      expect(
        PaywallTimingGates.showFullArchiveHistoryProBoundary(
          entryCount: 3,
          resolved: false,
          isPro: false,
          isPostSave: false,
          hasConfirmedRepeat: true,
          hasArchiveSummary: false,
          hasWeeklyArchiveReview: false,
        ),
        isTrue,
      );
    });
  });

  group('Full archive history copy', () {
    test('uses exact boundary copy', () {
      expect(
        ArchiveBeliefThreadCopy.fullArchiveHistoryTitle,
        'Keep the longer proof trail',
      );
      expect(
        ArchiveBeliefThreadCopy.fullArchiveHistoryBody,
        'Your first repeat is free. Pro keeps the longer proof trail so ArchiveMe '
        'can show what returns, changes, fades, or gets corrected over time.',
      );
      expect(
        ArchiveBeliefThreadCopy.fullArchiveHistoryBullets,
        containsAll([
          'Longer proof trail',
          'What returned and changed',
          'Correction history',
          'Continuity over time',
        ]),
      );
      expect(ArchiveBeliefThreadCopy.whyPro, isNotEmpty);
      expect(ArchiveBeliefThreadCopy.proBridgeCta, 'See Pro');
      expect(ArchiveBeliefThreadCopy.proBridgeSecondary, 'Not now');
    });

    test('no hard-lock or medical language', () {
      final haystack = [
        ArchiveBeliefThreadCopy.fullArchiveHistoryTitle,
        ArchiveBeliefThreadCopy.fullArchiveHistoryBody,
        ...ArchiveBeliefThreadCopy.fullArchiveHistoryBullets,
        ArchiveBeliefThreadCopy.whyPro,
        ArchiveBeliefThreadCopy.proBridgeCta,
        ArchiveBeliefThreadCopy.proBridgeSecondary,
      ].join(' ').toLowerCase();
      expect(haystack, isNot(contains('upgrade required')));
      expect(haystack, isNot(contains('feature locked')));
      expect(haystack, isNot(contains('must pay')));
      expect(haystack, isNot(contains('hard lock')));
      expect(haystack, isNot(contains('locked out')));
      expect(haystack, isNot(contains('unlock your healing')));
      expect(haystack, isNot(contains('therapy')));
      expect(haystack, isNot(contains('diagnosis')));
    });
  });

  group('ArchiveIntelligenceProBridgeCard', () {
    testWidgets('renders full archive history boundary', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArchiveIntelligenceProBridgeCard(
              onSeePro: () {},
              onNotNow: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text(ArchiveBeliefThreadCopy.fullArchiveHistoryTitle),
        findsOneWidget,
      );
      expect(
        find.text(ArchiveBeliefThreadCopy.fullArchiveHistoryBody),
        findsOneWidget,
      );
      for (final bullet in ArchiveBeliefThreadCopy.fullArchiveHistoryBullets) {
        expect(find.text(bullet), findsOneWidget);
      }
      expect(find.text(ArchiveBeliefThreadCopy.whyPro), findsOneWidget);
      expect(find.text(ArchiveBeliefThreadCopy.proBridgeCta), findsOneWidget);
      expect(
        find.text(ArchiveBeliefThreadCopy.proBridgeSecondary),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('full_archive_history_pro_boundary_card')),
        findsOneWidget,
      );
    });

    testWidgets('does not block recording', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ArchiveIntelligenceProBridgeCard(
                  onSeePro: () {},
                  onNotNow: () {},
                ),
                FilledButton(
                  key: const Key('record_primary_cta'),
                  onPressed: () {},
                  child: const Text('Record moment'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('full_archive_history_pro_boundary_card')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('record_primary_cta')), findsOneWidget);
      await tester.tap(find.byKey(const Key('record_primary_cta')));
      await tester.pump();
    });
  });
}
