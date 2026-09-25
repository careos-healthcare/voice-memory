import 'package:archiveme_mobile/features/acquisition/acquisition_cohort_model.dart';
import 'package:archiveme_mobile/features/activation/first_loop_activation_model.dart';
import 'package:archiveme_mobile/features/activation/return_day_friction_model.dart';
import 'package:archiveme_mobile/features/pattern_memory/habit_proof_model.dart';
import 'package:archiveme_mobile/features/pattern_memory/pattern_memory_model.dart';
import 'package:archiveme_mobile/features/pattern_memory/pattern_next_action_model.dart';
import 'package:archiveme_mobile/features/pattern_memory/pattern_progress_model.dart';
import 'package:archiveme_mobile/features/pattern_memory/weekly_pattern_recap_model.dart';
import 'package:archiveme_mobile/features/retention/retention_diagnosis_snapshot.dart';
import 'package:archiveme_mobile/features/trial/hook_diagnosis_model.dart';
import 'package:archiveme_mobile/features/trial/hook_rescue_decision_engine.dart';
import 'package:archiveme_mobile/features/trial/hook_rescue_decision_model.dart';

enum TrialSummaryVerdict { promising, weak, unclear }

enum TrialFrictionVerdict {
  clean,
  permissionIssue,
  recordFriction,
  hookIssue,
  unclear,
}

extension TrialFrictionVerdictIds on TrialFrictionVerdict {
  String get id => name;
}

extension TrialSummaryVerdictIds on TrialSummaryVerdict {
  String get id => name;
}

/// Whether tomorrow check-in reminders are worth building yet.
enum ReminderReadiness { notReady, maybe, ready }

extension ReminderReadinessIds on ReminderReadiness {
  String get id => name;
}

/// Runtime status of the local reminder implementation.
enum ReminderImplementationStatus {
  noOp,
  available,
  permissionDenied,
  scheduled,
}

extension ReminderImplementationStatusIds on ReminderImplementationStatus {
  String get id => name;
}

/// Outcome of the reminder readiness gate.
class ReminderReadinessDecision {
  const ReminderReadinessDecision({
    required this.readiness,
    required this.reason,
    required this.candidateCount,
  });

  final ReminderReadiness readiness;
  final String reason;
  final int candidateCount;
}

/// Decides whether reminders are worth testing.
///
/// Reminders only help when people care about the question but forget to
/// return. They annoy people when the question is confusing or not useful.
ReminderReadinessDecision computeReminderReadiness({
  required int checkInCreatedCount,
  required int checkInDueShownCount,
  required HookDiagnosisSummary hookDiagnosis,
}) {
  final created = checkInCreatedCount;
  final dueShown = checkInDueShownCount;
  final d = hookDiagnosis;

  final ratedTotal = d.questionRatedTotal;
  final positive = d.checkInQuestionRatedUseful + d.checkInQuestionRatedSortOf;
  final usefulRate = d.usefulQuestionRate;

  final missedReturns = (created - dueShown).clamp(0, created);
  final candidateCount = missedReturns > d.forgotCount
      ? missedReturns
      : d.forgotCount;

  // A negative reason is "dominant" when it shows up and is at least as strong
  // as the positive question signal.
  final confusingDominant =
      d.confusingCount >= 1 && d.confusingCount >= positive;
  final didNotCareDominant =
      d.didNotCareCount >= 1 && d.didNotCareCount >= positive;
  final resultNotUsefulHigh =
      d.resultNotUsefulCount >= 1 &&
      (d.resultUsefulCount + d.resultSortOfCount) == 0;

  if (created == 0) {
    return ReminderReadinessDecision(
      readiness: ReminderReadiness.notReady,
      reason: 'Do not add reminders yet. No check-in was created.',
      candidateCount: candidateCount,
    );
  }
  if (confusingDominant) {
    return ReminderReadinessDecision(
      readiness: ReminderReadiness.notReady,
      reason: 'Do not add reminders yet. The check-in is still confusing.',
      candidateCount: candidateCount,
    );
  }
  if (didNotCareDominant) {
    return ReminderReadinessDecision(
      readiness: ReminderReadiness.notReady,
      reason:
          'Do not add reminders yet. People did not care about the question.',
      candidateCount: candidateCount,
    );
  }
  if (resultNotUsefulHigh) {
    return ReminderReadinessDecision(
      readiness: ReminderReadiness.notReady,
      reason: 'Do not add reminders yet. The result was not useful.',
      candidateCount: candidateCount,
    );
  }

  final questionUseful = usefulRate != null && usefulRate >= 0.5;
  final enoughRatings = ratedTotal >= 2;

  if (created >= 2 &&
      questionUseful &&
      enoughRatings &&
      dueShown < created &&
      !confusingDominant &&
      !didNotCareDominant) {
    return ReminderReadinessDecision(
      readiness: ReminderReadiness.ready,
      reason:
          'Reminder is worth testing. People cared about the question but did not return.',
      candidateCount: candidateCount,
    );
  }

  return ReminderReadinessDecision(
    readiness: ReminderReadiness.maybe,
    reason: 'Watch this. Some people forgot, but rating volume is low.',
    candidateCount: candidateCount,
  );
}

