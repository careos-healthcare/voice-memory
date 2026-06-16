import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/memory/archive_retrieval_engine.dart';
import 'package:voicememory_mobile/features/memory/archive_retrieval_policy.dart';
import 'package:voicememory_mobile/features/memory/archive_retrieval_score.dart';
import 'package:voicememory_mobile/features/memory/memory_scope.dart';
import 'package:voicememory_mobile/features/memory/memory_scope_policy.dart';
import 'package:voicememory_mobile/features/pressure_retention/belief_distance_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/features/pressure_retention/thread_return_evidence_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/weekly_thread_review_engine.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';

const _engine = ArchiveRetrievalEngine();
const _threadEngine = ThreadReturnEvidenceEngine();
const _beliefEngine = BeliefDistanceEngine();
const _weeklyEngine = WeeklyThreadReviewEngine();

final DateTime _base = DateTime(2026, 6, 9, 12);

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
  String optionId = 'could_not_stop',
  String? fear,
  bool treatAsNew = false,
  bool connectionApproved = false,
}) => PressureCheckInRecord(
  entryId: id,
  createdAt: _base.subtract(Duration(days: daysAgo, hours: 1)),
  optionId: optionId,
  contextIds: contexts,
  fear: fear,
  treatAsNew: treatAsNew,
  connectionApproved: connectionApproved,
);

/// Engine-grade evidence: a work thread with repeated language across days.
List<PressureCheckInRecord> _evidenceRecords({
  bool treatAsNew = false,
  bool connectionApproved = false,
}) => [
  _rec(
    id: 'e1',
    daysAgo: 6,
    fear: 'I keep circling one hard work decision',
    treatAsNew: treatAsNew,
    connectionApproved: connectionApproved,
  ),
  _rec(
    id: 'e2',
    daysAgo: 3,
    fear: 'One hard work decision came back tonight',
    treatAsNew: treatAsNew,
    connectionApproved: connectionApproved,
  ),
  _rec(
    id: 'e3',
    daysAgo: 0,
    fear: 'Circling one hard work decision at my desk',
    treatAsNew: treatAsNew,
    connectionApproved: connectionApproved,
  ),
];

/// Recent entries with no overlap at all: different options, no contexts,
/// no notes — weak retrieval at best.
List<PressureCheckInRecord> _unrelatedRecords() => [
  _rec(id: 'u1', daysAgo: 2, contexts: const [], optionId: 'could_not_stop'),
  _rec(id: 'u2', daysAgo: 1, contexts: const [], optionId: 'guilty_resting'),
  _rec(
    id: 'u3',
    daysAgo: 0,
    contexts: const [],
    optionId: 'had_to_prove_enough',
  ),
];

ArchiveRetrievalResult _retrieve(List<PressureCheckInRecord> records) =>
    ArchiveRetrievalPolicy.retrieve(
      records,
      now: _base,
      cardType: 'thread_return',
    );

List<PressureCheckInRecord> _candidates(List<PressureCheckInRecord> records) =>
    ArchiveRetrievalPolicy.connectionCandidates(
      records,
      now: _base,
      cardType: 'thread_return',
    );

