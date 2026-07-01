import 'dart:async';

import '../../config/trial_mode.dart';
import '../archive_memory/memory_quality_model.dart';
import '../feedback/archive_feedback_model.dart';
import '../trial/positioning_comprehension_model.dart';
import '../../services/app_services.dart';
import '../../services/product_analytics.dart';
import 'activation_events_store.dart';
import 'first_pattern_correction_store.dart';
import '../quality/first_insight_specificity_store.dart';
import '../beta/beta_activation_loop_tracker.dart';
import '../acquisition/acquisition_cohort_coordinator.dart';
import '../loop_mode/loop_mode_coordinator.dart';
import '../loop_mode/loop_mode_model.dart';
import '../retention/retention_metrics_tracker.dart';
import 'return_capture_metrics_store.dart';
import 'watch_for_prompt_metrics_store.dart';

/// Local activation events for first-pattern quality and funnel health.
abstract class ActivationTracker {
  ActivationTracker._();

  static const String firstReflectionSaved = 'firstReflectionSaved';
  static const String firstPatternShown = 'firstPatternShown';
  static const String firstPatternAccepted = 'firstPatternAccepted';
  static const String firstPatternCorrected = 'first_pattern_corrected';
  static const String watchForPromptShown = 'watch_for_prompt_shown';
  static const String watchForPromptAccepted = 'watch_for_prompt_accepted';
  static const String returnCaptureQuickAnswerSelected =
      'return_capture_quick_answer_selected';
  static const String returnCaptureRecordedAfterSelection =
      'return_capture_recorded_after_selection';
  static const String returnCaptureSkipped = 'return_capture_skipped';
  static const String returnedNextDay = 'returnedNextDay';
  static const String secondReflectionSaved = 'secondReflectionSaved';
  static const String thirdReflectionSaved = 'thirdReflectionSaved';
  static const String comparisonViewed = 'comparisonViewed';
  static const String usefulnessYes = 'usefulnessYes';
  static const String usefulnessSortOf = 'usefulnessSortOf';
  static const String usefulnessNotReally = 'usefulnessNotReally';

