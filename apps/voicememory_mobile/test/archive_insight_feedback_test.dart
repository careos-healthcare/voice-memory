import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/activation/archive_home_summary.dart';
import 'package:voicememory_mobile/features/activation/archive_insight_feedback.dart';
import 'package:voicememory_mobile/features/activation/belief_evidence_trail.dart';
import 'package:voicememory_mobile/features/activation/belief_update_payoff.dart';
import 'package:voicememory_mobile/features/activation/weekly_archive_review.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/screens/belief_evidence_screen.dart';
import 'package:archiveme_research/screens/weekly_archive_review_screen.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/archive/archive_home_summary_card.dart';
import 'package:voicememory_mobile/widgets/archive/weekly_archive_review_card.dart';
import 'package:voicememory_mobile/widgets/record/belief_update_payoff_card.dart';

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

const _rawTranscriptSnippet =
    'I felt pressure at work before saying yes again even when I was tired';

List<String> _visibleText(WidgetTester tester) {
  final texts = <String>[];
  for (final element in find.byType(Text).evaluate()) {
    final data = (element.widget as Text).data;
    if (data != null && data.isNotEmpty) texts.add(data);
  }
  return texts;
}

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

void _expectFeedbackControlsPresent(WidgetTester tester) {
  expect(
    find.byKey(const Key('archive_insight_feedback_controls')),
    findsOneWidget,
  );
  expect(find.text(ArchiveInsightFeedbackCopy.feelsRight), findsOneWidget);
  expect(find.text(ArchiveInsightFeedbackCopy.notQuite), findsOneWidget);
  expect(find.text(ArchiveInsightFeedbackCopy.hideThis), findsOneWidget);
  expect(find.text(ArchiveInsightFeedbackCopy.whySeeing), findsOneWidget);
}

void _expectFeedbackControlsAbsent(WidgetTester tester) {
  expect(
    find.byKey(const Key('archive_insight_feedback_controls')),
    findsNothing,
  );
}

