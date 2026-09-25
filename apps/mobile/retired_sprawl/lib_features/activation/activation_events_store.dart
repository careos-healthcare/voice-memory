import 'package:archiveme_mobile/features/activation/activation_tracker.dart' show ActivationTracker;

import 'package:archiveme_mobile/features/recording/recording_dependencies.dart' show ActivationTracker;

import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Local activation funnel counters for the 5-user trial and QA.
class ActivationEventsStore {
  ActivationEventsStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'activation_trial_events';

  Future<ActivationEventCounts> read() async {
    final map = await _prefs.readMap(_key);
    if (map == null || map.isEmpty) {
      return const ActivationEventCounts();
    }
    return ActivationEventCounts.fromMap(map);
  }

  Future<void> write(ActivationEventCounts counts) async {
    await _prefs.writeMap(_key, counts.toMap());
  }

  Future<void> clear() async {
    await _prefs.writeMap(_key, {});
  }

  Future<void> setParticipantId(String? id) async {
    await _prefs.updateMap(
      _key,
      (current) => _counts(current).copyWith(participantId: id?.trim()).toMap(),
    );
  }

  Future<void> recordMemoryQuality({
    required String level,
    required bool tapped,
  }) async {
    await _prefs.updateMap(_key, (current) {
      final counts = _counts(current);
      return counts
          .copyWith(
            memoryQualityShown: tapped
                ? counts.memoryQualityShown
                : counts.memoryQualityShown + 1,
            memoryQualityTapped: tapped
                ? counts.memoryQualityTapped + 1
                : counts.memoryQualityTapped,
            latestMemoryQualityLevel: level,
          )
          .toMap();
    });
  }

  Future<void> recordCurrentObjectiveShown(String type) async {
    await _prefs.updateMap(_key, (current) {
      final counts = _counts(current);
      return counts
          .copyWith(
            currentObjectiveShown: counts.currentObjectiveShown + 1,
            latestCurrentObjectiveType: type,
          )
          .toMap();
    });
  }

  Future<void> recordProValuePreviewShown(String type) async {
    await _prefs.updateMap(_key, (current) {
      final counts = _counts(current);
      return counts
          .copyWith(
            proValuePreviewShown: counts.proValuePreviewShown + 1,
            latestProValuePreviewType: type,
          )
          .toMap();
    });
  }

  Future<ActivationEventCounts> increment(String field) async {
    final next = await _prefs.updateMap(
      _key,
      (current) => _counts(current).incrementField(field).toMap(),
    );
    return ActivationEventCounts.fromMap(next);
  }

  ActivationEventCounts _counts(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return const ActivationEventCounts();
    return ActivationEventCounts.fromMap(map);
  }
}

/// Trial hook metrics — field names match [ActivationTracker] event ids.
class ActivationEventCounts {
  const ActivationEventCounts({
    this.participantId,
    this.firstReflectionSaved = 0,
    this.firstPatternShown = 0,
    this.firstPatternAccepted = 0,
    this.firstPatternCorrected = 0,
    this.watchForPromptShown = 0,
    this.watchForPromptAccepted = 0,
    this.returnCaptureQuickAnswerSelected = 0,
    this.returnedNextDay = 0,
    this.secondReflectionSaved = 0,
    this.comparisonViewed = 0,
    this.usefulnessYes = 0,
    this.usefulnessSortOf = 0,
    this.usefulnessNotReally = 0,
    this.thirdReflectionSaved = 0,
    this.trialAppOpened = 0,
    this.trialRecordCtaTapped = 0,
    this.trialMicPermissionRequested = 0,
    this.trialMicPermissionDenied = 0,
    this.trialRecordingStarted = 0,
    this.trialRecordingCancelled = 0,
    this.trialSaveStarted = 0,
    this.trialSaveCompleted = 0,
    this.trialClosedBeforeWatchForAccepted = 0,
    this.trialExportCopied = 0,
    this.tomorrowCheckInCreated = 0,
    this.tomorrowCheckInDueShown = 0,
    this.tomorrowCheckInOptionSelected = 0,
    this.tomorrowCheckInRecordingStarted = 0,
    this.tomorrowCheckInCompleted = 0,
    this.tomorrowCheckInMissed = 0,
    this.checkInClarityCardShown = 0,
    this.checkInExamplesOpened = 0,
    this.checkInMomentRecorded = 0,
    this.tomorrowQuestionVariantShown = 0,
    this.tomorrowQuestionVariantSelected = 0,
    this.reminderScheduled = 0,
    this.reminderTapped = 0,
    this.reminderNotAvailable = 0,
    this.guidedCheckInShown = 0,
    this.guidedCheckInStepCompleted = 0,
    this.sharperQuestionShown = 0,
    this.sharperQuestionAccepted = 0,
    this.betterResultShown = 0,
    this.betterFirstRecordPromptShown = 0,
    this.betterFirstRecordPromptTapped = 0,
    this.sharperQuestionElevatedShown = 0,
    this.sharperQuestionAggressiveShown = 0,
    this.sharperQuestionAggressiveAccepted = 0,
    this.betterResultElevatedShown = 0,
    this.betterResultAggressiveShown = 0,
    this.checkInGoDeeperShown = 0,
    this.checkInGoDeeperTapped = 0,
    this.reminderPermissionRequested = 0,
    this.reminderPermissionGranted = 0,
    this.reminderPermissionDenied = 0,
    this.reminderCancelled = 0,
    this.patternMemoryCreated = 0,
    this.patternMemoryUpdated = 0,
    this.patternMemoryNextQuestionUsed = 0,
    this.patternProgressMomentCreated = 0,
    this.patternProgressCardShown = 0,
    this.patternProgressNextQuestionUsed = 0,
    this.patternNextActionCreated = 0,
    this.patternNextActionShown = 0,
    this.patternNextActionUsed = 0,
    this.habitProofCreated = 0,
    this.habitProofShown = 0,
    this.habitProofCtaTapped = 0,
    this.weeklyPatternRecapCreated = 0,
    this.weeklyPatternRecapShown = 0,
    this.weeklyPatternRecapCtaTapped = 0,
    this.patternShareCardShown = 0,
    this.patternShareCopied = 0,
    this.patternShareOpened = 0,
    this.patternShareFailed = 0,
    this.firstLoopRecordOpened = 0,
    this.firstLoopRecordingStarted = 0,
    this.firstLoopMomentSaved = 0,
    this.firstLoopPatternShown = 0,
    this.firstLoopTomorrowCheckChosen = 0,
    this.firstLoopReady = 0,
    this.returnDayDueShown = 0,
    this.returnDayAnswerSelected = 0,
    this.returnDayRecordingStarted = 0,
    this.returnDayMomentSaved = 0,
    this.returnDayLoopClosed = 0,
    this.returnDayAbandonedAfterAnswer = 0,
    this.resultNextCheckShown = 0,
    this.resultNextCheckUsed = 0,
    this.resultNextCheckChanged = 0,
    this.resultNextCheckUsedFromPatterns = 0,
    this.usefulResultTakeawayShown = 0,
    this.makeResultMoreUsefulTapped = 0,
    this.makeResultMoreUsefulReasonSelected = 0,
    this.usefulResultNextCheckUsed = 0,
    this.inputQualityCoachShown = 0,
    this.inputQualitySentenceAdded = 0,
    this.inputQualityUsedAnyway = 0,
    this.acceptedWeakInputCount = 0,
    this.sharpenedInputCount = 0,
    this.perspectiveShiftShown = 0,
    this.perspectiveShiftChanged = 0,
    this.perspectiveShiftUsed = 0,
    this.perspectiveShiftShownFromPatterns = 0,
    this.perspectiveShiftUsedFromPatterns = 0,
    this.kinderAngleShown = 0,
    this.kinderAngleUsed = 0,
    this.kinderAngleChanged = 0,
    this.kinderAngleShownFromPatterns = 0,
    this.kinderAngleUsedFromPatterns = 0,
    this.quickHelpOpened = 0,
    this.quickHelpIntentSelected = 0,
    this.quickHelpPrimaryActionTapped = 0,
    this.quickHelpCheckUsed = 0,
    this.keyMomentCreated = 0,
    this.keyMomentOpened = 0,
    this.keyMomentSearchUsed = 0,
    this.keyMomentUseCheckTapped = 0,
    this.askArchiveOpened = 0,
    this.askArchiveSearchUsed = 0,
    this.askArchiveSuggestedChipTapped = 0,
    this.askArchiveResultOpened = 0,
    this.askArchiveUseCheckTapped = 0,
    this.archiveCleanViewShown = 0,
    this.archiveCleanSectionTapped = 0,
    this.patternProfileShown = 0,
    this.patternProfileOpened = 0,
    this.patternProfileUseCheckTapped = 0,
    this.patternProfileFindMomentsTapped = 0,
    this.patternProfileOpenTimelineTapped = 0,
    this.patternMapShown = 0,
    this.patternMapOpened = 0,
    this.patternMapUseCheckTapped = 0,
    this.archiveFeedbackShown = 0,
    this.archiveFeedbackSelected = 0,
    this.archiveFeedbackUseful = 0,
    this.archiveFeedbackTooGeneric = 0,
    this.archiveFeedbackNotMe = 0,
    this.archiveFeedbackAlreadyKnew = 0,
    this.archiveFeedbackMoreSpecific = 0,
    this.archiveCompressionShown = 0,
    this.archiveCompressionOpened = 0,
    this.archiveCompressionKept = 0,
    this.archiveCompressionSplit = 0,
    this.archiveCompressionHidden = 0,
    this.memoryQualityShown = 0,
    this.memoryQualityTapped = 0,
    this.latestMemoryQualityLevel,
    this.paywallShown = 0,
    this.paywallTriggerShown = 0,
    this.annualPlanShown = 0,
    this.monthlyPlanShown = 0,
    this.annualPlanSelected = 0,
    this.monthlyPlanSelected = 0,
    this.paywallContinueTapped = 0,
    this.paywallDismissed = 0,
    this.restoreTapped = 0,
    this.archiveRangeReviewShown = 0,
    this.archiveRangeReviewOpened = 0,
    this.archiveRangeReviewUseCheckTapped = 0,
    this.archiveRangeReviewPresetChanged = 0,
    this.retentionStateShown = 0,
    this.retentionDueShown = 0,
    this.retentionCheckSetShown = 0,
    this.retentionLoopClosedShown = 0,
    this.retentionPrimaryCtaTapped = 0,
    this.retentionSecondaryCtaTapped = 0,
    this.retentionNextCheckReady = 0,
    this.retentionMissedCheck = 0,
    this.reminderScheduledFromRetention = 0,
    this.compellingCheckShown = 0,
    this.compellingCheckSelected = 0,
    this.compellingCheckMostSpecificSelected = 0,
    this.compellingCheckAccepted = 0,
    this.realReminderPermissionRequested = 0,
    this.realReminderPermissionGranted = 0,
    this.realReminderPermissionDenied = 0,
    this.realReminderScheduled = 0,
    this.realReminderCancelled = 0,
    this.realReminderUnavailable = 0,
    this.realReminderTapped = 0,
    this.currentObjectiveShown = 0,
    this.currentObjectivePrimaryTapped = 0,
    this.currentObjectiveSecondaryTapped = 0,
    this.latestCurrentObjectiveType,
    this.proValuePreviewShown = 0,
    this.proValuePreviewUnlockTapped = 0,
    this.proValuePreviewDismissed = 0,
    this.latestProValuePreviewType,
    this.objectiveWidgetRefreshAttempted = 0,
    this.objectiveWidgetRefreshSucceeded = 0,
    this.objectiveWidgetRefreshFailed = 0,
    this.objectiveWidgetCleared = 0,
    this.archiveMemorySummaryShown = 0,
    this.archiveMemoryOpenPatternMapTapped = 0,
    this.archiveMemoryFindMomentsTapped = 0,
    this.archiveMemoryUseCheckTapped = 0,
    this.archiveTimelineShown = 0,
    this.archiveTimelineOpened = 0,
    this.archiveTimelineUseCheckTapped = 0,
    this.archiveMemoryDemoShown = 0,
    this.archiveMemoryDemoCtaTapped = 0,
    this.archiveMemoryPreviewShown = 0,
    this.archiveMemoryPreviewCtaTapped = 0,
    this.positioningComprehensionAsked = 0,
    this.positioningComprehensionAnswered = 0,
    this.positioningUnderstoodArchiveMemory = 0,
    this.positioningJournal = 0,
    this.positioningChat = 0,
    this.positioningNotSure = 0,
    this.activationFirstRecordCardShown = 0,
    this.activationFirstRecordCtaTapped = 0,
    this.activationStarterPromptSelected = 0,
    this.activationFirstSaveCompleted = 0,
    this.activationTomorrowCheckShown = 0,
    this.activationTomorrowCheckUsed = 0,
    this.activationTomorrowCheckSharpened = 0,
    this.activationTomorrowCheckIgnored = 0,
    this.activationUsefulTakeawayShown = 0,
    this.activationMakeUsefulTapped = 0,
    this.activationMakeUsefulReasonSelected = 0,
    this.activationResultRatedUseful = 0,
    this.activationResultRatedSortOf = 0,
    this.activationResultRatedNotUseful = 0,
    this.activationNextCheckShown = 0,
    this.activationNextCheckUsed = 0,
    this.activationNextCheckChanged = 0,
    this.activationRoutineAnchorOffered = 0,
    this.activationRoutineAnchorSet = 0,
  });

