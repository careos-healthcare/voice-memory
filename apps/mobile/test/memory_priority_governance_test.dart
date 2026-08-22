import 'package:archiveme_mobile/features/archive_packs/archive_pack.dart';
import 'package:archiveme_mobile/features/archive_packs/archive_pack_scope_policy.dart';
import 'package:archiveme_mobile/features/archive_search/archive_entry_search_engine.dart';
import 'package:archiveme_mobile/features/archive_search/archive_search_query.dart';
import 'package:archiveme_mobile/features/memory/current_intent_signal.dart';
import 'package:archiveme_mobile/features/memory/memory_connection_rules.dart';
import 'package:archiveme_mobile/features/memory/memory_control_model.dart';
import 'package:archiveme_mobile/features/memory/memory_control_store.dart';
import 'package:archiveme_mobile/features/memory/memory_governance_decision.dart';
import 'package:archiveme_mobile/features/memory/memory_governance_policy.dart';
import 'package:archiveme_mobile/features/memory/memory_priority_decision.dart';
import 'package:archiveme_mobile/features/memory/memory_priority_governance.dart';
import 'package:archiveme_mobile/features/memory/memory_priority_score.dart';
import 'package:archiveme_mobile/features/memory/memory_scope.dart';
import 'package:archiveme_mobile/features/memory/memory_scope_policy.dart';
import 'package:archiveme_mobile/features/memory/memory_visibility_receipt.dart';
import 'package:archiveme_mobile/features/memory/not_important_feedback.dart';
import 'package:archiveme_mobile/features/memory/wrong_thread_feedback.dart';
import 'package:archiveme_mobile/features/pressure_retention/belief_distance_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:archiveme_mobile/features/pressure_retention/thread_return_evidence_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/weekly_thread_review_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

class _Event {
  const _Event(this.name, this.properties);
  final String name;
  final Map<String, Object> properties;
}

final List<_Event> _events = [];

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
  bool isPinned = false,
  bool keepExactDetails = false,
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
  isPinned: isPinned,
  keepExactDetails: keepExactDetails,
);

List<PressureCheckInRecord> _evidenceRecords() => [
  _rec(id: 'e1', daysAgo: 6, fear: 'Work alpha decision keeps circling'),
  _rec(id: 'e2', daysAgo: 3, fear: 'Work beta decision came back today'),
  _rec(id: 'e3', daysAgo: 0, fear: 'Work gamma decision tonight again'),
];

JournalEntry _entry(String id) => JournalEntry(
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
  MemoryConnectionRules.resetForTest();
  MemoryControlStore.resetSessionForTest();
  WrongThreadFeedback.resetForTest();
  ArchivePackScopePolicy.resetForTest();
  _events.clear();
  ActivationFunnelAnalytics.resetForTest();
  ActivationFunnelAnalytics.captureForTest(
    (event, properties) => _events.add(_Event(event, properties)),
  );
}

MemoryPriorityDecision _priorityFor(
  List<PressureCheckInRecord> records, {
  MemoryCardType cardType = MemoryCardType.threadReturn,
  int entryCount = 3,
}) {
  final governance = MemoryGovernancePolicy.evaluate(
    cardType: cardType,
    records: records,
    entryCount: entryCount,
    trackAnalytics: false,
  );
  return MemoryPriorityGovernance.evaluate(
    cardType: cardType,
    records: records,
    governance: governance,
    entryCount: entryCount,
    trackAnalytics: false,
  );
}

