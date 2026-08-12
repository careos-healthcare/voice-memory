import 'package:archiveme_mobile/features/activation/archive_home_summary.dart';
import 'package:archiveme_mobile/features/activation/archive_insight_feedback.dart';
import 'package:archiveme_mobile/features/activation/archive_insight_feedback_adaptation.dart';
import 'package:archiveme_mobile/features/activation/belief_evidence_trail.dart';
import 'package:archiveme_mobile/features/activation/belief_update_payoff.dart';
import 'package:archiveme_mobile/features/activation/weekly_archive_review.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/archive/archive_home_summary_card.dart';
import 'package:archiveme_mobile/widgets/record/belief_update_payoff_card.dart';
import 'package:archiveme_research/screens/weekly_archive_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

JournalEntry _voiceEntry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 12, 12),
  transcript: transcript,
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
  (i) => _voiceEntry(
    id: 'e$i',
    transcript:
        'I felt pressure at work before saying yes again even when I was tired moment $i.',
    createdAt: DateTime(2026, 6, 9 + i, 12),
  ),
);

List<JournalEntry> _fiveDistinctWorkEntries() => [
  _voiceEntry(
    id: 'e1',
    transcript:
        'I felt pressure at work before saying yes again even when I was tired.',
    createdAt: DateTime(2026, 6, 9, 12),
  ),
  _voiceEntry(
    id: 'e2',
    transcript:
        'Work kept pulling me back after I wanted to stop for the day at the office.',
    createdAt: DateTime(2026, 6, 10, 12),
  ),
  _voiceEntry(
    id: 'e3',
    transcript:
        'I noticed the same hurry showing up before I answered anyone at work.',
    createdAt: DateTime(2026, 6, 11, 12),
  ),
  _voiceEntry(
    id: 'e4',
    transcript:
        'The deadline pressure returned, but I caught it earlier this time.',
    createdAt: DateTime(2026, 6, 12, 12),
  ),
  _voiceEntry(
    id: 'e5',
    transcript:
        'The same hurry showed up at home with my partner after a long day at work.',
    createdAt: DateTime(2026, 6, 13, 12),
  ),
];

const _bannedWords = [
  'diagnosis',
  'symptom',
  'therapy',
  'mental health',
  'streak',
  'guilt',
  'you always',
  'pattern found',
  'certain',
  'must come back',
];

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