  factory ActivationEventCounts.fromMap(Map<String, dynamic> map) {
    int n(String key) => (map[key] as num?)?.toInt() ?? 0;
    return ActivationEventCounts(
      participantId: map['participantId'] as String?,
      firstReflectionSaved: n('firstReflectionSaved'),
      firstPatternShown: n('firstPatternShown'),
      firstPatternAccepted: n('firstPatternAccepted'),
      firstPatternCorrected: n('firstPatternCorrected'),
      watchForPromptShown: n('watchForPromptShown'),
      watchForPromptAccepted: n('watchForPromptAccepted'),
      returnCaptureQuickAnswerSelected: n('returnCaptureQuickAnswerSelected'),
      returnedNextDay: n('returnedNextDay'),
      secondReflectionSaved: n('secondReflectionSaved'),
      comparisonViewed: n('comparisonViewed'),
      usefulnessYes: n('usefulnessYes'),
      usefulnessSortOf: n('usefulnessSortOf'),
      usefulnessNotReally: n('usefulnessNotReally'),
      thirdReflectionSaved: n('thirdReflectionSaved'),
      trialAppOpened: n('trialAppOpened'),
      trialRecordCtaTapped: n('trialRecordCtaTapped'),
      trialMicPermissionRequested: n('trialMicPermissionRequested'),
      trialMicPermissionDenied: n('trialMicPermissionDenied'),
      trialRecordingStarted: n('trialRecordingStarted'),
      trialRecordingCancelled: n('trialRecordingCancelled'),
      trialSaveStarted: n('trialSaveStarted'),
      trialSaveCompleted: n('trialSaveCompleted'),
      trialClosedBeforeWatchForAccepted: n('trialClosedBeforeWatchForAccepted'),
      trialExportCopied: n('trialExportCopied'),
      tomorrowCheckInCreated: n('tomorrowCheckInCreated'),
      tomorrowCheckInDueShown: n('tomorrowCheckInDueShown'),
      tomorrowCheckInOptionSelected: n('tomorrowCheckInOptionSelected'),
      tomorrowCheckInRecordingStarted: n('tomorrowCheckInRecordingStarted'),
      tomorrowCheckInCompleted: n('tomorrowCheckInCompleted'),
      tomorrowCheckInMissed: n('tomorrowCheckInMissed'),
      checkInClarityCardShown: n('checkInClarityCardShown'),
      checkInExamplesOpened: n('checkInExamplesOpened'),
      checkInMomentRecorded: n('checkInMomentRecorded'),
      tomorrowQuestionVariantShown: n('tomorrowQuestionVariantShown'),
      tomorrowQuestionVariantSelected: n('tomorrowQuestionVariantSelected'),
      reminderScheduled: n('reminderScheduled'),
      reminderTapped: n('reminderTapped'),
      reminderNotAvailable: n('reminderNotAvailable'),
      guidedCheckInShown: n('guidedCheckInShown'),
      guidedCheckInStepCompleted: n('guidedCheckInStepCompleted'),
      sharperQuestionShown: n('sharperQuestionShown'),
      sharperQuestionAccepted: n('sharperQuestionAccepted'),
      betterResultShown: n('betterResultShown'),
      betterFirstRecordPromptShown: n('betterFirstRecordPromptShown'),
      betterFirstRecordPromptTapped: n('betterFirstRecordPromptTapped'),
      sharperQuestionElevatedShown: n('sharperQuestionElevatedShown'),
      sharperQuestionAggressiveShown: n('sharperQuestionAggressiveShown'),
      sharperQuestionAggressiveAccepted: n('sharperQuestionAggressiveAccepted'),
      betterResultElevatedShown: n('betterResultElevatedShown'),
      betterResultAggressiveShown: n('betterResultAggressiveShown'),
      checkInGoDeeperShown: n('checkInGoDeeperShown'),
      checkInGoDeeperTapped: n('checkInGoDeeperTapped'),
      reminderPermissionRequested: n('reminderPermissionRequested'),
      reminderPermissionGranted: n('reminderPermissionGranted'),
      reminderPermissionDenied: n('reminderPermissionDenied'),
      reminderCancelled: n('reminderCancelled'),
      patternMemoryCreated: n('patternMemoryCreated'),
      patternMemoryUpdated: n('patternMemoryUpdated'),
      patternMemoryNextQuestionUsed: n('patternMemoryNextQuestionUsed'),
      patternProgressMomentCreated: n('patternProgressMomentCreated'),
      patternProgressCardShown: n('patternProgressCardShown'),
      patternProgressNextQuestionUsed: n('patternProgressNextQuestionUsed'),
      patternNextActionCreated: n('patternNextActionCreated'),
      patternNextActionShown: n('patternNextActionShown'),
      patternNextActionUsed: n('patternNextActionUsed'),
      habitProofCreated: n('habitProofCreated'),
      habitProofShown: n('habitProofShown'),
      habitProofCtaTapped: n('habitProofCtaTapped'),
      weeklyPatternRecapCreated: n('weeklyPatternRecapCreated'),
      weeklyPatternRecapShown: n('weeklyPatternRecapShown'),
      weeklyPatternRecapCtaTapped: n('weeklyPatternRecapCtaTapped'),
      patternShareCardShown: n('patternShareCardShown'),
      patternShareCopied: n('patternShareCopied'),
      patternShareOpened: n('patternShareOpened'),
      patternShareFailed: n('patternShareFailed'),
      firstLoopRecordOpened: n('firstLoopRecordOpened'),
      firstLoopRecordingStarted: n('firstLoopRecordingStarted'),
      firstLoopMomentSaved: n('firstLoopMomentSaved'),
      firstLoopPatternShown: n('firstLoopPatternShown'),
      firstLoopTomorrowCheckChosen: n('firstLoopTomorrowCheckChosen'),
      firstLoopReady: n('firstLoopReady'),
      returnDayDueShown: n('returnDayDueShown'),
      returnDayAnswerSelected: n('returnDayAnswerSelected'),
      returnDayRecordingStarted: n('returnDayRecordingStarted'),
      returnDayMomentSaved: n('returnDayMomentSaved'),
      returnDayLoopClosed: n('returnDayLoopClosed'),
      returnDayAbandonedAfterAnswer: n('returnDayAbandonedAfterAnswer'),
      resultNextCheckShown: n('resultNextCheckShown'),
      resultNextCheckUsed: n('resultNextCheckUsed'),
      resultNextCheckChanged: n('resultNextCheckChanged'),
      resultNextCheckUsedFromPatterns: n('resultNextCheckUsedFromPatterns'),
      usefulResultTakeawayShown: n('usefulResultTakeawayShown'),
      makeResultMoreUsefulTapped: n('makeResultMoreUsefulTapped'),
      makeResultMoreUsefulReasonSelected: n(
        'makeResultMoreUsefulReasonSelected',
      ),
      usefulResultNextCheckUsed: n('usefulResultNextCheckUsed'),
      inputQualityCoachShown: n('inputQualityCoachShown'),
      inputQualitySentenceAdded: n('inputQualitySentenceAdded'),
      inputQualityUsedAnyway: n('inputQualityUsedAnyway'),
      acceptedWeakInputCount: n('acceptedWeakInputCount'),
      sharpenedInputCount: n('sharpenedInputCount'),
      perspectiveShiftShown: n('perspectiveShiftShown'),
      perspectiveShiftChanged: n('perspectiveShiftChanged'),
      perspectiveShiftUsed: n('perspectiveShiftUsed'),
      perspectiveShiftShownFromPatterns: n('perspectiveShiftShownFromPatterns'),
      perspectiveShiftUsedFromPatterns: n('perspectiveShiftUsedFromPatterns'),
      kinderAngleShown: n('kinderAngleShown'),
      kinderAngleUsed: n('kinderAngleUsed'),
      kinderAngleChanged: n('kinderAngleChanged'),
      kinderAngleShownFromPatterns: n('kinderAngleShownFromPatterns'),
      kinderAngleUsedFromPatterns: n('kinderAngleUsedFromPatterns'),
      quickHelpOpened: n('quickHelpOpened'),
      quickHelpIntentSelected: n('quickHelpIntentSelected'),
      quickHelpPrimaryActionTapped: n('quickHelpPrimaryActionTapped'),
      quickHelpCheckUsed: n('quickHelpCheckUsed'),
      keyMomentCreated: n('keyMomentCreated'),
      keyMomentOpened: n('keyMomentOpened'),
      keyMomentSearchUsed: n('keyMomentSearchUsed'),
      keyMomentUseCheckTapped: n('keyMomentUseCheckTapped'),
      askArchiveOpened: n('askArchiveOpened'),
      askArchiveSearchUsed: n('askArchiveSearchUsed'),
      askArchiveSuggestedChipTapped: n('askArchiveSuggestedChipTapped'),
      askArchiveResultOpened: n('askArchiveResultOpened'),
      askArchiveUseCheckTapped: n('askArchiveUseCheckTapped'),
      archiveCleanViewShown: n('archiveCleanViewShown'),
      archiveCleanSectionTapped: n('archiveCleanSectionTapped'),
      patternProfileShown: n('patternProfileShown'),
      patternProfileOpened: n('patternProfileOpened'),
      patternProfileUseCheckTapped: n('patternProfileUseCheckTapped'),
      patternProfileFindMomentsTapped: n('patternProfileFindMomentsTapped'),
      patternProfileOpenTimelineTapped: n('patternProfileOpenTimelineTapped'),
      patternMapShown: n('patternMapShown'),
      patternMapOpened: n('patternMapOpened'),
      patternMapUseCheckTapped: n('patternMapUseCheckTapped'),
      archiveFeedbackShown: n('archiveFeedbackShown'),
      archiveFeedbackSelected: n('archiveFeedbackSelected'),
      archiveFeedbackUseful: n('archiveFeedbackUseful'),
      archiveFeedbackTooGeneric: n('archiveFeedbackTooGeneric'),
      archiveFeedbackNotMe: n('archiveFeedbackNotMe'),
      archiveFeedbackAlreadyKnew: n('archiveFeedbackAlreadyKnew'),
      archiveFeedbackMoreSpecific: n('archiveFeedbackMoreSpecific'),
      archiveCompressionShown: n('archiveCompressionShown'),
      archiveCompressionOpened: n('archiveCompressionOpened'),
      archiveCompressionKept: n('archiveCompressionKept'),
      archiveCompressionSplit: n('archiveCompressionSplit'),
      archiveCompressionHidden: n('archiveCompressionHidden'),
      memoryQualityShown: n('memoryQualityShown'),
      memoryQualityTapped: n('memoryQualityTapped'),
      latestMemoryQualityLevel: map['latestMemoryQualityLevel'] as String?,
      paywallShown: n('paywallShown'),
      paywallTriggerShown: n('paywallTriggerShown'),
      annualPlanShown: n('annualPlanShown'),
      monthlyPlanShown: n('monthlyPlanShown'),
      annualPlanSelected: n('annualPlanSelected'),
      monthlyPlanSelected: n('monthlyPlanSelected'),
      paywallContinueTapped: n('paywallContinueTapped'),
      paywallDismissed: n('paywallDismissed'),
      restoreTapped: n('restoreTapped'),
      archiveRangeReviewShown: n('archiveRangeReviewShown'),
      archiveRangeReviewOpened: n('archiveRangeReviewOpened'),
      archiveRangeReviewUseCheckTapped: n('archiveRangeReviewUseCheckTapped'),
      archiveRangeReviewPresetChanged: n('archiveRangeReviewPresetChanged'),
      retentionStateShown: n('retentionStateShown'),
      retentionDueShown: n('retentionDueShown'),
      retentionCheckSetShown: n('retentionCheckSetShown'),
      retentionLoopClosedShown: n('retentionLoopClosedShown'),
      retentionPrimaryCtaTapped: n('retentionPrimaryCtaTapped'),
      retentionSecondaryCtaTapped: n('retentionSecondaryCtaTapped'),
      retentionNextCheckReady: n('retentionNextCheckReady'),
      retentionMissedCheck: n('retentionMissedCheck'),
      reminderScheduledFromRetention: n('reminderScheduledFromRetention'),
      compellingCheckShown: n('compellingCheckShown'),
      compellingCheckSelected: n('compellingCheckSelected'),
      compellingCheckMostSpecificSelected: n(
        'compellingCheckMostSpecificSelected',
      ),
      compellingCheckAccepted: n('compellingCheckAccepted'),
      realReminderPermissionRequested: n('realReminderPermissionRequested'),
      realReminderPermissionGranted: n('realReminderPermissionGranted'),
      realReminderPermissionDenied: n('realReminderPermissionDenied'),
      realReminderScheduled: n('realReminderScheduled'),
      realReminderCancelled: n('realReminderCancelled'),
      realReminderUnavailable: n('realReminderUnavailable'),
      realReminderTapped: n('realReminderTapped'),
      currentObjectiveShown: n('currentObjectiveShown'),
      currentObjectivePrimaryTapped: n('currentObjectivePrimaryTapped'),
      currentObjectiveSecondaryTapped: n('currentObjectiveSecondaryTapped'),
      latestCurrentObjectiveType: map['latestCurrentObjectiveType'] as String?,
      proValuePreviewShown: n('proValuePreviewShown'),
      proValuePreviewUnlockTapped: n('proValuePreviewUnlockTapped'),
      proValuePreviewDismissed: n('proValuePreviewDismissed'),
      latestProValuePreviewType: map['latestProValuePreviewType'] as String?,
      objectiveWidgetRefreshAttempted: n('objectiveWidgetRefreshAttempted'),
      objectiveWidgetRefreshSucceeded: n('objectiveWidgetRefreshSucceeded'),
      objectiveWidgetRefreshFailed: n('objectiveWidgetRefreshFailed'),
      objectiveWidgetCleared: n('objectiveWidgetCleared'),
      archiveMemorySummaryShown: n('archiveMemorySummaryShown'),
      archiveMemoryOpenPatternMapTapped: n('archiveMemoryOpenPatternMapTapped'),
      archiveMemoryFindMomentsTapped: n('archiveMemoryFindMomentsTapped'),
      archiveMemoryUseCheckTapped: n('archiveMemoryUseCheckTapped'),
      archiveTimelineShown: n('archiveTimelineShown'),
      archiveTimelineOpened: n('archiveTimelineOpened'),
      archiveTimelineUseCheckTapped: n('archiveTimelineUseCheckTapped'),
      archiveMemoryDemoShown: n('archiveMemoryDemoShown'),
      archiveMemoryDemoCtaTapped: n('archiveMemoryDemoCtaTapped'),
      archiveMemoryPreviewShown: n('archiveMemoryPreviewShown'),
      archiveMemoryPreviewCtaTapped: n('archiveMemoryPreviewCtaTapped'),
      positioningComprehensionAsked: n('positioningComprehensionAsked'),
      positioningComprehensionAnswered: n('positioningComprehensionAnswered'),
      positioningUnderstoodArchiveMemory: n(
        'positioningUnderstoodArchiveMemory',
      ),
      positioningJournal: n('positioningJournal'),
      positioningChat: n('positioningChat'),
      positioningNotSure: n('positioningNotSure'),
      activationFirstRecordCardShown: n('activationFirstRecordCardShown'),
      activationFirstRecordCtaTapped: n('activationFirstRecordCtaTapped'),
      activationStarterPromptSelected: n('activationStarterPromptSelected'),
      activationFirstSaveCompleted: n('activationFirstSaveCompleted'),
      activationTomorrowCheckShown: n('activationTomorrowCheckShown'),
      activationTomorrowCheckUsed: n('activationTomorrowCheckUsed'),
      activationTomorrowCheckSharpened: n('activationTomorrowCheckSharpened'),
      activationTomorrowCheckIgnored: n('activationTomorrowCheckIgnored'),
      activationUsefulTakeawayShown: n('activationUsefulTakeawayShown'),
      activationMakeUsefulTapped: n('activationMakeUsefulTapped'),
      activationMakeUsefulReasonSelected: n(
        'activationMakeUsefulReasonSelected',
      ),
      activationResultRatedUseful: n('activationResultRatedUseful'),
      activationResultRatedSortOf: n('activationResultRatedSortOf'),
      activationResultRatedNotUseful: n('activationResultRatedNotUseful'),
      activationNextCheckShown: n('activationNextCheckShown'),
      activationNextCheckUsed: n('activationNextCheckUsed'),
      activationNextCheckChanged: n('activationNextCheckChanged'),
      activationRoutineAnchorOffered: n('activationRoutineAnchorOffered'),
      activationRoutineAnchorSet: n('activationRoutineAnchorSet'),
    );
  }