Future<void> _pumpArchiveHomeCard(
  WidgetTester tester,
  ArchiveHomeSummary summary, {
  VoidCallback? onPrimary,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: ArchiveHomeSummaryCard(
            summary: summary,
            onPrimary: onPrimary ?? () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(ArchiveInsightFeedbackStore.resetForTest);

  group('ArchiveInsightFeedbackGate', () {
    test('archive home shows controls at 3+ entries only', () {
      expect(
        ArchiveInsightFeedbackGate.showForArchiveHome(ArchiveHomeStage.empty),
        isFalse,
      );
      expect(
        ArchiveInsightFeedbackGate.showForArchiveHome(ArchiveHomeStage.one),
        isFalse,
      );
      expect(
        ArchiveInsightFeedbackGate.showForArchiveHome(ArchiveHomeStage.two),
        isFalse,
      );
      expect(
        ArchiveInsightFeedbackGate.showForArchiveHome(ArchiveHomeStage.three),
        isTrue,
      );
      expect(
        ArchiveInsightFeedbackGate.showForArchiveHome(ArchiveHomeStage.four),
        isTrue,
      );
      expect(
        ArchiveInsightFeedbackGate.showForArchiveHome(
          ArchiveHomeStage.fivePlus,
        ),
        isTrue,
      );
    });

    test('weekly review shows controls only with enough evidence', () {
      expect(
        ArchiveInsightFeedbackGate.showForWeeklyReview(
          hasEnoughEvidence: false,
        ),
        isFalse,
      );
      expect(
        ArchiveInsightFeedbackGate.showForWeeklyReview(hasEnoughEvidence: true),
        isTrue,
      );
    });
  });

  group('ArchiveInsightFeedbackStore', () {
    test('records feels right and not quite counts locally', () {
      const id = 'weeklyReview';
      expect(ArchiveInsightFeedbackStore.feelsRightCount(id), 0);
      expect(ArchiveInsightFeedbackStore.notQuiteCount(id), 0);

      ArchiveInsightFeedbackStore.record(
        id,
        ArchiveInsightFeedbackChoice.feelsRight,
      );
      expect(ArchiveInsightFeedbackStore.feelsRightCount(id), 1);

      ArchiveInsightFeedbackStore.record(
        id,
        ArchiveInsightFeedbackChoice.notQuite,
      );
      expect(ArchiveInsightFeedbackStore.notQuiteCount(id), 1);
    });

    test('hide marks insight as hidden', () {
      const id = 'beliefEvidence';
      expect(ArchiveInsightFeedbackStore.isHidden(id), isFalse);
      ArchiveInsightFeedbackStore.hide(id);
      expect(ArchiveInsightFeedbackStore.isHidden(id), isTrue);
    });
  });

  group('Archive Home feedback controls', () {
    testWidgets('render for 3+ entry archive home stages', (tester) async {
      for (final count in [3, 4, 5]) {
        ArchiveInsightFeedbackStore.resetForTest();
        final summary = ArchiveHomeSummaryEngine.build(
          entries: _entries(count),
        );
        await _pumpArchiveHomeCard(tester, summary);
        _expectFeedbackControlsPresent(tester);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('do not render for 0–1 entry premature states', (tester) async {
      for (final count in [0, 1]) {
        ArchiveInsightFeedbackStore.resetForTest();
        final summary = ArchiveHomeSummaryEngine.build(
          entries: count == 0 ? const [] : _entries(count),
        );
        await _pumpArchiveHomeCard(tester, summary);
        _expectFeedbackControlsAbsent(tester);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('two-entry stage hides feedback controls', (tester) async {
      final summary = ArchiveHomeSummaryEngine.build(entries: _entries(2));
      await _pumpArchiveHomeCard(tester, summary);
      _expectFeedbackControlsAbsent(tester);
    });
  });

  group('Weekly review feedback controls', () {
    testWidgets('render for 5+ entry review', (tester) async {
      final review = WeeklyArchiveReviewEngine.build(
        entries: _fiveDistinctWorkEntries(),
      );
      await tester.binding.setSurfaceSize(const Size(390, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: WeeklyArchiveReviewCard(review: review),
            ),
          ),
        ),
      );
      await tester.pump();
      _expectFeedbackControlsPresent(tester);
    });

    testWidgets('do not render for insufficient review', (tester) async {
      final review = WeeklyArchiveReviewEngine.build(
        entries: _fiveDistinctWorkEntries().sublist(0, 3),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: WeeklyArchiveReviewCard(review: review)),
        ),
      );
      await tester.pump();
      _expectFeedbackControlsAbsent(tester);
    });
  });

  group('Feedback interactions', () {
    testWidgets('why am I seeing this expands explanation copy', (
      tester,
    ) async {
      final summary = ArchiveHomeSummaryEngine.build(entries: _entries(3));
      await _pumpArchiveHomeCard(tester, summary);

      expect(
        find.byKey(const Key('archive_insight_feedback_why_source')),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('archive_insight_feedback_why')));
      await tester.pump();

      expect(
        find.byKey(const Key('archive_insight_feedback_why_source')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('archive_insight_feedback_why_not_conclusion')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('archive_insight_feedback_why_hide')),
        findsOneWidget,
      );
    });

    testWidgets('feels right stores local positive feedback', (tester) async {
      final summary = ArchiveHomeSummaryEngine.build(entries: _entries(3));
      final insightId = ArchiveInsightFeedbackStore.archiveHomeId(
        summary.stage,
      );
      await _pumpArchiveHomeCard(tester, summary);

      await tester.tap(
        find.byKey(const Key('archive_insight_feedback_feels_right')),
      );
      await tester.pump();

      expect(ArchiveInsightFeedbackStore.feelsRightCount(insightId), 1);
    });

    testWidgets('not quite stores local negative feedback', (tester) async {
      final summary = ArchiveHomeSummaryEngine.build(entries: _entries(3));
      final insightId = ArchiveInsightFeedbackStore.archiveHomeId(
        summary.stage,
      );
      await _pumpArchiveHomeCard(tester, summary);

      await tester.tap(
        find.byKey(const Key('archive_insight_feedback_not_quite')),
      );
      await tester.pump();

      expect(ArchiveInsightFeedbackStore.notQuiteCount(insightId), 1);
    });

    testWidgets('hide this suppresses the insight locally', (tester) async {
      final summary = ArchiveHomeSummaryEngine.build(entries: _entries(3));
      final insightId = ArchiveInsightFeedbackStore.archiveHomeId(
        summary.stage,
      );
      await _pumpArchiveHomeCard(tester, summary);

      expect(
        find.byKey(const Key('archive_home_summary_card')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('archive_insight_feedback_hide')));
      await tester.pump();

      expect(ArchiveInsightFeedbackStore.isHidden(insightId), isTrue);
      expect(find.byKey(const Key('archive_home_summary_card')), findsNothing);
      expect(
        find.byKey(Key('archive_insight_feedback_hidden_$insightId')),
        findsOneWidget,
      );
    });
  });

  group('Copy safety', () {
    test('feedback copy avoids banned language', () {
      _expectNoBannedCopy([
        ArchiveInsightFeedbackCopy.feelsRight,
        ArchiveInsightFeedbackCopy.notQuite,
        ArchiveInsightFeedbackCopy.hideThis,
        ArchiveInsightFeedbackCopy.whySeeing,
        ArchiveInsightFeedbackCopy.whySource,
        ArchiveInsightFeedbackCopy.whyNotConclusion,
        ArchiveInsightFeedbackCopy.whyHide,
      ]);
    });

    test('feedback copy does not expose raw transcript text', () {
      for (final line in [
        ArchiveInsightFeedbackCopy.feelsRight,
        ArchiveInsightFeedbackCopy.notQuite,
        ArchiveInsightFeedbackCopy.hideThis,
        ArchiveInsightFeedbackCopy.whySeeing,
        ArchiveInsightFeedbackCopy.whySource,
        ArchiveInsightFeedbackCopy.whyNotConclusion,
        ArchiveInsightFeedbackCopy.whyHide,
      ]) {
        expect(
          line.toLowerCase(),
          isNot(contains(_rawTranscriptSnippet.toLowerCase())),
        );
      }
    });

    testWidgets('why panel on card avoids banned and transcript copy', (
      tester,
    ) async {
      final summary = ArchiveHomeSummaryEngine.build(entries: _entries(4));
      await _pumpArchiveHomeCard(tester, summary);
      await tester.tap(find.byKey(const Key('archive_insight_feedback_why')));
      await tester.pump();

      final visible = _visibleText(tester).where(
        (text) =>
            text == ArchiveInsightFeedbackCopy.whySource ||
            text == ArchiveInsightFeedbackCopy.whyNotConclusion ||
            text == ArchiveInsightFeedbackCopy.whyHide,
      );
      _expectNoBannedCopy(visible);
      for (final text in visible) {
        expect(
          text.toLowerCase(),
          isNot(contains(_rawTranscriptSnippet.toLowerCase())),
        );
      }
    });
  });

  group('Navigation still works with feedback controls', () {
    testWidgets('view evidence CTA still fires on belief update card', (
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
            builder: (context, state) => BeliefEvidenceScreen(
              previewTrail: BeliefEvidenceTrailEngine.build(
                entries: _fiveDistinctWorkEntries().sublist(0, 4),
              ),
            ),
          ),
        ],
      );

      await tester.binding.setSurfaceSize(const Size(390, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pumpAndSettle();

      _expectFeedbackControlsPresent(tester);

      final cta = find.byKey(
        const Key('belief_update_payoff_view_evidence_cta'),
      );
      await tester.ensureVisible(cta);
      await tester.tap(cta);
      await tester.pumpAndSettle();

      expect(evidenceOpened, isTrue);
      expect(
        find.byKey(const Key('belief_evidence_trail_card')),
        findsOneWidget,
      );
    });

    testWidgets('view review CTA still fires on archive home', (tester) async {
      final summary = ArchiveHomeSummaryEngine.build(entries: _entries(5));
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

      _expectFeedbackControlsPresent(tester);

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
