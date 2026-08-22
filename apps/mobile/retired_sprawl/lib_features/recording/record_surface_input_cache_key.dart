import 'package:archiveme_mobile/audio/recording_service.dart';
import 'package:archiveme_mobile/dev/visual_audit_overrides.dart';
import 'package:archiveme_mobile/features/beta/beta_activation_loop_counts.dart';
import 'package:archiveme_mobile/features/record/record_stack_policy.dart';
import 'package:archiveme_mobile/features/recording/record_surface_flags.dart';
import 'package:archiveme_mobile/features/recording/record_surface_input.dart';
import 'package:archiveme_mobile/features/recording/record_user_pro_state.dart';
import 'package:archiveme_mobile/features/voice_capture/microphone_permission_state.dart';
import 'package:archiveme_mobile/features/voice_capture/record_microphone_permission_ui.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Stable fingerprint of [RecordSurfaceInput] for memoized resolution.
final class RecordSurfaceInputCacheKey {
  const RecordSurfaceInputCacheKey._({
    required this.ui,
    required this.flags,
    required this.journalEntriesKey,
    required this.entryCount,
    required this.entryCountLoaded,
    required this.isPostSave,
    required this.userProState,
    required this.micPhase,
    required this.micPermissionState,
    required this.micUserDeniedThisSession,
    required this.sessionRequiresOpenSettings,
    required this.compactLayout,
    required this.stackDecision,
    required this.error,
    required this.localSaveTitle,
    required this.syncNoteRaw,
    required this.stageLabelRaw,
    required this.entriesAfterSaveKey,
    required this.lastCaptureAnalysisSucceeded,
    required this.showPostSaveLoop,
    required this.lastSavedEntryKey,
    required this.lastSavedEntryIsDegraded,
    required this.recordReturnProJustSaved,
    required this.recordReturnCueVisible,
    required this.savedFromConfirmedRepeatTrigger,
    required this.savedFromHelpfulAction,
    required this.earlyEvidenceTriggerCaptured,
    required this.earlyEvidenceHelpfulCaptured,
    required this.earlyReturnReminderOffer,
    required this.earlyReturnReminderHidden,
    required this.secondSessionComparisonKey,
    required this.valueMomentBridgeKey,
    required this.purchaseIntentCueKey,
    required this.betaActivationLoopCountsKey,
    required this.betaFeedbackCaptured,
    required this.canShowArchiveProgressCards,
    required this.dailyReturnSuggestionsKey,
    required this.hasWatchTheme,
    required this.offerDayTwoReminder,
    required this.postSaveCuriosityHookKey,
    required this.shareableProofKey,
    required this.applyEmptyArchiveGates,
    required this.visualAuditPresentationKey,
  });

  static int auditPresentationFingerprint() {
    if (!VisualAuditOverrides.active) return 0;
    final audit = VisualAuditOverrides.peekRecordPresentation();
    if (audit == null) return 0;
    return Object.hash(
      audit.ui,
      audit.justSavedFirst,
      audit.degradedVoicePostSave,
      audit.entriesAfterSave?.length ?? -1,
      audit.lastCaptureAnalysisSucceeded,
      audit.micPhase,
      audit.userDeniedThisSession,
      audit.error,
      audit.localSaveTitle,
      audit.syncNote,
      audit.stageLabel,
    );
  }

