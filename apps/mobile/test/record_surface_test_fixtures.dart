import 'package:archiveme_mobile/audio/recording_service.dart';
import 'package:archiveme_mobile/features/beta/beta_activation_loop_counts.dart';
import 'package:archiveme_mobile/features/pressure_retention/daily_return_suggestion_model.dart';
import 'package:archiveme_mobile/features/record/record_stack_policy.dart';
import 'package:archiveme_mobile/features/recording/record_surface_flags.dart';
import 'package:archiveme_mobile/features/recording/record_surface_input.dart';
import 'package:archiveme_mobile/features/recording/record_user_pro_state.dart';
import 'package:archiveme_mobile/features/voice_capture/microphone_permission_state.dart';
import 'package:archiveme_mobile/features/voice_capture/record_microphone_permission_ui.dart';

RecordSurfaceInput emptyRecordSurfaceInput({int entryCount = 0}) {
  return RecordSurfaceInput(
    ui: RecordUiState.ready,
    flags: RecordSurfaceFlags.from(RecordUiState.ready),
    journalEntries: const [],
    entryCount: entryCount,
    entryCountLoaded: true,
    isPostSave: false,
    userProState: const RecordUserProState(
      recordReturnProState: null,
      isPro: false,
    ),
    micPhase: RecordingPhase.ready,
    micPermissionState: MicrophonePermissionState.granted,
    micUserDeniedThisSession: false,
    sessionRequiresOpenSettings: false,
    compactLayout: false,
    stackDecision: decideRecordStack(
      hasDueCheck: false,
      isFirstRun: entryCount == 0,
      reflectionCount: entryCount,
      isTrialMode: false,
      isRecording: false,
      hasSavedReflection: false,
      inputQualityNeedsCoach: false,
      hasCompletedResult: false,
      hasResultNextCheck: false,
      hasRoutineAnchorOffer: false,
      hasArchiveProof: false,
    ),
    error: null,
    localSaveTitle: null,
    syncNoteRaw: null,
    stageLabelRaw: '',
    entriesAfterSave: const [],
    lastCaptureAnalysisSucceeded: true,
    showPostSaveLoop: false,
    lastSavedEntry: null,
    lastSavedEntryIsDegraded: false,
    recordReturnProJustSaved: false,
    recordReturnCueVisible: false,
    savedFromConfirmedRepeatTrigger: false,
    savedFromHelpfulAction: false,
    earlyEvidenceTriggerCaptured: false,
    earlyEvidenceHelpfulCaptured: false,
    earlyReturnReminderOffer: false,
    earlyReturnReminderHidden: false,
    secondSessionComparison: null,
    valueMomentBridge: null,
    purchaseIntentCue: null,
    betaActivationLoopCounts: const BetaActivationLoopCounts(),
    betaFeedbackCaptured: false,
    canShowArchiveProgressCards: true,
    dailyReturnSuggestions: DailyReturnSuggestionSet.empty,
    hasWatchTheme: false,
    offerDayTwoReminder: false,
    postSaveCuriosityHook: null,
    shareableProof: null,
    applyEmptyArchiveGates: true,
  );
}