import 'package:archiveme_mobile/features/archive_packs/archive_pack.dart';
import 'package:archiveme_mobile/features/archive_packs/archive_pack_scope_policy.dart';
import 'package:archiveme_mobile/features/archive_packs/cross_pack_confirmation.dart';
import 'package:archiveme_mobile/features/archive_search/archive_entry_search_engine.dart';
import 'package:archiveme_mobile/features/archive_search/archive_search_query.dart';
import 'package:archiveme_mobile/features/memory/cross_thread_confirmation.dart';
import 'package:archiveme_mobile/features/memory/current_intent_signal.dart';
import 'package:archiveme_mobile/features/memory/entry_memory_mode.dart';
import 'package:archiveme_mobile/features/memory/memory_control_model.dart';
import 'package:archiveme_mobile/features/memory/memory_governance_decision.dart';
import 'package:archiveme_mobile/features/memory/memory_governance_policy.dart';
import 'package:archiveme_mobile/features/memory/memory_priority_governance.dart';
import 'package:archiveme_mobile/features/memory/memory_reliability_check.dart';
import 'package:archiveme_mobile/features/memory/memory_scope.dart';
import 'package:archiveme_mobile/features/memory/memory_scope_policy.dart';
import 'package:archiveme_mobile/features/memory/memory_visibility_receipt.dart';
import 'package:archiveme_mobile/features/memory/wrong_thread_feedback.dart';
import 'package:archiveme_mobile/features/pressure_retention/belief_distance_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:archiveme_mobile/features/pressure_retention/thread_return_evidence_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/weekly_thread_review_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/memory/memory_governance_notice.dart';
import 'package:archiveme_mobile/widgets/pressure_retention/thread_return_evidence_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Event {
  const _Event(this.name, this.properties);
  final String name;
  final Map<String, Object> properties;
}

final List<_Event> _events = [];

const _threadEngine = ThreadReturnEvidenceEngine();
const _beliefEngine = BeliefDistanceEngine();
const _weeklyEngine = WeeklyThreadReviewEngine();

PressureCheckInRecord _rec({
  required String id,
  required int daysAgo,
  List<String> contexts = const ['work'],
  String? fear,
  String? archiveThreadId,
  String? archivePackId,
  bool treatAsNew = false,
  bool keepSeparate = false,
  bool connectionApproved = false,
  String optionId = 'could_not_stop',
}) => PressureCheckInRecord(
  entryId: id,
  createdAt: DateTime.now().subtract(Duration(days: daysAgo, hours: 1)),
  optionId: optionId,
  contextIds: contexts,
  fear: fear,
  archiveThreadId: archiveThreadId,
  archivePackId: archivePackId,
  treatAsNew: treatAsNew,
  keepSeparate: keepSeparate,
  connectionApproved: connectionApproved,
);

List<PressureCheckInRecord> _evidenceRecords() => [
  _rec(id: 'e1', daysAgo: 6, fear: 'I keep circling the same work decision'),
  _rec(id: 'e2', daysAgo: 3, fear: 'The same work decision came back today'),
  _rec(id: 'e3', daysAgo: 0, fear: 'Circling the same work decision tonight'),
];

JournalEntry _entry(
  String id, {
  bool treatAsNew = false,
  bool keepSeparate = false,
}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 11),
  transcript: 'A long enough transcript for archive search tests here.',
  durationSeconds: 20,
  reflection: const Reflection(
    mood: 'thoughtful',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: 'pattern',
    concreteObservation: 'Observation text.',
    repeatedSignal: 'signal',
  ),
  treatAsNew: treatAsNew,
  keepSeparate: keepSeparate,
);

const _bannedWords = [
  'always',
  'never',
  'proves',
  'definitely',
  'diagnosis',
  'diagnose',
  'therapy',
  'treatment',
  'fixed',
  'broken',
  'problem',
  'failure',
  'lazy',
  'weak',
  'must',
  'should',
  'surveillance',
  'spying',
  'tracking',
  'VoiceMemory',
];

void _reset() {
  MemoryScopePolicy.resetForTest();
  MemoryGovernancePolicy.resetForTest();
  MemoryPriorityGovernance.resetForTest();
  WrongThreadFeedback.resetForTest();
  CrossThreadConfirmation.resetForTest();
  CrossPackConfirmation.resetForTest();
  ArchivePackScopePolicy.resetForTest();
  _events.clear();
  ActivationFunnelAnalytics.resetForTest();
  ActivationFunnelAnalytics.captureForTest(
    (event, properties) => _events.add(_Event(event, properties)),
  );
}

