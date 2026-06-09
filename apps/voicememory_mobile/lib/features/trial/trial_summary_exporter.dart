import 'dart:convert';

import '../activation/first_loop_activation_model.dart';
import '../pattern_memory/habit_proof_model.dart';
import '../pattern_memory/pattern_memory_model.dart';
import '../pattern_memory/pattern_next_action_model.dart';
import '../pattern_memory/pattern_progress_model.dart';
import '../pattern_memory/weekly_pattern_recap_model.dart';
import 'hook_diagnosis_model.dart';
import 'hook_rescue_decision_model.dart';
import '../acquisition/acquisition_cohort_model.dart';
import '../acquisition/acquisition_intent_model.dart';
import 'trial_summary_model.dart';

/// Exports [TrialSummaryModel] for facilitator handoff.
class TrialSummaryExporter {
  const TrialSummaryExporter();

  String toJson(TrialSummaryModel summary) {
    return const JsonEncoder.withIndent('  ').convert(summary.toJson());
  }

  String toMarkdown(TrialSummaryModel summary) {
    final participant = summary.participantId?.trim().isNotEmpty == true
        ? summary.participantId!
        : '—';
    final pct = (double? rate) =>
        rate == null ? '—' : '${(rate * 100).toStringAsFixed(0)}%';

    return '''
# ArchiveMe trial summary

**Participant:** $participant  
**Generated:** ${summary.generatedAt.toIso8601String()}  
**Verdict:** ${summary.verdict.id}

## Metrics

| Metric | Count |
|--------|------:|
| First reflection saved | ${summary.firstReflectionSaved} |
| First pattern shown | ${summary.firstPatternShown} |
| First pattern accepted | ${summary.firstPatternAccepted} |
| First pattern corrected | ${summary.firstPatternCorrected} |
| Watch-for prompt shown | ${summary.watchForPromptShown} |
| Watch-for prompt accepted | ${summary.watchForPromptAccepted} |
| Return quick answer selected | ${summary.returnCaptureQuickAnswerSelected} |
| Returned next day | ${summary.returnedNextDay} |
| Second reflection saved | ${summary.secondReflectionSaved} |
| Comparison viewed | ${summary.comparisonViewed} |
| Useful — yes | ${summary.usefulnessYes} |
| Useful — sort of | ${summary.usefulnessSortOf} |
| Useful — not really | ${summary.usefulnessNotReally} |
| Third reflection saved | ${summary.thirdReflectionSaved} |

## Trial friction

| Metric | Count |
|--------|------:|
| App opened | ${summary.appOpenedCount} |
| Record CTA tapped | ${summary.recordCtaTappedCount} |
| Recording started | ${summary.recordingStartedCount} |
| Reflections saved (milestones) | ${summary.recordingSavedCount} |
| Mic denied | ${summary.micDeniedCount} |
| Save completed | ${summary.saveCompletedCount} |
| Closed before watch-for accepted | ${summary.closedBeforeWatchForAcceptedCount} |

**Friction verdict:** ${summary.trialFrictionVerdict.id}

## Tomorrow check-in

| Metric | Count |
|--------|------:|
| Check-in created | ${summary.checkInCreatedCount} |
| Due shown | ${summary.checkInDueShownCount} |
| Option selected | ${summary.checkInOptionSelectedCount} |
| Completed | ${summary.checkInCompletedCount} |

**Check-in completion rate:** ${pct(summary.checkInCompletionRate)}

## Reminder readiness

**Status:** ${summary.reminderReadiness.id}  
**Reason:** ${summary.reminderReadinessReason}  
**Reminder candidates:** ${summary.reminderCandidateCount}

- Enabled: ${summary.reminderEnabled}
- Permission requested: ${summary.reminderPermissionRequestedCount}
- Permission granted: ${summary.reminderPermissionGrantedCount}
- Permission denied: ${summary.reminderPermissionDeniedCount}
- Scheduled: ${summary.reminderScheduledCount}
- Cancelled: ${summary.reminderCancelledCount}
- Tapped: ${summary.reminderTappedCount}

## Recommended next fix

**Primary action:** ${summary.hookRescuePrimaryAction.id}  
**Reason:** ${summary.hookRescueReason}  
**Confidence:** ${summary.hookRescueConfidence.id}  
**Secondary actions:** ${summary.hookRescueSecondaryActions.isEmpty ? '—' : summary.hookRescueSecondaryActions.map((a) => a.id).join(', ')}

## Hook escalation

- Sharper question: ${summary.sharperQuestionIntensity.id}
- Better result: ${summary.betterResultIntensity.id}
- Reminder: ${summary.reminderImplementationStatus.id} (scheduled: ${summary.reminderScheduledCount}, denied: ${summary.reminderDeniedCount})

## Hook quality

- Sharper questions shown: ${summary.sharperQuestionGeneratedCount} (very sharp: ${summary.verySharpQuestionGeneratedCount})
- Sharper questions accepted: ${summary.sharperQuestionAcceptedCount} (very sharp: ${summary.verySharpQuestionAcceptedCount})
- Better result shown: ${summary.betterResultShownCount} (aggressive: ${summary.aggressiveBetterResultShownCount})
- Go deeper shown / opened: ${summary.checkInGoDeeperShownCount} / ${summary.checkInGoDeeperTappedCount}

## Next useful check

- Shown: ${summary.resultNextCheckShownCount}
- Used: ${summary.resultNextCheckUsedCount}
- Changed: ${summary.resultNextCheckChangedCount}
- Used from Patterns: ${summary.resultNextCheckUsedFromPatternsCount}

## Useful result rescue

- Takeaway shown: ${summary.usefulResultTakeawayShownCount}
- Make more useful tapped: ${summary.makeResultMoreUsefulTappedCount}
- Make more useful reason selected: ${summary.makeResultMoreUsefulReasonSelectedCount}
- Next check used: ${summary.usefulResultNextCheckUsedCount}

## Input quality coach

- Coach shown: ${summary.inputQualityCoachShownCount}
- Sentence added: ${summary.inputQualitySentenceAddedCount}
- Used anyway: ${summary.inputQualityUsedAnywayCount}
- Accepted weak input: ${summary.acceptedWeakInputCount}
- Sharpened input: ${summary.sharpenedInputCount}
- Latest level: ${summary.latestInputQualityLevel ?? 'none'}
- Average score: ${summary.averageInputQualityScore?.toStringAsFixed(2) ?? 'n/a'}

## Another perspective

- Shown: ${summary.perspectiveShiftShownCount}
- Changed: ${summary.perspectiveShiftChangedCount}
- Used: ${summary.perspectiveShiftUsedCount}
- Shown from Patterns: ${summary.perspectiveShiftShownFromPatternsCount}
- Used from Patterns: ${summary.perspectiveShiftUsedFromPatternsCount}

## Kinder angle

- Shown: ${summary.kinderAngleShownCount}
- Used: ${summary.kinderAngleUsedCount}
- Changed: ${summary.kinderAngleChangedCount}
- Shown from Patterns: ${summary.kinderAngleShownFromPatternsCount}
- Used from Patterns: ${summary.kinderAngleUsedFromPatternsCount}

## Quick help

- Opened: ${summary.quickHelpOpenedCount}
- Intent selected: ${summary.quickHelpIntentSelectedCount}
- Primary action tapped: ${summary.quickHelpPrimaryActionTappedCount}
- Check used: ${summary.quickHelpCheckUsedCount}

## Key moments

- Created: ${summary.keyMomentCreatedCount}
- Opened: ${summary.keyMomentOpenedCount}
- Search used: ${summary.keyMomentSearchUsedCount}
- Use this check tapped: ${summary.keyMomentUseCheckTappedCount}

## Ask my Archive

- Opened: ${summary.askArchiveOpenedCount}
- Search used: ${summary.askArchiveSearchUsedCount}
- Suggested chip tapped: ${summary.askArchiveSuggestedChipTappedCount}
- Result opened: ${summary.askArchiveResultOpenedCount}
- Use this check tapped: ${summary.askArchiveUseCheckTappedCount}

## Archive clean view

- Shown: ${summary.archiveCleanViewShownCount}
- Section tapped: ${summary.archiveCleanSectionTappedCount}

## Pattern profile

- Shown: ${summary.patternProfileShownCount}
- Opened: ${summary.patternProfileOpenedCount}
- Use this check tapped: ${summary.patternProfileUseCheckTappedCount}
- Find moments tapped: ${summary.patternProfileFindMomentsTappedCount}
- Open timeline tapped: ${summary.patternProfileOpenTimelineTappedCount}

## Pattern map

- Shown: ${summary.patternMapShownCount}
- Opened: ${summary.patternMapOpenedCount}
- Use this check tapped: ${summary.patternMapUseCheckTappedCount}

## Feedback

- Shown: ${summary.archiveFeedbackShownCount}
- Selected: ${summary.archiveFeedbackSelectedCount}
- Useful: ${summary.archiveFeedbackUsefulCount}
- Too generic: ${summary.archiveFeedbackTooGenericCount}
- Not me: ${summary.archiveFeedbackNotMeCount}
- Already knew: ${summary.archiveFeedbackAlreadyKnewCount}
- More specific: ${summary.archiveFeedbackMoreSpecificCount}
- Dominant issue: ${summary.archiveFeedbackDominantIssue}

## Archive compression

- Shown: ${summary.archiveCompressionShownCount}
- Opened: ${summary.archiveCompressionOpenedCount}
- Kept: ${summary.archiveCompressionKeptCount}
- Split: ${summary.archiveCompressionSplitCount}
- Hidden: ${summary.archiveCompressionHiddenCount}

## Memory quality

- Shown: ${summary.memoryQualityShownCount}
- Tapped: ${summary.memoryQualityTappedCount}
- Latest level: ${summary.latestMemoryQualityLevel ?? 'none'}

## Tester invite copy

${_testerInviteSection(summary)}

## Acquisition cohort

${_acquisitionCohortSection(summary)}

## Retention diagnosis (v2)

${_retentionDiagnosisSection(summary)}

## Billing / paywall

- Paywall shown: ${summary.paywallShownCount}
- Paywall trigger shown: ${summary.paywallTriggerShownCount}
- Annual plan shown: ${summary.annualPlanShownCount}
- Monthly plan shown: ${summary.monthlyPlanShownCount}
- Annual plan selected: ${summary.annualPlanSelectedCount}
- Monthly plan selected: ${summary.monthlyPlanSelectedCount}
- Continue tapped: ${summary.paywallContinueTappedCount}
- Dismissed: ${summary.paywallDismissedCount}
- Restore tapped: ${summary.restoreTappedCount}

## Archive range review

- Shown: ${summary.archiveRangeReviewShownCount}
- Opened: ${summary.archiveRangeReviewOpenedCount}
- Use check tapped: ${summary.archiveRangeReviewUseCheckTappedCount}
- Preset changed: ${summary.archiveRangeReviewPresetChangedCount}

## Retention loop
- State shown: ${summary.retentionStateShownCount}
- Due shown: ${summary.retentionDueShownCount}
- Check set shown: ${summary.retentionCheckSetShownCount}
- Loop closed shown: ${summary.retentionLoopClosedShownCount}
- Primary CTA tapped: ${summary.retentionPrimaryCtaTappedCount}
- Next check ready: ${summary.retentionNextCheckReadyCount}
- Missed check: ${summary.retentionMissedCheckCount}
- Reminder from retention: ${summary.reminderScheduledFromRetentionCount}

## Compelling check
- Shown: ${summary.compellingCheckShownCount}
- Selected: ${summary.compellingCheckSelectedCount}
- Most specific selected: ${summary.compellingCheckMostSpecificSelectedCount}
- Accepted: ${summary.compellingCheckAcceptedCount}

## Real reminders
- Permission requested: ${summary.realReminderPermissionRequestedCount}
- Permission granted: ${summary.realReminderPermissionGrantedCount}
- Permission denied: ${summary.realReminderPermissionDeniedCount}
- Scheduled: ${summary.realReminderScheduledCount}
- Cancelled: ${summary.realReminderCancelledCount}
- Unavailable: ${summary.realReminderUnavailableCount}

## Current objective
- Shown: ${summary.currentObjectiveShownCount}
- Primary tapped: ${summary.currentObjectivePrimaryTappedCount}
- Secondary tapped: ${summary.currentObjectiveSecondaryTappedCount}
- Latest type: ${summary.latestCurrentObjectiveType ?? 'none'}

## Pro value preview
- Shown: ${summary.proValuePreviewShownCount}
- Unlock tapped: ${summary.proValuePreviewUnlockTappedCount}
- Dismissed: ${summary.proValuePreviewDismissedCount}
- Latest type: ${summary.latestProValuePreviewType ?? 'none'}

## Today\u2019s check widget
- Refresh attempted: ${summary.objectiveWidgetRefreshAttemptedCount}
- Refresh succeeded: ${summary.objectiveWidgetRefreshSucceededCount}
- Refresh failed: ${summary.objectiveWidgetRefreshFailedCount}
- Cleared: ${summary.objectiveWidgetClearedCount}

## What ArchiveMe remembers

- Summary shown: ${summary.archiveMemorySummaryShownCount}
- Open pattern map tapped: ${summary.archiveMemoryOpenPatternMapTappedCount}
- Find moments tapped: ${summary.archiveMemoryFindMomentsTappedCount}
- Use this check tapped: ${summary.archiveMemoryUseCheckTappedCount}

## Pattern timeline

- Timeline shown: ${summary.archiveTimelineShownCount}
- Timeline opened: ${summary.archiveTimelineOpenedCount}
- Use this check tapped: ${summary.archiveTimelineUseCheckTappedCount}

## Positioning comprehension

- Asked: ${summary.positioningComprehensionAskedCount}
- Answered: ${summary.positioningComprehensionAnsweredCount}
- Understood archive memory: ${summary.positioningUnderstoodArchiveMemoryCount}
- Journal: ${summary.positioningJournalCount}
- Chat: ${summary.positioningChatCount}
- Not sure: ${summary.positioningNotSureCount}
- Rate: ${summary.positioningArchiveMemoryRate == null ? 'n/a' : '${(summary.positioningArchiveMemoryRate! * 100).toStringAsFixed(0)}%'}
- Pass (≥3/5 archive memory): ${summary.positioningComprehensionPass ? 'yes' : 'no'}

## Pattern memory

- Status: ${summary.activePatternMemoryStatus?.id ?? 'none'}
- Check-ins: ${summary.patternMemoryCheckInCount}
- Created: ${summary.patternMemoryCreatedCount}
- Updated: ${summary.patternMemoryUpdatedCount}

## Pattern progress

- Latest type: ${summary.latestPatternProgressType?.id ?? 'none'}
- Moments created: ${summary.patternProgressMomentCreatedCount}
- Cards shown: ${summary.patternProgressCardShownCount}

## Pattern next action

- Latest type: ${summary.latestPatternNextActionType?.id ?? 'none'}
- Actions created: ${summary.patternNextActionCreatedCount}
- Actions used: ${summary.patternNextActionUsedCount}

## Habit proof

- Latest type: ${summary.latestHabitProofType?.id ?? 'none'}
- Proofs created: ${summary.habitProofCreatedCount}
- Cards shown: ${summary.habitProofShownCount}
- CTA tapped: ${summary.habitProofCtaTappedCount}

## Weekly pattern recap

- Latest type: ${summary.latestWeeklyPatternRecapType?.id ?? 'none'}
- Recaps created: ${summary.weeklyPatternRecapCreatedCount}
- Cards shown: ${summary.weeklyPatternRecapShownCount}
- CTA tapped: ${summary.weeklyPatternRecapCtaTappedCount}

## Pattern share

- Cards shown: ${summary.patternShareCardShownCount}
- Copied: ${summary.patternShareCopiedCount}
- Opened: ${summary.patternShareOpenedCount}
- Failed: ${summary.patternShareFailedCount}

## Activation loop

| Step | Status |
|------|--------|
| First moment | ${summary.activationSavedFirstMoment ? 'yes' : 'no'} |
| Tomorrow check | ${summary.activationChoseTomorrowCheck ? 'yes' : 'no'} |
| Returned | ${summary.activationReturnedNextDay ? 'yes' : 'no'} |
| Loop closed | ${summary.activationClosedLoop ? 'yes' : 'no'} |
| Useful / sort-of | ${summary.activationRatedUsefulOrSortOf ? 'yes' : 'no'} |
| Next check | ${summary.activationChoseNextCheck ? 'yes' : 'no'} |

**Weakest bucket:** ${summary.activationWeakestBucket}  
**Full loops completed:** ${summary.activationFullLoopCompletedCount}

## First loop

- Stage: ${summary.firstLoopStage.id}
- Completed: ${summary.firstLoopCompleted}
- Seconds to first save: ${summary.secondsToFirstSave ?? 'n/a'}
- Seconds to loop ready: ${summary.secondsToLoopReady ?? 'n/a'}
- Dropoff point: ${summary.firstLoopDropoffPoint.id}

## Return day

- Due shown: ${summary.returnDayDueShownCount}
- Answer selected: ${summary.returnDayAnswerSelectedCount}
- Loop closed: ${summary.returnDayLoopClosedCount}
- Latest seconds to answer: ${summary.latestSecondsToAnswer ?? 'n/a'}
- Latest seconds to loop closed: ${summary.latestSecondsToLoopClosed ?? 'n/a'}
- Completion rate: ${summary.returnDayCompletionRate?.toStringAsFixed(2) ?? 'n/a'}
- Dropoff point: ${summary.returnDayDropoffPoint.name}

## Hook diagnosis

**Likely failure:** ${summary.hookDiagnosis.likelyFailure}

| Question rating | Count |
|-----------------|------:|
| Useful | ${summary.hookDiagnosis.checkInQuestionRatedUseful} |
| Sort of | ${summary.hookDiagnosis.checkInQuestionRatedSortOf} |
| Not useful | ${summary.hookDiagnosis.checkInQuestionRatedNotUseful} |

| Missed reason | Count |
|---------------|------:|
| Forgot | ${summary.hookDiagnosis.forgotCount} |
| Did not care | ${summary.hookDiagnosis.didNotCareCount} |
| Confusing | ${summary.hookDiagnosis.confusingCount} |

| Result rating | Count |
|---------------|------:|
| Useful | ${summary.hookDiagnosis.resultUsefulCount} |
| Sort of | ${summary.hookDiagnosis.resultSortOfCount} |
| Not useful | ${summary.hookDiagnosis.resultNotUsefulCount} |

| Clarity signal | Count |
|----------------|------:|
| Clarity card shown | ${summary.hookDiagnosis.checkInClarityCardShownCount} |
| Examples opened | ${summary.hookDiagnosis.examplesOpenedCount} |
| Moment recorded CTA | ${summary.hookDiagnosis.checkInMomentRecordedCount} |

**Clarity issue rate:** ${pct(summary.hookDiagnosis.clarityIssueRate)}

| Not useful reason | Count |
|-------------------|------:|
| Too vague | ${summary.hookDiagnosis.notUsefulReasonCounts[HookDiagnosisNotUsefulReason.tooVague] ?? 0} |
| Not accurate | ${summary.hookDiagnosis.notUsefulReasonCounts[HookDiagnosisNotUsefulReason.notAccurate] ?? 0} |
| Already knew | ${summary.hookDiagnosis.notUsefulReasonCounts[HookDiagnosisNotUsefulReason.alreadyKnewThis] ?? 0} |
| Confusing | ${summary.hookDiagnosis.notUsefulReasonCounts[HookDiagnosisNotUsefulReason.confusing] ?? 0} |

## Rates

| Rate | Value |
|------|------:|
| Correction rate | ${pct(summary.correctionRate)} |
| Watch-for accept rate | ${pct(summary.watchForAcceptRate)} |
| Day-2 return rate | ${pct(summary.day2ReturnRate)} |
| Useful rate (yes + sort of) | ${pct(summary.usefulRate)} |

## Notes

_Add facilitator observations here._

''';
  }