/// Aggregated activation metrics for a trial participant.
class TrialSummaryModel {
  const TrialSummaryModel({
    required this.generatedAt, required this.firstReflectionSaved, required this.firstPatternShown, required this.firstPatternAccepted, required this.firstPatternCorrected, required this.watchForPromptShown, required this.watchForPromptAccepted, required this.returnCaptureQuickAnswerSelected, required this.returnedNextDay, required this.secondReflectionSaved, required this.comparisonViewed, required this.usefulnessYes, required this.usefulnessSortOf, required this.usefulnessNotReally, required this.thirdReflectionSaved, required this.appOpenedCount, required this.recordCtaTappedCount, required this.recordingStartedCount, required this.recordingSavedCount, required this.micDeniedCount, required this.saveCompletedCount, required this.closedBeforeWatchForAcceptedCount, required this.trialFrictionVerdict, required this.checkInCreatedCount, required this.checkInDueShownCount, required this.checkInOptionSelectedCount, required this.checkInCompletedCount, required this.verdict, required this.hookDiagnosis, this.participantId,
    this.checkInCompletionRate,
    this.correctionRate,
    this.watchForAcceptRate,
    this.day2ReturnRate,
    this.usefulRate,
    this.reminderScheduledCount = 0,
    this.reminderDeniedCount = 0,
    this.reminderPluginAvailable = false,
    this.reminderPermissionRequestedCount = 0,
    this.reminderPermissionGrantedCount = 0,
    this.reminderPermissionDeniedCount = 0,
    this.reminderCancelledCount = 0,
    this.reminderTappedCount = 0,
    this.reminderEnabled = false,
    this.patternMemoryCreatedCount = 0,
    this.patternMemoryUpdatedCount = 0,
    this.patternMemoryCheckInCount = 0,
    this.activePatternMemoryStatus,
    this.patternProgressMomentCreatedCount = 0,
    this.patternProgressCardShownCount = 0,
    this.latestPatternProgressType,
    this.patternNextActionCreatedCount = 0,
    this.patternNextActionUsedCount = 0,
    this.latestPatternNextActionType,
    this.habitProofCreatedCount = 0,
    this.habitProofShownCount = 0,
    this.habitProofCtaTappedCount = 0,
    this.latestHabitProofType,
    this.weeklyPatternRecapCreatedCount = 0,
    this.weeklyPatternRecapShownCount = 0,
    this.weeklyPatternRecapCtaTappedCount = 0,
    this.latestWeeklyPatternRecapType,
    this.patternShareCardShownCount = 0,
    this.patternShareCopiedCount = 0,
    this.patternShareOpenedCount = 0,
    this.patternShareFailedCount = 0,
    this.firstLoopStage = FirstLoopActivationStage.notStarted,
    this.firstLoopCompleted = false,
    this.secondsToFirstSave,
    this.secondsToLoopReady,
    this.firstLoopDropoffPoint = FirstLoopDropoffPoint.none,
    this.returnDayDueShownCount = 0,
    this.returnDayAnswerSelectedCount = 0,
    this.returnDayLoopClosedCount = 0,
    this.latestSecondsToAnswer,
    this.latestSecondsToLoopClosed,
    this.returnDayCompletionRate,
    this.returnDayDropoffPoint = ReturnDayDropoffPoint.none,
    this.sharperQuestionGeneratedCount = 0,
    this.verySharpQuestionGeneratedCount = 0,
    this.sharperQuestionAcceptedCount = 0,
    this.verySharpQuestionAcceptedCount = 0,
    this.betterResultShownCount = 0,
    this.aggressiveBetterResultShownCount = 0,
    this.checkInGoDeeperShownCount = 0,
    this.checkInGoDeeperTappedCount = 0,
    this.resultNextCheckShownCount = 0,
    this.resultNextCheckUsedCount = 0,
    this.resultNextCheckChangedCount = 0,
    this.resultNextCheckUsedFromPatternsCount = 0,
    this.usefulResultTakeawayShownCount = 0,
    this.makeResultMoreUsefulTappedCount = 0,
    this.makeResultMoreUsefulReasonSelectedCount = 0,
    this.usefulResultNextCheckUsedCount = 0,
    this.inputQualityCoachShownCount = 0,
    this.inputQualitySentenceAddedCount = 0,
    this.inputQualityUsedAnywayCount = 0,
    this.acceptedWeakInputCount = 0,
    this.sharpenedInputCount = 0,
    this.latestInputQualityLevel,
    this.averageInputQualityScore,
    this.perspectiveShiftShownCount = 0,
    this.perspectiveShiftChangedCount = 0,
    this.perspectiveShiftUsedCount = 0,
    this.perspectiveShiftShownFromPatternsCount = 0,
    this.perspectiveShiftUsedFromPatternsCount = 0,
    this.kinderAngleShownCount = 0,
    this.kinderAngleUsedCount = 0,
    this.kinderAngleChangedCount = 0,
    this.kinderAngleShownFromPatternsCount = 0,
    this.kinderAngleUsedFromPatternsCount = 0,
    this.quickHelpOpenedCount = 0,
    this.quickHelpIntentSelectedCount = 0,
    this.quickHelpPrimaryActionTappedCount = 0,
    this.quickHelpCheckUsedCount = 0,
    this.keyMomentCreatedCount = 0,
    this.keyMomentOpenedCount = 0,
    this.keyMomentSearchUsedCount = 0,
    this.keyMomentUseCheckTappedCount = 0,
    this.askArchiveOpenedCount = 0,
    this.askArchiveSearchUsedCount = 0,
    this.askArchiveSuggestedChipTappedCount = 0,
    this.askArchiveResultOpenedCount = 0,
    this.askArchiveUseCheckTappedCount = 0,
    this.archiveCleanViewShownCount = 0,
    this.archiveCleanSectionTappedCount = 0,
    this.patternProfileShownCount = 0,
    this.patternProfileOpenedCount = 0,
    this.patternProfileUseCheckTappedCount = 0,
    this.patternProfileFindMomentsTappedCount = 0,
    this.patternProfileOpenTimelineTappedCount = 0,
    this.patternMapShownCount = 0,
    this.patternMapOpenedCount = 0,
    this.patternMapUseCheckTappedCount = 0,
    this.archiveFeedbackShownCount = 0,
    this.archiveFeedbackSelectedCount = 0,
    this.archiveFeedbackUsefulCount = 0,
    this.archiveFeedbackTooGenericCount = 0,
    this.archiveFeedbackNotMeCount = 0,
    this.archiveFeedbackAlreadyKnewCount = 0,
    this.archiveFeedbackMoreSpecificCount = 0,
    this.archiveCompressionShownCount = 0,
    this.archiveCompressionOpenedCount = 0,
    this.archiveCompressionKeptCount = 0,
    this.archiveCompressionSplitCount = 0,
    this.archiveCompressionHiddenCount = 0,
    this.memoryQualityShownCount = 0,
    this.memoryQualityTappedCount = 0,
    this.latestMemoryQualityLevel,
    this.paywallShownCount = 0,
    this.paywallTriggerShownCount = 0,
    this.annualPlanShownCount = 0,
    this.monthlyPlanShownCount = 0,
    this.annualPlanSelectedCount = 0,
    this.monthlyPlanSelectedCount = 0,
    this.paywallContinueTappedCount = 0,
    this.paywallDismissedCount = 0,
    this.restoreTappedCount = 0,
    this.archiveRangeReviewShownCount = 0,
    this.archiveRangeReviewOpenedCount = 0,
    this.archiveRangeReviewUseCheckTappedCount = 0,
    this.archiveRangeReviewPresetChangedCount = 0,
    this.retentionStateShownCount = 0,
    this.retentionDueShownCount = 0,
    this.retentionCheckSetShownCount = 0,
    this.retentionLoopClosedShownCount = 0,
    this.retentionPrimaryCtaTappedCount = 0,
    this.retentionNextCheckReadyCount = 0,
    this.retentionMissedCheckCount = 0,
    this.reminderScheduledFromRetentionCount = 0,
    this.compellingCheckShownCount = 0,
    this.compellingCheckSelectedCount = 0,
    this.compellingCheckMostSpecificSelectedCount = 0,
    this.compellingCheckAcceptedCount = 0,
    this.realReminderPermissionRequestedCount = 0,
    this.realReminderPermissionGrantedCount = 0,
    this.realReminderPermissionDeniedCount = 0,
    this.realReminderScheduledCount = 0,
    this.realReminderCancelledCount = 0,
    this.realReminderUnavailableCount = 0,
    this.currentObjectiveShownCount = 0,
    this.currentObjectivePrimaryTappedCount = 0,
    this.currentObjectiveSecondaryTappedCount = 0,
    this.latestCurrentObjectiveType,
    this.proValuePreviewShownCount = 0,
    this.proValuePreviewUnlockTappedCount = 0,
    this.proValuePreviewDismissedCount = 0,
    this.latestProValuePreviewType,
    this.objectiveWidgetRefreshAttemptedCount = 0,
    this.objectiveWidgetRefreshSucceededCount = 0,
    this.objectiveWidgetRefreshFailedCount = 0,
    this.objectiveWidgetClearedCount = 0,
    this.archiveMemorySummaryShownCount = 0,
    this.archiveMemoryOpenPatternMapTappedCount = 0,
    this.archiveMemoryFindMomentsTappedCount = 0,
    this.archiveMemoryUseCheckTappedCount = 0,
    this.archiveTimelineShownCount = 0,
    this.archiveTimelineOpenedCount = 0,
    this.archiveTimelineUseCheckTappedCount = 0,
    this.positioningComprehensionAskedCount = 0,
    this.positioningComprehensionAnsweredCount = 0,
    this.positioningUnderstoodArchiveMemoryCount = 0,
    this.positioningJournalCount = 0,
    this.positioningChatCount = 0,
    this.positioningNotSureCount = 0,
    this.retentionDiagnosisSnapshot,
    this.acquisitionCohort,
    this.capacityInviteCopiedCount = 0,
    this.proveInviteCopiedCount = 0,
    this.genericInviteCopiedCount = 0,
    this.proveDefaultShownCount = 0,
    this.proveDefaultStartedCount = 0,
    this.proveFirstMomentRecordedCount = 0,
    this.proveReadAcceptedCount = 0,
    this.proveSecondMomentRecordedCount = 0,
    this.proveReviewConfirmedCount = 0,
    this.provePaywallTeaserTappedCount = 0,
    this.activationFullLoopCompletedCount = 0,
    this.activationWeakestBucket = 'none',
    this.activationSavedFirstMoment = false,
    this.activationChoseTomorrowCheck = false,
    this.activationReturnedNextDay = false,
    this.activationClosedLoop = false,
    this.activationRatedUsefulOrSortOf = false,
    this.activationChoseNextCheck = false,
  });

