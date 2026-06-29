import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/activation/belief_evidence_trail.dart';
import 'package:voicememory_mobile/features/activation/weekly_archive_review.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/screens/weekly_archive_review_screen.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/archive/weekly_archive_review_card.dart';

JournalEntry _voiceEntry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) =>
    JournalEntry(
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

JournalEntry _degradedVoiceEntry({String id = 'v1'}) => JournalEntry(
      id: id,
      createdAt: DateTime(2026, 6, 12, 12),
      transcript:
          '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected',
      durationSeconds: 20,
      localAudioPath: '/tmp/$id.m4a',
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 0,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
    );

List<JournalEntry> _fourDistinctWorkEntries() => [
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
    ];

List<JournalEntry> _fiveDistinctWorkEntries() => [
      ..._fourDistinctWorkEntries(),
      _voiceEntry(
        id: 'e5',
        transcript:
            'The same hurry showed up at home with my partner after a long day at work.',
        createdAt: DateTime(2026, 6, 13, 12),
      ),
    ];

const _bannedWords = [
  'you always',
  'diagnosis',
  'symptom',
  'therapy',
  'mental health condition',
  'we found your pattern',
  'streak',
  'guilt',
  'must come back',
];

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

void main() {
  group('WeeklyArchiveReviewEngine', () {
    test('fewer than five usable entries show insufficient copy', () {
      for (final count in [1, 2, 3, 4]) {
        final review = WeeklyArchiveReviewEngine.build(
          entries: _fourDistinctWorkEntries().sublist(0, count),
        );
        expect(review.hasEnoughEvidence, isFalse);
        expect(
          review.insufficientBody,
          'Your archive needs more moments before it can create a review.',
        );
      }
    });

    test('five usable entries show Your archive review', () {
      final review = WeeklyArchiveReviewEngine.build(
        entries: _fiveDistinctWorkEntries(),
      );
      expect(review.hasEnoughEvidence, isTrue);
      expect(review.title, 'Your archive review');
      expect(
        review.subtitle,
        'What your saved words are starting to show.',
      );
    });

    test('review includes all required sections', () {
      final review = WeeklyArchiveReviewEngine.build(
        entries: _fiveDistinctWorkEntries(),
      );
      expect(review.strongestThreadLine, isNotEmpty);
      expect(review.whatChangedLine, isNotEmpty);
      expect(review.evidenceRows.length, greaterThanOrEqualTo(2));
      expect(review.nextActionLine, isNotEmpty);
      expect(review.notConclusionLine, VisibleArchiveProofCopy.weeklyArchiveReviewNotConclusion);
      expect(
        review.sourceLine,
        'ArchiveMe is using your saved words, not guessing.',
      );
      _expectNoBannedCopy([
        review.title,
        review.subtitle!,
        review.notConclusionLine!,
        review.sourceLine!,
        review.strongestThreadLine!,
        review.whatChangedLine!,
        ...review.evidenceRows,
        if (review.nextActionLine != null) review.nextActionLine!,
      ]);
    });

    test('degraded entries do not count toward five usable entries', () {
      final review = WeeklyArchiveReviewEngine.build(
        entries: [
          ..._fourDistinctWorkEntries(),
          _degradedVoiceEntry(id: 'e5'),
        ],
      );
      expect(review.hasEnoughEvidence, isFalse);
    });

    test('weak duplicate evidence shows still thin uncertainty', () {
      const shared =
          'I felt pressure at work before saying yes again even when I was tired.';
      final review = WeeklyArchiveReviewEngine.build(
        entries: List.generate(
          5,
          (i) => _voiceEntry(
            id: 'e$i',
            transcript: shared,
            createdAt: DateTime(2026, 6, 9 + i, 12),
          ),
        ),
      );
      expect(review.hasEnoughEvidence, isTrue);
      expect(review.evidenceWeak, isTrue);
      expect(review.uncertaintyLine, VisibleArchiveProofCopy.weeklyArchiveReviewStillThin);
    });

    test('route constant is stable', () {
      expect(WeeklyArchiveReviewNavigation.route, '/weekly-archive-review');
    });
  });

  group('WeeklyArchiveReviewCard', () {
    testWidgets('full card renders all sections', (tester) async {
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

      expect(find.byKey(const Key('weekly_archive_review_card')), findsOneWidget);
      expect(find.text('This week\'s strongest thread'), findsOneWidget);
      expect(find.text('What changed'), findsOneWidget);
      expect(find.text('Evidence from your archive'), findsOneWidget);
      expect(find.text('What to add next'), findsOneWidget);
      expect(find.byKey(const Key('weekly_archive_review_evidence_0')), findsOneWidget);
      _expectNoBannedCopy(_visibleText(tester));
    });

    testWidgets('insufficient card shows graceful copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: WeeklyArchiveReviewCard(
              review: WeeklyArchiveReview.insufficient(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('weekly_archive_review_insufficient')), findsOneWidget);
      expect(
        find.text(
          'Your archive needs more moments before it can create a review.',
        ),
        findsOneWidget,
      );
    });
  });

  group('WeeklyArchiveReviewScreen', () {
    testWidgets('preview review renders without crash', (tester) async {
      final review = WeeklyArchiveReviewEngine.build(
        entries: _fiveDistinctWorkEntries(),
      );

      await tester.binding.setSurfaceSize(const Size(390, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: WeeklyArchiveReviewScreen(previewReview: review),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('weekly_archive_review_screen_title')), findsOneWidget);
      expect(find.text('Your archive review'), findsWidgets);
      expect(find.byKey(const Key('weekly_archive_review_add_cta')), findsOneWidget);
      expect(find.byKey(const Key('weekly_archive_review_view_evidence_cta')), findsOneWidget);
    });

    testWidgets('insufficient preview does not crash', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: WeeklyArchiveReviewScreen(
            previewReview: WeeklyArchiveReview.insufficient(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('weekly_archive_review_insufficient_body')), findsOneWidget);
    });
  });

  group('Weekly archive review navigation', () {
    testWidgets('Add one more moment routes to record', (tester) async {
      final review = WeeklyArchiveReviewEngine.build(
        entries: _fiveDistinctWorkEntries(),
      );
      var recordOpened = false;

      final router = GoRouter(
        initialLocation: WeeklyArchiveReviewNavigation.route,
        routes: [
          GoRoute(
            path: WeeklyArchiveReviewNavigation.route,
            builder: (context, state) => WeeklyArchiveReviewScreen(
              previewReview: review,
            ),
          ),
          GoRoute(
            path: '/record',
            builder: (context, state) {
              recordOpened = true;
              return const Scaffold(body: Text('RECORD_SCREEN'));
            },
          ),
        ],
      );

      await tester.binding.setSurfaceSize(const Size(390, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pumpAndSettle();

      final addCta = find.byKey(const Key('weekly_archive_review_add_cta'));
      await tester.ensureVisible(addCta);
      await tester.tap(addCta);
      await tester.pumpAndSettle();

      expect(recordOpened, isTrue);
      expect(find.text('RECORD_SCREEN'), findsOneWidget);
    });

    testWidgets('View evidence routes to belief evidence', (tester) async {
      final review = WeeklyArchiveReviewEngine.build(
        entries: _fiveDistinctWorkEntries(),
      );
      var evidenceOpened = false;

      final router = GoRouter(
        initialLocation: WeeklyArchiveReviewNavigation.route,
        routes: [
          GoRoute(
            path: WeeklyArchiveReviewNavigation.route,
            builder: (context, state) => WeeklyArchiveReviewScreen(
              previewReview: review,
            ),
          ),
          GoRoute(
            path: BeliefEvidenceNavigation.route,
            builder: (context, state) {
              evidenceOpened = true;
              return const Scaffold(
                body: Text('EVIDENCE_SCREEN'),
              );
            },
          ),
        ],
      );

      await tester.binding.setSurfaceSize(const Size(390, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pumpAndSettle();

      final evidenceCta =
          find.byKey(const Key('weekly_archive_review_view_evidence_cta'));
      await tester.ensureVisible(evidenceCta);
      await tester.tap(evidenceCta);
      await tester.pumpAndSettle();

      expect(evidenceOpened, isTrue);
      expect(find.text('EVIDENCE_SCREEN'), findsOneWidget);
    });
  });
}