void main() {
  setUp(_reset);

  group('Governance blocks', () {
    test('memory off blocks governance', () {
      MemoryScopePolicy.scope = MemoryScope.off;
      final decision = MemoryGovernancePolicy.evaluate(
        cardType: MemoryCardType.threadReturn,
        records: _evidenceRecords(),
        entryCount: 3,
        trackAnalytics: false,
      );
      expect(decision.allowed, isFalse);
      expect(decision.decisionId, MemoryGovernanceDecisionId.blockedMemoryOff);
    });

    test('first save blocks memory claims', () {
      final decision = MemoryGovernancePolicy.evaluate(
        cardType: MemoryCardType.threadReturn,
        records: _evidenceRecords(),
        entryCount: 1,
        trackAnalytics: false,
      );
      expect(decision.allowed, isFalse);
      expect(decision.decisionId, MemoryGovernanceDecisionId.blockedFirstSave);
      expect(
        _threadEngine.build(_evidenceRecords(), entryCount: 1).hasEvidence,
        isFalse,
      );
    });

    test('treat-as-new blocks memory claims', () {
      final records = [
        _rec(id: 'e1', daysAgo: 2, treatAsNew: true),
        _rec(id: 'e2', daysAgo: 1),
        _rec(id: 'e3', daysAgo: 0),
      ];
      final decision = MemoryGovernancePolicy.evaluate(
        cardType: MemoryCardType.threadReturn,
        records: records,
        entryCount: 3,
        trackAnalytics: false,
      );
      expect(decision.decisionId, MemoryGovernanceDecisionId.blockedFreshEntry);
    });

    test('keep separate blocks memory claims', () {
      final records = [
        _rec(id: 'e1', daysAgo: 2, keepSeparate: true),
        _rec(id: 'e2', daysAgo: 1),
        _rec(id: 'e3', daysAgo: 0),
      ];
      final decision = MemoryGovernancePolicy.evaluate(
        cardType: MemoryCardType.threadReturn,
        records: records,
        entryCount: 3,
        trackAnalytics: false,
      );
      expect(
        decision.decisionId,
        MemoryGovernanceDecisionId.blockedKeepSeparate,
      );
    });

    test('wrong-thread rule blocks memory claim', () {
      WrongThreadFeedback.markWrongPair(
        MemoryCardType.threadReturn,
        'thread_a',
      );
      WrongThreadFeedback.assignExplicitThread(
        MemoryCardType.threadReturn,
        'thread_a',
      );
      final records = [
        _rec(id: 'e1', daysAgo: 5, archiveThreadId: 'thread_a'),
        _rec(id: 'e2', daysAgo: 3, archiveThreadId: 'thread_b'),
        _rec(id: 'e3', daysAgo: 0, archiveThreadId: 'thread_a'),
      ];
      final decision = MemoryGovernancePolicy.evaluate(
        cardType: MemoryCardType.threadReturn,
        records: records,
        entryCount: 3,
        trackAnalytics: false,
      );
      expect(decision.allowed, isFalse);
    });

    test('wrong-pack rule blocks memory claim', () {
      CrossPackConfirmation.keepSeparate('thread_return');
      final decision = MemoryGovernancePolicy.evaluate(
        cardType: MemoryCardType.threadReturn,
        records: _evidenceRecords(),
        entryCount: 3,
        trackAnalytics: false,
      );
      expect(decision.decisionId, MemoryGovernanceDecisionId.blockedWrongPack);
    });
  });

  group('Governance allows and confirms', () {
    test('same explicit thread can pass when retrieval and authority pass', () {
      WrongThreadFeedback.assignExplicitThread(
        MemoryCardType.threadReturn,
        'thread_work',
      );
      final records = [
        _rec(
          id: 'e1',
          daysAgo: 6,
          archiveThreadId: 'thread_work',
          fear: 'Work alpha decision',
        ),
        _rec(
          id: 'e2',
          daysAgo: 3,
          archiveThreadId: 'thread_work',
          fear: 'Work beta decision',
        ),
        _rec(
          id: 'e3',
          daysAgo: 0,
          archiveThreadId: 'thread_work',
          fear: 'Work gamma decision',
        ),
      ];
      final decision = MemoryGovernancePolicy.evaluate(
        cardType: MemoryCardType.threadReturn,
        records: records,
        entryCount: 3,
        trackAnalytics: false,
      );
      expect(decision.allowed, isTrue);
    });

    test('same pack can pass when pack policy allows and retrieval passes', () {
      ArchivePackScopePolicy.applyLoadedPacks([
        ArchivePack(
          id: 'pack_a',
          name: 'Work',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ]);
      final records = [
        _rec(id: 'e1', daysAgo: 6, archivePackId: 'pack_a', fear: 'Alpha work'),
        _rec(id: 'e2', daysAgo: 3, archivePackId: 'pack_a', fear: 'Beta work'),
        _rec(id: 'e3', daysAgo: 0, archivePackId: 'pack_a', fear: 'Gamma work'),
      ];
      final decision = MemoryGovernancePolicy.evaluate(
        cardType: MemoryCardType.threadReturn,
        records: records,
        entryCount: 3,
        trackAnalytics: false,
      );
      expect(decision.allowed, isTrue);
      expect(decision.decisionId, MemoryGovernanceDecisionId.allowedSamePack);
    });

    test('cross-thread requires confirmation before claim', () {
      final records = [
        _rec(id: 'e1', daysAgo: 6, archiveThreadId: 't_a', fear: 'Alpha work'),
        _rec(id: 'e2', daysAgo: 3, archiveThreadId: 't_b', fear: 'Beta novel'),
        _rec(id: 'e3', daysAgo: 0, archiveThreadId: 't_a', fear: 'Gamma work'),
      ];
      final decision = MemoryGovernancePolicy.evaluate(
        cardType: MemoryCardType.threadReturn,
        records: records,
        entryCount: 3,
        trackAnalytics: false,
      );
      expect(decision.requiresUserConfirmation, isTrue);
      expect(
        decision.decisionId,
        MemoryGovernanceDecisionId.confirmCrossThread,
      );
    });

    test('cross-pack requires confirmation before claim', () {
      ArchivePackScopePolicy.applyLoadedPacks([
        ArchivePack(
          id: 'pack_a',
          name: 'A',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
        ArchivePack(
          id: 'pack_b',
          name: 'B',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ]);
      final records = [
        _rec(id: 'e1', daysAgo: 6, archivePackId: 'pack_a', fear: 'Alpha work'),
        _rec(id: 'e2', daysAgo: 3, archivePackId: 'pack_b', fear: 'Beta novel'),
        _rec(id: 'e3', daysAgo: 0, archivePackId: 'pack_a', fear: 'Gamma work'),
      ];
      final decision = MemoryGovernancePolicy.evaluate(
        cardType: MemoryCardType.threadReturn,
        records: records,
        entryCount: 3,
        trackAnalytics: false,
      );
      expect(decision.requiresUserConfirmation, isTrue);
      expect(decision.decisionId, MemoryGovernanceDecisionId.confirmCrossPack);
    });

    test('Connect allows cross-thread after confirmation', () {
      CrossThreadConfirmation.approve(MemoryCardType.threadReturn);
      final records = [
        _rec(id: 'e1', daysAgo: 6, archiveThreadId: 't_a', fear: 'Alpha work'),
        _rec(id: 'e2', daysAgo: 3, archiveThreadId: 't_b', fear: 'Beta novel'),
        _rec(id: 'e3', daysAgo: 0, archiveThreadId: 't_a', fear: 'Gamma work'),
      ];
      final decision = MemoryGovernancePolicy.evaluate(
        cardType: MemoryCardType.threadReturn,
        records: records,
        entryCount: 3,
        trackAnalytics: false,
      );
      expect(decision.allowed, isTrue);
    });

    test('user-confirmed evidence passes unless memory is off', () {
      final records = [
        _rec(id: 'e1', daysAgo: 6, connectionApproved: true, fear: 'Alpha'),
        _rec(id: 'e2', daysAgo: 3, fear: 'Beta'),
        _rec(id: 'e3', daysAgo: 0, fear: 'Gamma'),
      ];
      final decision = MemoryGovernancePolicy.evaluate(
        cardType: MemoryCardType.threadReturn,
        records: records,
        entryCount: 3,
        trackAnalytics: false,
      );
      expect(
        decision.decisionId,
        MemoryGovernanceDecisionId.allowedUserConfirmed,
      );
    });

    test('user-confirmed does not pass when memory is off', () {
      MemoryScopePolicy.scope = MemoryScope.off;
      final records = [_rec(id: 'e1', daysAgo: 6, connectionApproved: true)];
      final decision = MemoryGovernancePolicy.evaluate(
        cardType: MemoryCardType.threadReturn,
        records: records,
        entryCount: 3,
        trackAnalytics: false,
      );
      expect(decision.decisionId, MemoryGovernanceDecisionId.blockedMemoryOff);
    });
  });

  group('Relevance gate', () {
    test('low relevance blocks major memory claim', () {
      final decision = MemoryGovernancePolicy.evaluate(
        cardType: MemoryCardType.threadReturn,
        records: [_rec(id: 'e1', daysAgo: 0)],
        entryCount: 3,
        trackAnalytics: false,
      );
      expect(
        decision.decisionId == MemoryGovernanceDecisionId.blockedLowRelevance ||
            decision.relevanceBand == RelevanceBand.low,
        isTrue,
      );
    });

    test('high relevance still requires authority framing', () {
      final records = _evidenceRecords();
      final decision = MemoryGovernancePolicy.evaluate(
        cardType: MemoryCardType.threadReturn,
        records: records,
        entryCount: 3,
        trackAnalytics: false,
      );
      expect(decision.reliability, isNotNull);
      if (decision.allowed) {
        expect(decision.reliability!.framing!.allowsConnectionClaims, isTrue);
      }
    });

    test('repeated language alone cannot cross explicit thread boundaries', () {
      final records = [
        _rec(
          id: 'e1',
          daysAgo: 5,
          archiveThreadId: 'thread_a',
          fear: 'exact same words here',
        ),
        _rec(
          id: 'e2',
          daysAgo: 3,
          archiveThreadId: 'thread_b',
          fear: 'exact same words here',
        ),
        _rec(
          id: 'e3',
          daysAgo: 0,
          archiveThreadId: 'thread_a',
          fear: 'exact same words here',
        ),
      ];
      final reliability = MemoryReliabilityCheck.classify(
        cardType: MemoryCardType.threadReturn,
        records: records,
      );
      expect(reliability.state, isNot(MemoryReliabilityState.enoughEvidence));
    });

    test('repeated language alone cannot cross explicit pack boundaries', () {
      ArchivePackScopePolicy.applyLoadedPacks([
        ArchivePack(
          id: 'pack_a',
          name: 'A',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
        ArchivePack(
          id: 'pack_b',
          name: 'B',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ]);
      final records = [
        _rec(
          id: 'e1',
          daysAgo: 5,
          archivePackId: 'pack_a',
          fear: 'same phrase',
        ),
        _rec(
          id: 'e2',
          daysAgo: 3,
          archivePackId: 'pack_b',
          fear: 'same phrase',
        ),
        _rec(
          id: 'e3',
          daysAgo: 0,
          archivePackId: 'pack_a',
          fear: 'same phrase',
        ),
      ];
      final decision = MemoryGovernancePolicy.evaluate(
        cardType: MemoryCardType.threadReturn,
        records: records,
        entryCount: 3,
        trackAnalytics: false,
      );
      expect(decision.allowsMemoryClaim, isFalse);
    });

    test('retrieval similarity alone cannot bypass governance', () {
      final records = [
        _rec(id: 'u0', daysAgo: 2, contexts: const []),
        _rec(
          id: 'u1',
          daysAgo: 1,
          optionId: 'guilty_resting',
          contexts: const [],
        ),
        _rec(
          id: 'u2',
          daysAgo: 0,
          optionId: 'had_to_prove_enough',
          contexts: const [],
        ),
      ];
      final decision = MemoryGovernancePolicy.evaluate(
        cardType: MemoryCardType.threadReturn,
        records: records,
        entryCount: 3,
        trackAnalytics: false,
      );
      expect(decision.allowsMemoryClaim, isFalse);
    });
  });

  group('Current intent signal', () {
    test('classifies first save', () {
      expect(
        CurrentIntentSignal.classify(
          cardType: MemoryCardType.threadReturn,
          records: const [],
          entryCount: 1,
        ),
        CurrentIntent.firstSave,
      );
    });

    test('classifies keep separate', () {
      expect(
        CurrentIntentSignal.classify(
          cardType: MemoryCardType.threadReturn,
          records: [_rec(id: 'e1', daysAgo: 0, keepSeparate: true)],
          entryCount: 3,
        ),
        CurrentIntent.keepSeparate,
      );
    });

    test('classifies use archive context', () {
      EntryMemoryModeSession.select(EntryMemoryMode.useArchiveContext);
      expect(
        CurrentIntentSignal.classify(
          cardType: MemoryCardType.threadReturn,
          records: _evidenceRecords(),
          entryCount: 3,
        ),
        CurrentIntent.useArchiveContext,
      );
    });
  });

  group('Visible receipt integration', () {
    test('receipt appears only when governance allowed memory use', () {
      final records = _evidenceRecords();
      final decision = MemoryGovernancePolicy.evaluate(
        cardType: MemoryCardType.threadReturn,
        records: records,
        entryCount: 3,
        trackAnalytics: false,
      );
      expect(
        MemoryVisibilityReceipt.shouldShow(
          cardType: MemoryCardType.threadReturn,
          memoryUsed: true,
          entryCount: 3,
          governance: decision,
        ),
        decision.showReceipt,
      );
    });

    test('receipt does not appear when governance blocked memory', () {
      final decision = MemoryGovernancePolicy.evaluate(
        cardType: MemoryCardType.threadReturn,
        records: _evidenceRecords(),
        entryCount: 1,
        trackAnalytics: false,
      );
      expect(
        MemoryVisibilityReceipt.shouldShow(
          cardType: MemoryCardType.threadReturn,
          memoryUsed: true,
          entryCount: 1,
          governance: decision,
        ),
        isFalse,
      );
    });
  });

  group('Engine integration', () {
    test('thread return evidence uses governance', () {
      expect(
        _threadEngine.build(_evidenceRecords(), entryCount: 3).hasEvidence,
        isTrue,
      );
      expect(
        _threadEngine.build(_evidenceRecords(), entryCount: 1).hasEvidence,
        isFalse,
      );
    });

    test('belief distance uses governance', () {
      expect(
        _beliefEngine.build(_evidenceRecords(), entryCount: 3).hasBelief,
        isTrue,
      );
    });

    test('weekly review connection section uses governance', () {
      final review = _weeklyEngine.build(_evidenceRecords());
      expect(review.hasReview, isTrue);
    });
  });

  group('Archive search unaffected', () {
    test('archive search remains unaffected by governance blocking claims', () {
      MemoryScopePolicy.scope = MemoryScope.off;
      const engine = ArchiveEntrySearchEngine();
      final entries = [_entry('e1'), _entry('e2', treatAsNew: true)];
      final results = engine.search(
        entries: entries,
        query: const ArchiveEntrySearchQuery(keyword: 'transcript'),
      );
      expect(results, hasLength(2));
    });

    test('fresh/blocked entries remain searchable', () {
      const engine = ArchiveEntrySearchEngine();
      final results = engine.search(
        entries: [_entry('e1', keepSeparate: true)],
        query: const ArchiveEntrySearchQuery(keyword: 'transcript'),
      );
      expect(results, hasLength(1));
    });
  });

  group('UI widgets', () {
    testWidgets('thread return card shows receipt when governance allows', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final evidence = _threadEngine.build(_evidenceRecords(), entryCount: 3);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ThreadReturnEvidenceCard(evidence: evidence),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('memory_used_receipt')), findsOneWidget);
    });
  });

  group('Privacy and copy', () {
    test('analytics payload contains no private content', () {
      MemoryGovernancePolicy.evaluate(
        cardType: MemoryCardType.threadReturn,
        records: _evidenceRecords(),
        entryCount: 3,
      );
      for (final event in _events) {
        final flat = '${event.name} ${event.properties.values.join(' ')}';
        expect(flat.toLowerCase(), isNot(contains('work decision')));
        expect(flat.toLowerCase(), isNot(contains('voicememory')));
      }
      expect(
        ActivationFunnelAnalytics.allowedPropertyKeys.containsAll({
          'decision_id',
          'current_intent',
          'relevance_band',
        }),
        isTrue,
      );
    });

    test('consumer copy avoids banned words and VoiceMemory', () {
      for (final text in MemoryGovernanceCopy.all) {
        for (final banned in _bannedWords) {
          expect(
            text.toLowerCase().contains(banned.toLowerCase()),
            isFalse,
            reason: '$banned in "$text"',
          );
        }
      }
    });
  });
}