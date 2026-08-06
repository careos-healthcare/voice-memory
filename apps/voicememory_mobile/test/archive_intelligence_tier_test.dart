import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_belief_thread_copy.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_belief_thread_engine.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence_heuristics.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_intelligence_tier.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_intelligence_tier_resolver.dart';
import 'package:voicememory_mobile/features/activation/first_three_session_gates.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

JournalEntry _entry(String id, String transcript, {DateTime? createdAt}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt ?? DateTime(2026, 6, 12, 10),
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

final _workThenPersonalEntries = [
  _entry(
    '1',
    'I said yes at work again even though I was already tired from deadlines today.',
    createdAt: DateTime(2026, 6, 10, 10),
  ),
  _entry(
    '2',
    'I took responsibility at work again before asking anyone for help today.',
    createdAt: DateTime(2026, 6, 11, 10),
  ),
  _entry(
    '3',
    'I noticed I said yes to family again before checking whether I had capacity today.',
    createdAt: DateTime(2026, 6, 12, 10),
  ),
];

final _repeatEntries = [
  _entry(
    '1',
    'I said yes again even though I was already tired from work today.',
  ),
  _entry(
    '2',
    'I took responsibility again before asking anyone for help today.',
  ),
  _entry(
    '3',
    'I agreed to help again before checking whether I had capacity today.',
  ),
];

void main() {
  group('ArchiveIntelligenceTierResolver', () {
    test('free users use medium archive intelligence', () {
      final resolver = ArchiveIntelligenceTierResolver(
        reader: FakeArchiveEntitlementReader(pro: false),
      );
      expect(
        resolver.resolveSync(isPro: false),
        ArchiveIntelligenceTier.freeMedium,
      );
    });

    test('pro users use max archive intelligence', () {
      final resolver = ArchiveIntelligenceTierResolver(
        reader: FakeArchiveEntitlementReader(pro: true),
      );
      expect(resolver.resolveSync(isPro: true), ArchiveIntelligenceTier.proMax);
    });
  });

  group('ArchiveEvidenceHeuristics', () {
    const heuristics = ArchiveEvidenceHeuristics();

    test('repeated pressure phrases produce specific belief copy', () {
      final analysis = heuristics.analyze(_repeatEntries);
      expect(analysis.possibleRepeat, isTrue);
      expect(
        analysis.beliefLine.toLowerCase(),
        anyOf(contains('say yes'), contains('capacity'), contains('may')),
      );
    });

    test('context shift produces last time / this time style copy', () {
      final analysis = heuristics.analyze(_workThenPersonalEntries);
      expect(analysis.whatChangedLine, isNotNull);
      expect(analysis.whatChangedLine!, contains('Last time'));
      expect(analysis.whatChangedLine!, contains('This time'));
    });

    test('what faded only when older theme absent in latest entry', () {
      final fadedEntries = [
        _entry(
          '1',
          'Work deadlines piled up and I stayed late at the office again.',
          createdAt: DateTime(2026, 6, 10),
        ),
        _entry(
          '2',
          'More work pressure at the office before I left for the day.',
          createdAt: DateTime(2026, 6, 11),
        ),
        _entry(
          '3',
          'I said yes to family again before checking whether I had capacity.',
          createdAt: DateTime(2026, 6, 12),
        ),
      ];
      final analysis = heuristics.analyze(
        fadedEntries,
        tier: ArchiveIntelligenceTier.proMax,
      );
      expect(
        analysis.whatFadedLine,
        'This has not shown up in the latest entry.',
      );
    });

    test('free window uses fewer entries than pro', () {
      final many = List.generate(
        6,
        (i) => _entry(
          '$i',
          'I said yes again at work before checking capacity on day $i.',
          createdAt: DateTime(2026, 6, 1 + i),
        ),
      );
      final free = heuristics.analyze(
        many,
        tier: ArchiveIntelligenceTier.freeMedium,
      );
      final pro = heuristics.analyze(
        many,
        tier: ArchiveIntelligenceTier.proMax,
      );
      expect(free.windowEntries.length, lessThanOrEqualTo(3));
      expect(pro.windowEntries.length, greaterThan(free.windowEntries.length));
      expect(pro.evidenceSnippets, isNotEmpty);
      expect(free.evidenceSnippets, isEmpty);
    });
  });

  group('ArchiveBeliefThreadEngine tiering', () {
    const engine = ArchiveBeliefThreadEngine();

    test('3+ entries produce archive belief for free and pro', () {
      final free = engine.build(
        _repeatEntries,
        tier: ArchiveIntelligenceTier.freeMedium,
      );
      final pro = engine.build(
        _repeatEntries,
        tier: ArchiveIntelligenceTier.proMax,
      );
      expect(free.hasEnoughData, isTrue);
      expect(pro.hasEnoughData, isTrue);
    });

    test('free user sees simpler timeline', () {
      final free = engine.build(
        _repeatEntries,
        tier: ArchiveIntelligenceTier.freeMedium,
      );
      expect(free.worthWatchingLine, ArchiveBeliefThreadCopy.worthWatching);
      expect(free.timeline.length, lessThanOrEqualTo(3));
      expect(free.evidenceSnippets, isEmpty);
      expect(free.confidenceBand, isNull);
    });

    test('pro user sees deeper evidence and confidence band', () {
      final pro = engine.build(
        _repeatEntries,
        tier: ArchiveIntelligenceTier.proMax,
      );
      expect(pro.isProDepth, isTrue);
      expect(pro.confidenceBand, isNotNull);
      expect(pro.timeline.length, greaterThan(3));
    });

    test('oh wow moment surfaces for repeat evidence', () {
      final ohWow = engine.buildOhWow(
        _workThenPersonalEntries,
        tier: ArchiveIntelligenceTier.freeMedium,
      );
      expect(ohWow.hasMoment, isTrue);
      expect(ohWow.title, isNotEmpty);
    });
  });

  group('WeeklyWhatChangedReviewEngine tiering', () {
    const engine = WeeklyWhatChangedReviewEngine();

    test('3+ entries produce weekly review', () {
      final review = engine.build(
        _repeatEntries,
        tier: ArchiveIntelligenceTier.freeMedium,
      );
      expect(review.hasReview, isTrue);
      expect(FirstThreeSessionGates.minEntriesForUsefulArchive, 3);
    });

    test('pro weekly review may include what faded', () {
      final pro = engine.build(
        _workThenPersonalEntries,
        tier: ArchiveIntelligenceTier.proMax,
      );
      expect(pro.isProDepth, isTrue);
    });
  });

  group('Archive intelligence copy safety', () {
    test('pro bridge avoids hard paywall language', () {
      final haystack = [
        ArchiveBeliefThreadCopy.fullArchiveHistoryTitle,
        ArchiveBeliefThreadCopy.fullArchiveHistoryBody,
        ArchiveBeliefThreadCopy.proBridgeBody,
        ArchiveBeliefThreadCopy.proBridgeCta,
        ArchiveBeliefThreadCopy.proBridgeSecondary,
        ArchiveBeliefThreadCopy.proKeepsThread,
      ].join(' ').toLowerCase();
      expect(haystack, isNot(contains('upgrade required')));
      expect(haystack, isNot(contains('feature locked')));
      expect(haystack, isNot(contains('revenuecat')));
      expect(haystack, isNot(contains('entitlement')));
    });
  });
}