  static const String trialAppOpened = 'trialAppOpened';
  static const String trialRecordCtaTapped = 'trialRecordCtaTapped';
  static const String trialMicPermissionRequested =
      'trialMicPermissionRequested';
  static const String trialMicPermissionDenied = 'trialMicPermissionDenied';
  static const String trialRecordingStarted = 'trialRecordingStarted';
  static const String trialRecordingCancelled = 'trialRecordingCancelled';
  static const String trialSaveStarted = 'trialSaveStarted';
  static const String trialSaveCompleted = 'trialSaveCompleted';
  static const String trialClosedBeforeWatchForAccepted =
      'trialClosedBeforeWatchForAccepted';
  static const String trialExportCopied = 'trialExportCopied';
  static const String tomorrowCheckInCreated = 'tomorrowCheckInCreated';
  static const String tomorrowCheckInDueShown = 'tomorrowCheckInDueShown';
  static const String tomorrowCheckInOptionSelected =
      'tomorrowCheckInOptionSelected';
  static const String tomorrowCheckInRecordingStarted =
      'tomorrowCheckInRecordingStarted';
  static const String tomorrowCheckInCompleted = 'tomorrowCheckInCompleted';
  static const String tomorrowCheckInMissed = 'tomorrowCheckInMissed';
  static const String checkInClarityCardShown = 'checkInClarityCardShown';
  static const String checkInExamplesOpened = 'checkInExamplesOpened';
  static const String checkInMomentRecorded = 'checkInMomentRecorded';
  static const String tomorrowQuestionVariantShown =
      'tomorrowQuestionVariantShown';
  static const String tomorrowQuestionVariantSelected =
      'tomorrowQuestionVariantSelected';
  static const String reminderScheduled = 'reminderScheduled';
  static const String reminderTapped = 'reminderTapped';
  static const String reminderNotAvailable = 'reminderNotAvailable';
  static const String guidedCheckInShown = 'guidedCheckInShown';
  static const String guidedCheckInStepCompleted = 'guidedCheckInStepCompleted';
  static const String sharperQuestionShown = 'sharperQuestionShown';
  static const String sharperQuestionAccepted = 'sharperQuestionAccepted';
  static const String betterResultShown = 'betterResultShown';
  static const String betterFirstRecordPromptShown =
      'betterFirstRecordPromptShown';
  static const String betterFirstRecordPromptTapped =
      'betterFirstRecordPromptTapped';
  static const String sharperQuestionElevatedShown =
      'sharperQuestionElevatedShown';
  static const String sharperQuestionAggressiveShown =
      'sharperQuestionAggressiveShown';
  static const String sharperQuestionAggressiveAccepted =
      'sharperQuestionAggressiveAccepted';
  static const String betterResultElevatedShown = 'betterResultElevatedShown';
  static const String betterResultAggressiveShown =
      'betterResultAggressiveShown';
  static const String checkInGoDeeperShown = 'checkInGoDeeperShown';
  static const String checkInGoDeeperTapped = 'checkInGoDeeperTapped';
  static const String reminderPermissionRequested =
      'reminderPermissionRequested';
  static const String reminderPermissionGranted = 'reminderPermissionGranted';
  static const String reminderPermissionDenied = 'reminderPermissionDenied';
  static const String reminderCancelled = 'reminderCancelled';
  static const String patternMemoryCreated = 'patternMemoryCreated';
  static const String patternMemoryUpdated = 'patternMemoryUpdated';
  static const String patternMemoryNextQuestionUsed =
      'patternMemoryNextQuestionUsed';
  static const String patternProgressMomentCreated =
      'patternProgressMomentCreated';
  static const String patternProgressCardShown = 'patternProgressCardShown';
  static const String patternProgressNextQuestionUsed =
      'patternProgressNextQuestionUsed';
  static const String patternNextActionCreated = 'patternNextActionCreated';
  static const String patternNextActionShown = 'patternNextActionShown';
  static const String patternNextActionUsed = 'patternNextActionUsed';
  static const String habitProofCreated = 'habitProofCreated';
  static const String habitProofShown = 'habitProofShown';
  static const String habitProofCtaTapped = 'habitProofCtaTapped';
  static const String weeklyPatternRecapCreated = 'weeklyPatternRecapCreated';
  static const String weeklyPatternRecapShown = 'weeklyPatternRecapShown';
  static const String weeklyPatternRecapCtaTapped =
      'weeklyPatternRecapCtaTapped';
  static const String patternShareCardShown = 'patternShareCardShown';
  static const String patternShareCopied = 'patternShareCopied';
  static const String patternShareOpened = 'patternShareOpened';
  static const String patternShareFailed = 'patternShareFailed';
  static const String firstLoopRecordOpened = 'firstLoopRecordOpened';
  static const String firstLoopRecordingStarted = 'firstLoopRecordingStarted';
  static const String firstLoopMomentSaved = 'firstLoopMomentSaved';
  static const String firstLoopPatternShown = 'firstLoopPatternShown';
  static const String firstLoopTomorrowCheckChosen =
      'firstLoopTomorrowCheckChosen';
  static const String firstLoopReady = 'firstLoopReady';
  static const String returnDayDueShown = 'returnDayDueShown';
  static const String returnDayAnswerSelected = 'returnDayAnswerSelected';
  static const String returnDayRecordingStarted = 'returnDayRecordingStarted';
  static const String returnDayMomentSaved = 'returnDayMomentSaved';
  static const String returnDayLoopClosed = 'returnDayLoopClosed';
  static const String returnDayAbandonedAfterAnswer =
      'returnDayAbandonedAfterAnswer';
  static const String resultNextCheckShown = 'resultNextCheckShown';
  static const String resultNextCheckUsed = 'resultNextCheckUsed';
  static const String resultNextCheckChanged = 'resultNextCheckChanged';
  static const String resultNextCheckUsedFromPatterns =
      'resultNextCheckUsedFromPatterns';
  static const String usefulResultTakeawayShown = 'usefulResultTakeawayShown';
  static const String makeResultMoreUsefulTapped = 'makeResultMoreUsefulTapped';
  static const String makeResultMoreUsefulReasonSelected =
      'makeResultMoreUsefulReasonSelected';
  static const String usefulResultNextCheckUsed = 'usefulResultNextCheckUsed';
  static const String inputQualityCoachShown = 'inputQualityCoachShown';
  static const String inputQualitySentenceAdded = 'inputQualitySentenceAdded';
  static const String inputQualityUsedAnyway = 'inputQualityUsedAnyway';
  static const String acceptedWeakInputCount = 'acceptedWeakInputCount';
  static const String sharpenedInputCount = 'sharpenedInputCount';
  static const String perspectiveShiftShown = 'perspectiveShiftShown';
  static const String perspectiveShiftChanged = 'perspectiveShiftChanged';
  static const String perspectiveShiftUsed = 'perspectiveShiftUsed';
  static const String perspectiveShiftShownFromPatterns =
      'perspectiveShiftShownFromPatterns';
  static const String perspectiveShiftUsedFromPatterns =
      'perspectiveShiftUsedFromPatterns';
  static const String kinderAngleShown = 'kinderAngleShown';
  static const String kinderAngleUsed = 'kinderAngleUsed';
  static const String kinderAngleChanged = 'kinderAngleChanged';
  static const String kinderAngleShownFromPatterns =
      'kinderAngleShownFromPatterns';
  static const String kinderAngleUsedFromPatterns =
      'kinderAngleUsedFromPatterns';
  static const String quickHelpOpened = 'quickHelpOpened';
  static const String quickHelpIntentSelected = 'quickHelpIntentSelected';
  static const String quickHelpPrimaryActionTapped =
      'quickHelpPrimaryActionTapped';
  static const String quickHelpCheckUsed = 'quickHelpCheckUsed';
  static const String keyMomentCreated = 'keyMomentCreated';
  static const String keyMomentOpened = 'keyMomentOpened';
  static const String keyMomentSearchUsed = 'keyMomentSearchUsed';
  static const String keyMomentUseCheckTapped = 'keyMomentUseCheckTapped';
  static const String askArchiveOpened = 'askArchiveOpened';
  static const String askArchiveSearchUsed = 'askArchiveSearchUsed';
  static const String askArchiveSuggestedChipTapped =
      'askArchiveSuggestedChipTapped';
  static const String askArchiveResultOpened = 'askArchiveResultOpened';
  static const String askArchiveUseCheckTapped = 'askArchiveUseCheckTapped';
  static const String archiveCleanViewShown = 'archiveCleanViewShown';
  static const String archiveCleanSectionTapped = 'archiveCleanSectionTapped';
  static const String patternProfileShown = 'patternProfileShown';
  static const String patternProfileOpened = 'patternProfileOpened';
  static const String patternProfileUseCheckTapped =
      'patternProfileUseCheckTapped';
  static const String patternProfileFindMomentsTapped =
      'patternProfileFindMomentsTapped';
  static const String patternProfileOpenTimelineTapped =
      'patternProfileOpenTimelineTapped';
  static const String patternMapShown = 'patternMapShown';
  static const String patternMapOpened = 'patternMapOpened';
  static const String patternMapUseCheckTapped = 'patternMapUseCheckTapped';
  static const String archiveFeedbackShown = 'archiveFeedbackShown';
  static const String archiveFeedbackSelected = 'archiveFeedbackSelected';
  static const String archiveFeedbackUseful = 'archiveFeedbackUseful';
  static const String archiveFeedbackTooGeneric = 'archiveFeedbackTooGeneric';
  static const String archiveFeedbackNotMe = 'archiveFeedbackNotMe';
  static const String archiveFeedbackAlreadyKnew = 'archiveFeedbackAlreadyKnew';
  static const String archiveFeedbackMoreSpecific =
      'archiveFeedbackMoreSpecific';
  static const String archiveCompressionShown = 'archiveCompressionShown';
  static const String archiveCompressionOpened = 'archiveCompressionOpened';
  static const String archiveCompressionKept = 'archiveCompressionKept';
  static const String archiveCompressionSplit = 'archiveCompressionSplit';
  static const String archiveCompressionHidden = 'archiveCompressionHidden';
  static const String memoryQualityShown = 'memoryQualityShown';
  static const String memoryQualityTapped = 'memoryQualityTapped';
  static const String paywallShown = 'paywallShown';
  static const String paywallTriggerShown = 'paywallTriggerShown';
  static const String annualPlanShown = 'annualPlanShown';
  static const String monthlyPlanShown = 'monthlyPlanShown';
  static const String annualPlanSelected = 'annualPlanSelected';
  static const String monthlyPlanSelected = 'monthlyPlanSelected';
  static const String paywallContinueTapped = 'paywallContinueTapped';
  static const String paywallDismissed = 'paywallDismissed';
  static const String restoreTapped = 'restoreTapped';
  static const String archiveRangeReviewShown = 'archiveRangeReviewShown';
  static const String archiveRangeReviewOpened = 'archiveRangeReviewOpened';
  static const String archiveRangeReviewUseCheckTapped =
      'archiveRangeReviewUseCheckTapped';
  static const String archiveRangeReviewPresetChanged =
      'archiveRangeReviewPresetChanged';
  static const String retentionStateShown = 'retentionStateShown';
  static const String retentionDueShown = 'retentionDueShown';
  static const String retentionCheckSetShown = 'retentionCheckSetShown';
  static const String retentionLoopClosedShown = 'retentionLoopClosedShown';
  static const String retentionPrimaryCtaTapped = 'retentionPrimaryCtaTapped';
  static const String retentionSecondaryCtaTapped =
      'retentionSecondaryCtaTapped';
  static const String retentionNextCheckReady = 'retentionNextCheckReady';
  static const String retentionMissedCheck = 'retentionMissedCheck';
  static const String reminderScheduledFromRetention =
      'reminderScheduledFromRetention';
  static const String compellingCheckShown = 'compellingCheckShown';
  static const String compellingCheckSelected = 'compellingCheckSelected';
  static const String compellingCheckMostSpecificSelected =
      'compellingCheckMostSpecificSelected';
  static const String compellingCheckAccepted = 'compellingCheckAccepted';
  static const String realReminderPermissionRequested =
      'realReminderPermissionRequested';
  static const String realReminderPermissionGranted =
      'realReminderPermissionGranted';
  static const String realReminderPermissionDenied =
      'realReminderPermissionDenied';
  static const String realReminderScheduled = 'realReminderScheduled';
  static const String realReminderCancelled = 'realReminderCancelled';
  static const String realReminderUnavailable = 'realReminderUnavailable';
  static const String realReminderTapped = 'realReminderTapped';
  static const String currentObjectiveShown = 'currentObjectiveShown';
  static const String currentObjectivePrimaryTapped =
      'currentObjectivePrimaryTapped';
  static const String currentObjectiveSecondaryTapped =
      'currentObjectiveSecondaryTapped';
  static const String proValuePreviewShown = 'proValuePreviewShown';
  static const String proValuePreviewUnlockTapped =
      'proValuePreviewUnlockTapped';
  static const String proValuePreviewDismissed = 'proValuePreviewDismissed';
  static const String objectiveWidgetRefreshAttempted =
      'objectiveWidgetRefreshAttempted';
  static const String objectiveWidgetRefreshSucceeded =
      'objectiveWidgetRefreshSucceeded';
  static const String objectiveWidgetRefreshFailed =
      'objectiveWidgetRefreshFailed';
  static const String objectiveWidgetCleared = 'objectiveWidgetCleared';
  static const String archiveMemorySummaryShown = 'archiveMemorySummaryShown';
  static const String archiveMemoryOpenPatternMapTapped =
      'archiveMemoryOpenPatternMapTapped';
  static const String archiveMemoryFindMomentsTapped =
      'archiveMemoryFindMomentsTapped';
  static const String archiveMemoryUseCheckTapped =
      'archiveMemoryUseCheckTapped';
  static const String archiveTimelineShown = 'archiveTimelineShown';
  static const String archiveTimelineOpened = 'archiveTimelineOpened';
  static const String archiveTimelineUseCheckTapped =
      'archiveTimelineUseCheckTapped';
  static const String archiveMemoryDemoShown = 'archiveMemoryDemoShown';
  static const String archiveMemoryDemoCtaTapped = 'archiveMemoryDemoCtaTapped';
  static const String archiveMemoryPreviewShown = 'archiveMemoryPreviewShown';
  static const String archiveMemoryPreviewCtaTapped =
      'archiveMemoryPreviewCtaTapped';
  static const String positioningComprehensionAsked =
      'positioningComprehensionAsked';
  static const String positioningComprehensionAnswered =
      'positioningComprehensionAnswered';
  static const String positioningUnderstoodArchiveMemory =
      'positioningUnderstoodArchiveMemory';
  static const String positioningJournal = 'positioningJournal';
  static const String positioningChat = 'positioningChat';
  static const String positioningNotSure = 'positioningNotSure';

