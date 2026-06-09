import '../activation/activation_loop_score_engine.dart';
import '../activation/activation_loop_score_model.dart';
import '../../services/app_services.dart';
import '../activation/activation_events_store.dart';
import '../activation/activation_summary_engine.dart';
import '../activation/first_loop_activation_store.dart';
import '../activation/return_day_friction_store.dart';
import '../activation/return_capture_metrics_store.dart';
import '../activation/watch_for_prompt_metrics_store.dart';
import '../input_quality/input_quality_store.dart';
import '../pattern_memory/habit_proof_store.dart';
import '../pattern_memory/pattern_memory_store.dart';
import '../pattern_memory/pattern_next_action_store.dart';
import '../pattern_memory/pattern_progress_store.dart';
import '../pattern_memory/weekly_pattern_recap_store.dart';
import '../tomorrow_return/check_in_reminder_service.dart';
import 'hook_diagnosis_store.dart';
import '../acquisition/acquisition_cohort_coordinator.dart';
import '../retention/retention_diagnosis_v2_coordinator.dart';
import '../retention/retention_metrics_tracker.dart';
import 'trial_summary_model.dart';

/// Builds a trial summary from local activation stores.
class TrialSummaryEngine {
  const TrialSummaryEngine();

  Future<TrialSummaryModel> build({DateTime? now}) async {
    final clock = now ?? DateTime.now();
    final prefs = AppServices.instance.prefs;
    await AcquisitionCohortCoordinator.syncMilestonesFromAppState();
    final acquisitionCohort = await AcquisitionCohortCoordinator.load();
    final metrics = RetentionMetricsStore.instance();
    final events = await ActivationEventsStore(prefs).read();
    final activation = await const ActivationSummaryEngine().build();
    final watch = await WatchForPromptMetricsStore(prefs).read();
    final capture = await ReturnCaptureMetricsStore(prefs).read();

    final watchForPromptShown =
        _max(events.watchForPromptShown, watch.shownCount);
    final watchForPromptAccepted =
        _max(events.watchForPromptAccepted, watch.acceptedCount);
    final returnCaptureQuickAnswerSelected = _max(
      events.returnCaptureQuickAnswerSelected,
      capture.quickAnswerSelectedCount,
    );

    final correctionRate = events.firstPatternShown == 0
        ? null
        : events.firstPatternCorrected / events.firstPatternShown;
    final watchForAcceptRate = watchForPromptShown == 0
        ? watch.acceptanceRate
        : watchForPromptAccepted / watchForPromptShown;
    final day2ReturnRate = events.firstPatternAccepted == 0
        ? null
        : events.returnedNextDay / events.firstPatternAccepted;
    final usefulDenom = events.usefulnessYes +
        events.usefulnessSortOf +
        events.usefulnessNotReally;
    final usefulRate = usefulDenom == 0
        ? null
        : (events.usefulnessYes + events.usefulnessSortOf) / usefulDenom;

    final recordingSavedCount = events.firstReflectionSaved +
        events.secondReflectionSaved +
        events.thirdReflectionSaved;

    final hookDiagnosis = await HookDiagnosisStore(prefs).summary();
    final patternMemory = await PatternMemoryStore(prefs).loadActive();
    final patternProgress = await PatternProgressStore(prefs).loadLatest();
    final patternNextAction = await PatternNextActionStore(prefs).loadLatest();
    final habitProof = await HabitProofStore(prefs).loadLatest();
    final weeklyRecap = await WeeklyPatternRecapStore(prefs).loadLatest();
    final firstLoop = await FirstLoopActivationStore(prefs).load();
    final returnDay = await ReturnDayFrictionStore(prefs).load();
    final returnDayCompletionRate = events.returnDayDueShown == 0
        ? null
        : events.returnDayLoopClosed / events.returnDayDueShown;
    final remindersEnabled = await CheckInReminderService.remindersEnabled();
    final inputQuality = await InputQualityStore(prefs).read();
    final activationLoop = buildActivationLoopScore(events);

    return TrialSummaryModel(
      participantId: events.participantId,
      generatedAt: clock,
      firstReflectionSaved: events.firstReflectionSaved,
      firstPatternShown: events.firstPatternShown,
      firstPatternAccepted: events.firstPatternAccepted,
      firstPatternCorrected: _max(
        events.firstPatternCorrected,
        activation.firstPatternCorrectionCount,
      ),
      watchForPromptShown: watchForPromptShown,
      watchForPromptAccepted: watchForPromptAccepted,
      returnCaptureQuickAnswerSelected: returnCaptureQuickAnswerSelected,
      returnedNextDay: events.returnedNextDay,
      secondReflectionSaved: events.secondReflectionSaved,
      comparisonViewed: events.comparisonViewed,
      usefulnessYes: events.usefulnessYes,
      usefulnessSortOf: events.usefulnessSortOf,
      usefulnessNotReally: events.usefulnessNotReally,
      thirdReflectionSaved: events.thirdReflectionSaved,
      appOpenedCount: events.trialAppOpened,
      recordCtaTappedCount: events.trialRecordCtaTapped,
      recordingStartedCount: events.trialRecordingStarted,
      recordingSavedCount: recordingSavedCount,
      micDeniedCount: events.trialMicPermissionDenied,
      saveCompletedCount: events.trialSaveCompleted,
      closedBeforeWatchForAcceptedCount:
          events.trialClosedBeforeWatchForAccepted,
      trialFrictionVerdict: frictionVerdict(events),
      checkInCreatedCount: events.tomorrowCheckInCreated,
      checkInDueShownCount: events.tomorrowCheckInDueShown,
      checkInOptionSelectedCount: events.tomorrowCheckInOptionSelected,
      checkInCompletedCount: events.tomorrowCheckInCompleted,
      checkInCompletionRate: events.tomorrowCheckInCreated == 0
          ? null
          : events.tomorrowCheckInCompleted / events.tomorrowCheckInCreated,
      correctionRate: correctionRate,
      watchForAcceptRate: watchForAcceptRate,
      day2ReturnRate: day2ReturnRate,
      usefulRate: usefulRate,
      verdict: _verdict(events),
      hookDiagnosis: hookDiagnosis,
      reminderScheduledCount: events.reminderScheduled,
      reminderDeniedCount: events.reminderPermissionDenied,
      reminderPluginAvailable: CheckInReminderService.pluginAvailable,
      reminderPermissionRequestedCount: events.reminderPermissionRequested,
      reminderPermissionGrantedCount: events.reminderPermissionGranted,
      reminderPermissionDeniedCount: events.reminderPermissionDenied,
      reminderCancelledCount: events.reminderCancelled,
      reminderTappedCount: events.reminderTapped,
      reminderEnabled: remindersEnabled,
      patternMemoryCreatedCount: events.patternMemoryCreated,
      patternMemoryUpdatedCount: events.patternMemoryUpdated,
      patternMemoryCheckInCount: patternMemory?.checkInCount ?? 0,
      activePatternMemoryStatus: patternMemory?.status,
      patternProgressMomentCreatedCount: events.patternProgressMomentCreated,
      patternProgressCardShownCount: events.patternProgressCardShown,
      latestPatternProgressType: patternProgress?.type,
      patternNextActionCreatedCount: events.patternNextActionCreated,
      patternNextActionUsedCount: events.patternNextActionUsed,
      latestPatternNextActionType: patternNextAction?.type,
      habitProofCreatedCount: events.habitProofCreated,
      habitProofShownCount: events.habitProofShown,
      habitProofCtaTappedCount: events.habitProofCtaTapped,
      latestHabitProofType: habitProof?.type,
      weeklyPatternRecapCreatedCount: events.weeklyPatternRecapCreated,
      weeklyPatternRecapShownCount: events.weeklyPatternRecapShown,
      weeklyPatternRecapCtaTappedCount: events.weeklyPatternRecapCtaTapped,
      latestWeeklyPatternRecapType: weeklyRecap?.type,
      patternShareCardShownCount: events.patternShareCardShown,
      patternShareCopiedCount: events.patternShareCopied,
      patternShareOpenedCount: events.patternShareOpened,
      patternShareFailedCount: events.patternShareFailed,
      firstLoopStage: firstLoop.stage,
      firstLoopCompleted: firstLoop.isComplete,
      secondsToFirstSave: firstLoop.secondsToFirstSave,
      secondsToLoopReady: firstLoop.secondsToLoopReady,
      firstLoopDropoffPoint: firstLoop.dropoffPoint,
      returnDayDueShownCount: events.returnDayDueShown,
      returnDayAnswerSelectedCount: events.returnDayAnswerSelected,
      returnDayLoopClosedCount: events.returnDayLoopClosed,
      latestSecondsToAnswer: returnDay.secondsToAnswer,
      latestSecondsToLoopClosed: returnDay.secondsToLoopClosed,
      returnDayCompletionRate: returnDayCompletionRate,
      returnDayDropoffPoint: returnDay.dropoffPoint,
      sharperQuestionGeneratedCount: events.sharperQuestionShown,
      verySharpQuestionGeneratedCount: events.sharperQuestionAggressiveShown,
      sharperQuestionAcceptedCount: events.sharperQuestionAccepted,
      verySharpQuestionAcceptedCount: events.sharperQuestionAggressiveAccepted,
      betterResultShownCount: events.betterResultShown,
      aggressiveBetterResultShownCount: events.betterResultAggressiveShown,
      checkInGoDeeperShownCount: events.checkInGoDeeperShown,
      checkInGoDeeperTappedCount: events.checkInGoDeeperTapped,
      resultNextCheckShownCount: events.resultNextCheckShown,
      resultNextCheckUsedCount: events.resultNextCheckUsed,
      resultNextCheckChangedCount: events.resultNextCheckChanged,
      resultNextCheckUsedFromPatternsCount:
          events.resultNextCheckUsedFromPatterns,
      usefulResultTakeawayShownCount: events.usefulResultTakeawayShown,
      makeResultMoreUsefulTappedCount: events.makeResultMoreUsefulTapped,
      makeResultMoreUsefulReasonSelectedCount:
          events.makeResultMoreUsefulReasonSelected,
      usefulResultNextCheckUsedCount: events.usefulResultNextCheckUsed,
      inputQualityCoachShownCount: events.inputQualityCoachShown,
      inputQualitySentenceAddedCount: events.inputQualitySentenceAdded,
      inputQualityUsedAnywayCount: events.inputQualityUsedAnyway,
      acceptedWeakInputCount: _max(
        events.acceptedWeakInputCount,
        inputQuality.acceptedWeakInputCount,
      ),
      sharpenedInputCount: _max(
        events.sharpenedInputCount,
        inputQuality.sharpenedInputCount,
      ),
      latestInputQualityLevel: inputQuality.lastQualityLevel?.name,
      averageInputQualityScore: inputQuality.averageInputQualityScore,
      perspectiveShiftShownCount: events.perspectiveShiftShown,
      perspectiveShiftChangedCount: events.perspectiveShiftChanged,
      perspectiveShiftUsedCount: events.perspectiveShiftUsed,
      perspectiveShiftShownFromPatternsCount:
          events.perspectiveShiftShownFromPatterns,
      perspectiveShiftUsedFromPatternsCount:
          events.perspectiveShiftUsedFromPatterns,
      kinderAngleShownCount: events.kinderAngleShown,
      kinderAngleUsedCount: events.kinderAngleUsed,
      kinderAngleChangedCount: events.kinderAngleChanged,
      kinderAngleShownFromPatternsCount: events.kinderAngleShownFromPatterns,
      kinderAngleUsedFromPatternsCount: events.kinderAngleUsedFromPatterns,
      quickHelpOpenedCount: events.quickHelpOpened,
      quickHelpIntentSelectedCount: events.quickHelpIntentSelected,
      quickHelpPrimaryActionTappedCount: events.quickHelpPrimaryActionTapped,
      quickHelpCheckUsedCount: events.quickHelpCheckUsed,
      keyMomentCreatedCount: events.keyMomentCreated,
      keyMomentOpenedCount: events.keyMomentOpened,
      keyMomentSearchUsedCount: events.keyMomentSearchUsed,
      keyMomentUseCheckTappedCount: events.keyMomentUseCheckTapped,
      askArchiveOpenedCount: events.askArchiveOpened,
      askArchiveSearchUsedCount: events.askArchiveSearchUsed,
      askArchiveSuggestedChipTappedCount: events.askArchiveSuggestedChipTapped,
      askArchiveResultOpenedCount: events.askArchiveResultOpened,
      askArchiveUseCheckTappedCount: events.askArchiveUseCheckTapped,
      archiveCleanViewShownCount: events.archiveCleanViewShown,
      archiveCleanSectionTappedCount: events.archiveCleanSectionTapped,
      patternProfileShownCount: events.patternProfileShown,
      patternProfileOpenedCount: events.patternProfileOpened,
      patternProfileUseCheckTappedCount: events.patternProfileUseCheckTapped,
      patternProfileFindMomentsTappedCount:
          events.patternProfileFindMomentsTapped,
      patternProfileOpenTimelineTappedCount:
          events.patternProfileOpenTimelineTapped,
      patternMapShownCount: events.patternMapShown,
      patternMapOpenedCount: events.patternMapOpened,
      patternMapUseCheckTappedCount: events.patternMapUseCheckTapped,
      archiveFeedbackShownCount: events.archiveFeedbackShown,
      archiveFeedbackSelectedCount: events.archiveFeedbackSelected,
      archiveFeedbackUsefulCount: events.archiveFeedbackUseful,
      archiveFeedbackTooGenericCount: events.archiveFeedbackTooGeneric,
      archiveFeedbackNotMeCount: events.archiveFeedbackNotMe,
      archiveFeedbackAlreadyKnewCount: events.archiveFeedbackAlreadyKnew,
      archiveFeedbackMoreSpecificCount: events.archiveFeedbackMoreSpecific,
      archiveCompressionShownCount: events.archiveCompressionShown,
      archiveCompressionOpenedCount: events.archiveCompressionOpened,
      archiveCompressionKeptCount: events.archiveCompressionKept,
      archiveCompressionSplitCount: events.archiveCompressionSplit,
      archiveCompressionHiddenCount: events.archiveCompressionHidden,
      memoryQualityShownCount: events.memoryQualityShown,
      memoryQualityTappedCount: events.memoryQualityTapped,
      latestMemoryQualityLevel: events.latestMemoryQualityLevel,
      paywallShownCount: events.paywallShown,
      paywallTriggerShownCount: events.paywallTriggerShown,
      annualPlanShownCount: events.annualPlanShown,
      monthlyPlanShownCount: events.monthlyPlanShown,
      annualPlanSelectedCount: events.annualPlanSelected,
      monthlyPlanSelectedCount: events.monthlyPlanSelected,
      paywallContinueTappedCount: events.paywallContinueTapped,
      paywallDismissedCount: events.paywallDismissed,
      restoreTappedCount: events.restoreTapped,
      archiveRangeReviewShownCount: events.archiveRangeReviewShown,
      archiveRangeReviewOpenedCount: events.archiveRangeReviewOpened,
      archiveRangeReviewUseCheckTappedCount:
          events.archiveRangeReviewUseCheckTapped,
      archiveRangeReviewPresetChangedCount:
          events.archiveRangeReviewPresetChanged,
      retentionStateShownCount: events.retentionStateShown,
      retentionDueShownCount: events.retentionDueShown,
      retentionCheckSetShownCount: events.retentionCheckSetShown,
      retentionLoopClosedShownCount: events.retentionLoopClosedShown,
      retentionPrimaryCtaTappedCount: events.retentionPrimaryCtaTapped,
      retentionNextCheckReadyCount: events.retentionNextCheckReady,
      retentionMissedCheckCount: events.retentionMissedCheck,
      reminderScheduledFromRetentionCount:
          events.reminderScheduledFromRetention,
      compellingCheckShownCount: events.compellingCheckShown,
      compellingCheckSelectedCount: events.compellingCheckSelected,
      compellingCheckMostSpecificSelectedCount:
          events.compellingCheckMostSpecificSelected,
      compellingCheckAcceptedCount: events.compellingCheckAccepted,
      realReminderPermissionRequestedCount:
          events.realReminderPermissionRequested,
      realReminderPermissionGrantedCount:
          events.realReminderPermissionGranted,
      realReminderPermissionDeniedCount:
          events.realReminderPermissionDenied,
      realReminderScheduledCount: events.realReminderScheduled,
      realReminderCancelledCount: events.realReminderCancelled,
      realReminderUnavailableCount: events.realReminderUnavailable,
      currentObjectiveShownCount: events.currentObjectiveShown,
      currentObjectivePrimaryTappedCount: events.currentObjectivePrimaryTapped,
      currentObjectiveSecondaryTappedCount:
          events.currentObjectiveSecondaryTapped,
      latestCurrentObjectiveType: events.latestCurrentObjectiveType,
      proValuePreviewShownCount: events.proValuePreviewShown,
      proValuePreviewUnlockTappedCount: events.proValuePreviewUnlockTapped,
      proValuePreviewDismissedCount: events.proValuePreviewDismissed,
      latestProValuePreviewType: events.latestProValuePreviewType,
      objectiveWidgetRefreshAttemptedCount:
          events.objectiveWidgetRefreshAttempted,
      objectiveWidgetRefreshSucceededCount:
          events.objectiveWidgetRefreshSucceeded,
      objectiveWidgetRefreshFailedCount: events.objectiveWidgetRefreshFailed,
      objectiveWidgetClearedCount: events.objectiveWidgetCleared,
      archiveMemorySummaryShownCount: events.archiveMemorySummaryShown,
      archiveMemoryOpenPatternMapTappedCount:
          events.archiveMemoryOpenPatternMapTapped,
      archiveMemoryFindMomentsTappedCount:
          events.archiveMemoryFindMomentsTapped,
      archiveMemoryUseCheckTappedCount: events.archiveMemoryUseCheckTapped,
      archiveTimelineShownCount: events.archiveTimelineShown,
      archiveTimelineOpenedCount: events.archiveTimelineOpened,
      archiveTimelineUseCheckTappedCount: events.archiveTimelineUseCheckTapped,
      positioningComprehensionAskedCount: events.positioningComprehensionAsked,
      positioningComprehensionAnsweredCount:
          events.positioningComprehensionAnswered,
      positioningUnderstoodArchiveMemoryCount:
          events.positioningUnderstoodArchiveMemory,
      positioningJournalCount: events.positioningJournal,
      positioningChatCount: events.positioningChat,
      positioningNotSureCount: events.positioningNotSure,
      activationFullLoopCompletedCount:
          activationLoop.completedFullLoop ? 1 : 0,
      activationWeakestBucket: activationLoop.weakestBucket.id,
      activationSavedFirstMoment: activationLoop.savedFirstMoment,
      activationChoseTomorrowCheck: activationLoop.choseTomorrowCheck,
      activationReturnedNextDay: activationLoop.returnedNextDay,
      activationClosedLoop: activationLoop.closedLoop,
      activationRatedUsefulOrSortOf: activationLoop.ratedUsefulOrSortOf,
      activationChoseNextCheck: activationLoop.choseNextCheck,
      retentionDiagnosisSnapshot:
          await RetentionDiagnosisV2Coordinator.build(),
      acquisitionCohort: acquisitionCohort,
      capacityInviteCopiedCount: await metrics.count(
        RetentionMetricsTracker.capacityInviteCopied,
      ),
      proveInviteCopiedCount: await metrics.count(
        RetentionMetricsTracker.proveInviteCopied,
      ),
      genericInviteCopiedCount: await metrics.count(
        RetentionMetricsTracker.genericInviteCopied,
      ),
      proveDefaultShownCount: await metrics.count(
        RetentionMetricsTracker.proveDefaultShown,
      ),
      proveDefaultStartedCount: await metrics.count(
        RetentionMetricsTracker.proveDefaultStarted,
      ),
      proveFirstMomentRecordedCount: await metrics.count(
        RetentionMetricsTracker.proveFirstMomentRecorded,
      ),
      proveReadAcceptedCount: await metrics.count(
        RetentionMetricsTracker.proveReadAccepted,
      ),
      proveSecondMomentRecordedCount: await metrics.count(
        RetentionMetricsTracker.proveSecondMomentRecorded,
      ),
      proveReviewConfirmedCount: await metrics.count(
        RetentionMetricsTracker.proveReviewConfirmed,
      ),
      provePaywallTeaserTappedCount: await metrics.count(
        RetentionMetricsTracker.provePaywallTeaserTapped,
      ),
    );
  }