void main() {
  setUp(() {
    MemoryScopePolicy.resetForTest();
    ArchiveRetrievalPolicy.resetSessionForTest();
    ActivationFunnelAnalytics.resetForTest();
    _events.clear();
    ActivationFunnelAnalytics.captureForTest(
      (name, properties) => _events.add(_Event(name, properties)),
    );
  });

  tearDown(ActivationFunnelAnalytics.resetForTest);

  group('Archive retrieval — memory scope integration', () {
    test('memory off returns empty retrieval results', () {
      MemoryScopePolicy.scope = MemoryScope.off;

      final result = _retrieve(_evidenceRecords());
      expect(result.isEmpty, isTrue);
      expect(result.band, ArchiveRetrievalBand.none);
      expect(_candidates(_evidenceRecords()), isEmpty);
      expect(
        _threadEngine.build(_evidenceRecords(), now: _base).hasEvidence,
        isFalse,
      );
    });

    test('treat-as-new entries are excluded', () {
      final records = [
        ..._evidenceRecords(),
        _rec(
          id: 'fresh',
          daysAgo: 0,
          fear: 'Circling one hard work decision again',
          treatAsNew: true,
        ),
      ];
      final ids = _candidates(records).map((r) => r.entryId);
      expect(ids, isNot(contains('fresh')));
      expect(ids, containsAll(['e1', 'e2', 'e3']));
    });

    test('ask mode excludes unapproved entries', () {
      MemoryScopePolicy.scope = MemoryScope.ask;
      expect(_candidates(_evidenceRecords()), isEmpty);
      expect(_retrieve(_evidenceRecords()).isEmpty, isTrue);
    });

    test('ask mode includes approved entries', () {
      MemoryScopePolicy.scope = MemoryScope.ask;
      final approved = _evidenceRecords(connectionApproved: true);
      expect(
        _candidates(approved).map((r) => r.entryId),
        containsAll(['e1', 'e2', 'e3']),
      );
    });

    test('threadOnly mode requires explicit shared context marker', () {
      MemoryScopePolicy.scope = MemoryScope.threadOnly;

      // Repeated language but no shared explicit context marker.
      final unmarked = [
        _rec(
          id: 'm1',
          daysAgo: 3,
          contexts: const ['home'],
          fear: 'I keep circling one hard work decision',
        ),
        _rec(
          id: 'm2',
          daysAgo: 0,
          contexts: const ['evening'],
          fear: 'One hard work decision came back',
        ),
      ];
      expect(_candidates(unmarked), isEmpty);

      // The same entries with a shared explicit marker are retrievable.
      expect(_candidates(_evidenceRecords()), isNotEmpty);
    });

    test('retrieval never overrides scope: off beats high relevance', () {
      MemoryScopePolicy.scope = MemoryScope.off;
      final result = _retrieve(_evidenceRecords());
      expect(result.supportsConnectionClaims, isFalse);
    });
  });

  group('Archive retrieval — scoring and decay', () {
    test('recent related entries outrank stale entries', () {
      final records = [
        _rec(id: 'stale', daysAgo: 40, fear: 'One hard work decision'),
        _rec(id: 'recent', daysAgo: 0, fear: 'One hard work decision'),
        _rec(id: 'mid', daysAgo: 5, fear: 'One hard work decision'),
      ];
      final ordered = _retrieve(
        records,
      ).scores.map((s) => s.record.entryId).toList();
      expect(ordered.first, 'recent');
      expect(ordered.last, 'stale');
    });

    test('same-day entries score the strongest recency tier', () {
      final result = _retrieve(_evidenceRecords());
      final byId = {for (final s in result.scores) s.record.entryId: s};
      expect(byId['e3']!.recencyPoints, greaterThan(byId['e2']!.recencyPoints));
      expect(byId['e2']!.recencyPoints, greaterThan(0));
    });

    test('stale entries decay unless relevance is strong', () {
      // 31+ days old, related only through repeated words: stays weak.
      final wordsOnly = [
        _rec(
          id: 'old1',
          daysAgo: 40,
          contexts: const [],
          optionId: 'could_not_stop',
          fear: 'One hard work decision',
        ),
        _rec(
          id: 'old2',
          daysAgo: 35,
          contexts: const [],
          optionId: 'guilty_resting',
          fear: 'One hard work decision again',
        ),
      ];
      final weakResult = _retrieve(wordsOnly);
      for (final score in weakResult.scores) {
        expect(score.band, ArchiveRetrievalBand.weak);
      }
      expect(weakResult.supportsConnectionClaims, isFalse);

      // The same age with a shared explicit context marker on top stays
      // retrievable: old entries are weaker, not impossible.
      final strongRelevance = [
        _rec(id: 'old3', daysAgo: 40, fear: 'One hard work decision'),
        _rec(id: 'old4', daysAgo: 35, fear: 'One hard work decision again'),
      ];
      final strongResult = _retrieve(strongRelevance);
      expect(strongResult.band, ArchiveRetrievalBand.possible);
    });

    test('top results are capped at 5', () {
      final records = [
        for (var i = 0; i < 8; i++)
          _rec(id: 'r$i', daysAgo: i, fear: 'One hard work decision'),
      ];
      final result = _retrieve(records);
      expect(result.scores.length, ArchiveRetrievalEngine.defaultMaxRecords);
      expect(result.scores.length, 5);
      expect(_candidates(records).length, 5);
    });

    test('useful feedback raises a record, not quite lowers it', () {
      final records = [
        _rec(id: 'a', daysAgo: 2, fear: 'One hard work decision'),
        _rec(id: 'b', daysAgo: 2, fear: 'One hard work decision again'),
      ];

      ArchiveRetrievalPolicy.markRecordUseful('a');
      ArchiveRetrievalPolicy.markRecordNotQuite('b');

      final byId = {
        for (final s in _retrieve(records).scores) s.record.entryId: s,
      };
      expect(byId['a']!.usagePoints, greaterThan(0));
      expect(byId['b']!.usagePoints, lessThan(0));
      expect(byId['a']!.total, greaterThan(byId['b']!.total));
    });
  });

  group('Archive retrieval — claim gating', () {
    test('weak-only results do not trigger major memory claims', () {
      final unrelated = _unrelatedRecords();
      final result = _retrieve(unrelated);
      expect(result.band, ArchiveRetrievalBand.weak);
      expect(result.supportsConnectionClaims, isFalse);
      expect(_candidates(unrelated), isEmpty);
      expect(_threadEngine.build(unrelated, now: _base).hasEvidence, isFalse);
      expect(_beliefEngine.build(unrelated).hasBelief, isFalse);
    });

    test('possible results support the existing engines', () {
      final records = _evidenceRecords();
      expect(_retrieve(records).band, ArchiveRetrievalBand.possible);
      expect(_threadEngine.build(records, now: _base).hasEvidence, isTrue);
      expect(_beliefEngine.build(records).hasBelief, isTrue);
      expect(_weeklyEngine.build(records, now: _base).hasReview, isTrue);
    });

    test('retrieval score alone never creates a strong claim', () {
      final result = _retrieve(_evidenceRecords());
      // The engine band is capped below strong no matter the score.
      expect(result.band, ArchiveRetrievalBand.possible);
      expect(
        result.bandWithEvidence(hasEvidenceSupport: false),
        ArchiveRetrievalBand.possible,
      );
      // Strong needs the existing evidence engine to hold the claim too.
      expect(
        result.bandWithEvidence(hasEvidenceSupport: true),
        ArchiveRetrievalBand.strong,
      );
    });

    test('weekly counting still works without a connected thread', () {
      // Counting this week's own entries is not a connection claim, so
      // weak-only retrieval does not erase the weekly review itself.
      final review = _weeklyEngine.build(_unrelatedRecords(), now: _base);
      expect(review.hasReview, isTrue);
      expect(review.evidenceLine, 'You added 3 pieces of evidence.');
      expect(review.returnedLine, isEmpty);
      expect(review.fadedLine, isEmpty);
      expect(review.changedLine, isEmpty);
    });

    test('Not related suppresses the specific record for the session', () {
      final records = _evidenceRecords();
      expect(_candidates(records).map((r) => r.entryId), contains('e2'));

      ArchiveRetrievalPolicy.markRecordNotRelated('e2');
      expect(_candidates(records).map((r) => r.entryId), isNot(contains('e2')));

      // The record itself is untouched and returns next session.
      ArchiveRetrievalPolicy.resetSessionForTest();
      expect(_candidates(records).map((r) => r.entryId), contains('e2'));
    });
  });

  group('Archive retrieval — analytics privacy', () {
    test('events fire with band, count, card type, and scope only', () {
      _retrieve(_evidenceRecords());

      final scored = _events
          .where((e) => e.name == 'archive_retrieval_scored')
          .toList();
      final used = _events
          .where((e) => e.name == 'archive_retrieval_used')
          .toList();
      expect(scored, hasLength(1));
      expect(used, hasLength(1));
      expect(scored.first.properties['score_band'], 'possible');
      expect(scored.first.properties['record_count'], 3);
      expect(scored.first.properties['card_type'], 'thread_return');
      expect(scored.first.properties['memory_scope'], 'automatic');
    });

    test('empty retrieval fires archive_retrieval_empty', () {
      MemoryScopePolicy.scope = MemoryScope.off;
      _retrieve(_evidenceRecords());

      final empty = _events
          .where((e) => e.name == 'archive_retrieval_empty')
          .toList();
      expect(empty, hasLength(1));
      expect(empty.first.properties['score_band'], 'none');
      expect(empty.first.properties['record_count'], 0);
      expect(_events.where((e) => e.name == 'archive_retrieval_used'), isEmpty);
    });

    test('analytics payload has no raw content', () {
      _retrieve(_evidenceRecords());
      _retrieve(_unrelatedRecords());

      expect(_events, isNotEmpty);
      for (final event in _events) {
        for (final key in event.properties.keys) {
          expect(
            ActivationFunnelAnalytics.allowedPropertyKeys,
            contains(key),
            reason: '$key is not a whitelisted property',
          );
        }
        for (final value in event.properties.values) {
          expect(value is int || value is String, isTrue);
          if (value is String) {
            expect(
              RegExp(r'^[a-z0-9_]{1,40}$').hasMatch(value),
              isTrue,
              reason: '"$value" is not a stable id',
            );
            expect(value.toLowerCase(), isNot(contains('decision')));
            expect(value.toLowerCase(), isNot(contains('circling')));
          }
        }
      }
    });

    test('repeat engine builds do not spam events in one session', () {
      _retrieve(_evidenceRecords());
      _retrieve(_evidenceRecords());
      _retrieve(_evidenceRecords());

      expect(
        _events.where((e) => e.name == 'archive_retrieval_scored'),
        hasLength(1),
      );
      expect(
        _events.where((e) => e.name == 'archive_retrieval_used'),
        hasLength(1),
      );
    });
  });

  group('Archive retrieval — copy guardrails', () {
    const allCopy = [
      ArchiveRetrievalCopy.whyRecentLine,
      ArchiveRetrievalCopy.whyOlderLine,
    ];

    test('no VoiceMemory in consumer-facing copy', () {
      for (final line in allCopy) {
        expect(line.toLowerCase(), isNot(contains('voicememory')));
        expect(line.toLowerCase(), isNot(contains('voice memory')));
      }
    });

    test('no exact scores or percentages in copy', () {
      for (final line in allCopy) {
        expect(line, isNot(contains('%')));
        expect(
          RegExp(r'\d').hasMatch(line),
          isFalse,
          reason: 'copy must not expose numbers: "$line"',
        );
      }
    });

    test('banned-word sweep', () {
      const banned = [
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
      ];
      for (final line in allCopy) {
        final words = line
            .toLowerCase()
            .split(RegExp(r'[^a-z]+'))
            .where((w) => w.isNotEmpty)
            .toSet();
        for (final word in banned) {
          expect(
            words,
            isNot(contains(word)),
            reason: '"$word" found in "$line"',
          );
        }
      }
    });

    test('score bands use stable ids and stay internal', () {
      expect(ArchiveRetrievalBand.none.id, 'none');
      expect(ArchiveRetrievalBand.weak.id, 'weak');
      expect(ArchiveRetrievalBand.possible.id, 'possible');
      expect(ArchiveRetrievalBand.strong.id, 'strong');
      expect(ActivationFunnelAnalytics.allowedScoreBandValues, {
        'none',
        'weak',
        'possible',
        'strong',
      });
    });

    test('pure engine never returns records it was not given', () {
      final records = _evidenceRecords();
      final result = _engine.score(records, now: _base);
      final givenIds = records.map((r) => r.entryId).toSet();
      for (final score in result.scores) {
        expect(givenIds, contains(score.record.entryId));
      }
    });
  });
}
