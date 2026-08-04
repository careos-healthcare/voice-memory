import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_clarity/archive_clarity_models.dart';
import 'package:voicememory_mobile/features/demo/sample_archive_entries.dart';
import 'package:voicememory_mobile/features/todays_question/todays_question_copy.dart';
import 'package:voicememory_mobile/features/todays_question/todays_question_engine.dart';
import 'package:voicememory_mobile/features/todays_question/todays_question_models.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/screens/todays_one_question_screen.dart';
import 'package:voicememory_mobile/security/sensitive_screen_guard.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/record/todays_one_question_card.dart';

const _bannedWords = [
  'diagnosis',
  'symptom',
  'therapy',
  'mental health',
  'medical',
  'treatment',
  'streak',
  'guilt',
  'certain',
  'addictive',
  'limited time',
  'subscribe now',
  'buy now',
  'must upgrade',
  'share to unlock',
  "don't miss",
  'you must',
  'voice memory',
  'wellbeing score',
  'mental health score',
  'life score',
  'clinical score',
  'pro is active',
];

TodaysQuestionInput _input({
  int realSavedMomentCount = 0,
  int usableEvidenceCount = 0,
  bool hasWatchTheme = false,
  bool betaFeedbackCaptured = false,
  ArchiveClarityStageId archiveClarityStage = ArchiveClarityStageId.starting,
  bool weeklyReviewAvailable = false,
  bool sampleMode = false,
  int dayKey = 1,
}) => TodaysQuestionInput(
  realSavedMomentCount: realSavedMomentCount,
  usableEvidenceCount: usableEvidenceCount,
  hasWatchTheme: hasWatchTheme,
  betaFeedbackCaptured: betaFeedbackCaptured,
  archiveClarityStage: archiveClarityStage,
  weeklyReviewAvailable: weeklyReviewAvailable,
  sampleMode: sampleMode,
  dayKey: dayKey,
);

JournalEntry _entry(String id, {String? transcript}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 12, 12),
  transcript:
      transcript ??
      'I noticed the same work pressure pattern when I said yes again today.',
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

List<JournalEntry> _realEntries(int count) =>
    List.generate(count, (i) => _entry('real_$i'));

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
    expect(lower, isNot(contains('voicememory')));
  }
}