  static const String activationFirstRecordCardShown =
      'activationFirstRecordCardShown';
  static const String activationFirstRecordCtaTapped =
      'activationFirstRecordCtaTapped';
  static const String activationStarterPromptSelected =
      'activationStarterPromptSelected';
  static const String activationFirstSaveCompleted =
      'activationFirstSaveCompleted';
  static const String activationTomorrowCheckShown =
      'activationTomorrowCheckShown';
  static const String activationTomorrowCheckUsed =
      'activationTomorrowCheckUsed';
  static const String activationTomorrowCheckSharpened =
      'activationTomorrowCheckSharpened';
  static const String activationTomorrowCheckIgnored =
      'activationTomorrowCheckIgnored';
  static const String activationUsefulTakeawayShown =
      'activationUsefulTakeawayShown';
  static const String activationMakeUsefulTapped = 'activationMakeUsefulTapped';
  static const String activationMakeUsefulReasonSelected =
      'activationMakeUsefulReasonSelected';
  static const String activationResultRatedUseful =
      'activationResultRatedUseful';
  static const String activationResultRatedSortOf =
      'activationResultRatedSortOf';
  static const String activationResultRatedNotUseful =
      'activationResultRatedNotUseful';
  static const String activationNextCheckShown = 'activationNextCheckShown';
  static const String activationNextCheckUsed = 'activationNextCheckUsed';
  static const String activationNextCheckChanged = 'activationNextCheckChanged';
  static const String activationRoutineAnchorOffered =
      'activationRoutineAnchorOffered';
  static const String activationRoutineAnchorSet = 'activationRoutineAnchorSet';

  static const _returnedNextDayFlagKey = 'trial_returned_next_day_logged';
  static const _checkInDueShownFlagKey = 'trial_check_in_due_shown_logged';
  static const _trialAppOpenedFlagKey = 'trial_app_opened_logged';
  static const _watchForPendingAcceptKey = 'trial_watch_for_pending_accept';
  static const _firstReflectionFlagKey = 'trial_first_reflection_logged';
  static const _secondReflectionFlagKey = 'trial_second_reflection_logged';
  static const _thirdReflectionFlagKey = 'trial_third_reflection_logged';
  static const _fourthReflectionFlagKey = 'trial_fourth_reflection_logged';

  static ActivationEventsStore _events() =>
      ActivationEventsStore(AppServices.instance.prefs);

  static FirstPatternCorrectionStore _correctionStore() =>
      FirstPatternCorrectionStore(AppServices.instance.prefs);

  static WatchForPromptMetricsStore _watchForMetrics() =>
      WatchForPromptMetricsStore(AppServices.instance.prefs);

  static ReturnCaptureMetricsStore _returnCaptureMetrics() =>
      ReturnCaptureMetricsStore(AppServices.instance.prefs);

  static Future<void> _incrementEvent(String field) async {
    if (!AppServices.isInitialized) return;
    try {
      await _events().increment(field);
    } catch (_) {}
  }