void main() {
  setUp(() async => ArchiveInsightFeedbackStore.resetForTest());

  group('ArchiveInsightFeedbackAdaptation resolver', () {
    test('Not quite produces cautious copy for the same target', () {
      const target = ArchiveInsightTarget.weeklyReview;
      const base = 'What your saved words are starting to show.';

      expect(
        ArchiveInsightFeedbackAdaptation.adaptedCopyFor(base, target),
        base,
      );

      ArchiveInsightFeedbackStore.record(
        ArchiveInsightFeedbackStore.targetId(target),
        ArchiveInsightFeedbackChoice.notQuite,
      );

      expect(
        ArchiveInsightFeedbackAdaptation.hasNegativeFeedback(target),
        isTrue,
      );
      final adapted = ArchiveInsightFeedbackAdaptation.adaptedCopyFor(
        base,
        target,
      );
      expect(
        adapted,
        startsWith(ArchiveInsightFeedbackAdaptationCopy.mayNotBeQuiteRight),
      );
      expect(adapted, contains(base));
    });

    test('two Not quite responses use elevated cautious copy', () {
      const target = ArchiveInsightTarget.archiveHome;
      const base = 'Your archive is starting to see a thread.';
      const id = 'archive_home_three';

      ArchiveInsightFeedbackStore.record(
        id,
        ArchiveInsightFeedbackChoice.notQuite,
      );
      ArchiveInsightFeedbackStore.record(
        id,
        ArchiveInsightFeedbackChoice.notQuite,
      );

      expect(
        ArchiveInsightFeedbackAdaptation.cautionLevelFor(
          target,
          archiveHomeStage: ArchiveHomeStage.three,
        ),
        ArchiveInsightCautionLevel.elevated,
      );
      expect(
        ArchiveInsightFeedbackAdaptation.adaptedCopyFor(
          base,
          target,
          archiveHomeStage: ArchiveHomeStage.three,
        ),
        startsWith(ArchiveInsightFeedbackAdaptationCopy.stillTestingBelief),
      );
    });

    test('belief evidence uses needs-another-moment copy at mild caution', () {
      const target = ArchiveInsightTarget.beliefEvidence;
      const base = 'Work pressure keeps showing up before you say yes.';

      ArchiveInsightFeedbackStore.record(
        ArchiveInsightFeedbackStore.targetId(target),
        ArchiveInsightFeedbackChoice.notQuite,
      );

      expect(
        ArchiveInsightFeedbackAdaptation.adaptedCopyFor(base, target),
        startsWith(ArchiveInsightFeedbackAdaptationCopy.needsAnotherMoment),
      );
    });

    test('Feels right stores positive feedback and does not suppress', () {
      const target = ArchiveInsightTarget.beliefUpdate;
      final id = ArchiveInsightFeedbackStore.targetId(target);

      ArchiveInsightFeedbackStore.record(
        id,
        ArchiveInsightFeedbackChoice.feelsRight,
      );

      expect(
        ArchiveInsightFeedbackAdaptation.hasPositiveFeedback(target),
        isTrue,
      );
      expect(ArchiveInsightFeedbackAdaptation.shouldSuppress(target), isFalse);
      expect(
        ArchiveInsightFeedbackAdaptation.cautionLevelFor(target),
        ArchiveInsightCautionLevel.none,
      );
    });

    test('Hide this suppresses the same target locally', () {
      const target = ArchiveInsightTarget.weeklyReview;
      final id = ArchiveInsightFeedbackStore.targetId(target);

      ArchiveInsightFeedbackStore.hide(id);

      expect(ArchiveInsightFeedbackAdaptation.shouldSuppress(target), isTrue);
    });

    test('Hide this does not suppress unrelated targets', () {
      ArchiveInsightFeedbackStore.hide(
        ArchiveInsightFeedbackStore.targetId(ArchiveInsightTarget.weeklyReview),
      );

      expect(
        ArchiveInsightFeedbackAdaptation.shouldSuppress(
          ArchiveInsightTarget.beliefEvidence,
        ),
        isFalse,
      );
      expect(
        ArchiveInsightFeedbackAdaptation.shouldSuppress(
          ArchiveInsightTarget.archiveHome,
          archiveHomeStage: ArchiveHomeStage.four,
        ),
        isFalse,
      );
    });

    test('adapted copy avoids banned language', () {
      const base = 'Work pressure keeps showing up before you say yes.';
      for (final target in ArchiveInsightTarget.values) {
        await ArchiveInsightFeedbackStore.resetForTest();
        ArchiveInsightFeedbackStore.record(
          ArchiveInsightFeedbackAdaptation.resolveInsightId(
            target,
            archiveHomeStage: ArchiveHomeStage.three,
          ),
          ArchiveInsightFeedbackChoice.notQuite,
        );
        ArchiveInsightFeedbackStore.record(
          ArchiveInsightFeedbackAdaptation.resolveInsightId(
            target,
            archiveHomeStage: ArchiveHomeStage.three,
          ),
          ArchiveInsightFeedbackChoice.notQuite,
        );
        final adapted = ArchiveInsightFeedbackAdaptation.adaptedCopyFor(
          base,
          target,
          archiveHomeStage: target == ArchiveInsightTarget.archiveHome
              ? ArchiveHomeStage.three
              : null,
        );
        _expectNoBannedCopy([adapted]);
      }
    });
  });

  group('ArchiveInsightFeedbackAdaptation UI', () {
    testWidgets('archive home body adapts after Not quite tap', (tester) async {
      final summary = ArchiveHomeSummaryEngine.build(entries: _entries(3));
      await tester.binding.setSurfaceSize(const Size(390, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ArchiveHomeSummaryCard(summary: summary, onPrimary: () {}),
            ),
          ),
        ),
      );
      await tester.pump();

      final bodyFinder = find.byKey(const Key('archive_home_summary_body'));
      final originalBody = tester.widget<Text>(bodyFinder).data!;
      expect(originalBody, isNot(contains('not be quite right')));

      await tester.tap(
        find.byKey(const Key('archive_insight_feedback_not_quite')),
      );
      await tester.pump();

      final adaptedBody = tester.widget<Text>(bodyFinder).data!;
      expect(adaptedBody, contains('not be quite right'));
      expect(adaptedBody, contains(summary.body));
    });

    testWidgets(
      'Feels right shows local confirmation without suppressing card',
      (tester) async {
        final summary = ArchiveHomeSummaryEngine.build(entries: _entries(3));
        await tester.binding.setSurfaceSize(const Size(390, 1800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: ArchiveHomeSummaryCard(
                  summary: summary,
                  onPrimary: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.tap(
          find.byKey(const Key('archive_insight_feedback_feels_right')),
        );
        await tester.pump();

        expect(
          find.byKey(
            const Key('archive_insight_feedback_feels_right_confirmation'),
          ),
          findsOneWidget,
        );
        expect(
          find.text(ArchiveInsightFeedbackAdaptationCopy.savedUsefulFeedback),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('archive_home_summary_card')),
          findsOneWidget,
        );
      },
    );

    testWidgets('view evidence route still works with adapted payoff card', (
      tester,
    ) async {
      const payoff = BeliefUpdatePayoff(
        title: BeliefUpdatePayoffCopy.title,
        body: BeliefUpdatePayoffCopy.bodyChanged,
        currentBelief: VisibleArchiveProofCopy.beliefUpdateWorkBelief,
        evidenceRows: ['snippet one', 'snippet two'],
        whatChangedLine: VisibleArchiveProofCopy.beliefUpdateChangeNewContext,
        beliefChanged: true,
        evidenceWeak: false,
        primaryCta: 'Record if it happens again',
        secondaryCta: 'View evidence',
      );

      ArchiveInsightFeedbackStore.record(
        ArchiveInsightFeedbackStore.targetId(ArchiveInsightTarget.beliefUpdate),
        ArchiveInsightFeedbackChoice.notQuite,
      );

      var evidenceOpened = false;
      final router = GoRouter(
        initialLocation: '/start',
        routes: [
          GoRoute(
            path: '/start',
            builder: (context, state) => Scaffold(
              body: SingleChildScrollView(
                child: BeliefUpdatePayoffCard(
                  payoff: payoff,
                  onAddAnother: () {},
                  onViewEvidence: () {
                    evidenceOpened = true;
                    context.push(BeliefEvidenceNavigation.route);
                  },
                ),
              ),
            ),
          ),
          GoRoute(
            path: BeliefEvidenceNavigation.route,
            builder: (context, state) =>
                const Scaffold(body: Text('EVIDENCE_SCREEN')),
          ),
        ],
      );

      await tester.binding.setSurfaceSize(const Size(390, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          ArchiveInsightFeedbackAdaptationCopy.needsAnotherMoment,
        ),
        findsOneWidget,
      );

      final cta = find.byKey(
        const Key('belief_update_payoff_view_evidence_cta'),
      );
      await tester.ensureVisible(cta);
      await tester.tap(cta);
      await tester.pumpAndSettle();

      expect(evidenceOpened, isTrue);
      expect(find.text('EVIDENCE_SCREEN'), findsOneWidget);
    });

    testWidgets('view review route still works with adapted archive home', (
      tester,
    ) async {
      final summary = ArchiveHomeSummaryEngine.build(entries: _entries(5));
      ArchiveInsightFeedbackStore.record(
        ArchiveInsightFeedbackStore.archiveHomeId(summary.stage),
        ArchiveInsightFeedbackChoice.notQuite,
      );

      var reviewOpened = false;
      final router = GoRouter(
        initialLocation: '/archive-home',
        routes: [
          GoRoute(
            path: '/archive-home',
            builder: (context, state) => Scaffold(
              body: SingleChildScrollView(
                child: ArchiveHomeSummaryCard(
                  summary: summary,
                  onPrimary: () {
                    reviewOpened = true;
                    context.push(WeeklyArchiveReviewNavigation.route);
                  },
                ),
              ),
            ),
          ),
          GoRoute(
            path: WeeklyArchiveReviewNavigation.route,
            builder: (context, state) => WeeklyArchiveReviewScreen(
              previewReview: WeeklyArchiveReviewEngine.build(
                entries: _fiveDistinctWorkEntries(),
              ),
            ),
          ),
        ],
      );

      await tester.binding.setSurfaceSize(const Size(390, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          ArchiveInsightFeedbackAdaptationCopy.mayNotBeQuiteRight,
        ),
        findsWidgets,
      );

      final cta = find.byKey(const Key('archive_home_summary_primary_cta'));
      await tester.ensureVisible(cta);
      await tester.tap(cta);
      await tester.pumpAndSettle();

      expect(reviewOpened, isTrue);
      expect(
        find.byKey(const Key('weekly_archive_review_card')),
        findsOneWidget,
      );
    });
  });
}