  final String? participantId;
  final DateTime generatedAt;
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
  final int appOpenedCount;
  final int recordCtaTappedCount;
  final int recordingStartedCount;
  final int recordingSavedCount;
  final int micDeniedCount;
  final int saveCompletedCount;
  final int closedBeforeWatchForAcceptedCount;
  final TrialFrictionVerdict trialFrictionVerdict;
  final int checkInCreatedCount;
  final int checkInDueShownCount;
  final int checkInOptionSelectedCount;
  final int checkInCompletedCount;
  final double? checkInCompletionRate;
  final double? correctionRate;
  final double? watchForAcceptRate;
  final double? day2ReturnRate;
  final double? usefulRate;
  final TrialSummaryVerdict verdict;
  final HookDiagnosisSummary hookDiagnosis;
  final int reminderScheduledCount;
  final int reminderDeniedCount;
  final bool reminderPluginAvailable;
  final int reminderPermissionRequestedCount;
  final int reminderPermissionGrantedCount;
  final int reminderPermissionDeniedCount;
  final int reminderCancelledCount;
  final int reminderTappedCount;
  final bool reminderEnabled;
  final int patternMemoryCreatedCount;
  final int patternMemoryUpdatedCount;
  final int patternMemoryCheckInCount;
  final PatternMemoryStatus? activePatternMemoryStatus;
  final int patternProgressMomentCreatedCount;
  final int patternProgressCardShownCount;
  final PatternProgressType? latestPatternProgressType;
  final int patternNextActionCreatedCount;
  final int patternNextActionUsedCount;
  final PatternNextActionType? latestPatternNextActionType;
  final int habitProofCreatedCount;
  final int habitProofShownCount;
  final int habitProofCtaTappedCount;
  final HabitProofType? latestHabitProofType;
  final int weeklyPatternRecapCreatedCount;
  final int weeklyPatternRecapShownCount;
  final int weeklyPatternRecapCtaTappedCount;
  final WeeklyPatternRecapType? latestWeeklyPatternRecapType;
  final int patternShareCardShownCount;
  final int patternShareCopiedCount;
  final int patternShareOpenedCount;
  final int patternShareFailedCount;
  final FirstLoopActivationStage firstLoopStage;
  final bool firstLoopCompleted;
  final int? secondsToFirstSave;
  final int? secondsToLoopReady;
  final FirstLoopDropoffPoint firstLoopDropoffPoint;
  final int returnDayDueShownCount;
  final int returnDayAnswerSelectedCount;
  final int returnDayLoopClosedCount;
  final int? latestSecondsToAnswer;
  final int? latestSecondsToLoopClosed;
  final double? returnDayCompletionRate;
  final ReturnDayDropoffPoint returnDayDropoffPoint;

