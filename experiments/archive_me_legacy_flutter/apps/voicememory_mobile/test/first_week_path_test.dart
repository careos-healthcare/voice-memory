import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/weekly_archive_review.dart';
import 'package:voicememory_mobile/features/archive_depth/archive_depth_models.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_engine.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_models.dart';
import 'package:voicememory_mobile/features/demo/sample_archive_entries.dart';
import 'package:voicememory_mobile/features/first_week_path/first_week_path_copy.dart';
import 'package:voicememory_mobile/features/first_week_path/first_week_path_engine.dart';
import 'package:voicememory_mobile/features/first_week_path/first_week_path_models.dart';
import 'package:voicememory_mobile/features/help/help_reviewer_guide_copy.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/screens/support_feedback_screen.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/first_week_path_card.dart';

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
  'don\'t miss',
  'voice memory',
];

FirstWeekPathInput _input({
  int realSavedMomentCount = 0,
  bool hasWatchTheme = false,
  bool betaFeedbackCaptured = false,
  bool hasWeeklyReviewAvailable = false,
  bool sampleMode = false,
}) => FirstWeekPathInput(
  realSavedMomentCount: realSavedMomentCount,
  hasWatchTheme: hasWatchTheme,
  betaFeedbackCaptured: betaFeedbackCaptured,
  hasWeeklyReviewAvailable: hasWeeklyReviewAvailable,
  sampleMode: sampleMode,
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
  const engine = FirstWeekPathEngine();

  group('FirstWeekPathEngine', () {
    test('0 entries returns Day 1 start state', () {
      final result = engine.build(_input());

      expect(result.completedStepCount, 0);
      expect(result.currentStep, FirstWeekPathStep.day1);
      expect(result.cardTitle, FirstWeekPathCopy.startTitle);
      expect(result.primaryRoute, '/record');
      expect(result.primaryCtaLabel, FirstWeekPathCopy.saveFirstMomentCta);
      expect(result.isComplete, isFalse);
    });

    test('1 entry returns Day 1 completed and Day 2 next', () {
      final result = engine.build(_input(realSavedMomentCount: 1));

      expect(result.completedStepCount, 1);
      expect(result.currentStep, FirstWeekPathStep.day2);
      expect(result.rewardText, FirstWeekPathCopy.day1Reward);
      expect(result.nextStepText, FirstWeekPathCopy.day2Next);
      expect(result.primaryRoute, '/record');
    });

    test('2 entries returns Day 2 completed and Day 3 next', () {
      final result = engine.build(_input(realSavedMomentCount: 2));

      expect(result.completedStepCount, 2);
      expect(result.currentStep, FirstWeekPathStep.day3);
      expect(result.rewardText, FirstWeekPathCopy.day2Reward);
      expect(result.nextStepText, FirstWeekPathCopy.day3Next);
      expect(result.primaryRoute, '/record');
    });

    test('3 entries routes to beta feedback', () {
      final result = engine.build(_input(realSavedMomentCount: 3));

      expect(result.completedStepCount, 3);
      expect(result.primaryRoute, '/beta-feedback');
      expect(result.primaryCtaLabel, FirstWeekPathCopy.openBetaFeedbackCta);
      expect(result.nextStepText, FirstWeekPathCopy.day3Next);
    });

    test('4 entries routes to watch theme on Archive Home', () {
      final result = engine.build(_input(realSavedMomentCount: 4));

      expect(result.completedStepCount, 4);
      expect(result.primaryRoute, '/archive-belief');
      expect(result.primaryCtaLabel, FirstWeekPathCopy.pickWatchThemeCta);
    });

    test('5 entries says evidence is getting stronger', () {
      final result = engine.build(_input(realSavedMomentCount: 5));

      expect(result.completedStepCount, 5);
      expect(result.rewardText, FirstWeekPathCopy.day5Reward);
      expect(result.nextStepText, FirstWeekPathCopy.day5Next);
    });

    test('6 entries points to review what changed', () {
      final result = engine.build(_input(realSavedMomentCount: 6));

      expect(result.completedStepCount, 6);
      expect(result.primaryRoute, '/archive-belief');
      expect(result.primaryCtaLabel, FirstWeekPathCopy.reviewChangesCta);
      expect(result.nextStepText, FirstWeekPathCopy.day6Next);
    });

    test('7 entries marks first week path complete and weekly review', () {
      final result = engine.build(
        _input(realSavedMomentCount: 7, hasWeeklyReviewAvailable: true),
      );

      expect(result.isComplete, isTrue);
      expect(result.completedStepCount, 7);
      expect(result.cardTitle, FirstWeekPathCopy.completeTitle);
      expect(result.primaryRoute, WeeklyArchiveReviewNavigation.route);
      expect(result.primaryCtaLabel, FirstWeekPathCopy.openWeeklyReviewCta);
    });

    test('sample entries are excluded from real counts', () {
      final entries = [..._realEntries(2), ...SampleArchiveEntries.build()];
      expect(engine.realSavedMomentCount(entries), 2);
    });

    test('ScreenshotMode preview does not expose private data', () {
      final result = engine.build(_input(sampleMode: true));

      expect(result.cardTitle, FirstWeekPathCopy.screenshotCardTitle);
      expect(result.cardBody, contains('Example only'));
      expect(result.showOnArchiveHome, isFalse);
      for (final entry in _realEntries(3)) {
        expect(result.cardBody, isNot(contains(entry.transcript)));
        expect(result.nextStepText, isNot(contains(entry.transcript)));
      }
    });

    test('copy uses ArchiveMe and avoids banned language', () {
      final copy = FirstWeekPathCopy.allVisibleStrings.join(' ').toLowerCase();
      expect(copy, contains('archiveme'));
      _expectNoBannedCopy(FirstWeekPathCopy.allVisibleStrings);
    });
  });

  group('Archive Home integration', () {
    test('early users rank first week path on Archive Home', () {
      final plan = const ArchiveHomePriorityEngine().build(
        ArchiveHomePriorityInput(
          savedEntryCount: 1,
          usableEvidenceCount: 1,
          depthLevel: ArchiveDepthLevel.firstEvidence,
          returnChangesAvailable: false,
          weeklyReviewAvailable: false,
          sampleMode: false,
          proPreviewPromoVisible: false,
          showEmptySample: false,
          firstWeekPathVisible: true,
          dailyArchiveExerciseVisible: true,
          archiveClarityProgressVisible: true,
          capacityLoopVisible: false,
          capacityThreeMomentActivationVisible: false,
          capacityPullReasonVisible: false,
          capacityDecisionOutcomeVisible: false,
          capacityCostLaterCheckinVisible: false,
          capacityActivationFitVisible: false,
          beforeYouSayYesPauseVisible: false,
          capacityWeeklyReviewVisible: false,
          capacityBoundaryResponseVisible: false,
          thenVsNowVisible: false,
          archiveCalendarVisible: false,
          reviewRitualVisible: false,
          milestoneShareVisible: false,
        ),
      );

      expect(
        plan.primarySections,
        contains(ArchiveHomeSectionId.firstWeekPath),
      );
    });

    testWidgets('Archive Home shows compact card for early users', (
      tester,
    ) async {
      final entries = _realEntries(1);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: FirstWeekPathCard.test(
            entries: entries,
            initialResult: engine.build(_input(realSavedMomentCount: 1)),
          ),
        ),
      );

      expect(find.byKey(const Key('first_week_path_card')), findsOneWidget);
      expect(find.text(FirstWeekPathCopy.day2Next), findsOneWidget);
    });
  });

  group('Support and reviewer guide links', () {
    testWidgets('Support & feedback links to first week path', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const SupportFeedbackScreen(),
        ),
      );
      await tester.pump();

      expect(find.text(FirstWeekPathCopy.supportSectionTitle), findsOneWidget);
      expect(
        find.byKey(const Key('support_feedback_open_first_week_path')),
        findsOneWidget,
      );
      expect(find.text(FirstWeekPathCopy.openPathCta), findsOneWidget);
    });

    test('router registers first week path route', () {
      final router = File('lib/router/app_router.dart').readAsStringSync();
      final support = File(
        'lib/screens/support_feedback_screen.dart',
      ).readAsStringSync();
      expect(router, contains("path: '/first-week-path'"));
      expect(support, contains('FirstWeekPathCopy.route'));
    });

    test('Help & reviewer guide mentions guided first-week path', () {
      final bullets = HelpReviewerGuideCopy.sections
          .expand((section) => section.bullets)
          .join(' ')
          .toLowerCase();
      expect(bullets, contains('first week path'));
      expect(bullets, contains('guided'));
    });
  });

  group('Privacy and local-only behavior', () {
    test('engine does not include raw journal text in output', () {
      final entries = _realEntries(2);
      final privateText = entries.first.transcript;
      final result = engine.buildFromJournal(
        entries: entries,
        hasWatchTheme: false,
        betaFeedbackCaptured: false,
        hasWeeklyReviewAvailable: false,
      );

      expect(result.rewardText, isNot(contains(privateText)));
      expect(result.nextStepText, isNot(contains(privateText)));
      expect(result.cardBody, isNot(contains(privateText)));
    });

    test('support copy stays local-only', () {
      expect(
        FirstWeekPathCopy.supportSectionBody.toLowerCase(),
        contains('local'),
      );
      expect(
        FirstWeekPathCopy.supportSectionBody.toLowerCase(),
        contains('nothing is uploaded'),
      );
    });
  });
}
