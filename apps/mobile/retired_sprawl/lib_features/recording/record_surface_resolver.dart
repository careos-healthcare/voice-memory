import 'package:archiveme_mobile/core/config/v1_feature_flags.dart';
import 'package:archiveme_mobile/features/recording/record_postsave_surface_bag.dart';
import 'package:archiveme_mobile/features/recording/record_proof_stack_snapshot.dart';
import 'package:archiveme_mobile/features/recording/record_ready_surface_bag.dart';
import 'package:archiveme_mobile/features/recording/record_surface_capture_policy.dart';
import 'package:archiveme_mobile/features/recording/record_surface_input.dart';
import 'package:archiveme_mobile/features/recording/record_surface_view_state.dart';
import 'package:archiveme_mobile/features/recording/recording_dependencies.dart';
import 'package:archiveme_mobile/features/weekly_review/weekly_archive_review_engine.dart'
    as weekly_review_surface;

/// Pure resolver for record-screen domain gates, engines, and surface audits.
abstract final class RecordSurfaceResolver {
  RecordSurfaceResolver._();

  static ({
    RecordSurfaceFlags flags,
    RecordingPhase policyMic,
    bool policyUserDenied,
    bool firstUseSimplifiedRecord,
    String? error,
    String? localSaveTitle,
    String? syncNote,
    String stageLabel,
    List<JournalEntry> entriesAfterSave,
    bool lastCaptureAnalysisSucceeded,
  })
  resolveInputOverlay(RecordSurfaceInput input) {
    final flags = input.flags;
    var policyMic = input.micPhase;
    var policyUserDenied = input.micUserDeniedThisSession;
    final firstUseSimplifiedRecord =
        flags.isReady &&
        RecordEmptyArchiveGates.showFirstUseSimplifiedRecord(
          loaded: input.entryCountLoaded,
          entryCount: input.entryCount,
        );
    var error = input.error;
    var localSaveTitle = input.localSaveTitle;
    var syncNote = recordSurfaceSyncNote(input.syncNoteRaw);
    var stageLabel = input.stageLabelRaw;
    var entriesAfterSave = input.entriesAfterSave;
    var lastCaptureAnalysisSucceeded = input.lastCaptureAnalysisSucceeded;
    if (VisualAuditOverrides.active) {
      final audit = VisualAuditOverrides.peekRecordPresentation();
      if (audit != null) {
        if (audit.entriesAfterSave != null) {
          entriesAfterSave = audit.entriesAfterSave!;
        }
        if (audit.micPhase != null) policyMic = audit.micPhase!;
        if (audit.userDeniedThisSession != null) {
          policyUserDenied = audit.userDeniedThisSession!;
        }
        error = audit.error;
        localSaveTitle = audit.localSaveTitle;
        syncNote = recordSurfaceSyncNote(audit.syncNote);
        stageLabel = audit.stageLabel ?? (input.stageLabelRaw);
        lastCaptureAnalysisSucceeded = audit.lastCaptureAnalysisSucceeded;
      }
    }
    return (
      flags: flags,
      policyMic: policyMic,
      policyUserDenied: policyUserDenied,
      firstUseSimplifiedRecord: firstUseSimplifiedRecord,
      error: error,
      localSaveTitle: localSaveTitle,
      syncNote: syncNote,
      stageLabel: stageLabel,
      entriesAfterSave: entriesAfterSave,
      lastCaptureAnalysisSucceeded: lastCaptureAnalysisSucceeded,
    );
  }