  /// Hook quality: sharper / very-sharp question generation and acceptance.
  final int sharperQuestionGeneratedCount;
  final int verySharpQuestionGeneratedCount;
  final int sharperQuestionAcceptedCount;
  final int verySharpQuestionAcceptedCount;

  /// Hook quality: better-result interpretation surfaced to the user.
  final int betterResultShownCount;
  final int aggressiveBetterResultShownCount;

  /// Hook quality: "go deeper" offered / opened after an obvious or weak result.
  final int checkInGoDeeperShownCount;
  final int checkInGoDeeperTappedCount;

  /// Result-to-next-check: the next useful check shown after a loop closes,
  /// used as-is, swapped for a different check, or used from the Patterns tab.
  final int resultNextCheckShownCount;
  final int resultNextCheckUsedCount;
  final int resultNextCheckChangedCount;
  final int resultNextCheckUsedFromPatternsCount;

  /// Useful result rescue: the takeaway shown before rating, the "make this
  /// more useful" path opened / used, and the next check used from a takeaway.
  final int usefulResultTakeawayShownCount;
  final int makeResultMoreUsefulTappedCount;
  final int makeResultMoreUsefulReasonSelectedCount;
  final int usefulResultNextCheckUsedCount;

  /// Input quality coach: the coach shown on weak input, sentences added,
  /// weak input kept anyway, and the latest level / average score.
  final int inputQualityCoachShownCount;
  final int inputQualitySentenceAddedCount;
  final int inputQualityUsedAnywayCount;
  final int acceptedWeakInputCount;
  final int sharpenedInputCount;
  final String? latestInputQualityLevel;
  final double? averageInputQualityScore;

  /// Perspective shift: another angle shown after a result, cycled to a
  /// different angle, used as a next check, and the same from the Patterns tab.
  final int perspectiveShiftShownCount;
  final int perspectiveShiftChangedCount;
  final int perspectiveShiftUsedCount;
  final int perspectiveShiftShownFromPatternsCount;
  final int perspectiveShiftUsedFromPatternsCount;

  /// Kinder angle: a grounded kinder read shown after a hard moment, used as a
  /// next check, stepped back to a broader read, and the same from Patterns.
  final int kinderAngleShownCount;
  final int kinderAngleUsedCount;
  final int kinderAngleChangedCount;
  final int kinderAngleShownFromPatternsCount;
  final int kinderAngleUsedFromPatternsCount;

  /// Quick help: the always-available "Need help?" sheet — opened, an intent
  /// chosen, the primary action tapped, and a next check actually used.
  final int quickHelpOpenedCount;
  final int quickHelpIntentSelectedCount;
  final int quickHelpPrimaryActionTappedCount;
  final int quickHelpCheckUsedCount;

  /// Key Moments timeline: moments created, opened, searches run, and "use this
  /// check" taps from a revisited moment.
  final int keyMomentCreatedCount;
  final int keyMomentOpenedCount;
  final int keyMomentSearchUsedCount;
  final int keyMomentUseCheckTappedCount;

  /// Ask my Archive: screen opened, searches run, chip taps, result opens, and
  /// "use this check" taps from search results.
  final int askArchiveOpenedCount;
  final int askArchiveSearchUsedCount;
  final int askArchiveSuggestedChipTappedCount;
  final int askArchiveResultOpenedCount;
  final int askArchiveUseCheckTappedCount;

  /// Archive clean view: organized entry card shown and section taps.
  final int archiveCleanViewShownCount;
  final int archiveCleanSectionTappedCount;

  /// Pattern profile: compact card shown, profile opened, and action taps.
  final int patternProfileShownCount;
  final int patternProfileOpenedCount;
  final int patternProfileUseCheckTappedCount;
  final int patternProfileFindMomentsTappedCount;
  final int patternProfileOpenTimelineTappedCount;

  /// Pattern map: the map shown inline, opened on its own screen, and "use this
  /// check" taps that set tomorrow's check from the map.
  final int patternMapShownCount;
  final int patternMapOpenedCount;
  final int patternMapUseCheckTappedCount;

