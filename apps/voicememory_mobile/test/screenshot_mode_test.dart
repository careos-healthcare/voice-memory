import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/config/screenshot_mode.dart';
import 'package:voicememory_mobile/features/archive_review/archive_range_review_engine.dart';
import 'package:voicememory_mobile/config/screenshot_sample_data.dart';
import 'package:voicememory_mobile/features/activation/first_loop_activation_model.dart';
import 'package:voicememory_mobile/features/activation/first_three_journey_engine.dart';
import 'package:voicememory_mobile/features/activation/first_three_session_copy.dart';
import 'package:voicememory_mobile/features/tomorrow_return/return_capture_model.dart';
import 'package:voicememory_mobile/features/tomorrow_return/tomorrow_check_in_model.dart';
import 'package:voicememory_mobile/features/tomorrow_return/watch_for_model.dart';
import 'package:voicememory_mobile/features/trial/hook_rescue_decision_model.dart';

void main() {
  test('screenshot mode is off by default in tests', () {
    expect(ScreenshotMode.enabled, isFalse);
  });

  test('hook-fix preview is inert when screenshot mode is off', () {
    expect(ScreenshotMode.hookFix, isNull);
    expect(
      ScreenshotMode.screenshotSharperIntensity,
      HookRescueIntensity.normal,
    );
    expect(ScreenshotMode.screenshotBetterResult, isFalse);
    expect(
      ScreenshotMode.screenshotBetterResultIntensity,
      HookRescueIntensity.normal,
    );
  });

  test('result-next-check preview is inert when screenshot mode is off', () {
    expect(ScreenshotMode.resultNextCheckPreview, isFalse);
  });

  test('useful-result preview is inert when screenshot mode is off', () {
    expect(ScreenshotMode.usefulResultPreview, isFalse);
    expect(ScreenshotMode.completedCheckInPreview, isFalse);
  });

  test('activation rescue preview is inert when screenshot mode is off', () {
    expect(ScreenshotMode.activationRescue, isNull);
    expect(ScreenshotMode.activationRescueFirstRecordPreview, isFalse);
    expect(ScreenshotMode.activationRescueTomorrowCheckPreview, isFalse);
    expect(ScreenshotMode.activationRescueUsefulResultPreview, isFalse);
    expect(ScreenshotMode.activationRescueNextCheckPreview, isFalse);
  });

  test('compelling check preview is inert when screenshot mode is off', () {
    expect(ScreenshotMode.compellingCheckPreview, isFalse);
    expect(ScreenshotMode.realReminderPreview, isFalse);
  });

  test('compelling check sample has question, why, and example', () {
    final sample = ScreenshotSampleData.compellingCheckSample;
    expect(sample.question, isNotEmpty);
    expect(sample.whyThisCheck, contains('useful'));
    expect(sample.exampleAnswer, isNotEmpty);
  });

  test('objective preview is inert when screenshot mode is off', () {
    expect(ScreenshotMode.objective, isNull);
    expect(ScreenshotMode.objectiveDueCheckPreview, isFalse);
    expect(ScreenshotMode.objectiveFirstMomentPreview, isFalse);
    expect(ScreenshotMode.objectiveNextReadyPreview, isFalse);
  });

  test('objective samples have title and body', () {
    expect(ScreenshotSampleData.objectiveDueCheckSample.title, isNotEmpty);
    expect(ScreenshotSampleData.objectiveFirstMomentSample.body, isNotEmpty);
    expect(
      ScreenshotSampleData.objectiveNextReadySample.checkQuestion,
      isNotNull,
    );
  });

  test('retention preview is inert when screenshot mode is off', () {
    expect(ScreenshotMode.retention, isNull);
    expect(ScreenshotMode.retentionCheckSetPreview, isFalse);
    expect(ScreenshotMode.retentionDueTodayPreview, isFalse);
    expect(ScreenshotMode.retentionLoopClosedPreview, isFalse);
    expect(ScreenshotMode.retentionNextReadyPreview, isFalse);
  });

  test('kindness preview is inert when screenshot mode is off', () {
    expect(ScreenshotMode.kindnessPreview, isFalse);
    expect(ScreenshotMode.completedCheckInPreview, isFalse);
  });

  test('quick-help preview is inert when screenshot mode is off', () {
    expect(ScreenshotMode.quickHelpPreview, isFalse);
  });

  test('key-moments preview is inert when screenshot mode is off', () {
    expect(ScreenshotMode.keyMomentsPreview, isFalse);
  });

  test('key moments sample has three days with results', () {
    final moments = ScreenshotSampleData.keyMomentsSample;
    expect(moments, hasLength(3));
    expect(moments.first.resultHint, 'heavier');
    expect(moments.first.originalText, contains('said yes'));
    expect(moments[1].resultHint, 'lighter');
    expect(moments[2].resultHint, 'changed');
  });

  test('pattern-map preview is inert when screenshot mode is off', () {
    expect(ScreenshotMode.patternMapPreview, isFalse);
  });

  test('pattern map sample is a filled-in recurring pattern', () {
    final map = ScreenshotSampleData.patternMapSample;
    expect(map.seenCount, 8);
    expect(map.usuallyStartsBefore, 'before saying yes');
    expect(map.getsLighterWhen, 'pausing before answering');
    expect(map.hasNextCheck, isTrue);
  });

  test('feedback preview is inert when screenshot mode is off', () {
    expect(ScreenshotMode.feedbackPreview, isFalse);
  });

  test('archive memory preview is inert when screenshot mode is off', () {
    expect(ScreenshotMode.archiveMemoryPreview, isFalse);
  });

  test('archive timeline preview is inert when screenshot mode is off', () {
    expect(ScreenshotMode.archiveTimelinePreview, isFalse);
  });

  test('positioning rescue preview is inert when screenshot mode is off', () {
    expect(ScreenshotMode.positioningRescuePreview, isFalse);
  });

  test('ask archive preview is inert when screenshot mode is off', () {
    expect(ScreenshotMode.askArchivePreview, isFalse);
  });

  test('archive clean preview is inert when screenshot mode is off', () {
    expect(ScreenshotMode.archiveCleanPreview, isFalse);
  });

  test('pattern profile preview is inert when screenshot mode is off', () {
    expect(ScreenshotMode.patternProfilePreview, isFalse);
  });

  test('patterns clean preview is inert when screenshot mode is off', () {
    expect(ScreenshotMode.patternsCleanPreview, isFalse);
  });

  test('record clean preview is inert when screenshot mode is off', () {
    expect(ScreenshotMode.recordClean, isNull);
    expect(ScreenshotMode.recordCleanFirstRunPreview, isFalse);
    expect(ScreenshotMode.recordCleanDueCheckPreview, isFalse);
    expect(ScreenshotMode.recordCleanPostSavePreview, isFalse);
  });

  test('archive compression preview is inert when screenshot mode is off', () {
    expect(ScreenshotMode.archiveCompressionPreview, isFalse);
  });

  test('memory quality preview is inert when screenshot mode is off', () {
    expect(ScreenshotMode.memoryQualityPreview, isFalse);
  });

  test('archive review preview is inert when screenshot mode is off', () {
    expect(ScreenshotMode.archiveReviewPreview, isFalse);
  });

  test('archive review sample has six moments this week', () {
    expect(ScreenshotSampleData.archiveReviewMomentsSample.length, 6);
    final review = buildArchiveRangeReview(
      moments: ScreenshotSampleData.archiveReviewMomentsSample,
      now: ScreenshotSampleData.archiveReviewPreviewDay,
    );
    expect(review.hasEnoughData, isTrue);
    expect(review.title, 'This week');
  });

  test('memory quality sample shows clear pattern chip', () {
    final quality = ScreenshotSampleData.memoryQualitySample;
    expect(quality.label, 'Clear pattern');
    expect(quality.level.name, 'clearPattern');
    expect(quality.momentCount, 8);
    expect(quality.shouldShow, isTrue);
  });

  test('archive compression sample has five moments across two weeks', () {
    final group = ScreenshotSampleData.archiveCompressionGroupSample;
    expect(group.title, 'Taking responsibility before asking for help');
    expect(group.count, 5);
    expect(group.dateRangeLabel, '2 weeks');
    expect(group.tags, contains('pressure'));
    expect(group.tags, contains('work'));
    expect(group.tags, contains('helped'));
  });

  test('archive evolution sample has four grounded events', () {
    final timeline = ScreenshotSampleData.archiveEvolutionTimelineSample;
    expect(timeline.eventCount, 4);
    expect(timeline.events.length, 4);
    expect(timeline.events.first.title, 'First seen');
    expect(timeline.events.last.title, 'Check chosen');
  });

  test('archive memory sample is a filled-in remembered pattern', () {
    final summary = ScreenshotSampleData.archiveMemorySummarySample;
    expect(
      summary.primaryMemoryLine,
      'You often take responsibility before asking for help.',
    );
    expect(summary.clarityLabel, 'Clear pattern');
    expect(summary.basedOnMomentCount, 8);
    expect(summary.basedOnWeekCount, 3);
    expect(summary.hasNextCheck, isTrue);
  });

  test('input-quality preview is inert when screenshot mode is off', () {
    expect(ScreenshotMode.inputQuality, isNull);
    expect(ScreenshotMode.inputQualityCoachPreview, isFalse);
  });

  test('language preview is inert when screenshot mode is off', () {
    expect(ScreenshotMode.language, isNull);
    expect(ScreenshotMode.languageCode, 'en');
  });

  test('completed check-in sample is a closed loop with a result', () {
    final completed = ScreenshotSampleData.tomorrowCheckInCompletedSample;
    expect(completed.isCompleted, isTrue);
    expect(completed.selectedOptionId, 'showed_up_again');
    expect(completed.resultHeadline, 'It showed up again.');
  });

  test('screenshot sample data is populated for marketing captures', () {
    final beliefs = ScreenshotSampleData.beliefsSnapshot;
    expect(
      beliefs.current.first.statement,
      contains('keeping everything together'),
    );
    expect(beliefs.stats.reflectionsAnalysed, 12);
    expect(beliefs.current.first.confidencePercent, 78);
    expect(beliefs.current.first.timeline.length, 3);
    expect(
      ScreenshotSampleData.changingStories.first.detail,
      contains('cost of carrying everything alone'),
    );
    expect(ScreenshotSampleData.insightsSnapshot.blindSpots, isNotEmpty);
    expect(
      ScreenshotSampleData.insightsSnapshot.blindSpots.first.summary,
      contains('support you need'),
    );
    expect(
      ScreenshotSampleData
          .insightsSnapshot
          .strongestBelief
          ?.supportingEvidence
          .length,
      3,
    );
    expect(
      ScreenshotSampleData.returnLoopTodayNoticed,
      contains('responsibility'),
    );
    expect(ScreenshotSampleData.returnLoopWatchChips, hasLength(3));
    expect(
      ScreenshotSampleData.tomorrowReturnLoop.displayTomorrowPrompt,
      contains('Tomorrow'),
    );
    final commitment = ScreenshotSampleData.tomorrowCommitmentForPreview(
      DateTime(2026, 5, 25),
    );
    expect(commitment.watchForChips, hasLength(3));
    expect(commitment.promptText, contains('responsibility'));
    final comparison = ScreenshotSampleData.returnComparisonSample;
    expect(comparison.headline, contains('showed up again'));
    expect(comparison.chips, hasLength(3));
    expect(ScreenshotSampleData.returnStreakSample.currentStreakDays, 3);
    expect(
      ScreenshotSampleData.changeSummarySample.title,
      contains('still here'),
    );
    expect(ScreenshotSampleData.weeklyRecapSample.title, contains('week'));
    final watchPending = ScreenshotSampleData.watchForPendingForToday(
      DateTime(2026, 5, 26),
    );
    expect(watchPending.text, ScreenshotSampleData.watchForSpecificPrompt);
    expect(watchPending.checkInQuestion, isNotEmpty);
    expect(watchPending.chips, hasLength(3));
    final watchDone = ScreenshotSampleData.watchForCompletedSample;
    expect(watchDone.result.name, 'showedAgain');
    expect(
      ScreenshotSampleData.watchForCompletedHeadline,
      contains('showed up again'),
    );
    expect(
      ScreenshotSampleData.watchForCompletedBody,
      contains('responsibility'),
    );
    final thread = ScreenshotSampleData.activePatternThreadSample;
    expect(thread.title, contains('Taking responsibility'));
    expect(thread.daysActive, 3);
    expect(thread.lastResult, WatchForResult.showedAgain);
    expect(thread.nextPrompt, contains('Today, notice'));
    final first = ScreenshotSampleData.firstSessionPatternSample;
    expect(first.title, contains('Taking responsibility'));
    expect(
      ScreenshotSampleData.firstSessionWhyNoticed,
      contains('responsibility'),
    );
    final journey0 = ScreenshotSampleData.firstThreeJourneyForCount(0);
    expect(journey0.progressLabel, 'Start your archive');
    expect(journey0.nextAction, 'Record one moment');
    final journey3 = ScreenshotSampleData.firstThreeJourneyForCount(3);
    expect(journey3.completed, isTrue);
    expect(journey3.nextAction, 'View archive');
    expect(
      const FirstThreeJourneyEngine().build(reflectionCount: 2).title,
      FirstThreeSessionCopy.session2StartingToNoticeTitle,
    );
  });

  test('return capture selection defaults in screenshot mode when enabled', () {
    if (!ScreenshotMode.enabled) {
      expect(ScreenshotMode.returnCaptureSelection, isNull);
      return;
    }
    final selection = ScreenshotMode.returnCaptureSelection;
    expect(selection, isNotNull);
    expect(selection!.comparisonHint, isNotEmpty);
  });

  test('tomorrow check-in due sample has pattern and question', () {
    final checkIn = ScreenshotSampleData.tomorrowCheckInDueSample;
    expect(
      checkIn.patternTitle,
      'Taking responsibility before asking for help',
    );
    expect(checkIn.question, 'Did you ask for help, or carry it alone?');
    expect(checkIn.options, kDefaultTomorrowCheckInOptions);
    expect(ScreenshotMode.recordCheckInDuePreview, isFalse);
  });

  test('pattern memory sample has counts and next question', () {
    final memory = ScreenshotSampleData.patternMemorySample;
    expect(memory.patternTitle, 'Taking responsibility before asking for help');
    expect(memory.checkInCount, 4);
    expect(memory.showedAgainCount, 2);
    expect(memory.lighterCount, 1);
    expect(memory.heavierCount, 1);
    expect(memory.status.name, 'active');
    expect(memory.commonBeforeMoments, hasLength(2));
    expect(memory.helpedMoments, contains('paused before answering'));
    expect(memory.nextBestQuestion, 'What happens right before it shows up?');
  });

  test('pattern progress sample shows the what-changed payoff', () {
    final progress = ScreenshotSampleData.patternProgressSample;
    expect(progress.type.name, 'stillRepeating');
    expect(progress.headline, 'This pattern is still showing up.');
    expect(progress.body, contains('caught it 4 times'));
    expect(progress.beforeLine, 'It often starts around: before saying yes');
    expect(
      progress.nextLine,
      'Next, watch what happens right before it starts.',
    );
    expect(progress.shouldShow, isTrue);
  });

  test('pattern next action sample offers the next useful check', () {
    final action = ScreenshotSampleData.patternNextActionSample;
    expect(action.type.name, 'repeatCheck');
    expect(action.title, 'Check what happens before it starts');
    expect(action.question, 'What happens right before it shows up?');
    expect(action.ctaLabel, 'Use this check');
  });

  test('habit proof sample shows why checking is useful', () {
    final proof = ScreenshotSampleData.habitProofSample;
    expect(proof.type.name, 'progressFound');
    expect(proof.headline, 'Now there is something to compare.');
    expect(proof.proofLine, 'This pattern is still showing up.');
    expect(proof.nextLine, 'What happens right before it shows up?');
    expect(proof.shouldShow, isTrue);
  });

  test('weekly pattern recap sample shows what repeated this week', () {
    final recap = ScreenshotSampleData.weeklyPatternRecapSample;
    expect(recap.type.name, 'repeated');
    expect(recap.headline, 'This pattern kept showing up this week.');
    expect(recap.body, 'You checked it 4 times and caught it more than once.');
    expect(recap.usefulLine, 'It often starts around: before saying yes');
    expect(recap.nextQuestion, 'What happens right before it starts?');
    expect(recap.shouldShow, isTrue);
  });

  test('pattern share recap sample is keepable text', () {
    final recap = ScreenshotSampleData.patternShareRecapSample;
    expect(recap.type.name, 'weekly');
    expect(recap.title, 'This week\u2019s pattern');
    expect(recap.body, 'This pattern kept showing up this week.');
    expect(
      recap.lines,
      contains('You checked it 4 times and caught it more than once.'),
    );
    expect(recap.lines, contains('It often starts around: before saying yes'));
    expect(recap.plainText, contains('Made with ArchiveMe'));
  });

  test('journey step override is inactive in unit tests', () {
    expect(ScreenshotMode.screenshotJourneyReflectionCount, -1);
    expect(ScreenshotMode.journeyStep, isEmpty);
  });

  test('first-loop stage is inactive in unit tests', () {
    expect(ScreenshotMode.firstLoopStage, isNull);
  });

  test('first-loop screenshot stages map to sample states', () {
    final start = ScreenshotSampleData.firstLoopStateFor('start');
    expect(start.stage, FirstLoopActivationStage.openedRecord);
    expect(start.isComplete, isFalse);

    final saved = ScreenshotSampleData.firstLoopStateFor('saved');
    expect(saved.stage, FirstLoopActivationStage.firstMomentSaved);
    expect(saved.hasFirstMoment, isTrue);

    final choosing = ScreenshotSampleData.firstLoopStateFor('choosing');
    expect(choosing.stage, FirstLoopActivationStage.firstPatternShown);
    expect(choosing.firstPatternTitle, isNotNull);

    final ready = ScreenshotSampleData.firstLoopStateFor('ready');
    expect(ready.stage, FirstLoopActivationStage.loopReady);
    expect(ready.isComplete, isTrue);
    expect(ready.tomorrowQuestion, isNotNull);
  });
}
