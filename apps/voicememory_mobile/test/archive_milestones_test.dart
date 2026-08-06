import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/activation/weekly_archive_review.dart';
import 'package:voicememory_mobile/features/archive_export/archive_export_pack.dart';
import 'package:voicememory_mobile/features/archive_milestones/archive_milestones_copy.dart';
import 'package:voicememory_mobile/features/archive_milestones/archive_milestones_engine.dart';
import 'package:voicememory_mobile/features/archive_milestones/archive_milestones_gates.dart';
import 'package:voicememory_mobile/features/archive_milestones/archive_milestones_models.dart';
import 'package:voicememory_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:voicememory_mobile/features/return_ritual/return_ritual_models.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/archive_milestones_card.dart';

const _bannedWords = [
  'diagnosis',
  'symptom',
  'therapy',
  'mental health',
  'medical',
  'streak',
  'guilt',
  'certain',
  'addictive',
  'limited time',
  'subscribe now',
  'buy now',
  'must upgrade',
  'share to unlock',
];

const _forbiddenPurchaseCtas = [
  'Buy now',
  'Subscribe now',
  'Start trial',
  'Limited time',
];

JournalEntry _entry(
  String id, {
  String? transcript,
  DateTime? createdAt,
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 12, 12),
  transcript:
      transcript ??
      'I felt pressure at work before saying yes again even when I was tired today.',
  durationSeconds: 30,
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

List<JournalEntry> _entries(int count) => List.generate(
  count,
  (i) => _entry('e$i', createdAt: DateTime(2026, 6, 9 + i, 12)),
);

void _expectNoBannedCopy(Iterable<String> visible) {
  for (final text in visible) {
    final lower = text.toLowerCase();
    for (final word in _bannedWords) {
      expect(
        lower,
        isNot(contains(word)),
        reason: 'must not contain "$word" in "$text"',
      );
    }
  }
}

bool _milestoneComplete({
  required ArchiveMilestoneId id,
  required List<JournalEntry> entries,
  int watchlistCount = 0,
  bool hasReturnRitual = false,
}) {
  final saved = entries
      .where(
        (e) =>
            e.transcript.trim().isNotEmpty &&
            !e.transcript.startsWith('[draft]'),
      )
      .length;
  final shareProof = const ShareableArchiveProofEngine().buildFromJournal(
    entries: entries,
  );
  final weekly = WeeklyArchiveReviewEngine.build(entries: entries);
  return ArchiveMilestonesEngine.isComplete(
    id: id,
    savedCount: saved,
    eligibleCount: saved,
    watchlistCount: watchlistCount,
    hasReturnRitual: hasReturnRitual,
    shareProofReady: shareProof.hasProof,
    weeklyReviewReady: weekly.hasEnoughEvidence,
  );
}

void main() {
  const engine = ArchiveMilestonesEngine();

  group('Archive milestones gates', () {
    test('shows on archive when not sample mode', () {
      expect(ArchiveMilestonesGates.showOnArchive(sampleMode: false), isTrue);
    });

    test('hidden on sample archive mode', () {
      expect(ArchiveMilestonesGates.showOnArchive(sampleMode: true), isFalse);
    });

    test('Pro line only at ten entries', () {
      expect(ArchiveMilestonesGates.showProLine(savedCount: 9), isFalse);
      expect(ArchiveMilestonesGates.showProLine(savedCount: 10), isTrue);
    });
  });

  group('Archive milestones engine', () {
    test('0 entries shows first milestone as next', () {
      final result = engine.build(
        entries: const [],
        watchlistCount: 0,
        hasReturnRitual: false,
      );
      expect(result.rows.first.id, ArchiveMilestoneId.firstMomentSaved);
      expect(result.rows.first.state, ArchiveMilestoneRowState.now);
    });

    test('1 entry completes first moment saved', () {
      expect(
        _milestoneComplete(
          id: ArchiveMilestoneId.firstMomentSaved,
          entries: [_entry('e1')],
        ),
        isTrue,
      );
    });

    test('2 entries completes first comparison possible', () {
      expect(
        _milestoneComplete(
          id: ArchiveMilestoneId.firstComparisonPossible,
          entries: _entries(2),
        ),
        isTrue,
      );
    });

    test('3+ entries completes cautious belief milestone', () {
      expect(
        _milestoneComplete(
          id: ArchiveMilestoneId.firstCautiousBelief,
          entries: _entries(3),
        ),
        isTrue,
      );
    });

    test('5+ entries completes weekly review milestone when review ready', () {
      final entries = _entries(5);
      final weekly = WeeklyArchiveReviewEngine.build(entries: entries);
      expect(weekly.hasEnoughEvidence, isTrue);
      expect(
        _milestoneComplete(
          id: ArchiveMilestoneId.firstWeeklyReviewReady,
          entries: entries,
        ),
        isTrue,
      );
    });

    test('watchlist item completes watchlist milestone', () {
      expect(
        _milestoneComplete(
          id: ArchiveMilestoneId.firstWatchlistTheme,
          entries: [_entry('e1')],
          watchlistCount: 1,
        ),
        isTrue,
      );
      final result = engine.build(
        entries: [_entry('e1')],
        watchlistCount: 1,
        hasReturnRitual: false,
      );
      expect(
        result.rows.any(
          (row) =>
              row.id == ArchiveMilestoneId.firstWatchlistTheme &&
              row.isComplete,
        ),
        isFalse,
      );
      expect(
        _milestoneComplete(
          id: ArchiveMilestoneId.firstWatchlistTheme,
          entries: [_entry('e1')],
          watchlistCount: 1,
        ),
        isTrue,
      );
    });

    test('return ritual completes return ritual milestone', () {
      expect(
        _milestoneComplete(
          id: ArchiveMilestoneId.firstReturnRitual,
          entries: [_entry('e1')],
          hasReturnRitual: true,
        ),
        isTrue,
      );
    });

    test('10+ entries shows long-term archive building', () {
      expect(
        _milestoneComplete(
          id: ArchiveMilestoneId.longTermArchiveBuilding,
          entries: _entries(10),
        ),
        isTrue,
      );
      final result = engine.build(
        entries: _entries(10),
        watchlistCount: 0,
        hasReturnRitual: false,
      );
      expect(result.showProLine, isTrue);
    });

    test('share-safe proof milestone at three eligible entries', () {
      expect(
        _milestoneComplete(
          id: ArchiveMilestoneId.firstShareSafeProof,
          entries: _entries(3),
        ),
        isTrue,
      );
    });

    test('shows at most five milestone rows', () {
      final result = engine.build(
        entries: const [],
        watchlistCount: 0,
        hasReturnRitual: false,
      );
      expect(result.rows.length, lessThanOrEqualTo(5));
    });
  });

  group('Archive milestones copy', () {
    test('uses ArchiveMe and avoids banned language', () {
      _expectNoBannedCopy(ArchiveMilestonesCopy.allVisibleCopy());
      for (final text in ArchiveMilestonesCopy.allVisibleCopy()) {
        expect(text.toLowerCase(), isNot(contains('voicememory')));
      }
      expect(
        ArchiveMilestonesCopy.allVisibleCopy(),
        anyElement(contains('ArchiveMe')),
      );
    });

    test('does not include Buy now or Subscribe now copy', () {
      final joined = ArchiveMilestonesCopy.allVisibleCopy().join('\n');
      for (final cta in _forbiddenPurchaseCtas) {
        expect(joined, isNot(contains(cta)));
      }
    });
  });

  group('Archive milestones UI', () {
    testWidgets('card hidden in sample mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ArchiveMilestonesCard.test(
              entries: _entries(3),
              sampleMode: true,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('archive_milestones_card_hidden')),
        findsOneWidget,
      );
    });

    testWidgets('Pro preview routes at ten entries', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                ArchiveMilestonesCard.test(entries: _entries(10)),
          ),
          GoRoute(
            path: '/pro-preview',
            builder: (_, _) => const Scaffold(body: Text('pro-preview')),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('archive_milestones_pro_line')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('archive_milestones_pro_preview_button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('pro-preview'), findsOneWidget);
    });

    testWidgets('does not include Buy now or Subscribe now text', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ArchiveMilestonesCard.test(entries: _entries(3)),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Buy now'), findsNothing);
      expect(find.text('Subscribe now'), findsNothing);
    });
  });

  group('Archive milestones privacy boundaries', () {
    test('does not write to JournalStore', () {
      final engineSrc = File(
        'lib/features/archive_milestones/archive_milestones_engine.dart',
      ).readAsStringSync();
      expect(engineSrc, isNot(contains('JournalStore')));
    });

    test('share-safe proof excludes milestone text', () {
      final proof = const ShareableArchiveProofEngine().buildFromJournal(
        entries: _entries(5),
      );
      expect(proof.shareText, isNot(contains('Archive milestones')));
    });

    test('archive export pack excludes milestone text', () {
      final pack = ArchiveExportPackEngine.build(
        entries: _entries(5),
        exportedAt: DateTime.utc(2026, 6, 15),
      );
      expect(pack.plainText, isNot(contains('Archive milestones')));
    });

    test('archive belief screen wires milestones card', () {
      final src = File(
        'lib/screens/archive_belief_screen.dart',
      ).readAsStringSync();
      expect(src, contains('ArchiveMilestonesCard'));
      expect(src, contains('ArchiveMilestonesGates.showOnArchive'));
    });
  });
}