  final String? participantId;
  final int firstReflectionSaved;
  final int firstPatternShown;
  final int firstPatternAccepted;
  final int firstPatternCorrected;
  final int watchForPromptShown;
  final int watchForPromptAccepted;
  final int returnCaptureQuickAnswerSelected;
  final int returnedNextDay;
  final int secondReflectionSaved;
  final int comparisonViewed;
  final int usefulnessYes;
  final int usefulnessSortOf;
  final int usefulnessNotReally;
  final int thirdReflectionSaved;
  final int trialAppOpened;
  final int trialRecordCtaTapped;
  final int trialMicPermissionRequested;
  final int trialMicPermissionDenied;
  final int trialRecordingStarted;
  final int trialRecordingCancelled;
  final int trialSaveStarted;
  final int trialSaveCompleted;
  final int trialClosedBeforeWatchForAccepted;
  final int trialExportCopied;
  final int tomorrowCheckInCreated;
  final int tomorrowCheckInDueShown;
  final int tomorrowCheckInOptionSelected;
  final int tomorrowCheckInRecordingStarted;
  final int tomorrowCheckInCompleted;
  final int tomorrowCheckInMissed;
  final int checkInClarityCardShown;
  final int checkInExamplesOpened;
  final int checkInMomentRecorded;
  final int tomorrowQuestionVariantShown;
  final int tomorrowQuestionVariantSelected;
  final int reminderScheduled;
  final int reminderTapped;
  final int reminderNotAvailable;
  final int guidedCheckInShown;
  final int guidedCheckInStepCompleted;
  final int sharperQuestionShown;
  final int sharperQuestionAccepted;
  final int betterResultShown;
  final int betterFirstRecordPromptShown;
  final int betterFirstRecordPromptTapped;
  final int sharperQuestionElevatedShown;
  final int sharperQuestionAggressiveShown;
  final int sharperQuestionAggressiveAccepted;
  final int betterResultElevatedShown;
  final int betterResultAggressiveShown;
  final int checkInGoDeeperShown;
  final int checkInGoDeeperTapped;
  final int reminderPermissionRequested;
  final int reminderPermissionGranted;
  final int reminderPermissionDenied;
  final int reminderCancelled;
  final int patternMemoryCreated;
  final int patternMemoryUpdated;
  final int patternMemoryNextQuestionUsed;
  final int patternProgressMomentCreated;
  final int patternProgressCardShown;
  final int patternProgressNextQuestionUsed;
  final int patternNextActionCreated;
  final int patternNextActionShown;
  final int patternNextActionUsed;
  final int habitProofCreated;
  final int habitProofShown;
  final int habitProofCtaTapped;
  final int weeklyPatternRecapCreated;
  final int weeklyPatternRecapShown;
  final int weeklyPatternRecapCtaTapped;
  final int patternShareCardShown;
  final int patternShareCopied;
  final int patternShareOpened;
  final int patternShareFailed;
  final int firstLoopRecordOpened;
  final int firstLoopRecordingStarted;
  final int firstLoopMomentSaved;
  final int firstLoopPatternShown;
  final int firstLoopTomorrowCheckChosen;
  final int firstLoopReady;
  final int returnDayDueShown;
  final int returnDayAnswerSelected;
  final int returnDayRecordingStarted;
  final int returnDayMomentSaved;
  final int returnDayLoopClosed;
  final int returnDayAbandonedAfterAnswer;
  final int resultNextCheckShown;
  final int resultNextCheckUsed;
  final int resultNextCheckChanged;
  final int resultNextCheckUsedFromPatterns;
  final int usefulResultTakeawayShown;
  final int makeResultMoreUsefulTapped;
  final int makeResultMoreUsefulReasonSelected;
  final int usefulResultNextCheckUsed;
  final int inputQualityCoachShown;
  final int inputQualitySentenceAdded;
  final int inputQualityUsedAnyway;
  final int acceptedWeakInputCount;
  final int sharpenedInputCount;
  final int perspectiveShiftShown;
  final int perspectiveShiftChanged;
  final int perspectiveShiftUsed;
  final int perspectiveShiftShownFromPatterns;
  final int perspectiveShiftUsedFromPatterns;
  final int kinderAngleShown;
  final int kinderAngleUsed;
  final int kinderAngleChanged;
  final int kinderAngleShownFromPatterns;
  final int kinderAngleUsedFromPatterns;
  final int quickHelpOpened;
  final int quickHelpIntentSelected;
  final int quickHelpPrimaryActionTapped;
  final int quickHelpCheckUsed;
  final int keyMomentCreated;
  final int keyMomentOpened;
  final int keyMomentSearchUsed;
  final int keyMomentUseCheckTapped;
  final int askArchiveOpened;
  final int askArchiveSearchUsed;
  final int askArchiveSuggestedChipTapped;
  final int askArchiveResultOpened;
  final int askArchiveUseCheckTapped;
  final int archiveCleanViewShown;
  final int archiveCleanSectionTapped;
  final int patternProfileShown;
  final int patternProfileOpened;
  final int patternProfileUseCheckTapped;
  final int patternProfileFindMomentsTapped;
  final int patternProfileOpenTimelineTapped;
  final int patternMapShown;
  final int patternMapOpened;
  final int patternMapUseCheckTapped;
  final int archiveFeedbackShown;
  final int archiveFeedbackSelected;
  final int archiveFeedbackUseful;
  final int archiveFeedbackTooGeneric;
  final int archiveFeedbackNotMe;
  final int archiveFeedbackAlreadyKnew;
  final int archiveFeedbackMoreSpecific;
  final int archiveCompressionShown;
  final int archiveCompressionOpened;
  final int archiveCompressionKept;
  final int archiveCompressionSplit;
  final int archiveCompressionHidden;
  final int memoryQualityShown;
  final int memoryQualityTapped;
  final String? latestMemoryQualityLevel;
  final int paywallShown;
  final int paywallTriggerShown;
  final int annualPlanShown;
  final int monthlyPlanShown;
  final int annualPlanSelected;
  final int monthlyPlanSelected;
  final int paywallContinueTapped;
  final int paywallDismissed;
  final int restoreTapped;
  final int archiveRangeReviewShown;
  final int archiveRangeReviewOpened;
  final int archiveRangeReviewUseCheckTapped;
  final int archiveRangeReviewPresetChanged;
  final int retentionStateShown;
  final int retentionDueShown;
  final int retentionCheckSetShown;
  final int retentionLoopClosedShown;
  final int retentionPrimaryCtaTapped;
  final int retentionSecondaryCtaTapped;
  final int retentionNextCheckReady;
  final int retentionMissedCheck;
  final int reminderScheduledFromRetention;
  final int compellingCheckShown;
  final int compellingCheckSelected;
  final int compellingCheckMostSpecificSelected;
  final int compellingCheckAccepted;
  final int realReminderPermissionRequested;
  final int realReminderPermissionGranted;
  final int realReminderPermissionDenied;
  final int realReminderScheduled;
  final int realReminderCancelled;
  final int realReminderUnavailable;
  final int realReminderTapped;
  final int currentObjectiveShown;
  final int currentObjectivePrimaryTapped;
  final int currentObjectiveSecondaryTapped;
  final String? latestCurrentObjectiveType;
  final int proValuePreviewShown;
  final int proValuePreviewUnlockTapped;
  final int proValuePreviewDismissed;
  final String? latestProValuePreviewType;
  final int objectiveWidgetRefreshAttempted;
  final int objectiveWidgetRefreshSucceeded;
  final int objectiveWidgetRefreshFailed;
  final int objectiveWidgetCleared;
  final int archiveMemorySummaryShown;
  final int archiveMemoryOpenPatternMapTapped;
  final int archiveMemoryFindMomentsTapped;
  final int archiveMemoryUseCheckTapped;
  final int archiveTimelineShown;
  final int archiveTimelineOpened;
  final int archiveTimelineUseCheckTapped;
  final int archiveMemoryDemoShown;
  final int archiveMemoryDemoCtaTapped;
  final int archiveMemoryPreviewShown;
  final int archiveMemoryPreviewCtaTapped;
  final int positioningComprehensionAsked;
  final int positioningComprehensionAnswered;
  final int positioningUnderstoodArchiveMemory;
  final int positioningJournal;
  final int positioningChat;
  final int positioningNotSure;
  final int activationFirstRecordCardShown;
  final int activationFirstRecordCtaTapped;
  final int activationStarterPromptSelected;
  final int activationFirstSaveCompleted;
  final int activationTomorrowCheckShown;
  final int activationTomorrowCheckUsed;
  final int activationTomorrowCheckSharpened;
  final int activationTomorrowCheckIgnored;
  final int activationUsefulTakeawayShown;
  final int activationMakeUsefulTapped;
  final int activationMakeUsefulReasonSelected;
  final int activationResultRatedUseful;
  final int activationResultRatedSortOf;
  final int activationResultRatedNotUseful;
  final int activationNextCheckShown;
  final int activationNextCheckUsed;
  final int activationNextCheckChanged;
  final int activationRoutineAnchorOffered;
  final int activationRoutineAnchorSet;

  static const fieldNames = [
    'firstReflectionSaved',
    'firstPatternShown',
    'firstPatternAccepted',
    'firstPatternCorrected',
    'watchForPromptShown',
    'watchForPromptAccepted',
    'returnCaptureQuickAnswerSelected',
    'returnedNextDay',
    'secondReflectionSaved',
    'comparisonViewed',
    'usefulnessYes',
    'usefulnessSortOf',
    'usefulnessNotReally',
    'thirdReflectionSaved',
    'trialAppOpened',
    'trialRecordCtaTapped',
    'trialMicPermissionRequested',
    'trialMicPermissionDenied',
    'trialRecordingStarted',
    'trialRecordingCancelled',
    'trialSaveStarted',
    'trialSaveCompleted',
    'trialClosedBeforeWatchForAccepted',
    'trialExportCopied',
    'tomorrowCheckInCreated',
    'tomorrowCheckInDueShown',
    'tomorrowCheckInOptionSelected',
    'tomorrowCheckInRecordingStarted',
    'tomorrowCheckInCompleted',
    'tomorrowCheckInMissed',
    'checkInClarityCardShown',
    'checkInExamplesOpened',
    'checkInMomentRecorded',
    'tomorrowQuestionVariantShown',
    'tomorrowQuestionVariantSelected',
    'reminderScheduled',
    'reminderTapped',
    'reminderNotAvailable',
    'guidedCheckInShown',
    'guidedCheckInStepCompleted',
    'sharperQuestionShown',
    'sharperQuestionAccepted',
    'betterResultShown',
    'betterFirstRecordPromptShown',
    'betterFirstRecordPromptTapped',
    'sharperQuestionElevatedShown',
    'sharperQuestionAggressiveShown',
    'sharperQuestionAggressiveAccepted',
    'betterResultElevatedShown',
    'betterResultAggressiveShown',
    'checkInGoDeeperShown',
    'checkInGoDeeperTapped',
    'reminderPermissionRequested',
    'reminderPermissionGranted',
    'reminderPermissionDenied',
    'reminderCancelled',
    'patternMemoryCreated',
    'patternMemoryUpdated',
    'patternMemoryNextQuestionUsed',
    'patternProgressMomentCreated',
    'patternProgressCardShown',
    'patternProgressNextQuestionUsed',
    'patternNextActionCreated',
    'patternNextActionShown',
    'patternNextActionUsed',
    'habitProofCreated',
    'habitProofShown',
    'habitProofCtaTapped',
    'weeklyPatternRecapCreated',
    'weeklyPatternRecapShown',
    'weeklyPatternRecapCtaTapped',
    'patternShareCardShown',
    'patternShareCopied',
    'patternShareOpened',
    'patternShareFailed',
    'firstLoopRecordOpened',
    'firstLoopRecordingStarted',
    'firstLoopMomentSaved',
    'firstLoopPatternShown',
    'firstLoopTomorrowCheckChosen',
    'firstLoopReady',
    'returnDayDueShown',
    'returnDayAnswerSelected',
    'returnDayRecordingStarted',
    'returnDayMomentSaved',
    'returnDayLoopClosed',
    'returnDayAbandonedAfterAnswer',
    'resultNextCheckShown',
    'resultNextCheckUsed',
    'resultNextCheckChanged',
    'resultNextCheckUsedFromPatterns',
    'usefulResultTakeawayShown',
    'makeResultMoreUsefulTapped',
    'makeResultMoreUsefulReasonSelected',
    'usefulResultNextCheckUsed',
    'inputQualityCoachShown',
    'inputQualitySentenceAdded',
    'inputQualityUsedAnyway',
    'acceptedWeakInputCount',
    'sharpenedInputCount',
    'perspectiveShiftShown',
    'perspectiveShiftChanged',
    'perspectiveShiftUsed',
    'perspectiveShiftShownFromPatterns',
    'perspectiveShiftUsedFromPatterns',
    'kinderAngleShown',
    'kinderAngleUsed',
    'kinderAngleChanged',
    'kinderAngleShownFromPatterns',
    'kinderAngleUsedFromPatterns',
    'quickHelpOpened',
    'quickHelpIntentSelected',
    'quickHelpPrimaryActionTapped',
    'quickHelpCheckUsed',
    'keyMomentCreated',
    'keyMomentOpened',
    'keyMomentSearchUsed',
    'keyMomentUseCheckTapped',
    'askArchiveOpened',
    'askArchiveSearchUsed',
    'askArchiveSuggestedChipTapped',
    'askArchiveResultOpened',
    'askArchiveUseCheckTapped',
    'archiveCleanViewShown',
    'archiveCleanSectionTapped',
    'patternProfileShown',
    'patternProfileOpened',
    'patternProfileUseCheckTapped',
    'patternProfileFindMomentsTapped',
    'patternProfileOpenTimelineTapped',
    'patternMapShown',
    'patternMapOpened',
    'patternMapUseCheckTapped',
    'archiveFeedbackShown',
    'archiveFeedbackSelected',
    'archiveFeedbackUseful',
    'archiveFeedbackTooGeneric',
    'archiveFeedbackNotMe',
    'archiveFeedbackAlreadyKnew',
    'archiveFeedbackMoreSpecific',
    'archiveCompressionShown',
    'archiveCompressionOpened',
    'archiveCompressionKept',
    'archiveCompressionSplit',
    'archiveCompressionHidden',
    'memoryQualityShown',
    'memoryQualityTapped',
    'paywallShown',
    'paywallTriggerShown',
    'annualPlanShown',
    'monthlyPlanShown',
    'annualPlanSelected',
    'monthlyPlanSelected',
    'paywallContinueTapped',
    'paywallDismissed',
    'restoreTapped',
    'archiveRangeReviewShown',
    'archiveRangeReviewOpened',
    'archiveRangeReviewUseCheckTapped',
    'archiveRangeReviewPresetChanged',
    'retentionStateShown',
    'retentionDueShown',
    'retentionCheckSetShown',
    'retentionLoopClosedShown',
    'retentionPrimaryCtaTapped',
    'retentionSecondaryCtaTapped',
    'retentionNextCheckReady',
    'retentionMissedCheck',
    'reminderScheduledFromRetention',
    'compellingCheckShown',
    'compellingCheckSelected',
    'compellingCheckMostSpecificSelected',
    'compellingCheckAccepted',
    'realReminderPermissionRequested',
    'realReminderPermissionGranted',
    'realReminderPermissionDenied',
    'realReminderScheduled',
    'realReminderCancelled',
    'realReminderUnavailable',
    'realReminderTapped',
    'currentObjectiveShown',
    'currentObjectivePrimaryTapped',
    'currentObjectiveSecondaryTapped',
    'proValuePreviewShown',
    'proValuePreviewUnlockTapped',
    'proValuePreviewDismissed',
    'objectiveWidgetRefreshAttempted',
    'objectiveWidgetRefreshSucceeded',
    'objectiveWidgetRefreshFailed',
    'objectiveWidgetCleared',
    'archiveMemorySummaryShown',
    'archiveMemoryOpenPatternMapTapped',
    'archiveMemoryFindMomentsTapped',
    'archiveMemoryUseCheckTapped',
    'archiveTimelineShown',
    'archiveTimelineOpened',
    'archiveTimelineUseCheckTapped',
    'archiveMemoryDemoShown',
    'archiveMemoryDemoCtaTapped',
    'archiveMemoryPreviewShown',
    'archiveMemoryPreviewCtaTapped',
    'positioningComprehensionAsked',
    'positioningComprehensionAnswered',
    'positioningUnderstoodArchiveMemory',
    'positioningJournal',
    'positioningChat',
    'positioningNotSure',
    'activationFirstRecordCardShown',
    'activationFirstRecordCtaTapped',
    'activationStarterPromptSelected',
    'activationFirstSaveCompleted',
    'activationTomorrowCheckShown',
    'activationTomorrowCheckUsed',
    'activationTomorrowCheckSharpened',
    'activationTomorrowCheckIgnored',
    'activationUsefulTakeawayShown',
    'activationMakeUsefulTapped',
    'activationMakeUsefulReasonSelected',
    'activationResultRatedUseful',
    'activationResultRatedSortOf',
    'activationResultRatedNotUseful',
    'activationNextCheckShown',
    'activationNextCheckUsed',
    'activationNextCheckChanged',
    'activationRoutineAnchorOffered',
    'activationRoutineAnchorSet',
  ];