  factory RecordSurfaceInputCacheKey.from(RecordSurfaceInput input) {
    return RecordSurfaceInputCacheKey._(
      ui: input.ui,
      flags: input.flags,
      journalEntriesKey: _entriesKey(input.journalEntries),
      entryCount: input.entryCount,
      entryCountLoaded: input.entryCountLoaded,
      isPostSave: input.isPostSave,
      userProState: input.userProState,
      micPhase: input.micPhase,
      micPermissionState: input.micPermissionState,
      micUserDeniedThisSession: input.micUserDeniedThisSession,
      sessionRequiresOpenSettings: input.sessionRequiresOpenSettings,
      compactLayout: input.compactLayout,
      stackDecision: input.stackDecision,
      error: input.error,
      localSaveTitle: input.localSaveTitle,
      syncNoteRaw: input.syncNoteRaw,
      stageLabelRaw: input.stageLabelRaw,
      entriesAfterSaveKey: _entriesKey(input.entriesAfterSave),
      lastCaptureAnalysisSucceeded: input.lastCaptureAnalysisSucceeded,
      showPostSaveLoop: input.showPostSaveLoop,
      lastSavedEntryKey: _entryKey(input.lastSavedEntry),
      lastSavedEntryIsDegraded: input.lastSavedEntryIsDegraded,
      recordReturnProJustSaved: input.recordReturnProJustSaved,
      recordReturnCueVisible: input.recordReturnCueVisible,
      savedFromConfirmedRepeatTrigger: input.savedFromConfirmedRepeatTrigger,
      savedFromHelpfulAction: input.savedFromHelpfulAction,
      earlyEvidenceTriggerCaptured: input.earlyEvidenceTriggerCaptured,
      earlyEvidenceHelpfulCaptured: input.earlyEvidenceHelpfulCaptured,
      earlyReturnReminderOffer: input.earlyReturnReminderOffer,
      earlyReturnReminderHidden: input.earlyReturnReminderHidden,
      secondSessionComparisonKey: input.secondSessionComparison?.hashCode ?? 0,
      valueMomentBridgeKey: input.valueMomentBridge?.hashCode ?? 0,
      purchaseIntentCueKey: input.purchaseIntentCue?.hashCode ?? 0,
      betaActivationLoopCountsKey: _betaActivationLoopCountsKey(
        input.betaActivationLoopCounts,
      ),
      betaFeedbackCaptured: input.betaFeedbackCaptured,
      canShowArchiveProgressCards: input.canShowArchiveProgressCards,
      dailyReturnSuggestionsKey: input.dailyReturnSuggestions.hashCode,
      hasWatchTheme: input.hasWatchTheme,
      offerDayTwoReminder: input.offerDayTwoReminder,
      postSaveCuriosityHookKey: input.postSaveCuriosityHook?.hashCode ?? 0,
      shareableProofKey: input.shareableProof?.hashCode ?? 0,
      applyEmptyArchiveGates: input.applyEmptyArchiveGates,
      visualAuditPresentationKey: input.visualAuditPresentationKey,
    );
  }

  final RecordUiState ui;
  final RecordSurfaceFlags flags;
  final int journalEntriesKey;
  final int entryCount;
  final bool entryCountLoaded;
  final bool isPostSave;
  final RecordUserProState userProState;
  final RecordingPhase micPhase;
  final MicrophonePermissionState micPermissionState;
  final bool micUserDeniedThisSession;
  final bool sessionRequiresOpenSettings;
  final bool compactLayout;
  final RecordStackDecision stackDecision;
  final String? error;
  final String? localSaveTitle;
  final String? syncNoteRaw;
  final String stageLabelRaw;
  final int entriesAfterSaveKey;
  final bool lastCaptureAnalysisSucceeded;
  final bool showPostSaveLoop;
  final int lastSavedEntryKey;
  final bool lastSavedEntryIsDegraded;
  final bool recordReturnProJustSaved;
  final bool recordReturnCueVisible;
  final bool savedFromConfirmedRepeatTrigger;
  final bool savedFromHelpfulAction;
  final bool earlyEvidenceTriggerCaptured;
  final bool earlyEvidenceHelpfulCaptured;
  final bool earlyReturnReminderOffer;
  final bool earlyReturnReminderHidden;
  final int secondSessionComparisonKey;
  final int valueMomentBridgeKey;
  final int purchaseIntentCueKey;
  final int betaActivationLoopCountsKey;
  final bool betaFeedbackCaptured;
  final bool canShowArchiveProgressCards;
  final int dailyReturnSuggestionsKey;
  final bool hasWatchTheme;
  final bool offerDayTwoReminder;
  final int postSaveCuriosityHookKey;
  final int shareableProofKey;
  final bool applyEmptyArchiveGates;
  final int visualAuditPresentationKey;

  static int _betaActivationLoopCountsKey(BetaActivationLoopCounts counts) {
    return Object.hashAll([
      counts.appOpened,
      counts.recordScreenSeen,
      counts.firstUsePromptSeen,
      counts.firstMomentSaved,
      counts.oneEntryReturnScreenSeen,
      counts.secondMomentSaved,
      counts.twoEntryRelatedSeen,
      counts.twoEntryUnrelatedSeen,
      counts.thirdMomentSaved,
      counts.confirmedRepeatSeen,
      counts.returnedAfterFirstProof,
      counts.fourthMomentSaved,
      counts.returnCheckAnswered,
      counts.proBoundarySeen,
      counts.paywallSeen,
      counts.restoreTapped,
      counts.purchaseTapped,
    ]);
  }

  static int _entryKey(JournalEntry? entry) {
    if (entry == null) return 0;
    return Object.hash(entry.id, entry.revision, entry.updatedAt);
  }