  static Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {}
  }

  static void _trackAnalytics(String event, Map<String, String> params) {
    if (TrialMode.enabled) return;
    unawaited(ProductAnalytics.trackStrings(event, params));
  }

  /// Fires at most once per milestone when [eligibleCount] reaches 1, 2, or 3.
  static Future<void> trackReflectionMilestones(int eligibleCount) async {
    if (!AppServices.isInitialized) return;
    final prefs = AppServices.instance.prefs;
    if (eligibleCount >= 1 &&
        await prefs.readBool(_firstReflectionFlagKey) != true) {
      await prefs.writeBool(_firstReflectionFlagKey, true);
      await trackFirstReflectionSaved();
    }
    if (eligibleCount >= 2 &&
        await prefs.readBool(_secondReflectionFlagKey) != true) {
      await prefs.writeBool(_secondReflectionFlagKey, true);
      await trackSecondReflectionSaved();
      trackSecondMomentRecorded();
    }
    if (eligibleCount >= 3 &&
        await prefs.readBool(_thirdReflectionFlagKey) != true) {
      await prefs.writeBool(_thirdReflectionFlagKey, true);
      await trackThirdReflectionSaved();
      trackThirdMomentRecorded();
    }
    if (eligibleCount >= 4 &&
        await prefs.readBool(_fourthReflectionFlagKey) != true) {
      await prefs.writeBool(_fourthReflectionFlagKey, true);
      unawaited(BetaActivationLoopTracker.trackFourthMomentSaved());
    }
  }

  static Future<void> trackFirstReflectionSaved() async {
    await _incrementEvent(firstReflectionSaved);
    _trackAnalytics(firstReflectionSaved, {});
    unawaited(BetaActivationLoopTracker.trackFirstMomentSaved());
    unawaited(AcquisitionCohortCoordinator.markFirstMomentRecorded());
    unawaited(_trackProveFirstMomentIfActive());
  }

  static Future<void> _trackProveFirstMomentIfActive() async {
    final loop = await LoopModeCoordinator.loadActive();
    if (loop?.id == LoopModeIds.proveEnough) {
      trackProveFirstMomentRecorded();
    }
  }

  static Future<void> trackFirstPatternShown() async {
    await _incrementEvent(firstPatternShown);
    _trackAnalytics(firstPatternShown, {});
  }

  static Future<void> trackFirstPatternAccepted() async {
    await _incrementEvent(firstPatternAccepted);
    _trackAnalytics(firstPatternAccepted, {});
  }

  static Future<void> trackSecondReflectionSaved() async {
    await _incrementEvent(secondReflectionSaved);
    _trackAnalytics(secondReflectionSaved, {});
    unawaited(BetaActivationLoopTracker.trackSecondMomentSaved());
  }

  static Future<void> trackThirdReflectionSaved() async {
    await _incrementEvent(thirdReflectionSaved);
    _trackAnalytics(thirdReflectionSaved, {});
    unawaited(BetaActivationLoopTracker.trackThirdMomentSaved());
  }

  static Future<void> trackReturnedNextDayOnce() async {
    if (!AppServices.isInitialized) return;
    final prefs = AppServices.instance.prefs;
    if (await prefs.readBool(_returnedNextDayFlagKey) == true) return;
    await prefs.writeBool(_returnedNextDayFlagKey, true);
    await _incrementEvent(returnedNextDay);
    _trackAnalytics(returnedNextDay, {});
  }

  static Future<void> trackComparisonViewed() async {
    await _incrementEvent(comparisonViewed);
    _trackAnalytics(comparisonViewed, {});
  }

  static Future<void> trackUsefulnessYes() async {
    await _incrementEvent(usefulnessYes);
    _trackAnalytics(usefulnessYes, {});
  }

  static Future<void> trackUsefulnessSortOf() async {
    await _incrementEvent(usefulnessSortOf);
    _trackAnalytics(usefulnessSortOf, {});
  }

  static Future<void> trackUsefulnessNotReally() async {
    await _incrementEvent(usefulnessNotReally);
    _trackAnalytics(usefulnessNotReally, {});
  }

  static Future<void> setParticipantId(String? id) async {
    if (!AppServices.isInitialized) return;
    await _events().setParticipantId(id);
  }

  static Future<void> trackFirstPatternCorrected({
    required String originalTitle,
    required String selectedTitle,
    required double confidenceScore,
  }) async {
    await _incrementEvent(firstPatternCorrected);
    await _correctionStore().record(
      originalTitle: originalTitle,
      selectedTitle: selectedTitle,
      confidenceScore: confidenceScore,
    );
    _trackAnalytics(firstPatternCorrected, {
      'original_title': originalTitle,
      'selected_title': selectedTitle,
      'confidence_score': confidenceScore.toStringAsFixed(2),
    });
  }

  static Future<void> trackWatchForPromptShown({
    required String strength,
  }) async {
    await _incrementEvent(watchForPromptShown);
    await _watchForMetrics().recordShown(strength: strength);
    _trackAnalytics(watchForPromptShown, {'prompt_strength': strength});
  }

  static Future<void> trackWatchForPromptAccepted({
    required String strength,
  }) async {
    await _incrementEvent(watchForPromptAccepted);
    await _watchForMetrics().recordAccepted(strength: strength);
    _trackAnalytics(watchForPromptAccepted, {'prompt_strength': strength});
  }

  static Future<void> trackReturnCaptureQuickAnswerSelected({
    required String quickAnswerId,
    required String comparisonHint,
  }) async {
    await _incrementEvent(returnCaptureQuickAnswerSelected);
    if (AppServices.isInitialized) {
      await _returnCaptureMetrics().recordQuickAnswerSelected();
    }
    _trackAnalytics(returnCaptureQuickAnswerSelected, {
      'quick_answer_id': quickAnswerId,
      'comparison_hint': comparisonHint,
    });
  }

  static Future<void> trackReturnCaptureRecordedAfterSelection() async {
    if (AppServices.isInitialized) {
      await _returnCaptureMetrics().recordRecordedAfterQuickAnswer();
    }
    _trackAnalytics(returnCaptureRecordedAfterSelection, {});
  }

  static Future<void> trackReturnCaptureSkipped() async {
    if (AppServices.isInitialized) {
      await _returnCaptureMetrics().recordSkipped();
    }
    _trackAnalytics(returnCaptureSkipped, {});
  }

  /// Once per app launch in trial mode.
  static Future<void> trackTrialAppOpened() async {
    if (!TrialMode.enabled || !AppServices.isInitialized) return;
    await _safe(() async {
      final prefs = AppServices.instance.prefs;
      if (await prefs.readBool(_trialAppOpenedFlagKey) == true) return;
      await prefs.writeBool(_trialAppOpenedFlagKey, true);
      await _incrementEvent(trialAppOpened);
    });
  }

  static Future<void> trackTrialRecordCtaTapped() async {
    if (!TrialMode.enabled) return;
    await _safe(() => _incrementEvent(trialRecordCtaTapped));
  }

  static Future<void> trackTrialMicPermissionRequested() async {
    if (!TrialMode.enabled) return;
    await _safe(() => _incrementEvent(trialMicPermissionRequested));
  }

  static Future<void> trackTrialMicPermissionDenied() async {
    if (!TrialMode.enabled) return;
    await _safe(() => _incrementEvent(trialMicPermissionDenied));
  }

  static Future<void> trackTrialRecordingStarted() async {
    if (!TrialMode.enabled) return;
    await _safe(() => _incrementEvent(trialRecordingStarted));
  }

  static Future<void> trackTrialRecordingCancelled() async {
    if (!TrialMode.enabled) return;
    await _safe(() => _incrementEvent(trialRecordingCancelled));
  }

  static Future<void> trackTrialSaveStarted() async {
    if (!TrialMode.enabled) return;
    await _safe(() => _incrementEvent(trialSaveStarted));
  }

  static Future<void> trackTrialSaveCompleted() async {
    if (!TrialMode.enabled) return;
    await _safe(() => _incrementEvent(trialSaveCompleted));
  }

  /// Facilitator export from trial control (any build with dev access).
  static Future<void> trackTrialExportCopied() async {
    await _safe(() => _incrementEvent(trialExportCopied));
  }

  static Future<void> trackTomorrowCheckInCreated() async {
    await _safe(() => _incrementEvent(tomorrowCheckInCreated));
  }

  static Future<void> trackTomorrowCheckInDueShown() async {
    await _safe(() async {
      if (!AppServices.isInitialized) return;
      final prefs = AppServices.instance.prefs;
      if (await prefs.readBool(_checkInDueShownFlagKey) == true) return;
      await prefs.writeBool(_checkInDueShownFlagKey, true);
      await _incrementEvent(tomorrowCheckInDueShown);
    });
  }

  static Future<void> trackTomorrowCheckInOptionSelected() async {
    await _safe(() => _incrementEvent(tomorrowCheckInOptionSelected));
  }

  static Future<void> trackTomorrowCheckInRecordingStarted() async {
    await _safe(() => _incrementEvent(tomorrowCheckInRecordingStarted));
  }

  static Future<void> trackTomorrowCheckInCompleted() async {
    await _safe(() => _incrementEvent(tomorrowCheckInCompleted));
  }

  static Future<void> trackTomorrowCheckInMissed() async {
    await _safe(() => _incrementEvent(tomorrowCheckInMissed));
  }

  static void trackCheckInClarityCardShown() {
    unawaited(_safe(() => _incrementEvent(checkInClarityCardShown)));
  }

  static void trackCheckInExamplesOpened() {
    unawaited(_safe(() => _incrementEvent(checkInExamplesOpened)));
  }

  static Future<void> trackCheckInMomentRecorded() async {
    await _safe(() => _incrementEvent(checkInMomentRecorded));
  }

  static void trackTomorrowQuestionVariantShown({
    required String variantId,
    required String categoryId,
  }) {
    unawaited(_safe(() => _incrementEvent(tomorrowQuestionVariantShown)));
    _trackAnalytics(tomorrowQuestionVariantShown, {
      'variant_id': variantId,
      'category_id': categoryId,
    });
  }

  static void trackTomorrowQuestionVariantSelected({
    required String variantId,
    required String categoryId,
  }) {
    unawaited(_safe(() => _incrementEvent(tomorrowQuestionVariantSelected)));
    _trackAnalytics(tomorrowQuestionVariantSelected, {
      'variant_id': variantId,
      'category_id': categoryId,
    });
  }

  // --- Hook rescue pack metrics (gated fixes) ---
  static void trackReminderScheduled() {
    unawaited(_safe(() => _incrementEvent(reminderScheduled)));
  }

  static void trackReminderTapped() {
    unawaited(_safe(() => _incrementEvent(reminderTapped)));
  }

  static void trackReminderNotAvailable() {
    unawaited(_safe(() => _incrementEvent(reminderNotAvailable)));
  }

  static void trackGuidedCheckInShown() {
    unawaited(_safe(() => _incrementEvent(guidedCheckInShown)));
  }

  static void trackGuidedCheckInStepCompleted() {
    unawaited(_safe(() => _incrementEvent(guidedCheckInStepCompleted)));
  }

  static void trackSharperQuestionShown() {
    unawaited(_safe(() => _incrementEvent(sharperQuestionShown)));
  }

  static void trackSharperQuestionAccepted() {
    unawaited(_safe(() => _incrementEvent(sharperQuestionAccepted)));
  }

  static void trackBetterResultShown() {
    unawaited(_safe(() => _incrementEvent(betterResultShown)));
  }

  static void trackBetterFirstRecordPromptShown() {
    unawaited(_safe(() => _incrementEvent(betterFirstRecordPromptShown)));
  }

  static void trackBetterFirstRecordPromptTapped() {
    unawaited(_safe(() => _incrementEvent(betterFirstRecordPromptTapped)));
  }

  // --- Hook escalation v2 metrics ---
  static void trackSharperQuestionElevatedShown() {
    unawaited(_safe(() => _incrementEvent(sharperQuestionElevatedShown)));
  }

  static void trackSharperQuestionAggressiveShown() {
    unawaited(_safe(() => _incrementEvent(sharperQuestionAggressiveShown)));
  }

  static void trackSharperQuestionAggressiveAccepted() {
    unawaited(_safe(() => _incrementEvent(sharperQuestionAggressiveAccepted)));
  }

  static void trackBetterResultElevatedShown() {
    unawaited(_safe(() => _incrementEvent(betterResultElevatedShown)));
  }

  static void trackBetterResultAggressiveShown() {
    unawaited(_safe(() => _incrementEvent(betterResultAggressiveShown)));
  }

  static void trackCheckInGoDeeperShown() {
    unawaited(_safe(() => _incrementEvent(checkInGoDeeperShown)));
  }

  static void trackCheckInGoDeeperTapped() {
    unawaited(_safe(() => _incrementEvent(checkInGoDeeperTapped)));
  }

  static void trackReminderPermissionRequested() {
    unawaited(_safe(() => _incrementEvent(reminderPermissionRequested)));
  }

  static void trackReminderPermissionGranted() {
    unawaited(_safe(() => _incrementEvent(reminderPermissionGranted)));
  }

  static void trackReminderPermissionDenied() {
    unawaited(_safe(() => _incrementEvent(reminderPermissionDenied)));
  }

  static void trackReminderCancelled() {
    unawaited(_safe(() => _incrementEvent(reminderCancelled)));
  }

  // --- Pattern memory metrics ---
  static void trackPatternMemoryCreated() {
    unawaited(_safe(() => _incrementEvent(patternMemoryCreated)));
  }

  static void trackPatternMemoryUpdated() {
    unawaited(_safe(() => _incrementEvent(patternMemoryUpdated)));
  }

  static void trackPatternMemoryNextQuestionUsed() {
    unawaited(_safe(() => _incrementEvent(patternMemoryNextQuestionUsed)));
  }

  // --- Pattern progress metrics ---
  static void trackPatternProgressMomentCreated() {
    unawaited(_safe(() => _incrementEvent(patternProgressMomentCreated)));
  }

  static void trackPatternProgressCardShown() {
    unawaited(_safe(() => _incrementEvent(patternProgressCardShown)));
  }

  static void trackPatternProgressNextQuestionUsed() {
    unawaited(_safe(() => _incrementEvent(patternProgressNextQuestionUsed)));
  }

  // --- Pattern next action metrics ---
  static void trackPatternNextActionCreated() {
    unawaited(_safe(() => _incrementEvent(patternNextActionCreated)));
  }

  static void trackPatternNextActionShown() {
    unawaited(_safe(() => _incrementEvent(patternNextActionShown)));
  }

  static void trackPatternNextActionUsed() {
    unawaited(_safe(() => _incrementEvent(patternNextActionUsed)));
  }

  // --- Habit proof metrics ---
  static void trackHabitProofCreated() {
    unawaited(_safe(() => _incrementEvent(habitProofCreated)));
  }

  static void trackHabitProofCardShown() {
    unawaited(_safe(() => _incrementEvent(habitProofShown)));
  }

  static void trackHabitProofCtaTapped() {
    unawaited(_safe(() => _incrementEvent(habitProofCtaTapped)));
  }

  // --- Weekly pattern recap metrics ---
  static void trackWeeklyPatternRecapCreated() {
    unawaited(_safe(() => _incrementEvent(weeklyPatternRecapCreated)));
  }

  static void trackWeeklyPatternRecapShown() {
    unawaited(_safe(() => _incrementEvent(weeklyPatternRecapShown)));
  }

  static void trackWeeklyPatternRecapCtaTapped() {
    unawaited(_safe(() => _incrementEvent(weeklyPatternRecapCtaTapped)));
  }

  // --- Pattern share / export metrics ---
  static void trackPatternShareCardShown() {
    unawaited(_safe(() => _incrementEvent(patternShareCardShown)));
  }

  static void trackPatternShareCopied() {
    unawaited(_safe(() => _incrementEvent(patternShareCopied)));
  }

  static void trackPatternShareOpened() {
    unawaited(_safe(() => _incrementEvent(patternShareOpened)));
  }

  static void trackPatternShareFailed() {
    unawaited(_safe(() => _incrementEvent(patternShareFailed)));
  }

  // --- First-loop activation metrics ---
  static void trackFirstLoopRecordOpened() {
    unawaited(_safe(() => _incrementEvent(firstLoopRecordOpened)));
  }

  static void trackFirstLoopRecordingStarted() {
    unawaited(_safe(() => _incrementEvent(firstLoopRecordingStarted)));
  }

  static void trackFirstLoopMomentSaved() {
    unawaited(_safe(() => _incrementEvent(firstLoopMomentSaved)));
  }

  static void trackFirstLoopPatternShown() {
    unawaited(_safe(() => _incrementEvent(firstLoopPatternShown)));
  }

  static void trackFirstLoopTomorrowCheckChosen() {
    unawaited(_safe(() => _incrementEvent(firstLoopTomorrowCheckChosen)));
  }

  static void trackFirstLoopReady() {
    unawaited(_safe(() => _incrementEvent(firstLoopReady)));
  }

  // --- Return-day friction metrics ---
  static void trackReturnDayDueShown() {
    unawaited(_safe(() => _incrementEvent(returnDayDueShown)));
  }

  static void trackReturnDayAnswerSelected() {
    unawaited(_safe(() => _incrementEvent(returnDayAnswerSelected)));
  }

  static void trackReturnDayRecordingStarted() {
    unawaited(_safe(() => _incrementEvent(returnDayRecordingStarted)));
  }

  static void trackReturnDayMomentSaved() {
    unawaited(_safe(() => _incrementEvent(returnDayMomentSaved)));
  }

  static void trackReturnDayLoopClosed() {
    unawaited(_safe(() => _incrementEvent(returnDayLoopClosed)));
  }

  static void trackReturnDayAbandonedAfterAnswer() {
    unawaited(_safe(() => _incrementEvent(returnDayAbandonedAfterAnswer)));
  }

  // --- Result-to-next-check metrics ---
  static void trackResultNextCheckShown() {
    unawaited(_safe(() => _incrementEvent(resultNextCheckShown)));
  }

  static void trackResultNextCheckUsed() {
    unawaited(_safe(() => _incrementEvent(resultNextCheckUsed)));
  }

  static void trackResultNextCheckChanged() {
    unawaited(_safe(() => _incrementEvent(resultNextCheckChanged)));
  }

  static void trackResultNextCheckUsedFromPatterns() {
    unawaited(_safe(() => _incrementEvent(resultNextCheckUsedFromPatterns)));
  }

  // --- Perspective shift metrics ---
  static void trackPerspectiveShiftShown() {
    unawaited(_safe(() => _incrementEvent(perspectiveShiftShown)));
  }

  static void trackPerspectiveShiftChanged() {
    unawaited(_safe(() => _incrementEvent(perspectiveShiftChanged)));
  }

  static void trackPerspectiveShiftUsed() {
    unawaited(_safe(() => _incrementEvent(perspectiveShiftUsed)));
  }

  static void trackPerspectiveShiftShownFromPatterns() {
    unawaited(_safe(() => _incrementEvent(perspectiveShiftShownFromPatterns)));
  }

  static void trackPerspectiveShiftUsedFromPatterns() {
    unawaited(_safe(() => _incrementEvent(perspectiveShiftUsedFromPatterns)));
  }

  // --- Kinder angle metrics ---
  static void trackKinderAngleShown() {
    unawaited(_safe(() => _incrementEvent(kinderAngleShown)));
  }

  static void trackKinderAngleUsed() {
    unawaited(_safe(() => _incrementEvent(kinderAngleUsed)));
  }

  static void trackKinderAngleChanged() {
    unawaited(_safe(() => _incrementEvent(kinderAngleChanged)));
  }

  static void trackKinderAngleShownFromPatterns() {
    unawaited(_safe(() => _incrementEvent(kinderAngleShownFromPatterns)));
  }

  static void trackKinderAngleUsedFromPatterns() {
    unawaited(_safe(() => _incrementEvent(kinderAngleUsedFromPatterns)));
  }

  // --- Quick help metrics ---
  static void trackQuickHelpOpened() {
    unawaited(_safe(() => _incrementEvent(quickHelpOpened)));
  }

  static void trackQuickHelpIntentSelected() {
    unawaited(_safe(() => _incrementEvent(quickHelpIntentSelected)));
  }

  static void trackQuickHelpPrimaryActionTapped() {
    unawaited(_safe(() => _incrementEvent(quickHelpPrimaryActionTapped)));
  }

  static void trackQuickHelpCheckUsed() {
    unawaited(_safe(() => _incrementEvent(quickHelpCheckUsed)));
  }

  // --- Key moments metrics ---
  static void trackKeyMomentCreated() {
    unawaited(_safe(() => _incrementEvent(keyMomentCreated)));
  }

  static void trackKeyMomentOpened() {
    unawaited(_safe(() => _incrementEvent(keyMomentOpened)));
  }

  static void trackKeyMomentSearchUsed() {
    unawaited(_safe(() => _incrementEvent(keyMomentSearchUsed)));
  }

  static void trackKeyMomentUseCheckTapped() {
    unawaited(_safe(() => _incrementEvent(keyMomentUseCheckTapped)));
  }

  // --- Ask my Archive metrics ---
  static void trackAskArchiveOpened() {
    unawaited(_safe(() => _incrementEvent(askArchiveOpened)));
  }

  static void trackAskArchiveSearchUsed() {
    unawaited(_safe(() => _incrementEvent(askArchiveSearchUsed)));
  }

  static void trackAskArchiveSuggestedChipTapped() {
    unawaited(_safe(() => _incrementEvent(askArchiveSuggestedChipTapped)));
  }

  static void trackAskArchiveResultOpened() {
    unawaited(_safe(() => _incrementEvent(askArchiveResultOpened)));
  }

  static void trackAskArchiveUseCheckTapped() {
    unawaited(_safe(() => _incrementEvent(askArchiveUseCheckTapped)));
  }

  // --- Archive clean view metrics ---
  static void trackArchiveCleanViewShown() {
    unawaited(_safe(() => _incrementEvent(archiveCleanViewShown)));
  }

  static void trackArchiveCleanSectionTapped() {
    unawaited(_safe(() => _incrementEvent(archiveCleanSectionTapped)));
  }

  // --- Pattern profile metrics ---
  static void trackPatternProfileShown() {
    unawaited(_safe(() => _incrementEvent(patternProfileShown)));
  }

  static void trackPatternProfileOpened() {
    unawaited(_safe(() => _incrementEvent(patternProfileOpened)));
  }

  static void trackPatternProfileUseCheckTapped() {
    unawaited(_safe(() => _incrementEvent(patternProfileUseCheckTapped)));
  }

  static void trackPatternProfileFindMomentsTapped() {
    unawaited(_safe(() => _incrementEvent(patternProfileFindMomentsTapped)));
  }

  static void trackPatternProfileOpenTimelineTapped() {
    unawaited(_safe(() => _incrementEvent(patternProfileOpenTimelineTapped)));
  }

  // --- Pattern map metrics ---
  static void trackPatternMapShown() {
    unawaited(_safe(() => _incrementEvent(patternMapShown)));
  }

  static void trackPatternMapOpened() {
    unawaited(_safe(() => _incrementEvent(patternMapOpened)));
  }

  static void trackPatternMapUseCheckTapped() {
    unawaited(_safe(() => _incrementEvent(patternMapUseCheckTapped)));
  }

  // --- Feedback learning loop metrics ---
  static void trackArchiveFeedbackShown() {
    unawaited(_safe(() => _incrementEvent(archiveFeedbackShown)));
  }

  static void trackArchiveFeedbackSelected(ArchiveFeedbackType type) {
    unawaited(
      _safe(() async {
        await _incrementEvent(archiveFeedbackSelected);
        await _incrementEvent(_feedbackTypeEvent(type));
      }),
    );
  }

  static String _feedbackTypeEvent(ArchiveFeedbackType type) {
    switch (type) {
      case ArchiveFeedbackType.useful:
        return archiveFeedbackUseful;
      case ArchiveFeedbackType.tooGeneric:
        return archiveFeedbackTooGeneric;
      case ArchiveFeedbackType.notMe:
        return archiveFeedbackNotMe;
      case ArchiveFeedbackType.alreadyKnew:
        return archiveFeedbackAlreadyKnew;
      case ArchiveFeedbackType.moreSpecific:
        return archiveFeedbackMoreSpecific;
    }
  }

  // --- Archive compression metrics ---
  static void trackArchiveCompressionShown() {
    unawaited(_safe(() => _incrementEvent(archiveCompressionShown)));
  }

  static void trackArchiveCompressionOpened() {
    unawaited(_safe(() => _incrementEvent(archiveCompressionOpened)));
  }

  static void trackArchiveCompressionKept() {
    unawaited(_safe(() => _incrementEvent(archiveCompressionKept)));
  }

  static void trackArchiveCompressionSplit() {
    unawaited(_safe(() => _incrementEvent(archiveCompressionSplit)));
  }

  static void trackArchiveCompressionHidden() {
    unawaited(_safe(() => _incrementEvent(archiveCompressionHidden)));
  }

  // --- Memory quality metrics ---
  static void trackMemoryQualityShown(MemoryQualityLevel level) {
    unawaited(
      _safe(() async {
        if (!AppServices.isInitialized) return;
        await _events().recordMemoryQuality(level: level.name, tapped: false);
      }),
    );
  }

  static void trackMemoryQualityTapped(MemoryQualityLevel level) {
    unawaited(
      _safe(() async {
        if (!AppServices.isInitialized) return;
        await _events().recordMemoryQuality(level: level.name, tapped: true);
      }),
    );
  }

  // --- Billing / paywall metrics ---
  static void trackPaywallShown() {
    unawaited(_safe(() => _incrementEvent(paywallShown)));
    unawaited(BetaActivationLoopTracker.trackPaywallSeen());
  }

  static void trackPaywallTriggerShown() {
    unawaited(_safe(() => _incrementEvent(paywallTriggerShown)));
  }

  static void trackAnnualPlanShown() {
    unawaited(_safe(() => _incrementEvent(annualPlanShown)));
  }

  static void trackMonthlyPlanShown() {
    unawaited(_safe(() => _incrementEvent(monthlyPlanShown)));
  }

  static void trackAnnualPlanSelected() {
    unawaited(_safe(() => _incrementEvent(annualPlanSelected)));
  }

  static void trackMonthlyPlanSelected() {
    unawaited(_safe(() => _incrementEvent(monthlyPlanSelected)));
  }

  static void trackPaywallContinueTapped() {
    unawaited(_safe(() => _incrementEvent(paywallContinueTapped)));
  }

  static void trackPaywallDismissed() {
    unawaited(_safe(() => _incrementEvent(paywallDismissed)));
  }

  static void trackRestoreTapped() {
    unawaited(_safe(() => _incrementEvent(restoreTapped)));
    unawaited(BetaActivationLoopTracker.trackRestoreTapped());
  }

  static void trackArchiveRangeReviewShown() {
    unawaited(_safe(() => _incrementEvent(archiveRangeReviewShown)));
  }

  static void trackArchiveRangeReviewOpened() {
    unawaited(_safe(() => _incrementEvent(archiveRangeReviewOpened)));
  }

  static void trackArchiveRangeReviewUseCheckTapped() {
    unawaited(_safe(() => _incrementEvent(archiveRangeReviewUseCheckTapped)));
  }

  static void trackArchiveRangeReviewPresetChanged() {
    unawaited(_safe(() => _incrementEvent(archiveRangeReviewPresetChanged)));
  }

  static void trackRetentionStateShown() {
    unawaited(_safe(() => _incrementEvent(retentionStateShown)));
  }

  static void trackRetentionDueShown() {
    unawaited(_safe(() => _incrementEvent(retentionDueShown)));
  }

  static void trackRetentionCheckSetShown() {
    unawaited(_safe(() => _incrementEvent(retentionCheckSetShown)));
  }

  static void trackRetentionLoopClosedShown() {
    unawaited(_safe(() => _incrementEvent(retentionLoopClosedShown)));
  }

  static void trackRetentionPrimaryCtaTapped() {
    unawaited(_safe(() => _incrementEvent(retentionPrimaryCtaTapped)));
  }

  static void trackRetentionSecondaryCtaTapped() {
    unawaited(_safe(() => _incrementEvent(retentionSecondaryCtaTapped)));
  }

  static void trackRetentionNextCheckReady() {
    unawaited(_safe(() => _incrementEvent(retentionNextCheckReady)));
  }

  static void trackRetentionMissedCheck() {
    unawaited(_safe(() => _incrementEvent(retentionMissedCheck)));
  }

  static Future<void> trackReminderScheduledFromRetention() async {
    await _safe(() => _incrementEvent(reminderScheduledFromRetention));
  }

  static void trackCompellingCheckShown() {
    unawaited(_safe(() => _incrementEvent(compellingCheckShown)));
  }

  static void trackCompellingCheckSelected() {
    unawaited(_safe(() => _incrementEvent(compellingCheckSelected)));
  }

  static void trackCompellingCheckMostSpecificSelected() {
    unawaited(
      _safe(() => _incrementEvent(compellingCheckMostSpecificSelected)),
    );
  }

  static void trackCompellingCheckAccepted() {
    unawaited(_safe(() => _incrementEvent(compellingCheckAccepted)));
  }

  static void trackRealReminderPermissionRequested() {
    unawaited(_safe(() => _incrementEvent(realReminderPermissionRequested)));
  }

  static void trackRealReminderPermissionGranted() {
    unawaited(_safe(() => _incrementEvent(realReminderPermissionGranted)));
  }

  static void trackRealReminderPermissionDenied() {
    unawaited(_safe(() => _incrementEvent(realReminderPermissionDenied)));
  }

  static void trackRealReminderScheduled() {
    unawaited(_safe(() => _incrementEvent(realReminderScheduled)));
  }

  static void trackRealReminderCancelled() {
    unawaited(_safe(() => _incrementEvent(realReminderCancelled)));
  }

  static void trackRealReminderUnavailable() {
    unawaited(_safe(() => _incrementEvent(realReminderUnavailable)));
  }

  static void trackRealReminderTapped() {
    unawaited(_safe(() => _incrementEvent(realReminderTapped)));
  }

  static void trackCurrentObjectiveShown(String type) {
    unawaited(
      _safe(() async {
        if (!AppServices.isInitialized) return;
        await ActivationEventsStore(
          AppServices.instance.prefs,
        ).recordCurrentObjectiveShown(type);
      }),
    );
  }

  static void trackCurrentObjectivePrimaryTapped() {
    unawaited(_safe(() => _incrementEvent(currentObjectivePrimaryTapped)));
  }

  static void trackCurrentObjectiveSecondaryTapped() {
    unawaited(_safe(() => _incrementEvent(currentObjectiveSecondaryTapped)));
  }

  static void trackProValuePreviewShown(String type) {
    unawaited(
      _safe(() async {
        if (!AppServices.isInitialized) return;
        await ActivationEventsStore(
          AppServices.instance.prefs,
        ).recordProValuePreviewShown(type);
      }),
    );
  }

  static void trackProValuePreviewUnlockTapped() {
    unawaited(_safe(() => _incrementEvent(proValuePreviewUnlockTapped)));
  }

  static void trackProValuePreviewDismissed() {
    unawaited(_safe(() => _incrementEvent(proValuePreviewDismissed)));
  }

  static Future<void> trackObjectiveWidgetRefreshAttempted() async {
    await _safe(() => _incrementEvent(objectiveWidgetRefreshAttempted));
  }

  static Future<void> trackObjectiveWidgetRefreshSucceeded() async {
    await _safe(() => _incrementEvent(objectiveWidgetRefreshSucceeded));
  }

  static Future<void> trackObjectiveWidgetRefreshFailed() async {
    await _safe(() => _incrementEvent(objectiveWidgetRefreshFailed));
  }

  static Future<void> trackObjectiveWidgetCleared() async {
    await _safe(() => _incrementEvent(objectiveWidgetCleared));
  }

  // --- Archive memory summary metrics ---
  static void trackArchiveMemorySummaryShown() {
    unawaited(_safe(() => _incrementEvent(archiveMemorySummaryShown)));
  }

  static void trackArchiveMemoryOpenPatternMapTapped() {
    unawaited(_safe(() => _incrementEvent(archiveMemoryOpenPatternMapTapped)));
  }

  static void trackArchiveMemoryFindMomentsTapped() {
    unawaited(_safe(() => _incrementEvent(archiveMemoryFindMomentsTapped)));
  }

  static void trackArchiveMemoryUseCheckTapped() {
    unawaited(_safe(() => _incrementEvent(archiveMemoryUseCheckTapped)));
  }

  // --- Archive evolution timeline metrics ---
  static void trackArchiveTimelineShown() {
    unawaited(_safe(() => _incrementEvent(archiveTimelineShown)));
  }

  static void trackArchiveTimelineOpened() {
    unawaited(_safe(() => _incrementEvent(archiveTimelineOpened)));
  }

  static void trackArchiveTimelineUseCheckTapped() {
    unawaited(_safe(() => _incrementEvent(archiveTimelineUseCheckTapped)));
  }

  // --- Positioning comprehension rescue metrics ---
  static void trackArchiveMemoryDemoShown() {
    unawaited(_safe(() => _incrementEvent(archiveMemoryDemoShown)));
  }

  static void trackArchiveMemoryDemoCtaTapped() {
    unawaited(_safe(() => _incrementEvent(archiveMemoryDemoCtaTapped)));
  }

  static void trackArchiveMemoryPreviewShown() {
    unawaited(_safe(() => _incrementEvent(archiveMemoryPreviewShown)));
  }

  static void trackArchiveMemoryPreviewCtaTapped() {
    unawaited(_safe(() => _incrementEvent(archiveMemoryPreviewCtaTapped)));
  }

  static void trackPositioningComprehensionAsked() {
    unawaited(_safe(() => _incrementEvent(positioningComprehensionAsked)));
  }

  static void trackPositioningComprehensionAnswered(
    PositioningComprehensionAnswer answer,
  ) {
    unawaited(
      _safe(() async {
        await _incrementEvent(positioningComprehensionAnswered);
        switch (answer) {
          case PositioningComprehensionAnswer.archiveMemory:
            await _incrementEvent(positioningUnderstoodArchiveMemory);
          case PositioningComprehensionAnswer.journal:
            await _incrementEvent(positioningJournal);
          case PositioningComprehensionAnswer.chat:
            await _incrementEvent(positioningChat);
          case PositioningComprehensionAnswer.notSure:
            await _incrementEvent(positioningNotSure);
        }
      }),
    );
  }

  // --- Activation rescue pack metrics ---
  static Future<void> trackActivationFirstRecordCardShown() async {
    await _safe(() => _incrementEvent(activationFirstRecordCardShown));
  }

  static Future<void> trackActivationFirstRecordCtaTapped() async {
    await _safe(() => _incrementEvent(activationFirstRecordCtaTapped));
  }

  static Future<void> trackActivationStarterPromptSelected() async {
    await _safe(() => _incrementEvent(activationStarterPromptSelected));
  }

  static Future<void> trackActivationFirstSaveCompleted() async {
    await _safe(() => _incrementEvent(activationFirstSaveCompleted));
  }

  static Future<void> trackActivationTomorrowCheckShown() async {
    await _safe(() => _incrementEvent(activationTomorrowCheckShown));
  }

  static Future<void> trackActivationTomorrowCheckUsed() async {
    await _safe(() => _incrementEvent(activationTomorrowCheckUsed));
  }

  static Future<void> trackActivationTomorrowCheckSharpened() async {
    await _safe(() => _incrementEvent(activationTomorrowCheckSharpened));
  }

  static Future<void> trackActivationTomorrowCheckIgnored() async {
    await _safe(() => _incrementEvent(activationTomorrowCheckIgnored));
  }

  static Future<void> trackActivationUsefulTakeawayShown() async {
    await _safe(() => _incrementEvent(activationUsefulTakeawayShown));
  }

  static Future<void> trackActivationMakeUsefulTapped() async {
    await _safe(() => _incrementEvent(activationMakeUsefulTapped));
  }

  static Future<void> trackActivationMakeUsefulReasonSelected() async {
    await _safe(() => _incrementEvent(activationMakeUsefulReasonSelected));
  }

  static Future<void> trackActivationResultRatedUseful() async {
    await _safe(() => _incrementEvent(activationResultRatedUseful));
  }

  static Future<void> trackActivationResultRatedSortOf() async {
    await _safe(() => _incrementEvent(activationResultRatedSortOf));
  }

  static Future<void> trackActivationResultRatedNotUseful() async {
    await _safe(() => _incrementEvent(activationResultRatedNotUseful));
  }

  static Future<void> trackActivationNextCheckShown() async {
    await _safe(() => _incrementEvent(activationNextCheckShown));
  }

  static Future<void> trackActivationNextCheckUsed() async {
    await _safe(() => _incrementEvent(activationNextCheckUsed));
  }

  static Future<void> trackActivationNextCheckChanged() async {
    await _safe(() => _incrementEvent(activationNextCheckChanged));
  }

  static Future<void> trackActivationRoutineAnchorOffered() async {
    await _safe(() => _incrementEvent(activationRoutineAnchorOffered));
  }

  static Future<void> trackActivationRoutineAnchorSet() async {
    await _safe(() => _incrementEvent(activationRoutineAnchorSet));
  }

  // --- Useful result rescue metrics ---
  static void trackUsefulResultTakeawayShown() {
    unawaited(_safe(() => _incrementEvent(usefulResultTakeawayShown)));
  }

  static void trackMakeResultMoreUsefulTapped() {
    unawaited(_safe(() => _incrementEvent(makeResultMoreUsefulTapped)));
  }

  static void trackMakeResultMoreUsefulReasonSelected() {
    unawaited(_safe(() => _incrementEvent(makeResultMoreUsefulReasonSelected)));
  }

  static void trackUsefulResultNextCheckUsed() {
    unawaited(_safe(() => _incrementEvent(usefulResultNextCheckUsed)));
  }

  // --- Input quality coach metrics ---
  static void trackInputQualityCoachShown() {
    unawaited(_safe(() => _incrementEvent(inputQualityCoachShown)));
  }

  /// Adding a sharpening sentence both counts a coach action and a sharpen.
  static void trackInputQualitySentenceAdded() {
    unawaited(
      _safe(() async {
        await _incrementEvent(inputQualitySentenceAdded);
        await _incrementEvent(sharpenedInputCount);
      }),
    );
  }

  /// Using weak input anyway both counts a coach action and an accepted-weak.
  static void trackInputQualityUsedAnyway() {
    unawaited(
      _safe(() async {
        await _incrementEvent(inputQualityUsedAnyway);
        await _incrementEvent(acceptedWeakInputCount);
      }),
    );
  }

  /// Call when first-session pattern card is visible and watch-for not yet accepted.
  static Future<void> markWatchForAcceptPending() async {
    if (!TrialMode.enabled || !AppServices.isInitialized) return;
    await _safe(
      () =>
          AppServices.instance.prefs.writeBool(_watchForPendingAcceptKey, true),
    );
  }

  static Future<void> clearWatchForAcceptPending() async {
    if (!AppServices.isInitialized) return;
    await _safe(
      () => AppServices.instance.prefs.writeBool(
        _watchForPendingAcceptKey,
        false,
      ),
    );
  }

  /// Approximate: left record flow with pattern shown but no accept.
  static Future<void> trackTrialClosedBeforeWatchForAcceptedIfPending() async {
    if (!TrialMode.enabled || !AppServices.isInitialized) return;
    await _safe(() async {
      final prefs = AppServices.instance.prefs;
      if (await prefs.readBool(_watchForPendingAcceptKey) != true) return;
      await prefs.writeBool(_watchForPendingAcceptKey, false);
      await _incrementEvent(trialClosedBeforeWatchForAccepted);
    });
  }

  // --- Retention diagnosis instrumentation (local counters) ---

  static void trackOnboardingIntentSelected() {
    unawaited(
      RetentionMetricsTracker.track(
        RetentionMetricsTracker.onboardingIntentSelected,
      ),
    );
  }

  static void trackAudienceWedgeSelected() {
    unawaited(
      RetentionMetricsTracker.track(
        RetentionMetricsTracker.audienceWedgeSelected,
      ),
    );
  }

  static void trackFirstInsightSpecificityRating(
    FirstInsightSpecificityRating rating,
  ) {
    switch (rating) {
      case FirstInsightSpecificityRating.yesSpecific:
        unawaited(
          RetentionMetricsTracker.track(
            RetentionMetricsTracker.firstInsightYesSpecific,
          ),
        );
      case FirstInsightSpecificityRating.tooGeneric:
        unawaited(
          RetentionMetricsTracker.track(
            RetentionMetricsTracker.firstInsightTooGeneric,
          ),
        );
      case FirstInsightSpecificityRating.wrongAngle:
        unawaited(
          RetentionMetricsTracker.track(
            RetentionMetricsTracker.firstInsightWrongAngle,
          ),
        );
    }
  }

  static void trackFirstPromptUsed() {
    unawaited(
      RetentionMetricsTracker.track(RetentionMetricsTracker.firstPromptUsed),
    );
  }

  static void trackLoopModeSelected() {
    unawaited(
      RetentionMetricsTracker.track(RetentionMetricsTracker.loopModeSelected),
    );
  }

  static void trackLoopFirstPromptUsed() {
    unawaited(
      RetentionMetricsTracker.track(
        RetentionMetricsTracker.loopFirstPromptUsed,
      ),
    );
  }

  static void trackLoopFirstRecordingSaved() {
    unawaited(
      RetentionMetricsTracker.track(
        RetentionMetricsTracker.loopFirstRecordingSaved,
      ),
    );
  }

  static void trackLoopReadAccepted() {
    unawaited(
      RetentionMetricsTracker.track(RetentionMetricsTracker.loopReadAccepted),
    );
  }

  static void trackLoopReadRejected() {
    unawaited(
      RetentionMetricsTracker.track(RetentionMetricsTracker.loopReadRejected),
    );
  }

  static void trackLoopUnsupportedRecording() {
    unawaited(
      RetentionMetricsTracker.track(
        RetentionMetricsTracker.loopUnsupportedRecording,
      ),
    );
  }

  static void trackLoopCompleted() {
    unawaited(
      RetentionMetricsTracker.track(RetentionMetricsTracker.loopCompleted),
    );
  }

  static void trackLoopReviewViewed() {
    unawaited(
      RetentionMetricsTracker.track(RetentionMetricsTracker.loopReviewViewed),
    );
  }

  static void trackLoopReviewConfirmed() {
    unawaited(
      RetentionMetricsTracker.track(
        RetentionMetricsTracker.loopReviewConfirmed,
      ),
    );
  }

  static void trackLoopReviewCorrected() {
    unawaited(
      RetentionMetricsTracker.track(
        RetentionMetricsTracker.loopReviewCorrected,
      ),
    );
  }

  static void trackLoopReviewKeptWatching() {
    unawaited(
      RetentionMetricsTracker.track(
        RetentionMetricsTracker.loopReviewKeptWatching,
      ),
    );
  }

  static void trackLoopPaywallTeaserShown() {
    unawaited(
      RetentionMetricsTracker.track(
        RetentionMetricsTracker.loopPaywallTeaserShown,
      ),
    );
  }

  static void trackLoopPaywallTeaserTapped() {
    unawaited(
      RetentionMetricsTracker.track(
        RetentionMetricsTracker.loopPaywallTeaserTapped,
      ),
    );
  }

  static void trackReadUsefulTapped() {
    unawaited(
      RetentionMetricsTracker.track(RetentionMetricsTracker.readUsefulTapped),
    );
  }

  static void trackReadNotQuiteTapped() {
    unawaited(
      RetentionMetricsTracker.track(RetentionMetricsTracker.readNotQuiteTapped),
    );
  }

  static void trackInterpretationStrong() {
    unawaited(
      RetentionMetricsTracker.track(
        RetentionMetricsTracker.interpretationStrongCount,
      ),
    );
  }

  static void trackInterpretationWeak() {
    unawaited(
      RetentionMetricsTracker.track(
        RetentionMetricsTracker.interpretationWeakCount,
      ),
    );
  }

  static void trackReminderTimingOffered() {
    unawaited(
      RetentionMetricsTracker.track(
        RetentionMetricsTracker.reminderTimingOffered,
      ),
    );
  }

  static void trackReminderTimingSelected() {
    unawaited(
      RetentionMetricsTracker.track(
        RetentionMetricsTracker.reminderTimingSelected,
      ),
    );
  }

  static void trackReminderPrePromptDismissed() {
    unawaited(
      RetentionMetricsTracker.track(
        RetentionMetricsTracker.reminderPrePromptDismissed,
      ),
    );
  }

  static void trackReminderReturnRecorded() {
    unawaited(
      RetentionMetricsTracker.track(
        RetentionMetricsTracker.reminderReturnRecorded,
      ),
    );
  }

  static void trackSecondMomentRecorded() {
    unawaited(
      RetentionMetricsTracker.track(
        RetentionMetricsTracker.secondMomentRecorded,
      ),
    );
    unawaited(AcquisitionCohortCoordinator.markSecondMomentRecorded());
    unawaited(_trackProveSecondMomentIfActive());
  }

  static Future<void> _trackProveSecondMomentIfActive() async {
    final loop = await LoopModeCoordinator.loadActive();
    if (loop?.id == LoopModeIds.proveEnough) {
      trackProveSecondMomentRecorded();
    }
  }

  static void trackThirdMomentRecorded() {
    unawaited(
      RetentionMetricsTracker.track(
        RetentionMetricsTracker.thirdMomentRecorded,
      ),
    );
    unawaited(AcquisitionCohortCoordinator.markThirdMomentRecorded());
  }

  static void trackCohortAssigned() {
    unawaited(
      RetentionMetricsTracker.track(RetentionMetricsTracker.cohortAssigned),
    );
  }

  static void trackCohortStartScreenViewed() {
    unawaited(
      RetentionMetricsTracker.track(
        RetentionMetricsTracker.cohortStartScreenViewed,
      ),
    );
  }

  static void trackCohortStartCtaTapped() {
    unawaited(
      RetentionMetricsTracker.track(
        RetentionMetricsTracker.cohortStartCtaTapped,
      ),
    );
  }

  static void trackCohortLoopSelected() {
    unawaited(
      RetentionMetricsTracker.track(RetentionMetricsTracker.cohortLoopSelected),
    );
  }

  static void trackCohortFirstMomentRecorded() {
    unawaited(
      RetentionMetricsTracker.track(
        RetentionMetricsTracker.cohortFirstMomentRecorded,
      ),
    );
  }

  static void trackCohortSecondMomentRecorded() {
    unawaited(
      RetentionMetricsTracker.track(
        RetentionMetricsTracker.cohortSecondMomentRecorded,
      ),
    );
  }

  static void trackCohortThirdMomentRecorded() {
    unawaited(
      RetentionMetricsTracker.track(
        RetentionMetricsTracker.cohortThirdMomentRecorded,
      ),
    );
  }

  static void trackCohortReviewReached() {
    unawaited(
      RetentionMetricsTracker.track(
        RetentionMetricsTracker.cohortReviewReached,
      ),
    );
  }

  static void trackCohortReviewConfirmed() {
    unawaited(
      RetentionMetricsTracker.track(
        RetentionMetricsTracker.cohortReviewConfirmed,
      ),
    );
  }

  static void trackCohortPaywallTeaserTapped() {
    unawaited(
      RetentionMetricsTracker.track(
        RetentionMetricsTracker.cohortPaywallTeaserTapped,
      ),
    );
  }

  static void trackCapacityInviteCopied() {
    unawaited(
      RetentionMetricsTracker.track(
        RetentionMetricsTracker.capacityInviteCopied,
      ),
    );
  }

  static void trackProveInviteCopied() {
    unawaited(
      RetentionMetricsTracker.track(RetentionMetricsTracker.proveInviteCopied),
    );
  }

  static void trackGenericInviteCopied() {
    unawaited(
      RetentionMetricsTracker.track(
        RetentionMetricsTracker.genericInviteCopied,
      ),
    );
  }

  static void trackProveDefaultShown() {
    unawaited(
      RetentionMetricsTracker.track(RetentionMetricsTracker.proveDefaultShown),
    );
  }

  static void trackProveDefaultStarted() {
    unawaited(
      RetentionMetricsTracker.track(
        RetentionMetricsTracker.proveDefaultStarted,
      ),
    );
  }

  static void trackProveFirstMomentRecorded() {
    unawaited(
      RetentionMetricsTracker.track(
        RetentionMetricsTracker.proveFirstMomentRecorded,
      ),
    );
  }

  static void trackProveReadAccepted() {
    unawaited(
      RetentionMetricsTracker.track(RetentionMetricsTracker.proveReadAccepted),
    );
  }

  static void trackProveSecondMomentRecorded() {
    unawaited(
      RetentionMetricsTracker.track(
        RetentionMetricsTracker.proveSecondMomentRecorded,
      ),
    );
  }

  static void trackProveReviewConfirmed() {
    unawaited(
      RetentionMetricsTracker.track(
        RetentionMetricsTracker.proveReviewConfirmed,
      ),
    );
  }

  static void trackProvePaywallTeaserTapped() {
    unawaited(
      RetentionMetricsTracker.track(
        RetentionMetricsTracker.provePaywallTeaserTapped,
      ),
    );
  }

  static void trackRetentionDiagnosisComputed() {
    unawaited(
      RetentionMetricsTracker.track(
        RetentionMetricsTracker.retentionDiagnosisComputed,
      ),
    );
  }
}
