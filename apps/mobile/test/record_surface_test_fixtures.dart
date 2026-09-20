import 'package:archiveme_mobile/audio/recording_service.dart';
import 'package:archiveme_mobile/features/beta/beta_activation_loop_counts.dart';
import 'package:archiveme_mobile/features/pressure_retention/daily_return_suggestion_model.dart';
import 'package:archiveme_mobile/features/record/record_stack_policy.dart';
import 'package:archiveme_mobile/features/recording/record_surface_flags.dart';
import 'package:archiveme_mobile/features/recording/record_surface_input.dart';
import 'package:archiveme_mobile/features/recording/record_user_pro_state.dart';
import 'package:archiveme_mobile/features/voice_capture/microphone_permission_state.dart';
import 'package:archiveme_mobile/features/voice_capture/record_microphone_permission_ui.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';

RecordSurfaceInput emptyRecordSurfaceInput({
  int? entryCount,
  RecordUiState ui = RecordUiState.ready,
  List<JournalEntry> journalEntries = const [],
  bool isPostSave = false,
  RecordUserProState? userProState,
  MicrophonePermissionState micPermissionState =
      MicrophonePermissionState.granted,
  List<JournalEntry> entriesAfterSave = const [],
  bool recordReturnProJustSaved = false,
  bool savedFromConfirmedRepeatTrigger = false,
}) {
  final resolvedEntryCount = entryCount ?? journalEntries.length;
  return RecordSurfaceInput(
    ui: ui,
    flags: RecordSurfaceFlags.from(ui),
    journalEntries: journalEntries,
    entryCount: resolvedEntryCount,
    entryCountLoaded: true,
    isPostSave: isPostSave,
    userProState:
        userProState ??
        const RecordUserProState(recordReturnProState: null, isPro: false),
    micPhase: ui == RecordUiState.recording
        ? RecordingPhase.recording
        : RecordingPhase.ready,
    micPermissionState: micPermissionState,
    micUserDeniedThisSession:
        micPermissionState == MicrophonePermissionState.deniedOpenSettings ||
        micPermissionState == MicrophonePermissionState.deniedCanAskAgain,
    sessionRequiresOpenSettings:
        micPermissionState == MicrophonePermissionState.deniedOpenSettings,
    compactLayout: false,
    stackDecision: decideRecordStack(
      hasDueCheck: false,
      isFirstRun: resolvedEntryCount == 0,
      reflectionCount: resolvedEntryCount,
      isTrialMode: false,
      isRecording: ui == RecordUiState.recording,
      hasSavedReflection:
          journalEntries.isNotEmpty || entriesAfterSave.isNotEmpty,
      inputQualityNeedsCoach: false,
      hasCompletedResult: ui == RecordUiState.done || isPostSave,
      hasResultNextCheck: false,
      hasRoutineAnchorOffer: false,
      hasArchiveProof: false,
    ),
    error: null,
    localSaveTitle: null,
    syncNoteRaw: null,
    stageLabelRaw: '',
    entriesAfterSave: entriesAfterSave,
    lastCaptureAnalysisSucceeded: true,
    showPostSaveLoop: isPostSave,
    lastSavedEntry: entriesAfterSave.isNotEmpty ? entriesAfterSave.last : null,
    lastSavedEntryIsDegraded: false,
    recordReturnProJustSaved: recordReturnProJustSaved,
    recordReturnCueVisible: false,
    savedFromConfirmedRepeatTrigger: savedFromConfirmedRepeatTrigger,
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

/// Same shape as `repeat_return_check_test.dart`'s `_entry`.
JournalEntry relatedRepeatEntry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt ?? DateTime(2026, 6, 12, 10),
    transcript: transcript,
    durationSeconds: 24,
    reflection: const Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 2,
      recurringThemes: ['work'],
      exactLanguagePattern: 'I said yes again',
      concreteObservation: 'Saying yes showed up again.',
      repeatedSignal: 'saying yes before ready',
    ),
  );
}

List<JournalEntry> threeRelatedRepeatEntries() => [
  relatedRepeatEntry(
    id: 'e1',
    transcript:
        'I had no capacity but I said yes again to the extra meeting today.',
    createdAt: DateTime(2026, 6, 10, 12),
  ),
  relatedRepeatEntry(
    id: 'e2',
    transcript:
        'Same thing — said yes when I had no capacity for one more thing.',
    createdAt: DateTime(2026, 6, 11, 12),
  ),
  relatedRepeatEntry(
    id: 'e3',
    transcript:
        'I said yes again even though I had no capacity for one more ask.',
    createdAt: DateTime(2026, 6, 12, 12),
  ),
];

List<JournalEntry> fourRelatedRepeatEntries() => [
  ...threeRelatedRepeatEntries(),
  relatedRepeatEntry(
    id: 'e4',
    transcript:
        'I said yes again even though I had no capacity for one more ask today.',
    createdAt: DateTime(2026, 6, 13, 12),
  ),
];