  static RecordProofStackSnapshot resolveArchiveProofStack({
    required RecordSurfaceInput input,
    required RecordSurfaceFlags flags,
    required ConfirmedRepeatTriggerPayoff? confirmedRepeatTriggerPayoff,
    required ConfirmedRepeatHelpfulActionPayoff?
    confirmedRepeatHelpfulActionPayoff,
    required ConfirmedRepeatChangeNotice? confirmedRepeatChangeNotice,
  }) {
    final earlyEvidenceTimeline =
        flags.isReady &&
            input.entryCountLoaded &&
            RecordEmptyArchiveGates.showEarlyEvidenceTimelineCompact(
              loaded: input.entryCountLoaded,
              entryCount: input.entryCount,
              isPostSave: input.isPostSave,
            )
        ? EarlyEvidenceTimelineEngine.build(
            entries: input.journalEntries,
            triggerCapturedMilestone: input.earlyEvidenceTriggerCaptured,
            helpfulActionCapturedMilestone: input.earlyEvidenceHelpfulCaptured,
          )
        : null;
    final showEarlyEvidenceTimeline = earlyEvidenceTimeline != null;
    final suppressEarlyRepeatPayoffCompetitors =
        confirmedRepeatTriggerPayoff != null ||
        confirmedRepeatHelpfulActionPayoff != null ||
        confirmedRepeatChangeNotice != null;
    final earlyFirstSignalOnRecord =
        flags.isReady && input.entryCountLoaded && !showEarlyEvidenceTimeline
        ? EarlyFirstSignalEngine.build(entries: input.journalEntries)
        : null;
    final returnTomorrowCueReady = flags.isReady && input.entryCountLoaded
        ? ReturnTomorrowCueEngine.buildReady(entries: input.journalEntries)
        : null;
    final returnDayFlowCandidate = flags.isReady && input.entryCountLoaded
        ? ReturnDayFlowEngine.build(entries: input.journalEntries)
        : null;
    final showReturnDayFlow = ReturnDayFlowGates.shouldShow(
      isReady: flags.isReady,
      isRecording: flags.isRecording,
      isPostSave: input.isPostSave,
      flow: returnDayFlowCandidate,
      dismissedToday: ReturnDayFlowEngine.shouldHideForDismissal(),
    );
    final showReturnTomorrowCueReady =
        ReturnTomorrowCueGates.shouldShowReady(
          isReady: flags.isReady,
          isRecording: flags.isRecording,
          isPostSave: input.isPostSave,
          cue: returnTomorrowCueReady,
        ) &&
        !showReturnDayFlow;
    final firstWeekProgressReady = flags.isReady && input.entryCountLoaded
        ? FirstWeekProgressEngine.buildReady(entries: input.journalEntries)
        : null;
    final showFirstWeekProgressReady = FirstWeekProgressGates.shouldShowReady(
      isReady: flags.isReady,
      isRecording: flags.isRecording,
      isPostSave: input.isPostSave,
      progress: firstWeekProgressReady,
      showReturnDayFlow: showReturnDayFlow,
      showReturnTomorrowCue: showReturnTomorrowCueReady,
    );
    final showEarlyReturnReminder =
        V1CapabilityRegistry.notifications &&
        flags.isReady &&
        input.entryCountLoaded &&
        !input.isPostSave &&
        !showReturnDayFlow &&
        !showReturnTomorrowCueReady &&
        input.earlyReturnReminderOffer &&
        !input.earlyReturnReminderHidden &&
        !suppressEarlyRepeatPayoffCompetitors &&
        EarlyArchiveReturnReminderGates.eligible(
          entryCount: input.entryCount,
          entries: input.journalEntries,
          hasRealTimeline:
              showEarlyEvidenceTimeline ||
              EarlyEvidenceTimelineEngine.build(
                    entries: input.journalEntries,
                    triggerCapturedMilestone:
                        input.earlyEvidenceTriggerCaptured,
                    helpfulActionCapturedMilestone:
                        input.earlyEvidenceHelpfulCaptured,
                  ) !=
                  null,
        ) &&
        (showEarlyEvidenceTimeline ||
            (earlyFirstSignalOnRecord?.showsConfirmedRepeat ?? false));
    final viewingConfirmedRepeatOnRecord =
        showEarlyEvidenceTimeline ||
        (earlyFirstSignalOnRecord?.showsConfirmedRepeat ?? false);
    final suppressConfirmedRepeatInlineFeedback =
        ConfirmedRepeatBetaFeedbackGates.suppressInlineAccuracyFeedback(
          state: ConfirmedRepeatBetaFeedbackStore.cached,
        );
    final showConfirmedRepeatBetaFeedback =
        flags.isReady &&
        input.entryCountLoaded &&
        ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces() &&
        input.entryCount >= ConfirmedRepeatBetaFeedbackGates.minEntryCount &&
        viewingConfirmedRepeatOnRecord;
    final repeatReturnChangeProof =
        flags.isReady && input.entryCountLoaded && !input.isPostSave
        ? RepeatReturnCheckEngine.changeProofForReady(
            entryCount: input.entryCount,
            viewingConfirmedRepeat: viewingConfirmedRepeatOnRecord,
            isRecording: flags.isRecording,
            isPostSave: input.isPostSave,
            records: RepeatReturnCheckStore.cached,
          )
        : null;
    final patternChangedCandidate =
        flags.isReady && input.entryCountLoaded && !input.isPostSave
        ? PatternChangedEngine.build(
            changeProof: repeatReturnChangeProof,
            records: RepeatReturnCheckStore.cached,
            entries: input.journalEntries,
          )
        : null;
    final patternChangedDismissed =
        patternChangedCandidate != null &&
        PatternChangedStore.isDismissed(
          entryId: patternChangedCandidate.entryId,
          type: patternChangedCandidate.type,
        );
    final confirmedRepeatThoughtMap =
        flags.isReady && input.entryCountLoaded && !input.isPostSave
        ? ConfirmedRepeatThoughtMapEngine.build(
            entries: input.journalEntries,
            triggerCapturedMilestone: input.earlyEvidenceTriggerCaptured,
            helpfulActionCapturedMilestone: input.earlyEvidenceHelpfulCaptured,
            returnChecks: RepeatReturnCheckStore.cached,
          )
        : null;
    final positivePattern =
        flags.isReady && input.entryCountLoaded && !input.isPostSave
        ? PositivePatternEngine.build(entries: input.journalEntries)
        : null;
    final helpfulActionAppearedCandidate =
        flags.isReady && input.entryCountLoaded && !input.isPostSave
        ? HelpfulActionAppearedEngine.build(
            entries: input.journalEntries,
            returnChecks: RepeatReturnCheckStore.cached,
            helpfulActionCapturedMilestone: input.earlyEvidenceHelpfulCaptured,
          )
        : null;
    final showHelpfulActionAppearedEligible =
        HelpfulActionAppearedGates.shouldShow(
          loaded: input.entryCountLoaded,
          entryCount: input.entryCount,
          isReady: flags.isReady,
          isRecording: flags.isRecording,
          isPostSave: input.isPostSave,
          isDegradedPostSave: false,
          viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
          hasConfirmedRepeatFoundation:
              EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                input.journalEntries,
              ),
          result: helpfulActionAppearedCandidate,
        );
    final positiveReinforcement =
        flags.isReady &&
            input.entryCountLoaded &&
            !input.isPostSave &&
            !showHelpfulActionAppearedEligible
        ? PositiveReinforcementEngine.build(
            positivePattern: positivePattern,
            entries: input.journalEntries,
            helpfulActionCapturedMilestone: input.earlyEvidenceHelpfulCaptured,
          )
        : null;
    final archiveSummaryCandidate =
        flags.isReady && input.entryCountLoaded && !input.isPostSave
        ? ArchiveSummaryEngine.build(
            entries: input.journalEntries,
            confirmedRepeat: earlyFirstSignalOnRecord,
            timeline: earlyEvidenceTimeline,
            changeProof: repeatReturnChangeProof,
            triggerCapturedMilestone: input.earlyEvidenceTriggerCaptured,
            helpfulActionCapturedMilestone: input.earlyEvidenceHelpfulCaptured,
            returnChecks: RepeatReturnCheckStore.cached,
            viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
          )
        : null;
    final archiveBeliefSurfaceCandidate =
        flags.isReady && input.entryCountLoaded && !input.isPostSave
        ? PatternNameEngine.applyDisplayLabels(
            const ArchiveBeliefSurfaceSource().resolve(
              input.journalEntries,
              confirmedRepeat: earlyFirstSignalOnRecord,
              changeProof: repeatReturnChangeProof,
              returnChecks: RepeatReturnCheckStore.cached,
              triggerCapturedMilestone: input.earlyEvidenceTriggerCaptured,
              helpfulActionCapturedMilestone:
                  input.earlyEvidenceHelpfulCaptured,
              viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
            ),
          )
        : ArchiveBeliefSurface.none;
    final patternNamePrompt =
        flags.isReady && input.entryCountLoaded && !input.isPostSave
        ? PatternNameEngine.buildPrompt(
            entries: input.journalEntries,
            confirmedRepeat: earlyFirstSignalOnRecord,
          )
        : null;
    final showArchiveCurrentBeliefEligible =
        ArchiveCurrentBeliefGates.shouldShow(
          loaded: input.entryCountLoaded,
          entryCount: input.entryCount,
          isReady: flags.isReady,
          isRecording: flags.isRecording,
          isPostSave: input.isPostSave,
          viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
          hasConfirmedRepeatFoundation:
              EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                input.journalEntries,
              ),
          hasCurrentBeliefSurface:
              archiveBeliefSurfaceCandidate.isPrimaryAfterFirstProof &&
              archiveBeliefSurfaceCandidate.shouldShow,
        );
    final dailyReturnReasonCandidate =
        flags.isReady && input.entryCountLoaded && !input.isPostSave
        ? DailyReturnReasonEngine.build(
            entries: input.journalEntries,
            changeProof: repeatReturnChangeProof,
            triggerCapturedMilestone: input.earlyEvidenceTriggerCaptured,
            helpfulActionCapturedMilestone: input.earlyEvidenceHelpfulCaptured,
            returnChecks: RepeatReturnCheckStore.cached,
            viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
          )
        : null;
    final hasChangeOverTimeProof = repeatReturnChangeProof != null;
    final postProofArchiveProof = PaywallTimingGates.hasArchiveProofFromEntries(
      entries: input.journalEntries,
      triggerCapturedMilestone: input.earlyEvidenceTriggerCaptured,
      helpfulActionCapturedMilestone: input.earlyEvidenceHelpfulCaptured,
      hasChangeOverTimeProof: hasChangeOverTimeProof,
    );
    final archiveSummaryVisibleForProGate = ArchiveSummaryGates.shouldShow(
      loaded: input.entryCountLoaded,
      entryCount: input.entryCount,
      isReady: flags.isReady,
      isRecording: flags.isRecording,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
      hasSummary: archiveSummaryCandidate != null,
    );
    final weeklyArchiveReviewVisibleForProGate =
        flags.isReady &&
        input.entryCountLoaded &&
        !input.isPostSave &&
        weekly_review_surface.WeeklyArchiveReviewEngine.shouldShowOnSurface(
          loaded: input.entryCountLoaded,
          isReady: flags.isReady,
          isRecording: flags.isRecording,
          isPostSave: input.isPostSave,
          entries: input.journalEntries,
          returnChecks: RepeatReturnCheckStore.cached,
        );
    final hasConfirmedRepeatForProGate =
        viewingConfirmedRepeatOnRecord &&
        ((earlyFirstSignalOnRecord?.showsConfirmedRepeat ?? false) ||
            showEarlyEvidenceTimeline);
    final privateArchiveReportForProGate =
        flags.isReady && input.entryCountLoaded && !input.isPostSave
        ? PrivateArchiveReportEngine.build(
            entries: input.journalEntries,
            triggerCapturedMilestone: input.earlyEvidenceTriggerCaptured,
            helpfulActionCapturedMilestone: input.earlyEvidenceHelpfulCaptured,
            returnChecks: RepeatReturnCheckStore.cached,
            viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
            isRecording: flags.isRecording,
            isPostSave: input.isPostSave,
          )
        : null;
    final privateArchiveReportPreviewForProGate =
        privateArchiveReportForProGate != null &&
        PrivateArchiveReportGates.shouldShow(
          loaded: input.entryCountLoaded,
          entryCount: input.entryCount,
          isReady: flags.isReady,
          isRecording: flags.isRecording,
          isPostSave: input.isPostSave,
          viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
          report: privateArchiveReportForProGate,
        ) &&
        PrivateArchiveReportGates.showPreviewNote(
          isPro: input.userProState.isPro,
        );
    final patternChangedForProGate =
        patternChangedCandidate != null &&
        viewingConfirmedRepeatOnRecord &&
        input.entryCount > FirstThreeSessionGates.minEntriesForUsefulArchive;
    final hasReturnCheckAnsweredForProGate =
        RepeatReturnCheckTrendEngine.hasAnsweredCheck(
          RepeatReturnCheckStore.cached,
        ) &&
        input.entryCount >= PaywallTimingGates.minFullArchiveHistoryEntryCount;
    final showPostProofProBridge =
        flags.isReady &&
        input.entryCountLoaded &&
        !input.isPostSave &&
        input.userProState.recordReturnProState != null &&
        PaywallTimingGates.showPostProofProBridge(
          entryCount: input.entryCount,
          resolved: input.userProState.recordReturnProState!.proBridgeResolved,
          isPro: input.userProState.isPro,
          hasArchiveProof: postProofArchiveProof,
          viewingConfirmedRepeatOrTimeline: hasConfirmedRepeatForProGate,
          hasChangeOverTimeProof: hasChangeOverTimeProof,
          isPostSave: input.isPostSave,
          hasArchiveSummary: archiveSummaryVisibleForProGate,
          hasWeeklyArchiveReview: weeklyArchiveReviewVisibleForProGate,
          hasPatternChanged: patternChangedForProGate,
          hasPrivateArchiveReportPreview: privateArchiveReportPreviewForProGate,
          hasReturnCheckAnswered: hasReturnCheckAnsweredForProGate,
        );
    final proofSurfaceLayout = ArchiveProofSurfaceLayout(
      confirmedRepeatCardVisible:
          earlyFirstSignalOnRecord?.showsConfirmedRepeat ?? false,
      timelineVisible: showEarlyEvidenceTimeline,
      changeProofVisible: repeatReturnChangeProof != null,
      proBridgeVisible: showPostProofProBridge,
      whyMattersVisible: ConfirmedRepeatWhyMattersGates.shouldShow(
        loaded: input.entryCountLoaded,
        viewingConfirmedRepeat: viewingConfirmedRepeatOnRecord,
        entryCount: input.entryCount,
        isReady: flags.isReady,
        isRecording: flags.isRecording,
        dismissed: ConfirmedRepeatWhyMattersStore.cachedDismissed,
      ),
      thoughtMapVisible: ConfirmedRepeatThoughtMapGates.shouldShow(
        loaded: input.entryCountLoaded,
        viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
        entryCount: input.entryCount,
        isReady: flags.isReady,
        isRecording: flags.isRecording,
        hasThoughtMap: confirmedRepeatThoughtMap != null,
      ),
      positiveReinforcementVisible: PositiveReinforcementGates.shouldShow(
        loaded: input.entryCountLoaded,
        entryCount: input.entryCount,
        isReady: flags.isReady,
        isRecording: flags.isRecording,
        hasPositivePattern: positiveReinforcement != null,
      ),
      helpfulActionAppearedVisible: showHelpfulActionAppearedEligible,
      patternChangedVisible: PatternChangedGates.shouldShow(
        loaded: input.entryCountLoaded,
        entryCount: input.entryCount,
        isReady: flags.isReady,
        isRecording: flags.isRecording,
        isPostSave: input.isPostSave,
        viewingConfirmedRepeat: viewingConfirmedRepeatOnRecord,
        patternChanged: patternChangedCandidate,
        dismissed: patternChangedDismissed,
      ),
      archiveSummaryVisible: ArchiveSummaryGates.shouldShow(
        loaded: input.entryCountLoaded,
        entryCount: input.entryCount,
        isReady: flags.isReady,
        isRecording: flags.isRecording,
        viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
        hasSummary: archiveSummaryCandidate != null,
      ),
      archiveCurrentBeliefVisible: showArchiveCurrentBeliefEligible,
    );
    final showArchiveSummary =
        proofSurfaceLayout.effectiveArchiveSummaryVisible;
    final archiveSummary = showArchiveSummary ? archiveSummaryCandidate : null;
    final showDailyReturnReason = DailyReturnReasonGates.shouldShow(
      loaded: input.entryCountLoaded,
      entryCount: input.entryCount,
      isReady: flags.isReady,
      isRecording: flags.isRecording,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
      hasReason: dailyReturnReasonCandidate != null,
    );
    final dailyReturnReason = showDailyReturnReason
        ? dailyReturnReasonCandidate
        : null;
    final archiveWatchingCandidate =
        flags.isReady && input.entryCountLoaded && !input.isPostSave
        ? ArchiveWatchingEngine.build(
            entries: input.journalEntries,
            changeProof: repeatReturnChangeProof,
            triggerCapturedMilestone: input.earlyEvidenceTriggerCaptured,
            helpfulActionCapturedMilestone: input.earlyEvidenceHelpfulCaptured,
            returnChecks: RepeatReturnCheckStore.cached,
            viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
          )
        : null;
    final archiveWatching =
        ArchiveWatchingGates.shouldShow(
          loaded: input.entryCountLoaded,
          entryCount: input.entryCount,
          isReady: flags.isReady,
          isRecording: flags.isRecording,
          viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
          archiveSummaryVisible: showArchiveSummary,
          hasWatching: archiveWatchingCandidate != null,
        )
        ? archiveWatchingCandidate
        : null;
    final weeklyArchiveReview =
        flags.isReady && input.entryCountLoaded && !input.isPostSave
        ? weekly_review_surface.WeeklyArchiveReviewEngine.build(
            entries: input.journalEntries,
            confirmedRepeat: earlyFirstSignalOnRecord,
            changeProof: repeatReturnChangeProof,
            triggerCapturedMilestone: input.earlyEvidenceTriggerCaptured,
            helpfulActionCapturedMilestone: input.earlyEvidenceHelpfulCaptured,
            returnChecks: RepeatReturnCheckStore.cached,
            viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
          )
        : null;
    final showWeeklyArchiveReview =
        weekly_review_surface.WeeklyArchiveReviewEngine.shouldShowOnSurface(
          loaded: input.entryCountLoaded,
          isReady: flags.isReady,
          isRecording: flags.isRecording,
          isPostSave: input.isPostSave,
          entries: input.journalEntries,
          returnChecks: RepeatReturnCheckStore.cached,
        );
    final privateArchiveReportCandidate =
        flags.isReady && input.entryCountLoaded && !input.isPostSave
        ? PrivateArchiveReportEngine.build(
            entries: input.journalEntries,
            triggerCapturedMilestone: input.earlyEvidenceTriggerCaptured,
            helpfulActionCapturedMilestone: input.earlyEvidenceHelpfulCaptured,
            returnChecks: RepeatReturnCheckStore.cached,
            viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
            isRecording: flags.isRecording,
            isPostSave: input.isPostSave,
          )
        : null;
    final showPrivateArchiveReport = PrivateArchiveReportGates.shouldShow(
      loaded: input.entryCountLoaded,
      entryCount: input.entryCount,
      isReady: flags.isReady,
      isRecording: flags.isRecording,
      isPostSave: input.isPostSave,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
      report: privateArchiveReportCandidate,
    );
    final showConfirmedRepeatWhyMatters =
        proofSurfaceLayout.effectiveWhyMattersVisible;
    final showConfirmedRepeatThoughtMap =
        proofSurfaceLayout.effectiveThoughtMapVisible;
    final showPositiveReinforcement =
        proofSurfaceLayout.effectivePositiveReinforcementVisible;
    final firstWeekLoopCandidate =
        flags.isReady && input.entryCountLoaded && !input.isPostSave
        ? FirstWeekLoopEngine.build(
            entries: input.journalEntries,
            returnChecks: RepeatReturnCheckStore.cached,
          )
        : null;
    final firstWeekLoopProGated = FirstWeekLoopGates.isProRequirementGated(
      valueMomentProBridgeVisible:
          input.valueMomentBridge != null && input.valueMomentBridge!.show,
      purchaseIntentReturnCueVisible: input.purchaseIntentCue != null,
    );
    final recordProofStack = RecordProofStackPolicy.decide(
      loaded: input.entryCountLoaded,
      entryCount: input.entryCount,
      isReady: flags.isReady,
      isPostSave: input.isPostSave,
      isRecording: flags.isRecording,
      archiveSummaryVisible: showArchiveSummary,
      hasEarlyFirstSignal:
          EarlyFirstSignalEngine.build(entries: input.journalEntries) != null,
      hasEarlyEvidenceTimeline: showEarlyEvidenceTimeline,
      patternChangedVisible: PatternChangedGates.shouldShow(
        loaded: input.entryCountLoaded,
        entryCount: input.entryCount,
        isReady: flags.isReady,
        isRecording: flags.isRecording,
        isPostSave: input.isPostSave,
        viewingConfirmedRepeat: viewingConfirmedRepeatOnRecord,
        patternChanged: patternChangedCandidate,
        dismissed: patternChangedDismissed,
      ),
      dailyReturnReasonEligible: showDailyReturnReason,
      weeklyReviewEligible: showWeeklyArchiveReview,
      privateReportEligible: showPrivateArchiveReport,
      whyMattersEligible: showConfirmedRepeatWhyMatters,
      thoughtMapEligible: showConfirmedRepeatThoughtMap,
      positiveReinforcementEligible: showPositiveReinforcement,
      helpfulActionAppearedEligible: showHelpfulActionAppearedEligible,
      changeProofEligible: repeatReturnChangeProof != null,
      firstWeekLoopEligible:
          firstWeekLoopCandidate != null && !firstWeekLoopProGated,
      proBridgeEligible: showPostProofProBridge,
      archiveCurrentBeliefEligible: showArchiveCurrentBeliefEligible,
    );
    final showPatternChanged = recordProofStack.showPatternChanged;
    final showArchiveCurrentBeliefOnRecord =
        recordProofStack.showArchiveCurrentBelief;
    final showEarlyEvidenceTimelineOnRecord =
        recordProofStack.showEarlyEvidenceTimeline;
    final showWeeklyArchiveReviewOnRecord =
        !V1FeatureFlags.enableV1Only &&
        recordProofStack.showWeeklyArchiveWeekReview;
    final showPrivateArchiveReportOnRecord =
        recordProofStack.showPrivateArchiveReport;
    final showDailyReturnReasonOnRecord =
        recordProofStack.showDailyReturnReason;
    final showPostProofProBridgeOnRecord = recordProofStack.showProBridge;
    return RecordProofStackSnapshot(
      earlyEvidenceTimeline: earlyEvidenceTimeline,
      showEarlyEvidenceTimeline: showEarlyEvidenceTimeline,
      suppressEarlyRepeatPayoffCompetitors:
          suppressEarlyRepeatPayoffCompetitors,
      earlyFirstSignalOnRecord: earlyFirstSignalOnRecord,
      returnTomorrowCueReady: returnTomorrowCueReady,
      returnDayFlowCandidate: returnDayFlowCandidate,
      showReturnDayFlow: showReturnDayFlow,
      showReturnTomorrowCueReady: showReturnTomorrowCueReady,
      firstWeekProgressReady: firstWeekProgressReady,
      showFirstWeekProgressReady: showFirstWeekProgressReady,
      showEarlyReturnReminder: showEarlyReturnReminder,
      viewingConfirmedRepeatOnRecord: viewingConfirmedRepeatOnRecord,
      suppressConfirmedRepeatInlineFeedback:
          suppressConfirmedRepeatInlineFeedback,
      showConfirmedRepeatBetaFeedback: showConfirmedRepeatBetaFeedback,
      repeatReturnChangeProof: repeatReturnChangeProof,
      patternChangedCandidate: patternChangedCandidate,
      patternChangedDismissed: patternChangedDismissed,
      confirmedRepeatThoughtMap: confirmedRepeatThoughtMap,
      positivePattern: positivePattern,
      helpfulActionAppearedCandidate: helpfulActionAppearedCandidate,
      showHelpfulActionAppearedEligible: showHelpfulActionAppearedEligible,
      positiveReinforcement: positiveReinforcement,
      archiveSummaryCandidate: archiveSummaryCandidate,
      archiveBeliefSurfaceCandidate: archiveBeliefSurfaceCandidate,
      patternNamePrompt: patternNamePrompt,
      showArchiveCurrentBeliefEligible: showArchiveCurrentBeliefEligible,
      dailyReturnReasonCandidate: dailyReturnReasonCandidate,
      hasChangeOverTimeProof: hasChangeOverTimeProof,
      postProofArchiveProof: postProofArchiveProof,
      archiveSummaryVisibleForProGate: archiveSummaryVisibleForProGate,
      weeklyArchiveReviewVisibleForProGate:
          weeklyArchiveReviewVisibleForProGate,
      hasConfirmedRepeatForProGate: hasConfirmedRepeatForProGate,
      privateArchiveReportForProGate: privateArchiveReportForProGate,
      privateArchiveReportPreviewForProGate:
          privateArchiveReportPreviewForProGate,
      patternChangedForProGate: patternChangedForProGate,
      hasReturnCheckAnsweredForProGate: hasReturnCheckAnsweredForProGate,
      showPostProofProBridge: showPostProofProBridge,
      proofSurfaceLayout: proofSurfaceLayout,
      showArchiveSummary: showArchiveSummary,
      archiveSummary: archiveSummary,
      showDailyReturnReason: showDailyReturnReason,
      dailyReturnReason: dailyReturnReason,
      archiveWatchingCandidate: archiveWatchingCandidate,
      archiveWatching: archiveWatching,
      weeklyArchiveReview: weeklyArchiveReview,
      showWeeklyArchiveReview: showWeeklyArchiveReview,
      privateArchiveReportCandidate: privateArchiveReportCandidate,
      showPrivateArchiveReport: showPrivateArchiveReport,
      showConfirmedRepeatWhyMatters: showConfirmedRepeatWhyMatters,
      showConfirmedRepeatThoughtMap: showConfirmedRepeatThoughtMap,
      showPositiveReinforcement: showPositiveReinforcement,
      firstWeekLoopCandidate: firstWeekLoopCandidate,
      firstWeekLoopProGated: firstWeekLoopProGated,
      recordProofStack: recordProofStack,
      showPatternChanged: showPatternChanged,
      showArchiveCurrentBeliefOnRecord: showArchiveCurrentBeliefOnRecord,
      showEarlyEvidenceTimelineOnRecord: showEarlyEvidenceTimelineOnRecord,
      showWeeklyArchiveReviewOnRecord: showWeeklyArchiveReviewOnRecord,
      showPrivateArchiveReportOnRecord: showPrivateArchiveReportOnRecord,
      showDailyReturnReasonOnRecord: showDailyReturnReasonOnRecord,
      showPostProofProBridgeOnRecord: showPostProofProBridgeOnRecord,
    );
  }

  static ({
    RecordCtaPolicyResolution readyCapturePolicy,
    bool showTesterMission,
    bool showRecordCaptureModes,
    bool testerMissionCompact,
    bool showTesterMissionFull,
    TesterMissionResult? testerMission,
    bool showThoughtMapRecordCta,
    bool showPositiveReinforcementRecordCta,
    bool showPatternChangedRecordCta,
    bool showArchiveSummaryRecordCta,
    bool showDailyReturnReasonRecordCta,
    bool showFirstWeekLoopRecordCta,
  })
  resolveCaptureCtas({
    required RecordSurfaceInput input,
    required RecordingPhase policyMic,
    required bool policyUserDenied,
    required RecordSurfaceFlags flags,
    required bool firstUseSimplifiedRecord,
    required bool showReturningWatchTargetFocusedUi,
    required bool showConfirmedRepeatThoughtMapOnRecord,
    required ThoughtMapResult? confirmedRepeatThoughtMap,
    required bool showPositiveReinforcementOnRecord,
    required PositiveReinforcementResult? positiveReinforcement,
    required bool showPatternChanged,
    required PatternChangedResult? patternChangedCandidate,
    required bool showArchiveSummaryOnRecord,
    required bool showDailyReturnReasonOnRecord,
    required bool showFirstWeekLoopOnRecord,
    required FirstWeekLoop? firstWeekLoopCandidate,
  }) {
    final readyCapturePolicy = RecordSurfaceCapturePolicy.resolve(
      input,
      micPhase: policyMic,
      userDeniedThisSession: policyUserDenied,
    );
    final showTesterMission =
        TesterMissionGates.shouldShow(
          dismissed: TesterMissionStore.isDismissed,
          ui: input.ui,
          entryCountLoaded: input.entryCountLoaded,
          isRecording: flags.isRecording,
          isPostSave: input.isPostSave,
        ) &&
        !firstUseSimplifiedRecord &&
        !showReturningWatchTargetFocusedUi;
    final showRecordCaptureModes =
        flags.isReady &&
        RecordCaptureModeEngine.shouldShow(
          loaded: input.entryCountLoaded,
          isReady: true,
          isPostSave: input.isPostSave,
        ) &&
        !firstUseSimplifiedRecord &&
        !showReturningWatchTargetFocusedUi;
    final testerMissionCompact =
        showTesterMission &&
        TesterMissionGates.useCompactPresentation(
          entryCount: input.entryCount,
          firstUseSimplifiedRecord: firstUseSimplifiedRecord,
        );
    final showTesterMissionFull = showTesterMission && !testerMissionCompact;
    final testerMission = showTesterMission
        ? TesterMissionEngine.build(
            entryCount: input.entryCount,
            entries: input.journalEntries,
            compactAtEntryZero: firstUseSimplifiedRecord,
            feedbackAnswered: CoreValueFeedbackStore.cached.answered,
          )
        : null;
    final showThoughtMapRecordCta =
        showConfirmedRepeatThoughtMapOnRecord &&
        confirmedRepeatThoughtMap?.firstMissingSection != null &&
        ConfirmedRepeatThoughtMapGates.showRecordMissingPieceCta(
          policy: readyCapturePolicy,
          hideCardRecordButtons:
              RecordSurfaceCapturePolicy.shouldHideCardRecordButtons(
                input,
                readyCapturePolicy,
              ),
          promoteMicCaptureActions:
              RecordSurfaceCapturePolicy.shouldPromoteMicCaptureActions(
                readyCapturePolicy,
              ),
        );
    final showPositiveReinforcementRecordCta =
        showPositiveReinforcementOnRecord &&
        positiveReinforcement != null &&
        PositiveReinforcementGates.showRecordAgainCta(
          policy: readyCapturePolicy,
          hideCardRecordButtons:
              RecordSurfaceCapturePolicy.shouldHideCardRecordButtons(
                input,
                readyCapturePolicy,
              ),
          promoteMicCaptureActions:
              RecordSurfaceCapturePolicy.shouldPromoteMicCaptureActions(
                readyCapturePolicy,
              ),
          isCompletion: positiveReinforcement.isCompletion,
        );
    final showPatternChangedRecordCta =
        showPatternChanged &&
        patternChangedCandidate != null &&
        PatternChangedGates.showRecordCta(
          policy: readyCapturePolicy,
          hideCardRecordButtons:
              RecordSurfaceCapturePolicy.shouldHideCardRecordButtons(
                input,
                readyCapturePolicy,
              ),
          promoteMicCaptureActions:
              RecordSurfaceCapturePolicy.shouldPromoteMicCaptureActions(
                readyCapturePolicy,
              ),
        );
    final showArchiveSummaryRecordCta =
        showArchiveSummaryOnRecord &&
        ArchiveSummaryGates.showRecordNextCta(
          policy: readyCapturePolicy,
          hideCardRecordButtons:
              RecordSurfaceCapturePolicy.shouldHideCardRecordButtons(
                input,
                readyCapturePolicy,
              ),
          promoteMicCaptureActions:
              RecordSurfaceCapturePolicy.shouldPromoteMicCaptureActions(
                readyCapturePolicy,
              ),
        );
    final showDailyReturnReasonRecordCta =
        showDailyReturnReasonOnRecord &&
        DailyReturnReasonGates.showRecordCta(
          policy: readyCapturePolicy,
          hideCardRecordButtons:
              RecordSurfaceCapturePolicy.shouldHideCardRecordButtons(
                input,
                readyCapturePolicy,
              ),
          promoteMicCaptureActions:
              RecordSurfaceCapturePolicy.shouldPromoteMicCaptureActions(
                readyCapturePolicy,
              ),
        );
    final showFirstWeekLoopRecordCta =
        showFirstWeekLoopOnRecord &&
        firstWeekLoopCandidate != null &&
        FirstWeekLoopGates.showRecordCta(
          policy: readyCapturePolicy,
          hideCardRecordButtons:
              RecordSurfaceCapturePolicy.shouldHideCardRecordButtons(
                input,
                readyCapturePolicy,
              ),
          promoteMicCaptureActions:
              RecordSurfaceCapturePolicy.shouldPromoteMicCaptureActions(
                readyCapturePolicy,
              ),
        );
    return (
      readyCapturePolicy: readyCapturePolicy,
      showTesterMission: showTesterMission,
      showRecordCaptureModes: showRecordCaptureModes,
      testerMissionCompact: testerMissionCompact,
      showTesterMissionFull: showTesterMissionFull,
      testerMission: testerMission,
      showThoughtMapRecordCta: showThoughtMapRecordCta,
      showPositiveReinforcementRecordCta: showPositiveReinforcementRecordCta,
      showPatternChangedRecordCta: showPatternChangedRecordCta,
      showArchiveSummaryRecordCta: showArchiveSummaryRecordCta,
      showDailyReturnReasonRecordCta: showDailyReturnReasonRecordCta,
      showFirstWeekLoopRecordCta: showFirstWeekLoopRecordCta,
    );
  }

  static ({
    RecordReadySurfaceBag readyBag,
    bool currentRelevanceQuestionActiveOnRecord,
    CorrectionMemoryResult? correctionMemoryCandidate,
    EvidenceWeightingResult? evidenceWeightingCandidate,
    ProofSpecificityResult proofSpecificityCandidate,
    PresentDayRelevanceResult? presentDayRelevanceCandidate,
    TimelinePositioningResult timelinePositioningCandidate,
    int otherEducationCardsOnRecord,
    int patternConfidenceEducationCount,
    PatternConfidenceExplanationResult? patternConfidenceExplanationCandidate,
    bool showConfirmedRepeatWhyMattersOnRecord,
    bool showConfirmedRepeatThoughtMapOnRecord,
    bool showPositiveReinforcementOnRecord,
    bool showHelpfulActionAppearedOnRecord,
    bool showChangeProofOnRecord,
    bool showFirstWeekLoopOnRecord,
    FirstProofPayoff? firstProofPayoffCandidate,
    ThreeDayChallengeState? threeDayChallengeCandidate,
    bool showThreeDayChallengeOnRecord,
    PatternConfidence? firstProofPatternConfidence,
    String firstProofTruthProofKey,
    bool showFirstProofTruth,
    FirstProofTruthAnswer? firstProofTruthAnswer,
    bool showFirstProofActionLoop,
    FirstProofActionLoopContent? firstProofActionLoopContent,
    bool showFirstProofMoment,
    bool postSaveHasConfirmedRepeat,
    bool postSaveHasFirstProof,
    bool postSaveDegraded,
    bool showCoreValueFeedbackOnRecordPostFirstProof,
    ReturnCheckPayoff? returnCheckPayoffCandidate,
    WhatChangedV2Prompt? whatChangedV2Prompt,
    WhatChangedV2Prompt? whatChangedV2Display,
    bool showWhatChangedV2,
    bool showWhatChangedV2Display,
    FirstMomentCaptureResult firstMomentCaptureCandidate,
    FirstSaveLiftResult firstSaveLiftCandidate,
    FirstSessionCaptureRepairResult? openingRepairOverride,
    FirstSessionLiftResult firstSessionLiftCandidate,
    SecondMomentReturnResult secondMomentReturnCandidate,
    ThreeMomentCompletionResult threeMomentCompletionCandidate,
    FirstRunPositioningResult firstRunPositioningCandidate,
    BetaTodaySummaryResult betaTodaySummaryCandidate,
    ArchiveTimelineSpineResult? archiveTimelineSpineCandidate,
    WhatToNoticeNextResult whatToNoticeNextCandidate,
    bool suppressLegacyEducationCardsForSpineOnRecord,
    TimelineProofMomentResult? timelineProofMomentCandidate,
    BetaTesterReportResult betaTesterReportCandidate,
    NotRelevantRecoveryResult notRelevantRecoveryCandidate,
    ProofQualityResponseResult proofQualityResponseTimelineCandidate,
    ProofQualityResponseResult proofQualityResponseSpineCandidate,
    BetaProofLiftResult betaProofLiftTimelineCandidate,
    ReturnAfterProofResult returnAfterProofRecordCandidate,
    ReturnAfterProofLiftV2Result returnAfterProofLiftV2Candidate,
    ProBridgeTimingLoosenSignals recordLoosenSignalsPreAudit,
    EvidenceAnchorExtractionResult recordEvidenceAnchorPreAudit,
    ProofQualityFeedbackState recordFeedbackStateForLift,
    BetaProofFeedbackType? timelineFeedbackType,
    BetaRepairLabVisibilityInput betaRepairLabInput,
    BetaRepairLabProPlacementResult betaRepairLabProPlacementResult,
    PricingValueFramingResult betaRepairLabPricingValueFramingResult,
    PaywallValueRepairResult betaRepairLabPaywallValueResult,
    bool hasProEngagementOnRecord,
    PricingValidationResult betaRepairLabPricingValidationResult,
    ProUnderstandingLiftVisibilityInput proUnderstandingLiftRecordReadyInput,
    ProVisibilityLiftResult? proVisibilityLiftRecordReadyResult,
    BetaActivationPathContext betaActivationPathPreAuditContext,
    BetaActivationPathResult betaActivationPathPreAuditResult,
    BetaFeedbackCaptureResult betaFeedbackCaptureRecordReadyPreAudit,
    ({int useful, int negative}) betaProofFeedbackCounts,
    bool betaProofFeedbackRowVisibleOnTimeline,
    ProofQualityRepairVisibilityInput proofQualityRepairInput,
    ProofQualityRepairResult proofQualityRepairResult,
    ProofFloorRescueInput proofFloorRescueInput,
    ProofFloorRescueResult proofFloorRescueResult,
    bool blocksProByProofFloorOnRecord,
    BetaRepairLabProofResult betaRepairLabProofResult,
    bool blocksProCardsByProofProtectionOnRecord,
    EvidenceTrailClarityResult betaRepairLabEvidenceTrailClarityResult,
  })
  resolveReadySurface({
    required RecordSurfaceInput input,
    required RecordSurfaceFlags flags,
    required List<JournalEntry> entriesAfterSave,
    required bool compact,
    required int postSaveEntryCount,
    required bool viewingConfirmedRepeatOnRecord,
    required RepeatReturnCheckChangeProof? repeatReturnChangeProof,
    required ArchiveBeliefSurface archiveBeliefSurfaceCandidate,
    required bool privateArchiveReportPreviewForProGate,
    required ArchiveProofSurfaceLayout proofSurfaceLayout,
    required bool showConfirmedRepeatWhyMatters,
    required bool showConfirmedRepeatThoughtMap,
    required bool showPositiveReinforcement,
    required FirstWeekLoop? firstWeekLoopCandidate,
    required bool firstWeekLoopProGated,
    required RecordProofStackDecision recordProofStack,
    required bool showPrivateArchiveReportOnRecord,
    required bool showPostProofProBridgeOnRecord,
    required bool firstProofPayoffSeenOnRecord,
    required bool isDegradedTranscriptOnRecord,
    required CurrentRelevanceState? currentRelevanceCandidate,
    required bool patternReviewInboxActiveOnRecord,
  }) {
    final readyBag = RecordReadySurfaceBag();
    readyBag.showCurrentRelevanceOnRecordReady =
        flags.isReady &&
        CurrentRelevanceEngine.shouldShowOnRecordReady(
          state: currentRelevanceCandidate,
          isZeroEntryState: input.entryCount == 0,
          isFirstRecordingState:
              input.entryCount <= 1 && !firstProofPayoffSeenOnRecord,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPostSaveDegradedState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    final currentRelevanceQuestionActiveOnRecord =
        CurrentRelevanceEngine.isQuestionActive(
          state: currentRelevanceCandidate,
          visible: readyBag.showCurrentRelevanceOnRecordReady,
        );
    final correctionMemoryCandidate = CorrectionMemoryEngine.build(
      entries: input.journalEntries,
      source: 'record',
    );
    readyBag.showCorrectionMemoryOnRecordReady =
        flags.isReady &&
        readyBag.showCurrentRelevanceOnRecordReady &&
        CorrectionMemoryEngine.shouldShowOnRecordReady(
          result: correctionMemoryCandidate,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    final evidenceWeightingCandidate = input.entryCount >= 3
        ? EvidenceWeightingEngine.build(
            entries: input.journalEntries,
            beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
          )
        : null;
    readyBag.showEvidenceWeightingOnRecordReady =
        flags.isReady &&
        EvidenceWeightingEngine.shouldShowOnRecordReady(
          result: evidenceWeightingCandidate,
          isZeroEntryState: input.entryCount == 0,
          isFirstRecordingState:
              input.entryCount <= 1 && !firstProofPayoffSeenOnRecord,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPostSaveDegradedState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    final proofSpecificityCandidate = input.entryCount >= 3
        ? ProofSpecificityEngine.build(
            entries: input.journalEntries,
            beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
            source: 'record',
            beliefEvidencePhrases:
                archiveBeliefSurfaceCandidate.evidencePhrases,
          )
        : ProofSpecificityEngine.build(
            entries: input.journalEntries,
            beliefSurfaceVisible: false,
            source: 'record',
          );
    readyBag.showProofSpecificityOnRecordReady =
        flags.isReady &&
        ProofSpecificityEngine.shouldShowOnRecordReady(
          result: proofSpecificityCandidate,
          isZeroEntryState: input.entryCount == 0,
          isFirstRecordingState:
              input.entryCount <= 1 && !firstProofPayoffSeenOnRecord,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    final presentDayRelevanceCandidate = input.entryCount >= 3
        ? PresentDayRelevanceEngine.build(
            entries: input.journalEntries,
            beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
            source: 'record',
          )
        : null;
    readyBag.showPresentDayRelevanceOnRecordReady =
        flags.isReady &&
        PresentDayRelevanceEngine.shouldShowOnRecordReady(
          result: presentDayRelevanceCandidate,
          isZeroEntryState: input.entryCount == 0,
          isFirstRecordingState:
              input.entryCount <= 1 && !firstProofPayoffSeenOnRecord,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPostSaveDegradedState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    readyBag.showCaptureFreedomLine =
        ProofSpecificityEngine.shouldShowCaptureFreedomLine(
          isReady: flags.isReady,
          isRecording: flags.isRecording,
          isPostSave: input.isPostSave,
          entryCount: input.entryCount,
        );
    final timelinePositioningCandidate = TimelinePositioningEngine.build(
      entries: input.journalEntries,
      beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
      source: 'record',
    );
    final otherEducationCardsOnRecord =
        TimelinePositioningEngine.countOtherEducationCards(
          captureFreedomLineVisible: readyBag.showCaptureFreedomLine,
          currentRelevanceVisible:
              readyBag.showCurrentRelevanceOnRecordReady &&
              currentRelevanceCandidate != null,
          evidenceWeightingVisible:
              readyBag.showEvidenceWeightingOnRecordReady &&
              evidenceWeightingCandidate != null,
          proofSpecificityVisible:
              readyBag.showProofSpecificityOnRecordReady &&
              proofSpecificityCandidate.shouldShow,
          presentDayRelevanceVisible:
              readyBag.showPresentDayRelevanceOnRecordReady &&
              presentDayRelevanceCandidate != null,
        );
    readyBag.showTimelinePositioningOnRecordReady =
        flags.isReady &&
        TimelinePositioningEngine.shouldShowOnRecordReady(
          result: timelinePositioningCandidate,
          entryCount: input.entryCount,
          otherEducationCardCount: otherEducationCardsOnRecord,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPostSaveDegradedState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    final patternConfidenceEducationCount =
        PatternConfidenceEngine.countOtherEducationCards(
          captureFreedomLineVisible: readyBag.showCaptureFreedomLine,
          timelinePositioningVisible:
              readyBag.showTimelinePositioningOnRecordReady,
          currentRelevanceVisible:
              readyBag.showCurrentRelevanceOnRecordReady &&
              currentRelevanceCandidate != null,
          correctionMemoryVisible:
              readyBag.showCorrectionMemoryOnRecordReady &&
              correctionMemoryCandidate != null,
          evidenceWeightingVisible:
              readyBag.showEvidenceWeightingOnRecordReady &&
              evidenceWeightingCandidate != null,
          proofSpecificityVisible:
              readyBag.showProofSpecificityOnRecordReady &&
              proofSpecificityCandidate.shouldShow,
          presentDayRelevanceVisible:
              readyBag.showPresentDayRelevanceOnRecordReady &&
              presentDayRelevanceCandidate != null,
        );
    final patternConfidenceExplanationCandidate =
        PatternConfidenceEngine.buildExplanation(
          entries: input.journalEntries,
          beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
          source: 'record',
          returnChecks: RepeatReturnCheckStore.cached,
          changeProof: repeatReturnChangeProof,
          viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
          helpfulActionCapturedMilestone: input.earlyEvidenceHelpfulCaptured,
        );
    readyBag.showPatternConfidenceExplanationOnRecordReady =
        flags.isReady &&
        PatternConfidenceEngine.shouldShowExplanationOnRecordReady(
          result: patternConfidenceExplanationCandidate,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
          otherEducationCardCount: patternConfidenceEducationCount,
        );
    readyBag.showProEvidenceValueOnRecordReady =
        showPostProofProBridgeOnRecord &&
        ProEvidenceValueEngine.shouldShowCard(
          ProEvidenceValueEngine.buildContext(
            surface: ProEvidenceValueSurface.recordReady,
            entryCount: input.entryCount,
            isPro: input.userProState.isPro,
            dismissed: ProEvidenceValueDismissStore.isDismissed(),
            entries: input.journalEntries,
            returnChecks: RepeatReturnCheckStore.cached,
            isZeroEntryState: input.entryCount == 0,
            isFirstRecordingState:
                input.entryCount <= 1 && !firstProofPayoffSeenOnRecord,
            isDegradedTranscriptState: isDegradedTranscriptOnRecord,
            currentRelevanceQuestionActive:
                currentRelevanceQuestionActiveOnRecord,
          ),
        );
    readyBag.showProBridgeVisibilityOnRecordReady = false;
    readyBag.showProEvidenceValuePrivateReportOnRecord =
        showPrivateArchiveReportOnRecord &&
        privateArchiveReportPreviewForProGate &&
        ProEvidenceValueEngine.shouldShowCard(
          ProEvidenceValueEngine.buildContext(
            surface: ProEvidenceValueSurface.privateReportPreview,
            entryCount: input.entryCount,
            isPro: input.userProState.isPro,
            dismissed: ProEvidenceValueDismissStore.isDismissed(),
            entries: input.journalEntries,
            returnChecks: RepeatReturnCheckStore.cached,
            isDegradedTranscriptState: isDegradedTranscriptOnRecord,
            privateReportPreviewVisible: true,
          ),
        );
    final showConfirmedRepeatWhyMattersOnRecord =
        recordProofStack.showConfirmedRepeatWhyMatters;
    final showConfirmedRepeatThoughtMapOnRecord =
        recordProofStack.showConfirmedRepeatThoughtMap;
    final showPositiveReinforcementOnRecord =
        recordProofStack.showPositiveReinforcement;
    final showHelpfulActionAppearedOnRecord =
        recordProofStack.showHelpfulActionAppeared;
    final showChangeProofOnRecord = recordProofStack.showChangeProof;
    final showFirstWeekLoopOnRecord = FirstWeekLoopGates.shouldShow(
      loaded: input.entryCountLoaded,
      entryCount: input.entryCount,
      isReady: flags.isReady,
      isRecording: flags.isRecording,
      isPostSave: input.isPostSave,
      isProRequirementGated: firstWeekLoopProGated,
      policyAllows: recordProofStack.showFirstWeekLoop,
      loop: firstWeekLoopCandidate,
    );
    final firstProofPayoffCandidate =
        flags.isDone && entriesAfterSave.isNotEmpty
        ? FirstProofPayoffEngine.build(entries: entriesAfterSave)
        : null;
    readyBag.showFirstProofPayoff = FirstProofPayoffGates.shouldShow(
      isPostSaveDone: flags.isDone,
      entryCount: postSaveEntryCount,
      isDegradedPostSave:
          entriesAfterSave.isNotEmpty &&
          VoiceCaptureQuality.isDegradedVoiceCapture(entriesAfterSave.last),
      payoff: firstProofPayoffCandidate,
    );
    final threeDayChallengeCandidate = flags.isReady && input.entryCountLoaded
        ? ThreeDayChallengeEngine.build(entries: input.journalEntries)
        : null;
    final showThreeDayChallengeOnRecord = ThreeDayChallengeGates.shouldShow(
      isReady: flags.isReady,
      isRecording: flags.isRecording,
      isPostSave: input.isPostSave,
      isDegradedTranscriptState:
          ThreeDayChallengeEngine.shouldHideForDegradedTranscript(
            input.journalEntries,
          ),
      firstProofPayoffVisible:
          readyBag.showFirstProofPayoff && firstProofPayoffCandidate != null,
      challenge: threeDayChallengeCandidate,
    );
    final firstProofPatternConfidence =
        readyBag.showFirstProofPayoff && firstProofPayoffCandidate != null
        ? PatternConfidenceEngine.build(
            entries: entriesAfterSave,
            returnChecks: RepeatReturnCheckStore.cached,
            viewingConfirmedRepeatOrTimeline: true,
            hideNotEnoughYet: true,
          )
        : null;
    final firstProofTruthProofKey = readyBag.showFirstProofPayoff
        ? FirstProofTruthGates.proofKeyForEntries(entriesAfterSave)
        : '';
    final showFirstProofTruth = FirstProofTruthGates.shouldShow(
      showFirstProofPayoff: readyBag.showFirstProofPayoff,
      payoff: firstProofPayoffCandidate,
      entries: entriesAfterSave,
      proofKey: firstProofTruthProofKey,
      hasAnsweredForProof:
          firstProofTruthProofKey.isNotEmpty &&
          FirstProofTruthStore.hasAnswered(firstProofTruthProofKey),
    );
    final firstProofTruthAnswer = firstProofTruthProofKey.isNotEmpty
        ? FirstProofTruthStore.answerFor(firstProofTruthProofKey)
        : null;
    final showFirstProofActionLoop = FirstProofActionLoopGates.shouldShow(
      showFirstProofPayoff: readyBag.showFirstProofPayoff,
      payoff: firstProofPayoffCandidate,
      proofKey: firstProofTruthProofKey,
      hasAnsweredForProof:
          firstProofTruthProofKey.isNotEmpty &&
          FirstProofTruthStore.hasAnswered(firstProofTruthProofKey),
    );
    final firstProofActionLoopContent =
        showFirstProofActionLoop &&
            firstProofTruthAnswer != null &&
            firstProofPayoffCandidate != null
        ? FirstProofActionLoopEngine.build(
            answer: firstProofTruthAnswer,
            entries: entriesAfterSave,
            payoff: firstProofPayoffCandidate,
          )
        : null;
    final showFirstProofMoment = readyBag.showFirstProofPayoff;
    final postSaveHasConfirmedRepeat =
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entriesAfterSave);
    final postSaveHasFirstProof = CoreValueFeedbackGates.hasFirstProof(
      entryCount: postSaveEntryCount,
      hasConfirmedRepeatFoundation: postSaveHasConfirmedRepeat,
    );
    final postSaveDegraded =
        entriesAfterSave.isNotEmpty &&
        VoiceCaptureQuality.isDegradedVoiceCapture(entriesAfterSave.last);
    final showCoreValueFeedbackOnRecordPostFirstProof =
        !readyBag.showFirstProofPayoff &&
        CoreValueFeedbackGates.shouldShowOnRecordPostFirstProof(
          showFirstProofMoment: showFirstProofMoment,
          isPostSaveDone: flags.isDone,
          entryCount: postSaveEntryCount,
          hasConfirmedRepeatFoundation: postSaveHasConfirmedRepeat,
          isRecording: flags.isRecording,
          isDegradedPostSave: postSaveDegraded,
          isProPaywallVisible: false,
        );
    final returnCheckPayoffCandidate =
        flags.isDone && entriesAfterSave.isNotEmpty
        ? ReturnCheckPayoffEngine.build(
            entries: entriesAfterSave,
            returnChecks: RepeatReturnCheckStore.cached,
          )
        : null;
    final whatChangedV2Prompt = flags.isDone && entriesAfterSave.isNotEmpty
        ? WhatChangedV2Engine.buildPrompt(
            entries: entriesAfterSave,
            returnChecks: RepeatReturnCheckStore.cached,
          )
        : null;
    final whatChangedV2Display = flags.isDone && entriesAfterSave.isNotEmpty
        ? WhatChangedV2Engine.buildPostSaveDisplay(
            entries: entriesAfterSave,
            returnChecks: RepeatReturnCheckStore.cached,
          )
        : null;
    final showWhatChangedV2 = WhatChangedV2Engine.shouldShowOnPostSave(
      isPostSaveDone: flags.isDone,
      isDegradedPostSave:
          entriesAfterSave.isNotEmpty &&
          VoiceCaptureQuality.isDegradedVoiceCapture(entriesAfterSave.last),
      showFirstProofMoment: showFirstProofMoment,
      prompt: whatChangedV2Prompt,
    );
    final showWhatChangedV2Display =
        WhatChangedV2Engine.shouldShowPostSaveDisplay(
          isPostSaveDone: flags.isDone,
          isDegradedPostSave:
              entriesAfterSave.isNotEmpty &&
              VoiceCaptureQuality.isDegradedVoiceCapture(entriesAfterSave.last),
          showFirstProofMoment: showFirstProofMoment,
          display: whatChangedV2Display,
        );
    readyBag.showOpenCapturePromptChips = OpenCaptureEngine.shouldShow(
      isReady: flags.isReady,
      isRecording: flags.isRecording,
      isPostSave: input.isPostSave,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      firstProofPayoffVisible:
          readyBag.showFirstProofPayoff && firstProofPayoffCandidate != null,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
      isPermissionBlocked: flags.isPermissionBlocked,
      entryCount: input.entryCount,
    );
    readyBag.showLowFrictionReturnCard = LowFrictionReturnEngine.shouldShow(
      isReady: flags.isReady,
      isRecording: flags.isRecording,
      isPostSave: input.isPostSave,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      firstProofPayoffVisible:
          readyBag.showFirstProofPayoff && firstProofPayoffCandidate != null,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
      isPermissionBlocked: flags.isPermissionBlocked,
      entryCount: input.entryCount,
      entries: input.journalEntries,
      dismissedForToday: LowFrictionReturnStore.isDismissedToday,
    );
    final firstMomentCaptureCandidate = FirstMomentCaptureEngine.build(
      entryCount: input.entryCount,
      source: 'record',
    );
    final firstSaveLiftCandidate = FirstSaveLiftEngine.build(
      entryCount: input.entryCount,
      source: 'record',
    );
    readyBag.firstSessionCaptureRepairCandidate =
        FirstSessionProofRepairEngine.buildCapture(
          entryCount: input.entryCount,
          source: 'record',
        );
    final openingRepairOverride = BetaRepairLabEngine.openingCaptureOverride(
      base: readyBag.firstSessionCaptureRepairCandidate,
      betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
    );
    if (openingRepairOverride != null) {
      readyBag.firstSessionCaptureRepairCandidate = openingRepairOverride;
    }
    readyBag.showFirstSessionCaptureRepairCard =
        FirstSessionProofRepairEngine.shouldShowCapture(
          result: readyBag.firstSessionCaptureRepairCandidate,
          betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
          isReady: flags.isReady,
          isRecording: flags.isRecording,
          isPostSave: input.isPostSave,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPermissionBlocked: flags.isPermissionBlocked,
          entryCount: input.entryCount,
        );
    final firstSessionLiftCandidate = FirstSessionLiftEngine.build(
      entryCount: input.entryCount,
      source: 'record',
    );
    readyBag.showFirstSessionLiftCard = FirstSessionLiftEngine.shouldShow(
      result: firstSessionLiftCandidate,
      betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
      isReady: flags.isReady,
      isRecording: flags.isRecording,
      isPostSave: input.isPostSave,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      isPermissionBlocked: flags.isPermissionBlocked,
      entryCount: input.entryCount,
    );
    readyBag.showFirstSaveLiftCard = FirstSaveLiftEngine.shouldShow(
      result: firstSaveLiftCandidate,
      betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
      isReady: flags.isReady,
      isRecording: flags.isRecording,
      isPostSave: input.isPostSave,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      isPermissionBlocked: flags.isPermissionBlocked,
      entryCount: input.entryCount,
    );
    if (BetaRepairLabEngine.suppressFirstSessionLiftWhenOpeningRepairActive(
      betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
      showOpeningRepair: readyBag.showFirstSessionCaptureRepairCard,
    )) {
      readyBag.showFirstSessionLiftCard = false;
      readyBag.showFirstSaveLiftCard = false;
    }
    readyBag.showFirstMomentCaptureCard = FirstMomentCaptureEngine.shouldShow(
      result: firstMomentCaptureCandidate,
      isReady: flags.isReady,
      isRecording: flags.isRecording,
      isPostSave: input.isPostSave,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      firstProofPayoffVisible:
          readyBag.showFirstProofPayoff && firstProofPayoffCandidate != null,
      isPermissionBlocked: flags.isPermissionBlocked,
      entryCount: input.entryCount,
    );
    final secondMomentReturnCandidate = SecondMomentReturnEngine.build(
      entries: input.journalEntries,
      source: 'record',
    );
    readyBag.showSecondMomentReturnCard = SecondMomentReturnEngine.shouldShow(
      result: secondMomentReturnCandidate,
      isReady: flags.isReady,
      isRecording: flags.isRecording,
      isPostSave: input.isPostSave,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      firstProofPayoffVisible:
          readyBag.showFirstProofPayoff && firstProofPayoffCandidate != null,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
      entryCount: input.entryCount,
    );
    final threeMomentCompletionCandidate = ThreeMomentCompletionEngine.build(
      entryCount: input.entryCount,
      source: 'record',
    );
    readyBag.showThreeMomentCompletionCard =
        ThreeMomentCompletionEngine.shouldShow(
          result: threeMomentCompletionCandidate,
          isReady: flags.isReady,
          isRecording: flags.isRecording,
          isPostSave: input.isPostSave,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
          isPermissionBlocked: flags.isPermissionBlocked,
          entryCount: input.entryCount,
          dismissedForToday: ThreeMomentCompletionStore.isDismissedToday,
        );
    final firstRunPositioningCandidate = FirstRunPositioningEngine.build(
      entryCount: input.entryCount,
      source: 'record',
    );
    readyBag.showFirstRunPositioningCard = FirstRunPositioningEngine.shouldShow(
      result: firstRunPositioningCandidate,
      isReady: flags.isReady,
      isRecording: flags.isRecording,
      isPostSave: input.isPostSave,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      firstProofSeen: firstProofPayoffSeenOnRecord,
      isPermissionBlocked: flags.isPermissionBlocked,
      entryCount: input.entryCount,
    );
    final betaTodaySummaryCandidate = BetaTodaySummaryEngine.build(
      entries: input.journalEntries,
      beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
      source: 'record',
    );
    readyBag.showBetaTodaySummaryCard = BetaTodaySummaryEngine.shouldShow(
      result: betaTodaySummaryCandidate,
      isReady: flags.isReady,
      isRecording: flags.isRecording,
      isPostSave: input.isPostSave,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      firstProofPayoffVisible:
          readyBag.showFirstProofPayoff && firstProofPayoffCandidate != null,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
    );
    final archiveTimelineSpineCandidate = input.entryCount >= 3
        ? ArchiveTimelineSpineEngine.build(
            entries: input.journalEntries,
            beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
            source: 'record',
          )
        : null;
    final whatToNoticeNextCandidate = WhatToNoticeNextEngine.build(
      entries: input.journalEntries,
      beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
      source: 'record',
      timelineSpine: archiveTimelineSpineCandidate,
    );
    readyBag.showWhatToNoticeNextCard = WhatToNoticeNextEngine.shouldShow(
      result: whatToNoticeNextCandidate,
      isReady: flags.isReady,
      isRecording: flags.isRecording,
      isPostSave: input.isPostSave,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      firstProofPayoffVisible:
          readyBag.showFirstProofPayoff && firstProofPayoffCandidate != null,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
      entryCount: input.entryCount,
      lowFrictionReturnVisible: readyBag.showLowFrictionReturnCard,
      betaTodaySummaryVisible: readyBag.showBetaTodaySummaryCard,
      openCapturePromptChipsVisible: readyBag.showOpenCapturePromptChips,
    );
    readyBag.showArchiveTimelineSpineOnRecord =
        flags.isReady &&
        ArchiveTimelineSpineEngine.shouldShowOnRecordReady(
          result: archiveTimelineSpineCandidate,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPostSaveDegradedState: false,
          firstProofPayoffVisible:
              readyBag.showFirstProofPayoff &&
              firstProofPayoffCandidate != null,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    final suppressLegacyEducationCardsForSpineOnRecord =
        ArchiveTimelineSpineEngine.suppressLegacyEducationCards(
          result: archiveTimelineSpineCandidate,
          visible: readyBag.showArchiveTimelineSpineOnRecord,
        );
    final timelineProofMomentCandidate = archiveTimelineSpineCandidate != null
        ? TimelineProofMomentEngine.buildFromSpine(
            spine: archiveTimelineSpineCandidate,
            entries: input.journalEntries,
            source: 'record',
          )
        : null;
    readyBag.showTimelineProofMomentOnRecord =
        TimelineProofMomentEngine.shouldShowOnRecordReady(
          result: timelineProofMomentCandidate,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    final betaTesterReportCandidate = BetaTesterReportEngine.build(
      entries: input.journalEntries,
      beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
      source: 'record',
      timelineSpine: archiveTimelineSpineCandidate,
    );
    readyBag.showBetaTesterReportOnRecord = BetaTesterReportEngine.shouldShow(
      result: betaTesterReportCandidate,
      isReady: flags.isReady,
      isRecording: flags.isRecording,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      firstProofPayoffVisible:
          readyBag.showFirstProofPayoff && firstProofPayoffCandidate != null,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
    );
    readyBag.showProBridgeVisibilityOnRecordReady = false;
    final notRelevantRecoveryCandidate = NotRelevantRecoveryEngine.build(
      entries: input.journalEntries,
      source: 'record',
    );
    final proofQualityResponseTimelineCandidate =
        ProofQualityResponseEngine.build(
          entries: input.journalEntries,
          surface: ProofQualityResponseSurface.timelineProofMoment,
          source: 'record',
          beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
        );
    final proofQualityResponseSpineCandidate = ProofQualityResponseEngine.build(
      entries: input.journalEntries,
      surface: ProofQualityResponseSurface.archiveTimelineSpine,
      source: 'record',
      beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
    );
    final betaProofLiftTimelineCandidate = BetaProofLiftEngine.build(
      entries: input.journalEntries,
      surface: BetaProofLiftSurface.timelineProofMoment,
      source: 'record',
      beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
      beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
      timelineProof: timelineProofMomentCandidate,
    );
    final returnAfterProofRecordCandidate = ReturnAfterProofEngine.build(
      entries: input.journalEntries,
      source: 'record',
      firstProofSeen: firstProofPayoffSeenOnRecord,
      timelineProofVisible:
          readyBag.showTimelineProofMomentOnRecord &&
          timelineProofMomentCandidate != null,
      betaTesterReportVisible: readyBag.showBetaTesterReportOnRecord,
    );
    readyBag.showReturnAfterProofStrengthenedOnRecordReady =
        ReturnAfterProofEngine.shouldShowStrengthenedOnRecordReady(
          result: returnAfterProofRecordCandidate,
          isReady: flags.isReady,
          isRecording: flags.isRecording,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
          firstProofSeen: firstProofPayoffSeenOnRecord,
          timelineProofVisible:
              readyBag.showTimelineProofMomentOnRecord &&
              timelineProofMomentCandidate != null,
          dismissedForToday: ReturnAfterProofStore.isDismissedToday,
        );
    readyBag.showReturnAfterProofGenericOnRecordReady =
        ReturnAfterProofEngine.shouldShowGenericOnRecordReady(
          result: returnAfterProofRecordCandidate,
          isReady: flags.isReady,
          isRecording: flags.isRecording,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
          firstProofSeen: firstProofPayoffSeenOnRecord,
          timelineProofVisible:
              readyBag.showTimelineProofMomentOnRecord &&
              timelineProofMomentCandidate != null,
          betaTesterReportVisible: readyBag.showBetaTesterReportOnRecord,
          dismissedForToday: ReturnAfterProofStore.isDismissedToday,
        );
    readyBag.showReturnAfterProofOnRecordReady =
        readyBag.showReturnAfterProofStrengthenedOnRecordReady ||
        readyBag.showReturnAfterProofGenericOnRecordReady;
    final returnAfterProofLiftV2Candidate = ReturnAfterProofLiftV2Engine.build(
      entries: input.journalEntries,
      source: 'record',
      firstProofSeen: firstProofPayoffSeenOnRecord,
      timelineProofVisible:
          readyBag.showTimelineProofMomentOnRecord &&
          timelineProofMomentCandidate != null,
    );
    readyBag.showReturnAfterProofLiftV2OnRecordReady =
        ReturnAfterProofLiftV2Engine.shouldShow(
          result: returnAfterProofLiftV2Candidate,
          isReady: flags.isReady,
          isRecording: flags.isRecording,
          isPostSave: false,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    final recordLoosenSignalsPreAudit =
        ProBridgeTimingLoosenEngine.resolveSignals(
          entries: input.journalEntries,
          source: 'record_ready',
          beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
          beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
        );
    final recordEvidenceAnchorPreAudit = EvidenceAnchorEngine.build(
      entries: input.journalEntries,
      beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
      source: 'record_ready',
      beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
    );
    final recordFeedbackStateForLift =
        ProMomentTimingEngine.resolveFeedbackState(
          entries: input.journalEntries,
          surface: ProofQualityResponseSurface.timelineProofMoment,
        );
    final timelineFeedbackType = BetaProofFeedbackStore.recordFor(
      BetaProofFeedbackSurface.timelineProofMoment,
    ).feedbackType;
    final betaRepairLabInput = BetaRepairLabVisibilityInput(
      mode: BetaRepairLabStore.activeMode,
      entryCount: input.entryCount,
      source: 'record_ready',
      isPro: input.userProState.isPro,
      isRecording: flags.isRecording,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
      hasTimelineProofVisible:
          readyBag.showTimelineProofMomentOnRecord &&
          timelineProofMomentCandidate != null,
      hasConfirmedRepeat: EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
        input.journalEntries,
      ),
      confidenceLevel:
          recordLoosenSignalsPreAudit.confidenceLevel ??
          ProofConfidenceLevel.watchOnly,
      hasUsefulProofFeedback:
          timelineFeedbackType == BetaProofFeedbackType.useful,
      feedbackType: timelineFeedbackType,
      isNegativeFeedback:
          timelineFeedbackType == BetaProofFeedbackType.tooVague ||
          timelineFeedbackType == BetaProofFeedbackType.notRelevant,
      betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
    );
    readyBag.showBetaRepairLabProPlacementOnRecord =
        BetaRepairLabEngine.shouldShowProPlacement(input: betaRepairLabInput);
    final betaRepairLabProPlacementResult =
        readyBag.showBetaRepairLabProPlacementOnRecord
        ? BetaRepairLabEngine.buildProPlacement(input: betaRepairLabInput)
        : BetaRepairLabProPlacementResult.hidden;
    readyBag.showBetaRepairLabPricingValueFramingOnRecord =
        PricingValueFramingEngine.shouldShow(input: betaRepairLabInput);
    final betaRepairLabPricingValueFramingResult =
        readyBag.showBetaRepairLabPricingValueFramingOnRecord
        ? PricingValueFramingEngine.build(input: betaRepairLabInput)
        : PricingValueFramingResult.hidden;
    readyBag.showBetaRepairLabPaywallValueOnRecord =
        PaywallValueRepairEngine.shouldShow(input: betaRepairLabInput);
    final betaRepairLabPaywallValueResult =
        readyBag.showBetaRepairLabPaywallValueOnRecord
        ? PaywallValueRepairEngine.build(input: betaRepairLabInput)
        : PaywallValueRepairResult.hidden;
    final hasProEngagementOnRecord =
        input.betaActivationLoopCounts.paywallSeen > 0 ||
        input.betaActivationLoopCounts.purchaseTapped > 0 ||
        input.betaActivationLoopCounts.proBoundarySeen > 0;
    readyBag.showBetaRepairLabPricingValidationOnRecord =
        PricingValidationEngine.shouldShow(
          input: betaRepairLabInput,
          hasProEngagement: hasProEngagementOnRecord,
        );
    readyBag.showBetaRepairLabEvidenceTrailClarityOnRecord = false;
    final betaRepairLabPricingValidationResult =
        readyBag.showBetaRepairLabPricingValidationOnRecord
        ? PricingValidationEngine.build(
            input: betaRepairLabInput,
            hasProEngagement: hasProEngagementOnRecord,
          )
        : PricingValidationResult.hidden;
    final proUnderstandingLiftRecordReadyInput =
        ProUnderstandingLiftVisibilityInput(
          surface: ProUnderstandingLiftSurface.recordReady,
          source: 'record_ready',
          entryCount: input.entryCount,
          isPro: input.userProState.isPro,
          hasUsefulProof:
              recordFeedbackStateForLift == ProofQualityFeedbackState.useful,
          confidenceLevel:
              recordLoosenSignalsPreAudit.confidenceLevel ??
              ProofConfidenceLevel.watchOnly,
          feedbackState: recordFeedbackStateForLift,
          hasProEngagement: hasProEngagementOnRecord,
          hasFreshReturnAfterCorrection:
              recordLoosenSignalsPreAudit.hasFreshReturnAfterCorrection,
          hasChangeAnchor: recordEvidenceAnchorPreAudit.hasChangeAnchor,
          isRecording: flags.isRecording,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    readyBag.showProUnderstandingLiftOnRecordReady =
        ProUnderstandingLiftEngine.shouldShowCard(
          input: proUnderstandingLiftRecordReadyInput,
        );
    readyBag.showProVisibilityLiftOnRecordReady =
        ProVisibilityLiftEngine.shouldShowCard(
          entryCount: input.entryCount,
          isPro: input.userProState.isPro,
          hasUsefulProof:
              recordFeedbackStateForLift == ProofQualityFeedbackState.useful,
          confidenceLevel:
              recordLoosenSignalsPreAudit.confidenceLevel ??
              ProofConfidenceLevel.watchOnly,
          feedbackState: recordFeedbackStateForLift,
          hasPaywallSeen: input.betaActivationLoopCounts.paywallSeen > 0,
          hasFreshReturnAfterCorrection:
              recordLoosenSignalsPreAudit.hasFreshReturnAfterCorrection,
          hasChangeAnchor: recordEvidenceAnchorPreAudit.hasChangeAnchor,
          isRecording: flags.isRecording,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    readyBag.proUnderstandingLiftRecordReadyResult =
        readyBag.showProUnderstandingLiftOnRecordReady
        ? ProUnderstandingLiftEngine.build(
            input: proUnderstandingLiftRecordReadyInput,
          )
        : null;
    if (readyBag.proUnderstandingLiftRecordReadyResult != null) {
      readyBag.proUnderstandingLiftRecordReadyResult =
          BetaRepairLabEngine.applyProExplanationCopy(
            base: readyBag.proUnderstandingLiftRecordReadyResult!,
            betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
          ) ??
          readyBag.proUnderstandingLiftRecordReadyResult;
    }
    final proVisibilityLiftRecordReadyResult =
        readyBag.showProVisibilityLiftOnRecordReady
        ? ProVisibilityLiftEngine.build(
            surface: ProVisibilityLiftSurface.recordReady,
            source: 'record_ready',
            entryCount: input.entryCount,
            isPro: input.userProState.isPro,
            hasUsefulProof:
                recordFeedbackStateForLift == ProofQualityFeedbackState.useful,
            confidenceLevel:
                recordLoosenSignalsPreAudit.confidenceLevel ??
                ProofConfidenceLevel.watchOnly,
            feedbackState: recordFeedbackStateForLift,
            hasPaywallSeen: input.betaActivationLoopCounts.paywallSeen > 0,
            hasFreshReturnAfterCorrection:
                recordLoosenSignalsPreAudit.hasFreshReturnAfterCorrection,
            hasChangeAnchor: recordEvidenceAnchorPreAudit.hasChangeAnchor,
            isRecording: flags.isRecording,
            isDegradedTranscriptState: isDegradedTranscriptOnRecord,
            isPostSaveDegradedState: false,
            whatChangedQuestionActive: showWhatChangedV2,
            patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
          )
        : null;
    readyBag.showProofQualityResponseOnRecordReady =
        flags.isReady &&
        proofQualityResponseTimelineCandidate.shouldShow &&
        ProofQualityResponseEngine.shouldRender(
          result: proofQualityResponseTimelineCandidate,
          parentVisible: true,
          timelineProofVisible:
              readyBag.showTimelineProofMomentOnRecord &&
              timelineProofMomentCandidate != null,
          firstProofPayoffVisible: false,
          isRecording: flags.isRecording,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    readyBag.showNotRelevantRecoveryOnRecordReady =
        flags.isReady &&
        notRelevantRecoveryCandidate.shouldShow &&
        NotRelevantRecoveryEngine.shouldRender(
          result: notRelevantRecoveryCandidate,
          parentVisible: true,
          isRecording: flags.isRecording,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    readyBag.showBetaProofLiftOnRecordReady =
        flags.isReady &&
        readyBag.showTimelineProofMomentOnRecord &&
        timelineProofMomentCandidate != null &&
        BetaProofLiftEngine.shouldRender(
          result: betaProofLiftTimelineCandidate,
          qualityResponse: proofQualityResponseTimelineCandidate,
          parentVisible: true,
          timelineProofVisible: true,
          firstProofPayoffVisible: false,
          isRecording: flags.isRecording,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    readyBag.showProBridgeVisibilityOnRecordReady =
        showPostProofProBridgeOnRecord &&
        ProBridgeVisibilityEngine.shouldShow(
          input: ProBridgeTimingLoosenEngine.enrichVisibilityInput(
            base: ProBridgeVisibilityInput(
              surface: ProBridgeVisibilitySurface.recordReady,
              source: 'record_ready',
              entryCount: input.entryCount,
              isPro: input.userProState.isPro,
              postProofProBridgeEnabled: showPostProofProBridgeOnRecord,
              hasFirstProof:
                  firstProofPayoffSeenOnRecord ||
                  EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                    input.journalEntries,
                  ),
              isRecording: flags.isRecording,
              isZeroEntryState: input.entryCount == 0,
              isFirstRecordingState:
                  input.entryCount <= 1 && !firstProofPayoffSeenOnRecord,
              isDegradedTranscriptState: isDegradedTranscriptOnRecord,
              hasTimelineProofVisible:
                  readyBag.showTimelineProofMomentOnRecord &&
                  timelineProofMomentCandidate != null,
              hasBetaTesterReportVisible: readyBag.showBetaTesterReportOnRecord,
              hasCorrectionMemoryVisible:
                  readyBag.showCorrectionMemoryOnRecordReady &&
                  correctionMemoryCandidate != null,
              feedbackState: ProMomentTimingEngine.resolveFeedbackState(
                entries: input.journalEntries,
                surface: ProofQualityResponseSurface.timelineProofMoment,
              ),
              whatChangedQuestionActive: showWhatChangedV2,
              patternReviewInboxHasActiveItems:
                  patternReviewInboxActiveOnRecord,
              compact: proofSurfaceLayout.proBridgeCompact,
              hasSeenFirstRepeat: DelayedPaywallProofStore.hasSeenFirstRepeat,
              hasOpenedEvidenceTrail:
                  DelayedPaywallProofStore.hasOpenedEvidenceTrail,
            ),
            entries: input.journalEntries,
            beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
            beliefEvidencePhrases:
                archiveBeliefSurfaceCandidate.evidencePhrases,
            hasBetaProofLiftVisible: readyBag.showBetaProofLiftOnRecordReady,
            hasReturnAfterProofStrengthenedVisible:
                readyBag.showReturnAfterProofStrengthenedOnRecordReady,
          ),
        );
    final betaActivationPathPreAuditContext =
        BetaActivationPathEngine.buildContext(
          source: 'record',
          entryCount: input.entryCount,
          hasTimelineProof:
              readyBag.showTimelineProofMomentOnRecord ||
              readyBag.showArchiveTimelineSpineOnRecord,
          hasPaywallSeen: input.betaActivationLoopCounts.paywallSeen > 0,
          hasPurchaseCtaTapped:
              input.betaActivationLoopCounts.purchaseTapped > 0,
          strongerProCardVisible:
              readyBag.showProBridgeVisibilityOnRecordReady ||
              readyBag.showProEvidenceValueOnRecordReady ||
              readyBag.showProVisibilityLiftOnRecordReady,
          isReady: flags.isReady,
          isRecording: flags.isRecording,
          isPostSave: input.isPostSave,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
          isPermissionBlocked: flags.isPermissionBlocked,
        );
    final betaActivationPathPreAuditResult = BetaActivationPathEngine.build(
      context: betaActivationPathPreAuditContext,
    );
    readyBag.showBetaActivationPathCard =
        betaActivationPathPreAuditResult.shouldShow;
    final betaFeedbackCaptureRecordReadyPreAudit =
        BetaFeedbackCaptureEngine.build(
          context: BetaFeedbackCaptureEngine.buildContext(
            surface: BetaFeedbackCaptureSurface.recordReady,
            source: 'record',
            entryCount: input.entryCount,
            isReady: flags.isReady,
            isRecording: flags.isRecording,
            isDegradedTranscriptState: isDegradedTranscriptOnRecord,
            whatChangedQuestionActive: showWhatChangedV2,
            patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
            hasPaywallSeen: input.betaActivationLoopCounts.paywallSeen > 0,
            hasPurchaseCtaTapped:
                input.betaActivationLoopCounts.purchaseTapped > 0,
            isPro: input.userProState.isPro,
            timelineProofVisible:
                readyBag.showTimelineProofMomentOnRecord &&
                timelineProofMomentCandidate != null,
            existingProofFeedbackVisible:
                BetaFeedbackCaptureEngine.existingProofFeedbackVisible(
                  surface: BetaProofFeedbackSurface.timelineProofMoment,
                  parentVisible:
                      readyBag.showTimelineProofMomentOnRecord &&
                      timelineProofMomentCandidate != null,
                  entryCount: input.entryCount,
                  hasConfirmedRepeat:
                      EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                        input.journalEntries,
                      ),
                  isRecording: flags.isRecording,
                  isPostSaveDegraded: false,
                  whatChangedQuestionActive: showWhatChangedV2,
                  patternReviewInboxHasActiveItems:
                      patternReviewInboxActiveOnRecord,
                ),
            coreCaptureCtaVisible:
                readyBag.showFirstMomentCaptureCard ||
                readyBag.showThreeMomentCompletionCard ||
                readyBag.showSecondMomentReturnCard,
          ),
        );
    readyBag.showBetaFeedbackCaptureRecordReady =
        betaFeedbackCaptureRecordReadyPreAudit.shouldShow;
    readyBag.betaFeedbackCaptureRecordReadyResult =
        betaFeedbackCaptureRecordReadyPreAudit.shouldShow
        ? betaFeedbackCaptureRecordReadyPreAudit
        : null;
    final betaProofFeedbackCounts =
        FirstSessionProofRepairEngine.feedbackCountsFromStore();
    final betaProofFeedbackRowVisibleOnTimeline =
        FirstSessionProofRepairEngine.betaProofFeedbackRowVisible(
          parentVisible:
              readyBag.showTimelineProofMomentOnRecord &&
              timelineProofMomentCandidate != null,
          entryCount: input.entryCount,
          hasConfirmedRepeat:
              EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                input.journalEntries,
              ),
          isRecording: flags.isRecording,
          isPostSaveDegraded: false,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    final proofQualityRepairInput = ProofQualityRepairVisibilityInput(
      entryCount: input.entryCount,
      source: 'record_ready',
      hasTimelineProofVisible:
          readyBag.showTimelineProofMomentOnRecord &&
          timelineProofMomentCandidate != null,
      hasConfirmedRepeat: EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
        input.journalEntries,
      ),
      confidenceLevel:
          recordLoosenSignalsPreAudit.confidenceLevel ??
          ProofConfidenceLevel.watchOnly,
      usefulFeedbackCount: betaProofFeedbackCounts.useful,
      negativeFeedbackCount: betaProofFeedbackCounts.negative,
      betaProofFeedbackRowVisible: betaProofFeedbackRowVisibleOnTimeline,
      isRecording: flags.isRecording,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
    );
    readyBag.showProofQualityRepairOnRecord =
        FirstSessionProofRepairEngine.shouldShowProof(
          input: proofQualityRepairInput,
        );
    final proofQualityRepairResult = readyBag.showProofQualityRepairOnRecord
        ? FirstSessionProofRepairEngine.buildProof(
            input: proofQualityRepairInput,
          )
        : ProofQualityRepairResult.hidden;
    final proofFloorRescueInput = ProofFloorRescueEngine.inputFromStore(
      entryCount: input.entryCount,
      source: 'record_ready',
      isPro: input.userProState.isPro,
      hasTimelineProofVisible:
          readyBag.showTimelineProofMomentOnRecord &&
          timelineProofMomentCandidate != null,
      hasConfirmedRepeat: EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
        input.journalEntries,
      ),
      confidenceLevel:
          recordLoosenSignalsPreAudit.confidenceLevel ??
          ProofConfidenceLevel.watchOnly,
      hasSafeAnchor: recordLoosenSignalsPreAudit.hasSafeAnchor,
      hasLowMatchQuality: ProofFloorRescueEngine.resolveHasLowMatchQuality(
        entries: input.journalEntries,
        beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
        source: 'record_ready',
        beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
      ),
      isRecording: flags.isRecording,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
    );
    readyBag.showProofFloorRescueOnRecord =
        ProofFloorRescueEngine.shouldShowCard(
          input: proofFloorRescueInput,
        );
    final proofFloorRescueResult = readyBag.showProofFloorRescueOnRecord
        ? ProofFloorRescueEngine.build(input: proofFloorRescueInput)
        : ProofFloorRescueResult.hidden;
    final blocksProByProofFloorOnRecord =
        ProofFloorRescueEngine.blocksProMonetization(proofFloorRescueInput);
    if (blocksProByProofFloorOnRecord) {
      readyBag.showProUnderstandingLiftOnRecordReady = false;
      readyBag.showProVisibilityLiftOnRecordReady = false;
      readyBag.showProBridgeVisibilityOnRecordReady = false;
      readyBag.showProEvidenceValueOnRecordReady = false;
      readyBag.showProEvidenceValuePrivateReportOnRecord = false;
      readyBag.showBetaRepairLabProPlacementOnRecord = false;
      readyBag.showBetaRepairLabPaywallValueOnRecord = false;
      readyBag.showBetaRepairLabPricingValueFramingOnRecord = false;
      readyBag.showBetaRepairLabPricingValidationOnRecord = false;
      readyBag.showBetaRepairLabEvidenceTrailClarityOnRecord = false;
    }
    if (ProofFloorRescueEngine.shouldSuppressStrongProofPayoff(
      proofFloorRescueInput,
    )) {
      readyBag.showBetaProofLiftOnRecordReady = false;
    }
    if (readyBag.showProofFloorRescueOnRecord) {
      readyBag.showProofQualityRepairOnRecord = false;
    }
    readyBag.showBetaRepairLabProofOnRecord =
        BetaRepairLabEngine.shouldShowProof(
          input: betaRepairLabInput,
        );
    final betaRepairLabProofResult = readyBag.showBetaRepairLabProofOnRecord
        ? BetaRepairLabEngine.buildProof(input: betaRepairLabInput)
        : BetaRepairLabProofResult.hidden;
    final blocksProCardsByProofProtectionOnRecord =
        BetaRepairLabEngine.blocksProWhenProofRepairActive(
          input: betaRepairLabInput,
          showProofRepair: readyBag.showBetaRepairLabProofOnRecord,
        );
    readyBag.showBetaRepairLabEvidenceTrailClarityOnRecord =
        EvidenceTrailClarityEngine.shouldShow(
          input: betaRepairLabInput,
          hasSafeAnchor: recordLoosenSignalsPreAudit.hasSafeAnchor,
          blocksProCards:
              blocksProByProofFloorOnRecord ||
              blocksProCardsByProofProtectionOnRecord,
        );
    final betaRepairLabEvidenceTrailClarityResult =
        readyBag.showBetaRepairLabEvidenceTrailClarityOnRecord
        ? EvidenceTrailClarityEngine.build(
            input: betaRepairLabInput,
            hasSafeAnchor: recordLoosenSignalsPreAudit.hasSafeAnchor,
            blocksProCards:
                blocksProByProofFloorOnRecord ||
                blocksProCardsByProofProtectionOnRecord,
          )
        : EvidenceTrailClarityResult.hidden;
    if (BetaRepairLabEngine.suppressProofFloorRescueWhenProofRepairActive(
      betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
      showProofRepair: readyBag.showBetaRepairLabProofOnRecord,
    )) {
      readyBag.showProofFloorRescueOnRecord = false;
      readyBag.showProofQualityRepairOnRecord = false;
    }
    if (BetaRepairLabEngine.blocksProWhenProofRepairActive(
          input: betaRepairLabInput,
          showProofRepair: readyBag.showBetaRepairLabProofOnRecord,
        ) ||
        BetaRepairLabEngine.blocksOtherProCardsWhenPlacementRepairActive(
          betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
          showProPlacement: readyBag.showBetaRepairLabProPlacementOnRecord,
        ) ||
        PaywallValueRepairEngine.blocksOtherProCardsWhenPaywallValueRepairActive(
          betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
          showPaywallValue: readyBag.showBetaRepairLabPaywallValueOnRecord,
        ) ||
        PricingValueFramingEngine.blocksOtherProCardsWhenPricingValueFramingActive(
          betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
          showPricingValueFraming:
              readyBag.showBetaRepairLabPricingValueFramingOnRecord,
        ) ||
        PricingValidationEngine.blocksOtherProCardsWhenPricingValidationActive(
          betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
          showPricingValidation:
              readyBag.showBetaRepairLabPricingValidationOnRecord,
        ) ||
        EvidenceTrailClarityEngine.blocksOtherProCardsWhenEvidenceTrailClarityActive(
          betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
          showEvidenceTrailClarity:
              readyBag.showBetaRepairLabEvidenceTrailClarityOnRecord,
        )) {
      readyBag.showProUnderstandingLiftOnRecordReady = false;
      readyBag.showProVisibilityLiftOnRecordReady = false;
      readyBag.showProBridgeVisibilityOnRecordReady = false;
      readyBag.showProEvidenceValueOnRecordReady = false;
      readyBag.showProEvidenceValuePrivateReportOnRecord = false;
    }
    return (
      readyBag: readyBag,
      currentRelevanceQuestionActiveOnRecord:
          currentRelevanceQuestionActiveOnRecord,
      correctionMemoryCandidate: correctionMemoryCandidate,
      evidenceWeightingCandidate: evidenceWeightingCandidate,
      proofSpecificityCandidate: proofSpecificityCandidate,
      presentDayRelevanceCandidate: presentDayRelevanceCandidate,
      timelinePositioningCandidate: timelinePositioningCandidate,
      otherEducationCardsOnRecord: otherEducationCardsOnRecord,
      patternConfidenceEducationCount: patternConfidenceEducationCount,
      patternConfidenceExplanationCandidate:
          patternConfidenceExplanationCandidate,
      showConfirmedRepeatWhyMattersOnRecord:
          showConfirmedRepeatWhyMattersOnRecord,
      showConfirmedRepeatThoughtMapOnRecord:
          showConfirmedRepeatThoughtMapOnRecord,
      showPositiveReinforcementOnRecord: showPositiveReinforcementOnRecord,
      showHelpfulActionAppearedOnRecord: showHelpfulActionAppearedOnRecord,
      showChangeProofOnRecord: showChangeProofOnRecord,
      showFirstWeekLoopOnRecord: showFirstWeekLoopOnRecord,
      firstProofPayoffCandidate: firstProofPayoffCandidate,
      threeDayChallengeCandidate: threeDayChallengeCandidate,
      showThreeDayChallengeOnRecord: showThreeDayChallengeOnRecord,
      firstProofPatternConfidence: firstProofPatternConfidence,
      firstProofTruthProofKey: firstProofTruthProofKey,
      showFirstProofTruth: showFirstProofTruth,
      firstProofTruthAnswer: firstProofTruthAnswer,
      showFirstProofActionLoop: showFirstProofActionLoop,
      firstProofActionLoopContent: firstProofActionLoopContent,
      showFirstProofMoment: showFirstProofMoment,
      postSaveHasConfirmedRepeat: postSaveHasConfirmedRepeat,
      postSaveHasFirstProof: postSaveHasFirstProof,
      postSaveDegraded: postSaveDegraded,
      showCoreValueFeedbackOnRecordPostFirstProof:
          showCoreValueFeedbackOnRecordPostFirstProof,
      returnCheckPayoffCandidate: returnCheckPayoffCandidate,
      whatChangedV2Prompt: whatChangedV2Prompt,
      whatChangedV2Display: whatChangedV2Display,
      showWhatChangedV2: showWhatChangedV2,
      showWhatChangedV2Display: showWhatChangedV2Display,
      firstMomentCaptureCandidate: firstMomentCaptureCandidate,
      firstSaveLiftCandidate: firstSaveLiftCandidate,
      openingRepairOverride: openingRepairOverride,
      firstSessionLiftCandidate: firstSessionLiftCandidate,
      secondMomentReturnCandidate: secondMomentReturnCandidate,
      threeMomentCompletionCandidate: threeMomentCompletionCandidate,
      firstRunPositioningCandidate: firstRunPositioningCandidate,
      betaTodaySummaryCandidate: betaTodaySummaryCandidate,
      archiveTimelineSpineCandidate: archiveTimelineSpineCandidate,
      whatToNoticeNextCandidate: whatToNoticeNextCandidate,
      suppressLegacyEducationCardsForSpineOnRecord:
          suppressLegacyEducationCardsForSpineOnRecord,
      timelineProofMomentCandidate: timelineProofMomentCandidate,
      betaTesterReportCandidate: betaTesterReportCandidate,
      notRelevantRecoveryCandidate: notRelevantRecoveryCandidate,
      proofQualityResponseTimelineCandidate:
          proofQualityResponseTimelineCandidate,
      proofQualityResponseSpineCandidate: proofQualityResponseSpineCandidate,
      betaProofLiftTimelineCandidate: betaProofLiftTimelineCandidate,
      returnAfterProofRecordCandidate: returnAfterProofRecordCandidate,
      returnAfterProofLiftV2Candidate: returnAfterProofLiftV2Candidate,
      recordLoosenSignalsPreAudit: recordLoosenSignalsPreAudit,
      recordEvidenceAnchorPreAudit: recordEvidenceAnchorPreAudit,
      recordFeedbackStateForLift: recordFeedbackStateForLift,
      timelineFeedbackType: timelineFeedbackType,
      betaRepairLabInput: betaRepairLabInput,
      betaRepairLabProPlacementResult: betaRepairLabProPlacementResult,
      betaRepairLabPricingValueFramingResult:
          betaRepairLabPricingValueFramingResult,
      betaRepairLabPaywallValueResult: betaRepairLabPaywallValueResult,
      hasProEngagementOnRecord: hasProEngagementOnRecord,
      betaRepairLabPricingValidationResult:
          betaRepairLabPricingValidationResult,
      proUnderstandingLiftRecordReadyInput:
          proUnderstandingLiftRecordReadyInput,
      proVisibilityLiftRecordReadyResult: proVisibilityLiftRecordReadyResult,
      betaActivationPathPreAuditContext: betaActivationPathPreAuditContext,
      betaActivationPathPreAuditResult: betaActivationPathPreAuditResult,
      betaFeedbackCaptureRecordReadyPreAudit:
          betaFeedbackCaptureRecordReadyPreAudit,
      betaProofFeedbackCounts: betaProofFeedbackCounts,
      betaProofFeedbackRowVisibleOnTimeline:
          betaProofFeedbackRowVisibleOnTimeline,
      proofQualityRepairInput: proofQualityRepairInput,
      proofQualityRepairResult: proofQualityRepairResult,
      proofFloorRescueInput: proofFloorRescueInput,
      proofFloorRescueResult: proofFloorRescueResult,
      blocksProByProofFloorOnRecord: blocksProByProofFloorOnRecord,
      betaRepairLabProofResult: betaRepairLabProofResult,
      blocksProCardsByProofProtectionOnRecord:
          blocksProCardsByProofProtectionOnRecord,
      betaRepairLabEvidenceTrailClarityResult:
          betaRepairLabEvidenceTrailClarityResult,
    );
  }

  static RecordPostSaveSurfaceBag resolvePostSaveCardsA({
    required RecordSurfaceInput input,
    required RecordSurfaceFlags flags,
    required List<JournalEntry> entriesAfterSave,
    required int postSaveEntryCount,
    required RecordReadySurfaceBag readyBag,
    required FirstProofPayoff? firstProofPayoffCandidate,
    required bool showFirstProofTruth,
    required bool postSaveDegraded,
    required bool showWhatChangedV2,
    required ArchiveBeliefSurface archiveBeliefSurfaceCandidate,
    required bool showPostProofProBridgeOnRecord,
    required bool patternReviewInboxActivePostSave,
    required TimelineProofMomentResult? timelineProofMomentPostSaveCandidate,
  }) {
    final postSaveBag = RecordPostSaveSurfaceBag();
    postSaveBag.registerTimelineProofMoment(
      TimelineProofMomentEngine.shouldShowOnFirstProofPayoffPostSave(
        result: timelineProofMomentPostSaveCandidate,
        showFirstProofPayoff: readyBag.showFirstProofPayoff,
        isDegradedPostSave:
            entriesAfterSave.isNotEmpty &&
            VoiceCaptureQuality.isDegradedVoiceCapture(entriesAfterSave.last),
        whatChangedQuestionActive: showWhatChangedV2,
        patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
      ),
    );
    final proofSpecificityPostSaveCandidate = entriesAfterSave.length >= 3
        ? ProofSpecificityEngine.build(
            entries: entriesAfterSave,
            beliefSurfaceVisible: false,
            source: 'record_post_save',
          )
        : ProofSpecificityEngine.build(
            entries: entriesAfterSave,
            beliefSurfaceVisible: false,
            source: 'record_post_save',
          );
    postSaveBag.registerProofSpecificity(
      flags.isDone &&
          readyBag.showFirstProofPayoff &&
          ProofSpecificityEngine.shouldShowOnFirstProofPayoff(
            result: proofSpecificityPostSaveCandidate,
            isPostSaveDegradedState:
                entriesAfterSave.isNotEmpty &&
                VoiceCaptureQuality.isDegradedVoiceCapture(
                  entriesAfterSave.last,
                ),
            whatChangedQuestionActive: showWhatChangedV2,
            patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
          ),
    );
    final proofSpecificityBoostPostSaveCandidate =
        ProofSpecificityBoostEngine.build(
          entries: entriesAfterSave,
          beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
          source: 'record_post_save',
          beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
        );
    final proofQualityResponseFirstProofCandidate =
        ProofQualityResponseEngine.build(
          entries: entriesAfterSave,
          surface: ProofQualityResponseSurface.firstProofPayoff,
          source: 'record_post_save',
          beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
        );
    final proofQualityResponseTimelinePostSaveCandidate =
        ProofQualityResponseEngine.build(
          entries: entriesAfterSave,
          surface: ProofQualityResponseSurface.timelineProofMoment,
          source: 'record_post_save',
          beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
        );
    final betaProofLiftFirstProofCandidate = BetaProofLiftEngine.build(
      entries: entriesAfterSave,
      surface: BetaProofLiftSurface.firstProofPayoff,
      source: 'record_post_save',
      beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
      beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
      timelineProof: timelineProofMomentPostSaveCandidate,
    );
    final betaProofLiftTimelinePostSaveCandidate = BetaProofLiftEngine.build(
      entries: entriesAfterSave,
      surface: BetaProofLiftSurface.timelineProofMoment,
      source: 'record_post_save_first_proof',
      beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
      beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
      timelineProof: timelineProofMomentPostSaveCandidate,
    );
    final returnAfterProofPostSaveCandidate = ReturnAfterProofEngine.build(
      entries: entriesAfterSave,
      source: 'record_post_save',
      firstProofSeen: true,
      timelineProofVisible: false,
      betaTesterReportVisible: false,
    );
    final firstProofPayoffParentVisible =
        readyBag.showFirstProofPayoff && firstProofPayoffCandidate != null;
    postSaveBag.registerProofSpecificityBoostOnFirstProof(
      flags.isDone &&
          ProofSpecificityBoostEngine.shouldRender(
            result: proofSpecificityBoostPostSaveCandidate,
            surface: ProofSpecificityBoostSurface.firstProofPayoff,
            parentVisible: firstProofPayoffParentVisible,
            timelineProofVisible: false,
            firstProofPayoffVisible: firstProofPayoffParentVisible,
            isRecording: flags.isRecording,
            isDegradedTranscriptState: false,
            isPostSaveDegradedState: postSaveDegraded,
            whatChangedQuestionActive: showWhatChangedV2,
            patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
          ),
    );
    final showProofQualityResponseOnFirstProofPayoff =
        flags.isDone &&
        ProofQualityResponseEngine.shouldRender(
          result: proofQualityResponseFirstProofCandidate,
          parentVisible: firstProofPayoffParentVisible,
          timelineProofVisible: false,
          firstProofPayoffVisible: firstProofPayoffParentVisible,
          isRecording: flags.isRecording,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: postSaveDegraded,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
        );
    if (showProofQualityResponseOnFirstProofPayoff &&
        ProofQualityResponseEngine.coversLegacyBoost(
          result: proofQualityResponseFirstProofCandidate,
          parentVisible: firstProofPayoffParentVisible,
          timelineProofVisible: false,
          firstProofPayoffVisible: firstProofPayoffParentVisible,
          isRecording: flags.isRecording,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: postSaveDegraded,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
        )) {
      postSaveBag.suppressProofSpecificityBoostOnFirstProof();
    }
    final timelineProofPostSaveParentVisible =
        postSaveBag.showTimelineProofMomentOnFirstProofPayoff &&
        timelineProofMomentPostSaveCandidate != null;
    postSaveBag.registerProofSpecificityBoostOnTimeline(
      flags.isDone &&
          ProofSpecificityBoostEngine.shouldRender(
            result: proofSpecificityBoostPostSaveCandidate,
            surface: ProofSpecificityBoostSurface.timelineProofMoment,
            parentVisible: timelineProofPostSaveParentVisible,
            timelineProofVisible: timelineProofPostSaveParentVisible,
            firstProofPayoffVisible: false,
            isRecording: flags.isRecording,
            isDegradedTranscriptState: false,
            isPostSaveDegradedState: postSaveDegraded,
            whatChangedQuestionActive: showWhatChangedV2,
            patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
          ),
    );
    final showProofQualityResponseOnTimelineProofPostSave =
        flags.isDone &&
        ProofQualityResponseEngine.shouldRender(
          result: proofQualityResponseTimelinePostSaveCandidate,
          parentVisible: timelineProofPostSaveParentVisible,
          timelineProofVisible: timelineProofPostSaveParentVisible,
          firstProofPayoffVisible: false,
          isRecording: flags.isRecording,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: postSaveDegraded,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
        );
    if (showProofQualityResponseOnTimelineProofPostSave &&
        ProofQualityResponseEngine.coversLegacyBoost(
          result: proofQualityResponseTimelinePostSaveCandidate,
          parentVisible: timelineProofPostSaveParentVisible,
          timelineProofVisible: timelineProofPostSaveParentVisible,
          firstProofPayoffVisible: false,
          isRecording: flags.isRecording,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: postSaveDegraded,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
        )) {
      postSaveBag.suppressProofSpecificityBoostOnTimeline();
    }
    postSaveBag.registerBetaProofLiftOnFirstProof(
      flags.isDone &&
          BetaProofLiftEngine.shouldRender(
            result: betaProofLiftFirstProofCandidate,
            qualityResponse: proofQualityResponseFirstProofCandidate,
            parentVisible: firstProofPayoffParentVisible,
            timelineProofVisible: false,
            firstProofPayoffVisible: firstProofPayoffParentVisible,
            isRecording: flags.isRecording,
            isDegradedTranscriptState: false,
            isPostSaveDegradedState: postSaveDegraded,
            whatChangedQuestionActive: showWhatChangedV2,
            patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
          ),
    );
    postSaveBag.registerBetaProofLiftOnTimeline(
      flags.isDone &&
          BetaProofLiftEngine.shouldRender(
            result: betaProofLiftTimelinePostSaveCandidate,
            qualityResponse: proofQualityResponseTimelinePostSaveCandidate,
            parentVisible: timelineProofPostSaveParentVisible,
            timelineProofVisible: timelineProofPostSaveParentVisible,
            firstProofPayoffVisible: false,
            isRecording: flags.isRecording,
            isDegradedTranscriptState: false,
            isPostSaveDegradedState: postSaveDegraded,
            whatChangedQuestionActive: showWhatChangedV2,
            patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
          ),
    );
    if (BetaProofLiftEngine.coversLegacyBoost(
      result: betaProofLiftFirstProofCandidate,
      parentVisible: firstProofPayoffParentVisible,
      timelineProofVisible: false,
      firstProofPayoffVisible: firstProofPayoffParentVisible,
      isRecording: flags.isRecording,
      isDegradedTranscriptState: false,
      isPostSaveDegradedState: postSaveDegraded,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
    )) {
      postSaveBag.suppressProofSpecificityBoostOnFirstProof();
    }
    if (BetaProofLiftEngine.coversLegacyBoost(
      result: betaProofLiftTimelinePostSaveCandidate,
      parentVisible: timelineProofPostSaveParentVisible,
      timelineProofVisible: timelineProofPostSaveParentVisible,
      firstProofPayoffVisible: false,
      isRecording: flags.isRecording,
      isDegradedTranscriptState: false,
      isPostSaveDegradedState: postSaveDegraded,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
    )) {
      postSaveBag.suppressProofSpecificityBoostOnTimeline();
    }
    postSaveBag.registerReturnAfterProof(
      strengthened:
          flags.isDone &&
          ReturnAfterProofEngine.shouldShowStrengthenedOnFirstProofPayoffPostSave(
            result: returnAfterProofPostSaveCandidate,
            showFirstProofPayoff: readyBag.showFirstProofPayoff,
            isRecording: flags.isRecording,
            isPostSaveDegraded: postSaveDegraded,
            whatChangedQuestionActive: showWhatChangedV2,
            patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
            dismissedForToday: ReturnAfterProofStore.isDismissedToday,
          ),
      generic:
          flags.isDone &&
          ReturnAfterProofEngine.shouldShowGenericOnFirstProofPayoffPostSave(
            result: returnAfterProofPostSaveCandidate,
            showFirstProofPayoff: readyBag.showFirstProofPayoff,
            isRecording: flags.isRecording,
            isPostSaveDegraded: postSaveDegraded,
            whatChangedQuestionActive: showWhatChangedV2,
            patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
            dismissedForToday: ReturnAfterProofStore.isDismissedToday,
          ),
    );
    final returnAfterProofLiftV2PostSaveCandidate =
        ReturnAfterProofLiftV2Engine.build(
          entries: entriesAfterSave,
          source: 'record_post_save',
          firstProofSeen: true,
          timelineProofVisible:
              postSaveBag.showTimelineProofMomentOnFirstProofPayoff &&
              timelineProofMomentPostSaveCandidate != null,
        );
    postSaveBag.registerReturnAfterProofLiftV2(
      ReturnAfterProofLiftV2Engine.shouldShow(
        result: returnAfterProofLiftV2PostSaveCandidate,
        isReady: false,
        isRecording: flags.isRecording,
        isPostSave: flags.isDone,
        isDegradedTranscriptState: false,
        isPostSaveDegradedState: postSaveDegraded,
        whatChangedQuestionActive: showWhatChangedV2,
        patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
      ),
    );
    final postSaveLoosenSignalsPreAudit =
        ProBridgeTimingLoosenEngine.resolveSignals(
          entries: entriesAfterSave,
          source: 'record_post_save',
          beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
          beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
        );
    final postSaveEvidenceAnchorPreAudit = EvidenceAnchorEngine.build(
      entries: entriesAfterSave,
      beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
      source: 'record_post_save',
      beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
    );
    final postSaveFeedbackStateForLift =
        ProMomentTimingEngine.resolveFeedbackState(
          entries: entriesAfterSave,
          surface: ProofQualityResponseSurface.firstProofPayoff,
        );
    final hasProEngagementOnPostSave =
        input.betaActivationLoopCounts.paywallSeen > 0 ||
        input.betaActivationLoopCounts.purchaseTapped > 0 ||
        input.betaActivationLoopCounts.proBoundarySeen > 0;
    final proUnderstandingLiftPostSaveInput =
        ProUnderstandingLiftVisibilityInput(
          surface: ProUnderstandingLiftSurface.recordPostSave,
          source: 'record_post_save',
          entryCount: postSaveEntryCount,
          isPro: input.userProState.isPro,
          hasUsefulProof:
              postSaveFeedbackStateForLift == ProofQualityFeedbackState.useful,
          confidenceLevel:
              postSaveLoosenSignalsPreAudit.confidenceLevel ??
              ProofConfidenceLevel.watchOnly,
          feedbackState: postSaveFeedbackStateForLift,
          hasProEngagement: hasProEngagementOnPostSave,
          hasFreshReturnAfterCorrection:
              postSaveLoosenSignalsPreAudit.hasFreshReturnAfterCorrection,
          hasChangeAnchor: postSaveEvidenceAnchorPreAudit.hasChangeAnchor,
          isRecording: flags.isRecording,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: postSaveDegraded,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
        );
    postSaveBag.registerProUnderstandingLift(
      flags.isDone &&
          entriesAfterSave.isNotEmpty &&
          readyBag.showFirstProofPayoff &&
          firstProofPayoffCandidate != null &&
          ProUnderstandingLiftEngine.shouldShowCard(
            input: proUnderstandingLiftPostSaveInput,
          ),
    );
    ProUnderstandingLiftResult? base;
    ProUnderstandingLiftResult? proUnderstandingLiftPostSaveResult;
    if (postSaveBag.showProUnderstandingLiftOnPostSave) {
      base = ProUnderstandingLiftEngine.build(
        input: proUnderstandingLiftPostSaveInput,
      );
      proUnderstandingLiftPostSaveResult =
          BetaRepairLabEngine.applyProExplanationCopy(
            base: base,
            betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
          ) ??
          base;
    }
    postSaveBag.registerProVisibilityLift(
      flags.isDone &&
          entriesAfterSave.isNotEmpty &&
          readyBag.showFirstProofPayoff &&
          firstProofPayoffCandidate != null &&
          ProVisibilityLiftEngine.shouldShowCard(
            entryCount: postSaveEntryCount,
            isPro: input.userProState.isPro,
            hasUsefulProof:
                postSaveFeedbackStateForLift ==
                ProofQualityFeedbackState.useful,
            confidenceLevel:
                postSaveLoosenSignalsPreAudit.confidenceLevel ??
                ProofConfidenceLevel.watchOnly,
            feedbackState: postSaveFeedbackStateForLift,
            hasPaywallSeen: input.betaActivationLoopCounts.paywallSeen > 0,
            hasFreshReturnAfterCorrection:
                postSaveLoosenSignalsPreAudit.hasFreshReturnAfterCorrection,
            hasChangeAnchor: postSaveEvidenceAnchorPreAudit.hasChangeAnchor,
            isRecording: flags.isRecording,
            isDegradedTranscriptState: false,
            isPostSaveDegradedState: postSaveDegraded,
            whatChangedQuestionActive: showWhatChangedV2,
            patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
          ),
    );
    final proVisibilityLiftPostSaveResult =
        postSaveBag.showProVisibilityLiftOnPostSave
        ? ProVisibilityLiftEngine.build(
            surface: ProVisibilityLiftSurface.recordPostSave,
            source: 'record_post_save',
            entryCount: postSaveEntryCount,
            isPro: input.userProState.isPro,
            hasUsefulProof:
                postSaveFeedbackStateForLift ==
                ProofQualityFeedbackState.useful,
            confidenceLevel:
                postSaveLoosenSignalsPreAudit.confidenceLevel ??
                ProofConfidenceLevel.watchOnly,
            feedbackState: postSaveFeedbackStateForLift,
            hasPaywallSeen: input.betaActivationLoopCounts.paywallSeen > 0,
            hasFreshReturnAfterCorrection:
                postSaveLoosenSignalsPreAudit.hasFreshReturnAfterCorrection,
            hasChangeAnchor: postSaveEvidenceAnchorPreAudit.hasChangeAnchor,
            isRecording: flags.isRecording,
            isDegradedTranscriptState: false,
            isPostSaveDegradedState: postSaveDegraded,
            whatChangedQuestionActive: showWhatChangedV2,
            patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
          )
        : null;
    postSaveBag.registerProEvidenceValue(
      flags.isDone &&
          entriesAfterSave.isNotEmpty &&
          readyBag.showFirstProofPayoff &&
          firstProofPayoffCandidate != null &&
          ProEvidenceValueEngine.shouldShowCard(
            ProEvidenceValueEngine.buildContext(
              surface: ProEvidenceValueSurface.recordPostSaveAfterPayoff,
              entryCount: postSaveEntryCount,
              isPro: input.userProState.isPro,
              dismissed: ProEvidenceValueDismissStore.isDismissed(),
              entries: entriesAfterSave,
              returnChecks: RepeatReturnCheckStore.cached,
              isPostSaveDegradedState:
                  VoiceCaptureQuality.isDegradedVoiceCapture(
                    entriesAfterSave.last,
                  ),
              firstProofTruthQuestionActive: showFirstProofTruth,
              whatChangedQuestionActive: showWhatChangedV2,
              firstProofPayoffVisible: true,
            ),
          ),
    );
    postSaveBag.registerBetaInviteLoop(
      flags.isDone &&
          entriesAfterSave.isNotEmpty &&
          readyBag.showFirstProofPayoff &&
          firstProofPayoffCandidate != null &&
          BetaInviteLoopEngine.shouldShowCard(
            BetaInviteLoopEngine.buildContext(
              surface: BetaInviteLoopSurface.recordPostSave,
              source: 'record_post_save',
              entryCount: postSaveEntryCount,
              entries: entriesAfterSave,
              beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
              beliefEvidencePhrases:
                  archiveBeliefSurfaceCandidate.evidencePhrases,
              isPostSaveDegradedState: postSaveDegraded,
              whatChangedQuestionActive: showWhatChangedV2,
              patternReviewInboxHasActiveItems:
                  patternReviewInboxActivePostSave,
            ),
          ),
    );
    postSaveBag.registerProPreview(
      flags.isDone &&
          entriesAfterSave.isNotEmpty &&
          readyBag.showFirstProofPayoff &&
          firstProofPayoffCandidate != null &&
          ProPreviewEngine.shouldShowCard(
            ProPreviewEngine.buildContext(
              surface: ProPreviewSurface.recordPostSave,
              source: 'record_post_save',
              entryCount: postSaveEntryCount,
              isPro: input.userProState.isPro,
              dismissed: ProPreviewEngine.isDismissed(),
              entries: entriesAfterSave,
              hasTimelineProofVisible: postSaveBag.hasTimelineProofVisible(
                timelineProofMomentPostSaveCandidate,
              ),
              firstProofPayoffVisible: readyBag.showFirstProofPayoff,
              isPostSaveDegradedState: postSaveDegraded,
              firstProofTruthQuestionActive: showFirstProofTruth,
              whatChangedQuestionActive: showWhatChangedV2,
              patternReviewInboxHasActiveItems:
                  patternReviewInboxActivePostSave,
            ),
          ),
    );
    postSaveBag.registerProBridgeVisibility(
      flags.isDone &&
          entriesAfterSave.isNotEmpty &&
          readyBag.showFirstProofPayoff &&
          firstProofPayoffCandidate != null &&
          ProBridgeVisibilityEngine.shouldShow(
            input: ProBridgeTimingLoosenEngine.enrichVisibilityInput(
              base: ProBridgeVisibilityInput(
                surface: ProBridgeVisibilitySurface.recordPostSaveAfterPayoff,
                source: 'record_post_save',
                entryCount: postSaveEntryCount,
                isPro: input.userProState.isPro,
                postProofProBridgeEnabled: showPostProofProBridgeOnRecord,
                hasFirstProof: true,
                isPostSaveDegradedState: postSaveDegraded,
                hasFirstProofPayoffVisible: readyBag.showFirstProofPayoff,
                hasTimelineProofVisible: postSaveBag.hasTimelineProofVisible(
                  timelineProofMomentPostSaveCandidate,
                ),
                hasBetaProofLiftVisible: postSaveBag.hasBetaProofLiftVisible,
                hasReturnAfterProofStrengthenedVisible: postSaveBag
                    .showReturnAfterProofStrengthenedOnFirstProofPayoff,
                feedbackState: ProMomentTimingEngine.resolveFeedbackState(
                  entries: entriesAfterSave,
                  surface: ProofQualityResponseSurface.firstProofPayoff,
                ),
                whatChangedQuestionActive: showWhatChangedV2,
                patternReviewInboxHasActiveItems:
                    patternReviewInboxActivePostSave,
                hasSeenFirstRepeat: DelayedPaywallProofStore.hasSeenFirstRepeat,
                hasOpenedEvidenceTrail:
                    DelayedPaywallProofStore.hasOpenedEvidenceTrail,
              ),
              entries: entriesAfterSave,
              beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
              beliefEvidencePhrases:
                  archiveBeliefSurfaceCandidate.evidencePhrases,
              hasBetaProofLiftVisible: postSaveBag.hasBetaProofLiftVisible,
              hasReturnAfterProofStrengthenedVisible: postSaveBag
                  .showReturnAfterProofStrengthenedOnFirstProofPayoff,
            ),
          ),
    );
    postSaveBag.registerProLockMoment(
      flags.isDone &&
          entriesAfterSave.isNotEmpty &&
          readyBag.showFirstProofPayoff &&
          firstProofPayoffCandidate != null &&
          !postSaveBag.showProBridgeVisibilityPostSave &&
          !postSaveBag.showProEvidenceValuePostSave &&
          ProLockMomentEngine.shouldShowCard(
            ProLockMomentEngine.buildContext(
              entryCount: postSaveEntryCount,
              isPro: input.userProState.isPro,
              dismissed: ProLockMomentDismissStore.isDismissed(),
              entries: entriesAfterSave,
              returnChecks: RepeatReturnCheckStore.cached,
              isPostSaveDegradedState:
                  VoiceCaptureQuality.isDegradedVoiceCapture(
                    entriesAfterSave.last,
                  ),
              firstProofTruthQuestionActive: showFirstProofTruth,
              whatChangedQuestionActive: showWhatChangedV2,
              firstProofPayoffVisible: true,
              proEvidenceValueVisible: postSaveBag.showProEvidenceValuePostSave,
            ),
          ),
    );
    postSaveBag.storeMonthlyReportPreview(
      flags.isDone && entriesAfterSave.isNotEmpty
          ? MonthlyPrivateReportEngine.build(
              entries: entriesAfterSave,
              returnChecks: RepeatReturnCheckStore.cached,
              isPostSave: true,
            )
          : null,
    );
    postSaveBag.registerMonthlyPrivateReport(
      flags.isDone &&
          entriesAfterSave.isNotEmpty &&
          readyBag.showFirstProofPayoff &&
          firstProofPayoffCandidate != null &&
          !postSaveBag.showProBridgeVisibilityPostSave &&
          !postSaveBag.showProEvidenceValuePostSave &&
          !postSaveBag.showProLockMomentPostSave &&
          postSaveBag.monthlyPrivateReportPreviewPostSave != null &&
          MonthlyPrivateReportEngine.shouldShowCard(
            MonthlyPrivateReportEngine.buildContext(
              surface: MonthlyPrivateReportSurface.recordPostSaveAfterProof,
              entryCount: postSaveEntryCount,
              isPro: input.userProState.isPro,
              dismissed: MonthlyPrivateReportDismissStore.isDismissed(),
              entries: entriesAfterSave,
              returnChecks: RepeatReturnCheckStore.cached,
              preview: postSaveBag.monthlyPrivateReportPreviewPostSave,
              isPostSaveDegradedState: postSaveDegraded,
              firstProofTruthQuestionActive: showFirstProofTruth,
              whatChangedQuestionActive: showWhatChangedV2,
              proLockMomentVisible: postSaveBag.showProLockMomentPostSave,
              proEvidenceValueVisible: postSaveBag.showProEvidenceValuePostSave,
              isPostSave: true,
            ),
          ),
    );
    postSaveBag.storeProofSpecificityCandidate(
      proofSpecificityPostSaveCandidate,
    );
    postSaveBag.storeProofSupportCandidates(
      boost: proofSpecificityBoostPostSaveCandidate,
      firstProofQuality: proofQualityResponseFirstProofCandidate,
      timelineQuality: proofQualityResponseTimelinePostSaveCandidate,
      firstProofLift: betaProofLiftFirstProofCandidate,
      timelineLift: betaProofLiftTimelinePostSaveCandidate,
      returnAfterProof: returnAfterProofPostSaveCandidate,
    );
    postSaveBag.storeParentVisibility(
      firstProofPayoff: firstProofPayoffParentVisible,
      timelineProof: timelineProofPostSaveParentVisible,
    );
    postSaveBag.storeQualityResponseShows(
      onFirstProofPayoff: showProofQualityResponseOnFirstProofPayoff,
      onTimelineProof: showProofQualityResponseOnTimelineProofPostSave,
    );
    postSaveBag.storeLiftV2Candidate(returnAfterProofLiftV2PostSaveCandidate);
    postSaveBag.storeLoosenAndEngagement(
      loosen: postSaveLoosenSignalsPreAudit,
      evidence: postSaveEvidenceAnchorPreAudit,
      feedback: postSaveFeedbackStateForLift,
      hasProEngagement: hasProEngagementOnPostSave,
      understandingInput: proUnderstandingLiftPostSaveInput,
    );
    postSaveBag.storeProUnderstandingResults(
      builtBase: base,
      result: proUnderstandingLiftPostSaveResult,
    );
    postSaveBag.storeProVisibilityResult(proVisibilityLiftPostSaveResult);
    return postSaveBag;
  }

  static void resolvePostSaveCardsB({
    required RecordSurfaceInput input,
    required RecordSurfaceFlags flags,
    required List<JournalEntry> entriesAfterSave,
    required int postSaveEntryCount,
    required RecordPostSaveSurfaceBag postSaveBag,
    required RecordReadySurfaceBag readyBag,
    required FirstProofPayoff? firstProofPayoffCandidate,
    required bool showFirstProofMoment,
    required bool showFirstProofTruth,
    required bool showFirstProofActionLoop,
    required bool showWhatChangedV2,
    required bool showWhatChangedV2Display,
    required bool showHelpedTracking,
    required bool postSaveDegraded,
    required bool suppressNoisyFirstSaveCards,
    required bool patternReviewInboxActivePostSave,
    required TimelineProofMomentResult? timelineProofMomentPostSaveCandidate,
    required ArchiveBeliefSurface archiveBeliefSurfaceCandidate,
  }) {
    final postSaveReturnHandoffCandidate =
        flags.isDone && entriesAfterSave.isNotEmpty
        ? PostSaveReturnHandoffEngine.build(entries: entriesAfterSave)
        : null;
    final returnTomorrowCuePostSave =
        flags.isDone && entriesAfterSave.isNotEmpty
        ? ReturnTomorrowCueEngine.buildPostSave(
            entries: entriesAfterSave,
            firstProofUnlocked: showFirstProofMoment,
          )
        : null;
    final postSaveDegradedForReturnCue =
        entriesAfterSave.isNotEmpty &&
        VoiceCaptureQuality.isDegradedVoiceCapture(entriesAfterSave.last);
    final comeBackTomorrowV2PostSaveWatch =
        flags.isDone && entriesAfterSave.isNotEmpty
        ? ComeBackTomorrowV2Engine.buildPostSaveWatch(
            entries: entriesAfterSave,
            firstProofUnlocked: showFirstProofMoment,
          )
        : null;
    postSaveBag.registerComeBackTomorrow(
      !suppressNoisyFirstSaveCards &&
          ComeBackTomorrowV2Gates.shouldShowPostSave(
            isPostSaveDone: flags.isDone,
            isDegradedPostSave: postSaveDegradedForReturnCue,
            watch: comeBackTomorrowV2PostSaveWatch,
            showFirstProofPayoff: readyBag.showFirstProofPayoff,
            showFirstProofTruth: showFirstProofTruth,
            showFirstProofActionLoop: showFirstProofActionLoop,
            showWhatChangedV2Display: showWhatChangedV2Display,
            showHelpedTracking: showHelpedTracking,
          ),
    );
    final showPostSaveCuriosityHook = CuriosityHookGates.shouldShowPostSaveCard(
      isPostSaveDone: flags.isDone,
      hook: input.postSaveCuriosityHook,
      isDegradedPostSave: postSaveDegradedForReturnCue,
    );
    final betaFeedbackCapturePostSavePreAudit =
        flags.isDone && entriesAfterSave.isNotEmpty
        ? BetaFeedbackCaptureEngine.build(
            context: BetaFeedbackCaptureEngine.buildContext(
              surface: BetaFeedbackCaptureSurface.recordPostSave,
              source: 'record_post_save',
              entryCount: postSaveEntryCount,
              isPostSave: true,
              isRecording: flags.isRecording,
              isPostSaveDegradedState: postSaveDegraded,
              whatChangedQuestionActive: showWhatChangedV2,
              patternReviewInboxHasActiveItems:
                  patternReviewInboxActivePostSave,
              hasPaywallSeen: input.betaActivationLoopCounts.paywallSeen > 0,
              hasPurchaseCtaTapped:
                  input.betaActivationLoopCounts.purchaseTapped > 0,
              isPro: input.userProState.isPro,
              timelineProofVisible:
                  postSaveBag.showTimelineProofMomentOnFirstProofPayoff &&
                  timelineProofMomentPostSaveCandidate != null,
              proPreviewVisible: postSaveBag.showProPreviewPostSave,
              existingProofFeedbackVisible:
                  BetaFeedbackCaptureEngine.existingProofFeedbackVisible(
                    surface: BetaProofFeedbackSurface.timelineProofMoment,
                    parentVisible:
                        postSaveBag.showTimelineProofMomentOnFirstProofPayoff &&
                        timelineProofMomentPostSaveCandidate != null,
                    entryCount: postSaveEntryCount,
                    hasConfirmedRepeat:
                        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                          entriesAfterSave,
                        ),
                    isRecording: flags.isRecording,
                    isPostSaveDegraded: postSaveDegraded,
                    whatChangedQuestionActive: showWhatChangedV2,
                    patternReviewInboxHasActiveItems:
                        patternReviewInboxActivePostSave,
                  ) ||
                  BetaFeedbackCaptureEngine.existingProofFeedbackVisible(
                    surface: BetaProofFeedbackSurface.firstProofPayoff,
                    parentVisible:
                        readyBag.showFirstProofPayoff &&
                        firstProofPayoffCandidate != null,
                    entryCount: postSaveEntryCount,
                    hasConfirmedRepeat:
                        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                          entriesAfterSave,
                        ),
                    isRecording: flags.isRecording,
                    isPostSaveDegraded: postSaveDegraded,
                    whatChangedQuestionActive: showWhatChangedV2,
                    patternReviewInboxHasActiveItems:
                        patternReviewInboxActivePostSave,
                  ),
            ),
          )
        : BetaFeedbackCaptureResult.hidden;
    postSaveBag.registerBetaFeedbackCapture(
      show: betaFeedbackCapturePostSavePreAudit.shouldShow,
      result: betaFeedbackCapturePostSavePreAudit.shouldShow
          ? betaFeedbackCapturePostSavePreAudit
          : null,
    );
    if (!ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces()) {
      postSaveBag.suppressBetaSurfaces();
    }
    final postSaveProofFloorRescueInput = ProofFloorRescueEngine.inputFromStore(
      entryCount: postSaveEntryCount,
      source: 'record_post_save',
      isPro: input.userProState.isPro,
      hasTimelineProofVisible:
          postSaveBag.showTimelineProofMomentOnFirstProofPayoff &&
          timelineProofMomentPostSaveCandidate != null,
      hasConfirmedRepeat: EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
        entriesAfterSave,
      ),
      confidenceLevel:
          postSaveBag.postSaveLoosenSignalsPreAudit.confidenceLevel ??
          ProofConfidenceLevel.watchOnly,
      hasSafeAnchor: postSaveBag.postSaveLoosenSignalsPreAudit.hasSafeAnchor,
      hasLowMatchQuality: ProofFloorRescueEngine.resolveHasLowMatchQuality(
        entries: entriesAfterSave,
        beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
        source: 'record_post_save',
        beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
      ),
      isRecording: flags.isRecording,
      isDegradedTranscriptState: false,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
    );
    final blocksProByProofFloorOnPostSave =
        ProofFloorRescueEngine.blocksProMonetization(
          postSaveProofFloorRescueInput,
        );
    if (blocksProByProofFloorOnPostSave) {
      postSaveBag.suppressProCardsByProofFloor();
    }
    if (ProofFloorRescueEngine.shouldSuppressStrongProofPayoff(
      postSaveProofFloorRescueInput,
    )) {
      postSaveBag.suppressStrongProofPayoff();
    }
    postSaveBag.storeReturnCueState(
      handoff: postSaveReturnHandoffCandidate,
      returnCue: returnTomorrowCuePostSave,
      degradedForReturnCue: postSaveDegradedForReturnCue,
      watch: comeBackTomorrowV2PostSaveWatch,
      curiosityHook: showPostSaveCuriosityHook,
    );
    postSaveBag.storeProofFloor(
      input: postSaveProofFloorRescueInput,
      blocksPro: blocksProByProofFloorOnPostSave,
    );
    postSaveBag.betaFeedbackCapturePostSavePreAudit =
        betaFeedbackCapturePostSavePreAudit;
  }

  static ({
    SurfacePriorityResult? recordPostSaveSurfacePriority,
    ProBridgeTimingLoosenSignals? postSaveLoosenSignals,
    ProMomentTimingContext? postSaveProTiming,
    BetaFeedbackCaptureResult? betaFeedbackCapturePostSaveFinal,
  })
  auditPostSaveSurfaces({
    required RecordSurfaceInput input,
    required RecordSurfaceFlags flags,
    required List<JournalEntry> entriesAfterSave,
    required int postSaveEntryCount,
    required RecordPostSaveSurfaceBag postSaveBag,
    required RecordReadySurfaceBag readyBag,
    required FirstProofPayoff? firstProofPayoffCandidate,
    required bool postSaveDegraded,
    required bool showWhatChangedV2,
    required bool showWhatChangedV2Display,
    required ArchiveBeliefSurface archiveBeliefSurfaceCandidate,
    required bool patternReviewInboxActivePostSave,
    required TimelineProofMomentResult? timelineProofMomentPostSaveCandidate,
  }) {
    SurfacePriorityResult? recordPostSaveSurfacePriority;
    ProBridgeTimingLoosenSignals? postSaveLoosenSignals;
    ProMomentTimingContext? postSaveProTiming;
    BetaFeedbackCaptureResult? betaFeedbackCapturePostSaveFinal;
    if (flags.isDone) {
      recordPostSaveSurfacePriority = SurfacePriorityEngine.auditRecordPostSave(
        entryCount: postSaveEntryCount,
        source: 'record_post_save',
        candidates: SurfacePriorityCandidates.recordPostSave(
          lowFrictionReturn: readyBag.showLowFrictionReturnCard,
          whatToNoticeNext: readyBag.showWhatToNoticeNextCard,
          betaTodaySummary: readyBag.showBetaTodaySummaryCard,
          openCapturePromptChips: readyBag.showOpenCapturePromptChips,
          captureFreedomLine: readyBag.showCaptureFreedomLine,
          firstProofPayoff:
              readyBag.showFirstProofPayoff &&
              firstProofPayoffCandidate != null,
          whatChanged: showWhatChangedV2 || showWhatChangedV2Display,
          returnPayoff: postSaveBag.showComeBackTomorrowV2PostSave,
          timelineProofMomentPostSave:
              postSaveBag.showTimelineProofMomentOnFirstProofPayoff &&
              timelineProofMomentPostSaveCandidate != null,
          proofSpecificityPostSave:
              postSaveBag.showProofSpecificityOnFirstProofPayoff &&
              postSaveBag.proofSpecificityPostSaveCandidate.shouldShow,
          betaProofFeedback:
              readyBag.showFirstProofPayoff &&
              firstProofPayoffCandidate != null,
          betaInviteLoop: postSaveBag.showBetaInviteLoopPostSave,
          betaProofLift: postSaveBag.hasBetaProofLiftVisible,
          returnAfterProofStrengthened:
              postSaveBag.showReturnAfterProofStrengthenedOnFirstProofPayoff,
          returnAfterProofLiftV2:
              postSaveBag.showReturnAfterProofLiftV2OnPostSave,
          returnAfterProof:
              postSaveBag.showReturnAfterProofGenericOnFirstProofPayoff,
          proofFloorRescue: postSaveBag.blocksProByProofFloorOnPostSave,
          proPreview: postSaveBag.showProPreviewPostSave,
          proUnderstandingLift: postSaveBag.showProUnderstandingLiftOnPostSave,
          proVisibilityLift: postSaveBag.showProVisibilityLiftOnPostSave,
          proBridgeVisibility: postSaveBag.showProBridgeVisibilityPostSave,
          proEvidenceValue: postSaveBag.showProEvidenceValuePostSave,
          proLockMoment: postSaveBag.showProLockMomentPostSave,
          privateReportProBridge:
              postSaveBag.showMonthlyPrivateReportPreviewPostSave,
          betaFeedbackCapture: postSaveBag.showBetaFeedbackCapturePostSave,
        ),
      );
      SurfacePriorityAnalytics.seen(result: recordPostSaveSurfacePriority);
      final audit = recordPostSaveSurfacePriority;
      if (audit.isVisible(
        SurfacePriorityCardKey.whatChanged,
        candidate: showWhatChangedV2 || showWhatChangedV2Display,
      )) {
        readyBag.showFirstProofPayoff = false;
      }
      postSaveBag.applyPriorityAudit(
        audit,
        timelineProof: timelineProofMomentPostSaveCandidate,
        firstProofPayoffVisible: readyBag.showFirstProofPayoff,
        firstProofPayoffCandidate: firstProofPayoffCandidate,
      );
      postSaveLoosenSignals = ProBridgeTimingLoosenEngine.resolveSignals(
        entries: entriesAfterSave,
        source: 'record_post_save',
        beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
        beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
      );
      postSaveProTiming = ProMomentTimingContext(
        surface: ProMomentTimingSurface.recordPostSave,
        source: 'record_post_save',
        entryCount: postSaveEntryCount,
        isPostSaveDegradedState: postSaveDegraded,
        hasFirstProof:
            readyBag.showFirstProofPayoff && firstProofPayoffCandidate != null,
        hasTimelineProofVisible:
            postSaveBag.showTimelineProofMomentOnFirstProofPayoff &&
            timelineProofMomentPostSaveCandidate != null,
        hasFirstProofPayoffVisible: readyBag.showFirstProofPayoff,
        hasMonthlyPrivateReportPreviewVisible:
            postSaveBag.showMonthlyPrivateReportPreviewPostSave,
        hasBetaProofLiftVisible: postSaveBag.hasBetaProofLiftVisible,
        hasReturnAfterProofStrengthenedVisible:
            postSaveBag.showReturnAfterProofStrengthenedOnFirstProofPayoff,
        feedbackState: ProMomentTimingEngine.resolveFeedbackState(
          entries: entriesAfterSave,
          surface: ProofQualityResponseSurface.firstProofPayoff,
        ),
        whatChangedQuestionActive: showWhatChangedV2,
        patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
        confidenceLevel: postSaveLoosenSignals.confidenceLevel,
        hasSafeAnchor: postSaveLoosenSignals.hasSafeAnchor,
        hasFreshReturnAfterCorrection:
            postSaveLoosenSignals.hasFreshReturnAfterCorrection,
        hasSolidStrongPatternWithSafeAnchors:
            postSaveLoosenSignals.hasSolidStrongPatternWithSafeAnchors,
      );
      postSaveBag.applyProMomentGates(postSaveProTiming);
      betaFeedbackCapturePostSaveFinal = BetaFeedbackCaptureEngine.build(
        context: BetaFeedbackCaptureEngine.buildContext(
          surface: BetaFeedbackCaptureSurface.recordPostSave,
          source: 'record_post_save',
          entryCount: postSaveEntryCount,
          isPostSave: true,
          isRecording: flags.isRecording,
          isPostSaveDegradedState: postSaveDegraded,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
          hasPaywallSeen: input.betaActivationLoopCounts.paywallSeen > 0,
          hasPurchaseCtaTapped:
              input.betaActivationLoopCounts.purchaseTapped > 0,
          isPro: input.userProState.isPro,
          timelineProofVisible:
              postSaveBag.showTimelineProofMomentOnFirstProofPayoff &&
              timelineProofMomentPostSaveCandidate != null,
          proPreviewVisible: postSaveBag.showProPreviewPostSave,
          existingProofFeedbackVisible:
              BetaFeedbackCaptureEngine.existingProofFeedbackVisible(
                surface: BetaProofFeedbackSurface.timelineProofMoment,
                parentVisible:
                    postSaveBag.showTimelineProofMomentOnFirstProofPayoff &&
                    timelineProofMomentPostSaveCandidate != null,
                entryCount: postSaveEntryCount,
                hasConfirmedRepeat:
                    EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                      entriesAfterSave,
                    ),
                isRecording: flags.isRecording,
                isPostSaveDegraded: postSaveDegraded,
                whatChangedQuestionActive: showWhatChangedV2,
                patternReviewInboxHasActiveItems:
                    patternReviewInboxActivePostSave,
              ) ||
              BetaFeedbackCaptureEngine.existingProofFeedbackVisible(
                surface: BetaProofFeedbackSurface.firstProofPayoff,
                parentVisible:
                    readyBag.showFirstProofPayoff &&
                    firstProofPayoffCandidate != null,
                entryCount: postSaveEntryCount,
                hasConfirmedRepeat:
                    EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                      entriesAfterSave,
                    ),
                isRecording: flags.isRecording,
                isPostSaveDegraded: postSaveDegraded,
                whatChangedQuestionActive: showWhatChangedV2,
                patternReviewInboxHasActiveItems:
                    patternReviewInboxActivePostSave,
              ),
        ),
      );
      postSaveBag.applyBetaFeedbackResult(betaFeedbackCapturePostSaveFinal);
    }
    return (
      recordPostSaveSurfacePriority: recordPostSaveSurfacePriority,
      postSaveLoosenSignals: postSaveLoosenSignals,
      postSaveProTiming: postSaveProTiming,
      betaFeedbackCapturePostSaveFinal: betaFeedbackCapturePostSaveFinal,
    );
  }

  static RecordSurfaceViewState resolve(RecordSurfaceInput input) {
    final (
      :flags,
      :policyMic,
      :policyUserDenied,
      :firstUseSimplifiedRecord,
      :error,
      :localSaveTitle,
      :syncNote,
      :stageLabel,
      :entriesAfterSave,
      :lastCaptureAnalysisSucceeded,
    ) = resolveInputOverlay(
      input,
    );

    final canRecord = flags.canRecord;
    final showFraming = flags.showFraming;
    final compact = input.compactLayout;
    final stack = input.stackDecision;
    final suppressPostResultNextCheckCompetitors =
        stack.suppressDuplicateUseTomorrowCtas;
    final auditPresentation = VisualAuditOverrides.active
        ? VisualAuditOverrides.peekRecordPresentation()
        : null;
    final justSavedFirstEntry =
        input.recordReturnProJustSaved ||
        (auditPresentation?.justSavedFirst ?? false);
    final postSaveEntryCount = entriesAfterSave.isNotEmpty
        ? entriesAfterSave.length
        : input.entryCount;
    final suppressNoisyFirstSaveCards =
        FirstThreeSessionGates.suppressNoisyPostSaveCards(
          justSavedFirst: justSavedFirstEntry,
          entryCount: flags.isDone && justSavedFirstEntry
              ? postSaveEntryCount
              : input.entryCount,
        );
    final suppressEarlyPatternClaimCards =
        FirstThreeSessionGates.suppressEarlyPatternClaimCards(
          entryCount: input.entryCount,
          hasGroundedRepeatMatch:
              input.secondSessionComparison?.hasEnoughData == true &&
              const SecondSessionSignalEngine().hasGroundedRepeatMatch(
                input.entriesAfterSave.isNotEmpty
                    ? input.entriesAfterSave
                    : input.journalEntries,
              ),
        );
    final suppressLatestSaveArchiveInsight =
        flags.isDone &&
        ArchiveEntrySignalGuard.newestEntryIsLowSignal(entriesAfterSave);
    final secondSessionPayoff =
        flags.isDone &&
            entriesAfterSave.isNotEmpty &&
            !suppressLatestSaveArchiveInsight
        ? SecondSessionPayoffEngine.build(
            entries: entriesAfterSave,
            analysisSucceeded: lastCaptureAnalysisSucceeded,
          )
        : null;
    final thirdEntryBeliefPayoff =
        flags.isDone &&
            entriesAfterSave.isNotEmpty &&
            !suppressLatestSaveArchiveInsight
        ? ThirdEntryBeliefPayoffEngine.build(
            entries: entriesAfterSave,
            analysisSucceeded: lastCaptureAnalysisSucceeded,
          )
        : null;
    final confirmedRepeatTriggerPayoff =
        flags.isDone &&
            entriesAfterSave.isNotEmpty &&
            input.savedFromConfirmedRepeatTrigger
        ? EarlyFirstSignalEngine.buildTriggerCapturePayoff(
            entries: entriesAfterSave,
            savedFromTriggerPrompt: true,
          )
        : null;
    final confirmedRepeatHelpfulActionPayoff =
        flags.isDone &&
            entriesAfterSave.isNotEmpty &&
            input.savedFromHelpfulAction
        ? EarlyFirstSignalEngine.buildHelpfulActionPayoff(
            entries: entriesAfterSave,
            savedFromHelpfulActionPrompt: true,
          )
        : null;
    final confirmedRepeatChangeNotice =
        flags.isDone &&
            entriesAfterSave.isNotEmpty &&
            !input.savedFromConfirmedRepeatTrigger &&
            !input.savedFromHelpfulAction
        ? EarlyFirstSignalEngine.buildChangeNotice(entries: entriesAfterSave)
        : null;
    final repeatReturnCheckOffer = flags.isDone && entriesAfterSave.isNotEmpty
        ? RepeatReturnCheckEngine.pendingForSave(
            entriesAfterSave: entriesAfterSave,
            records: RepeatReturnCheckStore.cached,
          )
        : null;
    final proofStack = resolveArchiveProofStack(
      input: input,
      flags: flags,
      confirmedRepeatTriggerPayoff: confirmedRepeatTriggerPayoff,
      confirmedRepeatHelpfulActionPayoff: confirmedRepeatHelpfulActionPayoff,
      confirmedRepeatChangeNotice: confirmedRepeatChangeNotice,
    );
    final earlyEvidenceTimeline = proofStack.earlyEvidenceTimeline;
    final showEarlyEvidenceTimeline = proofStack.showEarlyEvidenceTimeline;
    final suppressEarlyRepeatPayoffCompetitors =
        proofStack.suppressEarlyRepeatPayoffCompetitors;
    final earlyFirstSignalOnRecord = proofStack.earlyFirstSignalOnRecord;
    final returnTomorrowCueReady = proofStack.returnTomorrowCueReady;
    final returnDayFlowCandidate = proofStack.returnDayFlowCandidate;
    final showReturnDayFlow = proofStack.showReturnDayFlow;
    final showReturnTomorrowCueReady = proofStack.showReturnTomorrowCueReady;
    final firstWeekProgressReady = proofStack.firstWeekProgressReady;
    final showFirstWeekProgressReady = proofStack.showFirstWeekProgressReady;
    final showEarlyReturnReminder = proofStack.showEarlyReturnReminder;
    final viewingConfirmedRepeatOnRecord =
        proofStack.viewingConfirmedRepeatOnRecord;
    final suppressConfirmedRepeatInlineFeedback =
        proofStack.suppressConfirmedRepeatInlineFeedback;
    final showConfirmedRepeatBetaFeedback =
        proofStack.showConfirmedRepeatBetaFeedback;
    final repeatReturnChangeProof = proofStack.repeatReturnChangeProof;
    final patternChangedCandidate = proofStack.patternChangedCandidate;
    final patternChangedDismissed = proofStack.patternChangedDismissed;
    final confirmedRepeatThoughtMap = proofStack.confirmedRepeatThoughtMap;
    final positivePattern = proofStack.positivePattern;
    final helpfulActionAppearedCandidate =
        proofStack.helpfulActionAppearedCandidate;
    final showHelpfulActionAppearedEligible =
        proofStack.showHelpfulActionAppearedEligible;
    final positiveReinforcement = proofStack.positiveReinforcement;
    final archiveSummaryCandidate = proofStack.archiveSummaryCandidate;
    final archiveBeliefSurfaceCandidate =
        proofStack.archiveBeliefSurfaceCandidate;
    final patternNamePrompt = proofStack.patternNamePrompt;
    final showArchiveCurrentBeliefEligible =
        proofStack.showArchiveCurrentBeliefEligible;
    final dailyReturnReasonCandidate = proofStack.dailyReturnReasonCandidate;
    final hasChangeOverTimeProof = proofStack.hasChangeOverTimeProof;
    final postProofArchiveProof = proofStack.postProofArchiveProof;
    final archiveSummaryVisibleForProGate =
        proofStack.archiveSummaryVisibleForProGate;
    final weeklyArchiveReviewVisibleForProGate =
        proofStack.weeklyArchiveReviewVisibleForProGate;
    final hasConfirmedRepeatForProGate =
        proofStack.hasConfirmedRepeatForProGate;
    final privateArchiveReportForProGate =
        proofStack.privateArchiveReportForProGate;
    final privateArchiveReportPreviewForProGate =
        proofStack.privateArchiveReportPreviewForProGate;
    final patternChangedForProGate = proofStack.patternChangedForProGate;
    final hasReturnCheckAnsweredForProGate =
        proofStack.hasReturnCheckAnsweredForProGate;
    final showPostProofProBridge = proofStack.showPostProofProBridge;
    final proofSurfaceLayout = proofStack.proofSurfaceLayout;
    final showArchiveSummary = proofStack.showArchiveSummary;
    final archiveSummary = proofStack.archiveSummary;
    final showDailyReturnReason = proofStack.showDailyReturnReason;
    final dailyReturnReason = proofStack.dailyReturnReason;
    final archiveWatchingCandidate = proofStack.archiveWatchingCandidate;
    final archiveWatching = proofStack.archiveWatching;
    final weeklyArchiveReview = proofStack.weeklyArchiveReview;
    final showWeeklyArchiveReview = proofStack.showWeeklyArchiveReview;
    final privateArchiveReportCandidate =
        proofStack.privateArchiveReportCandidate;
    final showPrivateArchiveReport = proofStack.showPrivateArchiveReport;
    final showConfirmedRepeatWhyMatters =
        proofStack.showConfirmedRepeatWhyMatters;
    final showConfirmedRepeatThoughtMap =
        proofStack.showConfirmedRepeatThoughtMap;
    final showPositiveReinforcement = proofStack.showPositiveReinforcement;
    final firstWeekLoopCandidate = proofStack.firstWeekLoopCandidate;
    final firstWeekLoopProGated = proofStack.firstWeekLoopProGated;
    final recordProofStack = proofStack.recordProofStack;
    final showPatternChanged = proofStack.showPatternChanged;
    final showArchiveCurrentBeliefOnRecord =
        proofStack.showArchiveCurrentBeliefOnRecord;
    final showEarlyEvidenceTimelineOnRecord =
        proofStack.showEarlyEvidenceTimelineOnRecord;
    final showWeeklyArchiveReviewOnRecord =
        proofStack.showWeeklyArchiveReviewOnRecord;
    final showPrivateArchiveReportOnRecord =
        proofStack.showPrivateArchiveReportOnRecord;
    final showDailyReturnReasonOnRecord =
        proofStack.showDailyReturnReasonOnRecord;
    final showPostProofProBridgeOnRecord =
        proofStack.showPostProofProBridgeOnRecord;
    final firstProofPayoffSeenOnRecord =
        FirstProofPayoffEngine.build(entries: input.journalEntries) != null;
    final isDegradedTranscriptOnRecord =
        input.journalEntries.isNotEmpty &&
        VoiceCaptureQuality.isDegradedVoiceCapture(input.journalEntries.last);
    final currentRelevanceCandidate = input.entryCount >= 3
        ? CurrentRelevanceEngine.build(
            entries: input.journalEntries,
            beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
          )
        : null;
    final patternReviewInboxActiveOnRecord =
        CurrentRelevanceEngine.patternReviewInboxHasActiveItems(
          entries: input.journalEntries,
          returnChecks: RepeatReturnCheckStore.cached,
        );
    final (
      :readyBag,
      :currentRelevanceQuestionActiveOnRecord,
      :correctionMemoryCandidate,
      :evidenceWeightingCandidate,
      :proofSpecificityCandidate,
      :presentDayRelevanceCandidate,
      :timelinePositioningCandidate,
      :otherEducationCardsOnRecord,
      :patternConfidenceEducationCount,
      :patternConfidenceExplanationCandidate,
      :showConfirmedRepeatWhyMattersOnRecord,
      :showConfirmedRepeatThoughtMapOnRecord,
      :showPositiveReinforcementOnRecord,
      :showHelpfulActionAppearedOnRecord,
      :showChangeProofOnRecord,
      :showFirstWeekLoopOnRecord,
      :firstProofPayoffCandidate,
      :threeDayChallengeCandidate,
      :showThreeDayChallengeOnRecord,
      :firstProofPatternConfidence,
      :firstProofTruthProofKey,
      :showFirstProofTruth,
      :firstProofTruthAnswer,
      :showFirstProofActionLoop,
      :firstProofActionLoopContent,
      :showFirstProofMoment,
      :postSaveHasConfirmedRepeat,
      :postSaveHasFirstProof,
      :postSaveDegraded,
      :showCoreValueFeedbackOnRecordPostFirstProof,
      :returnCheckPayoffCandidate,
      :whatChangedV2Prompt,
      :whatChangedV2Display,
      :showWhatChangedV2,
      :showWhatChangedV2Display,
      :firstMomentCaptureCandidate,
      :firstSaveLiftCandidate,
      :openingRepairOverride,
      :firstSessionLiftCandidate,
      :secondMomentReturnCandidate,
      :threeMomentCompletionCandidate,
      :firstRunPositioningCandidate,
      :betaTodaySummaryCandidate,
      :archiveTimelineSpineCandidate,
      :whatToNoticeNextCandidate,
      :suppressLegacyEducationCardsForSpineOnRecord,
      :timelineProofMomentCandidate,
      :betaTesterReportCandidate,
      :notRelevantRecoveryCandidate,
      :proofQualityResponseTimelineCandidate,
      :proofQualityResponseSpineCandidate,
      :betaProofLiftTimelineCandidate,
      :returnAfterProofRecordCandidate,
      :returnAfterProofLiftV2Candidate,
      :recordLoosenSignalsPreAudit,
      :recordEvidenceAnchorPreAudit,
      :recordFeedbackStateForLift,
      :timelineFeedbackType,
      :betaRepairLabInput,
      :betaRepairLabProPlacementResult,
      :betaRepairLabPricingValueFramingResult,
      :betaRepairLabPaywallValueResult,
      :hasProEngagementOnRecord,
      :betaRepairLabPricingValidationResult,
      :proUnderstandingLiftRecordReadyInput,
      :proVisibilityLiftRecordReadyResult,
      :betaActivationPathPreAuditContext,
      :betaActivationPathPreAuditResult,
      :betaFeedbackCaptureRecordReadyPreAudit,
      :betaProofFeedbackCounts,
      :betaProofFeedbackRowVisibleOnTimeline,
      :proofQualityRepairInput,
      :proofQualityRepairResult,
      :proofFloorRescueInput,
      :proofFloorRescueResult,
      :blocksProByProofFloorOnRecord,
      :betaRepairLabProofResult,
      :blocksProCardsByProofProtectionOnRecord,
      :betaRepairLabEvidenceTrailClarityResult,
    ) = resolveReadySurface(
      input: input,
      flags: flags,
      entriesAfterSave: entriesAfterSave,
      compact: compact,
      postSaveEntryCount: postSaveEntryCount,
      viewingConfirmedRepeatOnRecord: viewingConfirmedRepeatOnRecord,
      repeatReturnChangeProof: repeatReturnChangeProof,
      archiveBeliefSurfaceCandidate: archiveBeliefSurfaceCandidate,
      privateArchiveReportPreviewForProGate:
          privateArchiveReportPreviewForProGate,
      proofSurfaceLayout: proofSurfaceLayout,
      showConfirmedRepeatWhyMatters: showConfirmedRepeatWhyMatters,
      showConfirmedRepeatThoughtMap: showConfirmedRepeatThoughtMap,
      showPositiveReinforcement: showPositiveReinforcement,
      firstWeekLoopCandidate: firstWeekLoopCandidate,
      firstWeekLoopProGated: firstWeekLoopProGated,
      recordProofStack: recordProofStack,
      showPrivateArchiveReportOnRecord: showPrivateArchiveReportOnRecord,
      showPostProofProBridgeOnRecord: showPostProofProBridgeOnRecord,
      firstProofPayoffSeenOnRecord: firstProofPayoffSeenOnRecord,
      isDegradedTranscriptOnRecord: isDegradedTranscriptOnRecord,
      currentRelevanceCandidate: currentRelevanceCandidate,
      patternReviewInboxActiveOnRecord: patternReviewInboxActiveOnRecord,
    );
    SurfacePriorityResult? recordReadySurfacePriority;
    ProBridgeTimingLoosenSignals? recordLoosenSignals;
    ProMomentTimingContext? recordReadyProTiming;
    BetaActivationPathContext? betaActivationPathFinalContext;
    if (flags.isReady) {
      recordReadySurfacePriority = SurfacePriorityEngine.auditRecordReady(
        entryCount: input.entryCount,
        source: 'record',
        candidates: SurfacePriorityCandidates.recordReady(
          firstSessionProofRepair: readyBag.showFirstSessionCaptureRepairCard,
          firstSessionLift: readyBag.showFirstSessionLiftCard,
          firstSaveLift: readyBag.showFirstSaveLiftCard,
          betaActivationPath:
              readyBag.showBetaActivationPathCard &&
              betaActivationPathPreAuditResult.slot ==
                  BetaActivationPathSlot.guidance,
          betaActivationPathRevenue:
              readyBag.showBetaActivationPathCard &&
              betaActivationPathPreAuditResult.slot ==
                  BetaActivationPathSlot.revenue,
          threeMomentCompletion: readyBag.showThreeMomentCompletionCard,
          firstMomentCapture: readyBag.showFirstMomentCaptureCard,
          secondMomentReturn: readyBag.showSecondMomentReturnCard,
          returnAfterProofStrengthened:
              readyBag.showReturnAfterProofStrengthenedOnRecordReady,
          returnAfterProofLiftV2:
              readyBag.showReturnAfterProofLiftV2OnRecordReady,
          returnAfterProof: readyBag.showReturnAfterProofGenericOnRecordReady,
          lowFrictionReturn: readyBag.showLowFrictionReturnCard,
          whatToNoticeNext: readyBag.showWhatToNoticeNextCard,
          betaTodaySummary: readyBag.showBetaTodaySummaryCard,
          openCapturePromptChips: readyBag.showOpenCapturePromptChips,
          captureFreedomLine: readyBag.showCaptureFreedomLine,
          firstRunPositioning: readyBag.showFirstRunPositioningCard,
          timelineProofMoment:
              readyBag.showTimelineProofMomentOnRecord &&
              timelineProofMomentCandidate != null,
          archiveTimelineSpine:
              readyBag.showArchiveTimelineSpineOnRecord &&
              archiveTimelineSpineCandidate != null,
          timelinePositioning: readyBag.showTimelinePositioningOnRecordReady,
          currentRelevance:
              readyBag.showCurrentRelevanceOnRecordReady &&
              currentRelevanceCandidate != null,
          correctionMemory:
              readyBag.showCorrectionMemoryOnRecordReady &&
              correctionMemoryCandidate != null,
          notRelevantRecovery:
              readyBag.showNotRelevantRecoveryOnRecordReady &&
              notRelevantRecoveryCandidate.shouldShow,
          proofQualityResponse:
              readyBag.showProofQualityResponseOnRecordReady &&
              proofQualityResponseTimelineCandidate.shouldShow,
          proofQualityRepair: readyBag.showProofQualityRepairOnRecord,
          proofFloorRescue: readyBag.showProofFloorRescueOnRecord,
          betaProofLift: readyBag.showBetaProofLiftOnRecordReady,
          evidenceWeighting:
              readyBag.showEvidenceWeightingOnRecordReady &&
              evidenceWeightingCandidate != null,
          proofSpecificity:
              readyBag.showProofSpecificityOnRecordReady &&
              proofSpecificityCandidate.shouldShow,
          presentDayRelevance:
              readyBag.showPresentDayRelevanceOnRecordReady &&
              presentDayRelevanceCandidate != null,
          patternConfidence:
              readyBag.showPatternConfidenceExplanationOnRecordReady &&
              patternConfidenceExplanationCandidate != null,
          betaTesterReport: readyBag.showBetaTesterReportOnRecord,
          proUnderstandingLift: readyBag.showProUnderstandingLiftOnRecordReady,
          proVisibilityLift: readyBag.showProVisibilityLiftOnRecordReady,
          proBridgeVisibility: readyBag.showProBridgeVisibilityOnRecordReady,
          proEvidenceValue: readyBag.showProEvidenceValueOnRecordReady,
          privateReportProBridge:
              readyBag.showProEvidenceValuePrivateReportOnRecord,
          suppressLegacyEducation: suppressLegacyEducationCardsForSpineOnRecord,
          betaFeedbackCapture: readyBag.showBetaFeedbackCaptureRecordReady,
        ),
      );
      SurfacePriorityAnalytics.seen(result: recordReadySurfacePriority);
      final audit = recordReadySurfacePriority;
      readyBag.showFirstSessionCaptureRepairCard = audit.isVisible(
        SurfacePriorityCardKey.firstSessionProofRepair,
        candidate: readyBag.showFirstSessionCaptureRepairCard,
      );
      readyBag.showFirstSessionLiftCard = audit.isVisible(
        SurfacePriorityCardKey.firstSessionLift,
        candidate: readyBag.showFirstSessionLiftCard,
      );
      readyBag.showFirstSaveLiftCard = audit.isVisible(
        SurfacePriorityCardKey.firstSaveLift,
        candidate: readyBag.showFirstSaveLiftCard,
      );
      readyBag.showFirstMomentCaptureCard = audit.isVisible(
        SurfacePriorityCardKey.firstMomentCapture,
        candidate: readyBag.showFirstMomentCaptureCard,
      );
      readyBag.showThreeMomentCompletionCard = audit.isVisible(
        SurfacePriorityCardKey.threeMomentCompletion,
        candidate: readyBag.showThreeMomentCompletionCard,
      );
      readyBag.showSecondMomentReturnCard = audit.isVisible(
        SurfacePriorityCardKey.secondMomentReturn,
        candidate: readyBag.showSecondMomentReturnCard,
      );
      readyBag.showReturnAfterProofStrengthenedOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.returnAfterProofStrengthened,
        candidate: readyBag.showReturnAfterProofStrengthenedOnRecordReady,
      );
      readyBag.showReturnAfterProofLiftV2OnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.returnAfterProofLiftV2,
        candidate: readyBag.showReturnAfterProofLiftV2OnRecordReady,
      );
      readyBag.showReturnAfterProofGenericOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.returnAfterProof,
        candidate: readyBag.showReturnAfterProofGenericOnRecordReady,
      );
      readyBag.showReturnAfterProofOnRecordReady =
          readyBag.showReturnAfterProofStrengthenedOnRecordReady ||
          readyBag.showReturnAfterProofGenericOnRecordReady;
      readyBag.showLowFrictionReturnCard = audit.isVisible(
        SurfacePriorityCardKey.lowFrictionReturn,
        candidate: readyBag.showLowFrictionReturnCard,
      );
      readyBag.showWhatToNoticeNextCard = audit.isVisible(
        SurfacePriorityCardKey.whatToNoticeNext,
        candidate: readyBag.showWhatToNoticeNextCard,
      );
      readyBag.showBetaTodaySummaryCard = audit.isVisible(
        SurfacePriorityCardKey.betaTodaySummary,
        candidate: readyBag.showBetaTodaySummaryCard,
      );
      readyBag.showOpenCapturePromptChips = audit.isVisible(
        SurfacePriorityCardKey.openCapturePromptChips,
        candidate: readyBag.showOpenCapturePromptChips,
      );
      readyBag.showCaptureFreedomLine = audit.isVisible(
        SurfacePriorityCardKey.captureFreedomLine,
        candidate: readyBag.showCaptureFreedomLine,
      );
      readyBag.showFirstRunPositioningCard = audit.isVisible(
        SurfacePriorityCardKey.firstRunPositioning,
        candidate: readyBag.showFirstRunPositioningCard,
      );
      readyBag.showTimelineProofMomentOnRecord = audit.isVisible(
        SurfacePriorityCardKey.timelineProofMoment,
        candidate:
            readyBag.showTimelineProofMomentOnRecord &&
            timelineProofMomentCandidate != null,
      );
      readyBag.showArchiveTimelineSpineOnRecord = audit.isVisible(
        SurfacePriorityCardKey.archiveTimelineSpine,
        candidate:
            readyBag.showArchiveTimelineSpineOnRecord &&
            archiveTimelineSpineCandidate != null,
      );
      readyBag.showTimelinePositioningOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.timelinePositioning,
        candidate: readyBag.showTimelinePositioningOnRecordReady,
      );
      readyBag.showCurrentRelevanceOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.currentRelevance,
        candidate:
            readyBag.showCurrentRelevanceOnRecordReady &&
            currentRelevanceCandidate != null,
      );
      readyBag.showCorrectionMemoryOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.correctionMemory,
        candidate:
            readyBag.showCorrectionMemoryOnRecordReady &&
            correctionMemoryCandidate != null,
      );
      readyBag.showNotRelevantRecoveryOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.notRelevantRecovery,
        candidate:
            readyBag.showNotRelevantRecoveryOnRecordReady &&
            notRelevantRecoveryCandidate.shouldShow,
      );
      readyBag.showProofQualityResponseOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.proofQualityResponse,
        candidate:
            readyBag.showProofQualityResponseOnRecordReady &&
            proofQualityResponseTimelineCandidate.shouldShow,
      );
      readyBag.showBetaProofLiftOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.betaProofLift,
        candidate: readyBag.showBetaProofLiftOnRecordReady,
      );
      readyBag.showEvidenceWeightingOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.evidenceWeighting,
        candidate:
            readyBag.showEvidenceWeightingOnRecordReady &&
            evidenceWeightingCandidate != null,
      );
      readyBag.showProofSpecificityOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.proofSpecificity,
        candidate:
            readyBag.showProofSpecificityOnRecordReady &&
            proofSpecificityCandidate.shouldShow,
      );
      readyBag.showPresentDayRelevanceOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.presentDayRelevance,
        candidate:
            readyBag.showPresentDayRelevanceOnRecordReady &&
            presentDayRelevanceCandidate != null,
      );
      readyBag.showPatternConfidenceExplanationOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.patternConfidence,
        candidate:
            readyBag.showPatternConfidenceExplanationOnRecordReady &&
            patternConfidenceExplanationCandidate != null,
      );
      readyBag.showBetaTesterReportOnRecord = audit.isVisible(
        SurfacePriorityCardKey.betaTesterReport,
        candidate: readyBag.showBetaTesterReportOnRecord,
      );
      readyBag.showProBridgeVisibilityOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.proBridgeVisibility,
        candidate: readyBag.showProBridgeVisibilityOnRecordReady,
      );
      readyBag.showProUnderstandingLiftOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.proUnderstandingLift,
        candidate: readyBag.showProUnderstandingLiftOnRecordReady,
      );
      readyBag.showProVisibilityLiftOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.proVisibilityLift,
        candidate: readyBag.showProVisibilityLiftOnRecordReady,
      );
      readyBag.showProEvidenceValueOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.proEvidenceValue,
        candidate: readyBag.showProEvidenceValueOnRecordReady,
      );
      readyBag.showProEvidenceValuePrivateReportOnRecord = audit.isVisible(
        SurfacePriorityCardKey.privateReportProBridge,
        candidate: readyBag.showProEvidenceValuePrivateReportOnRecord,
      );
      recordLoosenSignals = ProBridgeTimingLoosenEngine.resolveSignals(
        entries: input.journalEntries,
        source: 'record_ready',
        beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
        beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
      );
      recordReadyProTiming = ProMomentTimingContext(
        surface: ProMomentTimingSurface.recordReady,
        source: 'record_ready',
        entryCount: input.entryCount,
        isRecording: flags.isRecording,
        isZeroEntryState: input.entryCount == 0,
        isFirstRecordingState:
            input.entryCount <= 1 && !firstProofPayoffSeenOnRecord,
        isDegradedTranscriptState: isDegradedTranscriptOnRecord,
        hasFirstProof:
            firstProofPayoffSeenOnRecord ||
            EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
              input.journalEntries,
            ),
        hasTimelineProofVisible:
            readyBag.showTimelineProofMomentOnRecord &&
            timelineProofMomentCandidate != null,
        hasBetaTesterReportVisible: readyBag.showBetaTesterReportOnRecord,
        hasCorrectionMemoryVisible:
            readyBag.showCorrectionMemoryOnRecordReady &&
            correctionMemoryCandidate != null,
        hasBetaProofLiftVisible: readyBag.showBetaProofLiftOnRecordReady,
        hasReturnAfterProofStrengthenedVisible:
            readyBag.showReturnAfterProofStrengthenedOnRecordReady,
        feedbackState: ProMomentTimingEngine.resolveFeedbackState(
          entries: input.journalEntries,
          surface: ProofQualityResponseSurface.timelineProofMoment,
        ),
        patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        confidenceLevel: recordLoosenSignals.confidenceLevel,
        hasSafeAnchor: recordLoosenSignals.hasSafeAnchor,
        hasFreshReturnAfterCorrection:
            recordLoosenSignals.hasFreshReturnAfterCorrection,
        hasSolidStrongPatternWithSafeAnchors:
            recordLoosenSignals.hasSolidStrongPatternWithSafeAnchors,
      );
      readyBag.showProBridgeVisibilityOnRecordReady =
          ProMomentTimingEngine.applyGate(
            candidate: readyBag.showProBridgeVisibilityOnRecordReady,
            timing: recordReadyProTiming.copyWith(
              proSlotAvailable:
                  !readyBag.showProUnderstandingLiftOnRecordReady &&
                  !readyBag.showProVisibilityLiftOnRecordReady,
            ),
          );
      readyBag.showProEvidenceValueOnRecordReady =
          ProMomentTimingEngine.applyGate(
            candidate: readyBag.showProEvidenceValueOnRecordReady,
            timing: recordReadyProTiming.copyWith(
              proSlotAvailable:
                  !readyBag.showProUnderstandingLiftOnRecordReady &&
                  !readyBag.showProVisibilityLiftOnRecordReady &&
                  !readyBag.showProBridgeVisibilityOnRecordReady,
            ),
          );
      readyBag.showProEvidenceValuePrivateReportOnRecord =
          ProMomentTimingEngine.applyGate(
            candidate: readyBag.showProEvidenceValuePrivateReportOnRecord,
            timing: recordReadyProTiming.copyWith(
              hasMonthlyPrivateReportPreviewVisible: true,
              proSlotAvailable:
                  readyBag.showProEvidenceValuePrivateReportOnRecord &&
                  !readyBag.showProUnderstandingLiftOnRecordReady &&
                  !readyBag.showProVisibilityLiftOnRecordReady &&
                  !readyBag.showProBridgeVisibilityOnRecordReady &&
                  !readyBag.showProEvidenceValueOnRecordReady,
            ),
          );
      betaActivationPathFinalContext = BetaActivationPathEngine.buildContext(
        source: 'record',
        entryCount: input.entryCount,
        hasTimelineProof:
            readyBag.showTimelineProofMomentOnRecord ||
            readyBag.showArchiveTimelineSpineOnRecord,
        hasPaywallSeen: input.betaActivationLoopCounts.paywallSeen > 0,
        hasPurchaseCtaTapped: input.betaActivationLoopCounts.purchaseTapped > 0,
        strongerProCardVisible:
            readyBag.showProBridgeVisibilityOnRecordReady ||
            readyBag.showProEvidenceValueOnRecordReady ||
            readyBag.showProUnderstandingLiftOnRecordReady ||
            readyBag.showProVisibilityLiftOnRecordReady,
        isReady: flags.isReady,
        isRecording: flags.isRecording,
        isPostSave: input.isPostSave,
        isDegradedTranscriptState: isDegradedTranscriptOnRecord,
        whatChangedQuestionActive: showWhatChangedV2,
        patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        isPermissionBlocked: flags.isPermissionBlocked,
      );
      readyBag.betaActivationPathResult = BetaActivationPathEngine.build(
        context: betaActivationPathFinalContext,
      );
      readyBag.showBetaActivationPathCard =
          readyBag.betaActivationPathResult!.shouldShow;
      if (readyBag.betaActivationPathResult!.slot ==
          BetaActivationPathSlot.guidance) {
        readyBag.showBetaActivationPathCard = audit.isVisible(
          SurfacePriorityCardKey.betaActivationPath,
          candidate: readyBag.showBetaActivationPathCard,
        );
      } else if (readyBag.betaActivationPathResult!.slot ==
          BetaActivationPathSlot.revenue) {
        readyBag.showBetaActivationPathCard = audit.isVisible(
          SurfacePriorityCardKey.betaActivationPathRevenue,
          candidate: readyBag.showBetaActivationPathCard,
        );
      } else {
        readyBag.showBetaActivationPathCard = false;
      }
      readyBag.showProofQualityRepairOnRecord = audit.isVisible(
        SurfacePriorityCardKey.proofQualityRepair,
        candidate: readyBag.showProofQualityRepairOnRecord,
      );
      readyBag.showProofFloorRescueOnRecord = audit.isVisible(
        SurfacePriorityCardKey.proofFloorRescue,
        candidate: readyBag.showProofFloorRescueOnRecord,
      );
      if (readyBag.showProofFloorRescueOnRecord) {
        readyBag.showProofQualityRepairOnRecord = false;
      }
      if (readyBag.showFirstSessionCaptureRepairCard) {
        readyBag.showFirstSessionLiftCard = false;
        readyBag.showFirstSaveLiftCard = false;
        readyBag.showBetaActivationPathCard = false;
      } else if (readyBag.showFirstSessionLiftCard) {
        readyBag.showFirstSaveLiftCard = false;
        readyBag.showBetaActivationPathCard = false;
      } else if (readyBag.showFirstSaveLiftCard) {
        readyBag.showBetaActivationPathCard = false;
      }
      if (readyBag.showBetaActivationPathCard &&
          readyBag.betaActivationPathResult!.slot ==
              BetaActivationPathSlot.guidance) {
        readyBag.showThreeMomentCompletionCard = false;
        readyBag.showFirstMomentCaptureCard = false;
        readyBag.showSecondMomentReturnCard = false;
      }
      readyBag.showBetaFeedbackCaptureRecordReady = audit.isVisible(
        SurfacePriorityCardKey.betaFeedbackCapture,
        candidate: readyBag.showBetaFeedbackCaptureRecordReady,
      );
      readyBag.betaFeedbackCaptureRecordReadyResult =
          readyBag.showBetaFeedbackCaptureRecordReady
          ? betaFeedbackCaptureRecordReadyPreAudit
          : null;
    }
    if (readyBag.showTimelineProofMomentOnRecord &&
        timelineProofMomentCandidate != null) {
      ShareableProofSeenLatch.markTimelineProofMomentSeen();
    }
    if (readyBag.showBetaTesterReportOnRecord) {
      ShareableProofSeenLatch.markBetaTesterReportSeen();
    }
    final shareableNonPrivateProofResult = ShareableProofEngine.build(
      input: ShareableProofVisibilityInput(
        entryCount: input.entryCount,
        timelineProofMomentSeen:
            ShareableProofSeenLatch.timelineProofMomentSeen,
        betaTesterReportSeen: ShareableProofSeenLatch.betaTesterReportSeen,
        isRecording: flags.isRecording,
        isDegradedTranscript: isDegradedTranscriptOnRecord,
        whatChangedQuestionActive: showWhatChangedV2,
        patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
      ),
    );
    final showShareableNonPrivateProofOnRecord =
        shareableNonPrivateProofResult.shouldShow;
    final proofSpecificityBoostCandidate = ProofSpecificityBoostEngine.build(
      entries: input.journalEntries,
      beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
      source: 'record',
      beliefEvidencePhrases: archiveBeliefSurfaceCandidate.evidencePhrases,
    );
    final timelineProofParentVisible =
        readyBag.showTimelineProofMomentOnRecord &&
        timelineProofMomentCandidate != null;
    var showProofSpecificityBoostOnTimelineProof =
        flags.isReady &&
        ProofSpecificityBoostEngine.shouldRender(
          result: proofSpecificityBoostCandidate,
          surface: ProofSpecificityBoostSurface.timelineProofMoment,
          parentVisible: timelineProofParentVisible,
          timelineProofVisible: timelineProofParentVisible,
          firstProofPayoffVisible: false,
          isRecording: flags.isRecording,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    final showProofQualityResponseUnderTimelineProof =
        readyBag.showTimelineProofMomentOnRecord &&
        timelineProofMomentCandidate != null &&
        ProofQualityResponseEngine.shouldRender(
          result: proofQualityResponseTimelineCandidate,
          parentVisible: true,
          timelineProofVisible: true,
          firstProofPayoffVisible: false,
          isRecording: flags.isRecording,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    final showProofQualityResponseUnderArchiveSpine =
        readyBag.showArchiveTimelineSpineOnRecord &&
        archiveTimelineSpineCandidate != null &&
        !showProofQualityResponseUnderTimelineProof &&
        ProofQualityResponseEngine.shouldRender(
          result: proofQualityResponseSpineCandidate,
          parentVisible: true,
          timelineProofVisible: false,
          firstProofPayoffVisible: false,
          isRecording: flags.isRecording,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    var showNotRelevantRecoveryUnderTimelineProof =
        readyBag.showTimelineProofMomentOnRecord &&
        timelineProofMomentCandidate != null &&
        NotRelevantRecoveryEngine.shouldRender(
          result: notRelevantRecoveryCandidate,
          parentVisible: true,
          isRecording: flags.isRecording,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    if (showNotRelevantRecoveryUnderTimelineProof) {
      readyBag.showNotRelevantRecoveryOnRecordReady = false;
    }
    if (showProofQualityResponseUnderTimelineProof ||
        showProofQualityResponseUnderArchiveSpine) {
      readyBag.showProofQualityResponseOnRecordReady = false;
      if (ProofQualityResponseEngine.coversLegacyBoost(
        result: proofQualityResponseTimelineCandidate,
        parentVisible: true,
        timelineProofVisible: showProofQualityResponseUnderTimelineProof,
        firstProofPayoffVisible: false,
        isRecording: flags.isRecording,
        isDegradedTranscriptState: isDegradedTranscriptOnRecord,
        isPostSaveDegradedState: false,
        whatChangedQuestionActive: showWhatChangedV2,
        patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
      )) {
        showProofSpecificityBoostOnTimelineProof = false;
      }
      if (ProofQualityResponseEngine.coversLegacyNotRelevant(
            result: proofQualityResponseTimelineCandidate,
            parentVisible: true,
            timelineProofVisible: showProofQualityResponseUnderTimelineProof,
            firstProofPayoffVisible: false,
            isRecording: flags.isRecording,
            isDegradedTranscriptState: isDegradedTranscriptOnRecord,
            isPostSaveDegradedState: false,
            whatChangedQuestionActive: showWhatChangedV2,
            patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
          ) ||
          ProofQualityResponseEngine.coversLegacyNotRelevant(
            result: proofQualityResponseSpineCandidate,
            parentVisible: true,
            timelineProofVisible: false,
            firstProofPayoffVisible: false,
            isRecording: flags.isRecording,
            isDegradedTranscriptState: isDegradedTranscriptOnRecord,
            isPostSaveDegradedState: false,
            whatChangedQuestionActive: showWhatChangedV2,
            patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
          )) {
        showNotRelevantRecoveryUnderTimelineProof = false;
        readyBag.showNotRelevantRecoveryOnRecordReady = false;
      }
    }
    final showBetaProofLiftUnderTimelineProof =
        readyBag.showBetaProofLiftOnRecordReady &&
        readyBag.showTimelineProofMomentOnRecord &&
        timelineProofMomentCandidate != null;
    if (BetaProofLiftEngine.coversLegacyBoost(
      result: betaProofLiftTimelineCandidate,
      parentVisible: timelineProofParentVisible,
      timelineProofVisible: timelineProofParentVisible,
      firstProofPayoffVisible: false,
      isRecording: flags.isRecording,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      isPostSaveDegradedState: false,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
    )) {
      showProofSpecificityBoostOnTimelineProof = false;
    }
    final showReturnAfterProofLiftV2BelowProofOnRecord =
        readyBag.showReturnAfterProofLiftV2OnRecordReady &&
        ((readyBag.showTimelineProofMomentOnRecord &&
                timelineProofMomentCandidate != null) ||
            readyBag.showBetaTesterReportOnRecord);
    final showReturnAfterProofLiftV2InGuidanceStack =
        readyBag.showReturnAfterProofLiftV2OnRecordReady &&
        !showReturnAfterProofLiftV2BelowProofOnRecord;
    final showReturnAfterProofBelowProofOnRecord =
        readyBag.showReturnAfterProofOnRecordReady &&
        !readyBag.showReturnAfterProofLiftV2OnRecordReady &&
        ((readyBag.showTimelineProofMomentOnRecord &&
                timelineProofMomentCandidate != null) ||
            readyBag.showBetaTesterReportOnRecord);
    final showReturnAfterProofInGuidanceStack =
        readyBag.showReturnAfterProofOnRecordReady &&
        !showReturnAfterProofBelowProofOnRecord;
    if (firstUseSimplifiedRecord) {
      readyBag.showFirstSaveLiftCard = false;
      readyBag.showFirstSessionLiftCard = false;
      readyBag.showFirstSessionCaptureRepairCard = false;
      readyBag.showSecondMomentReturnCard = false;
      readyBag.showBetaActivationPathCard = false;
      readyBag.showCaptureFreedomLine = false;
      readyBag.showLowFrictionReturnCard = false;
      readyBag.showBetaTodaySummaryCard = false;
      readyBag.showWhatToNoticeNextCard = false;
      readyBag.showFirstMomentCaptureCard = false;
      readyBag.showThreeMomentCompletionCard = false;
      readyBag.showOpenCapturePromptChips = false;
    }
    final showProUnderstandingLiftBelowProofOnRecord =
        readyBag.showProUnderstandingLiftOnRecordReady &&
        ((readyBag.showTimelineProofMomentOnRecord &&
                timelineProofMomentCandidate != null) ||
            readyBag.showBetaTesterReportOnRecord ||
            showReturnAfterProofLiftV2BelowProofOnRecord);
    final showBetaRepairLabEvidenceTrailClarityBelowProofOnRecord =
        readyBag.showBetaRepairLabEvidenceTrailClarityOnRecord &&
        betaRepairLabEvidenceTrailClarityResult.shouldShow &&
        ((readyBag.showTimelineProofMomentOnRecord &&
                timelineProofMomentCandidate != null) ||
            readyBag.showBetaTesterReportOnRecord ||
            showReturnAfterProofLiftV2BelowProofOnRecord);
    final showBetaRepairLabPricingValidationBelowProofOnRecord =
        readyBag.showBetaRepairLabPricingValidationOnRecord &&
        betaRepairLabPricingValidationResult.shouldShow &&
        ((readyBag.showTimelineProofMomentOnRecord &&
                timelineProofMomentCandidate != null) ||
            readyBag.showBetaTesterReportOnRecord ||
            showReturnAfterProofLiftV2BelowProofOnRecord);
    final showBetaRepairLabPricingValueFramingBelowProofOnRecord =
        readyBag.showBetaRepairLabPricingValueFramingOnRecord &&
        betaRepairLabPricingValueFramingResult.shouldShow &&
        ((readyBag.showTimelineProofMomentOnRecord &&
                timelineProofMomentCandidate != null) ||
            readyBag.showBetaTesterReportOnRecord ||
            showReturnAfterProofLiftV2BelowProofOnRecord);
    final showBetaRepairLabPaywallValueBelowProofOnRecord =
        readyBag.showBetaRepairLabPaywallValueOnRecord &&
        betaRepairLabPaywallValueResult.shouldShow &&
        ((readyBag.showTimelineProofMomentOnRecord &&
                timelineProofMomentCandidate != null) ||
            readyBag.showBetaTesterReportOnRecord ||
            showReturnAfterProofLiftV2BelowProofOnRecord);
    final showBetaRepairLabProPlacementBelowProofOnRecord =
        readyBag.showBetaRepairLabProPlacementOnRecord &&
        betaRepairLabProPlacementResult.shouldShow &&
        ((readyBag.showTimelineProofMomentOnRecord &&
                timelineProofMomentCandidate != null) ||
            readyBag.showBetaTesterReportOnRecord ||
            showReturnAfterProofLiftV2BelowProofOnRecord);
    if (ArchiveBetaMissionGate.isEnabled) {
      ProPlacementTriggerAuditEngine.updateLatestInput(
        ProPlacementTriggerAuditInput(
          betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
          activeRepairMode: BetaRepairLabStore.activeMode,
          entryCount: input.entryCount,
          confidenceLevel:
              recordLoosenSignalsPreAudit.confidenceLevel ??
              ProofConfidenceLevel.watchOnly,
          hasSafeAnchor: recordLoosenSignalsPreAudit.hasSafeAnchor,
          hasMatchQuality: !ProofFloorRescueEngine.resolveHasLowMatchQuality(
            entries: input.journalEntries,
            beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
            source: 'record_ready',
            beliefEvidencePhrases:
                archiveBeliefSurfaceCandidate.evidencePhrases,
          ),
          hasConfirmedRepeat:
              EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                input.journalEntries,
              ),
          hasTimelineProofVisible:
              readyBag.showTimelineProofMomentOnRecord &&
              timelineProofMomentCandidate != null,
          feedbackType: timelineFeedbackType,
          hasUsefulOrStrongProof:
              ProPlacementTriggerAuditEngine.hasUsefulOrStrongProof(
                feedbackType: timelineFeedbackType,
                confidenceLevel:
                    recordLoosenSignalsPreAudit.confidenceLevel ??
                    ProofConfidenceLevel.watchOnly,
              ),
          proPlacementEligible: readyBag.showBetaRepairLabProPlacementOnRecord,
          proPlacementShown: showBetaRepairLabProPlacementBelowProofOnRecord,
          proPlacementBlocked:
              BetaRepairLabEngine.isRepairActive(
                BetaRepairLabMode.proPlacementAfterUsefulProof,
              ) &&
              !showBetaRepairLabProPlacementBelowProofOnRecord,
          hasProEngagement: hasProEngagementOnRecord,
          source: 'record_ready',
        ),
      );
    }
    final showProUnderstandingLiftInProSectionOnRecord =
        readyBag.showProUnderstandingLiftOnRecordReady &&
        !showProUnderstandingLiftBelowProofOnRecord;
    final showProVisibilityLiftBelowProofOnRecord =
        readyBag.showProVisibilityLiftOnRecordReady &&
        !readyBag.showProUnderstandingLiftOnRecordReady &&
        ((readyBag.showTimelineProofMomentOnRecord &&
                timelineProofMomentCandidate != null) ||
            readyBag.showBetaTesterReportOnRecord ||
            showReturnAfterProofLiftV2BelowProofOnRecord);
    final showProVisibilityLiftInProSectionOnRecord =
        readyBag.showProVisibilityLiftOnRecordReady &&
        !showProVisibilityLiftBelowProofOnRecord;
    final showProBridgeBelowProofOnRecord =
        readyBag.showProBridgeVisibilityOnRecordReady &&
        !readyBag.showProUnderstandingLiftOnRecordReady &&
        !readyBag.showProVisibilityLiftOnRecordReady &&
        ((readyBag.showTimelineProofMomentOnRecord &&
                timelineProofMomentCandidate != null) ||
            readyBag.showBetaTesterReportOnRecord ||
            readyBag.showReturnAfterProofStrengthenedOnRecordReady);
    final showProBridgeInProSectionOnRecord =
        readyBag.showProBridgeVisibilityOnRecordReady &&
        !readyBag.showProUnderstandingLiftOnRecordReady &&
        !readyBag.showProVisibilityLiftOnRecordReady &&
        !showProBridgeBelowProofOnRecord;
    final proBridgeVisibilityRecordResult =
        readyBag.showProBridgeVisibilityOnRecordReady
        ? ProBridgeVisibilityEngine.build(
            input: ProBridgeTimingLoosenEngine.enrichVisibilityInput(
              base: ProBridgeVisibilityInput(
                surface: ProBridgeVisibilitySurface.recordReady,
                source: 'record_ready',
                entryCount: input.entryCount,
                isPro: input.userProState.isPro,
                postProofProBridgeEnabled: showPostProofProBridgeOnRecord,
                hasFirstProof:
                    firstProofPayoffSeenOnRecord ||
                    EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                      input.journalEntries,
                    ),
                hasTimelineProofVisible:
                    readyBag.showTimelineProofMomentOnRecord &&
                    timelineProofMomentCandidate != null,
                hasBetaTesterReportVisible:
                    readyBag.showBetaTesterReportOnRecord,
                hasCorrectionMemoryVisible:
                    readyBag.showCorrectionMemoryOnRecordReady &&
                    correctionMemoryCandidate != null,
                hasBetaProofLiftVisible:
                    readyBag.showBetaProofLiftOnRecordReady,
                hasReturnAfterProofStrengthenedVisible:
                    readyBag.showReturnAfterProofStrengthenedOnRecordReady,
                feedbackState: ProMomentTimingEngine.resolveFeedbackState(
                  entries: input.journalEntries,
                  surface: ProofQualityResponseSurface.timelineProofMoment,
                ),
                compact: proofSurfaceLayout.proBridgeCompact,
                hasSeenFirstRepeat: DelayedPaywallProofStore.hasSeenFirstRepeat,
                hasOpenedEvidenceTrail:
                    DelayedPaywallProofStore.hasOpenedEvidenceTrail,
              ),
              entries: input.journalEntries,
              beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
              beliefEvidencePhrases:
                  archiveBeliefSurfaceCandidate.evidencePhrases,
              hasBetaProofLiftVisible: readyBag.showBetaProofLiftOnRecordReady,
              hasReturnAfterProofStrengthenedVisible:
                  readyBag.showReturnAfterProofStrengthenedOnRecordReady,
            ),
          )
        : null;
    final patternReviewInboxActivePostSave =
        ProofSpecificityEngine.patternReviewInboxHasActiveItems(
          entries: entriesAfterSave,
          returnChecks: RepeatReturnCheckStore.cached,
        );
    final timelineProofMomentPostSaveCandidate = entriesAfterSave.length >= 3
        ? TimelineProofMomentEngine.build(
            entries: entriesAfterSave,
            beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
            source: 'record_post_save',
            compact: true,
          )
        : null;
    final postSaveBag = resolvePostSaveCardsA(
      input: input,
      flags: flags,
      entriesAfterSave: entriesAfterSave,
      postSaveEntryCount: postSaveEntryCount,
      readyBag: readyBag,
      firstProofPayoffCandidate: firstProofPayoffCandidate,
      showFirstProofTruth: showFirstProofTruth,
      postSaveDegraded: postSaveDegraded,
      showWhatChangedV2: showWhatChangedV2,
      archiveBeliefSurfaceCandidate: archiveBeliefSurfaceCandidate,
      showPostProofProBridgeOnRecord: showPostProofProBridgeOnRecord,
      patternReviewInboxActivePostSave: patternReviewInboxActivePostSave,
      timelineProofMomentPostSaveCandidate:
          timelineProofMomentPostSaveCandidate,
    );
    const betaFeedbackRecordSurfaces = [
      BetaFeedbackIntelligenceSurface.afterProEvidenceSheet,
      BetaFeedbackIntelligenceSurface.afterFirstProofPayoff,
    ];
    final betaFeedbackIntelligenceSurfaceOnRecordReady = flags.isReady
        ? BetaFeedbackIntelligenceEngine.resolveVisibleSurface(
            candidates: betaFeedbackRecordSurfaces,
            entryCount: input.entryCount,
            entries: input.journalEntries,
            returnChecks: RepeatReturnCheckStore.cached,
            isZeroEntryState: input.entryCount == 0,
            isDegradedTranscriptState: isDegradedTranscriptOnRecord,
            firstProofPayoffVisible: firstProofPayoffSeenOnRecord,
          )
        : null;
    final betaFeedbackIntelligenceSurfacePostSave =
        flags.isDone && entriesAfterSave.isNotEmpty
        ? BetaFeedbackIntelligenceEngine.resolveVisibleSurface(
            candidates: betaFeedbackRecordSurfaces,
            entryCount: postSaveEntryCount,
            entries: entriesAfterSave,
            returnChecks: RepeatReturnCheckStore.cached,
            isPostSaveDegradedState: VoiceCaptureQuality.isDegradedVoiceCapture(
              entriesAfterSave.last,
            ),
            firstProofTruthQuestionActive: showFirstProofTruth,
            whatChangedQuestionActive: showWhatChangedV2,
            firstProofPayoffVisible:
                readyBag.showFirstProofPayoff &&
                firstProofPayoffCandidate != null,
          )
        : null;
    final helpedTrackingPrompt = flags.isDone && entriesAfterSave.isNotEmpty
        ? HelpedTrackingEngine.buildPrompt(
            entries: entriesAfterSave,
            isPostSaveDone: flags.isDone,
            isDegradedPostSave:
                entriesAfterSave.isNotEmpty &&
                VoiceCaptureQuality.isDegradedVoiceCapture(
                  entriesAfterSave.last,
                ),
            showWhatChangedV2: showWhatChangedV2,
          )
        : null;
    final showHelpedTracking =
        helpedTrackingPrompt != null && !readyBag.showFirstProofPayoff;
    final showReturnCheckPayoff = ReturnCheckPayoffGates.shouldShow(
      isPostSaveDone: flags.isDone,
      entryCount: postSaveEntryCount,
      isDegradedPostSave:
          entriesAfterSave.isNotEmpty &&
          VoiceCaptureQuality.isDegradedVoiceCapture(entriesAfterSave.last),
      showFirstProofMoment: showFirstProofMoment,
      showPostSaveReturnCheckAnswer: showWhatChangedV2,
      payoff: returnCheckPayoffCandidate,
    );
    final showArchiveSummaryOnRecord =
        recordProofStack.showArchiveSummary &&
        !showFirstProofMoment &&
        !showReturnCheckPayoff &&
        !showWhatChangedV2;
    final confirmedRepeatChangeNoticeOnRecord =
        flags.isReady &&
            input.entryCountLoaded &&
            RecordEmptyArchiveGates.showConfirmedRepeatChangeNoticeCard(
              loaded: input.entryCountLoaded,
              entryCount: input.entryCount,
              isPostSave: input.isPostSave,
            ) &&
            !showEarlyEvidenceTimelineOnRecord &&
            !showArchiveSummaryOnRecord
        ? EarlyFirstSignalEngine.buildChangeNotice(
            entries: input.journalEntries,
          )
        : null;
    final lowEvidenceGuidance = recordProofStack.showEarlyRepeatProgress
        ? LowEvidenceEngine.buildForRecordReady(entries: input.journalEntries)
        : null;
    final quietSignalCandidate =
        flags.isReady && input.entryCountLoaded && !input.isPostSave
        ? QuietSignalEngine.build(entries: input.journalEntries)
        : null;
    final showQuietSignalOnRecord = QuietSignalGates.shouldShowOnRecordReady(
      isReady: flags.isReady,
      isRecording: flags.isRecording,
      isPostSave: input.isPostSave,
      signal: quietSignalCandidate,
      showReturnDayFlow: showReturnDayFlow,
    );
    final showLowEvidenceGuidanceOnRecord =
        flags.isReady &&
        input.entryCountLoaded &&
        recordProofStack.showEarlyRepeatProgress &&
        lowEvidenceGuidance != null &&
        !showReturnTomorrowCueReady &&
        !showReturnDayFlow &&
        !showQuietSignalOnRecord;
    final dailyThoughtprintmoryCandidate =
        flags.isReady && input.entryCountLoaded && !input.isPostSave
        ? DailyThoughtprintmoryEngine.build(
            entries: input.journalEntries,
            confirmedRepeat: earlyFirstSignalOnRecord,
            changeProof: repeatReturnChangeProof,
            returnChecks: RepeatReturnCheckStore.cached,
            triggerCapturedMilestone: input.earlyEvidenceTriggerCaptured,
            helpfulActionCapturedMilestone: input.earlyEvidenceHelpfulCaptured,
            viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
            isRecording: flags.isRecording,
            isPostSave: input.isPostSave,
          )
        : null;
    final firstProofLoopActive =
        readyBag.showFirstProofPayoff ||
        showFirstProofTruth ||
        showFirstProofActionLoop;
    final showDailyThoughtprintmory =
        !V1FeatureFlags.enableV1Only &&
        DailyThoughtprintmoryGates.shouldShow(
          loaded: input.entryCountLoaded,
          entryCount: input.entryCount,
          isReady: flags.isReady,
          isRecording: flags.isRecording,
          isPostSave: input.isPostSave,
          memory: dailyThoughtprintmoryCandidate,
          showReturnDayFlow: showReturnDayFlow,
          showReturnTomorrowCueReady: showReturnTomorrowCueReady,
          showLowEvidenceGuidance: showLowEvidenceGuidanceOnRecord,
          showWeeklyArchiveReview: showWeeklyArchiveReviewOnRecord,
          firstProofLoopActive: firstProofLoopActive,
          showComeBackTomorrowQuietSignal: showQuietSignalOnRecord,
        );
    final showReturningWatchTargetFocusedUi =
        ReturningRecordWatchTargetUiGates.showFocusedSurface(
          showDailyThoughtprintmory: showDailyThoughtprintmory,
          dailyThoughtprintmory: dailyThoughtprintmoryCandidate,
        );
    final recordReadyShowsWatchTargetOnly =
        showReturningWatchTargetFocusedUi && flags.isReady && !input.isPostSave;
    final recordReadySuppressStreakPressure =
        recordReadyShowsWatchTargetOnly ||
        ReturningRecordWatchTargetUiGates.suppressDailyStreakPressureToday();
    if (showReturningWatchTargetFocusedUi) {
      readyBag.showOpenCapturePromptChips = false;
      readyBag.showLowFrictionReturnCard = false;
      readyBag.showCaptureFreedomLine = false;
      readyBag.showBetaTodaySummaryCard = false;
      readyBag.showBetaActivationPathCard = false;
      readyBag.showBetaTesterReportOnRecord = false;
      readyBag.showBetaFeedbackCaptureRecordReady = false;
      readyBag.betaFeedbackCaptureRecordReadyResult = null;
      readyBag.showBetaProofLiftOnRecordReady = false;
      readyBag.showBetaRepairLabProPlacementOnRecord = false;
      readyBag.showBetaRepairLabPricingValueFramingOnRecord = false;
      readyBag.showBetaRepairLabPaywallValueOnRecord = false;
      readyBag.showBetaRepairLabPricingValidationOnRecord = false;
      readyBag.showBetaRepairLabEvidenceTrailClarityOnRecord = false;
      readyBag.showBetaRepairLabProofOnRecord = false;
    }
    if (!ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces()) {
      readyBag.showBetaTodaySummaryCard = false;
      readyBag.showBetaActivationPathCard = false;
      readyBag.showBetaTesterReportOnRecord = false;
      readyBag.showBetaFeedbackCaptureRecordReady = false;
      readyBag.betaFeedbackCaptureRecordReadyResult = null;
      readyBag.showBetaProofLiftOnRecordReady = false;
      readyBag.showBetaRepairLabProPlacementOnRecord = false;
      readyBag.showBetaRepairLabPricingValueFramingOnRecord = false;
      readyBag.showBetaRepairLabPaywallValueOnRecord = false;
      readyBag.showBetaRepairLabPricingValidationOnRecord = false;
      readyBag.showBetaRepairLabEvidenceTrailClarityOnRecord = false;
      readyBag.showBetaRepairLabProofOnRecord = false;
    }
    final betaTestScriptCardCandidate = flags.isReady && input.entryCountLoaded
        ? BetaTestScriptEngine.buildCompactCard(entries: input.journalEntries)
        : null;
    final showBetaTestScriptCard =
        BetaTestScriptGates.shouldShowCompactCardOnRecord(
          isReady: flags.isReady,
          isRecording: flags.isRecording,
          isPostSave: input.isPostSave,
          dismissed: BetaTestScriptStore.cached.dismissed,
          showReturnDayFlow: showReturnDayFlow,
          firstProofLoopActive: firstProofLoopActive,
          showWhatChangedV2Display: showWhatChangedV2Display,
        );
    final daysSinceLastEntry = CaptureRecoveryGates.daysSinceLastEntry(
      entries: input.journalEntries,
    );
    final showReturnedAfterDelayRecovery =
        CaptureRecoveryGates.showReturnedAfterDelay(
          entryCount: input.entryCount,
          daysSinceLastEntry: daysSinceLastEntry,
          isReady: flags.isReady,
          isRecording: flags.isRecording,
          isPostSave: input.isPostSave,
        );
    final nextBestActionCandidate =
        flags.isReady && input.entryCountLoaded && !input.isPostSave
        ? NextBestActionEngine.build(
            entries: input.journalEntries,
            returnChecks: RepeatReturnCheckStore.cached,
            helpfulActionCapturedMilestone: input.earlyEvidenceHelpfulCaptured,
            privateReportForming:
                showPrivateArchiveReportOnRecord &&
                privateArchiveReportCandidate != null,
          )
        : null;
    final showNextBestActionOnRecord = NextBestActionGates.shouldShow(
      action: nextBestActionCandidate,
      surface: NextBestActionSurface.record,
      showEarlyRepeatProgress: recordProofStack.showEarlyRepeatProgress,
      showPostSaveReturnCheckAnswer: showWhatChangedV2,
      repeatReturnCheckOfferVisible: repeatReturnCheckOffer != null,
      showPatternChangedCard:
          showPatternChanged && patternChangedCandidate != null,
      showHelpfulActionCard:
          showHelpfulActionAppearedOnRecord &&
          helpfulActionAppearedCandidate != null,
      showPrivateArchiveReportCard:
          showPrivateArchiveReportOnRecord &&
          privateArchiveReportCandidate != null,
    );
    resolvePostSaveCardsB(
      input: input,
      flags: flags,
      entriesAfterSave: entriesAfterSave,
      postSaveEntryCount: postSaveEntryCount,
      postSaveBag: postSaveBag,
      readyBag: readyBag,
      firstProofPayoffCandidate: firstProofPayoffCandidate,
      showFirstProofMoment: showFirstProofMoment,
      showFirstProofTruth: showFirstProofTruth,
      showFirstProofActionLoop: showFirstProofActionLoop,
      showWhatChangedV2: showWhatChangedV2,
      showWhatChangedV2Display: showWhatChangedV2Display,
      showHelpedTracking: showHelpedTracking,
      postSaveDegraded: postSaveDegraded,
      suppressNoisyFirstSaveCards: suppressNoisyFirstSaveCards,
      patternReviewInboxActivePostSave: patternReviewInboxActivePostSave,
      timelineProofMomentPostSaveCandidate:
          timelineProofMomentPostSaveCandidate,
      archiveBeliefSurfaceCandidate: archiveBeliefSurfaceCandidate,
    );
    final (
      :recordPostSaveSurfacePriority,
      :postSaveLoosenSignals,
      :postSaveProTiming,
      :betaFeedbackCapturePostSaveFinal,
    ) = auditPostSaveSurfaces(
      input: input,
      flags: flags,
      entriesAfterSave: entriesAfterSave,
      postSaveEntryCount: postSaveEntryCount,
      postSaveBag: postSaveBag,
      readyBag: readyBag,
      firstProofPayoffCandidate: firstProofPayoffCandidate,
      postSaveDegraded: postSaveDegraded,
      showWhatChangedV2: showWhatChangedV2,
      showWhatChangedV2Display: showWhatChangedV2Display,
      archiveBeliefSurfaceCandidate: archiveBeliefSurfaceCandidate,
      patternReviewInboxActivePostSave: patternReviewInboxActivePostSave,
      timelineProofMomentPostSaveCandidate:
          timelineProofMomentPostSaveCandidate,
    );
    final proPreviewPostSaveResult = postSaveBag.showProPreviewPostSave
        ? ProPreviewEngine.build(
            context: ProPreviewEngine.buildContext(
              surface: ProPreviewSurface.recordPostSave,
              source: 'record_post_save',
              entryCount: postSaveEntryCount,
              isPro: input.userProState.isPro,
              dismissed: ProPreviewEngine.isDismissed(),
              entries: entriesAfterSave,
              hasTimelineProofVisible: postSaveBag.hasTimelineProofVisible(
                timelineProofMomentPostSaveCandidate,
              ),
              firstProofPayoffVisible: readyBag.showFirstProofPayoff,
              isPostSaveDegradedState: postSaveDegraded,
              firstProofTruthQuestionActive: showFirstProofTruth,
              whatChangedQuestionActive: showWhatChangedV2,
              patternReviewInboxHasActiveItems:
                  patternReviewInboxActivePostSave,
            ),
          )
        : null;
    final betaInviteLoopPostSaveResult = postSaveBag.showBetaInviteLoopPostSave
        ? BetaInviteLoopEngine.build(
            context: BetaInviteLoopEngine.buildContext(
              surface: BetaInviteLoopSurface.recordPostSave,
              source: 'record_post_save',
              entryCount: postSaveEntryCount,
              entries: entriesAfterSave,
              beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
              beliefEvidencePhrases:
                  archiveBeliefSurfaceCandidate.evidencePhrases,
              isPostSaveDegradedState: postSaveDegraded,
              whatChangedQuestionActive: showWhatChangedV2,
              patternReviewInboxHasActiveItems:
                  patternReviewInboxActivePostSave,
            ),
          )
        : null;
    final proBridgeVisibilityPostSaveResult =
        postSaveBag.showProBridgeVisibilityPostSave
        ? ProBridgeVisibilityEngine.build(
            input: ProBridgeTimingLoosenEngine.enrichVisibilityInput(
              base: ProBridgeVisibilityInput(
                surface: ProBridgeVisibilitySurface.recordPostSaveAfterPayoff,
                source: 'record_post_save',
                entryCount: postSaveEntryCount,
                isPro: input.userProState.isPro,
                postProofProBridgeEnabled: showPostProofProBridgeOnRecord,
                hasFirstProof: true,
                isPostSaveDegradedState: postSaveDegraded,
                hasFirstProofPayoffVisible: readyBag.showFirstProofPayoff,
                hasTimelineProofVisible: postSaveBag.hasTimelineProofVisible(
                  timelineProofMomentPostSaveCandidate,
                ),
                hasBetaProofLiftVisible: postSaveBag.hasBetaProofLiftVisible,
                hasReturnAfterProofStrengthenedVisible: postSaveBag
                    .showReturnAfterProofStrengthenedOnFirstProofPayoff,
                feedbackState: ProMomentTimingEngine.resolveFeedbackState(
                  entries: entriesAfterSave,
                  surface: ProofQualityResponseSurface.firstProofPayoff,
                ),
                whatChangedQuestionActive: showWhatChangedV2,
                patternReviewInboxHasActiveItems:
                    patternReviewInboxActivePostSave,
                hasSeenFirstRepeat: DelayedPaywallProofStore.hasSeenFirstRepeat,
                hasOpenedEvidenceTrail:
                    DelayedPaywallProofStore.hasOpenedEvidenceTrail,
              ),
              entries: entriesAfterSave,
              beliefSurfaceVisible: archiveBeliefSurfaceCandidate.shouldShow,
              beliefEvidencePhrases:
                  archiveBeliefSurfaceCandidate.evidencePhrases,
              hasBetaProofLiftVisible: postSaveBag.hasBetaProofLiftVisible,
              hasReturnAfterProofStrengthenedVisible: postSaveBag
                  .showReturnAfterProofStrengthenedOnFirstProofPayoff,
            ),
          )
        : null;
    final showReturnTomorrowCuePostSave =
        !suppressNoisyFirstSaveCards &&
        !readyBag.showFirstProofPayoff &&
        !postSaveBag.showComeBackTomorrowV2PostSave &&
        ReturnTomorrowCueGates.shouldShowPostSave(
          isPostSaveDone: flags.isDone,
          isDegradedPostSave: postSaveBag.postSaveDegradedForReturnCue,
          cue: postSaveBag.returnTomorrowCuePostSave,
        );
    final firstWeekProgressPostSave =
        flags.isDone && entriesAfterSave.isNotEmpty
        ? FirstWeekProgressEngine.buildPostSave(
            entries: entriesAfterSave,
            firstProofUnlocked: showFirstProofMoment,
          )
        : null;
    final showFirstWeekProgressPostSave =
        FirstWeekProgressGates.shouldShowPostSave(
          isPostSaveDone: flags.isDone,
          isDegradedPostSave: postSaveBag.postSaveDegradedForReturnCue,
          progress: firstWeekProgressPostSave,
          showReturnTomorrowCue: showReturnTomorrowCuePostSave,
        );
    final showPostSaveReturnHandoff =
        !suppressNoisyFirstSaveCards &&
        PostSaveReturnHandoffGates.shouldShow(
          isPostSaveDone: flags.isDone,
          entryCount: postSaveEntryCount,
          isDegradedPostSave: postSaveBag.postSaveDegradedForReturnCue,
          handoff: postSaveBag.postSaveReturnHandoffCandidate,
        ) &&
        !showReturnTomorrowCuePostSave &&
        !postSaveBag.showComeBackTomorrowV2PostSave;
    final beliefUpdatePayoff =
        flags.isDone &&
            entriesAfterSave.isNotEmpty &&
            !suppressLatestSaveArchiveInsight
        ? BeliefUpdatePayoffEngine.build(
            entries: entriesAfterSave,
            analysisSucceeded: lastCaptureAnalysisSucceeded,
          )
        : null;
    final journalShareProof = flags.isDone && entriesAfterSave.isNotEmpty
        ? const ShareableArchiveProofEngine().buildFromJournal(
            entries: entriesAfterSave,
          )
        : null;
    final shareableProof = journalShareProof?.hasProof == true
        ? journalShareProof
        : input.shareableProof;
    final returnLoopPayoff =
        flags.isDone &&
            entriesAfterSave.isNotEmpty &&
            !suppressLatestSaveArchiveInsight &&
            thirdEntryBeliefPayoff == null &&
            beliefUpdatePayoff == null
        ? DayTwoReturnLoopPayoffEngine.build(
            entries: entriesAfterSave,
            reminderAvailable:
                input.offerDayTwoReminder && !input.recordReturnCueVisible,
          )
        : null;
    final postSaveDailyMirror =
        flags.isDone &&
            entriesAfterSave.isNotEmpty &&
            !suppressLatestSaveArchiveInsight
        ? const DailyMirrorEngine().build(entriesAfterSave)
        : null;
    final postSaveArchiveHierarchy = flags.isDone && entriesAfterSave.isNotEmpty
        ? PostSaveArchiveHierarchy.resolve(
            entries: entriesAfterSave,
            suppressLatestSaveArchiveInsight: suppressLatestSaveArchiveInsight,
            beliefUpdatePayoff: beliefUpdatePayoff,
            mirror: postSaveDailyMirror,
            firstProofUnlocked: showFirstProofMoment,
          )
        : null;
    final suppressNoisyRepeatPostSaveCards =
        PostSaveRepeatUiGates.suppressNoisyRepeatPostSaveCards(
          suppressNoisyFirstSaveCards: suppressNoisyFirstSaveCards,
          showFirstProofMoment: showFirstProofMoment,
          postSaveArchiveKind: postSaveArchiveHierarchy?.kind,
          mirror: postSaveDailyMirror,
        );
    final repeatPostSaveThoughtMapPreview = suppressNoisyRepeatPostSaveCards
        ? const ArchiveThoughtMapEngine().build(entriesAfterSave)
        : null;
    if (suppressNoisyRepeatPostSaveCards) {
      postSaveBag.suppressComeBackTomorrow();
    }
    final showDegradedTranscriptFocusedPostSave =
        flags.isDone &&
        entriesAfterSave.isNotEmpty &&
        DegradedTranscriptPostSaveUiGates.showFocusedRecoverySurface(
          isDegradedPostSave: input.lastSavedEntryIsDegraded,
        );
    final suppressDegradedTranscriptPostSaveCompetitors =
        DegradedTranscriptPostSaveUiGates.suppressCompetingPostSaveCards(
          showFocusedRecoverySurface: showDegradedTranscriptFocusedPostSave,
        );
    final returningUserToday = flags.isReady && input.entryCountLoaded
        ? ReturningUserTodayEngine.build(entries: input.journalEntries)
        : null;
    final nextMomentPrompt = flags.isReady && input.entryCountLoaded
        ? NextMomentPromptEngine.build(entries: input.journalEntries)
        : null;
    final dailyArchiveExercise =
        flags.isReady && input.entryCountLoaded && !ScreenshotMode.enabled
        ? const DailyArchiveExerciseEngine().buildFromJournal(
            entries: input.journalEntries,
            hasWatchTheme: input.hasWatchTheme,
            betaFeedbackCaptured: input.betaFeedbackCaptured,
          )
        : null;
    final todaysOneQuestion =
        flags.isReady && input.entryCountLoaded && !ScreenshotMode.enabled
        ? const TodaysQuestionEngine().buildFromJournal(
            entries: input.journalEntries,
            hasWatchTheme: input.hasWatchTheme,
            betaFeedbackCaptured: input.betaFeedbackCaptured,
            weeklyReviewAvailable: WeeklyArchiveReviewEngine.build(
              entries: input.journalEntries,
            ).hasEnoughEvidence,
          )
        : null;
    final recordHomeSurface = flags.isReady && input.entryCountLoaded
        ? RecordHomeSurfacePolicy.resolve(
            isReady: true,
            loaded: input.entryCountLoaded,
            entryCount: input.entryCount,
            screenshotMode: ScreenshotMode.enabled,
            dailyArchiveExercise: dailyArchiveExercise,
            returningUserToday: returningUserToday,
            todaysOneQuestion: todaysOneQuestion,
            hasStartHereSuggestion: input.dailyReturnSuggestions.hasSuggestions,
          )
        : const RecordHomeSurfacePolicy();
    final showArchiveProgressCards = flags.isReady
        ? recordHomeSurface.showArchiveProgressCards &&
              !showEarlyEvidenceTimeline
        : input.canShowArchiveProgressCards;

    final (
      :readyCapturePolicy,
      :showTesterMission,
      :showRecordCaptureModes,
      :testerMissionCompact,
      :showTesterMissionFull,
      :testerMission,
      :showThoughtMapRecordCta,
      :showPositiveReinforcementRecordCta,
      :showPatternChangedRecordCta,
      :showArchiveSummaryRecordCta,
      :showDailyReturnReasonRecordCta,
      :showFirstWeekLoopRecordCta,
    ) = resolveCaptureCtas(
      input: input,
      policyMic: policyMic,
      policyUserDenied: policyUserDenied,
      flags: flags,
      firstUseSimplifiedRecord: firstUseSimplifiedRecord,
      showReturningWatchTargetFocusedUi: showReturningWatchTargetFocusedUi,
      showConfirmedRepeatThoughtMapOnRecord:
          showConfirmedRepeatThoughtMapOnRecord,
      confirmedRepeatThoughtMap: confirmedRepeatThoughtMap,
      showPositiveReinforcementOnRecord: showPositiveReinforcementOnRecord,
      positiveReinforcement: positiveReinforcement,
      showPatternChanged: showPatternChanged,
      patternChangedCandidate: patternChangedCandidate,
      showArchiveSummaryOnRecord: showArchiveSummaryOnRecord,
      showDailyReturnReasonOnRecord: showDailyReturnReasonOnRecord,
      showFirstWeekLoopOnRecord: showFirstWeekLoopOnRecord,
      firstWeekLoopCandidate: firstWeekLoopCandidate,
    );

    return RecordSurfaceViewState.build(
      policyMic: policyMic,
      policyUserDenied: policyUserDenied,
      firstUseSimplifiedRecord: firstUseSimplifiedRecord,
      error: error,
      localSaveTitle: localSaveTitle,
      syncNote: syncNote,
      stageLabel: stageLabel,
      entriesAfterSave: entriesAfterSave,
      lastCaptureAnalysisSucceeded: lastCaptureAnalysisSucceeded,
      canRecord: canRecord,
      showFraming: showFraming,
      compact: compact,
      stack: stack,
      suppressPostResultNextCheckCompetitors:
          suppressPostResultNextCheckCompetitors,
      auditPresentation: auditPresentation,
      justSavedFirstEntry: justSavedFirstEntry,
      postSaveEntryCount: postSaveEntryCount,
      suppressNoisyFirstSaveCards: suppressNoisyFirstSaveCards,
      suppressEarlyPatternClaimCards: suppressEarlyPatternClaimCards,
      suppressLatestSaveArchiveInsight: suppressLatestSaveArchiveInsight,
      secondSessionPayoff: secondSessionPayoff,
      thirdEntryBeliefPayoff: thirdEntryBeliefPayoff,
      confirmedRepeatTriggerPayoff: confirmedRepeatTriggerPayoff,
      confirmedRepeatHelpfulActionPayoff: confirmedRepeatHelpfulActionPayoff,
      confirmedRepeatChangeNotice: confirmedRepeatChangeNotice,
      repeatReturnCheckOffer: repeatReturnCheckOffer,
      earlyEvidenceTimeline: earlyEvidenceTimeline,
      showEarlyEvidenceTimeline: showEarlyEvidenceTimeline,
      suppressEarlyRepeatPayoffCompetitors:
          suppressEarlyRepeatPayoffCompetitors,
      earlyFirstSignalOnRecord: earlyFirstSignalOnRecord,
      returnTomorrowCueReady: returnTomorrowCueReady,
      returnDayFlowCandidate: returnDayFlowCandidate,
      showReturnDayFlow: showReturnDayFlow,
      showReturnTomorrowCueReady: showReturnTomorrowCueReady,
      firstWeekProgressReady: firstWeekProgressReady,
      showFirstWeekProgressReady: showFirstWeekProgressReady,
      showEarlyReturnReminder: showEarlyReturnReminder,
      viewingConfirmedRepeatOnRecord: viewingConfirmedRepeatOnRecord,
      suppressConfirmedRepeatInlineFeedback:
          suppressConfirmedRepeatInlineFeedback,
      showConfirmedRepeatBetaFeedback: showConfirmedRepeatBetaFeedback,
      repeatReturnChangeProof: repeatReturnChangeProof,
      patternChangedCandidate: patternChangedCandidate,
      patternChangedDismissed: patternChangedDismissed,
      confirmedRepeatThoughtMap: confirmedRepeatThoughtMap,
      positivePattern: positivePattern,
      helpfulActionAppearedCandidate: helpfulActionAppearedCandidate,
      showHelpfulActionAppearedEligible: showHelpfulActionAppearedEligible,
      positiveReinforcement: positiveReinforcement,
      archiveSummaryCandidate: archiveSummaryCandidate,
      archiveBeliefSurfaceCandidate: archiveBeliefSurfaceCandidate,
      patternNamePrompt: patternNamePrompt,
      showArchiveCurrentBeliefEligible: showArchiveCurrentBeliefEligible,
      dailyReturnReasonCandidate: dailyReturnReasonCandidate,
      hasChangeOverTimeProof: hasChangeOverTimeProof,
      postProofArchiveProof: postProofArchiveProof,
      archiveSummaryVisibleForProGate: archiveSummaryVisibleForProGate,
      weeklyArchiveReviewVisibleForProGate:
          weeklyArchiveReviewVisibleForProGate,
      hasConfirmedRepeatForProGate: hasConfirmedRepeatForProGate,
      privateArchiveReportForProGate: privateArchiveReportForProGate,
      privateArchiveReportPreviewForProGate:
          privateArchiveReportPreviewForProGate,
      patternChangedForProGate: patternChangedForProGate,
      hasReturnCheckAnsweredForProGate: hasReturnCheckAnsweredForProGate,
      showPostProofProBridge: showPostProofProBridge,
      proofSurfaceLayout: proofSurfaceLayout,
      showArchiveSummary: showArchiveSummary,
      archiveSummary: archiveSummary,
      showDailyReturnReason: showDailyReturnReason,
      dailyReturnReason: dailyReturnReason,
      archiveWatchingCandidate: archiveWatchingCandidate,
      archiveWatching: archiveWatching,
      weeklyArchiveReview: weeklyArchiveReview,
      showWeeklyArchiveReview: showWeeklyArchiveReview,
      privateArchiveReportCandidate: privateArchiveReportCandidate,
      showPrivateArchiveReport: showPrivateArchiveReport,
      showConfirmedRepeatWhyMatters: showConfirmedRepeatWhyMatters,
      showConfirmedRepeatThoughtMap: showConfirmedRepeatThoughtMap,
      showPositiveReinforcement: showPositiveReinforcement,
      firstWeekLoopCandidate: firstWeekLoopCandidate,
      firstWeekLoopProGated: firstWeekLoopProGated,
      recordProofStack: recordProofStack,
      showPatternChanged: showPatternChanged,
      showArchiveCurrentBeliefOnRecord: showArchiveCurrentBeliefOnRecord,
      showEarlyEvidenceTimelineOnRecord: showEarlyEvidenceTimelineOnRecord,
      showWeeklyArchiveReviewOnRecord: showWeeklyArchiveReviewOnRecord,
      showPrivateArchiveReportOnRecord: showPrivateArchiveReportOnRecord,
      showDailyReturnReasonOnRecord: showDailyReturnReasonOnRecord,
      showPostProofProBridgeOnRecord: showPostProofProBridgeOnRecord,
      firstProofPayoffSeenOnRecord: firstProofPayoffSeenOnRecord,
      isDegradedTranscriptOnRecord: isDegradedTranscriptOnRecord,
      currentRelevanceCandidate: currentRelevanceCandidate,
      patternReviewInboxActiveOnRecord: patternReviewInboxActiveOnRecord,
      showCurrentRelevanceOnRecordReady:
          readyBag.showCurrentRelevanceOnRecordReady,
      currentRelevanceQuestionActiveOnRecord:
          currentRelevanceQuestionActiveOnRecord,
      correctionMemoryCandidate: correctionMemoryCandidate,
      showCorrectionMemoryOnRecordReady:
          readyBag.showCorrectionMemoryOnRecordReady,
      evidenceWeightingCandidate: evidenceWeightingCandidate,
      showEvidenceWeightingOnRecordReady:
          readyBag.showEvidenceWeightingOnRecordReady,
      proofSpecificityCandidate: proofSpecificityCandidate,
      showProofSpecificityOnRecordReady:
          readyBag.showProofSpecificityOnRecordReady,
      presentDayRelevanceCandidate: presentDayRelevanceCandidate,
      showPresentDayRelevanceOnRecordReady:
          readyBag.showPresentDayRelevanceOnRecordReady,
      showCaptureFreedomLine: readyBag.showCaptureFreedomLine,
      timelinePositioningCandidate: timelinePositioningCandidate,
      otherEducationCardsOnRecord: otherEducationCardsOnRecord,
      showTimelinePositioningOnRecordReady:
          readyBag.showTimelinePositioningOnRecordReady,
      patternConfidenceEducationCount: patternConfidenceEducationCount,
      patternConfidenceExplanationCandidate:
          patternConfidenceExplanationCandidate,
      showPatternConfidenceExplanationOnRecordReady:
          readyBag.showPatternConfidenceExplanationOnRecordReady,
      showProEvidenceValueOnRecordReady:
          readyBag.showProEvidenceValueOnRecordReady,
      showProBridgeVisibilityOnRecordReady:
          readyBag.showProBridgeVisibilityOnRecordReady,
      showProEvidenceValuePrivateReportOnRecord:
          readyBag.showProEvidenceValuePrivateReportOnRecord,
      showConfirmedRepeatWhyMattersOnRecord:
          showConfirmedRepeatWhyMattersOnRecord,
      showConfirmedRepeatThoughtMapOnRecord:
          showConfirmedRepeatThoughtMapOnRecord,
      showPositiveReinforcementOnRecord: showPositiveReinforcementOnRecord,
      showHelpfulActionAppearedOnRecord: showHelpfulActionAppearedOnRecord,
      showChangeProofOnRecord: showChangeProofOnRecord,
      showFirstWeekLoopOnRecord: showFirstWeekLoopOnRecord,
      firstProofPayoffCandidate: firstProofPayoffCandidate,
      showFirstProofPayoff: readyBag.showFirstProofPayoff,
      threeDayChallengeCandidate: threeDayChallengeCandidate,
      showThreeDayChallengeOnRecord: showThreeDayChallengeOnRecord,
      firstProofPatternConfidence: firstProofPatternConfidence,
      firstProofTruthProofKey: firstProofTruthProofKey,
      showFirstProofTruth: showFirstProofTruth,
      firstProofTruthAnswer: firstProofTruthAnswer,
      showFirstProofActionLoop: showFirstProofActionLoop,
      firstProofActionLoopContent: firstProofActionLoopContent,
      showFirstProofMoment: showFirstProofMoment,
      postSaveHasConfirmedRepeat: postSaveHasConfirmedRepeat,
      postSaveHasFirstProof: postSaveHasFirstProof,
      postSaveDegraded: postSaveDegraded,
      showCoreValueFeedbackOnRecordPostFirstProof:
          showCoreValueFeedbackOnRecordPostFirstProof,
      returnCheckPayoffCandidate: returnCheckPayoffCandidate,
      whatChangedV2Prompt: whatChangedV2Prompt,
      whatChangedV2Display: whatChangedV2Display,
      showWhatChangedV2: showWhatChangedV2,
      showWhatChangedV2Display: showWhatChangedV2Display,
      showOpenCapturePromptChips: readyBag.showOpenCapturePromptChips,
      showLowFrictionReturnCard: readyBag.showLowFrictionReturnCard,
      firstMomentCaptureCandidate: firstMomentCaptureCandidate,
      firstSaveLiftCandidate: firstSaveLiftCandidate,
      firstSessionCaptureRepairCandidate:
          readyBag.firstSessionCaptureRepairCandidate,
      openingRepairOverride: openingRepairOverride,
      showFirstSessionCaptureRepairCard:
          readyBag.showFirstSessionCaptureRepairCard,
      firstSessionLiftCandidate: firstSessionLiftCandidate,
      showFirstSessionLiftCard: readyBag.showFirstSessionLiftCard,
      showFirstSaveLiftCard: readyBag.showFirstSaveLiftCard,
      showFirstMomentCaptureCard: readyBag.showFirstMomentCaptureCard,
      secondMomentReturnCandidate: secondMomentReturnCandidate,
      showSecondMomentReturnCard: readyBag.showSecondMomentReturnCard,
      threeMomentCompletionCandidate: threeMomentCompletionCandidate,
      showThreeMomentCompletionCard: readyBag.showThreeMomentCompletionCard,
      firstRunPositioningCandidate: firstRunPositioningCandidate,
      showFirstRunPositioningCard: readyBag.showFirstRunPositioningCard,
      betaTodaySummaryCandidate: betaTodaySummaryCandidate,
      showBetaTodaySummaryCard: readyBag.showBetaTodaySummaryCard,
      archiveTimelineSpineCandidate: archiveTimelineSpineCandidate,
      whatToNoticeNextCandidate: whatToNoticeNextCandidate,
      showWhatToNoticeNextCard: readyBag.showWhatToNoticeNextCard,
      showArchiveTimelineSpineOnRecord:
          readyBag.showArchiveTimelineSpineOnRecord,
      suppressLegacyEducationCardsForSpineOnRecord:
          suppressLegacyEducationCardsForSpineOnRecord,
      timelineProofMomentCandidate: timelineProofMomentCandidate,
      showTimelineProofMomentOnRecord: readyBag.showTimelineProofMomentOnRecord,
      betaTesterReportCandidate: betaTesterReportCandidate,
      showBetaTesterReportOnRecord: readyBag.showBetaTesterReportOnRecord,
      notRelevantRecoveryCandidate: notRelevantRecoveryCandidate,
      proofQualityResponseTimelineCandidate:
          proofQualityResponseTimelineCandidate,
      proofQualityResponseSpineCandidate: proofQualityResponseSpineCandidate,
      betaProofLiftTimelineCandidate: betaProofLiftTimelineCandidate,
      returnAfterProofRecordCandidate: returnAfterProofRecordCandidate,
      showReturnAfterProofStrengthenedOnRecordReady:
          readyBag.showReturnAfterProofStrengthenedOnRecordReady,
      showReturnAfterProofGenericOnRecordReady:
          readyBag.showReturnAfterProofGenericOnRecordReady,
      showReturnAfterProofOnRecordReady:
          readyBag.showReturnAfterProofOnRecordReady,
      returnAfterProofLiftV2Candidate: returnAfterProofLiftV2Candidate,
      showReturnAfterProofLiftV2OnRecordReady:
          readyBag.showReturnAfterProofLiftV2OnRecordReady,
      recordReadySurfacePriority: recordReadySurfacePriority,
      recordLoosenSignalsPreAudit: recordLoosenSignalsPreAudit,
      recordEvidenceAnchorPreAudit: recordEvidenceAnchorPreAudit,
      recordFeedbackStateForLift: recordFeedbackStateForLift,
      timelineFeedbackType: timelineFeedbackType,
      betaRepairLabInput: betaRepairLabInput,
      showBetaRepairLabProPlacementOnRecord:
          readyBag.showBetaRepairLabProPlacementOnRecord,
      betaRepairLabProPlacementResult: betaRepairLabProPlacementResult,
      showBetaRepairLabPricingValueFramingOnRecord:
          readyBag.showBetaRepairLabPricingValueFramingOnRecord,
      betaRepairLabPricingValueFramingResult:
          betaRepairLabPricingValueFramingResult,
      showBetaRepairLabPaywallValueOnRecord:
          readyBag.showBetaRepairLabPaywallValueOnRecord,
      betaRepairLabPaywallValueResult: betaRepairLabPaywallValueResult,
      hasProEngagementOnRecord: hasProEngagementOnRecord,
      showBetaRepairLabPricingValidationOnRecord:
          readyBag.showBetaRepairLabPricingValidationOnRecord,
      showBetaRepairLabEvidenceTrailClarityOnRecord:
          readyBag.showBetaRepairLabEvidenceTrailClarityOnRecord,
      betaRepairLabPricingValidationResult:
          betaRepairLabPricingValidationResult,
      proUnderstandingLiftRecordReadyInput:
          proUnderstandingLiftRecordReadyInput,
      showProUnderstandingLiftOnRecordReady:
          readyBag.showProUnderstandingLiftOnRecordReady,
      showProVisibilityLiftOnRecordReady:
          readyBag.showProVisibilityLiftOnRecordReady,
      proUnderstandingLiftRecordReadyResult:
          readyBag.proUnderstandingLiftRecordReadyResult,
      proVisibilityLiftRecordReadyResult: proVisibilityLiftRecordReadyResult,
      showProofQualityResponseOnRecordReady:
          readyBag.showProofQualityResponseOnRecordReady,
      showNotRelevantRecoveryOnRecordReady:
          readyBag.showNotRelevantRecoveryOnRecordReady,
      showBetaProofLiftOnRecordReady: readyBag.showBetaProofLiftOnRecordReady,
      betaActivationPathPreAuditContext: betaActivationPathPreAuditContext,
      betaActivationPathPreAuditResult: betaActivationPathPreAuditResult,
      showBetaActivationPathCard: readyBag.showBetaActivationPathCard,
      betaActivationPathResult: readyBag.betaActivationPathResult,
      betaFeedbackCaptureRecordReadyPreAudit:
          betaFeedbackCaptureRecordReadyPreAudit,
      showBetaFeedbackCaptureRecordReady:
          readyBag.showBetaFeedbackCaptureRecordReady,
      betaFeedbackCaptureRecordReadyResult:
          readyBag.betaFeedbackCaptureRecordReadyResult,
      betaProofFeedbackCounts: betaProofFeedbackCounts,
      betaProofFeedbackRowVisibleOnTimeline:
          betaProofFeedbackRowVisibleOnTimeline,
      proofQualityRepairInput: proofQualityRepairInput,
      showProofQualityRepairOnRecord: readyBag.showProofQualityRepairOnRecord,
      proofQualityRepairResult: proofQualityRepairResult,
      proofFloorRescueInput: proofFloorRescueInput,
      showProofFloorRescueOnRecord: readyBag.showProofFloorRescueOnRecord,
      proofFloorRescueResult: proofFloorRescueResult,
      blocksProByProofFloorOnRecord: blocksProByProofFloorOnRecord,
      showBetaRepairLabProofOnRecord: readyBag.showBetaRepairLabProofOnRecord,
      betaRepairLabProofResult: betaRepairLabProofResult,
      blocksProCardsByProofProtectionOnRecord:
          blocksProCardsByProofProtectionOnRecord,
      betaRepairLabEvidenceTrailClarityResult:
          betaRepairLabEvidenceTrailClarityResult,
      recordLoosenSignals: recordLoosenSignals,
      recordReadyProTiming: recordReadyProTiming,
      betaActivationPathFinalContext: betaActivationPathFinalContext,
      shareableNonPrivateProofResult: shareableNonPrivateProofResult,
      showShareableNonPrivateProofOnRecord:
          showShareableNonPrivateProofOnRecord,
      proofSpecificityBoostCandidate: proofSpecificityBoostCandidate,
      timelineProofParentVisible: timelineProofParentVisible,
      showProofSpecificityBoostOnTimelineProof:
          showProofSpecificityBoostOnTimelineProof,
      showProofQualityResponseUnderTimelineProof:
          showProofQualityResponseUnderTimelineProof,
      showProofQualityResponseUnderArchiveSpine:
          showProofQualityResponseUnderArchiveSpine,
      showNotRelevantRecoveryUnderTimelineProof:
          showNotRelevantRecoveryUnderTimelineProof,
      showBetaProofLiftUnderTimelineProof: showBetaProofLiftUnderTimelineProof,
      showReturnAfterProofLiftV2BelowProofOnRecord:
          showReturnAfterProofLiftV2BelowProofOnRecord,
      showReturnAfterProofLiftV2InGuidanceStack:
          showReturnAfterProofLiftV2InGuidanceStack,
      showReturnAfterProofBelowProofOnRecord:
          showReturnAfterProofBelowProofOnRecord,
      showReturnAfterProofInGuidanceStack: showReturnAfterProofInGuidanceStack,
      showProUnderstandingLiftBelowProofOnRecord:
          showProUnderstandingLiftBelowProofOnRecord,
      showBetaRepairLabEvidenceTrailClarityBelowProofOnRecord:
          showBetaRepairLabEvidenceTrailClarityBelowProofOnRecord,
      showBetaRepairLabPricingValidationBelowProofOnRecord:
          showBetaRepairLabPricingValidationBelowProofOnRecord,
      showBetaRepairLabPricingValueFramingBelowProofOnRecord:
          showBetaRepairLabPricingValueFramingBelowProofOnRecord,
      showBetaRepairLabPaywallValueBelowProofOnRecord:
          showBetaRepairLabPaywallValueBelowProofOnRecord,
      showBetaRepairLabProPlacementBelowProofOnRecord:
          showBetaRepairLabProPlacementBelowProofOnRecord,
      showProUnderstandingLiftInProSectionOnRecord:
          showProUnderstandingLiftInProSectionOnRecord,
      showProVisibilityLiftBelowProofOnRecord:
          showProVisibilityLiftBelowProofOnRecord,
      showProVisibilityLiftInProSectionOnRecord:
          showProVisibilityLiftInProSectionOnRecord,
      showProBridgeBelowProofOnRecord: showProBridgeBelowProofOnRecord,
      showProBridgeInProSectionOnRecord: showProBridgeInProSectionOnRecord,
      proBridgeVisibilityRecordResult: proBridgeVisibilityRecordResult,
      patternReviewInboxActivePostSave: patternReviewInboxActivePostSave,
      timelineProofMomentPostSaveCandidate:
          timelineProofMomentPostSaveCandidate,
      showTimelineProofMomentOnFirstProofPayoff:
          postSaveBag.showTimelineProofMomentOnFirstProofPayoff,
      proofSpecificityPostSaveCandidate:
          postSaveBag.proofSpecificityPostSaveCandidate,
      showProofSpecificityOnFirstProofPayoff:
          postSaveBag.showProofSpecificityOnFirstProofPayoff,
      proofSpecificityBoostPostSaveCandidate:
          postSaveBag.proofSpecificityBoostPostSaveCandidate,
      proofQualityResponseFirstProofCandidate:
          postSaveBag.proofQualityResponseFirstProofCandidate,
      proofQualityResponseTimelinePostSaveCandidate:
          postSaveBag.proofQualityResponseTimelinePostSaveCandidate,
      betaProofLiftFirstProofCandidate:
          postSaveBag.betaProofLiftFirstProofCandidate,
      betaProofLiftTimelinePostSaveCandidate:
          postSaveBag.betaProofLiftTimelinePostSaveCandidate,
      returnAfterProofPostSaveCandidate:
          postSaveBag.returnAfterProofPostSaveCandidate,
      firstProofPayoffParentVisible: postSaveBag.firstProofPayoffParentVisible,
      showProofSpecificityBoostOnFirstProofPayoff:
          postSaveBag.showProofSpecificityBoostOnFirstProofPayoff,
      showProofQualityResponseOnFirstProofPayoff:
          postSaveBag.showProofQualityResponseOnFirstProofPayoff,
      timelineProofPostSaveParentVisible:
          postSaveBag.timelineProofPostSaveParentVisible,
      showProofSpecificityBoostOnTimelineProofPostSave:
          postSaveBag.showProofSpecificityBoostOnTimelineProofPostSave,
      showProofQualityResponseOnTimelineProofPostSave:
          postSaveBag.showProofQualityResponseOnTimelineProofPostSave,
      showBetaProofLiftOnFirstProofPayoff:
          postSaveBag.showBetaProofLiftOnFirstProofPayoff,
      showBetaProofLiftUnderTimelineProofPostSave:
          postSaveBag.showBetaProofLiftUnderTimelineProofPostSave,
      showReturnAfterProofStrengthenedOnFirstProofPayoff:
          postSaveBag.showReturnAfterProofStrengthenedOnFirstProofPayoff,
      showReturnAfterProofGenericOnFirstProofPayoff:
          postSaveBag.showReturnAfterProofGenericOnFirstProofPayoff,
      showReturnAfterProofOnFirstProofPayoff:
          postSaveBag.showReturnAfterProofOnFirstProofPayoff,
      returnAfterProofLiftV2PostSaveCandidate:
          postSaveBag.returnAfterProofLiftV2PostSaveCandidate,
      showReturnAfterProofLiftV2OnPostSave:
          postSaveBag.showReturnAfterProofLiftV2OnPostSave,
      postSaveLoosenSignalsPreAudit: postSaveBag.postSaveLoosenSignalsPreAudit,
      postSaveEvidenceAnchorPreAudit:
          postSaveBag.postSaveEvidenceAnchorPreAudit,
      postSaveFeedbackStateForLift: postSaveBag.postSaveFeedbackStateForLift,
      hasProEngagementOnPostSave: postSaveBag.hasProEngagementOnPostSave,
      proUnderstandingLiftPostSaveInput:
          postSaveBag.proUnderstandingLiftPostSaveInput,
      showProUnderstandingLiftOnPostSave:
          postSaveBag.showProUnderstandingLiftOnPostSave,
      proUnderstandingLiftPostSaveResult:
          postSaveBag.proUnderstandingLiftPostSaveResult,
      base: postSaveBag.base,
      showProVisibilityLiftOnPostSave:
          postSaveBag.showProVisibilityLiftOnPostSave,
      proVisibilityLiftPostSaveResult:
          postSaveBag.proVisibilityLiftPostSaveResult,
      showProEvidenceValuePostSave: postSaveBag.showProEvidenceValuePostSave,
      showBetaInviteLoopPostSave: postSaveBag.showBetaInviteLoopPostSave,
      showProPreviewPostSave: postSaveBag.showProPreviewPostSave,
      showProBridgeVisibilityPostSave:
          postSaveBag.showProBridgeVisibilityPostSave,
      showProLockMomentPostSave: postSaveBag.showProLockMomentPostSave,
      monthlyPrivateReportPreviewPostSave:
          postSaveBag.monthlyPrivateReportPreviewPostSave,
      showMonthlyPrivateReportPreviewPostSave:
          postSaveBag.showMonthlyPrivateReportPreviewPostSave,
      betaFeedbackIntelligenceSurfaceOnRecordReady:
          betaFeedbackIntelligenceSurfaceOnRecordReady,
      betaFeedbackIntelligenceSurfacePostSave:
          betaFeedbackIntelligenceSurfacePostSave,
      helpedTrackingPrompt: helpedTrackingPrompt,
      showHelpedTracking: showHelpedTracking,
      showReturnCheckPayoff: showReturnCheckPayoff,
      showArchiveSummaryOnRecord: showArchiveSummaryOnRecord,
      confirmedRepeatChangeNoticeOnRecord: confirmedRepeatChangeNoticeOnRecord,
      lowEvidenceGuidance: lowEvidenceGuidance,
      quietSignalCandidate: quietSignalCandidate,
      showQuietSignalOnRecord: showQuietSignalOnRecord,
      showLowEvidenceGuidanceOnRecord: showLowEvidenceGuidanceOnRecord,
      dailyThoughtprintmoryCandidate: dailyThoughtprintmoryCandidate,
      firstProofLoopActive: firstProofLoopActive,
      showDailyThoughtprintmory: showDailyThoughtprintmory,
      showReturningWatchTargetFocusedUi: showReturningWatchTargetFocusedUi,
      recordReadyShowsWatchTargetOnly: recordReadyShowsWatchTargetOnly,
      recordReadySuppressStreakPressure: recordReadySuppressStreakPressure,
      betaTestScriptCardCandidate: betaTestScriptCardCandidate,
      showBetaTestScriptCard: showBetaTestScriptCard,
      daysSinceLastEntry: daysSinceLastEntry,
      showReturnedAfterDelayRecovery: showReturnedAfterDelayRecovery,
      nextBestActionCandidate: nextBestActionCandidate,
      showNextBestActionOnRecord: showNextBestActionOnRecord,
      postSaveReturnHandoffCandidate:
          postSaveBag.postSaveReturnHandoffCandidate,
      returnTomorrowCuePostSave: postSaveBag.returnTomorrowCuePostSave,
      postSaveDegradedForReturnCue: postSaveBag.postSaveDegradedForReturnCue,
      comeBackTomorrowV2PostSaveWatch:
          postSaveBag.comeBackTomorrowV2PostSaveWatch,
      showComeBackTomorrowV2PostSave:
          postSaveBag.showComeBackTomorrowV2PostSave,
      showPostSaveCuriosityHook: postSaveBag.showPostSaveCuriosityHook,
      betaFeedbackCapturePostSavePreAudit:
          postSaveBag.betaFeedbackCapturePostSavePreAudit,
      showBetaFeedbackCapturePostSave:
          postSaveBag.showBetaFeedbackCapturePostSave,
      betaFeedbackCapturePostSaveResult:
          postSaveBag.betaFeedbackCapturePostSaveResult,
      postSaveProofFloorRescueInput: postSaveBag.postSaveProofFloorRescueInput,
      blocksProByProofFloorOnPostSave:
          postSaveBag.blocksProByProofFloorOnPostSave,
      recordPostSaveSurfacePriority: recordPostSaveSurfacePriority,
      postSaveLoosenSignals: postSaveLoosenSignals,
      postSaveProTiming: postSaveProTiming,
      betaFeedbackCapturePostSaveFinal: betaFeedbackCapturePostSaveFinal,
      proPreviewPostSaveResult: proPreviewPostSaveResult,
      betaInviteLoopPostSaveResult: betaInviteLoopPostSaveResult,
      proBridgeVisibilityPostSaveResult: proBridgeVisibilityPostSaveResult,
      showReturnTomorrowCuePostSave: showReturnTomorrowCuePostSave,
      firstWeekProgressPostSave: firstWeekProgressPostSave,
      showFirstWeekProgressPostSave: showFirstWeekProgressPostSave,
      showPostSaveReturnHandoff: showPostSaveReturnHandoff,
      beliefUpdatePayoff: beliefUpdatePayoff,
      journalShareProof: journalShareProof,
      shareableProof: shareableProof,
      returnLoopPayoff: returnLoopPayoff,
      postSaveDailyMirror: postSaveDailyMirror,
      postSaveArchiveHierarchy: postSaveArchiveHierarchy,
      suppressNoisyRepeatPostSaveCards: suppressNoisyRepeatPostSaveCards,
      repeatPostSaveThoughtMapPreview: repeatPostSaveThoughtMapPreview,
      showDegradedTranscriptFocusedPostSave:
          showDegradedTranscriptFocusedPostSave,
      suppressDegradedTranscriptPostSaveCompetitors:
          suppressDegradedTranscriptPostSaveCompetitors,
      returningUserToday: returningUserToday,
      nextMomentPrompt: nextMomentPrompt,
      dailyArchiveExercise: dailyArchiveExercise,
      todaysOneQuestion: todaysOneQuestion,
      recordHomeSurface: recordHomeSurface,
      showArchiveProgressCards: showArchiveProgressCards,
      readyCapturePolicy: readyCapturePolicy,
      showTesterMission: showTesterMission,
      showRecordCaptureModes: showRecordCaptureModes,
      testerMissionCompact: testerMissionCompact,
      showTesterMissionFull: showTesterMissionFull,
      testerMission: testerMission,
      showThoughtMapRecordCta: showThoughtMapRecordCta,
      showPositiveReinforcementRecordCta: showPositiveReinforcementRecordCta,
      showPatternChangedRecordCta: showPatternChangedRecordCta,
      showArchiveSummaryRecordCta: showArchiveSummaryRecordCta,
      showDailyReturnReasonRecordCta: showDailyReturnReasonRecordCta,
      showFirstWeekLoopRecordCta: showFirstWeekLoopRecordCta,
    );
  }
}
