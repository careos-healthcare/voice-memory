import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/activation_events_store.dart';
import 'package:voicememory_mobile/features/activation/activation_tracker.dart';
import 'package:voicememory_mobile/features/activation/first_loop_activation_model.dart';
import 'package:voicememory_mobile/features/activation/first_loop_activation_store.dart';
import 'package:voicememory_mobile/features/pattern_memory/habit_proof_model.dart';
import 'package:voicememory_mobile/features/pattern_memory/habit_proof_store.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_memory_model.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_memory_store.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_next_action_model.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_next_action_store.dart';
import 'package:voicememory_mobile/features/pattern_memory/weekly_pattern_recap_model.dart';
import 'package:voicememory_mobile/features/pattern_memory/weekly_pattern_recap_store.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_progress_model.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_progress_store.dart';
import 'package:voicememory_mobile/features/tomorrow_return/check_in_reminder_service.dart';
import 'package:voicememory_mobile/features/trial/hook_diagnosis_model.dart';
import 'package:voicememory_mobile/features/trial/hook_diagnosis_store.dart';
import 'package:voicememory_mobile/features/trial/hook_rescue_decision_model.dart';
import 'package:voicememory_mobile/features/trial/trial_summary_engine.dart';
import 'package:voicememory_mobile/features/trial/trial_summary_model.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_trial_journal_$stamp.json',
    prefsPath: '/tmp/vm_trial_prefs_$stamp.json',
  );
}