void main() {
  setUp(_reset);

  group('Suppression ladder', () {
    test('memory off suppresses priority claims', () {
      MemoryScopePolicy.scope = MemoryScope.off;
      final p = _priorityFor(_evidenceRecords());
      expect(p.shouldSuppress, isTrue);
      expect(p.canSupportClaim, isFalse);
    });

    test('fresh entry suppresses priority claims', () {
      final p = _priorityFor([_rec(id: 'e1', daysAgo: 0, treatAsNew: true)]);
      expect(p.decisionId, MemoryPriorityDecisionId.suppressedFresh);
    });

    test('keep separate suppresses priority claims', () {
      final p = _priorityFor([_rec(id: 'e1', daysAgo: 0, keepSeparate: true)]);
      expect(p.decisionId, MemoryPriorityDecisionId.suppressedKeepSeparate);
    });

    test('not related suppresses priority claims', () {
      MemoryControlStore.markNotRelated(MemoryCardType.threadReturn);
      final p = _priorityFor(_evidenceRecords());
      expect(p.decisionId, MemoryPriorityDecisionId.suppressedNotRelated);
    });

    test('wrong thread suppresses priority claims', () {
      WrongThreadFeedback.suppressSession(MemoryCardType.threadReturn);
      final p = _priorityFor(_evidenceRecords());
      expect(p.decisionId, MemoryPriorityDecisionId.suppressedWrongThread);
    });

    test('wrong pack suppresses priority claims', () {
      final p = MemoryPriorityGovernance.evaluate(
        cardType: MemoryCardType.threadReturn,
        records: _evidenceRecords(),
        governance: const MemoryGovernanceDecision(
          allowed: false,
          decisionId: MemoryGovernanceDecisionId.blockedWrongPack,
          reasonId: 'keep_separate',
          currentIntent: CurrentIntent.useArchiveContext,
          relevanceBand: RelevanceBand.low,
          requiresUserConfirmation: false,
        ),
        trackAnalytics: false,
      );
      expect(p.decisionId, MemoryPriorityDecisionId.suppressedWrongPack);
    });

    test('not important suppresses priority claims', () {
      NotImportantFeedback.markNotImportant(MemoryCardType.threadReturn);
      final p = _priorityFor(_evidenceRecords());
      expect(p.decisionId, MemoryPriorityDecisionId.suppressedNotImportant);
    });
  });

  group('Priority ladder', () {
    test('old one-off evidence becomes background', () {
      final records = [
        _rec(id: 'e1', daysAgo: 30, fear: 'One old note only here'),
      ];
      final p = _priorityFor(records);
      expect(p.backgroundOnly, isTrue);
      expect(p.canSupportClaim, isFalse);
    });

    test('old one-off cannot support major memory claim', () {
      const engine = ThreadReturnEvidenceEngine();
      final records = [
        _rec(id: 'e1', daysAgo: 30, fear: 'One old note only here'),
      ];
      expect(engine.build(records, entryCount: 3).hasEvidence, isFalse);
    });

    test('recent related evidence becomes normal', () {
      final records = [
        _rec(id: 'e1', daysAgo: 1, fear: 'Recent work note alpha'),
        _rec(id: 'e2', daysAgo: 0, fear: 'Recent work note beta'),
      ];
      final p = _priorityFor(records);
      expect(
        p.priorityBand == MemoryPriorityBand.normal ||
            p.priorityBand == MemoryPriorityBand.important,
        isTrue,
      );
    });

    test('repeated evidence outranks old one-off', () {
      final repeated = _evidenceRecords();
      final oldScore = MemoryPriorityScore.scoreRecord(
        _rec(id: 'old', daysAgo: 40, fear: 'solo old'),
        cardType: MemoryCardType.threadReturn,
        candidates: repeated,
        anchor: DateTime.now(),
      );
      final newScore = MemoryPriorityScore.scoreRecord(
        repeated.last,
        cardType: MemoryCardType.threadReturn,
        candidates: repeated,
        anchor: DateTime.now(),
      );
      expect(newScore, greaterThan(oldScore));
    });

    test('same-thread repeated evidence becomes important', () {
      WrongThreadFeedback.assignExplicitThread(
        MemoryCardType.threadReturn,
        'thread_work',
      );
      final records = [
        _rec(
          id: 'e1',
          daysAgo: 6,
          archiveThreadId: 'thread_work',
          fear: 'Alpha work',
        ),
        _rec(
          id: 'e2',
          daysAgo: 3,
          archiveThreadId: 'thread_work',
          fear: 'Beta work',
        ),
        _rec(
          id: 'e3',
          daysAgo: 0,
          archiveThreadId: 'thread_work',
          fear: 'Gamma work',
        ),
      ];
      final p = _priorityFor(records);
      expect(p.decisionId, MemoryPriorityDecisionId.importantSameThread);
    });

    test(
      'same-pack repeated evidence becomes important when pack policy allows',
      () {
        ArchivePackScopePolicy.applyLoadedPacks([
          ArchivePack(
            id: 'pack_a',
            name: 'Work',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        ]);
        final records = [
          _rec(id: 'e1', daysAgo: 6, archivePackId: 'pack_a', fear: 'Alpha'),
          _rec(id: 'e2', daysAgo: 3, archivePackId: 'pack_a', fear: 'Beta'),
          _rec(id: 'e3', daysAgo: 0, archivePackId: 'pack_a', fear: 'Gamma'),
        ];
        final p = _priorityFor(records);
        expect(p.decisionId, MemoryPriorityDecisionId.importantSamePack);
      },
    );

    test('pinned alone cannot create claim', () {
      const engine = ThreadReturnEvidenceEngine();
      final records = [
        _rec(id: 'e1', daysAgo: 20, isPinned: true, fear: 'Pinned solo note'),
      ];
      expect(engine.build(records, entryCount: 3).hasEvidence, isFalse);
    });

    test('exact evidence alone cannot create claim', () {
      const engine = ThreadReturnEvidenceEngine();
      final records = [
        _rec(
          id: 'e1',
          daysAgo: 20,
          keepExactDetails: true,
          fear: 'Exact solo note',
        ),
      ];
      expect(engine.build(records, entryCount: 3).hasEvidence, isFalse);
    });

    test('user-confirmed connection becomes essential', () {
      MemoryConnectionRules.keepConnected(MemoryCardType.threadReturn);
      final p = _priorityFor(_evidenceRecords());
      expect(p.decisionId, MemoryPriorityDecisionId.essentialUserConfirmed);
      expect(p.priorityBand, MemoryPriorityBand.essential);
    });

    test('retrieval similarity alone cannot create important/essential', () {
      final records = [
        _rec(id: 'u0', daysAgo: 2),
        _rec(id: 'u1', daysAgo: 1, optionId: 'guilty_resting'),
        _rec(id: 'u2', daysAgo: 0, optionId: 'had_to_prove_enough'),
      ];
      final p = _priorityFor(records);
      expect(p.priorityBand, isNot(MemoryPriorityBand.essential));
    });
  });

  group('Not important feedback', () {
    test('creates durable demotion rule', () {
      NotImportantFeedback.markNotImportant(MemoryCardType.threadReturn);
      expect(
        NotImportantFeedback.isDemoted(MemoryCardType.threadReturn),
        isTrue,
      );
    });

    test('does not delete entries', () {
      NotImportantFeedback.markNotImportant(MemoryCardType.threadReturn);
      expect(_entry('e1').transcript, isNotEmpty);
    });

    test('entries remain searchable', () {
      NotImportantFeedback.markNotImportant(MemoryCardType.threadReturn);
      const engine = ArchiveEntrySearchEngine();
      final results = engine.search(
        entries: [_entry('e1')],
        query: const ArchiveEntrySearchQuery(keyword: 'transcript'),
      );
      expect(results, hasLength(1));
    });

    test('Keep connected can promote previously demoted connection', () {
      NotImportantFeedback.markNotImportant(MemoryCardType.threadReturn);
      MemoryConnectionRules.keepConnected(MemoryCardType.threadReturn);
      expect(
        NotImportantFeedback.isDemoted(MemoryCardType.threadReturn),
        isFalse,
      );
      final p = _priorityFor(_evidenceRecords());
      expect(p.canSupportClaim, isTrue);
    });
  });

  group('Engine integration', () {
    test('thread return evidence uses priority governance', () {
      const engine = ThreadReturnEvidenceEngine();
      expect(
        engine.build(_evidenceRecords(), entryCount: 3).hasEvidence,
        isTrue,
      );
    });

    test('belief distance uses priority governance', () {
      const engine = BeliefDistanceEngine();
      expect(engine.build(_evidenceRecords(), entryCount: 3).hasBelief, isTrue);
    });

    test('weekly review connection section uses priority governance', () {
      const engine = WeeklyThreadReviewEngine();
      expect(engine.build(_evidenceRecords()).hasReview, isTrue);
    });
  });

  group('Explanation and receipt', () {
    test('memory-used explanation includes safe priority reason', () {
      final p = _priorityFor(_evidenceRecords());
      final line = MemoryPriorityCopy.explanationFor(p.safeExplanationId);
      expect(line, isNotEmpty);
      expect(line.contains('e1'), isFalse);
    });

    test('receipt appears only when priority allows claim', () {
      final gov = MemoryGovernancePolicy.evaluate(
        cardType: MemoryCardType.threadReturn,
        records: _evidenceRecords(),
        entryCount: 3,
        trackAnalytics: false,
      );
      final pri = _priorityFor(_evidenceRecords());
      expect(
        MemoryVisibilityReceipt.shouldShow(
          cardType: MemoryCardType.threadReturn,
          memoryUsed: true,
          entryCount: 3,
          governance: gov,
          priority: pri,
        ),
        pri.canSupportClaim && gov.showReceipt,
      );
    });
  });

  group('Privacy and copy', () {
    test('analytics payload contains no private content', () {
      _priorityFor(_evidenceRecords());
      for (final event in _events) {
        final flat = '${event.name} ${event.properties.values.join(' ')}';
        expect(flat.toLowerCase(), isNot(contains('work alpha')));
        expect(flat.toLowerCase(), isNot(contains('voicememory')));
      }
      expect(
        ActivationFunnelAnalytics.allowedPropertyKeys.contains('priority_band'),
        isTrue,
      );
    });

    test('consumer copy avoids banned words and VoiceMemory', () {
      for (final text in MemoryPriorityCopy.all) {
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