  ActivationEventCounts incrementField(String field) {
    switch (field) {
      case 'firstReflectionSaved':
        return copyWith(firstReflectionSaved: firstReflectionSaved + 1);
      case 'firstPatternShown':
        return copyWith(firstPatternShown: firstPatternShown + 1);
      case 'firstPatternAccepted':
        return copyWith(firstPatternAccepted: firstPatternAccepted + 1);
      case 'firstPatternCorrected':
        return copyWith(firstPatternCorrected: firstPatternCorrected + 1);
      case 'watchForPromptShown':
        return copyWith(watchForPromptShown: watchForPromptShown + 1);
      case 'watchForPromptAccepted':
        return copyWith(watchForPromptAccepted: watchForPromptAccepted + 1);
      case 'returnCaptureQuickAnswerSelected':
        return copyWith(
          returnCaptureQuickAnswerSelected:
              returnCaptureQuickAnswerSelected + 1,
        );
      case 'returnedNextDay':
        return copyWith(returnedNextDay: returnedNextDay + 1);
      case 'secondReflectionSaved':
        return copyWith(secondReflectionSaved: secondReflectionSaved + 1);
      case 'comparisonViewed':
        return copyWith(comparisonViewed: comparisonViewed + 1);
      case 'usefulnessYes':
        return copyWith(usefulnessYes: usefulnessYes + 1);
      case 'usefulnessSortOf':
        return copyWith(usefulnessSortOf: usefulnessSortOf + 1);
      case 'usefulnessNotReally':
        return copyWith(usefulnessNotReally: usefulnessNotReally + 1);
      case 'thirdReflectionSaved':
        return copyWith(thirdReflectionSaved: thirdReflectionSaved + 1);
      case 'trialAppOpened':
        return copyWith(trialAppOpened: trialAppOpened + 1);
      case 'trialRecordCtaTapped':
        return copyWith(trialRecordCtaTapped: trialRecordCtaTapped + 1);
      case 'trialMicPermissionRequested':
        return copyWith(
          trialMicPermissionRequested: trialMicPermissionRequested + 1,
        );
      case 'trialMicPermissionDenied':
        return copyWith(trialMicPermissionDenied: trialMicPermissionDenied + 1);
      case 'trialRecordingStarted':
        return copyWith(trialRecordingStarted: trialRecordingStarted + 1);
      case 'trialRecordingCancelled':
        return copyWith(trialRecordingCancelled: trialRecordingCancelled + 1);
      case 'trialSaveStarted':
        return copyWith(trialSaveStarted: trialSaveStarted + 1);
      case 'trialSaveCompleted':
        return copyWith(trialSaveCompleted: trialSaveCompleted + 1);
      case 'trialClosedBeforeWatchForAccepted':
        return copyWith(
          trialClosedBeforeWatchForAccepted:
              trialClosedBeforeWatchForAccepted + 1,
        );
      case 'trialExportCopied':
        return copyWith(trialExportCopied: trialExportCopied + 1);
      case 'tomorrowCheckInCreated':
        return copyWith(tomorrowCheckInCreated: tomorrowCheckInCreated + 1);
      case 'tomorrowCheckInDueShown':
        return copyWith(tomorrowCheckInDueShown: tomorrowCheckInDueShown + 1);
      case 'tomorrowCheckInOptionSelected':
        return copyWith(
          tomorrowCheckInOptionSelected: tomorrowCheckInOptionSelected + 1,
        );
      case 'tomorrowCheckInRecordingStarted':
        return copyWith(
          tomorrowCheckInRecordingStarted: tomorrowCheckInRecordingStarted + 1,
        );
      case 'tomorrowCheckInCompleted':
        return copyWith(tomorrowCheckInCompleted: tomorrowCheckInCompleted + 1);
      case 'tomorrowCheckInMissed':
        return copyWith(tomorrowCheckInMissed: tomorrowCheckInMissed + 1);
      case 'checkInClarityCardShown':
        return copyWith(checkInClarityCardShown: checkInClarityCardShown + 1);
      case 'checkInExamplesOpened':
        return copyWith(checkInExamplesOpened: checkInExamplesOpened + 1);
      case 'checkInMomentRecorded':
        return copyWith(checkInMomentRecorded: checkInMomentRecorded + 1);
      case 'tomorrowQuestionVariantShown':
        return copyWith(
          tomorrowQuestionVariantShown: tomorrowQuestionVariantShown + 1,
        );
      case 'tomorrowQuestionVariantSelected':
        return copyWith(
          tomorrowQuestionVariantSelected: tomorrowQuestionVariantSelected + 1,
        );
      case 'reminderScheduled':
        return copyWith(reminderScheduled: reminderScheduled + 1);
      case 'reminderTapped':
        return copyWith(reminderTapped: reminderTapped + 1);
      case 'reminderNotAvailable':
        return copyWith(reminderNotAvailable: reminderNotAvailable + 1);
      case 'guidedCheckInShown':
        return copyWith(guidedCheckInShown: guidedCheckInShown + 1);
      case 'guidedCheckInStepCompleted':
        return copyWith(
          guidedCheckInStepCompleted: guidedCheckInStepCompleted + 1,
        );
      case 'sharperQuestionShown':
        return copyWith(sharperQuestionShown: sharperQuestionShown + 1);
      case 'sharperQuestionAccepted':
        return copyWith(sharperQuestionAccepted: sharperQuestionAccepted + 1);
      case 'betterResultShown':
        return copyWith(betterResultShown: betterResultShown + 1);
      case 'betterFirstRecordPromptShown':
        return copyWith(
          betterFirstRecordPromptShown: betterFirstRecordPromptShown + 1,
        );
      case 'betterFirstRecordPromptTapped':
        return copyWith(
          betterFirstRecordPromptTapped: betterFirstRecordPromptTapped + 1,
        );
      case 'sharperQuestionElevatedShown':
        return copyWith(
          sharperQuestionElevatedShown: sharperQuestionElevatedShown + 1,
        );
      case 'sharperQuestionAggressiveShown':
        return copyWith(
          sharperQuestionAggressiveShown: sharperQuestionAggressiveShown + 1,
        );
      case 'sharperQuestionAggressiveAccepted':
        return copyWith(
          sharperQuestionAggressiveAccepted:
              sharperQuestionAggressiveAccepted + 1,
        );
      case 'betterResultElevatedShown':
        return copyWith(
          betterResultElevatedShown: betterResultElevatedShown + 1,
        );
      case 'betterResultAggressiveShown':
        return copyWith(
          betterResultAggressiveShown: betterResultAggressiveShown + 1,
        );
      case 'checkInGoDeeperShown':
        return copyWith(checkInGoDeeperShown: checkInGoDeeperShown + 1);
      case 'checkInGoDeeperTapped':
        return copyWith(checkInGoDeeperTapped: checkInGoDeeperTapped + 1);
      case 'reminderPermissionRequested':
        return copyWith(
          reminderPermissionRequested: reminderPermissionRequested + 1,
        );
      case 'reminderPermissionGranted':
        return copyWith(
          reminderPermissionGranted: reminderPermissionGranted + 1,
        );
      case 'reminderPermissionDenied':
        return copyWith(reminderPermissionDenied: reminderPermissionDenied + 1);
      case 'reminderCancelled':
        return copyWith(reminderCancelled: reminderCancelled + 1);
      case 'patternMemoryCreated':
        return copyWith(patternMemoryCreated: patternMemoryCreated + 1);
      case 'patternMemoryUpdated':
        return copyWith(patternMemoryUpdated: patternMemoryUpdated + 1);
      case 'patternMemoryNextQuestionUsed':
        return copyWith(
          patternMemoryNextQuestionUsed: patternMemoryNextQuestionUsed + 1,
        );
      case 'patternProgressMomentCreated':
        return copyWith(
          patternProgressMomentCreated: patternProgressMomentCreated + 1,
        );
      case 'patternProgressCardShown':
        return copyWith(patternProgressCardShown: patternProgressCardShown + 1);
      case 'patternProgressNextQuestionUsed':
        return copyWith(
          patternProgressNextQuestionUsed: patternProgressNextQuestionUsed + 1,
        );
      case 'patternNextActionCreated':
        return copyWith(patternNextActionCreated: patternNextActionCreated + 1);
      case 'patternNextActionShown':
        return copyWith(patternNextActionShown: patternNextActionShown + 1);
      case 'patternNextActionUsed':
        return copyWith(patternNextActionUsed: patternNextActionUsed + 1);
      case 'habitProofCreated':
        return copyWith(habitProofCreated: habitProofCreated + 1);
      case 'habitProofShown':
        return copyWith(habitProofShown: habitProofShown + 1);
      case 'habitProofCtaTapped':
        return copyWith(habitProofCtaTapped: habitProofCtaTapped + 1);
      case 'weeklyPatternRecapCreated':
        return copyWith(
          weeklyPatternRecapCreated: weeklyPatternRecapCreated + 1,
        );
      case 'weeklyPatternRecapShown':
        return copyWith(weeklyPatternRecapShown: weeklyPatternRecapShown + 1);
      case 'weeklyPatternRecapCtaTapped':
        return copyWith(
          weeklyPatternRecapCtaTapped: weeklyPatternRecapCtaTapped + 1,
        );
      case 'patternShareCardShown':
        return copyWith(patternShareCardShown: patternShareCardShown + 1);
      case 'patternShareCopied':
        return copyWith(patternShareCopied: patternShareCopied + 1);
      case 'patternShareOpened':
        return copyWith(patternShareOpened: patternShareOpened + 1);
      case 'patternShareFailed':
        return copyWith(patternShareFailed: patternShareFailed + 1);
      case 'firstLoopRecordOpened':
        return copyWith(firstLoopRecordOpened: firstLoopRecordOpened + 1);
      case 'firstLoopRecordingStarted':
        return copyWith(
          firstLoopRecordingStarted: firstLoopRecordingStarted + 1,
        );
      case 'firstLoopMomentSaved':
        return copyWith(firstLoopMomentSaved: firstLoopMomentSaved + 1);
      case 'firstLoopPatternShown':
        return copyWith(firstLoopPatternShown: firstLoopPatternShown + 1);
      case 'firstLoopTomorrowCheckChosen':
        return copyWith(
          firstLoopTomorrowCheckChosen: firstLoopTomorrowCheckChosen + 1,
        );
      case 'firstLoopReady':
        return copyWith(firstLoopReady: firstLoopReady + 1);
      case 'returnDayDueShown':
        return copyWith(returnDayDueShown: returnDayDueShown + 1);
      case 'returnDayAnswerSelected':
        return copyWith(returnDayAnswerSelected: returnDayAnswerSelected + 1);
      case 'returnDayRecordingStarted':
        return copyWith(
          returnDayRecordingStarted: returnDayRecordingStarted + 1,
        );
      case 'returnDayMomentSaved':
        return copyWith(returnDayMomentSaved: returnDayMomentSaved + 1);
      case 'returnDayLoopClosed':
        return copyWith(returnDayLoopClosed: returnDayLoopClosed + 1);
      case 'returnDayAbandonedAfterAnswer':
        return copyWith(
          returnDayAbandonedAfterAnswer: returnDayAbandonedAfterAnswer + 1,
        );
      case 'resultNextCheckShown':
        return copyWith(resultNextCheckShown: resultNextCheckShown + 1);
      case 'resultNextCheckUsed':
        return copyWith(resultNextCheckUsed: resultNextCheckUsed + 1);
      case 'resultNextCheckChanged':
        return copyWith(resultNextCheckChanged: resultNextCheckChanged + 1);
      case 'resultNextCheckUsedFromPatterns':
        return copyWith(
          resultNextCheckUsedFromPatterns: resultNextCheckUsedFromPatterns + 1,
        );
      case 'usefulResultTakeawayShown':
        return copyWith(
          usefulResultTakeawayShown: usefulResultTakeawayShown + 1,
        );
      case 'makeResultMoreUsefulTapped':
        return copyWith(
          makeResultMoreUsefulTapped: makeResultMoreUsefulTapped + 1,
        );
      case 'makeResultMoreUsefulReasonSelected':
        return copyWith(
          makeResultMoreUsefulReasonSelected:
              makeResultMoreUsefulReasonSelected + 1,
        );
      case 'usefulResultNextCheckUsed':
        return copyWith(
          usefulResultNextCheckUsed: usefulResultNextCheckUsed + 1,
        );
      case 'inputQualityCoachShown':
        return copyWith(inputQualityCoachShown: inputQualityCoachShown + 1);
      case 'inputQualitySentenceAdded':
        return copyWith(
          inputQualitySentenceAdded: inputQualitySentenceAdded + 1,
        );
      case 'inputQualityUsedAnyway':
        return copyWith(inputQualityUsedAnyway: inputQualityUsedAnyway + 1);
      case 'acceptedWeakInputCount':
        return copyWith(acceptedWeakInputCount: acceptedWeakInputCount + 1);
      case 'sharpenedInputCount':
        return copyWith(sharpenedInputCount: sharpenedInputCount + 1);
      case 'perspectiveShiftShown':
        return copyWith(perspectiveShiftShown: perspectiveShiftShown + 1);
      case 'perspectiveShiftChanged':
        return copyWith(perspectiveShiftChanged: perspectiveShiftChanged + 1);
      case 'perspectiveShiftUsed':
        return copyWith(perspectiveShiftUsed: perspectiveShiftUsed + 1);
      case 'perspectiveShiftShownFromPatterns':
        return copyWith(
          perspectiveShiftShownFromPatterns:
              perspectiveShiftShownFromPatterns + 1,
        );
      case 'perspectiveShiftUsedFromPatterns':
        return copyWith(
          perspectiveShiftUsedFromPatterns:
              perspectiveShiftUsedFromPatterns + 1,
        );
      case 'kinderAngleShown':
        return copyWith(kinderAngleShown: kinderAngleShown + 1);
      case 'kinderAngleUsed':
        return copyWith(kinderAngleUsed: kinderAngleUsed + 1);
      case 'kinderAngleChanged':
        return copyWith(kinderAngleChanged: kinderAngleChanged + 1);
      case 'kinderAngleShownFromPatterns':
        return copyWith(
          kinderAngleShownFromPatterns: kinderAngleShownFromPatterns + 1,
        );
      case 'kinderAngleUsedFromPatterns':
        return copyWith(
          kinderAngleUsedFromPatterns: kinderAngleUsedFromPatterns + 1,
        );
      case 'quickHelpOpened':
        return copyWith(quickHelpOpened: quickHelpOpened + 1);
      case 'quickHelpIntentSelected':
        return copyWith(quickHelpIntentSelected: quickHelpIntentSelected + 1);
      case 'quickHelpPrimaryActionTapped':
        return copyWith(
          quickHelpPrimaryActionTapped: quickHelpPrimaryActionTapped + 1,
        );
      case 'quickHelpCheckUsed':
        return copyWith(quickHelpCheckUsed: quickHelpCheckUsed + 1);
      case 'keyMomentCreated':
        return copyWith(keyMomentCreated: keyMomentCreated + 1);
      case 'keyMomentOpened':
        return copyWith(keyMomentOpened: keyMomentOpened + 1);
      case 'keyMomentSearchUsed':
        return copyWith(keyMomentSearchUsed: keyMomentSearchUsed + 1);
      case 'keyMomentUseCheckTapped':
        return copyWith(keyMomentUseCheckTapped: keyMomentUseCheckTapped + 1);
      case 'askArchiveOpened':
        return copyWith(askArchiveOpened: askArchiveOpened + 1);
      case 'askArchiveSearchUsed':
        return copyWith(askArchiveSearchUsed: askArchiveSearchUsed + 1);
      case 'askArchiveSuggestedChipTapped':
        return copyWith(
          askArchiveSuggestedChipTapped: askArchiveSuggestedChipTapped + 1,
        );
      case 'askArchiveResultOpened':
        return copyWith(askArchiveResultOpened: askArchiveResultOpened + 1);
      case 'askArchiveUseCheckTapped':
        return copyWith(askArchiveUseCheckTapped: askArchiveUseCheckTapped + 1);
      case 'archiveCleanViewShown':
        return copyWith(archiveCleanViewShown: archiveCleanViewShown + 1);
      case 'archiveCleanSectionTapped':
        return copyWith(
          archiveCleanSectionTapped: archiveCleanSectionTapped + 1,
        );
      case 'patternProfileShown':
        return copyWith(patternProfileShown: patternProfileShown + 1);
      case 'patternProfileOpened':
        return copyWith(patternProfileOpened: patternProfileOpened + 1);
      case 'patternProfileUseCheckTapped':
        return copyWith(
          patternProfileUseCheckTapped: patternProfileUseCheckTapped + 1,
        );
      case 'patternProfileFindMomentsTapped':
        return copyWith(
          patternProfileFindMomentsTapped: patternProfileFindMomentsTapped + 1,
        );
      case 'patternProfileOpenTimelineTapped':
        return copyWith(
          patternProfileOpenTimelineTapped:
              patternProfileOpenTimelineTapped + 1,
        );
      case 'patternMapShown':
        return copyWith(patternMapShown: patternMapShown + 1);
      case 'patternMapOpened':
        return copyWith(patternMapOpened: patternMapOpened + 1);
      case 'patternMapUseCheckTapped':
        return copyWith(patternMapUseCheckTapped: patternMapUseCheckTapped + 1);
      case 'archiveFeedbackShown':
        return copyWith(archiveFeedbackShown: archiveFeedbackShown + 1);
      case 'archiveFeedbackSelected':
        return copyWith(archiveFeedbackSelected: archiveFeedbackSelected + 1);
      case 'archiveFeedbackUseful':
        return copyWith(archiveFeedbackUseful: archiveFeedbackUseful + 1);
      case 'archiveFeedbackTooGeneric':
        return copyWith(
          archiveFeedbackTooGeneric: archiveFeedbackTooGeneric + 1,
        );
      case 'archiveFeedbackNotMe':
        return copyWith(archiveFeedbackNotMe: archiveFeedbackNotMe + 1);
      case 'archiveFeedbackAlreadyKnew':
        return copyWith(
          archiveFeedbackAlreadyKnew: archiveFeedbackAlreadyKnew + 1,
        );
      case 'archiveFeedbackMoreSpecific':
        return copyWith(
          archiveFeedbackMoreSpecific: archiveFeedbackMoreSpecific + 1,
        );
      case 'archiveCompressionShown':
        return copyWith(archiveCompressionShown: archiveCompressionShown + 1);
      case 'archiveCompressionOpened':
        return copyWith(archiveCompressionOpened: archiveCompressionOpened + 1);
      case 'archiveCompressionKept':
        return copyWith(archiveCompressionKept: archiveCompressionKept + 1);
      case 'archiveCompressionSplit':
        return copyWith(archiveCompressionSplit: archiveCompressionSplit + 1);
      case 'archiveCompressionHidden':
        return copyWith(archiveCompressionHidden: archiveCompressionHidden + 1);
      case 'memoryQualityShown':
        return copyWith(memoryQualityShown: memoryQualityShown + 1);
      case 'memoryQualityTapped':
        return copyWith(memoryQualityTapped: memoryQualityTapped + 1);
      case 'paywallShown':
        return copyWith(paywallShown: paywallShown + 1);
      case 'paywallTriggerShown':
        return copyWith(paywallTriggerShown: paywallTriggerShown + 1);
      case 'annualPlanShown':
        return copyWith(annualPlanShown: annualPlanShown + 1);
      case 'monthlyPlanShown':
        return copyWith(monthlyPlanShown: monthlyPlanShown + 1);
      case 'annualPlanSelected':
        return copyWith(annualPlanSelected: annualPlanSelected + 1);
      case 'monthlyPlanSelected':
        return copyWith(monthlyPlanSelected: monthlyPlanSelected + 1);
      case 'paywallContinueTapped':
        return copyWith(paywallContinueTapped: paywallContinueTapped + 1);
      case 'paywallDismissed':
        return copyWith(paywallDismissed: paywallDismissed + 1);
      case 'restoreTapped':
        return copyWith(restoreTapped: restoreTapped + 1);
      case 'archiveRangeReviewShown':
        return copyWith(archiveRangeReviewShown: archiveRangeReviewShown + 1);
      case 'archiveRangeReviewOpened':
        return copyWith(archiveRangeReviewOpened: archiveRangeReviewOpened + 1);
      case 'archiveRangeReviewUseCheckTapped':
        return copyWith(
          archiveRangeReviewUseCheckTapped:
              archiveRangeReviewUseCheckTapped + 1,
        );
      case 'archiveRangeReviewPresetChanged':
        return copyWith(
          archiveRangeReviewPresetChanged: archiveRangeReviewPresetChanged + 1,
        );
      case 'retentionStateShown':
        return copyWith(retentionStateShown: retentionStateShown + 1);
      case 'retentionDueShown':
        return copyWith(retentionDueShown: retentionDueShown + 1);
      case 'retentionCheckSetShown':
        return copyWith(retentionCheckSetShown: retentionCheckSetShown + 1);
      case 'retentionLoopClosedShown':
        return copyWith(retentionLoopClosedShown: retentionLoopClosedShown + 1);
      case 'retentionPrimaryCtaTapped':
        return copyWith(
          retentionPrimaryCtaTapped: retentionPrimaryCtaTapped + 1,
        );
      case 'retentionSecondaryCtaTapped':
        return copyWith(
          retentionSecondaryCtaTapped: retentionSecondaryCtaTapped + 1,
        );
      case 'retentionNextCheckReady':
        return copyWith(retentionNextCheckReady: retentionNextCheckReady + 1);
      case 'retentionMissedCheck':
        return copyWith(retentionMissedCheck: retentionMissedCheck + 1);
      case 'reminderScheduledFromRetention':
        return copyWith(
          reminderScheduledFromRetention: reminderScheduledFromRetention + 1,
        );
      case 'compellingCheckShown':
        return copyWith(compellingCheckShown: compellingCheckShown + 1);
      case 'compellingCheckSelected':
        return copyWith(compellingCheckSelected: compellingCheckSelected + 1);
      case 'compellingCheckMostSpecificSelected':
        return copyWith(
          compellingCheckMostSpecificSelected:
              compellingCheckMostSpecificSelected + 1,
        );
      case 'compellingCheckAccepted':
        return copyWith(compellingCheckAccepted: compellingCheckAccepted + 1);
      case 'realReminderPermissionRequested':
        return copyWith(
          realReminderPermissionRequested: realReminderPermissionRequested + 1,
        );
      case 'realReminderPermissionGranted':
        return copyWith(
          realReminderPermissionGranted: realReminderPermissionGranted + 1,
        );
      case 'realReminderPermissionDenied':
        return copyWith(
          realReminderPermissionDenied: realReminderPermissionDenied + 1,
        );
      case 'realReminderScheduled':
        return copyWith(realReminderScheduled: realReminderScheduled + 1);
      case 'realReminderCancelled':
        return copyWith(realReminderCancelled: realReminderCancelled + 1);
      case 'realReminderUnavailable':
        return copyWith(realReminderUnavailable: realReminderUnavailable + 1);
      case 'realReminderTapped':
        return copyWith(realReminderTapped: realReminderTapped + 1);
      case 'currentObjectiveShown':
        return copyWith(currentObjectiveShown: currentObjectiveShown + 1);
      case 'currentObjectivePrimaryTapped':
        return copyWith(
          currentObjectivePrimaryTapped: currentObjectivePrimaryTapped + 1,
        );
      case 'currentObjectiveSecondaryTapped':
        return copyWith(
          currentObjectiveSecondaryTapped: currentObjectiveSecondaryTapped + 1,
        );
      case 'proValuePreviewShown':
        return copyWith(proValuePreviewShown: proValuePreviewShown + 1);
      case 'proValuePreviewUnlockTapped':
        return copyWith(
          proValuePreviewUnlockTapped: proValuePreviewUnlockTapped + 1,
        );
      case 'proValuePreviewDismissed':
        return copyWith(proValuePreviewDismissed: proValuePreviewDismissed + 1);
      case 'objectiveWidgetRefreshAttempted':
        return copyWith(
          objectiveWidgetRefreshAttempted: objectiveWidgetRefreshAttempted + 1,
        );
      case 'objectiveWidgetRefreshSucceeded':
        return copyWith(
          objectiveWidgetRefreshSucceeded: objectiveWidgetRefreshSucceeded + 1,
        );
      case 'objectiveWidgetRefreshFailed':
        return copyWith(
          objectiveWidgetRefreshFailed: objectiveWidgetRefreshFailed + 1,
        );
      case 'objectiveWidgetCleared':
        return copyWith(objectiveWidgetCleared: objectiveWidgetCleared + 1);
      case 'archiveMemorySummaryShown':
        return copyWith(
          archiveMemorySummaryShown: archiveMemorySummaryShown + 1,
        );
      case 'archiveMemoryOpenPatternMapTapped':
        return copyWith(
          archiveMemoryOpenPatternMapTapped:
              archiveMemoryOpenPatternMapTapped + 1,
        );
      case 'archiveMemoryFindMomentsTapped':
        return copyWith(
          archiveMemoryFindMomentsTapped: archiveMemoryFindMomentsTapped + 1,
        );
      case 'archiveMemoryUseCheckTapped':
        return copyWith(
          archiveMemoryUseCheckTapped: archiveMemoryUseCheckTapped + 1,
        );
      case 'archiveTimelineShown':
        return copyWith(archiveTimelineShown: archiveTimelineShown + 1);
      case 'archiveTimelineOpened':
        return copyWith(archiveTimelineOpened: archiveTimelineOpened + 1);
      case 'archiveTimelineUseCheckTapped':
        return copyWith(
          archiveTimelineUseCheckTapped: archiveTimelineUseCheckTapped + 1,
        );
      case 'archiveMemoryDemoShown':
        return copyWith(archiveMemoryDemoShown: archiveMemoryDemoShown + 1);
      case 'archiveMemoryDemoCtaTapped':
        return copyWith(
          archiveMemoryDemoCtaTapped: archiveMemoryDemoCtaTapped + 1,
        );
      case 'archiveMemoryPreviewShown':
        return copyWith(
          archiveMemoryPreviewShown: archiveMemoryPreviewShown + 1,
        );
      case 'archiveMemoryPreviewCtaTapped':
        return copyWith(
          archiveMemoryPreviewCtaTapped: archiveMemoryPreviewCtaTapped + 1,
        );
      case 'positioningComprehensionAsked':
        return copyWith(
          positioningComprehensionAsked: positioningComprehensionAsked + 1,
        );
      case 'positioningComprehensionAnswered':
        return copyWith(
          positioningComprehensionAnswered:
              positioningComprehensionAnswered + 1,
        );
      case 'positioningUnderstoodArchiveMemory':
        return copyWith(
          positioningUnderstoodArchiveMemory:
              positioningUnderstoodArchiveMemory + 1,
        );
      case 'positioningJournal':
        return copyWith(positioningJournal: positioningJournal + 1);
      case 'positioningChat':
        return copyWith(positioningChat: positioningChat + 1);
      case 'positioningNotSure':
        return copyWith(positioningNotSure: positioningNotSure + 1);
      case 'activationFirstRecordCardShown':
        return copyWith(
          activationFirstRecordCardShown: activationFirstRecordCardShown + 1,
        );
      case 'activationFirstRecordCtaTapped':
        return copyWith(
          activationFirstRecordCtaTapped: activationFirstRecordCtaTapped + 1,
        );
      case 'activationStarterPromptSelected':
        return copyWith(
          activationStarterPromptSelected: activationStarterPromptSelected + 1,
        );
      case 'activationFirstSaveCompleted':
        return copyWith(
          activationFirstSaveCompleted: activationFirstSaveCompleted + 1,
        );
      case 'activationTomorrowCheckShown':
        return copyWith(
          activationTomorrowCheckShown: activationTomorrowCheckShown + 1,
        );
      case 'activationTomorrowCheckUsed':
        return copyWith(
          activationTomorrowCheckUsed: activationTomorrowCheckUsed + 1,
        );
      case 'activationTomorrowCheckSharpened':
        return copyWith(
          activationTomorrowCheckSharpened:
              activationTomorrowCheckSharpened + 1,
        );
      case 'activationTomorrowCheckIgnored':
        return copyWith(
          activationTomorrowCheckIgnored: activationTomorrowCheckIgnored + 1,
        );
      case 'activationUsefulTakeawayShown':
        return copyWith(
          activationUsefulTakeawayShown: activationUsefulTakeawayShown + 1,
        );
      case 'activationMakeUsefulTapped':
        return copyWith(
          activationMakeUsefulTapped: activationMakeUsefulTapped + 1,
        );
      case 'activationMakeUsefulReasonSelected':
        return copyWith(
          activationMakeUsefulReasonSelected:
              activationMakeUsefulReasonSelected + 1,
        );
      case 'activationResultRatedUseful':
        return copyWith(
          activationResultRatedUseful: activationResultRatedUseful + 1,
        );
      case 'activationResultRatedSortOf':
        return copyWith(
          activationResultRatedSortOf: activationResultRatedSortOf + 1,
        );
      case 'activationResultRatedNotUseful':
        return copyWith(
          activationResultRatedNotUseful: activationResultRatedNotUseful + 1,
        );
      case 'activationNextCheckShown':
        return copyWith(activationNextCheckShown: activationNextCheckShown + 1);
      case 'activationNextCheckUsed':
        return copyWith(activationNextCheckUsed: activationNextCheckUsed + 1);
      case 'activationNextCheckChanged':
        return copyWith(
          activationNextCheckChanged: activationNextCheckChanged + 1,
        );
      case 'activationRoutineAnchorOffered':
        return copyWith(
          activationRoutineAnchorOffered: activationRoutineAnchorOffered + 1,
        );
      case 'activationRoutineAnchorSet':
        return copyWith(
          activationRoutineAnchorSet: activationRoutineAnchorSet + 1,
        );
      default:
        return this;
    }
  }