void main() {
  test('promising verdict when core hooks fire', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final store = ActivationEventsStore(AppServices.instance.prefs);
    await store.write(
      const ActivationEventCounts(
        participantId: 'P1',
        firstReflectionSaved: 1,
        firstPatternShown: 1,
        firstPatternAccepted: 1,
        watchForPromptShown: 1,
        watchForPromptAccepted: 1,
        returnedNextDay: 1,
        usefulnessYes: 1,
      ),
    );

    final summary = await const TrialSummaryEngine().build();
    expect(summary.verdict, TrialSummaryVerdict.promising);
    expect(summary.participantId, 'P1');
    expect(summary.watchForAcceptRate, 1.0);
    expect(summary.trialFrictionVerdict, TrialFrictionVerdict.clean);
    expect(summary.checkInCompletionRate, isNull);
  });

  test('hook quality counts surface in summary', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final store = ActivationEventsStore(AppServices.instance.prefs);
    await store.write(
      const ActivationEventCounts(
        sharperQuestionShown: 3,
        sharperQuestionAggressiveShown: 2,
        sharperQuestionAccepted: 1,
        sharperQuestionAggressiveAccepted: 1,
        betterResultShown: 4,
        betterResultAggressiveShown: 2,
        checkInGoDeeperShown: 5,
        checkInGoDeeperTapped: 3,
        resultNextCheckShown: 6,
        resultNextCheckUsed: 4,
        resultNextCheckChanged: 2,
        resultNextCheckUsedFromPatterns: 1,
        usefulResultTakeawayShown: 9,
        makeResultMoreUsefulTapped: 5,
        makeResultMoreUsefulReasonSelected: 4,
        usefulResultNextCheckUsed: 3,
        inputQualityCoachShown: 7,
        inputQualitySentenceAdded: 4,
        inputQualityUsedAnyway: 2,
        acceptedWeakInputCount: 2,
        sharpenedInputCount: 4,
        perspectiveShiftShown: 8,
        perspectiveShiftChanged: 5,
        perspectiveShiftUsed: 3,
        perspectiveShiftShownFromPatterns: 2,
        perspectiveShiftUsedFromPatterns: 1,
        kinderAngleShown: 6,
        kinderAngleUsed: 4,
        kinderAngleChanged: 3,
        kinderAngleShownFromPatterns: 2,
        kinderAngleUsedFromPatterns: 1,
        quickHelpOpened: 9,
        quickHelpIntentSelected: 7,
        quickHelpPrimaryActionTapped: 5,
        quickHelpCheckUsed: 3,
        keyMomentCreated: 12,
        keyMomentOpened: 8,
        keyMomentSearchUsed: 4,
        keyMomentUseCheckTapped: 2,
        askArchiveOpened: 6,
        askArchiveSearchUsed: 4,
        askArchiveSuggestedChipTapped: 3,
        askArchiveResultOpened: 2,
        askArchiveUseCheckTapped: 1,
        archiveCleanViewShown: 8,
        archiveCleanSectionTapped: 5,
        patternProfileShown: 9,
        patternProfileOpened: 6,
        patternProfileUseCheckTapped: 3,
        patternProfileFindMomentsTapped: 2,
        patternProfileOpenTimelineTapped: 1,
        patternMapShown: 7,
        patternMapOpened: 5,
        patternMapUseCheckTapped: 3,
        archiveFeedbackShown: 9,
        archiveFeedbackSelected: 6,
        archiveFeedbackUseful: 1,
        archiveFeedbackTooGeneric: 3,
        archiveFeedbackNotMe: 1,
        archiveFeedbackAlreadyKnew: 1,
        archiveFeedbackMoreSpecific: 0,
        archiveCompressionShown: 4,
        archiveCompressionOpened: 3,
        archiveCompressionKept: 2,
        archiveCompressionSplit: 1,
        archiveCompressionHidden: 1,
        memoryQualityShown: 5,
        memoryQualityTapped: 2,
        latestMemoryQualityLevel: 'clearPattern',
        archiveMemorySummaryShown: 11,
        archiveMemoryOpenPatternMapTapped: 4,
        archiveMemoryFindMomentsTapped: 3,
        archiveMemoryUseCheckTapped: 2,
        archiveTimelineShown: 6,
        archiveTimelineOpened: 4,
        archiveTimelineUseCheckTapped: 1,
      ),
    );

    final summary = await const TrialSummaryEngine().build();
    expect(summary.sharperQuestionGeneratedCount, 3);
    expect(summary.verySharpQuestionGeneratedCount, 2);
    expect(summary.sharperQuestionAcceptedCount, 1);
    expect(summary.verySharpQuestionAcceptedCount, 1);
    expect(summary.betterResultShownCount, 4);
    expect(summary.aggressiveBetterResultShownCount, 2);
    expect(summary.checkInGoDeeperShownCount, 5);
    expect(summary.checkInGoDeeperTappedCount, 3);
    expect(summary.resultNextCheckShownCount, 6);
    expect(summary.resultNextCheckUsedCount, 4);
    expect(summary.resultNextCheckChangedCount, 2);
    expect(summary.resultNextCheckUsedFromPatternsCount, 1);
    expect(summary.usefulResultTakeawayShownCount, 9);
    expect(summary.makeResultMoreUsefulTappedCount, 5);
    expect(summary.makeResultMoreUsefulReasonSelectedCount, 4);
    expect(summary.usefulResultNextCheckUsedCount, 3);
    expect(summary.inputQualityCoachShownCount, 7);
    expect(summary.inputQualitySentenceAddedCount, 4);
    expect(summary.inputQualityUsedAnywayCount, 2);
    expect(summary.acceptedWeakInputCount, 2);
    expect(summary.sharpenedInputCount, 4);
    expect(summary.perspectiveShiftShownCount, 8);
    expect(summary.perspectiveShiftChangedCount, 5);
    expect(summary.perspectiveShiftUsedCount, 3);
    expect(summary.perspectiveShiftShownFromPatternsCount, 2);
    expect(summary.perspectiveShiftUsedFromPatternsCount, 1);
    expect(summary.kinderAngleShownCount, 6);
    expect(summary.kinderAngleUsedCount, 4);
    expect(summary.kinderAngleChangedCount, 3);
    expect(summary.kinderAngleShownFromPatternsCount, 2);
    expect(summary.kinderAngleUsedFromPatternsCount, 1);
    expect(summary.quickHelpOpenedCount, 9);
    expect(summary.quickHelpIntentSelectedCount, 7);
    expect(summary.quickHelpPrimaryActionTappedCount, 5);
    expect(summary.quickHelpCheckUsedCount, 3);
    expect(summary.keyMomentCreatedCount, 12);
    expect(summary.keyMomentOpenedCount, 8);
    expect(summary.keyMomentSearchUsedCount, 4);
    expect(summary.keyMomentUseCheckTappedCount, 2);
    expect(summary.askArchiveOpenedCount, 6);
    expect(summary.askArchiveSearchUsedCount, 4);
    expect(summary.askArchiveSuggestedChipTappedCount, 3);
    expect(summary.askArchiveResultOpenedCount, 2);
    expect(summary.askArchiveUseCheckTappedCount, 1);
    expect(summary.archiveCleanViewShownCount, 8);
    expect(summary.archiveCleanSectionTappedCount, 5);
    expect(summary.patternProfileShownCount, 9);
    expect(summary.patternProfileOpenedCount, 6);
    expect(summary.patternProfileUseCheckTappedCount, 3);
    expect(summary.patternProfileFindMomentsTappedCount, 2);
    expect(summary.patternProfileOpenTimelineTappedCount, 1);
    expect(summary.patternMapShownCount, 7);
    expect(summary.patternMapOpenedCount, 5);
    expect(summary.patternMapUseCheckTappedCount, 3);
    expect(summary.archiveFeedbackShownCount, 9);
    expect(summary.archiveFeedbackSelectedCount, 6);
    expect(summary.archiveFeedbackTooGenericCount, 3);
    expect(summary.archiveFeedbackDominantIssue, 'tooGeneric');
    expect(summary.archiveCompressionShownCount, 4);
    expect(summary.archiveCompressionKeptCount, 2);
    expect(summary.archiveCompressionHiddenCount, 1);
    expect(summary.memoryQualityShownCount, 5);
    expect(summary.memoryQualityTappedCount, 2);
    expect(summary.latestMemoryQualityLevel, 'clearPattern');
    expect(summary.archiveMemorySummaryShownCount, 11);
    expect(summary.archiveMemoryOpenPatternMapTappedCount, 4);
    expect(summary.archiveMemoryFindMomentsTappedCount, 3);
    expect(summary.archiveMemoryUseCheckTappedCount, 2);
    expect(summary.archiveTimelineShownCount, 6);
    expect(summary.archiveTimelineOpenedCount, 4);
    expect(summary.archiveTimelineUseCheckTappedCount, 1);

    final json = summary.toJson();
    expect(json['sharperQuestionGeneratedCount'], 3);
    expect(json['betterResultShownCount'], 4);
    expect(json['checkInGoDeeperShownCount'], 5);
    expect(json['resultNextCheckShownCount'], 6);
    expect(json['resultNextCheckUsedCount'], 4);
    expect(json['usefulResultTakeawayShownCount'], 9);
    expect(json['makeResultMoreUsefulTappedCount'], 5);
    expect(json['makeResultMoreUsefulReasonSelectedCount'], 4);
    expect(json['usefulResultNextCheckUsedCount'], 3);
    expect(json['inputQualityCoachShownCount'], 7);
    expect(json['inputQualitySentenceAddedCount'], 4);
    expect(json['inputQualityUsedAnywayCount'], 2);
    expect(json['acceptedWeakInputCount'], 2);
    expect(json['sharpenedInputCount'], 4);
    expect(json['perspectiveShiftShownCount'], 8);
    expect(json['perspectiveShiftChangedCount'], 5);
    expect(json['perspectiveShiftUsedCount'], 3);
    expect(json['perspectiveShiftShownFromPatternsCount'], 2);
    expect(json['perspectiveShiftUsedFromPatternsCount'], 1);
    expect(json['kinderAngleShownCount'], 6);
    expect(json['kinderAngleUsedCount'], 4);
    expect(json['kinderAngleChangedCount'], 3);
    expect(json['kinderAngleShownFromPatternsCount'], 2);
    expect(json['kinderAngleUsedFromPatternsCount'], 1);
    expect(json['quickHelpOpenedCount'], 9);
    expect(json['quickHelpIntentSelectedCount'], 7);
    expect(json['quickHelpPrimaryActionTappedCount'], 5);
    expect(json['quickHelpCheckUsedCount'], 3);
    expect(json['keyMomentCreatedCount'], 12);
    expect(json['keyMomentOpenedCount'], 8);
    expect(json['keyMomentSearchUsedCount'], 4);
    expect(json['keyMomentUseCheckTappedCount'], 2);
    expect(json['askArchiveOpenedCount'], 6);
    expect(json['askArchiveSearchUsedCount'], 4);
    expect(json['askArchiveSuggestedChipTappedCount'], 3);
    expect(json['askArchiveResultOpenedCount'], 2);
    expect(json['askArchiveUseCheckTappedCount'], 1);
    expect(json['archiveCleanViewShownCount'], 8);
    expect(json['archiveCleanSectionTappedCount'], 5);
    expect(json['patternProfileShownCount'], 9);
    expect(json['patternProfileOpenedCount'], 6);
    expect(json['patternProfileUseCheckTappedCount'], 3);
    expect(json['patternProfileFindMomentsTappedCount'], 2);
    expect(json['patternProfileOpenTimelineTappedCount'], 1);
    expect(json['patternMapShownCount'], 7);
    expect(json['patternMapOpenedCount'], 5);
    expect(json['patternMapUseCheckTappedCount'], 3);
    expect(json['archiveFeedbackShownCount'], 9);
    expect(json['archiveFeedbackSelectedCount'], 6);
    expect(json['archiveFeedbackDominantIssue'], 'tooGeneric');
    expect(json['archiveCompressionShownCount'], 4);
    expect(json['archiveCompressionKeptCount'], 2);
    expect(json['memoryQualityShownCount'], 5);
    expect(json['memoryQualityTappedCount'], 2);
    expect(json['latestMemoryQualityLevel'], 'clearPattern');
    expect(json['archiveMemorySummaryShownCount'], 11);
    expect(json['archiveMemoryOpenPatternMapTappedCount'], 4);
    expect(json['archiveMemoryFindMomentsTappedCount'], 3);
    expect(json['archiveMemoryUseCheckTappedCount'], 2);
    expect(json['archiveTimelineShownCount'], 6);
    expect(json['archiveTimelineOpenedCount'], 4);
    expect(json['archiveTimelineUseCheckTappedCount'], 1);
  });

  test('check-in completion rate in summary', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await ActivationEventsStore(AppServices.instance.prefs).write(
      const ActivationEventCounts(
        tomorrowCheckInCreated: 2,
        tomorrowCheckInCompleted: 1,
      ),
    );
    final summary = await const TrialSummaryEngine().build();
    expect(summary.checkInCompletionRate, 0.5);
    expect(summary.checkInCreatedCount, 2);
    expect(summary.checkInCompletedCount, 1);
  });

  test('friction permissionIssue in summary', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await ActivationEventsStore(AppServices.instance.prefs).write(
      const ActivationEventCounts(trialMicPermissionDenied: 1),
    );
    final summary = await const TrialSummaryEngine().build();
    expect(summary.trialFrictionVerdict, TrialFrictionVerdict.permissionIssue);
    expect(summary.micDeniedCount, 1);
  });

  test('friction hookIssue in summary', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await ActivationEventsStore(AppServices.instance.prefs).write(
      const ActivationEventCounts(
        firstReflectionSaved: 1,
        watchForPromptAccepted: 0,
      ),
    );
    final summary = await const TrialSummaryEngine().build();
    expect(summary.trialFrictionVerdict, TrialFrictionVerdict.hookIssue);
  });

  test('weak verdict when no watch-for accept or return', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await ActivationEventsStore(AppServices.instance.prefs).write(
      const ActivationEventCounts(
        firstReflectionSaved: 1,
        firstPatternShown: 1,
        watchForPromptAccepted: 0,
        returnedNextDay: 0,
      ),
    );

    final summary = await const TrialSummaryEngine().build();
    expect(summary.verdict, TrialSummaryVerdict.weak);
  });

  test('summary includes notUsefulReasonCounts from hook diagnosis', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await HookDiagnosisStore(AppServices.instance.prefs).append(
      HookDiagnosisEvent(
        id: 'hd1',
        createdAt: DateTime(2026, 5, 26),
        type: HookDiagnosisEventType.checkInResultNotUsefulReason,
        checkInId: 'tci1',
        reason: HookDiagnosisNotUsefulReason.tooVague,
      ),
    );
    final summary = await const TrialSummaryEngine().build();
    expect(
      summary.hookDiagnosis.notUsefulReasonCounts[
          HookDiagnosisNotUsefulReason.tooVague],
      1,
    );
  });

  HookDiagnosisEvent _missed(String reason, String id) => HookDiagnosisEvent(
        id: id,
        createdAt: DateTime(2026, 5, 26),
        type: HookDiagnosisEventType.checkInMissedReason,
        reason: reason,
      );

  HookDiagnosisEvent _questionRated(String rating, String id) =>
      HookDiagnosisEvent(
        id: id,
        createdAt: DateTime(2026, 5, 26),
        type: HookDiagnosisEventType.checkInQuestionRated,
        rating: rating,
      );

  test('reminder notReady when confusing high', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await ActivationEventsStore(AppServices.instance.prefs).write(
      const ActivationEventCounts(
        tomorrowCheckInCreated: 3,
        tomorrowCheckInDueShown: 3,
      ),
    );
    final hook = HookDiagnosisStore(AppServices.instance.prefs);
    await hook.append(_missed(HookDiagnosisMissedReason.confusing, 'c1'));
    await hook.append(_missed(HookDiagnosisMissedReason.confusing, 'c2'));

    final summary = await const TrialSummaryEngine().build();
    expect(summary.reminderReadiness, ReminderReadiness.notReady);
    expect(summary.reminderReadinessReason, contains('confusing'));
  });

  test('reminder notReady when did not care high', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await ActivationEventsStore(AppServices.instance.prefs).write(
      const ActivationEventCounts(
        tomorrowCheckInCreated: 2,
        tomorrowCheckInDueShown: 2,
      ),
    );
    final hook = HookDiagnosisStore(AppServices.instance.prefs);
    await hook.append(_missed(HookDiagnosisMissedReason.didNotCare, 'd1'));
    await hook.append(_missed(HookDiagnosisMissedReason.didNotCare, 'd2'));

    final summary = await const TrialSummaryEngine().build();
    expect(summary.reminderReadiness, ReminderReadiness.notReady);
    expect(summary.reminderReadinessReason, contains('did not care'));
  });

  test('reminder notReady when no check-ins created', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final summary = await const TrialSummaryEngine().build();
    expect(summary.reminderReadiness, ReminderReadiness.notReady);
    expect(summary.reminderReadinessReason, contains('No check-in'));
  });

  test('reminder maybe when one forgot but low rating sample', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await ActivationEventsStore(AppServices.instance.prefs).write(
      const ActivationEventCounts(
        tomorrowCheckInCreated: 2,
        tomorrowCheckInDueShown: 0,
      ),
    );
    final hook = HookDiagnosisStore(AppServices.instance.prefs);
    await hook.append(_missed(HookDiagnosisMissedReason.forgot, 'f1'));
    await hook.append(_questionRated(HookDiagnosisRating.yes, 'q1'));

    final summary = await const TrialSummaryEngine().build();
    expect(summary.reminderReadiness, ReminderReadiness.maybe);
    expect(summary.reminderCandidateCount, 2);
  });

  test('reminder ready when question useful and due shown low', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await ActivationEventsStore(AppServices.instance.prefs).write(
      const ActivationEventCounts(
        tomorrowCheckInCreated: 2,
        tomorrowCheckInDueShown: 0,
      ),
    );
    final hook = HookDiagnosisStore(AppServices.instance.prefs);
    await hook.append(_questionRated(HookDiagnosisRating.yes, 'q1'));
    await hook.append(_questionRated(HookDiagnosisRating.sortOf, 'q2'));

    final summary = await const TrialSummaryEngine().build();
    expect(summary.reminderReadiness, ReminderReadiness.ready);
    expect(summary.reminderReadinessReason, contains('worth testing'));
    expect(summary.reminderCandidateCount, 2);
  });

  test('hook rescue primary action exposed on summary', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await ActivationEventsStore(AppServices.instance.prefs).write(
      const ActivationEventCounts(
        firstReflectionSaved: 1,
        tomorrowCheckInCreated: 2,
        tomorrowCheckInDueShown: 2,
      ),
    );
    final hook = HookDiagnosisStore(AppServices.instance.prefs);
    await hook.append(_missed(HookDiagnosisMissedReason.confusing, 'c1'));
    await hook.append(_missed(HookDiagnosisMissedReason.confusing, 'c2'));

    final summary = await const TrialSummaryEngine().build();
    expect(summary.hookRescuePrimaryAction.id, 'guidedCheckIn');
    expect(summary.hookRescueReason, 'People are confused by the check-in.');
  });

  test('escalation intensities and reminder status exposed on summary',
      () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await ActivationEventsStore(AppServices.instance.prefs).write(
      const ActivationEventCounts(
        firstReflectionSaved: 1,
        tomorrowCheckInCreated: 5,
        tomorrowCheckInDueShown: 5,
      ),
    );
    final hook = HookDiagnosisStore(AppServices.instance.prefs);
    await hook.append(_missed(HookDiagnosisMissedReason.didNotCare, 'd1'));
    await hook.append(_missed(HookDiagnosisMissedReason.didNotCare, 'd2'));

    final summary = await const TrialSummaryEngine().build();
    expect(summary.sharperQuestionIntensity, HookRescueIntensity.aggressive);
    expect(
      summary.reminderImplementationStatus,
      ReminderImplementationStatus.noOp,
    );
    expect(summary.reminderScheduledCount, 0);
    expect(summary.reminderEnabled, isFalse);
  });

  test('summary surfaces reminder counts and enabled flag', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await ActivationEventsStore(AppServices.instance.prefs).write(
      const ActivationEventCounts(
        reminderPermissionRequested: 3,
        reminderPermissionGranted: 2,
        reminderPermissionDenied: 1,
        reminderScheduled: 2,
        reminderCancelled: 1,
        reminderTapped: 1,
      ),
    );
    await CheckInReminderService.setRemindersEnabled(true);
    addTearDown(() => CheckInReminderService.setRemindersEnabled(false));

    final summary = await const TrialSummaryEngine().build();
    expect(summary.reminderPermissionRequestedCount, 3);
    expect(summary.reminderPermissionGrantedCount, 2);
    expect(summary.reminderPermissionDeniedCount, 1);
    expect(summary.reminderScheduledCount, 2);
    expect(summary.reminderCancelledCount, 1);
    expect(summary.reminderTappedCount, 1);
    expect(summary.reminderEnabled, isTrue);
  });

  test('summary includes pattern memory fields', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await ActivationEventsStore(AppServices.instance.prefs).write(
      const ActivationEventCounts(
        patternMemoryCreated: 1,
        patternMemoryUpdated: 2,
      ),
    );
    await PatternMemoryStore(AppServices.instance.prefs).saveActive(
      PatternMemory(
        id: 'pm1',
        patternTitle: 'Taking responsibility before asking for help',
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 4),
        checkInCount: 3,
        showedAgainCount: 3,
        status: PatternMemoryStatus.active,
      ),
    );

    final summary = await const TrialSummaryEngine().build();
    expect(summary.patternMemoryCreatedCount, 1);
    expect(summary.patternMemoryUpdatedCount, 2);
    expect(summary.patternMemoryCheckInCount, 3);
    expect(summary.activePatternMemoryStatus, PatternMemoryStatus.active);
  });

  test('summary includes pattern progress fields', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await ActivationEventsStore(AppServices.instance.prefs).write(
      const ActivationEventCounts(
        patternProgressMomentCreated: 2,
        patternProgressCardShown: 3,
        patternNextActionCreated: 4,
        patternNextActionUsed: 1,
      ),
    );
    await PatternProgressStore(AppServices.instance.prefs).saveLatest(
      PatternProgressMoment(
        id: 'pp_pm1_3',
        memoryId: 'pm1',
        createdAt: DateTime(2026, 6, 4),
        type: PatternProgressType.stillRepeating,
        headline: 'This pattern is still showing up.',
        body: 'You have caught it 3 times.',
        nextLine: 'Next, watch what happens right before it starts.',
        checkInCount: 3,
        shouldShow: true,
      ),
    );
    await PatternNextActionStore(AppServices.instance.prefs).saveLatest(
      PatternNextAction(
        id: 'na_pm1_3_repeatCheck',
        memoryId: 'pm1',
        createdAt: DateTime(2026, 6, 4),
        type: PatternNextActionType.repeatCheck,
        title: 'Check what happens before it starts',
        body: 'Tomorrow, look at the moment right before it shows up.',
        question: 'What happens right before it shows up?',
        ctaLabel: 'Use this check',
        sourceProgressType: 'stillRepeating',
        sourceStatus: 'active',
      ),
    );

    final summary = await const TrialSummaryEngine().build();
    expect(summary.patternProgressMomentCreatedCount, 2);
    expect(summary.patternProgressCardShownCount, 3);
    expect(
      summary.latestPatternProgressType,
      PatternProgressType.stillRepeating,
    );
    expect(summary.patternNextActionCreatedCount, 4);
    expect(summary.patternNextActionUsedCount, 1);
    expect(
      summary.latestPatternNextActionType,
      PatternNextActionType.repeatCheck,
    );
  });

  test('summary includes habit proof fields', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await ActivationEventsStore(AppServices.instance.prefs).write(
      const ActivationEventCounts(
        habitProofCreated: 3,
        habitProofShown: 5,
        habitProofCtaTapped: 2,
      ),
    );
    await HabitProofStore(AppServices.instance.prefs).saveLatest(
      HabitProofMoment(
        id: 'hp_pm1_3_progressFound',
        memoryId: 'pm1',
        createdAt: DateTime(2026, 6, 4),
        type: HabitProofType.progressFound,
        headline: 'Now there is something to compare.',
        body: 'You can see whether this pattern is repeating, '
            'getting lighter, getting heavier, or changing.',
        proofLine: 'This pattern is still showing up.',
        nextLine: 'What happens right before it shows up?',
        checkInCount: 3,
        shouldShow: true,
      ),
    );

    final summary = await const TrialSummaryEngine().build();
    expect(summary.habitProofCreatedCount, 3);
    expect(summary.habitProofShownCount, 5);
    expect(summary.habitProofCtaTappedCount, 2);
    expect(summary.latestHabitProofType, HabitProofType.progressFound);
  });

  test('summary includes weekly pattern recap fields', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await ActivationEventsStore(AppServices.instance.prefs).write(
      const ActivationEventCounts(
        weeklyPatternRecapCreated: 2,
        weeklyPatternRecapShown: 4,
        weeklyPatternRecapCtaTapped: 1,
        patternShareCardShown: 5,
        patternShareCopied: 3,
        patternShareOpened: 2,
        patternShareFailed: 1,
      ),
    );
    await WeeklyPatternRecapStore(AppServices.instance.prefs).saveLatest(
      WeeklyPatternRecap(
        id: 'wr_pm1_20260601_repeated',
        memoryId: 'pm1',
        createdAt: DateTime(2026, 6, 4),
        weekStart: DateTime(2026, 6, 1),
        weekEnd: DateTime(2026, 6, 7),
        type: WeeklyPatternRecapType.repeated,
        patternTitle: 'saying yes when you mean no',
        headline: 'This pattern kept showing up this week.',
        body: 'You checked it 4 times and caught it more than once.',
        usefulLine: 'It often starts around: before saying yes',
        nextQuestion: 'What happens right before it starts?',
        checkInCount: 4,
        shouldShow: true,
      ),
    );

    final summary = await const TrialSummaryEngine().build();
    expect(summary.weeklyPatternRecapCreatedCount, 2);
    expect(summary.weeklyPatternRecapShownCount, 4);
    expect(summary.weeklyPatternRecapCtaTappedCount, 1);
    expect(summary.patternShareCardShownCount, 5);
    expect(summary.patternShareCopiedCount, 3);
    expect(summary.patternShareOpenedCount, 2);
    expect(summary.patternShareFailedCount, 1);
    expect(
      summary.latestWeeklyPatternRecapType,
      WeeklyPatternRecapType.repeated,
    );
  });

  test('trackTrialExportCopied increments event store', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await ActivationTracker.trackTrialExportCopied();
    final events = await ActivationEventsStore(AppServices.instance.prefs).read();
    expect(events.trialExportCopied, 1);
  });

  test('summary includes first-loop activation fields', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final store = FirstLoopActivationStore(AppServices.instance.prefs);
    await store.markOpenedRecord(at: DateTime(2026, 6, 4, 9, 0, 0));
    await store.markFirstMomentSaved(at: DateTime(2026, 6, 4, 9, 0, 20));
    await store.markFirstPatternShown('saying yes',
        at: DateTime(2026, 6, 4, 9, 0, 25));
    await store.markLoopReady(
      'saying yes',
      'What happens right before you say yes?',
      at: DateTime(2026, 6, 4, 9, 1, 0),
    );

    final summary = await const TrialSummaryEngine().build();
    expect(summary.firstLoopStage, FirstLoopActivationStage.loopReady);
    expect(summary.firstLoopCompleted, isTrue);
    expect(summary.secondsToFirstSave, 20);
    expect(summary.secondsToLoopReady, 60);
    expect(summary.firstLoopDropoffPoint, FirstLoopDropoffPoint.none);
  });

  test('summary reports first-loop dropoff when user stalls', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await FirstLoopActivationStore(AppServices.instance.prefs)
        .markRecordingStarted();

    final summary = await const TrialSummaryEngine().build();
    expect(summary.firstLoopStage, FirstLoopActivationStage.recordingStarted);
    expect(summary.firstLoopCompleted, isFalse);
    expect(summary.firstLoopDropoffPoint, FirstLoopDropoffPoint.saveFriction);
  });

  test('activation loop score exposed on summary', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await ActivationEventsStore(AppServices.instance.prefs).write(
      const ActivationEventCounts(
        firstReflectionSaved: 1,
        firstPatternAccepted: 1,
        returnedNextDay: 1,
        tomorrowCheckInCompleted: 1,
        usefulnessYes: 1,
        resultNextCheckUsed: 1,
      ),
    );

    final summary = await const TrialSummaryEngine().build();
    expect(summary.activationSavedFirstMoment, isTrue);
    expect(summary.activationChoseTomorrowCheck, isTrue);
    expect(summary.activationReturnedNextDay, isTrue);
    expect(summary.activationClosedLoop, isTrue);
    expect(summary.activationRatedUsefulOrSortOf, isTrue);
    expect(summary.activationChoseNextCheck, isTrue);
    expect(summary.activationFullLoopCompletedCount, 1);
    expect(summary.activationWeakestBucket, 'none');
  });

  test('positioning comprehension counts surface in summary', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await ActivationEventsStore(AppServices.instance.prefs).write(
      const ActivationEventCounts(
        positioningComprehensionAsked: 5,
        positioningComprehensionAnswered: 5,
        positioningUnderstoodArchiveMemory: 3,
        positioningJournal: 1,
        positioningChat: 1,
        positioningNotSure: 0,
      ),
    );

    final summary = await const TrialSummaryEngine().build();
    expect(summary.positioningComprehensionAskedCount, 5);
    expect(summary.positioningComprehensionAnsweredCount, 5);
    expect(summary.positioningUnderstoodArchiveMemoryCount, 3);
    expect(summary.positioningJournalCount, 1);
    expect(summary.positioningChatCount, 1);
    expect(summary.positioningNotSureCount, 0);
    expect(summary.positioningComprehensionPass, isTrue);
    expect(summary.positioningArchiveMemoryRate, 0.6);
  });

  test('compelling check and real reminder counts surface in summary', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await ActivationEventsStore(AppServices.instance.prefs).write(
      const ActivationEventCounts(
        compellingCheckShown: 4,
        compellingCheckSelected: 3,
        compellingCheckMostSpecificSelected: 2,
        compellingCheckAccepted: 1,
        realReminderPermissionRequested: 2,
        realReminderPermissionGranted: 1,
        realReminderPermissionDenied: 1,
        realReminderScheduled: 1,
        realReminderCancelled: 1,
        realReminderUnavailable: 1,
      ),
    );

    final summary = await const TrialSummaryEngine().build();
    expect(summary.compellingCheckShownCount, 4);
    expect(summary.compellingCheckSelectedCount, 3);
    expect(summary.compellingCheckMostSpecificSelectedCount, 2);
    expect(summary.compellingCheckAcceptedCount, 1);
    expect(summary.realReminderPermissionRequestedCount, 2);
    expect(summary.realReminderPermissionGrantedCount, 1);
    expect(summary.realReminderPermissionDeniedCount, 1);
    expect(summary.realReminderScheduledCount, 1);
    expect(summary.realReminderCancelledCount, 1);
    expect(summary.realReminderUnavailableCount, 1);
  });

  test('current objective counts surface in summary', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await ActivationEventsStore(AppServices.instance.prefs).write(
      const ActivationEventCounts(
        currentObjectiveShown: 5,
        currentObjectivePrimaryTapped: 3,
        currentObjectiveSecondaryTapped: 1,
        latestCurrentObjectiveType: 'answerTodayCheck',
      ),
    );

    final summary = await const TrialSummaryEngine().build();
    expect(summary.currentObjectiveShownCount, 5);
    expect(summary.currentObjectivePrimaryTappedCount, 3);
    expect(summary.currentObjectiveSecondaryTappedCount, 1);
    expect(summary.latestCurrentObjectiveType, 'answerTodayCheck');
  });

  test('pro value preview counts surface in summary', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await ActivationEventsStore(AppServices.instance.prefs).write(
      const ActivationEventCounts(
        proValuePreviewShown: 4,
        proValuePreviewUnlockTapped: 2,
        proValuePreviewDismissed: 1,
        latestProValuePreviewType: 'patternMap',
      ),
    );

    final summary = await const TrialSummaryEngine().build();
    expect(summary.proValuePreviewShownCount, 4);
    expect(summary.proValuePreviewUnlockTappedCount, 2);
    expect(summary.proValuePreviewDismissedCount, 1);
    expect(summary.latestProValuePreviewType, 'patternMap');
  });

  test('objective widget counts surface in summary', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    await ActivationEventsStore(AppServices.instance.prefs).write(
      const ActivationEventCounts(
        objectiveWidgetRefreshAttempted: 3,
        objectiveWidgetRefreshSucceeded: 2,
        objectiveWidgetRefreshFailed: 1,
        objectiveWidgetCleared: 1,
      ),
    );

    final summary = await const TrialSummaryEngine().build();
    expect(summary.objectiveWidgetRefreshAttemptedCount, 3);
    expect(summary.objectiveWidgetRefreshSucceededCount, 2);
    expect(summary.objectiveWidgetRefreshFailedCount, 1);
    expect(summary.objectiveWidgetClearedCount, 1);
  });
}
