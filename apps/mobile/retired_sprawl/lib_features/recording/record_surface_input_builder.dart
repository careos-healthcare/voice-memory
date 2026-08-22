part of 'recording_screen.dart';

extension RecordSurfaceInputBuilder on _RecordScreenState {
  RecordSurfaceInput _buildRecordSurfaceInput() {
    var ui = _ui;
    var isPostSave = _isPostSaveSurface;
    var micPhase = _mic;
    var micUserDenied = _micPermissionUserDenied;
    var error = _error;
    var localSaveTitle = _localSaveTitle;
    var syncNoteRaw = _syncNote;
    var stageLabelRaw = _stageLabel;
    var entriesAfterSave = _entriesAfterSave;
    var lastCaptureAnalysisSucceeded = _lastCaptureAnalysisSucceeded;

    if (VisualAuditOverrides.active) {
      final audit = VisualAuditOverrides.peekRecordPresentation();
      if (audit != null) {
        ui = audit.ui;
        isPostSave = audit.ui == RecordUiState.done || _showPostSaveLoop;
        if (audit.entriesAfterSave != null) {
          entriesAfterSave = audit.entriesAfterSave!;
        }
        if (audit.micPhase != null) {
          micPhase = audit.micPhase!;
        }
        if (audit.userDeniedThisSession != null) {
          micUserDenied = audit.userDeniedThisSession!;
        }
        error = audit.error;
        localSaveTitle = audit.localSaveTitle;
        syncNoteRaw = audit.syncNote;
        stageLabelRaw = audit.stageLabel ?? _stageLabel;
        lastCaptureAnalysisSucceeded = audit.lastCaptureAnalysisSucceeded;
      }
    }

    return RecordSurfaceInput(
      ui: ui,
      flags: RecordSurfaceFlags.from(ui),
      journalEntries: _journalEntries,
      entryCount: _journalEntryCount,
      entryCountLoaded: _journalEntryCountReady,
      isPostSave: isPostSave,
      userProState: RecordUserProState(
        recordReturnProState: _recordReturnProState,
        isPro: _recordReturnProIsPro,
      ),
      micPhase: micPhase,
      micPermissionState: _micPermissionState,
      micUserDeniedThisSession: micUserDenied,
      sessionRequiresOpenSettings: _micSessionRequiresOpenSettings,
      compactLayout: _compactLayout(ui),
      stackDecision: _recordStackDecision(ui),
      error: error,
      localSaveTitle: localSaveTitle,
      syncNoteRaw: syncNoteRaw,
      stageLabelRaw: stageLabelRaw,
      entriesAfterSave: entriesAfterSave,
      lastCaptureAnalysisSucceeded: lastCaptureAnalysisSucceeded,
      showPostSaveLoop: _showPostSaveLoop,
      lastSavedEntry: _lastSavedEntry,
      lastSavedEntryIsDegraded: _lastSavedEntryIsDegraded,
      recordReturnProJustSaved: _recordReturnProJustSaved,
      recordReturnCueVisible: _recordReturnCueVisible,
      savedFromConfirmedRepeatTrigger: _savedFromConfirmedRepeatTrigger,
      savedFromHelpfulAction: _savedFromHelpfulAction,
      earlyEvidenceTriggerCaptured: _earlyEvidenceTriggerCaptured,
      earlyEvidenceHelpfulCaptured: _earlyEvidenceHelpfulCaptured,
      earlyReturnReminderOffer: _earlyReturnReminderOffer,
      earlyReturnReminderHidden: _earlyReturnReminderHidden,
      secondSessionComparison: _secondSessionComparison,
      valueMomentBridge: _valueMomentBridge,
      purchaseIntentCue: _purchaseIntentCue,
      betaActivationLoopCounts: _betaActivationLoopCounts,
      betaFeedbackCaptured: _betaFeedbackCaptured,
      canShowArchiveProgressCards: _canShowArchiveProgressCards,
      dailyReturnSuggestions: _dailyReturnSuggestions,
      hasWatchTheme: _hasWatchTheme,
      offerDayTwoReminder: _offerDayTwoReminder,
      postSaveCuriosityHook: _postSaveCuriosityHook,
      shareableProof: _shareableProof,
      applyEmptyArchiveGates: _applyEmptyArchiveGates,
      visualAuditPresentationKey:
          RecordSurfaceInputCacheKey.auditPresentationFingerprint(),
    );
  }
}
