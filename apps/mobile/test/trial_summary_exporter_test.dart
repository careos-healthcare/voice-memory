import 'package:archiveme_mobile/features/trial/hook_diagnosis_model.dart';
import 'package:archiveme_mobile/features/trial/hook_rescue_decision_model.dart';
import 'package:archiveme_mobile/features/trial/trial_summary_exporter.dart';
import 'package:archiveme_mobile/features/trial/trial_summary_model.dart';
import 'package:flutter_test/flutter_test.dart';

HookDiagnosisSummary _emptyDiagnosis() => buildHookDiagnosisSummary(
  events: const [],
  checkInsCreated: 0,
  checkInsDueShown: 0,
  checkInsCompleted: 0,
);

void main() {
  test('markdown includes metrics and verdict', () {
    final summary = TrialSummaryModel(
      participantId: 'user-3',
      generatedAt: DateTime(2026, 5, 26, 10),
      firstReflectionSaved: 1,
      firstPatternShown: 1,
      firstPatternAccepted: 1,
      firstPatternCorrected: 0,
      watchForPromptShown: 1,
      watchForPromptAccepted: 1,
      returnCaptureQuickAnswerSelected: 1,
      returnedNextDay: 1,
      secondReflectionSaved: 1,
      comparisonViewed: 1,
      usefulnessYes: 1,
      usefulnessSortOf: 0,
      usefulnessNotReally: 0,
      thirdReflectionSaved: 0,
      appOpenedCount: 2,
      recordCtaTappedCount: 1,
      recordingStartedCount: 1,
      recordingSavedCount: 1,
      micDeniedCount: 0,
      saveCompletedCount: 1,
      closedBeforeWatchForAcceptedCount: 0,
      trialFrictionVerdict: TrialFrictionVerdict.clean,
      checkInCreatedCount: 1,
      checkInDueShownCount: 1,
      checkInOptionSelectedCount: 1,
      checkInCompletedCount: 1,
      checkInCompletionRate: 1,
      correctionRate: 0,
      watchForAcceptRate: 1,
      day2ReturnRate: 1,
      usefulRate: 1,
      verdict: TrialSummaryVerdict.promising,
      hookDiagnosis: _emptyDiagnosis(),
    );

    final md = const TrialSummaryExporter().toMarkdown(summary);
    expect(md, contains('user-3'));
    expect(md, contains('promising'));
    expect(md, contains('First reflection saved'));
    expect(md, contains('Watch-for accept rate'));
    expect(md, contains('Trial friction'));
    expect(md, contains('Friction verdict'));
    expect(md, contains('App opened'));
    expect(md, contains('Tomorrow check-in'));
    expect(md, contains('Hook diagnosis'));
    expect(md, contains('Likely failure'));
    expect(md, contains('Check-in completion rate'));
    expect(md, contains('Examples opened'));
    expect(md, contains('Clarity issue rate'));
    expect(md, contains('## Reminder readiness'));
    expect(md, contains('**Status:**'));
    expect(md, contains('**Reason:**'));
    expect(md, contains('- Enabled:'));
    expect(md, contains('- Permission requested:'));
    expect(md, contains('- Permission granted:'));
    expect(md, contains('- Permission denied:'));
    expect(md, contains('- Scheduled:'));
    expect(md, contains('- Cancelled:'));
    expect(md, contains('- Tapped:'));
    expect(md, contains('## Recommended next fix'));
    expect(md, contains('**Primary action:**'));
    expect(md, contains('**Confidence:**'));
    expect(md, contains('## Hook escalation'));
    expect(md, contains('- Sharper question:'));
    expect(md, contains('- Better result:'));
    expect(md, contains('- Reminder:'));
    expect(md, contains('## Pattern memory'));
    expect(md, contains('- Check-ins:'));
    expect(md, contains('## Pattern progress'));
    expect(md, contains('- Latest type:'));
    expect(md, contains('- Moments created:'));
    expect(md, contains('## Pattern next action'));
    expect(md, contains('- Actions created:'));
    expect(md, contains('- Actions used:'));
    expect(md, contains('## Habit proof'));
    expect(md, contains('- Proofs created:'));
    expect(md, contains('- CTA tapped:'));
    expect(md, contains('## Weekly pattern recap'));
    expect(md, contains('- Recaps created:'));
    expect(md, contains('## Pattern share'));
    expect(md, contains('- Copied:'));
    expect(md, contains('## Activation loop'));
    expect(md, contains('| First moment |'));
    expect(md, contains('**Weakest bucket:**'));
    expect(md, contains('## First loop'));
    expect(md, contains('- Stage:'));
    expect(md, contains('- Dropoff point:'));
    expect(md, contains('## Next useful check'));
    expect(md, contains('- Used from Patterns:'));
    expect(md, contains('## Useful result rescue'));
    expect(md, contains('- Takeaway shown:'));
    expect(md, contains('- Make more useful tapped:'));
    expect(md, contains('## Input quality coach'));
    expect(md, contains('- Coach shown:'));
    expect(md, contains('- Sentence added:'));
    expect(md, contains('- Used anyway:'));
    expect(md, contains('- Latest level:'));
    expect(md, contains('- Average score:'));
    expect(md, contains('## Another perspective'));
    expect(md, contains('- Shown:'));
    expect(md, contains('- Changed:'));
    expect(md, contains('- Used:'));
    expect(md, contains('## Kinder angle'));
    expect(md, contains('## Quick help'));
    expect(md, contains('## Key moments'));
    expect(md, contains('## Pattern map'));
    expect(md, contains('## Feedback'));
    expect(md, contains('## What ArchiveMe remembers'));
    expect(md, contains('## Pattern timeline'));
    expect(md, contains('## Positioning comprehension'));
    expect(md, contains('- Understood archive memory:'));
    expect(md, contains('- Pass (≥3/5 archive memory):'));

    final json = const TrialSummaryExporter().toJson(summary);
    expect(json, contains('"participantId": "user-3"'));
    expect(json, contains('"notUsefulReasonCounts"'));
    expect(json, contains('"trialFrictionVerdict"'));
    expect(json, contains('"appOpenedCount"'));
    expect(json, contains('"reminderReadiness"'));
    expect(json, contains('"reminderReadinessReason"'));
    expect(json, contains('"hookRescuePrimaryAction"'));
    expect(json, contains('"hookRescueReason"'));
    expect(json, contains('"hookRescueConfidence"'));
    expect(json, contains('"sharperQuestionIntensity"'));
    expect(json, contains('"betterResultIntensity"'));
    expect(json, contains('"reminderImplementationStatus"'));
    expect(json, contains('"reminderEnabled"'));
    expect(json, contains('"reminderPermissionRequestedCount"'));
    expect(json, contains('"reminderPermissionGrantedCount"'));
    expect(json, contains('"reminderPermissionDeniedCount"'));
    expect(json, contains('"reminderCancelledCount"'));
    expect(json, contains('"reminderTappedCount"'));
    expect(json, contains('"patternMemoryCreatedCount"'));
    expect(json, contains('"patternMemoryCheckInCount"'));
    expect(json, contains('"patternProgressMomentCreatedCount"'));
    expect(json, contains('"patternProgressCardShownCount"'));
    expect(json, contains('"latestPatternProgressType"'));
    expect(json, contains('"patternNextActionCreatedCount"'));
    expect(json, contains('"patternNextActionUsedCount"'));
    expect(json, contains('"latestPatternNextActionType"'));
    expect(json, contains('"habitProofCreatedCount"'));
    expect(json, contains('"habitProofShownCount"'));
    expect(json, contains('"habitProofCtaTappedCount"'));
    expect(json, contains('"latestHabitProofType"'));
    expect(json, contains('"weeklyPatternRecapCreatedCount"'));
    expect(json, contains('"weeklyPatternRecapShownCount"'));
    expect(json, contains('"weeklyPatternRecapCtaTappedCount"'));
    expect(json, contains('"latestWeeklyPatternRecapType"'));
    expect(json, contains('"patternShareCardShownCount"'));
    expect(json, contains('"patternShareCopiedCount"'));
    expect(json, contains('"patternShareOpenedCount"'));
    expect(json, contains('"patternShareFailedCount"'));
    expect(json, contains('"firstLoopStage"'));
    expect(json, contains('"firstLoopCompleted"'));
    expect(json, contains('"firstLoopDropoffPoint"'));
    expect(json, contains('"resultNextCheckShownCount"'));
    expect(json, contains('"resultNextCheckUsedCount"'));
    expect(json, contains('"resultNextCheckChangedCount"'));
    expect(json, contains('"resultNextCheckUsedFromPatternsCount"'));
    expect(json, contains('"usefulResultTakeawayShownCount"'));
    expect(json, contains('"makeResultMoreUsefulTappedCount"'));
    expect(json, contains('"makeResultMoreUsefulReasonSelectedCount"'));
    expect(json, contains('"usefulResultNextCheckUsedCount"'));
    expect(json, contains('"inputQualityCoachShownCount"'));
    expect(json, contains('"inputQualitySentenceAddedCount"'));
    expect(json, contains('"inputQualityUsedAnywayCount"'));
    expect(json, contains('"acceptedWeakInputCount"'));
    expect(json, contains('"sharpenedInputCount"'));
    expect(json, contains('"perspectiveShiftShownCount"'));
    expect(json, contains('"perspectiveShiftChangedCount"'));
    expect(json, contains('"perspectiveShiftUsedCount"'));
    expect(json, contains('"perspectiveShiftShownFromPatternsCount"'));
    expect(json, contains('"perspectiveShiftUsedFromPatternsCount"'));
    expect(json, contains('"kinderAngleShownCount"'));
    expect(json, contains('"kinderAngleUsedCount"'));
    expect(json, contains('"kinderAngleChangedCount"'));
    expect(json, contains('"kinderAngleShownFromPatternsCount"'));
    expect(json, contains('"kinderAngleUsedFromPatternsCount"'));
    expect(json, contains('"quickHelpOpenedCount"'));
    expect(json, contains('"quickHelpIntentSelectedCount"'));
    expect(json, contains('"quickHelpPrimaryActionTappedCount"'));
    expect(json, contains('"quickHelpCheckUsedCount"'));
    expect(json, contains('"keyMomentCreatedCount"'));
    expect(json, contains('"keyMomentOpenedCount"'));
    expect(json, contains('"keyMomentSearchUsedCount"'));
    expect(json, contains('"keyMomentUseCheckTappedCount"'));
    expect(json, contains('"askArchiveOpenedCount"'));
    expect(json, contains('"askArchiveSearchUsedCount"'));
    expect(json, contains('"askArchiveSuggestedChipTappedCount"'));
    expect(json, contains('"askArchiveResultOpenedCount"'));
    expect(json, contains('"askArchiveUseCheckTappedCount"'));
    expect(json, contains('"archiveCleanViewShownCount"'));
    expect(json, contains('"archiveCleanSectionTappedCount"'));
    expect(json, contains('"patternProfileShownCount"'));
    expect(json, contains('"patternProfileOpenedCount"'));
    expect(json, contains('"patternProfileUseCheckTappedCount"'));
    expect(json, contains('"patternProfileFindMomentsTappedCount"'));
    expect(json, contains('"patternProfileOpenTimelineTappedCount"'));
    expect(json, contains('"patternMapShownCount"'));
    expect(json, contains('"patternMapOpenedCount"'));
    expect(json, contains('"patternMapUseCheckTappedCount"'));
    expect(json, contains('"archiveFeedbackShownCount"'));
    expect(json, contains('"archiveFeedbackSelectedCount"'));
    expect(json, contains('"archiveFeedbackDominantIssue"'));
    expect(json, contains('"archiveCompressionShownCount"'));
    expect(json, contains('"archiveCompressionKeptCount"'));
    expect(json, contains('"memoryQualityShownCount"'));
    expect(json, contains('"memoryQualityTappedCount"'));
    expect(json, contains('"archiveMemorySummaryShownCount"'));
    expect(json, contains('"archiveMemoryOpenPatternMapTappedCount"'));
    expect(json, contains('"archiveMemoryFindMomentsTappedCount"'));
    expect(json, contains('"archiveMemoryUseCheckTappedCount"'));
    expect(json, contains('"archiveTimelineShownCount"'));
    expect(json, contains('"archiveTimelineOpenedCount"'));
    expect(json, contains('"archiveTimelineUseCheckTappedCount"'));
    expect(json, contains('"retentionStateShownCount"'));
    expect(json, contains('"retentionDueShownCount"'));
    expect(json, contains('"retentionCheckSetShownCount"'));
    expect(json, contains('"retentionLoopClosedShownCount"'));
    expect(json, contains('"retentionPrimaryCtaTappedCount"'));
    expect(json, contains('"retentionNextCheckReadyCount"'));
    expect(json, contains('"retentionMissedCheckCount"'));
    expect(json, contains('"reminderScheduledFromRetentionCount"'));
    expect(json, contains('"compellingCheckShownCount"'));
    expect(json, contains('"compellingCheckAcceptedCount"'));
    expect(json, contains('"realReminderScheduledCount"'));
    expect(json, contains('"realReminderUnavailableCount"'));
    expect(json, contains('"currentObjectiveShownCount"'));
    expect(json, contains('"latestCurrentObjectiveType"'));
    expect(json, contains('"proValuePreviewShownCount"'));
    expect(json, contains('"latestProValuePreviewType"'));
    expect(json, contains('"objectiveWidgetRefreshAttemptedCount"'));
    expect(json, contains('"objectiveWidgetClearedCount"'));
  });

  test('exporter recommends sharper fix when did-not-care high', () {
    final diagnosis = buildHookDiagnosisSummary(
      events: [
        HookDiagnosisEvent(
          id: 'd1',
          createdAt: DateTime(2026, 5, 26),
          type: HookDiagnosisEventType.checkInMissedReason,
          reason: HookDiagnosisMissedReason.didNotCare,
        ),
        HookDiagnosisEvent(
          id: 'd2',
          createdAt: DateTime(2026, 5, 26),
          type: HookDiagnosisEventType.checkInMissedReason,
          reason: HookDiagnosisMissedReason.didNotCare,
        ),
      ],
      checkInsCreated: 2,
      checkInsDueShown: 2,
      checkInsCompleted: 0,
    );
    final summary = TrialSummaryModel(
      generatedAt: DateTime(2026, 5, 26),
      firstReflectionSaved: 1,
      firstPatternShown: 1,
      firstPatternAccepted: 1,
      firstPatternCorrected: 0,
      watchForPromptShown: 1,
      watchForPromptAccepted: 1,
      returnCaptureQuickAnswerSelected: 0,
      returnedNextDay: 0,
      secondReflectionSaved: 0,
      comparisonViewed: 0,
      usefulnessYes: 0,
      usefulnessSortOf: 0,
      usefulnessNotReally: 0,
      thirdReflectionSaved: 0,
      appOpenedCount: 0,
      recordCtaTappedCount: 0,
      recordingStartedCount: 0,
      recordingSavedCount: 1,
      micDeniedCount: 0,
      saveCompletedCount: 1,
      closedBeforeWatchForAcceptedCount: 0,
      trialFrictionVerdict: TrialFrictionVerdict.clean,
      checkInCreatedCount: 2,
      checkInDueShownCount: 2,
      checkInOptionSelectedCount: 0,
      checkInCompletedCount: 0,
      verdict: TrialSummaryVerdict.unclear,
      hookDiagnosis: diagnosis,
    );

    expect(summary.hookRescuePrimaryAction.id, 'sharperQuestion');
    final md = const TrialSummaryExporter().toMarkdown(summary);
    expect(md, contains('**Primary action:** sharperQuestion'));
    expect(md, contains('People do not care enough about the question.'));
  });

  test('markdown reminder readiness reflects ready signal', () {
    final diagnosis = buildHookDiagnosisSummary(
      events: [
        HookDiagnosisEvent(
          id: '1',
          createdAt: DateTime(2026, 5, 26),
          type: HookDiagnosisEventType.checkInQuestionRated,
          rating: HookDiagnosisRating.yes,
        ),
        HookDiagnosisEvent(
          id: '2',
          createdAt: DateTime(2026, 5, 26),
          type: HookDiagnosisEventType.checkInQuestionRated,
          rating: HookDiagnosisRating.sortOf,
        ),
      ],
      checkInsCreated: 2,
      checkInsDueShown: 0,
      checkInsCompleted: 0,
    );
    final summary = TrialSummaryModel(
      generatedAt: DateTime(2026, 5, 26),
      firstReflectionSaved: 1,
      firstPatternShown: 1,
      firstPatternAccepted: 1,
      firstPatternCorrected: 0,
      watchForPromptShown: 1,
      watchForPromptAccepted: 1,
      returnCaptureQuickAnswerSelected: 0,
      returnedNextDay: 0,
      secondReflectionSaved: 0,
      comparisonViewed: 0,
      usefulnessYes: 0,
      usefulnessSortOf: 0,
      usefulnessNotReally: 0,
      thirdReflectionSaved: 0,
      appOpenedCount: 0,
      recordCtaTappedCount: 0,
      recordingStartedCount: 0,
      recordingSavedCount: 1,
      micDeniedCount: 0,
      saveCompletedCount: 1,
      closedBeforeWatchForAcceptedCount: 0,
      trialFrictionVerdict: TrialFrictionVerdict.clean,
      checkInCreatedCount: 2,
      checkInDueShownCount: 0,
      checkInOptionSelectedCount: 0,
      checkInCompletedCount: 0,
      verdict: TrialSummaryVerdict.unclear,
      hookDiagnosis: diagnosis,
    );
    expect(summary.reminderReadiness, ReminderReadiness.ready);
    final md = const TrialSummaryExporter().toMarkdown(summary);
    expect(md, contains('**Status:** ready'));
    expect(md, contains('worth testing'));
  });

  test('markdown includes not-useful reason counts', () {
    final diagnosis = buildHookDiagnosisSummary(
      events: [
        HookDiagnosisEvent(
          id: '1',
          createdAt: DateTime(2026, 5, 26),
          type: HookDiagnosisEventType.checkInResultNotUsefulReason,
          reason: HookDiagnosisNotUsefulReason.tooVague,
        ),
      ],
      checkInsCreated: 1,
      checkInsDueShown: 1,
      checkInsCompleted: 1,
    );
    final summary = TrialSummaryModel(
      participantId: 'p2',
      generatedAt: DateTime(2026, 5, 26),
      firstReflectionSaved: 1,
      firstPatternShown: 1,
      firstPatternAccepted: 1,
      firstPatternCorrected: 0,
      watchForPromptShown: 1,
      watchForPromptAccepted: 1,
      returnCaptureQuickAnswerSelected: 0,
      returnedNextDay: 1,
      secondReflectionSaved: 1,
      comparisonViewed: 0,
      usefulnessYes: 0,
      usefulnessSortOf: 0,
      usefulnessNotReally: 0,
      thirdReflectionSaved: 0,
      appOpenedCount: 0,
      recordCtaTappedCount: 0,
      recordingStartedCount: 0,
      recordingSavedCount: 1,
      micDeniedCount: 0,
      saveCompletedCount: 1,
      closedBeforeWatchForAcceptedCount: 0,
      trialFrictionVerdict: TrialFrictionVerdict.clean,
      checkInCreatedCount: 1,
      checkInDueShownCount: 1,
      checkInOptionSelectedCount: 1,
      checkInCompletedCount: 1,
      checkInCompletionRate: 1,
      verdict: TrialSummaryVerdict.unclear,
      hookDiagnosis: diagnosis,
    );
    final md = const TrialSummaryExporter().toMarkdown(summary);
    expect(md, contains('Too vague'));
    expect(md, contains('| Too vague | 1 |'));
  });

  test('export copied event field exists in model json', () {
    final summary = TrialSummaryModel(
      generatedAt: DateTime(2026, 5, 26),
      firstReflectionSaved: 0,
      firstPatternShown: 0,
      firstPatternAccepted: 0,
      firstPatternCorrected: 0,
      watchForPromptShown: 0,
      watchForPromptAccepted: 0,
      returnCaptureQuickAnswerSelected: 0,
      returnedNextDay: 0,
      secondReflectionSaved: 0,
      comparisonViewed: 0,
      usefulnessYes: 0,
      usefulnessSortOf: 0,
      usefulnessNotReally: 0,
      thirdReflectionSaved: 0,
      appOpenedCount: 0,
      recordCtaTappedCount: 0,
      recordingStartedCount: 0,
      recordingSavedCount: 0,
      micDeniedCount: 0,
      saveCompletedCount: 0,
      closedBeforeWatchForAcceptedCount: 0,
      trialFrictionVerdict: TrialFrictionVerdict.unclear,
      checkInCreatedCount: 0,
      checkInDueShownCount: 0,
      checkInOptionSelectedCount: 0,
      checkInCompletedCount: 0,
      verdict: TrialSummaryVerdict.unclear,
      hookDiagnosis: _emptyDiagnosis(),
    );
    expect(summary.toJson(), isNot(contains('trialExportCopied')));
  });
}