  TrialSummaryVerdict _verdict(ActivationEventCounts events) {
    if (events.firstPatternAccepted >= 1 &&
        events.watchForPromptAccepted >= 1 &&
        events.returnedNextDay >= 1 &&
        events.usefulnessYes + events.usefulnessSortOf >= 1) {
      return TrialSummaryVerdict.promising;
    }

    if (events.firstReflectionSaved >= 1 &&
        (events.watchForPromptAccepted == 0 || events.returnedNextDay == 0)) {
      return TrialSummaryVerdict.weak;
    }

    return TrialSummaryVerdict.unclear;
  }

  int _max(int a, int b) => a > b ? a : b;
}

/// Exported for unit tests.
TrialFrictionVerdict frictionVerdict(ActivationEventCounts events) {
  if (events.trialMicPermissionDenied > 0) {
    return TrialFrictionVerdict.permissionIssue;
  }
  if (events.trialAppOpened > 0 && events.trialRecordingStarted == 0) {
    return TrialFrictionVerdict.recordFriction;
  }
  if (events.firstReflectionSaved > 0 && events.watchForPromptAccepted == 0) {
    return TrialFrictionVerdict.hookIssue;
  }
  if (events.firstReflectionSaved > 0 && events.watchForPromptAccepted > 0) {
    return TrialFrictionVerdict.clean;
  }
  return TrialFrictionVerdict.unclear;
}