  String _testerInviteSection(TrialSummaryModel summary) {
    return '''
- Capacity invite copied: ${summary.capacityInviteCopiedCount}
- Prove invite copied: ${summary.proveInviteCopiedCount}
- Generic invite copied: ${summary.genericInviteCopiedCount}

## Prove wedge (primary)

- Default shown: ${summary.proveDefaultShownCount}
- Default started: ${summary.proveDefaultStartedCount}
- First moment recorded: ${summary.proveFirstMomentRecordedCount}
- Read accepted: ${summary.proveReadAcceptedCount}
- Second moment recorded: ${summary.proveSecondMomentRecordedCount}
- Review confirmed: ${summary.proveReviewConfirmedCount}
- Pro teaser tapped: ${summary.provePaywallTeaserTappedCount}''';
  }

  String _acquisitionCohortSection(TrialSummaryModel summary) {
    final c = summary.acquisitionCohort;
    if (c == null) {
      return '- Cohort: none';
    }
    return '''
- Cohort: ${c.cohortId.label} (${c.cohortId.id})
- Loop promise shown: ${c.promiseShown.isNotEmpty ? c.promiseShown : '—'}
- First moment recorded: ${c.firstMomentRecorded ? 'yes' : 'no'}
- Second moment recorded: ${c.secondMomentRecorded ? 'yes' : 'no'}
- Third moment recorded: ${c.thirdMomentRecorded ? 'yes' : 'no'}
- Review reached: ${c.loopReviewReached ? 'yes' : 'no'}
- Review confirmed: ${c.loopReviewConfirmed ? 'yes' : 'no'}
- Pro teaser tapped: ${c.paywallTeaserTapped ? 'yes' : 'no'}''';
  }

