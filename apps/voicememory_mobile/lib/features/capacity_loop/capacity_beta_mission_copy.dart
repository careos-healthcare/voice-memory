import 'capacity_beta_mission_models.dart';

/// Copy for the capacity beta trial mission — calm beta language.
abstract final class CapacityBetaMissionCopy {
  CapacityBetaMissionCopy._();

  static const route = '/capacity-beta-mission';

  static const title = 'Your 7-day capacity test';
  static const subtitle =
      'Save 3 real yes moments, review your loop, and tell us if it fits.';

  static const calmNote = 'This helps test whether ArchiveMe is useful.';
  static const skipNote = 'Skip anything that does not apply.';

  static const taskFirstYesMoment = 'Save your first yes moment';
  static const taskThreeYesMoments = 'Reach 3 yes moments';
  static const taskPullReason = 'Mark what pulled you toward yes';
  static const taskDecisionOutcome = 'Mark what you chose';
  static const taskLaterCost = 'Record whether it cost you later';
  static const taskReviewLoop = 'Review your yes loop';
  static const taskActivationFit = 'Tell us if the loop fits';
  static const taskWeeklyReview = 'Review this week';
  static const taskBoundaryResponse = 'Choose your default yes pause';
  static const taskProInterest = 'Would you pay to keep this archive?';

  static const statusNotStarted = 'not started';
  static const statusReady = 'ready';
  static const statusDone = 'done';
  static const statusOptional = 'optional';

  static const ctaSaveYesMoment = 'Save yes moment';
  static const ctaReviewLoop = 'Review yes loop';
  static const ctaAnswerFit = 'Answer fit check';
  static const ctaReviewWeek = 'Review this week';
  static const ctaChooseResponse = 'Choose response';
  static const ctaMarkPullReason = 'Mark pull reason';
  static const ctaMarkOutcome = 'Mark outcome';
  static const ctaRecordCost = 'Record later cost';
  static const ctaProInterest = 'Mark Pro interest';
  static const ctaViewBetaSignals = 'View beta signals';

  static const openMissionCta = 'Open 7-day capacity test';
  static const startMissionCta = 'Start 7-day capacity test';
  static const dismissCta = 'Hide for now';
  static const viewMissionCta = 'View mission';

  static const cardTitle = startMissionCta;
  static const cardBody =
      'Follow a simple 7-day path to test the capacity yes loop.';

  static const supportTitle = '7-day capacity test';
  static const supportSubtitle =
      'Guided steps for beta testers to reach activation and fit signals.';

  static const betaSignalsMissionLink = 'Back to 7-day capacity test';

  static String progressLabel(int completed, int total) =>
      '$completed of $total steps complete';

  static String labelForTask(String taskId) => switch (taskId) {
        CapacityBetaMissionTaskIds.firstYesMoment => taskFirstYesMoment,
        CapacityBetaMissionTaskIds.threeYesMoments => taskThreeYesMoments,
        CapacityBetaMissionTaskIds.pullReason => taskPullReason,
        CapacityBetaMissionTaskIds.decisionOutcome => taskDecisionOutcome,
        CapacityBetaMissionTaskIds.laterCost => taskLaterCost,
        CapacityBetaMissionTaskIds.reviewLoop => taskReviewLoop,
        CapacityBetaMissionTaskIds.activationFit => taskActivationFit,
        CapacityBetaMissionTaskIds.weeklyReview => taskWeeklyReview,
        CapacityBetaMissionTaskIds.boundaryResponse => taskBoundaryResponse,
        CapacityBetaMissionTaskIds.proInterest => taskProInterest,
        _ => '',
      };

  static List<String> allVisibleStrings() => [
        title,
        subtitle,
        calmNote,
        skipNote,
        taskFirstYesMoment,
        taskThreeYesMoments,
        taskPullReason,
        taskDecisionOutcome,
        taskLaterCost,
        taskReviewLoop,
        taskActivationFit,
        taskWeeklyReview,
        taskBoundaryResponse,
        taskProInterest,
        statusNotStarted,
        statusReady,
        statusDone,
        statusOptional,
        ctaSaveYesMoment,
        ctaReviewLoop,
        ctaAnswerFit,
        ctaReviewWeek,
        ctaChooseResponse,
        ctaMarkPullReason,
        ctaMarkOutcome,
        ctaRecordCost,
        ctaProInterest,
        ctaViewBetaSignals,
        openMissionCta,
        startMissionCta,
        dismissCta,
        viewMissionCta,
        cardTitle,
        cardBody,
        supportTitle,
        supportSubtitle,
        betaSignalsMissionLink,
        progressLabel(0, 9),
        progressLabel(4, 9),
      ];
}