  /// Feedback learning loop: feedback rows shown, any chip selected, and the
  /// per-type counts behind the dominant issue.
  final int archiveFeedbackShownCount;
  final int archiveFeedbackSelectedCount;
  final int archiveFeedbackUsefulCount;
  final int archiveFeedbackTooGenericCount;
  final int archiveFeedbackNotMeCount;
  final int archiveFeedbackAlreadyKnewCount;
  final int archiveFeedbackMoreSpecificCount;
  final int archiveCompressionShownCount;
  final int archiveCompressionOpenedCount;
  final int archiveCompressionKeptCount;
  final int archiveCompressionSplitCount;
  final int archiveCompressionHiddenCount;
  final int memoryQualityShownCount;
  final int memoryQualityTappedCount;
  final String? latestMemoryQualityLevel;
  final int paywallShownCount;
  final int paywallTriggerShownCount;
  final int annualPlanShownCount;
  final int monthlyPlanShownCount;
  final int annualPlanSelectedCount;
  final int monthlyPlanSelectedCount;
  final int paywallContinueTappedCount;
  final int paywallDismissedCount;
  final int restoreTappedCount;
  final int archiveRangeReviewShownCount;
  final int archiveRangeReviewOpenedCount;
  final int archiveRangeReviewUseCheckTappedCount;
  final int archiveRangeReviewPresetChangedCount;
  final int retentionStateShownCount;
  final int retentionDueShownCount;
  final int retentionCheckSetShownCount;
  final int retentionLoopClosedShownCount;
  final int retentionPrimaryCtaTappedCount;
  final int retentionNextCheckReadyCount;
  final int retentionMissedCheckCount;
  final int reminderScheduledFromRetentionCount;
  final int compellingCheckShownCount;
  final int compellingCheckSelectedCount;
  final int compellingCheckMostSpecificSelectedCount;
  final int compellingCheckAcceptedCount;
  final int realReminderPermissionRequestedCount;
  final int realReminderPermissionGrantedCount;
  final int realReminderPermissionDeniedCount;
  final int realReminderScheduledCount;
  final int realReminderCancelledCount;
  final int realReminderUnavailableCount;
  final int currentObjectiveShownCount;
  final int currentObjectivePrimaryTappedCount;
  final int currentObjectiveSecondaryTappedCount;
  final String? latestCurrentObjectiveType;
  final int proValuePreviewShownCount;
  final int proValuePreviewUnlockTappedCount;
  final int proValuePreviewDismissedCount;
  final String? latestProValuePreviewType;
  final int objectiveWidgetRefreshAttemptedCount;
  final int objectiveWidgetRefreshSucceededCount;
  final int objectiveWidgetRefreshFailedCount;
  final int objectiveWidgetClearedCount;
  final int archiveMemorySummaryShownCount;
  final int archiveMemoryOpenPatternMapTappedCount;
  final int archiveMemoryFindMomentsTappedCount;
  final int archiveMemoryUseCheckTappedCount;
  final int archiveTimelineShownCount;
  final int archiveTimelineOpenedCount;
  final int archiveTimelineUseCheckTappedCount;
  final int positioningComprehensionAskedCount;
  final int positioningComprehensionAnsweredCount;
  final int positioningUnderstoodArchiveMemoryCount;
  final int positioningJournalCount;
  final int positioningChatCount;
  final int positioningNotSureCount;

  /// Retention instrumentation rollup (interpretation, reminders, acquisition).
  final RetentionDiagnosisSnapshot? retentionDiagnosisSnapshot;

  /// TestFlight acquisition cohort assignment and wedge funnel milestones.
  final AcquisitionCohort? acquisitionCohort;

  final int capacityInviteCopiedCount;
  final int proveInviteCopiedCount;
  final int genericInviteCopiedCount;

  final int proveDefaultShownCount;
  final int proveDefaultStartedCount;
  final int proveFirstMomentRecordedCount;
  final int proveReadAcceptedCount;
  final int proveSecondMomentRecordedCount;
  final int proveReviewConfirmedCount;
  final int provePaywallTeaserTappedCount;

  /// Pass when ≥3 of 5 trial users chose archive-memory framing.
  bool get positioningComprehensionPass =>
      positioningComprehensionAnsweredCount >= 5 &&
      positioningUnderstoodArchiveMemoryCount >= 3;

  double? get positioningArchiveMemoryRate =>
      positioningComprehensionAnsweredCount == 0
      ? null
      : positioningUnderstoodArchiveMemoryCount /
            positioningComprehensionAnsweredCount;

  final int activationFullLoopCompletedCount;
  final String activationWeakestBucket;
  final bool activationSavedFirstMoment;
  final bool activationChoseTomorrowCheck;
  final bool activationReturnedNextDay;
  final bool activationClosedLoop;
  final bool activationRatedUsefulOrSortOf;
  final bool activationChoseNextCheck;

  /// The most common correction so far, or `none` when no negative type has at
  /// least two taps. Kept as a plain id for the facilitator export.
  String get archiveFeedbackDominantIssue {
    const order = ['tooGeneric', 'notMe', 'alreadyKnew', 'moreSpecific'];
    final counts = {
      'tooGeneric': archiveFeedbackTooGenericCount,
      'notMe': archiveFeedbackNotMeCount,
      'alreadyKnew': archiveFeedbackAlreadyKnewCount,
      'moreSpecific': archiveFeedbackMoreSpecificCount,
    };
    var dominant = 'none';
    var best = 0;
    for (final key in order) {
      final count = counts[key]!;
      if (count > best) {
        best = count;
        dominant = key;
      }
    }
    return best >= 2 ? dominant : 'none';
  }

  ReminderReadinessDecision get _reminderDecision => computeReminderReadiness(
    checkInCreatedCount: checkInCreatedCount,
    checkInDueShownCount: checkInDueShownCount,
    hookDiagnosis: hookDiagnosis,
  );

  /// Check-ins that were created but did not lead to a return (reminder pool).
  int get reminderCandidateCount => _reminderDecision.candidateCount;

  ReminderReadiness get reminderReadiness => _reminderDecision.readiness;

  String get reminderReadinessReason => _reminderDecision.reason;

  HookRescueDecision get _rescueDecision =>
      const HookRescueDecisionEngine().decide(this);

  /// The single best next fix for the tomorrow check-in hook.
  HookRescueAction get hookRescuePrimaryAction => _rescueDecision.primaryAction;

  List<HookRescueAction> get hookRescueSecondaryActions =>
      _rescueDecision.secondaryActions;

  String get hookRescueReason => _rescueDecision.reason;

  HookRescueConfidence get hookRescueConfidence => _rescueDecision.confidence;

  /// Escalation level for the sharper question fix.
  HookRescueIntensity get sharperQuestionIntensity =>
      _rescueDecision.intensityFor(HookRescueAction.sharperQuestion);

  /// Escalation level for the better result fix.
  HookRescueIntensity get betterResultIntensity =>
      _rescueDecision.intensityFor(HookRescueAction.betterResult);

  /// Runtime status of the reminder implementation.
  ReminderImplementationStatus get reminderImplementationStatus {
    if (reminderScheduledCount > 0) {
      return ReminderImplementationStatus.scheduled;
    }
    if (reminderDeniedCount > 0) {
      return ReminderImplementationStatus.permissionDenied;
    }
    if (reminderPluginAvailable) return ReminderImplementationStatus.available;
    return ReminderImplementationStatus.noOp;
  }

