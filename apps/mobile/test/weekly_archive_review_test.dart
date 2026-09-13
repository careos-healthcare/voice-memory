import 'dart:io';

import 'package:archiveme_mobile/features/activation/belief_evidence_trail.dart';
import 'package:archiveme_mobile/features/activation/weekly_archive_review.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/features/pro_evidence_value/pro_evidence_value_dismiss_store.dart';
import 'package:archiveme_mobile/features/pro_evidence_value/pro_evidence_value_engine.dart';
import 'package:archiveme_mobile/features/pro_evidence_value/pro_evidence_value_model.dart';
import 'package:archiveme_mobile/features/pro_memory/pro_memory_boundary_engine.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_change_proof.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_copy.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:archiveme_mobile/features/weekly_review/weekly_archive_review_copy.dart'
    as review_surface_copy;
import 'package:archiveme_mobile/features/weekly_review/weekly_archive_review_engine.dart'
    as review_surface;
import 'package:archiveme_mobile/features/weekly_review/weekly_archive_review_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/capture_save_messages.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/archive/weekly_archive_review_card.dart';
import 'package:archiveme_mobile/widgets/weekly_review/weekly_archive_review_card.dart'
    as review_surface_card;
import 'package:archiveme_mobile/widgets/weekly_review/weekly_archive_review_sheet.dart'
    as review_surface_sheet;
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
      expect(review.subtitle, 'What your saved words are starting to show.');
    });

    test('review includes all required sections', () {
      final review = WeeklyArchiveReviewEngine.build(
        entries: _fiveDistinctWorkEntries(),
      );
      expect(review.strongestThreadLine, isNotEmpty);
      expect(review.whatChangedLine, isNotEmpty);
      expect(review.evidenceRows.length, greaterThanOrEqualTo(2));
      expect(review.nextActionLine, isNotEmpty);
      expect(
        review.notConclusionLine,
        VisibleArchiveProofCopy.weeklyArchiveReviewNotConclusion,
      );
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
      expect(
        review.uncertaintyLine,
        VisibleArchiveProofCopy.weeklyArchiveReviewStillThin,
      );
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

      expect(
        find.byKey(const Key('weekly_archive_review_card')),
        findsOneWidget,
      );
      expect(find.text("This week's strongest thread"), findsOneWidget);
      expect(find.text('What changed'), findsOneWidget);
      expect(find.text('Evidence from your archive'), findsOneWidget);
      expect(find.text('What to add next'), findsOneWidget);
      expect(
        find.byKey(const Key('weekly_archive_review_evidence_0')),
        findsOneWidget,
      );
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

      expect(
        find.byKey(const Key('weekly_archive_review_insufficient')),
        findsOneWidget,
      );
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

      expect(
        find.byKey(const Key('weekly_archive_review_screen_title')),
        findsOneWidget,
      );
      expect(find.text('Your archive review'), findsWidgets);
      expect(
        find.byKey(const Key('weekly_archive_review_add_cta')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('weekly_archive_review_view_evidence_cta')),
        findsOneWidget,
      );
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

      expect(
        find.byKey(const Key('weekly_archive_review_insufficient_body')),
        findsOneWidget,
      );
    });
  });

  group('Weekly archive review navigation', () {
    testWidgets('Record if it happens again routes to record', (tester) async {
      final review = WeeklyArchiveReviewEngine.build(
        entries: _fiveDistinctWorkEntries(),
      );
      var recordOpened = false;

      final router = GoRouter(
        initialLocation: WeeklyArchiveReviewNavigation.route,
        routes: [
          GoRoute(
            path: WeeklyArchiveReviewNavigation.route,
            builder: (context, state) =>
                WeeklyArchiveReviewScreen(previewReview: review),
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
            builder: (context, state) =>
                WeeklyArchiveReviewScreen(previewReview: review),
          ),
          GoRoute(
            path: BeliefEvidenceNavigation.route,
            builder: (context, state) {
              evidenceOpened = true;
              return const Scaffold(body: Text('EVIDENCE_SCREEN'));
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

      final evidenceCta = find.byKey(
        const Key('weekly_archive_review_view_evidence_cta'),
      );
      await tester.ensureVisible(evidenceCta);
      await tester.tap(evidenceCta);
      await tester.pumpAndSettle();

      expect(evidenceOpened, isTrue);
      expect(find.text('EVIDENCE_SCREEN'), findsOneWidget);
    });
  });

  group('WeeklyArchiveReviewSurface v1', () {
    const genericTestOne = 'This is a test to check function';
    const genericTestTwo = 'This is a second test for pressure';

    JournalEntry surfaceEntry({
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

    List<JournalEntry> threeDistinctUnrelatedEntries() => [
      surfaceEntry(
        id: 'u1',
        transcript: 'I stayed late finishing a report for my manager at work.',
        createdAt: DateTime(2026, 6, 10, 12),
      ),
      surfaceEntry(
        id: 'u2',
        transcript: 'My neighbor was loud during my morning call at home.',
        createdAt: DateTime(2026, 6, 11, 12),
      ),
      surfaceEntry(
        id: 'u3',
        transcript: 'I forgot to buy groceries on the way home tonight.',
        createdAt: DateTime(2026, 6, 12, 12),
      ),
    ];

    List<JournalEntry> fiveSaidYesEntries() => [
      surfaceEntry(
        id: 'e1',
        transcript:
            'I had no capacity but I said yes again to the extra meeting today.',
        createdAt: DateTime(2026, 6, 10, 12),
      ),
      surfaceEntry(
        id: 'e2',
        transcript:
            'Same thing — said yes when I had no capacity for one more thing.',
        createdAt: DateTime(2026, 6, 11, 12),
      ),
      surfaceEntry(
        id: 'e3',
        transcript:
            'I said yes again even though I had no capacity for one more ask.',
        createdAt: DateTime(2026, 6, 12, 12),
      ),
      surfaceEntry(
        id: 'e4',
        transcript:
            'I said yes again even though I had no capacity for one more ask today.',
        createdAt: DateTime(2026, 6, 13, 12),
      ),
      surfaceEntry(
        id: 'e5',
        transcript:
            'Same yes pattern came back but it felt less urgent and easier to stop this time.',
        createdAt: DateTime(2026, 6, 14, 12),
      ),
    ];

    List<JournalEntry> fiveDistinctUnrelatedEntries() => [
      ...threeDistinctUnrelatedEntries(),
      surfaceEntry(
        id: 'u4',
        transcript: 'The coffee machine broke before my first meeting.',
        createdAt: DateTime(2026, 6, 13, 12),
      ),
      surfaceEntry(
        id: 'u5',
        transcript: 'I missed the bus and walked the long way around town.',
        createdAt: DateTime(2026, 6, 14, 12),
      ),
    ];

    List<JournalEntry> mixedRepeatAndWalkEntries() => [
      ...fiveSaidYesEntries().sublist(0, 3),
      surfaceEntry(
        id: 'w4',
        transcript: 'I walked outside before replying and it helped.',
        createdAt: DateTime(2026, 6, 13, 12),
      ),
      surfaceEntry(
        id: 'w5',
        transcript: 'Same week I walked outside again before the hard email.',
        createdAt: DateTime(2026, 6, 14, 12),
      ),
    ];

    List<RepeatReturnCheckRecord> laterReturnChecks(
      RepeatReturnCheckChoice choice,
    ) => [
      RepeatReturnCheckRecord(
        entryId: 'e4',
        choice: choice,
        entryCountAtCapture: 4,
        createdAt: DateTime(2026, 6, 14),
      ),
    ];

    void expectNoDebugLabels(Iterable<String> copy) {
      final joined = copy.join(' ').toLowerCase();
      expect(joined, isNot(contains('[draft]')));
      expect(joined, isNot(contains('transcribe when connected')));
      expect(joined, isNot(contains('entry_id')));
      expect(joined, isNot(contains('debug')));
      _expectNoBannedCopy(copy);
    }

    group('gates', () {
      test('does not show with zero entries', () {
        expect(
          review_surface.WeeklyArchiveReviewEngine.shouldShow(entries: []),
          isFalse,
        );
        expect(
          review_surface.WeeklyArchiveReviewEngine.build(entries: []),
          isNull,
        );
      });

      test('does not show with generic test entries only', () {
        final entries = [
          surfaceEntry(id: 'g1', transcript: genericTestOne),
          surfaceEntry(id: 'g2', transcript: genericTestTwo),
        ];
        expect(
          review_surface.WeeklyArchiveReviewEngine.shouldShow(entries: entries),
          isFalse,
        );
      });

      test('does not show with quiet-day entries only', () {
        final entries = [
          surfaceEntry(id: 'q1', transcript: 'Nothing much today.'),
          surfaceEntry(id: 'q2', transcript: 'Nothing much today.'),
        ];
        expect(
          review_surface.WeeklyArchiveReviewEngine.shouldShow(entries: entries),
          isFalse,
        );
      });

      test('does not show with pending transcript entries only', () {
        final entries = [_degradedVoiceEntry(), _degradedVoiceEntry(id: 'v2')];
        expect(
          review_surface.WeeklyArchiveReviewEngine.shouldShow(entries: entries),
          isFalse,
        );
      });
    });

    group('states', () {
      test(
        'shows week still forming when low evidence but real entries exist',
        () {
          final entries = threeDistinctUnrelatedEntries();
          expect(
            review_surface.WeeklyArchiveReviewEngine.shouldShow(
              entries: entries,
            ),
            isTrue,
          );
          final review = review_surface.WeeklyArchiveReviewEngine.build(
            entries: entries,
          );
          expect(review, isNotNull);
          expect(review!.state, WeeklyArchiveReviewState.forming);
          expect(
            review.title,
            review_surface_copy.WeeklyArchiveReviewCopy.formingTitle,
          );
          expect(
            review.formingBody,
            review_surface_copy.WeeklyArchiveReviewCopy.formingBody,
          );
        },
      );

      test('shows full weekly review after five real entries', () {
        final entries = fiveSaidYesEntries();
        final review = review_surface.WeeklyArchiveReviewEngine.build(
          entries: entries,
          viewingConfirmedRepeatOrTimeline: true,
        );
        expect(review, isNotNull);
        expect(review!.state, WeeklyArchiveReviewState.full);
        expect(review.title, review_surface_copy.WeeklyArchiveReviewCopy.title);
        expect(
          review.subtitle,
          review_surface_copy.WeeklyArchiveReviewCopy.subtitle,
        );
      });

      test('shows full weekly review after first proof and later return', () {
        final entries = fiveSaidYesEntries().sublist(0, 4);
        final returnChecks = [
          RepeatReturnCheckRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.softer,
            entryCountAtCapture: 4,
            createdAt: DateTime(2026, 6, 14),
          ),
        ];
        expect(
          review_surface.WeeklyArchiveReviewEngine.shouldShow(
            entries: entries,
            returnChecks: returnChecks,
          ),
          isTrue,
        );
        final review = review_surface.WeeklyArchiveReviewEngine.build(
          entries: entries,
          returnChecks: returnChecks,
          viewingConfirmedRepeatOrTimeline: true,
        );
        expect(review, isNotNull);
        expect(review!.state, WeeklyArchiveReviewState.full);
      });
    });

    group('sections', () {
      test('what repeated uses grounded phrase only', () {
        final entries = fiveSaidYesEntries();
        final review = review_surface.WeeklyArchiveReviewEngine.build(
          entries: entries,
          viewingConfirmedRepeatOrTimeline: true,
        );
        expect(review!.whatRepeated?.isSupported, isTrue);
        expect(
          review.whatRepeated!.body,
          contains('appeared across several moments'),
        );
        expect(review.whatRepeated!.body.toLowerCase(), contains('said yes'));
        for (final phrase in review.whatRepeated!.evidencePhrases) {
          expect(
            phrase.toLowerCase(),
            isNot(anyOf('control', 'anxiety', 'stress')),
          );
        }
      });

      test('what changed appears only when change evidence supports it', () {
        final entries = fiveSaidYesEntries().sublist(0, 4);
        final withoutChange = review_surface.WeeklyArchiveReviewEngine.build(
          entries: entries,
        );
        expect(withoutChange!.whatChanged?.isSupported, isFalse);
        expect(
          withoutChange.whatChanged?.body,
          review_surface_copy.WeeklyArchiveReviewCopy.changedFallback,
        );

        final withChange = review_surface.WeeklyArchiveReviewEngine.build(
          entries: entries,
          changeProof: const RepeatReturnCheckChangeProof(
            title: RepeatReturnCheckCopy.changeProofTitle,
            body: RepeatReturnCheckCopy.trendSofterThanBefore,
            latestChoice: RepeatReturnCheckChoice.softer,
          ),
          viewingConfirmedRepeatOrTimeline: true,
        );
        expect(withChange!.whatChanged?.isSupported, isTrue);
        expect(withChange.whatChanged!.body, isNotEmpty);
      });

      test(
        'return-check-only stronger and same emit supported changed lines',
        () {
          final entries = fiveSaidYesEntries().sublist(0, 4);

          final stronger = review_surface.WeeklyArchiveReviewEngine.build(
            entries: entries,
            returnChecks: laterReturnChecks(RepeatReturnCheckChoice.stronger),
            viewingConfirmedRepeatOrTimeline: true,
          );
          expect(stronger!.whatChanged?.isSupported, isTrue);
          expect(
            stronger.whatChanged!.body,
            'One later entry sounded more aware of the pressure.',
          );

          final same = review_surface.WeeklyArchiveReviewEngine.build(
            entries: entries,
            returnChecks: laterReturnChecks(RepeatReturnCheckChoice.same),
            viewingConfirmedRepeatOrTimeline: true,
          );
          expect(same!.whatChanged?.isSupported, isTrue);
          expect(
            same.whatChanged!.body,
            'Later entries stayed about the same this week.',
          );

          final softer = review_surface.WeeklyArchiveReviewEngine.build(
            entries: entries,
            returnChecks: laterReturnChecks(RepeatReturnCheckChoice.softer),
            viewingConfirmedRepeatOrTimeline: true,
          );
          expect(softer!.whatChanged?.isSupported, isTrue);
          expect(
            softer.whatChanged!.body,
            'One later entry sounded more aware of checking capacity.',
          );

          final changedChoice = review_surface.WeeklyArchiveReviewEngine.build(
            entries: entries,
            returnChecks: laterReturnChecks(RepeatReturnCheckChoice.changed),
            viewingConfirmedRepeatOrTimeline: true,
          );
          expect(changedChoice!.whatChanged?.isSupported, isFalse);
          expect(
            changedChoice.whatChanged?.body,
            review_surface_copy.WeeklyArchiveReviewCopy.changedFallback,
          );
        },
      );

      test('what repeated uses section-specific empty copy', () {
        final review = review_surface.WeeklyArchiveReviewEngine.build(
          entries: fiveDistinctUnrelatedEntries(),
        );
        expect(review!.state, WeeklyArchiveReviewState.full);
        expect(review.whatRepeated?.isSupported, isFalse);
        expect(
          review.whatRepeated?.body,
          review_surface_copy.WeeklyArchiveReviewCopy.repeatedFallback,
        );
      });

      test('what seemed to help says not enough evidence when unsupported', () {
        final review = review_surface.WeeklyArchiveReviewEngine.build(
          entries: fiveSaidYesEntries(),
          viewingConfirmedRepeatOrTimeline: true,
        );
        expect(review!.whatHelped?.isSupported, isFalse);
        expect(
          review.whatHelped?.body,
          review_surface_copy.WeeklyArchiveReviewCopy.helpedFallback,
        );
      });

      test('positive-pattern helped line uses noticed-in-your-words prefix', () {
        final review = review_surface.WeeklyArchiveReviewEngine.build(
          entries: mixedRepeatAndWalkEntries(),
          viewingConfirmedRepeatOrTimeline: true,
        );
        expect(review!.whatHelped?.isSupported, isTrue);
        expect(
          review.whatHelped!.body,
          startsWith(
            '${review_surface_copy.WeeklyArchiveReviewCopy.helpedPrefix} ',
          ),
        );
        expect(review.whatHelped!.body.toLowerCase(), contains('walked outside'));
        expect(review.whatHelped!.body, isNot(contains('You marked that you')));
        expect(review.whatHelped!.body, isNot(contains('The last time you')));
      });
    });

    group('copy safety', () {
      test('no raw placeholders or debug labels', () {
        final review = review_surface.WeeklyArchiveReviewEngine.build(
          entries: fiveSaidYesEntries(),
          viewingConfirmedRepeatOrTimeline: true,
        );
        expectNoDebugLabels([
          review!.title,
          if (review.subtitle != null) review.subtitle!,
          if (review.whatRepeated != null) review.whatRepeated!.body,
          if (review.whatChanged != null) review.whatChanged!.body,
          if (review.whatHelped != null) review.whatHelped!.body,
          if (review.whatToWatchNext != null) review.whatToWatchNext!.body,
        ]);
      });
    });

    group('widgets', () {
      testWidgets('compact card uses view weekly review CTA', (tester) async {
        final review = review_surface.WeeklyArchiveReviewEngine.build(
          entries: fiveSaidYesEntries(),
          viewingConfirmedRepeatOrTimeline: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: review_surface_card.WeeklyArchiveReviewCard(
                review: review!,
                onViewReview: () {},
              ),
            ),
          ),
        );

        expect(
          find.byKey(const Key('weekly_archive_review_card')),
          findsOneWidget,
        );
        expect(
          find.text(
            review_surface_copy.WeeklyArchiveReviewCopy.viewWeeklyReviewCta,
          ),
          findsOneWidget,
        );
        expect(
          find.text(review_surface_copy.WeeklyArchiveReviewCopy.title),
          findsOneWidget,
        );
      });

      testWidgets('sheet renders full sections', (tester) async {
        final review = review_surface.WeeklyArchiveReviewEngine.build(
          entries: fiveSaidYesEntries(),
          viewingConfirmedRepeatOrTimeline: true,
        );

        await tester.binding.setSurfaceSize(const Size(390, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: review_surface_sheet.WeeklyArchiveReviewSheet(
                review: review!,
              ),
            ),
          ),
        );

        expect(
          find.byKey(const Key('weekly_archive_review_sheet')),
          findsOneWidget,
        );
        expect(
          find.text(
            review_surface_copy.WeeklyArchiveReviewCopy.whatRepeatedLabel,
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            review_surface_copy.WeeklyArchiveReviewCopy.whatChangedLabel,
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            review_surface_copy.WeeklyArchiveReviewCopy.whatHelpedLabel,
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            review_surface_copy.WeeklyArchiveReviewCopy.whatToWatchLabel,
          ),
          findsOneWidget,
        );
      });

      test(
        'weekly preview surface can show pro evidence bridge when gates pass',
        () {
          ProEvidenceValueDismissStore.invalidateSessionForTest();
          final entries = fiveSaidYesEntries();
          final review = review_surface.WeeklyArchiveReviewEngine.build(
            entries: entries,
            viewingConfirmedRepeatOrTimeline: true,
          );
          expect(review, isNotNull);
          expect(
            ProMemoryBoundaryEngine.hasGatedWeeklyReviewSections(
              review: review!,
              isPro: false,
            ),
            isTrue,
          );
          expect(
            ProEvidenceValueEngine.shouldShowCard(
              ProEvidenceValueContext(
                surface: ProEvidenceValueSurface.weeklyReviewPreview,
                entryCount: entries.length,
                isPro: false,
                dismissed: false,
                firstProofPayoffSeen: true,
                hasConfirmedRepeatEvidence: true,
                privateReportPreviewVisible: false,
                weeklyReviewPreviewVisible: true,
                isZeroEntryState: false,
                isFirstRecordingState: false,
                isDegradedTranscriptState: false,
                isPostSaveDegradedState: false,
                firstProofTruthQuestionActive: false,
                whatChangedQuestionActive: false,
                currentRelevanceQuestionActive: false,
                patternReviewInboxHasActiveItems: false,
                exportReportsLive: true,
              ),
            ),
            isTrue,
          );
        },
      );
    });

    group('billing untouched', () {
      test('surface files do not touch billing RevenueCat or restore', () {
        const surfacePaths = [
          'lib/features/weekly_review/weekly_archive_review_copy.dart',
          'lib/features/weekly_review/weekly_archive_review_model.dart',
          'lib/features/weekly_review/weekly_archive_review_engine.dart',
          'lib/widgets/weekly_review/weekly_archive_review_card.dart',
          'lib/widgets/weekly_review/weekly_archive_review_sheet.dart',
        ];
        for (final path in surfacePaths) {
          final content = File(path).readAsStringSync().toLowerCase();
          expect(content, isNot(contains('revenuecat')));
          expect(content, isNot(contains('restorepurchase')));
          expect(content, isNot(contains('billing/')));
        }
      });
    });
  });
}