  ActivationEventCounts copyWith({
    String? participantId,
    bool clearParticipantId = false,
    int? firstReflectionSaved,
    int? firstPatternShown,
    int? firstPatternAccepted,
    int? firstPatternCorrected,
    int? watchForPromptShown,
    int? watchForPromptAccepted,
    int? returnCaptureQuickAnswerSelected,
    int? returnedNextDay,
    int? secondReflectionSaved,
    int? comparisonViewed,
    int? usefulnessYes,
    int? usefulnessSortOf,
    int? usefulnessNotReally,
    int? thirdReflectionSaved,
    int? trialAppOpened,
    int? trialRecordCtaTapped,
    int? trialMicPermissionRequested,
    int? trialMicPermissionDenied,
    int? trialRecordingStarted,
    int? trialRecordingCancelled,
    int? trialSaveStarted,
    int? trialSaveCompleted,
    int? trialClosedBeforeWatchForAccepted,
    int? trialExportCopied,
    int? tomorrowCheckInCreated,
    int? tomorrowCheckInDueShown,
    int? tomorrowCheckInOptionSelected,
    int? tomorrowCheckInRecordingStarted,
    int? tomorrowCheckInCompleted,
    int? tomorrowCheckInMissed,
    int? checkInClarityCardShown,
    int? checkInExamplesOpened,
    int? checkInMomentRecorded,
    int? tomorrowQuestionVariantShown,
    int? tomorrowQuestionVariantSelected,
    int? reminderScheduled,
    int? reminderTapped,
    int? reminderNotAvailable,
    int? guidedCheckInShown,
    int? guidedCheckInStepCompleted,
    int? sharperQuestionShown,
    int? sharperQuestionAccepted,
    int? betterResultShown,
    int? betterFirstRecordPromptShown,
    int? betterFirstRecordPromptTapped,
    int? sharperQuestionElevatedShown,
    int? sharperQuestionAggressiveShown,
    int? sharperQuestionAggressiveAccepted,
    int? betterResultElevatedShown,
    int? betterResultAggressiveShown,
    int? checkInGoDeeperShown,
    int? checkInGoDeeperTapped,
    int? reminderPermissionRequested,
    int? reminderPermissionGranted,
    int? reminderPermissionDenied,
    int? reminderCancelled,
    int? patternMemoryCreated,
    int? patternMemoryUpdated,
    int? patternMemoryNextQuestionUsed,
    int? patternProgressMomentCreated,
    int? patternProgressCardShown,
    int? patternProgressNextQuestionUsed,
    int? patternNextActionCreated,
    int? patternNextActionShown,
    int? patternNextActionUsed,
    int? habitProofCreated,
    int? habitProofShown,
    int? habitProofCtaTapped,
    int? weeklyPatternRecapCreated,
    int? weeklyPatternRecapShown,
    int? weeklyPatternRecapCtaTapped,
    int? patternShareCardShown,
    int? patternShareCopied,
    int? patternShareOpened,
    int? patternShareFailed,
    int? firstLoopRecordOpened,
    int? firstLoopRecordingStarted,
    int? firstLoopMomentSaved,
    int? firstLoopPatternShown,
    int? firstLoopTomorrowCheckChosen,
    int? firstLoopReady,
    int? returnDayDueShown,
    int? returnDayAnswerSelected,
    int? returnDayRecordingStarted,
    int? returnDayMomentSaved,
    int? returnDayLoopClosed,
    int? returnDayAbandonedAfterAnswer,
    int? resultNextCheckShown,
    int? resultNextCheckUsed,
    int? resultNextCheckChanged,
    int? resultNextCheckUsedFromPatterns,
    int? usefulResultTakeawayShown,
    int? makeResultMoreUsefulTapped,
    int? makeResultMoreUsefulReasonSelected,
    int? usefulResultNextCheckUsed,
    int? inputQualityCoachShown,
    int? inputQualitySentenceAdded,
    int? inputQualityUsedAnyway,
    int? acceptedWeakInputCount,
    int? sharpenedInputCount,
    int? perspectiveShiftShown,
    int? perspectiveShiftChanged,
    int? perspectiveShiftUsed,
    int? perspectiveShiftShownFromPatterns,
    int? perspectiveShiftUsedFromPatterns,
    int? kinderAngleShown,
    int? kinderAngleUsed,
    int? kinderAngleChanged,
    int? kinderAngleShownFromPatterns,
    int? kinderAngleUsedFromPatterns,
    int? quickHelpOpened,
    int? quickHelpIntentSelected,
    int? quickHelpPrimaryActionTapped,
    int? quickHelpCheckUsed,
    int? keyMomentCreated,
    int? keyMomentOpened,
    int? keyMomentSearchUsed,
    int? keyMomentUseCheckTapped,
    int? askArchiveOpened,
    int? askArchiveSearchUsed,
    int? askArchiveSuggestedChipTapped,
    int? askArchiveResultOpened,
    int? askArchiveUseCheckTapped,
    int? archiveCleanViewShown,
    int? archiveCleanSectionTapped,
    int? patternProfileShown,
    int? patternProfileOpened,
    int? patternProfileUseCheckTapped,
    int? patternProfileFindMomentsTapped,
    int? patternProfileOpenTimelineTapped,
    int? patternMapShown,
    int? patternMapOpened,
    int? patternMapUseCheckTapped,
    int? archiveFeedbackShown,
    int? archiveFeedbackSelected,
    int? archiveFeedbackUseful,
    int? archiveFeedbackTooGeneric,
    int? archiveFeedbackNotMe,
    int? archiveFeedbackAlreadyKnew,
    int? archiveFeedbackMoreSpecific,
    int? archiveCompressionShown,
    int? archiveCompressionOpened,
    int? archiveCompressionKept,
    int? archiveCompressionSplit,
    int? archiveCompressionHidden,
    int? memoryQualityShown,
    int? memoryQualityTapped,
    String? latestMemoryQualityLevel,
    bool clearLatestMemoryQualityLevel = false,
    int? paywallShown,
    int? paywallTriggerShown,
    int? annualPlanShown,
    int? monthlyPlanShown,
    int? annualPlanSelected,
    int? monthlyPlanSelected,
    int? paywallContinueTapped,
    int? paywallDismissed,
    int? restoreTapped,
    int? archiveRangeReviewShown,
    int? archiveRangeReviewOpened,
    int? archiveRangeReviewUseCheckTapped,
    int? archiveRangeReviewPresetChanged,
    int? retentionStateShown,
    int? retentionDueShown,
    int? retentionCheckSetShown,
    int? retentionLoopClosedShown,
    int? retentionPrimaryCtaTapped,
    int? retentionSecondaryCtaTapped,
    int? retentionNextCheckReady,
    int? retentionMissedCheck,
    int? reminderScheduledFromRetention,
    int? compellingCheckShown,
    int? compellingCheckSelected,
    int? compellingCheckMostSpecificSelected,
    int? compellingCheckAccepted,
    int? realReminderPermissionRequested,
    int? realReminderPermissionGranted,
    int? realReminderPermissionDenied,
    int? realReminderScheduled,
    int? realReminderCancelled,
    int? realReminderUnavailable,
    int? realReminderTapped,
    int? currentObjectiveShown,
    int? currentObjectivePrimaryTapped,
    int? currentObjectiveSecondaryTapped,
    String? latestCurrentObjectiveType,
    int? proValuePreviewShown,
    int? proValuePreviewUnlockTapped,
    int? proValuePreviewDismissed,
    String? latestProValuePreviewType,
    int? objectiveWidgetRefreshAttempted,
    int? objectiveWidgetRefreshSucceeded,
    int? objectiveWidgetRefreshFailed,
    int? objectiveWidgetCleared,
    int? archiveMemorySummaryShown,
    int? archiveMemoryOpenPatternMapTapped,
    int? archiveMemoryFindMomentsTapped,
    int? archiveMemoryUseCheckTapped,
    int? archiveTimelineShown,
    int? archiveTimelineOpened,
    int? archiveTimelineUseCheckTapped,
    int? archiveMemoryDemoShown,
    int? archiveMemoryDemoCtaTapped,
    int? archiveMemoryPreviewShown,
    int? archiveMemoryPreviewCtaTapped,
    int? positioningComprehensionAsked,
    int? positioningComprehensionAnswered,
    int? positioningUnderstoodArchiveMemory,
    int? positioningJournal,
    int? positioningChat,
    int? positioningNotSure,
    int? activationFirstRecordCardShown,
    int? activationFirstRecordCtaTapped,
    int? activationStarterPromptSelected,
    int? activationFirstSaveCompleted,
    int? activationTomorrowCheckShown,
    int? activationTomorrowCheckUsed,
    int? activationTomorrowCheckSharpened,
    int? activationTomorrowCheckIgnored,
    int? activationUsefulTakeawayShown,
    int? activationMakeUsefulTapped,
    int? activationMakeUsefulReasonSelected,
    int? activationResultRatedUseful,
    int? activationResultRatedSortOf,
    int? activationResultRatedNotUseful,
    int? activationNextCheckShown,
    int? activationNextCheckUsed,
    int? activationNextCheckChanged,
    int? activationRoutineAnchorOffered,
    int? activationRoutineAnchorSet,
  }) {
    return ActivationEventCounts(
      participantId: clearParticipantId
          ? null
          : (participantId ?? this.participantId),
      firstReflectionSaved: firstReflectionSaved ?? this.firstReflectionSaved,
      firstPatternShown: firstPatternShown ?? this.firstPatternShown,
      firstPatternAccepted: firstPatternAccepted ?? this.firstPatternAccepted,
      firstPatternCorrected:
          firstPatternCorrected ?? this.firstPatternCorrected,
      watchForPromptShown: watchForPromptShown ?? this.watchForPromptShown,
      watchForPromptAccepted:
          watchForPromptAccepted ?? this.watchForPromptAccepted,
      returnCaptureQuickAnswerSelected:
          returnCaptureQuickAnswerSelected ??
          this.returnCaptureQuickAnswerSelected,
      returnedNextDay: returnedNextDay ?? this.returnedNextDay,
      secondReflectionSaved:
          secondReflectionSaved ?? this.secondReflectionSaved,
      comparisonViewed: comparisonViewed ?? this.comparisonViewed,
      usefulnessYes: usefulnessYes ?? this.usefulnessYes,
      usefulnessSortOf: usefulnessSortOf ?? this.usefulnessSortOf,
      usefulnessNotReally: usefulnessNotReally ?? this.usefulnessNotReally,
      thirdReflectionSaved: thirdReflectionSaved ?? this.thirdReflectionSaved,
      trialAppOpened: trialAppOpened ?? this.trialAppOpened,
      trialRecordCtaTapped: trialRecordCtaTapped ?? this.trialRecordCtaTapped,
      trialMicPermissionRequested:
          trialMicPermissionRequested ?? this.trialMicPermissionRequested,
      trialMicPermissionDenied:
          trialMicPermissionDenied ?? this.trialMicPermissionDenied,
      trialRecordingStarted:
          trialRecordingStarted ?? this.trialRecordingStarted,
      trialRecordingCancelled:
          trialRecordingCancelled ?? this.trialRecordingCancelled,
      trialSaveStarted: trialSaveStarted ?? this.trialSaveStarted,
      trialSaveCompleted: trialSaveCompleted ?? this.trialSaveCompleted,
      trialClosedBeforeWatchForAccepted:
          trialClosedBeforeWatchForAccepted ??
          this.trialClosedBeforeWatchForAccepted,
      trialExportCopied: trialExportCopied ?? this.trialExportCopied,
      tomorrowCheckInCreated:
          tomorrowCheckInCreated ?? this.tomorrowCheckInCreated,
      tomorrowCheckInDueShown:
          tomorrowCheckInDueShown ?? this.tomorrowCheckInDueShown,
      tomorrowCheckInOptionSelected:
          tomorrowCheckInOptionSelected ?? this.tomorrowCheckInOptionSelected,
      tomorrowCheckInRecordingStarted:
          tomorrowCheckInRecordingStarted ??
          this.tomorrowCheckInRecordingStarted,
      tomorrowCheckInCompleted:
          tomorrowCheckInCompleted ?? this.tomorrowCheckInCompleted,
      tomorrowCheckInMissed:
          tomorrowCheckInMissed ?? this.tomorrowCheckInMissed,
      checkInClarityCardShown:
          checkInClarityCardShown ?? this.checkInClarityCardShown,
      checkInExamplesOpened:
          checkInExamplesOpened ?? this.checkInExamplesOpened,
      checkInMomentRecorded:
          checkInMomentRecorded ?? this.checkInMomentRecorded,
      tomorrowQuestionVariantShown:
          tomorrowQuestionVariantShown ?? this.tomorrowQuestionVariantShown,
      tomorrowQuestionVariantSelected:
          tomorrowQuestionVariantSelected ??
          this.tomorrowQuestionVariantSelected,
      reminderScheduled: reminderScheduled ?? this.reminderScheduled,
      reminderTapped: reminderTapped ?? this.reminderTapped,
      reminderNotAvailable: reminderNotAvailable ?? this.reminderNotAvailable,
      guidedCheckInShown: guidedCheckInShown ?? this.guidedCheckInShown,
      guidedCheckInStepCompleted:
          guidedCheckInStepCompleted ?? this.guidedCheckInStepCompleted,
      sharperQuestionShown: sharperQuestionShown ?? this.sharperQuestionShown,
      sharperQuestionAccepted:
          sharperQuestionAccepted ?? this.sharperQuestionAccepted,
      betterResultShown: betterResultShown ?? this.betterResultShown,
      betterFirstRecordPromptShown:
          betterFirstRecordPromptShown ?? this.betterFirstRecordPromptShown,
      betterFirstRecordPromptTapped:
          betterFirstRecordPromptTapped ?? this.betterFirstRecordPromptTapped,
      sharperQuestionElevatedShown:
          sharperQuestionElevatedShown ?? this.sharperQuestionElevatedShown,
      sharperQuestionAggressiveShown:
          sharperQuestionAggressiveShown ?? this.sharperQuestionAggressiveShown,
      sharperQuestionAggressiveAccepted:
          sharperQuestionAggressiveAccepted ??
          this.sharperQuestionAggressiveAccepted,
      betterResultElevatedShown:
          betterResultElevatedShown ?? this.betterResultElevatedShown,
      betterResultAggressiveShown:
          betterResultAggressiveShown ?? this.betterResultAggressiveShown,
      checkInGoDeeperShown: checkInGoDeeperShown ?? this.checkInGoDeeperShown,
      checkInGoDeeperTapped:
          checkInGoDeeperTapped ?? this.checkInGoDeeperTapped,
      reminderPermissionRequested:
          reminderPermissionRequested ?? this.reminderPermissionRequested,
      reminderPermissionGranted:
          reminderPermissionGranted ?? this.reminderPermissionGranted,
      reminderPermissionDenied:
          reminderPermissionDenied ?? this.reminderPermissionDenied,
      reminderCancelled: reminderCancelled ?? this.reminderCancelled,
      patternMemoryCreated: patternMemoryCreated ?? this.patternMemoryCreated,
      patternMemoryUpdated: patternMemoryUpdated ?? this.patternMemoryUpdated,
      patternMemoryNextQuestionUsed:
          patternMemoryNextQuestionUsed ?? this.patternMemoryNextQuestionUsed,
      patternProgressMomentCreated:
          patternProgressMomentCreated ?? this.patternProgressMomentCreated,
      patternProgressCardShown:
          patternProgressCardShown ?? this.patternProgressCardShown,
      patternProgressNextQuestionUsed:
          patternProgressNextQuestionUsed ??
          this.patternProgressNextQuestionUsed,
      patternNextActionCreated:
          patternNextActionCreated ?? this.patternNextActionCreated,
      patternNextActionShown:
          patternNextActionShown ?? this.patternNextActionShown,
      patternNextActionUsed:
          patternNextActionUsed ?? this.patternNextActionUsed,
      habitProofCreated: habitProofCreated ?? this.habitProofCreated,
      habitProofShown: habitProofShown ?? this.habitProofShown,
      habitProofCtaTapped: habitProofCtaTapped ?? this.habitProofCtaTapped,
      weeklyPatternRecapCreated:
          weeklyPatternRecapCreated ?? this.weeklyPatternRecapCreated,
      weeklyPatternRecapShown:
          weeklyPatternRecapShown ?? this.weeklyPatternRecapShown,
      weeklyPatternRecapCtaTapped:
          weeklyPatternRecapCtaTapped ?? this.weeklyPatternRecapCtaTapped,
      patternShareCardShown:
          patternShareCardShown ?? this.patternShareCardShown,
      patternShareCopied: patternShareCopied ?? this.patternShareCopied,
      patternShareOpened: patternShareOpened ?? this.patternShareOpened,
      patternShareFailed: patternShareFailed ?? this.patternShareFailed,
      firstLoopRecordOpened:
          firstLoopRecordOpened ?? this.firstLoopRecordOpened,
      firstLoopRecordingStarted:
          firstLoopRecordingStarted ?? this.firstLoopRecordingStarted,
      firstLoopMomentSaved: firstLoopMomentSaved ?? this.firstLoopMomentSaved,
      firstLoopPatternShown:
          firstLoopPatternShown ?? this.firstLoopPatternShown,
      firstLoopTomorrowCheckChosen:
          firstLoopTomorrowCheckChosen ?? this.firstLoopTomorrowCheckChosen,
      firstLoopReady: firstLoopReady ?? this.firstLoopReady,
      returnDayDueShown: returnDayDueShown ?? this.returnDayDueShown,
      returnDayAnswerSelected:
          returnDayAnswerSelected ?? this.returnDayAnswerSelected,
      returnDayRecordingStarted:
          returnDayRecordingStarted ?? this.returnDayRecordingStarted,
      returnDayMomentSaved: returnDayMomentSaved ?? this.returnDayMomentSaved,
      returnDayLoopClosed: returnDayLoopClosed ?? this.returnDayLoopClosed,
      returnDayAbandonedAfterAnswer:
          returnDayAbandonedAfterAnswer ?? this.returnDayAbandonedAfterAnswer,
      resultNextCheckShown: resultNextCheckShown ?? this.resultNextCheckShown,
      resultNextCheckUsed: resultNextCheckUsed ?? this.resultNextCheckUsed,
      resultNextCheckChanged:
          resultNextCheckChanged ?? this.resultNextCheckChanged,
      resultNextCheckUsedFromPatterns:
          resultNextCheckUsedFromPatterns ??
          this.resultNextCheckUsedFromPatterns,
      usefulResultTakeawayShown:
          usefulResultTakeawayShown ?? this.usefulResultTakeawayShown,
      makeResultMoreUsefulTapped:
          makeResultMoreUsefulTapped ?? this.makeResultMoreUsefulTapped,
      makeResultMoreUsefulReasonSelected:
          makeResultMoreUsefulReasonSelected ??
          this.makeResultMoreUsefulReasonSelected,
      usefulResultNextCheckUsed:
          usefulResultNextCheckUsed ?? this.usefulResultNextCheckUsed,
      inputQualityCoachShown:
          inputQualityCoachShown ?? this.inputQualityCoachShown,
      inputQualitySentenceAdded:
          inputQualitySentenceAdded ?? this.inputQualitySentenceAdded,
      inputQualityUsedAnyway:
          inputQualityUsedAnyway ?? this.inputQualityUsedAnyway,
      acceptedWeakInputCount:
          acceptedWeakInputCount ?? this.acceptedWeakInputCount,
      sharpenedInputCount: sharpenedInputCount ?? this.sharpenedInputCount,
      perspectiveShiftShown:
          perspectiveShiftShown ?? this.perspectiveShiftShown,
      perspectiveShiftChanged:
          perspectiveShiftChanged ?? this.perspectiveShiftChanged,
      perspectiveShiftUsed: perspectiveShiftUsed ?? this.perspectiveShiftUsed,
      perspectiveShiftShownFromPatterns:
          perspectiveShiftShownFromPatterns ??
          this.perspectiveShiftShownFromPatterns,
      perspectiveShiftUsedFromPatterns:
          perspectiveShiftUsedFromPatterns ??
          this.perspectiveShiftUsedFromPatterns,
      kinderAngleShown: kinderAngleShown ?? this.kinderAngleShown,
      kinderAngleUsed: kinderAngleUsed ?? this.kinderAngleUsed,
      kinderAngleChanged: kinderAngleChanged ?? this.kinderAngleChanged,
      kinderAngleShownFromPatterns:
          kinderAngleShownFromPatterns ?? this.kinderAngleShownFromPatterns,
      kinderAngleUsedFromPatterns:
          kinderAngleUsedFromPatterns ?? this.kinderAngleUsedFromPatterns,
      quickHelpOpened: quickHelpOpened ?? this.quickHelpOpened,
      quickHelpIntentSelected:
          quickHelpIntentSelected ?? this.quickHelpIntentSelected,
      quickHelpPrimaryActionTapped:
          quickHelpPrimaryActionTapped ?? this.quickHelpPrimaryActionTapped,
      quickHelpCheckUsed: quickHelpCheckUsed ?? this.quickHelpCheckUsed,
      keyMomentCreated: keyMomentCreated ?? this.keyMomentCreated,
      keyMomentOpened: keyMomentOpened ?? this.keyMomentOpened,
      keyMomentSearchUsed: keyMomentSearchUsed ?? this.keyMomentSearchUsed,
      keyMomentUseCheckTapped:
          keyMomentUseCheckTapped ?? this.keyMomentUseCheckTapped,
      askArchiveOpened: askArchiveOpened ?? this.askArchiveOpened,
      askArchiveSearchUsed: askArchiveSearchUsed ?? this.askArchiveSearchUsed,
      askArchiveSuggestedChipTapped:
          askArchiveSuggestedChipTapped ?? this.askArchiveSuggestedChipTapped,
      askArchiveResultOpened:
          askArchiveResultOpened ?? this.askArchiveResultOpened,
      askArchiveUseCheckTapped:
          askArchiveUseCheckTapped ?? this.askArchiveUseCheckTapped,
      archiveCleanViewShown:
          archiveCleanViewShown ?? this.archiveCleanViewShown,
      archiveCleanSectionTapped:
          archiveCleanSectionTapped ?? this.archiveCleanSectionTapped,
      patternProfileShown: patternProfileShown ?? this.patternProfileShown,
      patternProfileOpened: patternProfileOpened ?? this.patternProfileOpened,
      patternProfileUseCheckTapped:
          patternProfileUseCheckTapped ?? this.patternProfileUseCheckTapped,
      patternProfileFindMomentsTapped:
          patternProfileFindMomentsTapped ??
          this.patternProfileFindMomentsTapped,
      patternProfileOpenTimelineTapped:
          patternProfileOpenTimelineTapped ??
          this.patternProfileOpenTimelineTapped,
      patternMapShown: patternMapShown ?? this.patternMapShown,
      patternMapOpened: patternMapOpened ?? this.patternMapOpened,
      patternMapUseCheckTapped:
          patternMapUseCheckTapped ?? this.patternMapUseCheckTapped,
      archiveFeedbackShown: archiveFeedbackShown ?? this.archiveFeedbackShown,
      archiveFeedbackSelected:
          archiveFeedbackSelected ?? this.archiveFeedbackSelected,
      archiveFeedbackUseful:
          archiveFeedbackUseful ?? this.archiveFeedbackUseful,
      archiveFeedbackTooGeneric:
          archiveFeedbackTooGeneric ?? this.archiveFeedbackTooGeneric,
      archiveFeedbackNotMe: archiveFeedbackNotMe ?? this.archiveFeedbackNotMe,
      archiveFeedbackAlreadyKnew:
          archiveFeedbackAlreadyKnew ?? this.archiveFeedbackAlreadyKnew,
      archiveFeedbackMoreSpecific:
          archiveFeedbackMoreSpecific ?? this.archiveFeedbackMoreSpecific,
      archiveCompressionShown:
          archiveCompressionShown ?? this.archiveCompressionShown,
      archiveCompressionOpened:
          archiveCompressionOpened ?? this.archiveCompressionOpened,
      archiveCompressionKept:
          archiveCompressionKept ?? this.archiveCompressionKept,
      archiveCompressionSplit:
          archiveCompressionSplit ?? this.archiveCompressionSplit,
      archiveCompressionHidden:
          archiveCompressionHidden ?? this.archiveCompressionHidden,
      memoryQualityShown: memoryQualityShown ?? this.memoryQualityShown,
      memoryQualityTapped: memoryQualityTapped ?? this.memoryQualityTapped,
      latestMemoryQualityLevel: clearLatestMemoryQualityLevel
          ? null
          : (latestMemoryQualityLevel ?? this.latestMemoryQualityLevel),
      paywallShown: paywallShown ?? this.paywallShown,
      paywallTriggerShown: paywallTriggerShown ?? this.paywallTriggerShown,
      annualPlanShown: annualPlanShown ?? this.annualPlanShown,
      monthlyPlanShown: monthlyPlanShown ?? this.monthlyPlanShown,
      annualPlanSelected: annualPlanSelected ?? this.annualPlanSelected,
      monthlyPlanSelected: monthlyPlanSelected ?? this.monthlyPlanSelected,
      paywallContinueTapped:
          paywallContinueTapped ?? this.paywallContinueTapped,
      paywallDismissed: paywallDismissed ?? this.paywallDismissed,
      restoreTapped: restoreTapped ?? this.restoreTapped,
      archiveRangeReviewShown:
          archiveRangeReviewShown ?? this.archiveRangeReviewShown,
      archiveRangeReviewOpened:
          archiveRangeReviewOpened ?? this.archiveRangeReviewOpened,
      archiveRangeReviewUseCheckTapped:
          archiveRangeReviewUseCheckTapped ??
          this.archiveRangeReviewUseCheckTapped,
      archiveRangeReviewPresetChanged:
          archiveRangeReviewPresetChanged ??
          this.archiveRangeReviewPresetChanged,
      retentionStateShown: retentionStateShown ?? this.retentionStateShown,
      retentionDueShown: retentionDueShown ?? this.retentionDueShown,
      retentionCheckSetShown:
          retentionCheckSetShown ?? this.retentionCheckSetShown,
      retentionLoopClosedShown:
          retentionLoopClosedShown ?? this.retentionLoopClosedShown,
      retentionPrimaryCtaTapped:
          retentionPrimaryCtaTapped ?? this.retentionPrimaryCtaTapped,
      retentionSecondaryCtaTapped:
          retentionSecondaryCtaTapped ?? this.retentionSecondaryCtaTapped,
      retentionNextCheckReady:
          retentionNextCheckReady ?? this.retentionNextCheckReady,
      retentionMissedCheck: retentionMissedCheck ?? this.retentionMissedCheck,
      reminderScheduledFromRetention:
          reminderScheduledFromRetention ?? this.reminderScheduledFromRetention,
      compellingCheckShown: compellingCheckShown ?? this.compellingCheckShown,
      compellingCheckSelected:
          compellingCheckSelected ?? this.compellingCheckSelected,
      compellingCheckMostSpecificSelected:
          compellingCheckMostSpecificSelected ??
          this.compellingCheckMostSpecificSelected,
      compellingCheckAccepted:
          compellingCheckAccepted ?? this.compellingCheckAccepted,
      realReminderPermissionRequested:
          realReminderPermissionRequested ??
          this.realReminderPermissionRequested,
      realReminderPermissionGranted:
          realReminderPermissionGranted ?? this.realReminderPermissionGranted,
      realReminderPermissionDenied:
          realReminderPermissionDenied ?? this.realReminderPermissionDenied,
      realReminderScheduled:
          realReminderScheduled ?? this.realReminderScheduled,
      realReminderCancelled:
          realReminderCancelled ?? this.realReminderCancelled,
      realReminderUnavailable:
          realReminderUnavailable ?? this.realReminderUnavailable,
      realReminderTapped: realReminderTapped ?? this.realReminderTapped,
      currentObjectiveShown:
          currentObjectiveShown ?? this.currentObjectiveShown,
      currentObjectivePrimaryTapped:
          currentObjectivePrimaryTapped ?? this.currentObjectivePrimaryTapped,
      currentObjectiveSecondaryTapped:
          currentObjectiveSecondaryTapped ??
          this.currentObjectiveSecondaryTapped,
      latestCurrentObjectiveType:
          latestCurrentObjectiveType ?? this.latestCurrentObjectiveType,
      proValuePreviewShown: proValuePreviewShown ?? this.proValuePreviewShown,
      proValuePreviewUnlockTapped:
          proValuePreviewUnlockTapped ?? this.proValuePreviewUnlockTapped,
      proValuePreviewDismissed:
          proValuePreviewDismissed ?? this.proValuePreviewDismissed,
      latestProValuePreviewType:
          latestProValuePreviewType ?? this.latestProValuePreviewType,
      objectiveWidgetRefreshAttempted:
          objectiveWidgetRefreshAttempted ??
          this.objectiveWidgetRefreshAttempted,
      objectiveWidgetRefreshSucceeded:
          objectiveWidgetRefreshSucceeded ??
          this.objectiveWidgetRefreshSucceeded,
      objectiveWidgetRefreshFailed:
          objectiveWidgetRefreshFailed ?? this.objectiveWidgetRefreshFailed,
      objectiveWidgetCleared:
          objectiveWidgetCleared ?? this.objectiveWidgetCleared,
      archiveMemorySummaryShown:
          archiveMemorySummaryShown ?? this.archiveMemorySummaryShown,
      archiveMemoryOpenPatternMapTapped:
          archiveMemoryOpenPatternMapTapped ??
          this.archiveMemoryOpenPatternMapTapped,
      archiveMemoryFindMomentsTapped:
          archiveMemoryFindMomentsTapped ?? this.archiveMemoryFindMomentsTapped,
      archiveMemoryUseCheckTapped:
          archiveMemoryUseCheckTapped ?? this.archiveMemoryUseCheckTapped,
      archiveTimelineShown: archiveTimelineShown ?? this.archiveTimelineShown,
      archiveTimelineOpened:
          archiveTimelineOpened ?? this.archiveTimelineOpened,
      archiveTimelineUseCheckTapped:
          archiveTimelineUseCheckTapped ?? this.archiveTimelineUseCheckTapped,
      archiveMemoryDemoShown:
          archiveMemoryDemoShown ?? this.archiveMemoryDemoShown,
      archiveMemoryDemoCtaTapped:
          archiveMemoryDemoCtaTapped ?? this.archiveMemoryDemoCtaTapped,
      archiveMemoryPreviewShown:
          archiveMemoryPreviewShown ?? this.archiveMemoryPreviewShown,
      archiveMemoryPreviewCtaTapped:
          archiveMemoryPreviewCtaTapped ?? this.archiveMemoryPreviewCtaTapped,
      positioningComprehensionAsked:
          positioningComprehensionAsked ?? this.positioningComprehensionAsked,
      positioningComprehensionAnswered:
          positioningComprehensionAnswered ??
          this.positioningComprehensionAnswered,
      positioningUnderstoodArchiveMemory:
          positioningUnderstoodArchiveMemory ??
          this.positioningUnderstoodArchiveMemory,
      positioningJournal: positioningJournal ?? this.positioningJournal,
      positioningChat: positioningChat ?? this.positioningChat,
      positioningNotSure: positioningNotSure ?? this.positioningNotSure,
      activationFirstRecordCardShown:
          activationFirstRecordCardShown ?? this.activationFirstRecordCardShown,
      activationFirstRecordCtaTapped:
          activationFirstRecordCtaTapped ?? this.activationFirstRecordCtaTapped,
      activationStarterPromptSelected:
          activationStarterPromptSelected ??
          this.activationStarterPromptSelected,
      activationFirstSaveCompleted:
          activationFirstSaveCompleted ?? this.activationFirstSaveCompleted,
      activationTomorrowCheckShown:
          activationTomorrowCheckShown ?? this.activationTomorrowCheckShown,
      activationTomorrowCheckUsed:
          activationTomorrowCheckUsed ?? this.activationTomorrowCheckUsed,
      activationTomorrowCheckSharpened:
          activationTomorrowCheckSharpened ??
          this.activationTomorrowCheckSharpened,
      activationTomorrowCheckIgnored:
          activationTomorrowCheckIgnored ?? this.activationTomorrowCheckIgnored,
      activationUsefulTakeawayShown:
          activationUsefulTakeawayShown ?? this.activationUsefulTakeawayShown,
      activationMakeUsefulTapped:
          activationMakeUsefulTapped ?? this.activationMakeUsefulTapped,
      activationMakeUsefulReasonSelected:
          activationMakeUsefulReasonSelected ??
          this.activationMakeUsefulReasonSelected,
      activationResultRatedUseful:
          activationResultRatedUseful ?? this.activationResultRatedUseful,
      activationResultRatedSortOf:
          activationResultRatedSortOf ?? this.activationResultRatedSortOf,
      activationResultRatedNotUseful:
          activationResultRatedNotUseful ?? this.activationResultRatedNotUseful,
      activationNextCheckShown:
          activationNextCheckShown ?? this.activationNextCheckShown,
      activationNextCheckUsed:
          activationNextCheckUsed ?? this.activationNextCheckUsed,
      activationNextCheckChanged:
          activationNextCheckChanged ?? this.activationNextCheckChanged,
      activationRoutineAnchorOffered:
          activationRoutineAnchorOffered ?? this.activationRoutineAnchorOffered,
      activationRoutineAnchorSet:
          activationRoutineAnchorSet ?? this.activationRoutineAnchorSet,
    );
  }

