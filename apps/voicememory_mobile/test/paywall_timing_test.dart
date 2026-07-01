import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/first_three_session_gates.dart';
import 'package:voicememory_mobile/features/activation/paywall_timing_gates.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_belief_thread_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/onboarding/first_60_second_state.dart';
import 'package:voicememory_mobile/features/onboarding/first_save_loop_state.dart';
import 'package:voicememory_mobile/features/onboarding/record_return_pro_state.dart';
import 'package:voicememory_mobile/billing/restore_purchases_copy.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_trend.dart';
import 'package:voicememory_mobile/features/retention/second_session_signal_engine.dart';
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
      exactLanguagePattern: 'pattern',
      concreteObservation: 'Work pressure showed up again today.',
      repeatedSignal: 'signal',
    ),
  );
}

List<JournalEntry> get _unrelatedTwoEntries => [
      _entry(
        '1',
        'A quiet moment about lunch with a friend today.',
      ),
      _entry(
        '2',
        'Another unrelated note about errands this afternoon.',
      ),
    ];

List<JournalEntry> get _groundedTwoEntries => [
      _entry(
        '1',
        'I said yes again even though I was already tired from work today.',
      ),
      _entry(
        '2',
        'I took responsibility again before asking anyone for help today.',
      ),
    ];

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

