import 'package:archiveme_mobile/features/activation/first_three_session_gates.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_belief_correction_store.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_belief_thread_copy.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_belief_thread_engine.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_belief_thread_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/widgets/patterns/archive_belief_thread_card.dart';
import 'package:archiveme_mobile/widgets/patterns/weekly_what_changed_review_card.dart';
import 'package:archiveme_mobile/widgets/record/entry_direction_starters.dart';
import 'package:archiveme_mobile/widgets/trust/archive_privacy_trust_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

final List<JournalEntry> _repeatEntries = [
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
  setUp(ArchiveBeliefCorrectionStore.resetForTest);

  group('ArchiveBeliefThreadEngine', () {
    test('surfaces thread at 3+ eligible entries', () {
      final thread = const ArchiveBeliefThreadEngine().build(_repeatEntries);
      expect(thread.hasEnoughData, isTrue);
      expect(thread.currentBelief.toLowerCase(), contains('may'));
    });

    test('surfaces thread at 2 entries when repeat evidence exists', () {
      final thread = const ArchiveBeliefThreadEngine().build(
        _repeatEntries.take(2).toList(),
      );
      expect(thread.hasEnoughData, isTrue);
    });

    test('insufficient with fewer than 2 eligible entries', () {
      final thread = const ArchiveBeliefThreadEngine().build([
        _entry('1', 'One short moment saved today.'),
      ]);
      expect(thread.hasEnoughData, isFalse);
    });
  });

  group('WeeklyWhatChangedReviewEngine', () {
    test('shows review at 3+ entries', () {
      final review = const WeeklyWhatChangedReviewEngine().build(
        _repeatEntries,
      );
      expect(review.hasReview, isTrue);
    });

    test('waits until useful archive threshold', () {
      final review = const WeeklyWhatChangedReviewEngine().build(
        _repeatEntries.take(2).toList(),
      );
      expect(review.hasReview, isFalse);
      expect(FirstThreeSessionGates.minEntriesForUsefulArchive, 3);
    });
  });

  group('ArchiveBeliefThreadCard', () {
    testWidgets('uses thread title and correction actions', (tester) async {
      const thread = ArchiveBeliefThread(
        hasEnoughData: true,
        suggestionId: 'test_thread',
        currentBelief: 'You may be doing more to avoid feeling behind.',
        evidenceLine: '3 entries point toward this.',
        whatChanged: 'This time, it showed up around saying yes too quickly.',
        whatToTest:
            'Before agreeing, check whether you actually have capacity.',
        worthWatchingLine: ArchiveBeliefThreadCopy.worthWatching,
        timeline: [
          ArchiveEvidenceTimelineStep(
            label: ArchiveBeliefThreadCopy.timelineFirstAppeared,
            body: 'first entry',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ArchiveBeliefThreadCard(
                thread: thread,
                onRecordMoreEvidence: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(ArchiveBeliefThreadCopy.threadTitle), findsOneWidget);
      expect(find.text(ArchiveBeliefThreadCopy.notMe), findsOneWidget);
      expect(
        find.text(ArchiveBeliefThreadCopy.closeButDifferent),
        findsOneWidget,
      );
      expect(find.text(ArchiveBeliefThreadCopy.saveThread), findsOneWidget);
      expect(
        find.text(ArchiveBeliefThreadCopy.recordMoreEvidence),
        findsOneWidget,
      );
    });

    testWidgets('evidence timeline shows title', (tester) async {
      const thread = ArchiveBeliefThread(
        hasEnoughData: true,
        suggestionId: 'timeline_test',
        currentBelief: 'You may be noticing pressure.',
        evidenceLine: '3 entries point toward this.',
        whatChanged: 'Latest moment may sit differently.',
        whatToTest: 'Pause before agreeing.',
        timeline: [
          ArchiveEvidenceTimelineStep(
            label: ArchiveBeliefThreadCopy.timelineFirstAppeared,
            body: 'first entry',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ArchiveBeliefThreadCard(
                thread: thread,
                onRecordMoreEvidence: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(ArchiveBeliefThreadCopy.timelineTitle), findsOneWidget);
    });
  });

  group('WeeklyWhatChangedReviewCard', () {
    testWidgets('uses weekly title copy', (tester) async {
      const review = WeeklyWhatChangedReview(
        hasReview: true,
        whatKeptReturning: 'Doing more to avoid feeling behind.',
        whatChanged: 'You caught the pressure earlier once.',
        whatToTestNext: 'Pause before agreeing to new requests.',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: WeeklyWhatChangedReviewCard(review: review)),
        ),
      );
      await tester.pump();

      expect(find.text(ArchiveBeliefThreadCopy.weeklyTitle), findsOneWidget);
    });
  });

  group('EntryDirectionStarters', () {
    testWidgets('shows three one-tap starters', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: EntryDirectionStarters(onSelect: (_) {})),
        ),
      );
      await tester.pump();

      expect(
        find.text(ArchiveBeliefThreadCopy.entryStarterRepeated),
        findsOneWidget,
      );
      expect(
        find.text(ArchiveBeliefThreadCopy.entryStarterChanged),
        findsOneWidget,
      );
      expect(
        find.text(ArchiveBeliefThreadCopy.entryStarterAvoided),
        findsOneWidget,
      );
    });
  });

  group('ArchivePrivacyTrustCard', () {
    testWidgets('shows trust copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ArchivePrivacyTrustCard(onPrivacyTap: () {})),
        ),
      );
      await tester.pump();

      expect(find.text(ArchiveBeliefThreadCopy.trustTitle), findsOneWidget);
      expect(find.text(ArchiveBeliefThreadCopy.trustDelete), findsOneWidget);
      expect(find.text(ArchiveBeliefThreadCopy.trustControl), findsOneWidget);
      expect(
        find.text(ArchiveBeliefThreadCopy.trustNotTherapy),
        findsOneWidget,
      );
    });
  });

  group('ArchiveBeliefThreadCopy', () {
    test('avoids banned internal and diagnostic language', () {
      final haystack = ArchiveBeliefThreadCopy.all
          .where((line) => line != ArchiveBeliefThreadCopy.trustNotTherapy)
          .join(' ')
          .toLowerCase();
      for (final banned in [
        'revenuecat',
        'entitlements',
        'billing',
        'vector',
        'embedding',
        'thread id',
        'pack id',
        'diagnosis',
        'analysis complete',
        'insight generated',
        'ai detected',
      ]) {
        expect(haystack, isNot(contains(banned)), reason: banned);
      }
      expect(
        ArchiveBeliefThreadCopy.trustNotTherapy,
        'ArchiveMe is not therapy or diagnosis.',
      );
    });
  });
}