  static int _entriesKey(List<JournalEntry> entries) {
    return Object.hash(
      entries.length,
      Object.hashAll(entries.map(_entryKey)),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RecordSurfaceInputCacheKey &&
        other.ui == ui &&
        other.flags == flags &&
        other.journalEntriesKey == journalEntriesKey &&
        other.entryCount == entryCount &&
        other.entryCountLoaded == entryCountLoaded &&
        other.isPostSave == isPostSave &&
        other.userProState == userProState &&
        other.micPhase == micPhase &&
        other.micPermissionState == micPermissionState &&
        other.micUserDeniedThisSession == micUserDeniedThisSession &&
        other.sessionRequiresOpenSettings == sessionRequiresOpenSettings &&
        other.compactLayout == compactLayout &&
        other.stackDecision == stackDecision &&
        other.error == error &&
        other.localSaveTitle == localSaveTitle &&
        other.syncNoteRaw == syncNoteRaw &&
        other.stageLabelRaw == stageLabelRaw &&
        other.entriesAfterSaveKey == entriesAfterSaveKey &&
        other.lastCaptureAnalysisSucceeded == lastCaptureAnalysisSucceeded &&
        other.showPostSaveLoop == showPostSaveLoop &&
        other.lastSavedEntryKey == lastSavedEntryKey &&
        other.lastSavedEntryIsDegraded == lastSavedEntryIsDegraded &&
        other.recordReturnProJustSaved == recordReturnProJustSaved &&
        other.recordReturnCueVisible == recordReturnCueVisible &&
        other.savedFromConfirmedRepeatTrigger ==
            savedFromConfirmedRepeatTrigger &&
        other.savedFromHelpfulAction == savedFromHelpfulAction &&
        other.earlyEvidenceTriggerCaptured == earlyEvidenceTriggerCaptured &&
        other.earlyEvidenceHelpfulCaptured == earlyEvidenceHelpfulCaptured &&
        other.earlyReturnReminderOffer == earlyReturnReminderOffer &&
        other.earlyReturnReminderHidden == earlyReturnReminderHidden &&
        other.secondSessionComparisonKey == secondSessionComparisonKey &&
        other.valueMomentBridgeKey == valueMomentBridgeKey &&
        other.purchaseIntentCueKey == purchaseIntentCueKey &&
        other.betaActivationLoopCountsKey == betaActivationLoopCountsKey &&
        other.betaFeedbackCaptured == betaFeedbackCaptured &&
        other.canShowArchiveProgressCards == canShowArchiveProgressCards &&
        other.dailyReturnSuggestionsKey == dailyReturnSuggestionsKey &&
        other.hasWatchTheme == hasWatchTheme &&
        other.offerDayTwoReminder == offerDayTwoReminder &&
        other.postSaveCuriosityHookKey == postSaveCuriosityHookKey &&
        other.shareableProofKey == shareableProofKey &&
        other.applyEmptyArchiveGates == applyEmptyArchiveGates &&
        other.visualAuditPresentationKey == visualAuditPresentationKey;
  }

  @override
  int get hashCode => Object.hashAll([
    ui,
    flags,
    journalEntriesKey,
    entryCount,
    entryCountLoaded,
    isPostSave,
    userProState,
    micPhase,
    micPermissionState,
    micUserDeniedThisSession,
    sessionRequiresOpenSettings,
    compactLayout,
    stackDecision,
    error,
    localSaveTitle,
    syncNoteRaw,
    stageLabelRaw,
    entriesAfterSaveKey,
    lastCaptureAnalysisSucceeded,
    showPostSaveLoop,
    lastSavedEntryKey,
    lastSavedEntryIsDegraded,
    recordReturnProJustSaved,
    recordReturnCueVisible,
    savedFromConfirmedRepeatTrigger,
    savedFromHelpfulAction,
    earlyEvidenceTriggerCaptured,
    earlyEvidenceHelpfulCaptured,
    earlyReturnReminderOffer,
    earlyReturnReminderHidden,
    secondSessionComparisonKey,
    valueMomentBridgeKey,
    purchaseIntentCueKey,
    betaActivationLoopCountsKey,
    betaFeedbackCaptured,
    canShowArchiveProgressCards,
    dailyReturnSuggestionsKey,
    hasWatchTheme,
    offerDayTwoReminder,
    postSaveCuriosityHookKey,
    shareableProofKey,
    applyEmptyArchiveGates,
    visualAuditPresentationKey,
  ]);
}