void main() {
  const engine = TodaysQuestionEngine();

  group('TodaysQuestionEngine', () {
    test('0 entries returns adaptive first-moment question via journal', () {
      final result = engine.buildFromJournal(
        entries: const [],
        hasWatchTheme: false,
        betaFeedbackCaptured: false,
      );

      expect(result.questionId, TodaysQuestionId.adaptive);
      expect(result.questionText, 'What is one real moment from today?');
      expect(result.primaryCtaLabel, TodaysQuestionCopy.saveMomentCta);
      expect(result.isEmptyState, isTrue);
    });

    test('1 entry returns adaptive similar-again question via journal', () {
      final result = engine.buildFromJournal(
        entries: _realEntries(1),
        hasWatchTheme: false,
        betaFeedbackCaptured: false,
      );

      expect(result.questionId, TodaysQuestionId.adaptive);
      expect(result.questionText, 'Did anything similar happen again?');
    });

    test('2 entries returns adaptive comparison question via journal', () {
      final result = engine.buildFromJournal(
        entries: _realEntries(2),
        hasWatchTheme: false,
        betaFeedbackCaptured: false,
      );

      expect(result.questionId, TodaysQuestionId.adaptive);
      expect(result.questionText, isNot(TodaysQuestionCopy.comparisonQuestion));
    });

    test(
      '3+ entries with beta feedback missing returns beta feedback prompt',
      () {
        final result = engine.build(
          _input(realSavedMomentCount: 3, betaFeedbackCaptured: false),
        );

        expect(result.questionId, TodaysQuestionId.betaFeedback);
        expect(result.isBetaFeedbackPrompt, isTrue);
        expect(result.primaryRoute, '/beta-feedback');
      },
    );

    test('watch theme present returns watch-theme question', () {
      final result = engine.build(
        _input(realSavedMomentCount: 4, hasWatchTheme: true),
      );

      expect(result.questionId, TodaysQuestionId.watchTheme);
      expect(result.questionText, TodaysQuestionCopy.watchThemeQuestion);
    });

    test('review-ready clarity stage can return change question', () {
      final result = engine.build(
        _input(
          realSavedMomentCount: 7,
          archiveClarityStage: ArchiveClarityStageId.reviewReady,
          weeklyReviewAvailable: true,
        ),
      );

      expect(result.questionId, TodaysQuestionId.reviewChange);
      expect(result.questionText, TodaysQuestionCopy.reviewChangeQuestion);
      expect(result.primaryRoute, '/weekly-archive-review');
    });

    test('sample entries are excluded from real counts', () {
      final entries = [..._realEntries(2), ...SampleArchiveEntries.build()];
      final result = engine.buildFromJournal(
        entries: entries,
        hasWatchTheme: false,
        betaFeedbackCaptured: false,
      );
      expect(result.questionId, TodaysQuestionId.adaptive);
    });

    test('question model contains no raw journal text', () {
      final entries = _realEntries(2);
      final privateText = entries.first.transcript;
      final result = engine.buildFromJournal(
        entries: entries,
        hasWatchTheme: false,
        betaFeedbackCaptured: false,
      );

      expect(result.questionText, isNot(contains(privateText)));
      expect(result.helperText, isNot(contains(privateText)));
    });

    test('ScreenshotMode hides Record card or uses safe static copy', () {
      final result = engine.build(_input(sampleMode: true));

      expect(result.showOnRecord, isFalse);
      expect(result.helperText, contains('Example only'));
    });

    test('copy uses ArchiveMe and avoids banned language', () {
      final copy = TodaysQuestionCopy.allVisibleStrings.join(' ').toLowerCase();
      expect(copy, contains('archiveme'));
      _expectNoBannedCopy(TodaysQuestionCopy.allVisibleStrings);
    });
  });

  group('Record screen card', () {
    testWidgets('ready state shows Today\'s One Question card', (tester) async {
      final question = engine.buildFromJournal(
        entries: _realEntries(1),
        hasWatchTheme: false,
        betaFeedbackCaptured: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: TodaysOneQuestionCard(question: question, onPrimary: () {}),
        ),
      );

      expect(find.byKey(const Key('todays_one_question_card')), findsOneWidget);
      expect(find.text('Did anything similar happen again?'), findsOneWidget);
    });

    testWidgets('Record screen still shows primary record button', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Column(
              children: [
                FilledButton(
                  key: const Key('capture_entry_record_cta'),
                  onPressed: () {},
                  child: const Text('Record'),
                ),
                TodaysOneQuestionCard(
                  question: engine.build(_input()),
                  onPrimary: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('capture_entry_record_cta')), findsOneWidget);
      expect(find.byKey(const Key('todays_one_question_card')), findsOneWidget);
    });
  });

  group('Full screen', () {
    testWidgets('has Record answer / Type answer / Back to Record CTAs', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: TodaysOneQuestionScreen(
            initialResult: engine.buildFromJournal(
              entries: _realEntries(1),
              hasWatchTheme: false,
              betaFeedbackCaptured: false,
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('todays_one_question_screen_record_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('todays_one_question_screen_type_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('todays_one_question_screen_back_button')),
        findsOneWidget,
      );
      expect(find.text(TodaysQuestionCopy.recordAnswerCta), findsOneWidget);
      expect(find.text(TodaysQuestionCopy.typeAnswerCta), findsOneWidget);
      expect(find.text(TodaysQuestionCopy.backToRecordCta), findsOneWidget);
      expect(
        find.byKey(const Key('todays_one_question_screen_helper')),
        findsOneWidget,
      );
      expect(
        find.text('ArchiveMe needs a second moment to compare.'),
        findsOneWidget,
      );
    });
  });

  group('Routing', () {
    test('router registers today\'s one question route', () {
      final router = File('lib/router/app_router.dart').readAsStringSync();
      expect(router, contains("path: '/todays-one-question'"));
    });

    test('sensitive route guard includes today\'s one question', () {
      expect(SensitiveRoutes.isSensitiveRoute('/todays-one-question'), isTrue);
    });

    test(
      'support feedback links to today\'s one question when implemented',
      () {
        final support = File(
          'lib/screens/support_feedback_screen.dart',
        ).readAsStringSync();
        expect(support, contains('support_feedback_open_todays_one_question'));
        expect(support, contains('TodaysQuestionCopy.route'));
      },
    );
  });
}