  Map<String, dynamic> toJson() => {
    if (participantId != null) 'participantId': participantId,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
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
    'appOpenedCount': appOpenedCount,
    'recordCtaTappedCount': recordCtaTappedCount,
    'recordingStartedCount': recordingStartedCount,
    'recordingSavedCount': recordingSavedCount,
    'micDeniedCount': micDeniedCount,
    'saveCompletedCount': saveCompletedCount,
    'closedBeforeWatchForAcceptedCount': closedBeforeWatchForAcceptedCount,
    'trialFrictionVerdict': trialFrictionVerdict.id,
    'checkInCreatedCount': checkInCreatedCount,
    'checkInDueShownCount': checkInDueShownCount,
    'checkInOptionSelectedCount': checkInOptionSelectedCount,
    'checkInCompletedCount': checkInCompletedCount,
    if (checkInCompletionRate != null)
      'checkInCompletionRate': checkInCompletionRate,
    if (correctionRate != null) 'correctionRate': correctionRate,
    if (watchForAcceptRate != null) 'watchForAcceptRate': watchForAcceptRate,
    if (day2ReturnRate != null) 'day2ReturnRate': day2ReturnRate,
    if (usefulRate != null) 'usefulRate': usefulRate,
    'verdict': verdict.id,
    'reminderCandidateCount': reminderCandidateCount,
    'reminderReadiness': reminderReadiness.id,
    'reminderReadinessReason': reminderReadinessReason,
    'hookRescuePrimaryAction': hookRescuePrimaryAction.id,
    'hookRescueSecondaryActions': hookRescueSecondaryActions
        .map((a) => a.id)
        .toList(),
    'hookRescueReason': hookRescueReason,
    'hookRescueConfidence': hookRescueConfidence.id,
    'sharperQuestionIntensity': sharperQuestionIntensity.id,
    'betterResultIntensity': betterResultIntensity.id,
    'reminderImplementationStatus': reminderImplementationStatus.id,
    'reminderScheduledCount': reminderScheduledCount,
    'reminderDeniedCount': reminderDeniedCount,
    'reminderPermissionRequestedCount': reminderPermissionRequestedCount,
    'reminderPermissionGrantedCount': reminderPermissionGrantedCount,
    'reminderPermissionDeniedCount': reminderPermissionDeniedCount,
    'reminderCancelledCount': reminderCancelledCount,
    'reminderTappedCount': reminderTappedCount,
    'reminderEnabled': reminderEnabled,
    'patternMemoryCreatedCount': patternMemoryCreatedCount,
    'patternMemoryUpdatedCount': patternMemoryUpdatedCount,
    'patternMemoryCheckInCount': patternMemoryCheckInCount,
    'activePatternMemoryStatus': activePatternMemoryStatus?.id,
    'patternProgressMomentCreatedCount': patternProgressMomentCreatedCount,
    'patternProgressCardShownCount': patternProgressCardShownCount,
    'latestPatternProgressType': latestPatternProgressType?.id,
    'patternNextActionCreatedCount': patternNextActionCreatedCount,
    'patternNextActionUsedCount': patternNextActionUsedCount,
    'latestPatternNextActionType': latestPatternNextActionType?.id,
    'habitProofCreatedCount': habitProofCreatedCount,
    'habitProofShownCount': habitProofShownCount,
    'habitProofCtaTappedCount': habitProofCtaTappedCount,
    'latestHabitProofType': latestHabitProofType?.id,
    'weeklyPatternRecapCreatedCount': weeklyPatternRecapCreatedCount,
    'weeklyPatternRecapShownCount': weeklyPatternRecapShownCount,
    'weeklyPatternRecapCtaTappedCount': weeklyPatternRecapCtaTappedCount,
    'latestWeeklyPatternRecapType': latestWeeklyPatternRecapType?.id,
    'patternShareCardShownCount': patternShareCardShownCount,
    'patternShareCopiedCount': patternShareCopiedCount,
    'patternShareOpenedCount': patternShareOpenedCount,
    'patternShareFailedCount': patternShareFailedCount,
    'firstLoopStage': firstLoopStage.id,
    'firstLoopCompleted': firstLoopCompleted,
    if (secondsToFirstSave != null) 'secondsToFirstSave': secondsToFirstSave,
    if (secondsToLoopReady != null) 'secondsToLoopReady': secondsToLoopReady,
    'firstLoopDropoffPoint': firstLoopDropoffPoint.id,
    'returnDayDueShownCount': returnDayDueShownCount,
    'returnDayAnswerSelectedCount': returnDayAnswerSelectedCount,
    'returnDayLoopClosedCount': returnDayLoopClosedCount,
    if (latestSecondsToAnswer != null)
      'latestSecondsToAnswer': latestSecondsToAnswer,
    if (latestSecondsToLoopClosed != null)
      'latestSecondsToLoopClosed': latestSecondsToLoopClosed,
    if (returnDayCompletionRate != null)
      'returnDayCompletionRate': returnDayCompletionRate,
    'returnDayDropoffPoint': returnDayDropoffPoint.id,
    'sharperQuestionGeneratedCount': sharperQuestionGeneratedCount,
    'verySharpQuestionGeneratedCount': verySharpQuestionGeneratedCount,
    'sharperQuestionAcceptedCount': sharperQuestionAcceptedCount,
    'verySharpQuestionAcceptedCount': verySharpQuestionAcceptedCount,
    'betterResultShownCount': betterResultShownCount,
    'aggressiveBetterResultShownCount': aggressiveBetterResultShownCount,
    'checkInGoDeeperShownCount': checkInGoDeeperShownCount,
    'checkInGoDeeperTappedCount': checkInGoDeeperTappedCount,
    'resultNextCheckShownCount': resultNextCheckShownCount,
    'resultNextCheckUsedCount': resultNextCheckUsedCount,
    'resultNextCheckChangedCount': resultNextCheckChangedCount,
    'resultNextCheckUsedFromPatternsCount':
        resultNextCheckUsedFromPatternsCount,
    'usefulResultTakeawayShownCount': usefulResultTakeawayShownCount,
    'makeResultMoreUsefulTappedCount': makeResultMoreUsefulTappedCount,
    'makeResultMoreUsefulReasonSelectedCount':
        makeResultMoreUsefulReasonSelectedCount,
    'usefulResultNextCheckUsedCount': usefulResultNextCheckUsedCount,
    'inputQualityCoachShownCount': inputQualityCoachShownCount,
    'inputQualitySentenceAddedCount': inputQualitySentenceAddedCount,
    'inputQualityUsedAnywayCount': inputQualityUsedAnywayCount,
    'acceptedWeakInputCount': acceptedWeakInputCount,
    'sharpenedInputCount': sharpenedInputCount,
    if (latestInputQualityLevel != null)
      'latestInputQualityLevel': latestInputQualityLevel,
    if (averageInputQualityScore != null)
      'averageInputQualityScore': averageInputQualityScore,
    'perspectiveShiftShownCount': perspectiveShiftShownCount,
    'perspectiveShiftChangedCount': perspectiveShiftChangedCount,
    'perspectiveShiftUsedCount': perspectiveShiftUsedCount,
    'perspectiveShiftShownFromPatternsCount':
        perspectiveShiftShownFromPatternsCount,
    'perspectiveShiftUsedFromPatternsCount':
        perspectiveShiftUsedFromPatternsCount,
    'kinderAngleShownCount': kinderAngleShownCount,
    'kinderAngleUsedCount': kinderAngleUsedCount,
    'kinderAngleChangedCount': kinderAngleChangedCount,
    'kinderAngleShownFromPatternsCount': kinderAngleShownFromPatternsCount,
    'kinderAngleUsedFromPatternsCount': kinderAngleUsedFromPatternsCount,
    'quickHelpOpenedCount': quickHelpOpenedCount,
    'quickHelpIntentSelectedCount': quickHelpIntentSelectedCount,
    'quickHelpPrimaryActionTappedCount': quickHelpPrimaryActionTappedCount,
    'quickHelpCheckUsedCount': quickHelpCheckUsedCount,
    'keyMomentCreatedCount': keyMomentCreatedCount,
    'keyMomentOpenedCount': keyMomentOpenedCount,
    'keyMomentSearchUsedCount': keyMomentSearchUsedCount,
    'keyMomentUseCheckTappedCount': keyMomentUseCheckTappedCount,
    'askArchiveOpenedCount': askArchiveOpenedCount,
    'askArchiveSearchUsedCount': askArchiveSearchUsedCount,
    'askArchiveSuggestedChipTappedCount': askArchiveSuggestedChipTappedCount,
    'askArchiveResultOpenedCount': askArchiveResultOpenedCount,
    'askArchiveUseCheckTappedCount': askArchiveUseCheckTappedCount,
    'archiveCleanViewShownCount': archiveCleanViewShownCount,
    'archiveCleanSectionTappedCount': archiveCleanSectionTappedCount,
    'patternProfileShownCount': patternProfileShownCount,
    'patternProfileOpenedCount': patternProfileOpenedCount,
    'patternProfileUseCheckTappedCount': patternProfileUseCheckTappedCount,
    'patternProfileFindMomentsTappedCount':
        patternProfileFindMomentsTappedCount,
    'patternProfileOpenTimelineTappedCount':
        patternProfileOpenTimelineTappedCount,
    'patternMapShownCount': patternMapShownCount,
    'patternMapOpenedCount': patternMapOpenedCount,
    'patternMapUseCheckTappedCount': patternMapUseCheckTappedCount,
    'archiveFeedbackShownCount': archiveFeedbackShownCount,
    'archiveFeedbackSelectedCount': archiveFeedbackSelectedCount,
    'archiveFeedbackUsefulCount': archiveFeedbackUsefulCount,
    'archiveFeedbackTooGenericCount': archiveFeedbackTooGenericCount,
    'archiveFeedbackNotMeCount': archiveFeedbackNotMeCount,
    'archiveFeedbackAlreadyKnewCount': archiveFeedbackAlreadyKnewCount,
    'archiveFeedbackMoreSpecificCount': archiveFeedbackMoreSpecificCount,
    'archiveFeedbackDominantIssue': archiveFeedbackDominantIssue,
    'archiveCompressionShownCount': archiveCompressionShownCount,
    'archiveCompressionOpenedCount': archiveCompressionOpenedCount,
    'archiveCompressionKeptCount': archiveCompressionKeptCount,
    'archiveCompressionSplitCount': archiveCompressionSplitCount,
    'archiveCompressionHiddenCount': archiveCompressionHiddenCount,
    'memoryQualityShownCount': memoryQualityShownCount,
    'memoryQualityTappedCount': memoryQualityTappedCount,
    if (latestMemoryQualityLevel != null)
      'latestMemoryQualityLevel': latestMemoryQualityLevel,
    'paywallShownCount': paywallShownCount,
    'paywallTriggerShownCount': paywallTriggerShownCount,
    'annualPlanShownCount': annualPlanShownCount,
    'monthlyPlanShownCount': monthlyPlanShownCount,
    'annualPlanSelectedCount': annualPlanSelectedCount,
    'monthlyPlanSelectedCount': monthlyPlanSelectedCount,
    'paywallContinueTappedCount': paywallContinueTappedCount,
    'paywallDismissedCount': paywallDismissedCount,
    'restoreTappedCount': restoreTappedCount,
    'archiveRangeReviewShownCount': archiveRangeReviewShownCount,
    'archiveRangeReviewOpenedCount': archiveRangeReviewOpenedCount,
    'archiveRangeReviewUseCheckTappedCount':
        archiveRangeReviewUseCheckTappedCount,
    'archiveRangeReviewPresetChangedCount':
        archiveRangeReviewPresetChangedCount,
    'retentionStateShownCount': retentionStateShownCount,
    'retentionDueShownCount': retentionDueShownCount,
    'retentionCheckSetShownCount': retentionCheckSetShownCount,
    'retentionLoopClosedShownCount': retentionLoopClosedShownCount,
    'retentionPrimaryCtaTappedCount': retentionPrimaryCtaTappedCount,
    'retentionNextCheckReadyCount': retentionNextCheckReadyCount,
    'retentionMissedCheckCount': retentionMissedCheckCount,
    'reminderScheduledFromRetentionCount': reminderScheduledFromRetentionCount,
    'compellingCheckShownCount': compellingCheckShownCount,
    'compellingCheckSelectedCount': compellingCheckSelectedCount,
    'compellingCheckMostSpecificSelectedCount':
        compellingCheckMostSpecificSelectedCount,
    'compellingCheckAcceptedCount': compellingCheckAcceptedCount,
    'realReminderPermissionRequestedCount':
        realReminderPermissionRequestedCount,
    'realReminderPermissionGrantedCount': realReminderPermissionGrantedCount,
    'realReminderPermissionDeniedCount': realReminderPermissionDeniedCount,
    'realReminderScheduledCount': realReminderScheduledCount,
    'realReminderCancelledCount': realReminderCancelledCount,
    'realReminderUnavailableCount': realReminderUnavailableCount,
    'currentObjectiveShownCount': currentObjectiveShownCount,
    'currentObjectivePrimaryTappedCount': currentObjectivePrimaryTappedCount,
    'currentObjectiveSecondaryTappedCount':
        currentObjectiveSecondaryTappedCount,
    'latestCurrentObjectiveType': latestCurrentObjectiveType,
    'proValuePreviewShownCount': proValuePreviewShownCount,
    'proValuePreviewUnlockTappedCount': proValuePreviewUnlockTappedCount,
    'proValuePreviewDismissedCount': proValuePreviewDismissedCount,
    'latestProValuePreviewType': latestProValuePreviewType,
    'objectiveWidgetRefreshAttemptedCount':
        objectiveWidgetRefreshAttemptedCount,
    'objectiveWidgetRefreshSucceededCount':
        objectiveWidgetRefreshSucceededCount,
    'objectiveWidgetRefreshFailedCount': objectiveWidgetRefreshFailedCount,
    'objectiveWidgetClearedCount': objectiveWidgetClearedCount,
    'archiveMemorySummaryShownCount': archiveMemorySummaryShownCount,
    'archiveMemoryOpenPatternMapTappedCount':
        archiveMemoryOpenPatternMapTappedCount,
    'archiveMemoryFindMomentsTappedCount': archiveMemoryFindMomentsTappedCount,
    'archiveMemoryUseCheckTappedCount': archiveMemoryUseCheckTappedCount,
    'archiveTimelineShownCount': archiveTimelineShownCount,
    'archiveTimelineOpenedCount': archiveTimelineOpenedCount,
    'archiveTimelineUseCheckTappedCount': archiveTimelineUseCheckTappedCount,
    'positioningComprehensionAskedCount': positioningComprehensionAskedCount,
    'positioningComprehensionAnsweredCount':
        positioningComprehensionAnsweredCount,
    'positioningUnderstoodArchiveMemoryCount':
        positioningUnderstoodArchiveMemoryCount,
    'positioningJournalCount': positioningJournalCount,
    'positioningChatCount': positioningChatCount,
    'positioningNotSureCount': positioningNotSureCount,
    'positioningComprehensionPass': positioningComprehensionPass,
    if (positioningArchiveMemoryRate != null)
      'positioningArchiveMemoryRate': positioningArchiveMemoryRate,
    'activationFullLoopCompletedCount': activationFullLoopCompletedCount,
    'activationWeakestBucket': activationWeakestBucket,
    'activationSavedFirstMoment': activationSavedFirstMoment,
    'activationChoseTomorrowCheck': activationChoseTomorrowCheck,
    'activationReturnedNextDay': activationReturnedNextDay,
    'activationClosedLoop': activationClosedLoop,
    'activationRatedUsefulOrSortOf': activationRatedUsefulOrSortOf,
    'activationChoseNextCheck': activationChoseNextCheck,
    'hookDiagnosis': {
      'likelyFailure': hookDiagnosis.likelyFailure,
      'checkInCompletionRate': hookDiagnosis.checkInCompletionRate,
      'checkInQuestionRatedUseful': hookDiagnosis.checkInQuestionRatedUseful,
      'checkInQuestionRatedSortOf': hookDiagnosis.checkInQuestionRatedSortOf,
      'checkInQuestionRatedNotUseful':
          hookDiagnosis.checkInQuestionRatedNotUseful,
      'resultUsefulCount': hookDiagnosis.resultUsefulCount,
      'resultSortOfCount': hookDiagnosis.resultSortOfCount,
      'resultNotUsefulCount': hookDiagnosis.resultNotUsefulCount,
      'forgotCount': hookDiagnosis.forgotCount,
      'didNotCareCount': hookDiagnosis.didNotCareCount,
      'confusingCount': hookDiagnosis.confusingCount,
      'didNotReturnReasonCounts': hookDiagnosis.didNotReturnReasonCounts,
      'examplesOpenedCount': hookDiagnosis.examplesOpenedCount,
      'checkInClarityCardShownCount':
          hookDiagnosis.checkInClarityCardShownCount,
      'checkInMomentRecordedCount': hookDiagnosis.checkInMomentRecordedCount,
      'notUsefulReasonCounts': hookDiagnosis.notUsefulReasonCounts,
      if (hookDiagnosis.clarityIssueRate != null)
        'clarityIssueRate': hookDiagnosis.clarityIssueRate,
    },
    if (retentionDiagnosisSnapshot != null)
      'retentionDiagnosisSnapshot': retentionDiagnosisSnapshot!.toJson(),
    if (acquisitionCohort != null)
      'acquisitionCohort': acquisitionCohort!.toJson(),
    'capacityInviteCopiedCount': capacityInviteCopiedCount,
    'proveInviteCopiedCount': proveInviteCopiedCount,
    'genericInviteCopiedCount': genericInviteCopiedCount,
    'proveDefaultShownCount': proveDefaultShownCount,
    'proveDefaultStartedCount': proveDefaultStartedCount,
    'proveFirstMomentRecordedCount': proveFirstMomentRecordedCount,
    'proveReadAcceptedCount': proveReadAcceptedCount,
    'proveSecondMomentRecordedCount': proveSecondMomentRecordedCount,
    'proveReviewConfirmedCount': proveReviewConfirmedCount,
    'provePaywallTeaserTappedCount': provePaywallTeaserTappedCount,
  };
}