  String _retentionDiagnosisSection(TrialSummaryModel summary) {
    final d = summary.retentionDiagnosisSnapshot;
    if (d == null) return '- Not computed';
    return '''
- Bottleneck: ${d.retentionBottleneckLabel}
- Summary: ${d.retentionBottleneckSummary}
- Onboarding intent: ${d.onboardingIntent?.label ?? 'none'}
- Read useful taps: ${d.readUsefulTappedCount}
- Read not quite taps: ${d.readNotQuiteTappedCount}
- Interpretation strong: ${d.interpretationStrongCount}
- Interpretation weak: ${d.interpretationWeakCount}
- Reminder timing offered: ${d.reminderTimingOfferedCount}
- Reminder timing selected: ${d.reminderTimingSelectedCount}
- Reminder pre-prompt dismissed: ${d.reminderPrePromptDismissedCount}
- Reminder return recorded: ${d.reminderReturnRecordedCount}
- Second moment recorded: ${d.secondMomentRecordedCount}
- Third moment recorded: ${d.thirdMomentRecordedCount}
- Loop review viewed: ${d.loopReviewViewed ? 'yes' : 'no'}
- Loop review confirmed: ${d.loopReviewConfirmed ? 'yes' : 'no'}
- Loop review corrected: ${d.loopReviewCorrected ? 'yes' : 'no'}
- Loop review kept watching: ${d.loopReviewKeptWatching ? 'yes' : 'no'}
- Loop paywall teaser shown: ${d.loopPaywallTeaserShown ? 'yes' : 'no'}
- Loop paywall teaser tapped: ${d.loopPaywallTeaserTapped ? 'yes' : 'no'}
- Prove enough selected: ${d.proveEnoughSelected ? 'yes' : 'no'}
- Prove enough first prompt used: ${d.proveEnoughFirstPromptUsed ? 'yes' : 'no'}
- Prove enough matched first recording: ${d.proveEnoughMatchedFirstRecording ? 'yes' : 'no'}
- Prove enough read accepted: ${d.proveEnoughReadAccepted ? 'yes' : 'no'}
- Prove enough unsupported recording: ${d.proveEnoughUnsupportedRecording ? 'yes' : 'no'}
- Prove enough completed: ${d.proveEnoughCompleted ? 'yes' : 'no'}
- Acquisition cohort: ${d.acquisitionCohortId?.label ?? 'none'}
- Cohort promise shown: ${d.acquisitionCohortPromiseShown.isNotEmpty ? d.acquisitionCohortPromiseShown : '—'}
- Cohort first moment: ${d.acquisitionCohortFirstMomentRecorded ? 'yes' : 'no'}
- Cohort second moment: ${d.acquisitionCohortSecondMomentRecorded ? 'yes' : 'no'}
- Cohort third moment: ${d.acquisitionCohortThirdMomentRecorded ? 'yes' : 'no'}
- Cohort review reached: ${d.acquisitionCohortReviewReached ? 'yes' : 'no'}
- Cohort review confirmed: ${d.acquisitionCohortReviewConfirmed ? 'yes' : 'no'}
- Cohort pro teaser tapped: ${d.acquisitionCohortPaywallTeaserTapped ? 'yes' : 'no'}''';
  }
}