  Map<String, dynamic> toMap() => {
    if (participantId != null && participantId!.isNotEmpty)
      'participantId': participantId,
    'firstReflectionSaved': firstReflectionSaved,
    'firstPatternShown': firstPatternShown,
    'firstPatternAccepted': firstPatternAccepted,
    'firstPatternCorrected': firstPatternCorrected,
    'watchForPromptShown': watchForPromptShown,
    'watchForPromptAccepted': watchForPromptAccepted,
    'returnCaptureQuickAnswerSelected': returnCaptureQuickAnswerSelected,
    'returnedNextDay': returnedNextDay,
    'secondReflectionSaved': secondReflectionSaved,
    'comparisonViewed': comparisonViewed,
    'usefulnessYes': usefulnessYes,
    'usefulnessSortOf': usefulnessSortOf,
    'usefulnessNotReally': usefulnessNotReally,
    'thirdReflectionSaved': thirdReflectionSaved,
    'trialAppOpened': trialAppOpened,
    'trialRecordCtaTapped': trialRecordCtaTapped,
    'trialMicPermissionRequested': trialMicPermissionRequested,
    'trialMicPermissionDenied': trialMicPermissionDenied,
    'trialRecordingStarted': trialRecordingStarted,
    'trialRecordingCancelled': trialRecordingCancelled,
    'trialSaveStarted': trialSaveStarted,
    'trialSaveCompleted': trialSaveCompleted,
    'trialClosedBeforeWatchForAccepted': trialClosedBeforeWatchForAccepted,
    'trialExportCopied': trialExportCopied,
    'tomorrowCheckInCreated': tomorrowCheckInCreated,
    'tomorrowCheckInDueShown': tomorrowCheckInDueShown,
    'tomorrowCheckInOptionSelected': tomorrowCheckInOptionSelected,
    'tomorrowCheckInRecordingStarted': tomorrowCheckInRecordingStarted,
    'tomorrowCheckInCompleted': tomorrowCheckInCompleted,
    'tomorrowCheckInMissed': tomorrowCheckInMissed,
    'checkInClarityCardShown': checkInClarityCardShown,
    'checkInExamplesOpened': checkInExamplesOpened,
    'checkInMomentRecorded': checkInMomentRecorded,
    'tomorrowQuestionVariantShown': tomorrowQuestionVariantShown,
    'tomorrowQuestionVariantSelected': tomorrowQuestionVariantSelected,
    'reminderScheduled': reminderScheduled,
    'reminderTapped': reminderTapped,
    'reminderNotAvailable': reminderNotAvailable,
    'guidedCheckInShown': guidedCheckInShown,
    'guidedCheckInStepCompleted': guidedCheckInStepCompleted,
    'sharperQuestionShown': sharperQuestionShown,
    'sharperQuestionAccepted': sharperQuestionAccepted,
    'betterResultShown': betterResultShown,
    'betterFirstRecordPromptShown': betterFirstRecordPromptShown,
    'betterFirstRecordPromptTapped': betterFirstRecordPromptTapped,
    'sharperQuestionElevatedShown': sharperQuestionElevatedShown,
    'sharperQuestionAggressiveShown': sharperQuestionAggressiveShown,
    'sharperQuestionAggressiveAccepted': sharperQuestionAggressiveAccepted,
    'betterResultElevatedShown': betterResultElevatedShown,
    'betterResultAggressiveShown': betterResultAggressiveShown,
    'checkInGoDeeperShown': checkInGoDeeperShown,
    'checkInGoDeeperTapped': checkInGoDeeperTapped,
    'reminderPermissionRequested': reminderPermissionRequested,
    'reminderPermissionGranted': reminderPermissionGranted,
    'reminderPermissionDenied': reminderPermissionDenied,
    'reminderCancelled': reminderCancelled,
    'patternMemoryCreated': patternMemoryCreated,
    'patternMemoryUpdated': patternMemoryUpdated,
    'patternMemoryNextQuestionUsed': patternMemoryNextQuestionUsed,
    'patternProgressMomentCreated': patternProgressMomentCreated,
    'patternProgressCardShown': patternProgressCardShown,
    'patternProgressNextQuestionUsed': patternProgressNextQuestionUsed,
    'patternNextActionCreated': patternNextActionCreated,
    'patternNextActionShown': patternNextActionShown,
    'patternNextActionUsed': patternNextActionUsed,
    'habitProofCreated': habitProofCreated,
    'habitProofShown': habitProofShown,
    'habitProofCtaTapped': habitProofCtaTapped,
    'weeklyPatternRecapCreated': weeklyPatternRecapCreated,
    'weeklyPatternRecapShown': weeklyPatternRecapShown,
    'weeklyPatternRecapCtaTapped': weeklyPatternRecapCtaTapped,
    'patternShareCardShown': patternShareCardShown,
    'patternShareCopied': patternShareCopied,
    'patternShareOpened': patternShareOpened,
    'patternShareFailed': patternShareFailed,
    'firstLoopRecordOpened': firstLoopRecordOpened,
    'firstLoopRecordingStarted': firstLoopRecordingStarted,
    'firstLoopMomentSaved': firstLoopMomentSaved,
    'firstLoopPatternShown': firstLoopPatternShown,
    'firstLoopTomorrowCheckChosen': firstLoopTomorrowCheckChosen,
    'firstLoopReady': firstLoopReady,
    'returnDayDueShown': returnDayDueShown,
    'returnDayAnswerSelected': returnDayAnswerSelected,
    'returnDayRecordingStarted': returnDayRecordingStarted,
    'returnDayMomentSaved': returnDayMomentSaved,
    'returnDayLoopClosed': returnDayLoopClosed,
    'returnDayAbandonedAfterAnswer': returnDayAbandonedAfterAnswer,
    'resultNextCheckShown': resultNextCheckShown,
    'resultNextCheckUsed': resultNextCheckUsed,
    'resultNextCheckChanged': resultNextCheckChanged,
    'resultNextCheckUsedFromPatterns': resultNextCheckUsedFromPatterns,
    'usefulResultTakeawayShown': usefulResultTakeawayShown,
    'makeResultMoreUsefulTapped': makeResultMoreUsefulTapped,
    'makeResultMoreUsefulReasonSelected': makeResultMoreUsefulReasonSelected,
    'usefulResultNextCheckUsed': usefulResultNextCheckUsed,
    'inputQualityCoachShown': inputQualityCoachShown,
    'inputQualitySentenceAdded': inputQualitySentenceAdded,
    'inputQualityUsedAnyway': inputQualityUsedAnyway,
    'acceptedWeakInputCount': acceptedWeakInputCount,
    'sharpenedInputCount': sharpenedInputCount,
    'perspectiveShiftShown': perspectiveShiftShown,
    'perspectiveShiftChanged': perspectiveShiftChanged,
    'perspectiveShiftUsed': perspectiveShiftUsed,
    'perspectiveShiftShownFromPatterns': perspectiveShiftShownFromPatterns,
    'perspectiveShiftUsedFromPatterns': perspectiveShiftUsedFromPatterns,
    'kinderAngleShown': kinderAngleShown,
    'kinderAngleUsed': kinderAngleUsed,
    'kinderAngleChanged': kinderAngleChanged,
    'kinderAngleShownFromPatterns': kinderAngleShownFromPatterns,
    'kinderAngleUsedFromPatterns': kinderAngleUsedFromPatterns,
    'quickHelpOpened': quickHelpOpened,
    'quickHelpIntentSelected': quickHelpIntentSelected,
    'quickHelpPrimaryActionTapped': quickHelpPrimaryActionTapped,
    'quickHelpCheckUsed': quickHelpCheckUsed,
    'keyMomentCreated': keyMomentCreated,
    'keyMomentOpened': keyMomentOpened,
    'keyMomentSearchUsed': keyMomentSearchUsed,
    'keyMomentUseCheckTapped': keyMomentUseCheckTapped,
    'askArchiveOpened': askArchiveOpened,
    'askArchiveSearchUsed': askArchiveSearchUsed,
    'askArchiveSuggestedChipTapped': askArchiveSuggestedChipTapped,
    'askArchiveResultOpened': askArchiveResultOpened,
    'askArchiveUseCheckTapped': askArchiveUseCheckTapped,
    'archiveCleanViewShown': archiveCleanViewShown,
    'archiveCleanSectionTapped': archiveCleanSectionTapped,
    'patternProfileShown': patternProfileShown,
    'patternProfileOpened': patternProfileOpened,
    'patternProfileUseCheckTapped': patternProfileUseCheckTapped,
    'patternProfileFindMomentsTapped': patternProfileFindMomentsTapped,
    'patternProfileOpenTimelineTapped': patternProfileOpenTimelineTapped,
    'patternMapShown': patternMapShown,
    'patternMapOpened': patternMapOpened,
    'patternMapUseCheckTapped': patternMapUseCheckTapped,
    'archiveFeedbackShown': archiveFeedbackShown,
    'archiveFeedbackSelected': archiveFeedbackSelected,
    'archiveFeedbackUseful': archiveFeedbackUseful,
    'archiveFeedbackTooGeneric': archiveFeedbackTooGeneric,
    'archiveFeedbackNotMe': archiveFeedbackNotMe,
    'archiveFeedbackAlreadyKnew': archiveFeedbackAlreadyKnew,
    'archiveFeedbackMoreSpecific': archiveFeedbackMoreSpecific,
    'archiveCompressionShown': archiveCompressionShown,
    'archiveCompressionOpened': archiveCompressionOpened,
    'archiveCompressionKept': archiveCompressionKept,
    'archiveCompressionSplit': archiveCompressionSplit,
    'archiveCompressionHidden': archiveCompressionHidden,
    'memoryQualityShown': memoryQualityShown,
    'memoryQualityTapped': memoryQualityTapped,
    if (latestMemoryQualityLevel != null)
      'latestMemoryQualityLevel': latestMemoryQualityLevel,
    'paywallShown': paywallShown,
    'paywallTriggerShown': paywallTriggerShown,
    'annualPlanShown': annualPlanShown,
    'monthlyPlanShown': monthlyPlanShown,
    'annualPlanSelected': annualPlanSelected,
    'monthlyPlanSelected': monthlyPlanSelected,
    'paywallContinueTapped': paywallContinueTapped,
    'paywallDismissed': paywallDismissed,
    'restoreTapped': restoreTapped,
    'archiveRangeReviewShown': archiveRangeReviewShown,
    'archiveRangeReviewOpened': archiveRangeReviewOpened,
    'archiveRangeReviewUseCheckTapped': archiveRangeReviewUseCheckTapped,
    'archiveRangeReviewPresetChanged': archiveRangeReviewPresetChanged,
    'retentionStateShown': retentionStateShown,
    'retentionDueShown': retentionDueShown,
    'retentionCheckSetShown': retentionCheckSetShown,
    'retentionLoopClosedShown': retentionLoopClosedShown,
    'retentionPrimaryCtaTapped': retentionPrimaryCtaTapped,
    'retentionSecondaryCtaTapped': retentionSecondaryCtaTapped,
    'retentionNextCheckReady': retentionNextCheckReady,
    'retentionMissedCheck': retentionMissedCheck,
    'reminderScheduledFromRetention': reminderScheduledFromRetention,
    'compellingCheckShown': compellingCheckShown,
    'compellingCheckSelected': compellingCheckSelected,
    'compellingCheckMostSpecificSelected': compellingCheckMostSpecificSelected,
    'compellingCheckAccepted': compellingCheckAccepted,
    'realReminderPermissionRequested': realReminderPermissionRequested,
    'realReminderPermissionGranted': realReminderPermissionGranted,
    'realReminderPermissionDenied': realReminderPermissionDenied,
    'realReminderScheduled': realReminderScheduled,
    'realReminderCancelled': realReminderCancelled,
    'realReminderUnavailable': realReminderUnavailable,
    'realReminderTapped': realReminderTapped,
    'currentObjectiveShown': currentObjectiveShown,
    'currentObjectivePrimaryTapped': currentObjectivePrimaryTapped,
    'currentObjectiveSecondaryTapped': currentObjectiveSecondaryTapped,
    'latestCurrentObjectiveType': latestCurrentObjectiveType,
    'proValuePreviewShown': proValuePreviewShown,
    'proValuePreviewUnlockTapped': proValuePreviewUnlockTapped,
    'proValuePreviewDismissed': proValuePreviewDismissed,
    'latestProValuePreviewType': latestProValuePreviewType,
    'objectiveWidgetRefreshAttempted': objectiveWidgetRefreshAttempted,
    'objectiveWidgetRefreshSucceeded': objectiveWidgetRefreshSucceeded,
    'objectiveWidgetRefreshFailed': objectiveWidgetRefreshFailed,
    'objectiveWidgetCleared': objectiveWidgetCleared,
    'archiveMemorySummaryShown': archiveMemorySummaryShown,
    'archiveMemoryOpenPatternMapTapped': archiveMemoryOpenPatternMapTapped,
    'archiveMemoryFindMomentsTapped': archiveMemoryFindMomentsTapped,
    'archiveMemoryUseCheckTapped': archiveMemoryUseCheckTapped,
    'archiveTimelineShown': archiveTimelineShown,
    'archiveTimelineOpened': archiveTimelineOpened,
    'archiveTimelineUseCheckTapped': archiveTimelineUseCheckTapped,
    'archiveMemoryDemoShown': archiveMemoryDemoShown,
    'archiveMemoryDemoCtaTapped': archiveMemoryDemoCtaTapped,
    'archiveMemoryPreviewShown': archiveMemoryPreviewShown,
    'archiveMemoryPreviewCtaTapped': archiveMemoryPreviewCtaTapped,
    'positioningComprehensionAsked': positioningComprehensionAsked,
    'positioningComprehensionAnswered': positioningComprehensionAnswered,
    'positioningUnderstoodArchiveMemory': positioningUnderstoodArchiveMemory,
    'positioningJournal': positioningJournal,
    'positioningChat': positioningChat,
    'positioningNotSure': positioningNotSure,
    'activationFirstRecordCardShown': activationFirstRecordCardShown,
    'activationFirstRecordCtaTapped': activationFirstRecordCtaTapped,
    'activationStarterPromptSelected': activationStarterPromptSelected,
    'activationFirstSaveCompleted': activationFirstSaveCompleted,
    'activationTomorrowCheckShown': activationTomorrowCheckShown,
    'activationTomorrowCheckUsed': activationTomorrowCheckUsed,
    'activationTomorrowCheckSharpened': activationTomorrowCheckSharpened,
    'activationTomorrowCheckIgnored': activationTomorrowCheckIgnored,
    'activationUsefulTakeawayShown': activationUsefulTakeawayShown,
    'activationMakeUsefulTapped': activationMakeUsefulTapped,
    'activationMakeUsefulReasonSelected': activationMakeUsefulReasonSelected,
    'activationResultRatedUseful': activationResultRatedUseful,
    'activationResultRatedSortOf': activationResultRatedSortOf,
    'activationResultRatedNotUseful': activationResultRatedNotUseful,
    'activationNextCheckShown': activationNextCheckShown,
    'activationNextCheckUsed': activationNextCheckUsed,
    'activationNextCheckChanged': activationNextCheckChanged,
    'activationRoutineAnchorOffered': activationRoutineAnchorOffered,
    'activationRoutineAnchorSet': activationRoutineAnchorSet,
  };
}