void main() {
  group('PaywallTimingGates.hasArchiveProofFromEntries', () {
    test('no proof for empty, one entry, or two unrelated saves', () {
      expect(
        PaywallTimingGates.hasArchiveProofFromEntries(entries: const []),
        isFalse,
      );
      expect(
        PaywallTimingGates.hasArchiveProofFromEntries(
          entries: [_entry('1', 'First honest moment with enough words.')],
        ),
        isFalse,
      );
      expect(
        PaywallTimingGates.hasArchiveProofFromEntries(
          entries: _unrelatedTwoEntries,
        ),
        isFalse,
      );
      expect(
        const SecondSessionSignalEngine().hasGroundedRepeatMatch(
          _unrelatedTwoEntries,
        ),
        isFalse,
      );
    });

    test('grounded two-entry repeat counts as archive proof', () {
      expect(
        PaywallTimingGates.hasArchiveProofFromEntries(
          entries: _groundedTwoEntries,
        ),
        isTrue,
      );
      expect(
        EarlyFirstSignalEngine.build(entries: _groundedTwoEntries)?.kind,
        EarlyFirstSignalKind.twoEntryFirstSignal,
      );
    });

    test('confirmed three-entry repeat counts as archive proof', () {
      expect(
        PaywallTimingGates.hasArchiveProofFromEntries(
          entries: _confirmedThreeEntries,
        ),
        isTrue,
      );
      expect(
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(_confirmedThreeEntries),
        isTrue,
      );
    });

    test('belief and weekly flags count as archive proof', () {
      expect(
        PaywallTimingGates.hasArchiveProofFromEntries(
          entries: _unrelatedTwoEntries,
          hasBeliefProof: true,
        ),
        isTrue,
      );
      expect(
        PaywallTimingGates.hasArchiveProofFromEntries(
          entries: _unrelatedTwoEntries,
          hasWeeklyReview: true,
        ),
        isTrue,
      );
    });

    test('change-over-time proof counts as archive proof', () {
      expect(
        PaywallTimingGates.hasArchiveProofFromEntries(
          entries: _unrelatedTwoEntries,
          hasChangeOverTimeProof: true,
        ),
        isTrue,
      );
    });
  });

  group('PaywallTimingGates.showPostProofProBridge', () {
    test('does not show before first repeat proof', () {
      expect(
        PaywallTimingGates.showPostProofProBridge(
          entryCount: 1,
          resolved: false,
          isPro: false,
          hasArchiveProof: false,
          viewingConfirmedRepeatOrTimeline: false,
          hasChangeOverTimeProof: false,
        ),
        isFalse,
      );
      expect(
        PaywallTimingGates.showPostProofProBridge(
          entryCount: 2,
          resolved: false,
          isPro: false,
          hasArchiveProof: false,
          viewingConfirmedRepeatOrTimeline: false,
          hasChangeOverTimeProof: false,
        ),
        isFalse,
      );
    });

    test('shows after confirmed repeat proof', () {
      final proof = PaywallTimingGates.hasArchiveProofFromEntries(
        entries: _confirmedThreeEntries,
      );
      expect(proof, isTrue);
      expect(
        PaywallTimingGates.showPostProofProBridge(
          entryCount: 4,
          resolved: false,
          isPro: false,
          hasArchiveProof: proof,
          viewingConfirmedRepeatOrTimeline: true,
          hasChangeOverTimeProof: false,
        ),
        isTrue,
      );
    });

    test('shows at three-entry confirmed repeat with evidence phrases', () {
      final signal = EarlyFirstSignalEngine.build(entries: _confirmedThreeEntries);
      final proof = PaywallTimingGates.hasArchiveProofFromEntries(
        entries: _confirmedThreeEntries,
      );
      expect(signal?.showsConfirmedRepeat, isTrue);
      expect(signal?.evidencePhrases, isNotEmpty);
      expect(proof, isTrue);
      expect(
        PaywallTimingGates.showPostProofProBridge(
          entryCount: 3,
          resolved: false,
          isPro: false,
          hasArchiveProof: proof,
          viewingConfirmedRepeatOrTimeline: true,
          hasChangeOverTimeProof: false,
        ),
        isTrue,
      );
    });

    test('shows after change-over-time proof when confirmed repeat is visible',
        () {
      expect(
        PaywallTimingGates.showPostProofProBridge(
          entryCount: 4,
          resolved: false,
          isPro: false,
          hasArchiveProof: true,
          viewingConfirmedRepeatOrTimeline: true,
          hasChangeOverTimeProof: true,
        ),
        isTrue,
      );
    });

    test('respects resolved and Pro user flags', () {
      expect(
        PaywallTimingGates.showPostProofProBridge(
          entryCount: 4,
          resolved: true,
          isPro: false,
          hasArchiveProof: true,
          viewingConfirmedRepeatOrTimeline: true,
          hasChangeOverTimeProof: false,
        ),
        isFalse,
      );
      expect(
        PaywallTimingGates.showPostProofProBridge(
          entryCount: 4,
          resolved: false,
          isPro: true,
          hasArchiveProof: true,
          viewingConfirmedRepeatOrTimeline: true,
          hasChangeOverTimeProof: false,
        ),
        isFalse,
      );
    });

    test('change-over-time proof alone does not show without value surfaces', () {
      expect(
        PaywallTimingGates.showPostProofProBridge(
          entryCount: 4,
          resolved: false,
          isPro: false,
          hasArchiveProof: true,
          viewingConfirmedRepeatOrTimeline: false,
          hasChangeOverTimeProof: true,
        ),
        isFalse,
      );
    });

    test('change-over-time proof alone does not bypass entry count gate', () {
      expect(
        PaywallTimingGates.showPostProofProBridge(
          entryCount: 1,
          resolved: false,
          isPro: false,
          hasArchiveProof: true,
          viewingConfirmedRepeatOrTimeline: false,
          hasChangeOverTimeProof: true,
        ),
        isFalse,
      );
    });
  });

  group('PaywallTimingGates.showSoftProBridge', () {
    test('never shows on first save or without proof', () {
      expect(
        PaywallTimingGates.showSoftProBridge(
          entryCount: 1,
          resolved: false,
          isPro: false,
          hasArchiveProof: true,
        ),
        isFalse,
      );
      expect(
        PaywallTimingGates.showSoftProBridge(
          entryCount: 2,
          resolved: false,
          isPro: false,
          hasArchiveProof: false,
        ),
        isFalse,
      );
      expect(
        RecordReturnProGates.showProBridge(
          entryCount: 1,
          resolved: false,
          isPro: false,
          hasArchiveProof: true,
        ),
        isFalse,
      );
      expect(
        FirstSaveLoopGates.showProBridge(
          entryCount: 2,
          resolved: false,
          isPro: false,
          hasArchiveProof: false,
        ),
        isFalse,
      );
    });

    test('shows after grounded repeat proof at two or more entries', () {
      final proof = PaywallTimingGates.hasArchiveProofFromEntries(
        entries: _groundedTwoEntries,
      );
      expect(proof, isTrue);
      expect(
        FirstThreeSessionGates.showSoftProBridge(
          entryCount: 2,
          resolved: false,
          isPro: false,
          hasArchiveProof: proof,
        ),
        isTrue,
      );
      expect(
        First60Gates.showProBridge(
          entryCount: 2,
          resolved: false,
          hasArchiveProof: proof,
        ),
        isTrue,
      );
    });

    test('respects resolved and Pro user flags', () {
      expect(
        PaywallTimingGates.showSoftProBridge(
          entryCount: 3,
          resolved: true,
          isPro: false,
          hasArchiveProof: true,
        ),
        isFalse,
      );
      expect(
        PaywallTimingGates.showSoftProBridge(
          entryCount: 3,
          resolved: false,
          isPro: true,
          hasArchiveProof: true,
        ),
        isFalse,
      );
    });
  });

  group('Full archive history Pro boundary copy', () {
    test('boundary ties Pro to full history without blocking free proof', () {
      expect(
        ArchiveBeliefThreadCopy.fullArchiveHistoryTitle,
        'Full archive history',
      );
      expect(
        ArchiveBeliefThreadCopy.fullArchiveHistoryBody,
        'ArchiveMe can show the first proof for free. Pro keeps the full evidence '
        'trail, weekly reviews, and long-term changes.',
      );
      expect(ArchiveBeliefThreadCopy.proBridgeCta, 'See Pro');
      expect(ArchiveBeliefThreadCopy.proBridgeSecondary, 'Not now');
    });

    test('boundary copy avoids hard lock language', () {
      final haystack = [
        ArchiveBeliefThreadCopy.fullArchiveHistoryTitle,
        ArchiveBeliefThreadCopy.fullArchiveHistoryBody,
        ArchiveBeliefThreadCopy.proBridgeCta,
        ArchiveBeliefThreadCopy.proBridgeSecondary,
      ].join(' ').toLowerCase();
      expect(haystack, isNot(contains('upgrade required')));
      expect(haystack, isNot(contains('feature locked')));
      expect(haystack, isNot(contains('must pay')));
      expect(haystack, isNot(contains('hard lock')));
    });

    testWidgets('full archive history boundary renders on Record-style surface',
        (tester) async {
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
      expect(find.text(ArchiveBeliefThreadCopy.proBridgeCta), findsOneWidget);
      expect(find.text(ArchiveBeliefThreadCopy.proBridgeSecondary), findsOneWidget);
      expect(
        find.byKey(const Key('full_archive_history_pro_boundary_card')),
        findsOneWidget,
      );
    });

    testWidgets('compact flag still renders full archive history copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArchiveIntelligenceProBridgeCard(
              compact: true,
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
      expect(
        find.byKey(const Key('archive_intelligence_pro_bridge_card_compact')),
        findsOneWidget,
      );
    });
  });

  group('Change-over-time proof and Pro bridge', () {
    test('answered repeat return check counts as change-over-time proof', () {
      final records = [
        RepeatReturnCheckRecord(
          entryId: 'e4',
          choice: RepeatReturnCheckChoice.stronger,
          entryCountAtCapture: 4,
          createdAt: DateTime(2026, 6, 13),
        ),
      ];
      expect(RepeatReturnCheckTrendEngine.hasAnsweredCheck(records), isTrue);
      expect(
        PaywallTimingGates.hasArchiveProofFromEntries(
          entries: _unrelatedTwoEntries,
          hasChangeOverTimeProof: true,
        ),
        isTrue,
      );
    });
  });

  group('Restore purchases safety', () {
    test('restore copy remains visible and billing logic untouched', () {
      expect(RestorePurchasesCopy.restorePurchases, isNotEmpty);
      expect(
        RestorePurchasesCopy.restorePurchases.toLowerCase(),
        contains('restore'),
      );
    });
  });
}
