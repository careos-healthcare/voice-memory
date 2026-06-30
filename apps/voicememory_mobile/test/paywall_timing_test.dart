import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/first_three_session_gates.dart';
import 'package:voicememory_mobile/features/activation/paywall_timing_gates.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_belief_thread_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/onboarding/first_60_second_state.dart';
import 'package:voicememory_mobile/features/onboarding/first_save_loop_state.dart';
import 'package:voicememory_mobile/features/onboarding/record_return_pro_state.dart';
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

  group('Post-proof bridge copy', () {
    test('strongest bridge uses evidence-first copy', () {
      expect(
        ArchiveBeliefThreadCopy.proKeepsThread,
        'ArchiveMe has enough evidence to show what keeps repeating.',
      );
      expect(
        ArchiveBeliefThreadCopy.proBridgeBody,
        'Pro keeps the full timeline and tracks how it changes.',
      );
    });

    testWidgets('archive intelligence bridge renders post-proof copy', (
      tester,
    ) async {
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
        find.text(
          'ArchiveMe has enough evidence to show what keeps repeating.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Pro keeps the full timeline and tracks how it changes.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('archive_intelligence_pro_bridge_card')),
          findsOneWidget);
    });
  });
}
