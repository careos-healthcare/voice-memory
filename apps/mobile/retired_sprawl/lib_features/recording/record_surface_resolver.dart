import 'package:archiveme_mobile/core/config/v1_feature_flags.dart';
import 'package:archiveme_mobile/features/recording/record_surface_capture_policy.dart';
import 'package:archiveme_mobile/features/recording/record_surface_input.dart';
import 'package:archiveme_mobile/features/recording/record_surface_view_state.dart';
import 'package:archiveme_mobile/features/recording/recording_dependencies.dart';
import 'package:archiveme_mobile/features/weekly_review/weekly_archive_review_engine.dart'
    as weekly_review_surface;

/// Pure resolver for record-screen domain gates, engines, and surface audits.
abstract final class RecordSurfaceResolver {
  RecordSurfaceResolver._();

  static RecordSurfaceViewState resolve(RecordSurfaceInput input) {
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
    final repeatReturnCheckOffer =
        flags.isDone && entriesAfterSave.isNotEmpty
        ? RepeatReturnCheckEngine.pendingForSave(
            entriesAfterSave: entriesAfterSave,
            records: RepeatReturnCheckStore.cached,
          )
        : null;
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
        flags.isReady &&
            input.entryCountLoaded &&
            !showEarlyEvidenceTimeline
        ? EarlyFirstSignalEngine.build(entries: input.journalEntries)
        : null;
    final returnTomorrowCueReady =
        flags.isReady && input.entryCountLoaded
        ? ReturnTomorrowCueEngine.buildReady(entries: input.journalEntries)
        : null;
    final returnDayFlowCandidate =
        flags.isReady && input.entryCountLoaded
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
    final firstWeekProgressReady =
        flags.isReady && input.entryCountLoaded
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
                    triggerCapturedMilestone: input.earlyEvidenceTriggerCaptured,
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
        flags.isReady &&
            input.entryCountLoaded &&
            !input.isPostSave
        ? RepeatReturnCheckEngine.changeProofForReady(
            entryCount: input.entryCount,
            viewingConfirmedRepeat: viewingConfirmedRepeatOnRecord,
            isRecording: flags.isRecording,
            isPostSave: input.isPostSave,
            records: RepeatReturnCheckStore.cached,
          )
        : null;
    final patternChangedCandidate =
        flags.isReady &&
            input.entryCountLoaded &&
            !input.isPostSave
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
        flags.isReady &&
            input.entryCountLoaded &&
            !input.isPostSave
        ? ConfirmedRepeatThoughtMapEngine.build(
            entries: input.journalEntries,
            triggerCapturedMilestone: input.earlyEvidenceTriggerCaptured,
            helpfulActionCapturedMilestone: input.earlyEvidenceHelpfulCaptured,
            returnChecks: RepeatReturnCheckStore.cached,
          )
        : null;
    final positivePattern =
        flags.isReady &&
            input.entryCountLoaded &&
            !input.isPostSave
        ? PositivePatternEngine.build(entries: input.journalEntries)
        : null;
    final helpfulActionAppearedCandidate =
        flags.isReady &&
            input.entryCountLoaded &&
            !input.isPostSave
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
        flags.isReady &&
            input.entryCountLoaded &&
            !input.isPostSave
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
        flags.isReady &&
            input.entryCountLoaded &&
            !input.isPostSave
        ? PatternNameEngine.applyDisplayLabels(
            const ArchiveBeliefSurfaceSource().resolve(
              input.journalEntries,
              confirmedRepeat: earlyFirstSignalOnRecord,
              changeProof: repeatReturnChangeProof,
              returnChecks: RepeatReturnCheckStore.cached,
              triggerCapturedMilestone: input.earlyEvidenceTriggerCaptured,
              helpfulActionCapturedMilestone: input.earlyEvidenceHelpfulCaptured,
              viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOnRecord,
            ),
          )
        : ArchiveBeliefSurface.none;
    final patternNamePrompt =
        flags.isReady &&
            input.entryCountLoaded &&
            !input.isPostSave
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
        flags.isReady &&
            input.entryCountLoaded &&
            !input.isPostSave
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
        flags.isReady &&
            input.entryCountLoaded &&
            !input.isPostSave
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
        PrivateArchiveReportGates.showPreviewNote(isPro: input.userProState.isPro);
    final patternChangedForProGate =
        patternChangedCandidate != null &&
        viewingConfirmedRepeatOnRecord &&
        input.entryCount > FirstThreeSessionGates.minEntriesForUsefulArchive;
    final hasReturnCheckAnsweredForProGate =
        RepeatReturnCheckTrendEngine.hasAnsweredCheck(
          RepeatReturnCheckStore.cached,
        ) &&
        input.entryCount >=
            PaywallTimingGates.minFullArchiveHistoryEntryCount;
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
        flags.isReady &&
            input.entryCountLoaded &&
            !input.isPostSave
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
        flags.isReady &&
            input.entryCountLoaded &&
            !input.isPostSave
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
        flags.isReady &&
            input.entryCountLoaded &&
            !input.isPostSave
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
        flags.isReady &&
            input.entryCountLoaded &&
            !input.isPostSave
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
    final showWeeklyArchiveReviewOnRecord = !V1FeatureFlags.enableV1Only && recordProofStack.showWeeklyArchiveWeekReview;
    final showPrivateArchiveReportOnRecord =
        recordProofStack.showPrivateArchiveReport;
    final showDailyReturnReasonOnRecord =
        recordProofStack.showDailyReturnReason;
    final showPostProofProBridgeOnRecord = recordProofStack.showProBridge;
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
    var showCurrentRelevanceOnRecordReady =
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
          visible: showCurrentRelevanceOnRecordReady,
        );
    final correctionMemoryCandidate = CorrectionMemoryEngine.build(
      entries: input.journalEntries,
      source: 'record',
    );
    var showCorrectionMemoryOnRecordReady =
        flags.isReady &&
        showCurrentRelevanceOnRecordReady &&
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
    var showEvidenceWeightingOnRecordReady =
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
    var showProofSpecificityOnRecordReady =
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
    var showPresentDayRelevanceOnRecordReady =
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
    var showCaptureFreedomLine =
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
          captureFreedomLineVisible: showCaptureFreedomLine,
          currentRelevanceVisible:
              showCurrentRelevanceOnRecordReady &&
              currentRelevanceCandidate != null,
          evidenceWeightingVisible:
              showEvidenceWeightingOnRecordReady &&
              evidenceWeightingCandidate != null,
          proofSpecificityVisible:
              showProofSpecificityOnRecordReady &&
              proofSpecificityCandidate.shouldShow,
          presentDayRelevanceVisible:
              showPresentDayRelevanceOnRecordReady &&
              presentDayRelevanceCandidate != null,
        );
    var showTimelinePositioningOnRecordReady =
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
          captureFreedomLineVisible: showCaptureFreedomLine,
          timelinePositioningVisible: showTimelinePositioningOnRecordReady,
          currentRelevanceVisible:
              showCurrentRelevanceOnRecordReady &&
              currentRelevanceCandidate != null,
          correctionMemoryVisible:
              showCorrectionMemoryOnRecordReady &&
              correctionMemoryCandidate != null,
          evidenceWeightingVisible:
              showEvidenceWeightingOnRecordReady &&
              evidenceWeightingCandidate != null,
          proofSpecificityVisible:
              showProofSpecificityOnRecordReady &&
              proofSpecificityCandidate.shouldShow,
          presentDayRelevanceVisible:
              showPresentDayRelevanceOnRecordReady &&
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
    var showPatternConfidenceExplanationOnRecordReady =
        flags.isReady &&
        PatternConfidenceEngine.shouldShowExplanationOnRecordReady(
          result: patternConfidenceExplanationCandidate,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
          otherEducationCardCount: patternConfidenceEducationCount,
        );
    var showProEvidenceValueOnRecordReady =
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
    var showProBridgeVisibilityOnRecordReady = false;
    var showProEvidenceValuePrivateReportOnRecord =
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
    var showFirstProofPayoff = FirstProofPayoffGates.shouldShow(
      isPostSaveDone: flags.isDone,
      entryCount: postSaveEntryCount,
      isDegradedPostSave:
          entriesAfterSave.isNotEmpty &&
          VoiceCaptureQuality.isDegradedVoiceCapture(entriesAfterSave.last),
      payoff: firstProofPayoffCandidate,
    );
    final threeDayChallengeCandidate =
        flags.isReady && input.entryCountLoaded
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
          showFirstProofPayoff && firstProofPayoffCandidate != null,
      challenge: threeDayChallengeCandidate,
    );
    final firstProofPatternConfidence =
        showFirstProofPayoff && firstProofPayoffCandidate != null
        ? PatternConfidenceEngine.build(
            entries: entriesAfterSave,
            returnChecks: RepeatReturnCheckStore.cached,
            viewingConfirmedRepeatOrTimeline: true,
            hideNotEnoughYet: true,
          )
        : null;
    final firstProofTruthProofKey = showFirstProofPayoff
        ? FirstProofTruthGates.proofKeyForEntries(entriesAfterSave)
        : '';
    final showFirstProofTruth = FirstProofTruthGates.shouldShow(
      showFirstProofPayoff: showFirstProofPayoff,
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
      showFirstProofPayoff: showFirstProofPayoff,
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
    final showFirstProofMoment = showFirstProofPayoff;
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
        !showFirstProofPayoff &&
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
    final whatChangedV2Prompt =
        flags.isDone && entriesAfterSave.isNotEmpty
        ? WhatChangedV2Engine.buildPrompt(
            entries: entriesAfterSave,
            returnChecks: RepeatReturnCheckStore.cached,
          )
        : null;
    final whatChangedV2Display =
        flags.isDone && entriesAfterSave.isNotEmpty
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
    var showOpenCapturePromptChips = OpenCaptureEngine.shouldShow(
      isReady: flags.isReady,
      isRecording: flags.isRecording,
      isPostSave: input.isPostSave,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      firstProofPayoffVisible:
          showFirstProofPayoff && firstProofPayoffCandidate != null,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
      isPermissionBlocked: flags.isPermissionBlocked,
      entryCount: input.entryCount,
    );
    var showLowFrictionReturnCard = LowFrictionReturnEngine.shouldShow(
      isReady: flags.isReady,
      isRecording: flags.isRecording,
      isPostSave: input.isPostSave,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      firstProofPayoffVisible:
          showFirstProofPayoff && firstProofPayoffCandidate != null,
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
    var firstSessionCaptureRepairCandidate =
        FirstSessionProofRepairEngine.buildCapture(
          entryCount: input.entryCount,
          source: 'record',
        );
    final openingRepairOverride = BetaRepairLabEngine.openingCaptureOverride(
      base: firstSessionCaptureRepairCandidate,
      betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
    );
    if (openingRepairOverride != null) {
      firstSessionCaptureRepairCandidate = openingRepairOverride;
    }
    var showFirstSessionCaptureRepairCard =
        FirstSessionProofRepairEngine.shouldShowCapture(
          result: firstSessionCaptureRepairCandidate,
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
    var showFirstSessionLiftCard = FirstSessionLiftEngine.shouldShow(
      result: firstSessionLiftCandidate,
      betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
      isReady: flags.isReady,
      isRecording: flags.isRecording,
      isPostSave: input.isPostSave,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      isPermissionBlocked: flags.isPermissionBlocked,
      entryCount: input.entryCount,
    );
    var showFirstSaveLiftCard = FirstSaveLiftEngine.shouldShow(
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
      showOpeningRepair: showFirstSessionCaptureRepairCard,
    )) {
      showFirstSessionLiftCard = false;
      showFirstSaveLiftCard = false;
    }
    var showFirstMomentCaptureCard = FirstMomentCaptureEngine.shouldShow(
      result: firstMomentCaptureCandidate,
      isReady: flags.isReady,
      isRecording: flags.isRecording,
      isPostSave: input.isPostSave,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      firstProofPayoffVisible:
          showFirstProofPayoff && firstProofPayoffCandidate != null,
      isPermissionBlocked: flags.isPermissionBlocked,
      entryCount: input.entryCount,
    );
    final secondMomentReturnCandidate = SecondMomentReturnEngine.build(
      entries: input.journalEntries,
      source: 'record',
    );
    var showSecondMomentReturnCard = SecondMomentReturnEngine.shouldShow(
      result: secondMomentReturnCandidate,
      isReady: flags.isReady,
      isRecording: flags.isRecording,
      isPostSave: input.isPostSave,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      firstProofPayoffVisible:
          showFirstProofPayoff && firstProofPayoffCandidate != null,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
      entryCount: input.entryCount,
    );
    final threeMomentCompletionCandidate = ThreeMomentCompletionEngine.build(
      entryCount: input.entryCount,
      source: 'record',
    );
    var showThreeMomentCompletionCard = ThreeMomentCompletionEngine.shouldShow(
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
    var showFirstRunPositioningCard = FirstRunPositioningEngine.shouldShow(
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
    var showBetaTodaySummaryCard = BetaTodaySummaryEngine.shouldShow(
      result: betaTodaySummaryCandidate,
      isReady: flags.isReady,
      isRecording: flags.isRecording,
      isPostSave: input.isPostSave,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      firstProofPayoffVisible:
          showFirstProofPayoff && firstProofPayoffCandidate != null,
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
    var showWhatToNoticeNextCard = WhatToNoticeNextEngine.shouldShow(
      result: whatToNoticeNextCandidate,
      isReady: flags.isReady,
      isRecording: flags.isRecording,
      isPostSave: input.isPostSave,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      firstProofPayoffVisible:
          showFirstProofPayoff && firstProofPayoffCandidate != null,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
      entryCount: input.entryCount,
      lowFrictionReturnVisible: showLowFrictionReturnCard,
      betaTodaySummaryVisible: showBetaTodaySummaryCard,
      openCapturePromptChipsVisible: showOpenCapturePromptChips,
    );
    var showArchiveTimelineSpineOnRecord =
        flags.isReady &&
        ArchiveTimelineSpineEngine.shouldShowOnRecordReady(
          result: archiveTimelineSpineCandidate,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPostSaveDegradedState: false,
          firstProofPayoffVisible:
              showFirstProofPayoff && firstProofPayoffCandidate != null,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    final suppressLegacyEducationCardsForSpineOnRecord =
        ArchiveTimelineSpineEngine.suppressLegacyEducationCards(
          result: archiveTimelineSpineCandidate,
          visible: showArchiveTimelineSpineOnRecord,
        );
    final timelineProofMomentCandidate = archiveTimelineSpineCandidate != null
        ? TimelineProofMomentEngine.buildFromSpine(
            spine: archiveTimelineSpineCandidate,
            entries: input.journalEntries,
            source: 'record',
          )
        : null;
    var showTimelineProofMomentOnRecord =
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
    var showBetaTesterReportOnRecord = BetaTesterReportEngine.shouldShow(
      result: betaTesterReportCandidate,
      isReady: flags.isReady,
      isRecording: flags.isRecording,
      isDegradedTranscriptState: isDegradedTranscriptOnRecord,
      firstProofPayoffVisible:
          showFirstProofPayoff && firstProofPayoffCandidate != null,
      whatChangedQuestionActive: showWhatChangedV2,
      patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
    );
    showProBridgeVisibilityOnRecordReady = false;
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
          showTimelineProofMomentOnRecord &&
          timelineProofMomentCandidate != null,
      betaTesterReportVisible: showBetaTesterReportOnRecord,
    );
    var showReturnAfterProofStrengthenedOnRecordReady =
        ReturnAfterProofEngine.shouldShowStrengthenedOnRecordReady(
          result: returnAfterProofRecordCandidate,
          isReady: flags.isReady,
          isRecording: flags.isRecording,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
          firstProofSeen: firstProofPayoffSeenOnRecord,
          timelineProofVisible:
              showTimelineProofMomentOnRecord &&
              timelineProofMomentCandidate != null,
          dismissedForToday: ReturnAfterProofStore.isDismissedToday,
        );
    var showReturnAfterProofGenericOnRecordReady =
        ReturnAfterProofEngine.shouldShowGenericOnRecordReady(
          result: returnAfterProofRecordCandidate,
          isReady: flags.isReady,
          isRecording: flags.isRecording,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
          firstProofSeen: firstProofPayoffSeenOnRecord,
          timelineProofVisible:
              showTimelineProofMomentOnRecord &&
              timelineProofMomentCandidate != null,
          betaTesterReportVisible: showBetaTesterReportOnRecord,
          dismissedForToday: ReturnAfterProofStore.isDismissedToday,
        );
    var showReturnAfterProofOnRecordReady =
        showReturnAfterProofStrengthenedOnRecordReady ||
        showReturnAfterProofGenericOnRecordReady;
    final returnAfterProofLiftV2Candidate = ReturnAfterProofLiftV2Engine.build(
      entries: input.journalEntries,
      source: 'record',
      firstProofSeen: firstProofPayoffSeenOnRecord,
      timelineProofVisible:
          showTimelineProofMomentOnRecord &&
          timelineProofMomentCandidate != null,
    );
    var showReturnAfterProofLiftV2OnRecordReady =
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
          showTimelineProofMomentOnRecord &&
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
    var showBetaRepairLabProPlacementOnRecord =
        BetaRepairLabEngine.shouldShowProPlacement(input: betaRepairLabInput);
    final betaRepairLabProPlacementResult =
        showBetaRepairLabProPlacementOnRecord
        ? BetaRepairLabEngine.buildProPlacement(input: betaRepairLabInput)
        : BetaRepairLabProPlacementResult.hidden;
    var showBetaRepairLabPricingValueFramingOnRecord =
        PricingValueFramingEngine.shouldShow(input: betaRepairLabInput);
    final betaRepairLabPricingValueFramingResult =
        showBetaRepairLabPricingValueFramingOnRecord
        ? PricingValueFramingEngine.build(input: betaRepairLabInput)
        : PricingValueFramingResult.hidden;
    var showBetaRepairLabPaywallValueOnRecord =
        PaywallValueRepairEngine.shouldShow(input: betaRepairLabInput);
    final betaRepairLabPaywallValueResult =
        showBetaRepairLabPaywallValueOnRecord
        ? PaywallValueRepairEngine.build(input: betaRepairLabInput)
        : PaywallValueRepairResult.hidden;
    final hasProEngagementOnRecord =
        input.betaActivationLoopCounts.paywallSeen > 0 ||
        input.betaActivationLoopCounts.purchaseTapped > 0 ||
        input.betaActivationLoopCounts.proBoundarySeen > 0;
    var showBetaRepairLabPricingValidationOnRecord =
        PricingValidationEngine.shouldShow(
          input: betaRepairLabInput,
          hasProEngagement: hasProEngagementOnRecord,
        );
    var showBetaRepairLabEvidenceTrailClarityOnRecord = false;
    final betaRepairLabPricingValidationResult =
        showBetaRepairLabPricingValidationOnRecord
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
    var showProUnderstandingLiftOnRecordReady =
        ProUnderstandingLiftEngine.shouldShowCard(
          input: proUnderstandingLiftRecordReadyInput,
        );
    var showProVisibilityLiftOnRecordReady =
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
    var proUnderstandingLiftRecordReadyResult =
        showProUnderstandingLiftOnRecordReady
        ? ProUnderstandingLiftEngine.build(
            input: proUnderstandingLiftRecordReadyInput,
          )
        : null;
    if (proUnderstandingLiftRecordReadyResult != null) {
      proUnderstandingLiftRecordReadyResult =
          BetaRepairLabEngine.applyProExplanationCopy(
            base: proUnderstandingLiftRecordReadyResult,
            betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
          ) ??
          proUnderstandingLiftRecordReadyResult;
    }
    final proVisibilityLiftRecordReadyResult =
        showProVisibilityLiftOnRecordReady
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
    var showProofQualityResponseOnRecordReady =
        flags.isReady &&
        proofQualityResponseTimelineCandidate.shouldShow &&
        ProofQualityResponseEngine.shouldRender(
          result: proofQualityResponseTimelineCandidate,
          parentVisible: true,
          timelineProofVisible:
              showTimelineProofMomentOnRecord &&
              timelineProofMomentCandidate != null,
          firstProofPayoffVisible: false,
          isRecording: flags.isRecording,
          isDegradedTranscriptState: isDegradedTranscriptOnRecord,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
        );
    var showNotRelevantRecoveryOnRecordReady =
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
    var showBetaProofLiftOnRecordReady =
        flags.isReady &&
        showTimelineProofMomentOnRecord &&
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
    showProBridgeVisibilityOnRecordReady =
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
                  showTimelineProofMomentOnRecord &&
                  timelineProofMomentCandidate != null,
              hasBetaTesterReportVisible: showBetaTesterReportOnRecord,
              hasCorrectionMemoryVisible:
                  showCorrectionMemoryOnRecordReady &&
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
            hasBetaProofLiftVisible: showBetaProofLiftOnRecordReady,
            hasReturnAfterProofStrengthenedVisible:
                showReturnAfterProofStrengthenedOnRecordReady,
          ),
        );
    final betaActivationPathPreAuditContext =
        BetaActivationPathEngine.buildContext(
          source: 'record',
          entryCount: input.entryCount,
          hasTimelineProof:
              showTimelineProofMomentOnRecord ||
              showArchiveTimelineSpineOnRecord,
          hasPaywallSeen: input.betaActivationLoopCounts.paywallSeen > 0,
          hasPurchaseCtaTapped: input.betaActivationLoopCounts.purchaseTapped > 0,
          strongerProCardVisible:
              showProBridgeVisibilityOnRecordReady ||
              showProEvidenceValueOnRecordReady ||
              showProVisibilityLiftOnRecordReady,
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
    var showBetaActivationPathCard =
        betaActivationPathPreAuditResult.shouldShow;
    BetaActivationPathResult? betaActivationPathResult;
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
            hasPurchaseCtaTapped: input.betaActivationLoopCounts.purchaseTapped > 0,
            isPro: input.userProState.isPro,
            timelineProofVisible:
                showTimelineProofMomentOnRecord &&
                timelineProofMomentCandidate != null,
            existingProofFeedbackVisible:
                BetaFeedbackCaptureEngine.existingProofFeedbackVisible(
                  surface: BetaProofFeedbackSurface.timelineProofMoment,
                  parentVisible:
                      showTimelineProofMomentOnRecord &&
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
                showFirstMomentCaptureCard ||
                showThreeMomentCompletionCard ||
                showSecondMomentReturnCard,
          ),
        );
    var showBetaFeedbackCaptureRecordReady =
        betaFeedbackCaptureRecordReadyPreAudit.shouldShow;
    var betaFeedbackCaptureRecordReadyResult =
        betaFeedbackCaptureRecordReadyPreAudit.shouldShow
        ? betaFeedbackCaptureRecordReadyPreAudit
        : null;
    final betaProofFeedbackCounts =
        FirstSessionProofRepairEngine.feedbackCountsFromStore();
    final betaProofFeedbackRowVisibleOnTimeline =
        FirstSessionProofRepairEngine.betaProofFeedbackRowVisible(
          parentVisible:
              showTimelineProofMomentOnRecord &&
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
          showTimelineProofMomentOnRecord &&
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
    var showProofQualityRepairOnRecord =
        FirstSessionProofRepairEngine.shouldShowProof(
          input: proofQualityRepairInput,
        );
    final proofQualityRepairResult = showProofQualityRepairOnRecord
        ? FirstSessionProofRepairEngine.buildProof(
            input: proofQualityRepairInput,
          )
        : ProofQualityRepairResult.hidden;
    final proofFloorRescueInput = ProofFloorRescueEngine.inputFromStore(
      entryCount: input.entryCount,
      source: 'record_ready',
      isPro: input.userProState.isPro,
      hasTimelineProofVisible:
          showTimelineProofMomentOnRecord &&
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
    var showProofFloorRescueOnRecord = ProofFloorRescueEngine.shouldShowCard(
      input: proofFloorRescueInput,
    );
    final proofFloorRescueResult = showProofFloorRescueOnRecord
        ? ProofFloorRescueEngine.build(input: proofFloorRescueInput)
        : ProofFloorRescueResult.hidden;
    final blocksProByProofFloorOnRecord =
        ProofFloorRescueEngine.blocksProMonetization(proofFloorRescueInput);
    if (blocksProByProofFloorOnRecord) {
      showProUnderstandingLiftOnRecordReady = false;
      showProVisibilityLiftOnRecordReady = false;
      showProBridgeVisibilityOnRecordReady = false;
      showProEvidenceValueOnRecordReady = false;
      showProEvidenceValuePrivateReportOnRecord = false;
      showBetaRepairLabProPlacementOnRecord = false;
      showBetaRepairLabPaywallValueOnRecord = false;
      showBetaRepairLabPricingValueFramingOnRecord = false;
      showBetaRepairLabPricingValidationOnRecord = false;
      showBetaRepairLabEvidenceTrailClarityOnRecord = false;
    }
    if (ProofFloorRescueEngine.shouldSuppressStrongProofPayoff(
      proofFloorRescueInput,
    )) {
      showBetaProofLiftOnRecordReady = false;
    }
    if (showProofFloorRescueOnRecord) {
      showProofQualityRepairOnRecord = false;
    }
    var showBetaRepairLabProofOnRecord = BetaRepairLabEngine.shouldShowProof(
      input: betaRepairLabInput,
    );
    final betaRepairLabProofResult = showBetaRepairLabProofOnRecord
        ? BetaRepairLabEngine.buildProof(input: betaRepairLabInput)
        : BetaRepairLabProofResult.hidden;
    final blocksProCardsByProofProtectionOnRecord =
        BetaRepairLabEngine.blocksProWhenProofRepairActive(
          input: betaRepairLabInput,
          showProofRepair: showBetaRepairLabProofOnRecord,
        );
    showBetaRepairLabEvidenceTrailClarityOnRecord =
        EvidenceTrailClarityEngine.shouldShow(
          input: betaRepairLabInput,
          hasSafeAnchor: recordLoosenSignalsPreAudit.hasSafeAnchor,
          blocksProCards:
              blocksProByProofFloorOnRecord ||
              blocksProCardsByProofProtectionOnRecord,
        );
    final betaRepairLabEvidenceTrailClarityResult =
        showBetaRepairLabEvidenceTrailClarityOnRecord
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
      showProofRepair: showBetaRepairLabProofOnRecord,
    )) {
      showProofFloorRescueOnRecord = false;
      showProofQualityRepairOnRecord = false;
    }
    if (BetaRepairLabEngine.blocksProWhenProofRepairActive(
          input: betaRepairLabInput,
          showProofRepair: showBetaRepairLabProofOnRecord,
        ) ||
        BetaRepairLabEngine.blocksOtherProCardsWhenPlacementRepairActive(
          betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
          showProPlacement: showBetaRepairLabProPlacementOnRecord,
        ) ||
        PaywallValueRepairEngine.blocksOtherProCardsWhenPaywallValueRepairActive(
          betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
          showPaywallValue: showBetaRepairLabPaywallValueOnRecord,
        ) ||
        PricingValueFramingEngine.blocksOtherProCardsWhenPricingValueFramingActive(
          betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
          showPricingValueFraming: showBetaRepairLabPricingValueFramingOnRecord,
        ) ||
        PricingValidationEngine.blocksOtherProCardsWhenPricingValidationActive(
          betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
          showPricingValidation: showBetaRepairLabPricingValidationOnRecord,
        ) ||
        EvidenceTrailClarityEngine.blocksOtherProCardsWhenEvidenceTrailClarityActive(
          betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
          showEvidenceTrailClarity:
              showBetaRepairLabEvidenceTrailClarityOnRecord,
        )) {
      showProUnderstandingLiftOnRecordReady = false;
      showProVisibilityLiftOnRecordReady = false;
      showProBridgeVisibilityOnRecordReady = false;
      showProEvidenceValueOnRecordReady = false;
      showProEvidenceValuePrivateReportOnRecord = false;
    }
    SurfacePriorityResult? recordReadySurfacePriority;
    ProBridgeTimingLoosenSignals? recordLoosenSignals;
    ProMomentTimingContext? recordReadyProTiming;
    BetaActivationPathContext? betaActivationPathFinalContext;
    if (flags.isReady) {
      recordReadySurfacePriority = SurfacePriorityEngine.auditRecordReady(
        entryCount: input.entryCount,
        source: 'record',
        candidates: SurfacePriorityCandidates.recordReady(
          firstSessionProofRepair: showFirstSessionCaptureRepairCard,
          firstSessionLift: showFirstSessionLiftCard,
          firstSaveLift: showFirstSaveLiftCard,
          betaActivationPath:
              showBetaActivationPathCard &&
              betaActivationPathPreAuditResult.slot ==
                  BetaActivationPathSlot.guidance,
          betaActivationPathRevenue:
              showBetaActivationPathCard &&
              betaActivationPathPreAuditResult.slot ==
                  BetaActivationPathSlot.revenue,
          threeMomentCompletion: showThreeMomentCompletionCard,
          firstMomentCapture: showFirstMomentCaptureCard,
          secondMomentReturn: showSecondMomentReturnCard,
          returnAfterProofStrengthened:
              showReturnAfterProofStrengthenedOnRecordReady,
          returnAfterProofLiftV2: showReturnAfterProofLiftV2OnRecordReady,
          returnAfterProof: showReturnAfterProofGenericOnRecordReady,
          lowFrictionReturn: showLowFrictionReturnCard,
          whatToNoticeNext: showWhatToNoticeNextCard,
          betaTodaySummary: showBetaTodaySummaryCard,
          openCapturePromptChips: showOpenCapturePromptChips,
          captureFreedomLine: showCaptureFreedomLine,
          firstRunPositioning: showFirstRunPositioningCard,
          timelineProofMoment:
              showTimelineProofMomentOnRecord &&
              timelineProofMomentCandidate != null,
          archiveTimelineSpine:
              showArchiveTimelineSpineOnRecord &&
              archiveTimelineSpineCandidate != null,
          timelinePositioning: showTimelinePositioningOnRecordReady,
          currentRelevance:
              showCurrentRelevanceOnRecordReady &&
              currentRelevanceCandidate != null,
          correctionMemory:
              showCorrectionMemoryOnRecordReady &&
              correctionMemoryCandidate != null,
          notRelevantRecovery:
              showNotRelevantRecoveryOnRecordReady &&
              notRelevantRecoveryCandidate.shouldShow,
          proofQualityResponse:
              showProofQualityResponseOnRecordReady &&
              proofQualityResponseTimelineCandidate.shouldShow,
          proofQualityRepair: showProofQualityRepairOnRecord,
          proofFloorRescue: showProofFloorRescueOnRecord,
          betaProofLift: showBetaProofLiftOnRecordReady,
          evidenceWeighting:
              showEvidenceWeightingOnRecordReady &&
              evidenceWeightingCandidate != null,
          proofSpecificity:
              showProofSpecificityOnRecordReady &&
              proofSpecificityCandidate.shouldShow,
          presentDayRelevance:
              showPresentDayRelevanceOnRecordReady &&
              presentDayRelevanceCandidate != null,
          patternConfidence:
              showPatternConfidenceExplanationOnRecordReady &&
              patternConfidenceExplanationCandidate != null,
          betaTesterReport: showBetaTesterReportOnRecord,
          proUnderstandingLift: showProUnderstandingLiftOnRecordReady,
          proVisibilityLift: showProVisibilityLiftOnRecordReady,
          proBridgeVisibility: showProBridgeVisibilityOnRecordReady,
          proEvidenceValue: showProEvidenceValueOnRecordReady,
          privateReportProBridge: showProEvidenceValuePrivateReportOnRecord,
          suppressLegacyEducation: suppressLegacyEducationCardsForSpineOnRecord,
          betaFeedbackCapture: showBetaFeedbackCaptureRecordReady,
        ),
      );
      SurfacePriorityAnalytics.seen(result: recordReadySurfacePriority);
      final audit = recordReadySurfacePriority;
      showFirstSessionCaptureRepairCard = audit.isVisible(
        SurfacePriorityCardKey.firstSessionProofRepair,
        candidate: showFirstSessionCaptureRepairCard,
      );
      showFirstSessionLiftCard = audit.isVisible(
        SurfacePriorityCardKey.firstSessionLift,
        candidate: showFirstSessionLiftCard,
      );
      showFirstSaveLiftCard = audit.isVisible(
        SurfacePriorityCardKey.firstSaveLift,
        candidate: showFirstSaveLiftCard,
      );
      showFirstMomentCaptureCard = audit.isVisible(
        SurfacePriorityCardKey.firstMomentCapture,
        candidate: showFirstMomentCaptureCard,
      );
      showThreeMomentCompletionCard = audit.isVisible(
        SurfacePriorityCardKey.threeMomentCompletion,
        candidate: showThreeMomentCompletionCard,
      );
      showSecondMomentReturnCard = audit.isVisible(
        SurfacePriorityCardKey.secondMomentReturn,
        candidate: showSecondMomentReturnCard,
      );
      showReturnAfterProofStrengthenedOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.returnAfterProofStrengthened,
        candidate: showReturnAfterProofStrengthenedOnRecordReady,
      );
      showReturnAfterProofLiftV2OnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.returnAfterProofLiftV2,
        candidate: showReturnAfterProofLiftV2OnRecordReady,
      );
      showReturnAfterProofGenericOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.returnAfterProof,
        candidate: showReturnAfterProofGenericOnRecordReady,
      );
      showReturnAfterProofOnRecordReady =
          showReturnAfterProofStrengthenedOnRecordReady ||
          showReturnAfterProofGenericOnRecordReady;
      showLowFrictionReturnCard = audit.isVisible(
        SurfacePriorityCardKey.lowFrictionReturn,
        candidate: showLowFrictionReturnCard,
      );
      showWhatToNoticeNextCard = audit.isVisible(
        SurfacePriorityCardKey.whatToNoticeNext,
        candidate: showWhatToNoticeNextCard,
      );
      showBetaTodaySummaryCard = audit.isVisible(
        SurfacePriorityCardKey.betaTodaySummary,
        candidate: showBetaTodaySummaryCard,
      );
      showOpenCapturePromptChips = audit.isVisible(
        SurfacePriorityCardKey.openCapturePromptChips,
        candidate: showOpenCapturePromptChips,
      );
      showCaptureFreedomLine = audit.isVisible(
        SurfacePriorityCardKey.captureFreedomLine,
        candidate: showCaptureFreedomLine,
      );
      showFirstRunPositioningCard = audit.isVisible(
        SurfacePriorityCardKey.firstRunPositioning,
        candidate: showFirstRunPositioningCard,
      );
      showTimelineProofMomentOnRecord = audit.isVisible(
        SurfacePriorityCardKey.timelineProofMoment,
        candidate:
            showTimelineProofMomentOnRecord &&
            timelineProofMomentCandidate != null,
      );
      showArchiveTimelineSpineOnRecord = audit.isVisible(
        SurfacePriorityCardKey.archiveTimelineSpine,
        candidate:
            showArchiveTimelineSpineOnRecord &&
            archiveTimelineSpineCandidate != null,
      );
      showTimelinePositioningOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.timelinePositioning,
        candidate: showTimelinePositioningOnRecordReady,
      );
      showCurrentRelevanceOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.currentRelevance,
        candidate:
            showCurrentRelevanceOnRecordReady &&
            currentRelevanceCandidate != null,
      );
      showCorrectionMemoryOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.correctionMemory,
        candidate:
            showCorrectionMemoryOnRecordReady &&
            correctionMemoryCandidate != null,
      );
      showNotRelevantRecoveryOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.notRelevantRecovery,
        candidate:
            showNotRelevantRecoveryOnRecordReady &&
            notRelevantRecoveryCandidate.shouldShow,
      );
      showProofQualityResponseOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.proofQualityResponse,
        candidate:
            showProofQualityResponseOnRecordReady &&
            proofQualityResponseTimelineCandidate.shouldShow,
      );
      showBetaProofLiftOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.betaProofLift,
        candidate: showBetaProofLiftOnRecordReady,
      );
      showEvidenceWeightingOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.evidenceWeighting,
        candidate:
            showEvidenceWeightingOnRecordReady &&
            evidenceWeightingCandidate != null,
      );
      showProofSpecificityOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.proofSpecificity,
        candidate:
            showProofSpecificityOnRecordReady &&
            proofSpecificityCandidate.shouldShow,
      );
      showPresentDayRelevanceOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.presentDayRelevance,
        candidate:
            showPresentDayRelevanceOnRecordReady &&
            presentDayRelevanceCandidate != null,
      );
      showPatternConfidenceExplanationOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.patternConfidence,
        candidate:
            showPatternConfidenceExplanationOnRecordReady &&
            patternConfidenceExplanationCandidate != null,
      );
      showBetaTesterReportOnRecord = audit.isVisible(
        SurfacePriorityCardKey.betaTesterReport,
        candidate: showBetaTesterReportOnRecord,
      );
      showProBridgeVisibilityOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.proBridgeVisibility,
        candidate: showProBridgeVisibilityOnRecordReady,
      );
      showProUnderstandingLiftOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.proUnderstandingLift,
        candidate: showProUnderstandingLiftOnRecordReady,
      );
      showProVisibilityLiftOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.proVisibilityLift,
        candidate: showProVisibilityLiftOnRecordReady,
      );
      showProEvidenceValueOnRecordReady = audit.isVisible(
        SurfacePriorityCardKey.proEvidenceValue,
        candidate: showProEvidenceValueOnRecordReady,
      );
      showProEvidenceValuePrivateReportOnRecord = audit.isVisible(
        SurfacePriorityCardKey.privateReportProBridge,
        candidate: showProEvidenceValuePrivateReportOnRecord,
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
            showTimelineProofMomentOnRecord &&
            timelineProofMomentCandidate != null,
        hasBetaTesterReportVisible: showBetaTesterReportOnRecord,
        hasCorrectionMemoryVisible:
            showCorrectionMemoryOnRecordReady &&
            correctionMemoryCandidate != null,
        hasBetaProofLiftVisible: showBetaProofLiftOnRecordReady,
        hasReturnAfterProofStrengthenedVisible:
            showReturnAfterProofStrengthenedOnRecordReady,
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
      showProBridgeVisibilityOnRecordReady = ProMomentTimingEngine.applyGate(
        candidate: showProBridgeVisibilityOnRecordReady,
        timing: recordReadyProTiming.copyWith(
          proSlotAvailable:
              !showProUnderstandingLiftOnRecordReady &&
              !showProVisibilityLiftOnRecordReady,
        ),
      );
      showProEvidenceValueOnRecordReady = ProMomentTimingEngine.applyGate(
        candidate: showProEvidenceValueOnRecordReady,
        timing: recordReadyProTiming.copyWith(
          proSlotAvailable:
              !showProUnderstandingLiftOnRecordReady &&
              !showProVisibilityLiftOnRecordReady &&
              !showProBridgeVisibilityOnRecordReady,
        ),
      );
      showProEvidenceValuePrivateReportOnRecord =
          ProMomentTimingEngine.applyGate(
            candidate: showProEvidenceValuePrivateReportOnRecord,
            timing: recordReadyProTiming.copyWith(
              hasMonthlyPrivateReportPreviewVisible: true,
              proSlotAvailable:
                  showProEvidenceValuePrivateReportOnRecord &&
                  !showProUnderstandingLiftOnRecordReady &&
                  !showProVisibilityLiftOnRecordReady &&
                  !showProBridgeVisibilityOnRecordReady &&
                  !showProEvidenceValueOnRecordReady,
            ),
          );
      betaActivationPathFinalContext =
          BetaActivationPathEngine.buildContext(
            source: 'record',
            entryCount: input.entryCount,
            hasTimelineProof:
                showTimelineProofMomentOnRecord ||
                showArchiveTimelineSpineOnRecord,
            hasPaywallSeen: input.betaActivationLoopCounts.paywallSeen > 0,
            hasPurchaseCtaTapped: input.betaActivationLoopCounts.purchaseTapped > 0,
            strongerProCardVisible:
                showProBridgeVisibilityOnRecordReady ||
                showProEvidenceValueOnRecordReady ||
                showProUnderstandingLiftOnRecordReady ||
                showProVisibilityLiftOnRecordReady,
            isReady: flags.isReady,
            isRecording: flags.isRecording,
            isPostSave: input.isPostSave,
            isDegradedTranscriptState: isDegradedTranscriptOnRecord,
            whatChangedQuestionActive: showWhatChangedV2,
            patternReviewInboxHasActiveItems: patternReviewInboxActiveOnRecord,
            isPermissionBlocked: flags.isPermissionBlocked,
          );
      betaActivationPathResult = BetaActivationPathEngine.build(
        context: betaActivationPathFinalContext,
      );
      showBetaActivationPathCard = betaActivationPathResult.shouldShow;
      if (betaActivationPathResult.slot == BetaActivationPathSlot.guidance) {
        showBetaActivationPathCard = audit.isVisible(
          SurfacePriorityCardKey.betaActivationPath,
          candidate: showBetaActivationPathCard,
        );
      } else if (betaActivationPathResult.slot ==
          BetaActivationPathSlot.revenue) {
        showBetaActivationPathCard = audit.isVisible(
          SurfacePriorityCardKey.betaActivationPathRevenue,
          candidate: showBetaActivationPathCard,
        );
      } else {
        showBetaActivationPathCard = false;
      }
      showProofQualityRepairOnRecord = audit.isVisible(
        SurfacePriorityCardKey.proofQualityRepair,
        candidate: showProofQualityRepairOnRecord,
      );
      showProofFloorRescueOnRecord = audit.isVisible(
        SurfacePriorityCardKey.proofFloorRescue,
        candidate: showProofFloorRescueOnRecord,
      );
      if (showProofFloorRescueOnRecord) {
        showProofQualityRepairOnRecord = false;
      }
      if (showFirstSessionCaptureRepairCard) {
        showFirstSessionLiftCard = false;
        showFirstSaveLiftCard = false;
        showBetaActivationPathCard = false;
      } else if (showFirstSessionLiftCard) {
        showFirstSaveLiftCard = false;
        showBetaActivationPathCard = false;
      } else if (showFirstSaveLiftCard) {
        showBetaActivationPathCard = false;
      }
      if (showBetaActivationPathCard &&
          betaActivationPathResult.slot == BetaActivationPathSlot.guidance) {
        showThreeMomentCompletionCard = false;
        showFirstMomentCaptureCard = false;
        showSecondMomentReturnCard = false;
      }
      showBetaFeedbackCaptureRecordReady = audit.isVisible(
        SurfacePriorityCardKey.betaFeedbackCapture,
        candidate: showBetaFeedbackCaptureRecordReady,
      );
      betaFeedbackCaptureRecordReadyResult = showBetaFeedbackCaptureRecordReady
          ? betaFeedbackCaptureRecordReadyPreAudit
          : null;
    }
    if (showTimelineProofMomentOnRecord &&
        timelineProofMomentCandidate != null) {
      ShareableProofSeenLatch.markTimelineProofMomentSeen();
    }
    if (showBetaTesterReportOnRecord) {
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
        showTimelineProofMomentOnRecord && timelineProofMomentCandidate != null;
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
        showTimelineProofMomentOnRecord &&
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
        showArchiveTimelineSpineOnRecord &&
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
        showTimelineProofMomentOnRecord &&
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
      showNotRelevantRecoveryOnRecordReady = false;
    }
    if (showProofQualityResponseUnderTimelineProof ||
        showProofQualityResponseUnderArchiveSpine) {
      showProofQualityResponseOnRecordReady = false;
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
        showNotRelevantRecoveryOnRecordReady = false;
      }
    }
    final showBetaProofLiftUnderTimelineProof =
        showBetaProofLiftOnRecordReady &&
        showTimelineProofMomentOnRecord &&
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
        showReturnAfterProofLiftV2OnRecordReady &&
        ((showTimelineProofMomentOnRecord &&
                timelineProofMomentCandidate != null) ||
            showBetaTesterReportOnRecord);
    final showReturnAfterProofLiftV2InGuidanceStack =
        showReturnAfterProofLiftV2OnRecordReady &&
        !showReturnAfterProofLiftV2BelowProofOnRecord;
    final showReturnAfterProofBelowProofOnRecord =
        showReturnAfterProofOnRecordReady &&
        !showReturnAfterProofLiftV2OnRecordReady &&
        ((showTimelineProofMomentOnRecord &&
                timelineProofMomentCandidate != null) ||
            showBetaTesterReportOnRecord);
    final showReturnAfterProofInGuidanceStack =
        showReturnAfterProofOnRecordReady &&
        !showReturnAfterProofBelowProofOnRecord;
    if (firstUseSimplifiedRecord) {
      showFirstSaveLiftCard = false;
      showFirstSessionLiftCard = false;
      showFirstSessionCaptureRepairCard = false;
      showSecondMomentReturnCard = false;
      showBetaActivationPathCard = false;
      showCaptureFreedomLine = false;
      showLowFrictionReturnCard = false;
      showBetaTodaySummaryCard = false;
      showWhatToNoticeNextCard = false;
      showFirstMomentCaptureCard = false;
      showThreeMomentCompletionCard = false;
      showOpenCapturePromptChips = false;
    }
    final showProUnderstandingLiftBelowProofOnRecord =
        showProUnderstandingLiftOnRecordReady &&
        ((showTimelineProofMomentOnRecord &&
                timelineProofMomentCandidate != null) ||
            showBetaTesterReportOnRecord ||
            showReturnAfterProofLiftV2BelowProofOnRecord);
    final showBetaRepairLabEvidenceTrailClarityBelowProofOnRecord =
        showBetaRepairLabEvidenceTrailClarityOnRecord &&
        betaRepairLabEvidenceTrailClarityResult.shouldShow &&
        ((showTimelineProofMomentOnRecord &&
                timelineProofMomentCandidate != null) ||
            showBetaTesterReportOnRecord ||
            showReturnAfterProofLiftV2BelowProofOnRecord);
    final showBetaRepairLabPricingValidationBelowProofOnRecord =
        showBetaRepairLabPricingValidationOnRecord &&
        betaRepairLabPricingValidationResult.shouldShow &&
        ((showTimelineProofMomentOnRecord &&
                timelineProofMomentCandidate != null) ||
            showBetaTesterReportOnRecord ||
            showReturnAfterProofLiftV2BelowProofOnRecord);
    final showBetaRepairLabPricingValueFramingBelowProofOnRecord =
        showBetaRepairLabPricingValueFramingOnRecord &&
        betaRepairLabPricingValueFramingResult.shouldShow &&
        ((showTimelineProofMomentOnRecord &&
                timelineProofMomentCandidate != null) ||
            showBetaTesterReportOnRecord ||
            showReturnAfterProofLiftV2BelowProofOnRecord);
    final showBetaRepairLabPaywallValueBelowProofOnRecord =
        showBetaRepairLabPaywallValueOnRecord &&
        betaRepairLabPaywallValueResult.shouldShow &&
        ((showTimelineProofMomentOnRecord &&
                timelineProofMomentCandidate != null) ||
            showBetaTesterReportOnRecord ||
            showReturnAfterProofLiftV2BelowProofOnRecord);
    final showBetaRepairLabProPlacementBelowProofOnRecord =
        showBetaRepairLabProPlacementOnRecord &&
        betaRepairLabProPlacementResult.shouldShow &&
        ((showTimelineProofMomentOnRecord &&
                timelineProofMomentCandidate != null) ||
            showBetaTesterReportOnRecord ||
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
              showTimelineProofMomentOnRecord &&
              timelineProofMomentCandidate != null,
          feedbackType: timelineFeedbackType,
          hasUsefulOrStrongProof:
              ProPlacementTriggerAuditEngine.hasUsefulOrStrongProof(
                feedbackType: timelineFeedbackType,
                confidenceLevel:
                    recordLoosenSignalsPreAudit.confidenceLevel ??
                    ProofConfidenceLevel.watchOnly,
              ),
          proPlacementEligible: showBetaRepairLabProPlacementOnRecord,
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
        showProUnderstandingLiftOnRecordReady &&
        !showProUnderstandingLiftBelowProofOnRecord;
    final showProVisibilityLiftBelowProofOnRecord =
        showProVisibilityLiftOnRecordReady &&
        !showProUnderstandingLiftOnRecordReady &&
        ((showTimelineProofMomentOnRecord &&
                timelineProofMomentCandidate != null) ||
            showBetaTesterReportOnRecord ||
            showReturnAfterProofLiftV2BelowProofOnRecord);
    final showProVisibilityLiftInProSectionOnRecord =
        showProVisibilityLiftOnRecordReady &&
        !showProVisibilityLiftBelowProofOnRecord;
    final showProBridgeBelowProofOnRecord =
        showProBridgeVisibilityOnRecordReady &&
        !showProUnderstandingLiftOnRecordReady &&
        !showProVisibilityLiftOnRecordReady &&
        ((showTimelineProofMomentOnRecord &&
                timelineProofMomentCandidate != null) ||
            showBetaTesterReportOnRecord ||
            showReturnAfterProofStrengthenedOnRecordReady);
    final showProBridgeInProSectionOnRecord =
        showProBridgeVisibilityOnRecordReady &&
        !showProUnderstandingLiftOnRecordReady &&
        !showProVisibilityLiftOnRecordReady &&
        !showProBridgeBelowProofOnRecord;
    final proBridgeVisibilityRecordResult = showProBridgeVisibilityOnRecordReady
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
                    showTimelineProofMomentOnRecord &&
                    timelineProofMomentCandidate != null,
                hasBetaTesterReportVisible: showBetaTesterReportOnRecord,
                hasCorrectionMemoryVisible:
                    showCorrectionMemoryOnRecordReady &&
                    correctionMemoryCandidate != null,
                hasBetaProofLiftVisible: showBetaProofLiftOnRecordReady,
                hasReturnAfterProofStrengthenedVisible:
                    showReturnAfterProofStrengthenedOnRecordReady,
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
              hasBetaProofLiftVisible: showBetaProofLiftOnRecordReady,
              hasReturnAfterProofStrengthenedVisible:
                  showReturnAfterProofStrengthenedOnRecordReady,
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
    var showTimelineProofMomentOnFirstProofPayoff =
        TimelineProofMomentEngine.shouldShowOnFirstProofPayoffPostSave(
          result: timelineProofMomentPostSaveCandidate,
          showFirstProofPayoff: showFirstProofPayoff,
          isDegradedPostSave:
              entriesAfterSave.isNotEmpty &&
              VoiceCaptureQuality.isDegradedVoiceCapture(entriesAfterSave.last),
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
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
    var showProofSpecificityOnFirstProofPayoff =
        flags.isDone &&
        showFirstProofPayoff &&
        ProofSpecificityEngine.shouldShowOnFirstProofPayoff(
          result: proofSpecificityPostSaveCandidate,
          isPostSaveDegradedState:
              entriesAfterSave.isNotEmpty &&
              VoiceCaptureQuality.isDegradedVoiceCapture(entriesAfterSave.last),
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
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
        showFirstProofPayoff && firstProofPayoffCandidate != null;
    var showProofSpecificityBoostOnFirstProofPayoff =
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
      showProofSpecificityBoostOnFirstProofPayoff = false;
    }
    final timelineProofPostSaveParentVisible =
        showTimelineProofMomentOnFirstProofPayoff &&
        timelineProofMomentPostSaveCandidate != null;
    var showProofSpecificityBoostOnTimelineProofPostSave =
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
      showProofSpecificityBoostOnTimelineProofPostSave = false;
    }
    var showBetaProofLiftOnFirstProofPayoff =
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
        );
    var showBetaProofLiftUnderTimelineProofPostSave =
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
      showProofSpecificityBoostOnFirstProofPayoff = false;
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
      showProofSpecificityBoostOnTimelineProofPostSave = false;
    }
    var showReturnAfterProofStrengthenedOnFirstProofPayoff =
        flags.isDone &&
        ReturnAfterProofEngine.shouldShowStrengthenedOnFirstProofPayoffPostSave(
          result: returnAfterProofPostSaveCandidate,
          showFirstProofPayoff: showFirstProofPayoff,
          isRecording: flags.isRecording,
          isPostSaveDegraded: postSaveDegraded,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
          dismissedForToday: ReturnAfterProofStore.isDismissedToday,
        );
    var showReturnAfterProofGenericOnFirstProofPayoff =
        flags.isDone &&
        ReturnAfterProofEngine.shouldShowGenericOnFirstProofPayoffPostSave(
          result: returnAfterProofPostSaveCandidate,
          showFirstProofPayoff: showFirstProofPayoff,
          isRecording: flags.isRecording,
          isPostSaveDegraded: postSaveDegraded,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
          dismissedForToday: ReturnAfterProofStore.isDismissedToday,
        );
    var showReturnAfterProofOnFirstProofPayoff =
        showReturnAfterProofStrengthenedOnFirstProofPayoff ||
        showReturnAfterProofGenericOnFirstProofPayoff;
    final returnAfterProofLiftV2PostSaveCandidate =
        ReturnAfterProofLiftV2Engine.build(
          entries: entriesAfterSave,
          source: 'record_post_save',
          firstProofSeen: true,
          timelineProofVisible:
              showTimelineProofMomentOnFirstProofPayoff &&
              timelineProofMomentPostSaveCandidate != null,
        );
    var showReturnAfterProofLiftV2OnPostSave =
        ReturnAfterProofLiftV2Engine.shouldShow(
          result: returnAfterProofLiftV2PostSaveCandidate,
          isReady: false,
          isRecording: flags.isRecording,
          isPostSave: flags.isDone,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: postSaveDegraded,
          whatChangedQuestionActive: showWhatChangedV2,
          patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
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
    var showProUnderstandingLiftOnPostSave =
        flags.isDone &&
        entriesAfterSave.isNotEmpty &&
        showFirstProofPayoff &&
        firstProofPayoffCandidate != null &&
        ProUnderstandingLiftEngine.shouldShowCard(
          input: proUnderstandingLiftPostSaveInput,
        );
    ProUnderstandingLiftResult? base;
    ProUnderstandingLiftResult? proUnderstandingLiftPostSaveResult;
    if (showProUnderstandingLiftOnPostSave) {
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
    var showProVisibilityLiftOnPostSave =
        flags.isDone &&
        entriesAfterSave.isNotEmpty &&
        showFirstProofPayoff &&
        firstProofPayoffCandidate != null &&
        ProVisibilityLiftEngine.shouldShowCard(
          entryCount: postSaveEntryCount,
          isPro: input.userProState.isPro,
          hasUsefulProof:
              postSaveFeedbackStateForLift == ProofQualityFeedbackState.useful,
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
        );
    final proVisibilityLiftPostSaveResult = showProVisibilityLiftOnPostSave
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
    var showProEvidenceValuePostSave =
        flags.isDone &&
        entriesAfterSave.isNotEmpty &&
        showFirstProofPayoff &&
        firstProofPayoffCandidate != null &&
        ProEvidenceValueEngine.shouldShowCard(
          ProEvidenceValueEngine.buildContext(
            surface: ProEvidenceValueSurface.recordPostSaveAfterPayoff,
            entryCount: postSaveEntryCount,
            isPro: input.userProState.isPro,
            dismissed: ProEvidenceValueDismissStore.isDismissed(),
            entries: entriesAfterSave,
            returnChecks: RepeatReturnCheckStore.cached,
            isPostSaveDegradedState: VoiceCaptureQuality.isDegradedVoiceCapture(
              entriesAfterSave.last,
            ),
            firstProofTruthQuestionActive: showFirstProofTruth,
            whatChangedQuestionActive: showWhatChangedV2,
            firstProofPayoffVisible: true,
          ),
        );
    var showBetaInviteLoopPostSave =
        flags.isDone &&
        entriesAfterSave.isNotEmpty &&
        showFirstProofPayoff &&
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
            patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
          ),
        );
    var showProPreviewPostSave =
        flags.isDone &&
        entriesAfterSave.isNotEmpty &&
        showFirstProofPayoff &&
        firstProofPayoffCandidate != null &&
        ProPreviewEngine.shouldShowCard(
          ProPreviewEngine.buildContext(
            surface: ProPreviewSurface.recordPostSave,
            source: 'record_post_save',
            entryCount: postSaveEntryCount,
            isPro: input.userProState.isPro,
            dismissed: ProPreviewEngine.isDismissed(),
            entries: entriesAfterSave,
            hasTimelineProofVisible:
                showTimelineProofMomentOnFirstProofPayoff &&
                timelineProofMomentPostSaveCandidate != null,
            firstProofPayoffVisible: showFirstProofPayoff,
            isPostSaveDegradedState: postSaveDegraded,
            firstProofTruthQuestionActive: showFirstProofTruth,
            whatChangedQuestionActive: showWhatChangedV2,
            patternReviewInboxHasActiveItems: patternReviewInboxActivePostSave,
          ),
        );
    var showProBridgeVisibilityPostSave =
        flags.isDone &&
        entriesAfterSave.isNotEmpty &&
        showFirstProofPayoff &&
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
              hasFirstProofPayoffVisible: showFirstProofPayoff,
              hasTimelineProofVisible:
                  showTimelineProofMomentOnFirstProofPayoff &&
                  timelineProofMomentPostSaveCandidate != null,
              hasBetaProofLiftVisible:
                  showBetaProofLiftOnFirstProofPayoff ||
                  showBetaProofLiftUnderTimelineProofPostSave,
              hasReturnAfterProofStrengthenedVisible:
                  showReturnAfterProofStrengthenedOnFirstProofPayoff,
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
            hasBetaProofLiftVisible:
                showBetaProofLiftOnFirstProofPayoff ||
                showBetaProofLiftUnderTimelineProofPostSave,
            hasReturnAfterProofStrengthenedVisible:
                showReturnAfterProofStrengthenedOnFirstProofPayoff,
          ),
        );
    var showProLockMomentPostSave =
        flags.isDone &&
        entriesAfterSave.isNotEmpty &&
        showFirstProofPayoff &&
        firstProofPayoffCandidate != null &&
        !showProBridgeVisibilityPostSave &&
        !showProEvidenceValuePostSave &&
        ProLockMomentEngine.shouldShowCard(
          ProLockMomentEngine.buildContext(
            entryCount: postSaveEntryCount,
            isPro: input.userProState.isPro,
            dismissed: ProLockMomentDismissStore.isDismissed(),
            entries: entriesAfterSave,
            returnChecks: RepeatReturnCheckStore.cached,
            isPostSaveDegradedState: VoiceCaptureQuality.isDegradedVoiceCapture(
              entriesAfterSave.last,
            ),
            firstProofTruthQuestionActive: showFirstProofTruth,
            whatChangedQuestionActive: showWhatChangedV2,
            firstProofPayoffVisible: true,
            proEvidenceValueVisible: showProEvidenceValuePostSave,
          ),
        );
    final monthlyPrivateReportPreviewPostSave =
        flags.isDone && entriesAfterSave.isNotEmpty
        ? MonthlyPrivateReportEngine.build(
            entries: entriesAfterSave,
            returnChecks: RepeatReturnCheckStore.cached,
            isPostSave: true,
          )
        : null;
    var showMonthlyPrivateReportPreviewPostSave =
        flags.isDone &&
        entriesAfterSave.isNotEmpty &&
        showFirstProofPayoff &&
        firstProofPayoffCandidate != null &&
        !showProBridgeVisibilityPostSave &&
        !showProEvidenceValuePostSave &&
        !showProLockMomentPostSave &&
        monthlyPrivateReportPreviewPostSave != null &&
        MonthlyPrivateReportEngine.shouldShowCard(
          MonthlyPrivateReportEngine.buildContext(
            surface: MonthlyPrivateReportSurface.recordPostSaveAfterProof,
            entryCount: postSaveEntryCount,
            isPro: input.userProState.isPro,
            dismissed: MonthlyPrivateReportDismissStore.isDismissed(),
            entries: entriesAfterSave,
            returnChecks: RepeatReturnCheckStore.cached,
            preview: monthlyPrivateReportPreviewPostSave,
            isPostSaveDegradedState: postSaveDegraded,
            firstProofTruthQuestionActive: showFirstProofTruth,
            whatChangedQuestionActive: showWhatChangedV2,
            proLockMomentVisible: showProLockMomentPostSave,
            proEvidenceValueVisible: showProEvidenceValuePostSave,
            isPostSave: true,
          ),
        );
    const betaFeedbackRecordSurfaces = [
      BetaFeedbackIntelligenceSurface.afterProEvidenceSheet,
      BetaFeedbackIntelligenceSurface.afterFirstProofPayoff,
    ];
    final betaFeedbackIntelligenceSurfaceOnRecordReady =
        flags.isReady
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
                showFirstProofPayoff && firstProofPayoffCandidate != null,
          )
        : null;
    final helpedTrackingPrompt =
        flags.isDone && entriesAfterSave.isNotEmpty
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
        helpedTrackingPrompt != null && !showFirstProofPayoff;
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
        flags.isReady &&
            input.entryCountLoaded &&
            !input.isPostSave
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
    final dailyArchiveMemoryCandidate =
        flags.isReady &&
            input.entryCountLoaded &&
            !input.isPostSave
        ? DailyArchiveMemoryEngine.build(
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
        showFirstProofPayoff || showFirstProofTruth || showFirstProofActionLoop;
    final showDailyArchiveMemory = !V1FeatureFlags.enableV1Only && DailyArchiveMemoryGates.shouldShow(
            loaded: input.entryCountLoaded,
            entryCount: input.entryCount,
            isReady: flags.isReady,
            isRecording: flags.isRecording,
            isPostSave: input.isPostSave,
            memory: dailyArchiveMemoryCandidate,
            showReturnDayFlow: showReturnDayFlow,
            showReturnTomorrowCueReady: showReturnTomorrowCueReady,
            showLowEvidenceGuidance: showLowEvidenceGuidanceOnRecord,
            showWeeklyArchiveReview: showWeeklyArchiveReviewOnRecord,
            firstProofLoopActive: firstProofLoopActive,
            showComeBackTomorrowQuietSignal: showQuietSignalOnRecord,
          );
    final showReturningWatchTargetFocusedUi =
        ReturningRecordWatchTargetUiGates.showFocusedSurface(
          showDailyArchiveMemory: showDailyArchiveMemory,
          dailyArchiveMemory: dailyArchiveMemoryCandidate,
        );
    final recordReadyShowsWatchTargetOnly =
        showReturningWatchTargetFocusedUi &&
        flags.isReady &&
        !input.isPostSave;
    final recordReadySuppressStreakPressure =
        recordReadyShowsWatchTargetOnly ||
        ReturningRecordWatchTargetUiGates.suppressDailyStreakPressureToday();
    if (showReturningWatchTargetFocusedUi) {
      showOpenCapturePromptChips = false;
      showLowFrictionReturnCard = false;
      showCaptureFreedomLine = false;
      showBetaTodaySummaryCard = false;
      showBetaActivationPathCard = false;
      showBetaTesterReportOnRecord = false;
      showBetaFeedbackCaptureRecordReady = false;
      betaFeedbackCaptureRecordReadyResult = null;
      showBetaProofLiftOnRecordReady = false;
      showBetaRepairLabProPlacementOnRecord = false;
      showBetaRepairLabPricingValueFramingOnRecord = false;
      showBetaRepairLabPaywallValueOnRecord = false;
      showBetaRepairLabPricingValidationOnRecord = false;
      showBetaRepairLabEvidenceTrailClarityOnRecord = false;
      showBetaRepairLabProofOnRecord = false;
    }
    if (!ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces()) {
      showBetaTodaySummaryCard = false;
      showBetaActivationPathCard = false;
      showBetaTesterReportOnRecord = false;
      showBetaFeedbackCaptureRecordReady = false;
      betaFeedbackCaptureRecordReadyResult = null;
      showBetaProofLiftOnRecordReady = false;
      showBetaRepairLabProPlacementOnRecord = false;
      showBetaRepairLabPricingValueFramingOnRecord = false;
      showBetaRepairLabPaywallValueOnRecord = false;
      showBetaRepairLabPricingValidationOnRecord = false;
      showBetaRepairLabEvidenceTrailClarityOnRecord = false;
      showBetaRepairLabProofOnRecord = false;
    }
    final betaTestScriptCardCandidate =
        flags.isReady && input.entryCountLoaded
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
        flags.isReady &&
            input.entryCountLoaded &&
            !input.isPostSave
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
    var showComeBackTomorrowV2PostSave =
        !suppressNoisyFirstSaveCards &&
        ComeBackTomorrowV2Gates.shouldShowPostSave(
          isPostSaveDone: flags.isDone,
          isDegradedPostSave: postSaveDegradedForReturnCue,
          watch: comeBackTomorrowV2PostSaveWatch,
          showFirstProofPayoff: showFirstProofPayoff,
          showFirstProofTruth: showFirstProofTruth,
          showFirstProofActionLoop: showFirstProofActionLoop,
          showWhatChangedV2Display: showWhatChangedV2Display,
          showHelpedTracking: showHelpedTracking,
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
                  showTimelineProofMomentOnFirstProofPayoff &&
                  timelineProofMomentPostSaveCandidate != null,
              proPreviewVisible: showProPreviewPostSave,
              existingProofFeedbackVisible:
                  BetaFeedbackCaptureEngine.existingProofFeedbackVisible(
                    surface: BetaProofFeedbackSurface.timelineProofMoment,
                    parentVisible:
                        showTimelineProofMomentOnFirstProofPayoff &&
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
                        showFirstProofPayoff &&
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
    var showBetaFeedbackCapturePostSave =
        betaFeedbackCapturePostSavePreAudit.shouldShow;
    var betaFeedbackCapturePostSaveResult =
        betaFeedbackCapturePostSavePreAudit.shouldShow
        ? betaFeedbackCapturePostSavePreAudit
        : null;
    if (!ReturningRecordWatchTargetUiGates.showBetaRecordSurfaces()) {
      showBetaProofLiftOnFirstProofPayoff = false;
      showBetaProofLiftUnderTimelineProofPostSave = false;
      showBetaInviteLoopPostSave = false;
      showBetaFeedbackCapturePostSave = false;
      betaFeedbackCapturePostSaveResult = null;
    }
    final postSaveProofFloorRescueInput = ProofFloorRescueEngine.inputFromStore(
      entryCount: postSaveEntryCount,
      source: 'record_post_save',
      isPro: input.userProState.isPro,
      hasTimelineProofVisible:
          showTimelineProofMomentOnFirstProofPayoff &&
          timelineProofMomentPostSaveCandidate != null,
      hasConfirmedRepeat: EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
        entriesAfterSave,
      ),
      confidenceLevel:
          postSaveLoosenSignalsPreAudit.confidenceLevel ??
          ProofConfidenceLevel.watchOnly,
      hasSafeAnchor: postSaveLoosenSignalsPreAudit.hasSafeAnchor,
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
      showProUnderstandingLiftOnPostSave = false;
      showProVisibilityLiftOnPostSave = false;
      showProPreviewPostSave = false;
      showProBridgeVisibilityPostSave = false;
      showProEvidenceValuePostSave = false;
      showProLockMomentPostSave = false;
      showMonthlyPrivateReportPreviewPostSave = false;
    }
    if (ProofFloorRescueEngine.shouldSuppressStrongProofPayoff(
      postSaveProofFloorRescueInput,
    )) {
      showBetaProofLiftOnFirstProofPayoff = false;
      showBetaProofLiftUnderTimelineProofPostSave = false;
    }
    SurfacePriorityResult? recordPostSaveSurfacePriority;
    ProBridgeTimingLoosenSignals? postSaveLoosenSignals;
    ProMomentTimingContext? postSaveProTiming;
    BetaFeedbackCaptureResult? betaFeedbackCapturePostSaveFinal;
    if (flags.isDone) {
      recordPostSaveSurfacePriority = SurfacePriorityEngine.auditRecordPostSave(
        entryCount: postSaveEntryCount,
        source: 'record_post_save',
        candidates: SurfacePriorityCandidates.recordPostSave(
          lowFrictionReturn: showLowFrictionReturnCard,
          whatToNoticeNext: showWhatToNoticeNextCard,
          betaTodaySummary: showBetaTodaySummaryCard,
          openCapturePromptChips: showOpenCapturePromptChips,
          captureFreedomLine: showCaptureFreedomLine,
          firstProofPayoff:
              showFirstProofPayoff && firstProofPayoffCandidate != null,
          whatChanged: showWhatChangedV2 || showWhatChangedV2Display,
          returnPayoff: showComeBackTomorrowV2PostSave,
          timelineProofMomentPostSave:
              showTimelineProofMomentOnFirstProofPayoff &&
              timelineProofMomentPostSaveCandidate != null,
          proofSpecificityPostSave:
              showProofSpecificityOnFirstProofPayoff &&
              proofSpecificityPostSaveCandidate.shouldShow,
          betaProofFeedback:
              showFirstProofPayoff && firstProofPayoffCandidate != null,
          betaInviteLoop: showBetaInviteLoopPostSave,
          betaProofLift:
              showBetaProofLiftOnFirstProofPayoff ||
              showBetaProofLiftUnderTimelineProofPostSave,
          returnAfterProofStrengthened:
              showReturnAfterProofStrengthenedOnFirstProofPayoff,
          returnAfterProofLiftV2: showReturnAfterProofLiftV2OnPostSave,
          returnAfterProof: showReturnAfterProofGenericOnFirstProofPayoff,
          proofFloorRescue: blocksProByProofFloorOnPostSave,
          proPreview: showProPreviewPostSave,
          proUnderstandingLift: showProUnderstandingLiftOnPostSave,
          proVisibilityLift: showProVisibilityLiftOnPostSave,
          proBridgeVisibility: showProBridgeVisibilityPostSave,
          proEvidenceValue: showProEvidenceValuePostSave,
          proLockMoment: showProLockMomentPostSave,
          privateReportProBridge: showMonthlyPrivateReportPreviewPostSave,
          betaFeedbackCapture: showBetaFeedbackCapturePostSave,
        ),
      );
      SurfacePriorityAnalytics.seen(result: recordPostSaveSurfacePriority);
      final audit = recordPostSaveSurfacePriority;
      if (audit.isVisible(
        SurfacePriorityCardKey.whatChanged,
        candidate: showWhatChangedV2 || showWhatChangedV2Display,
      )) {
        showFirstProofPayoff = false;
      }
      showTimelineProofMomentOnFirstProofPayoff = audit.isVisible(
        SurfacePriorityCardKey.timelineProofMomentPostSave,
        candidate:
            showTimelineProofMomentOnFirstProofPayoff &&
            timelineProofMomentPostSaveCandidate != null,
      );
      showProofSpecificityOnFirstProofPayoff = audit.isVisible(
        SurfacePriorityCardKey.proofSpecificityPostSave,
        candidate:
            showProofSpecificityOnFirstProofPayoff &&
            proofSpecificityPostSaveCandidate.shouldShow,
      );
      showReturnAfterProofStrengthenedOnFirstProofPayoff = audit.isVisible(
        SurfacePriorityCardKey.returnAfterProofStrengthened,
        candidate:
            showReturnAfterProofStrengthenedOnFirstProofPayoff &&
            showFirstProofPayoff &&
            firstProofPayoffCandidate != null,
      );
      showReturnAfterProofGenericOnFirstProofPayoff = audit.isVisible(
        SurfacePriorityCardKey.returnAfterProof,
        candidate:
            showReturnAfterProofGenericOnFirstProofPayoff &&
            showFirstProofPayoff &&
            firstProofPayoffCandidate != null,
      );
      showReturnAfterProofOnFirstProofPayoff =
          showReturnAfterProofStrengthenedOnFirstProofPayoff ||
          showReturnAfterProofGenericOnFirstProofPayoff;
      showReturnAfterProofLiftV2OnPostSave = audit.isVisible(
        SurfacePriorityCardKey.returnAfterProofLiftV2,
        candidate:
            showReturnAfterProofLiftV2OnPostSave &&
            showFirstProofPayoff &&
            firstProofPayoffCandidate != null,
      );
      if (showReturnAfterProofLiftV2OnPostSave) {
        showReturnAfterProofStrengthenedOnFirstProofPayoff = false;
        showReturnAfterProofGenericOnFirstProofPayoff = false;
        showReturnAfterProofOnFirstProofPayoff = false;
      }
      showProPreviewPostSave = audit.isVisible(
        SurfacePriorityCardKey.proPreview,
        candidate: showProPreviewPostSave,
      );
      showBetaInviteLoopPostSave = audit.isVisible(
        SurfacePriorityCardKey.betaInviteLoop,
        candidate: showBetaInviteLoopPostSave,
      );
      showProBridgeVisibilityPostSave = audit.isVisible(
        SurfacePriorityCardKey.proBridgeVisibility,
        candidate: showProBridgeVisibilityPostSave,
      );
      showProUnderstandingLiftOnPostSave = audit.isVisible(
        SurfacePriorityCardKey.proUnderstandingLift,
        candidate: showProUnderstandingLiftOnPostSave,
      );
      showProVisibilityLiftOnPostSave = audit.isVisible(
        SurfacePriorityCardKey.proVisibilityLift,
        candidate: showProVisibilityLiftOnPostSave,
      );
      showProEvidenceValuePostSave = audit.isVisible(
        SurfacePriorityCardKey.proEvidenceValue,
        candidate: showProEvidenceValuePostSave,
      );
      showProLockMomentPostSave = audit.isVisible(
        SurfacePriorityCardKey.proLockMoment,
        candidate: showProLockMomentPostSave,
      );
      showBetaFeedbackCapturePostSave = audit.isVisible(
        SurfacePriorityCardKey.betaFeedbackCapture,
        candidate: showBetaFeedbackCapturePostSave,
      );
      betaFeedbackCapturePostSaveResult = showBetaFeedbackCapturePostSave
          ? betaFeedbackCapturePostSavePreAudit
          : null;
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
            showFirstProofPayoff && firstProofPayoffCandidate != null,
        hasTimelineProofVisible:
            showTimelineProofMomentOnFirstProofPayoff &&
            timelineProofMomentPostSaveCandidate != null,
        hasFirstProofPayoffVisible: showFirstProofPayoff,
        hasMonthlyPrivateReportPreviewVisible:
            showMonthlyPrivateReportPreviewPostSave,
        hasBetaProofLiftVisible:
            showBetaProofLiftOnFirstProofPayoff ||
            showBetaProofLiftUnderTimelineProofPostSave,
        hasReturnAfterProofStrengthenedVisible:
            showReturnAfterProofStrengthenedOnFirstProofPayoff,
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
      showProPreviewPostSave = ProMomentTimingEngine.applyGate(
        candidate: showProPreviewPostSave,
        timing: postSaveProTiming.copyWith(
          proSlotAvailable:
              !showProUnderstandingLiftOnPostSave &&
              !showProVisibilityLiftOnPostSave,
        ),
      );
      showProBridgeVisibilityPostSave = ProMomentTimingEngine.applyGate(
        candidate: showProBridgeVisibilityPostSave,
        timing: postSaveProTiming.copyWith(
          proSlotAvailable:
              !showProUnderstandingLiftOnPostSave &&
              !showProVisibilityLiftOnPostSave &&
              !showProPreviewPostSave,
        ),
      );
      showProEvidenceValuePostSave = ProMomentTimingEngine.applyGate(
        candidate: showProEvidenceValuePostSave,
        timing: postSaveProTiming.copyWith(
          proSlotAvailable:
              !showProUnderstandingLiftOnPostSave &&
              !showProVisibilityLiftOnPostSave &&
              !showProPreviewPostSave &&
              !showProBridgeVisibilityPostSave,
        ),
      );
      showProLockMomentPostSave = ProMomentTimingEngine.applyGate(
        candidate: showProLockMomentPostSave,
        timing: postSaveProTiming.copyWith(
          proSlotAvailable:
              showProLockMomentPostSave &&
              !showProUnderstandingLiftOnPostSave &&
              !showProVisibilityLiftOnPostSave &&
              !showProPreviewPostSave &&
              !showProBridgeVisibilityPostSave,
        ),
      );
      showMonthlyPrivateReportPreviewPostSave = ProMomentTimingEngine.applyGate(
        candidate: showMonthlyPrivateReportPreviewPostSave,
        timing: postSaveProTiming.copyWith(
          hasMonthlyPrivateReportPreviewVisible: true,
          proSlotAvailable:
              showMonthlyPrivateReportPreviewPostSave &&
              !showProUnderstandingLiftOnPostSave &&
              !showProVisibilityLiftOnPostSave &&
              !showProPreviewPostSave &&
              !showProBridgeVisibilityPostSave,
        ),
      );
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
          hasPurchaseCtaTapped: input.betaActivationLoopCounts.purchaseTapped > 0,
          isPro: input.userProState.isPro,
          timelineProofVisible:
              showTimelineProofMomentOnFirstProofPayoff &&
              timelineProofMomentPostSaveCandidate != null,
          proPreviewVisible: showProPreviewPostSave,
          existingProofFeedbackVisible:
              BetaFeedbackCaptureEngine.existingProofFeedbackVisible(
                surface: BetaProofFeedbackSurface.timelineProofMoment,
                parentVisible:
                    showTimelineProofMomentOnFirstProofPayoff &&
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
                    showFirstProofPayoff && firstProofPayoffCandidate != null,
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
      showBetaFeedbackCapturePostSave =
          showBetaFeedbackCapturePostSave &&
          betaFeedbackCapturePostSaveFinal.shouldShow;
      betaFeedbackCapturePostSaveResult = showBetaFeedbackCapturePostSave
          ? betaFeedbackCapturePostSaveFinal
          : null;
    }
    final proPreviewPostSaveResult = showProPreviewPostSave
        ? ProPreviewEngine.build(
            context: ProPreviewEngine.buildContext(
              surface: ProPreviewSurface.recordPostSave,
              source: 'record_post_save',
              entryCount: postSaveEntryCount,
              isPro: input.userProState.isPro,
              dismissed: ProPreviewEngine.isDismissed(),
              entries: entriesAfterSave,
              hasTimelineProofVisible:
                  showTimelineProofMomentOnFirstProofPayoff &&
                  timelineProofMomentPostSaveCandidate != null,
              firstProofPayoffVisible: showFirstProofPayoff,
              isPostSaveDegradedState: postSaveDegraded,
              firstProofTruthQuestionActive: showFirstProofTruth,
              whatChangedQuestionActive: showWhatChangedV2,
              patternReviewInboxHasActiveItems:
                  patternReviewInboxActivePostSave,
            ),
          )
        : null;
    final betaInviteLoopPostSaveResult = showBetaInviteLoopPostSave
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
    final proBridgeVisibilityPostSaveResult = showProBridgeVisibilityPostSave
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
                hasFirstProofPayoffVisible: showFirstProofPayoff,
                hasTimelineProofVisible:
                    showTimelineProofMomentOnFirstProofPayoff &&
                    timelineProofMomentPostSaveCandidate != null,
                hasBetaProofLiftVisible:
                    showBetaProofLiftOnFirstProofPayoff ||
                    showBetaProofLiftUnderTimelineProofPostSave,
                hasReturnAfterProofStrengthenedVisible:
                    showReturnAfterProofStrengthenedOnFirstProofPayoff,
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
              hasBetaProofLiftVisible:
                  showBetaProofLiftOnFirstProofPayoff ||
                  showBetaProofLiftUnderTimelineProofPostSave,
              hasReturnAfterProofStrengthenedVisible:
                  showReturnAfterProofStrengthenedOnFirstProofPayoff,
            ),
          )
        : null;
    final showReturnTomorrowCuePostSave =
        !suppressNoisyFirstSaveCards &&
        !showFirstProofPayoff &&
        !showComeBackTomorrowV2PostSave &&
        ReturnTomorrowCueGates.shouldShowPostSave(
          isPostSaveDone: flags.isDone,
          isDegradedPostSave: postSaveDegradedForReturnCue,
          cue: returnTomorrowCuePostSave,
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
          isDegradedPostSave: postSaveDegradedForReturnCue,
          progress: firstWeekProgressPostSave,
          showReturnTomorrowCue: showReturnTomorrowCuePostSave,
        );
    final showPostSaveReturnHandoff =
        !suppressNoisyFirstSaveCards &&
        PostSaveReturnHandoffGates.shouldShow(
          isPostSaveDone: flags.isDone,
          entryCount: postSaveEntryCount,
          isDegradedPostSave: postSaveDegradedForReturnCue,
          handoff: postSaveReturnHandoffCandidate,
        ) &&
        !showReturnTomorrowCuePostSave &&
        !showComeBackTomorrowV2PostSave;
    final beliefUpdatePayoff =
        flags.isDone &&
            entriesAfterSave.isNotEmpty &&
            !suppressLatestSaveArchiveInsight
        ? BeliefUpdatePayoffEngine.build(
            entries: entriesAfterSave,
            analysisSucceeded: lastCaptureAnalysisSucceeded,
          )
        : null;
    final journalShareProof =
        flags.isDone && entriesAfterSave.isNotEmpty
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
            reminderAvailable: input.offerDayTwoReminder && !input.recordReturnCueVisible,
          )
        : null;
    final postSaveDailyMirror =
        flags.isDone &&
            entriesAfterSave.isNotEmpty &&
            !suppressLatestSaveArchiveInsight
        ? const DailyMirrorEngine().build(entriesAfterSave)
        : null;
    final postSaveArchiveHierarchy =
        flags.isDone && entriesAfterSave.isNotEmpty
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
      showComeBackTomorrowV2PostSave = false;
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
    final returningUserToday =
        flags.isReady && input.entryCountLoaded
        ? ReturningUserTodayEngine.build(entries: input.journalEntries)
        : null;
    final nextMomentPrompt =
        flags.isReady && input.entryCountLoaded
        ? NextMomentPromptEngine.build(entries: input.journalEntries)
        : null;
    final dailyArchiveExercise =
        flags.isReady &&
            input.entryCountLoaded &&
            !ScreenshotMode.enabled
        ? const DailyArchiveExerciseEngine().buildFromJournal(
            entries: input.journalEntries,
            hasWatchTheme: input.hasWatchTheme,
            betaFeedbackCaptured: input.betaFeedbackCaptured,
          )
        : null;
    final todaysOneQuestion =
        flags.isReady &&
            input.entryCountLoaded &&
            !ScreenshotMode.enabled
        ? const TodaysQuestionEngine().buildFromJournal(
            entries: input.journalEntries,
            hasWatchTheme: input.hasWatchTheme,
            betaFeedbackCaptured: input.betaFeedbackCaptured,
            weeklyReviewAvailable: WeeklyArchiveReviewEngine.build(
              entries: input.journalEntries,
            ).hasEnoughEvidence,
          )
        : null;
    final recordHomeSurface =
        flags.isReady && input.entryCountLoaded
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


    final readyCapturePolicy = RecordSurfaceCapturePolicy.resolve(input, micPhase: policyMic, userDeniedThisSession: policyUserDenied);
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
          hideCardRecordButtons: RecordSurfaceCapturePolicy.shouldHideCardRecordButtons(input, readyCapturePolicy),
          promoteMicCaptureActions: RecordSurfaceCapturePolicy.shouldPromoteMicCaptureActions(readyCapturePolicy),
        );
    final showPositiveReinforcementRecordCta =
        showPositiveReinforcementOnRecord &&
        positiveReinforcement != null &&
        PositiveReinforcementGates.showRecordAgainCta(
          policy: readyCapturePolicy,
          hideCardRecordButtons: RecordSurfaceCapturePolicy.shouldHideCardRecordButtons(input, readyCapturePolicy),
          promoteMicCaptureActions: RecordSurfaceCapturePolicy.shouldPromoteMicCaptureActions(readyCapturePolicy),
          isCompletion: positiveReinforcement.isCompletion,
        );
    final showPatternChangedRecordCta =
        showPatternChanged &&
        patternChangedCandidate != null &&
        PatternChangedGates.showRecordCta(
          policy: readyCapturePolicy,
          hideCardRecordButtons: RecordSurfaceCapturePolicy.shouldHideCardRecordButtons(input, readyCapturePolicy),
          promoteMicCaptureActions: RecordSurfaceCapturePolicy.shouldPromoteMicCaptureActions(readyCapturePolicy),
        );
    final showArchiveSummaryRecordCta =
        showArchiveSummaryOnRecord &&
        ArchiveSummaryGates.showRecordNextCta(
          policy: readyCapturePolicy,
          hideCardRecordButtons: RecordSurfaceCapturePolicy.shouldHideCardRecordButtons(input, readyCapturePolicy),
          promoteMicCaptureActions: RecordSurfaceCapturePolicy.shouldPromoteMicCaptureActions(readyCapturePolicy),
        );
    final showDailyReturnReasonRecordCta =
        showDailyReturnReasonOnRecord &&
        DailyReturnReasonGates.showRecordCta(
          policy: readyCapturePolicy,
          hideCardRecordButtons: RecordSurfaceCapturePolicy.shouldHideCardRecordButtons(input, readyCapturePolicy),
          promoteMicCaptureActions: RecordSurfaceCapturePolicy.shouldPromoteMicCaptureActions(readyCapturePolicy),
        );
    final showFirstWeekLoopRecordCta =
        showFirstWeekLoopOnRecord &&
        firstWeekLoopCandidate != null &&
        FirstWeekLoopGates.showRecordCta(
          policy: readyCapturePolicy,
          hideCardRecordButtons: RecordSurfaceCapturePolicy.shouldHideCardRecordButtons(input, readyCapturePolicy),
          promoteMicCaptureActions: RecordSurfaceCapturePolicy.shouldPromoteMicCaptureActions(readyCapturePolicy),
        );


    return RecordSurfaceViewState(
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
      suppressPostResultNextCheckCompetitors: suppressPostResultNextCheckCompetitors,
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
      suppressEarlyRepeatPayoffCompetitors: suppressEarlyRepeatPayoffCompetitors,
      earlyFirstSignalOnRecord: earlyFirstSignalOnRecord,
      returnTomorrowCueReady: returnTomorrowCueReady,
      returnDayFlowCandidate: returnDayFlowCandidate,
      showReturnDayFlow: showReturnDayFlow,
      showReturnTomorrowCueReady: showReturnTomorrowCueReady,
      firstWeekProgressReady: firstWeekProgressReady,
      showFirstWeekProgressReady: showFirstWeekProgressReady,
      showEarlyReturnReminder: showEarlyReturnReminder,
      viewingConfirmedRepeatOnRecord: viewingConfirmedRepeatOnRecord,
      suppressConfirmedRepeatInlineFeedback: suppressConfirmedRepeatInlineFeedback,
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
      weeklyArchiveReviewVisibleForProGate: weeklyArchiveReviewVisibleForProGate,
      hasConfirmedRepeatForProGate: hasConfirmedRepeatForProGate,
      privateArchiveReportForProGate: privateArchiveReportForProGate,
      privateArchiveReportPreviewForProGate: privateArchiveReportPreviewForProGate,
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
      showCurrentRelevanceOnRecordReady: showCurrentRelevanceOnRecordReady,
      currentRelevanceQuestionActiveOnRecord: currentRelevanceQuestionActiveOnRecord,
      correctionMemoryCandidate: correctionMemoryCandidate,
      showCorrectionMemoryOnRecordReady: showCorrectionMemoryOnRecordReady,
      evidenceWeightingCandidate: evidenceWeightingCandidate,
      showEvidenceWeightingOnRecordReady: showEvidenceWeightingOnRecordReady,
      proofSpecificityCandidate: proofSpecificityCandidate,
      showProofSpecificityOnRecordReady: showProofSpecificityOnRecordReady,
      presentDayRelevanceCandidate: presentDayRelevanceCandidate,
      showPresentDayRelevanceOnRecordReady: showPresentDayRelevanceOnRecordReady,
      showCaptureFreedomLine: showCaptureFreedomLine,
      timelinePositioningCandidate: timelinePositioningCandidate,
      otherEducationCardsOnRecord: otherEducationCardsOnRecord,
      showTimelinePositioningOnRecordReady: showTimelinePositioningOnRecordReady,
      patternConfidenceEducationCount: patternConfidenceEducationCount,
      patternConfidenceExplanationCandidate: patternConfidenceExplanationCandidate,
      showPatternConfidenceExplanationOnRecordReady: showPatternConfidenceExplanationOnRecordReady,
      showProEvidenceValueOnRecordReady: showProEvidenceValueOnRecordReady,
      showProBridgeVisibilityOnRecordReady: showProBridgeVisibilityOnRecordReady,
      showProEvidenceValuePrivateReportOnRecord: showProEvidenceValuePrivateReportOnRecord,
      showConfirmedRepeatWhyMattersOnRecord: showConfirmedRepeatWhyMattersOnRecord,
      showConfirmedRepeatThoughtMapOnRecord: showConfirmedRepeatThoughtMapOnRecord,
      showPositiveReinforcementOnRecord: showPositiveReinforcementOnRecord,
      showHelpfulActionAppearedOnRecord: showHelpfulActionAppearedOnRecord,
      showChangeProofOnRecord: showChangeProofOnRecord,
      showFirstWeekLoopOnRecord: showFirstWeekLoopOnRecord,
      firstProofPayoffCandidate: firstProofPayoffCandidate,
      showFirstProofPayoff: showFirstProofPayoff,
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
      showCoreValueFeedbackOnRecordPostFirstProof: showCoreValueFeedbackOnRecordPostFirstProof,
      returnCheckPayoffCandidate: returnCheckPayoffCandidate,
      whatChangedV2Prompt: whatChangedV2Prompt,
      whatChangedV2Display: whatChangedV2Display,
      showWhatChangedV2: showWhatChangedV2,
      showWhatChangedV2Display: showWhatChangedV2Display,
      showOpenCapturePromptChips: showOpenCapturePromptChips,
      showLowFrictionReturnCard: showLowFrictionReturnCard,
      firstMomentCaptureCandidate: firstMomentCaptureCandidate,
      firstSaveLiftCandidate: firstSaveLiftCandidate,
      firstSessionCaptureRepairCandidate: firstSessionCaptureRepairCandidate,
      openingRepairOverride: openingRepairOverride,
      showFirstSessionCaptureRepairCard: showFirstSessionCaptureRepairCard,
      firstSessionLiftCandidate: firstSessionLiftCandidate,
      showFirstSessionLiftCard: showFirstSessionLiftCard,
      showFirstSaveLiftCard: showFirstSaveLiftCard,
      showFirstMomentCaptureCard: showFirstMomentCaptureCard,
      secondMomentReturnCandidate: secondMomentReturnCandidate,
      showSecondMomentReturnCard: showSecondMomentReturnCard,
      threeMomentCompletionCandidate: threeMomentCompletionCandidate,
      showThreeMomentCompletionCard: showThreeMomentCompletionCard,
      firstRunPositioningCandidate: firstRunPositioningCandidate,
      showFirstRunPositioningCard: showFirstRunPositioningCard,
      betaTodaySummaryCandidate: betaTodaySummaryCandidate,
      showBetaTodaySummaryCard: showBetaTodaySummaryCard,
      archiveTimelineSpineCandidate: archiveTimelineSpineCandidate,
      whatToNoticeNextCandidate: whatToNoticeNextCandidate,
      showWhatToNoticeNextCard: showWhatToNoticeNextCard,
      showArchiveTimelineSpineOnRecord: showArchiveTimelineSpineOnRecord,
      suppressLegacyEducationCardsForSpineOnRecord: suppressLegacyEducationCardsForSpineOnRecord,
      timelineProofMomentCandidate: timelineProofMomentCandidate,
      showTimelineProofMomentOnRecord: showTimelineProofMomentOnRecord,
      betaTesterReportCandidate: betaTesterReportCandidate,
      showBetaTesterReportOnRecord: showBetaTesterReportOnRecord,
      notRelevantRecoveryCandidate: notRelevantRecoveryCandidate,
      proofQualityResponseTimelineCandidate: proofQualityResponseTimelineCandidate,
      proofQualityResponseSpineCandidate: proofQualityResponseSpineCandidate,
      betaProofLiftTimelineCandidate: betaProofLiftTimelineCandidate,
      returnAfterProofRecordCandidate: returnAfterProofRecordCandidate,
      showReturnAfterProofStrengthenedOnRecordReady: showReturnAfterProofStrengthenedOnRecordReady,
      showReturnAfterProofGenericOnRecordReady: showReturnAfterProofGenericOnRecordReady,
      showReturnAfterProofOnRecordReady: showReturnAfterProofOnRecordReady,
      returnAfterProofLiftV2Candidate: returnAfterProofLiftV2Candidate,
      showReturnAfterProofLiftV2OnRecordReady: showReturnAfterProofLiftV2OnRecordReady,
      recordReadySurfacePriority: recordReadySurfacePriority,
      recordLoosenSignalsPreAudit: recordLoosenSignalsPreAudit,
      recordEvidenceAnchorPreAudit: recordEvidenceAnchorPreAudit,
      recordFeedbackStateForLift: recordFeedbackStateForLift,
      timelineFeedbackType: timelineFeedbackType,
      betaRepairLabInput: betaRepairLabInput,
      showBetaRepairLabProPlacementOnRecord: showBetaRepairLabProPlacementOnRecord,
      betaRepairLabProPlacementResult: betaRepairLabProPlacementResult,
      showBetaRepairLabPricingValueFramingOnRecord: showBetaRepairLabPricingValueFramingOnRecord,
      betaRepairLabPricingValueFramingResult: betaRepairLabPricingValueFramingResult,
      showBetaRepairLabPaywallValueOnRecord: showBetaRepairLabPaywallValueOnRecord,
      betaRepairLabPaywallValueResult: betaRepairLabPaywallValueResult,
      hasProEngagementOnRecord: hasProEngagementOnRecord,
      showBetaRepairLabPricingValidationOnRecord: showBetaRepairLabPricingValidationOnRecord,
      showBetaRepairLabEvidenceTrailClarityOnRecord: showBetaRepairLabEvidenceTrailClarityOnRecord,
      betaRepairLabPricingValidationResult: betaRepairLabPricingValidationResult,
      proUnderstandingLiftRecordReadyInput: proUnderstandingLiftRecordReadyInput,
      showProUnderstandingLiftOnRecordReady: showProUnderstandingLiftOnRecordReady,
      showProVisibilityLiftOnRecordReady: showProVisibilityLiftOnRecordReady,
      proUnderstandingLiftRecordReadyResult: proUnderstandingLiftRecordReadyResult,
      proVisibilityLiftRecordReadyResult: proVisibilityLiftRecordReadyResult,
      showProofQualityResponseOnRecordReady: showProofQualityResponseOnRecordReady,
      showNotRelevantRecoveryOnRecordReady: showNotRelevantRecoveryOnRecordReady,
      showBetaProofLiftOnRecordReady: showBetaProofLiftOnRecordReady,
      betaActivationPathPreAuditContext: betaActivationPathPreAuditContext,
      betaActivationPathPreAuditResult: betaActivationPathPreAuditResult,
      showBetaActivationPathCard: showBetaActivationPathCard,
      betaActivationPathResult: betaActivationPathResult,
      betaFeedbackCaptureRecordReadyPreAudit: betaFeedbackCaptureRecordReadyPreAudit,
      showBetaFeedbackCaptureRecordReady: showBetaFeedbackCaptureRecordReady,
      betaFeedbackCaptureRecordReadyResult: betaFeedbackCaptureRecordReadyResult,
      betaProofFeedbackCounts: betaProofFeedbackCounts,
      betaProofFeedbackRowVisibleOnTimeline: betaProofFeedbackRowVisibleOnTimeline,
      proofQualityRepairInput: proofQualityRepairInput,
      showProofQualityRepairOnRecord: showProofQualityRepairOnRecord,
      proofQualityRepairResult: proofQualityRepairResult,
      proofFloorRescueInput: proofFloorRescueInput,
      showProofFloorRescueOnRecord: showProofFloorRescueOnRecord,
      proofFloorRescueResult: proofFloorRescueResult,
      blocksProByProofFloorOnRecord: blocksProByProofFloorOnRecord,
      showBetaRepairLabProofOnRecord: showBetaRepairLabProofOnRecord,
      betaRepairLabProofResult: betaRepairLabProofResult,
      blocksProCardsByProofProtectionOnRecord: blocksProCardsByProofProtectionOnRecord,
      betaRepairLabEvidenceTrailClarityResult: betaRepairLabEvidenceTrailClarityResult,
      recordLoosenSignals: recordLoosenSignals,
      recordReadyProTiming: recordReadyProTiming,
      betaActivationPathFinalContext: betaActivationPathFinalContext,
      shareableNonPrivateProofResult: shareableNonPrivateProofResult,
      showShareableNonPrivateProofOnRecord: showShareableNonPrivateProofOnRecord,
      proofSpecificityBoostCandidate: proofSpecificityBoostCandidate,
      timelineProofParentVisible: timelineProofParentVisible,
      showProofSpecificityBoostOnTimelineProof: showProofSpecificityBoostOnTimelineProof,
      showProofQualityResponseUnderTimelineProof: showProofQualityResponseUnderTimelineProof,
      showProofQualityResponseUnderArchiveSpine: showProofQualityResponseUnderArchiveSpine,
      showNotRelevantRecoveryUnderTimelineProof: showNotRelevantRecoveryUnderTimelineProof,
      showBetaProofLiftUnderTimelineProof: showBetaProofLiftUnderTimelineProof,
      showReturnAfterProofLiftV2BelowProofOnRecord: showReturnAfterProofLiftV2BelowProofOnRecord,
      showReturnAfterProofLiftV2InGuidanceStack: showReturnAfterProofLiftV2InGuidanceStack,
      showReturnAfterProofBelowProofOnRecord: showReturnAfterProofBelowProofOnRecord,
      showReturnAfterProofInGuidanceStack: showReturnAfterProofInGuidanceStack,
      showProUnderstandingLiftBelowProofOnRecord: showProUnderstandingLiftBelowProofOnRecord,
      showBetaRepairLabEvidenceTrailClarityBelowProofOnRecord: showBetaRepairLabEvidenceTrailClarityBelowProofOnRecord,
      showBetaRepairLabPricingValidationBelowProofOnRecord: showBetaRepairLabPricingValidationBelowProofOnRecord,
      showBetaRepairLabPricingValueFramingBelowProofOnRecord: showBetaRepairLabPricingValueFramingBelowProofOnRecord,
      showBetaRepairLabPaywallValueBelowProofOnRecord: showBetaRepairLabPaywallValueBelowProofOnRecord,
      showBetaRepairLabProPlacementBelowProofOnRecord: showBetaRepairLabProPlacementBelowProofOnRecord,
      showProUnderstandingLiftInProSectionOnRecord: showProUnderstandingLiftInProSectionOnRecord,
      showProVisibilityLiftBelowProofOnRecord: showProVisibilityLiftBelowProofOnRecord,
      showProVisibilityLiftInProSectionOnRecord: showProVisibilityLiftInProSectionOnRecord,
      showProBridgeBelowProofOnRecord: showProBridgeBelowProofOnRecord,
      showProBridgeInProSectionOnRecord: showProBridgeInProSectionOnRecord,
      proBridgeVisibilityRecordResult: proBridgeVisibilityRecordResult,
      patternReviewInboxActivePostSave: patternReviewInboxActivePostSave,
      timelineProofMomentPostSaveCandidate: timelineProofMomentPostSaveCandidate,
      showTimelineProofMomentOnFirstProofPayoff: showTimelineProofMomentOnFirstProofPayoff,
      proofSpecificityPostSaveCandidate: proofSpecificityPostSaveCandidate,
      showProofSpecificityOnFirstProofPayoff: showProofSpecificityOnFirstProofPayoff,
      proofSpecificityBoostPostSaveCandidate: proofSpecificityBoostPostSaveCandidate,
      proofQualityResponseFirstProofCandidate: proofQualityResponseFirstProofCandidate,
      proofQualityResponseTimelinePostSaveCandidate: proofQualityResponseTimelinePostSaveCandidate,
      betaProofLiftFirstProofCandidate: betaProofLiftFirstProofCandidate,
      betaProofLiftTimelinePostSaveCandidate: betaProofLiftTimelinePostSaveCandidate,
      returnAfterProofPostSaveCandidate: returnAfterProofPostSaveCandidate,
      firstProofPayoffParentVisible: firstProofPayoffParentVisible,
      showProofSpecificityBoostOnFirstProofPayoff: showProofSpecificityBoostOnFirstProofPayoff,
      showProofQualityResponseOnFirstProofPayoff: showProofQualityResponseOnFirstProofPayoff,
      timelineProofPostSaveParentVisible: timelineProofPostSaveParentVisible,
      showProofSpecificityBoostOnTimelineProofPostSave: showProofSpecificityBoostOnTimelineProofPostSave,
      showProofQualityResponseOnTimelineProofPostSave: showProofQualityResponseOnTimelineProofPostSave,
      showBetaProofLiftOnFirstProofPayoff: showBetaProofLiftOnFirstProofPayoff,
      showBetaProofLiftUnderTimelineProofPostSave: showBetaProofLiftUnderTimelineProofPostSave,
      showReturnAfterProofStrengthenedOnFirstProofPayoff: showReturnAfterProofStrengthenedOnFirstProofPayoff,
      showReturnAfterProofGenericOnFirstProofPayoff: showReturnAfterProofGenericOnFirstProofPayoff,
      showReturnAfterProofOnFirstProofPayoff: showReturnAfterProofOnFirstProofPayoff,
      returnAfterProofLiftV2PostSaveCandidate: returnAfterProofLiftV2PostSaveCandidate,
      showReturnAfterProofLiftV2OnPostSave: showReturnAfterProofLiftV2OnPostSave,
      postSaveLoosenSignalsPreAudit: postSaveLoosenSignalsPreAudit,
      postSaveEvidenceAnchorPreAudit: postSaveEvidenceAnchorPreAudit,
      postSaveFeedbackStateForLift: postSaveFeedbackStateForLift,
      hasProEngagementOnPostSave: hasProEngagementOnPostSave,
      proUnderstandingLiftPostSaveInput: proUnderstandingLiftPostSaveInput,
      showProUnderstandingLiftOnPostSave: showProUnderstandingLiftOnPostSave,
      proUnderstandingLiftPostSaveResult: proUnderstandingLiftPostSaveResult,
      base: base,
      showProVisibilityLiftOnPostSave: showProVisibilityLiftOnPostSave,
      proVisibilityLiftPostSaveResult: proVisibilityLiftPostSaveResult,
      showProEvidenceValuePostSave: showProEvidenceValuePostSave,
      showBetaInviteLoopPostSave: showBetaInviteLoopPostSave,
      showProPreviewPostSave: showProPreviewPostSave,
      showProBridgeVisibilityPostSave: showProBridgeVisibilityPostSave,
      showProLockMomentPostSave: showProLockMomentPostSave,
      monthlyPrivateReportPreviewPostSave: monthlyPrivateReportPreviewPostSave,
      showMonthlyPrivateReportPreviewPostSave: showMonthlyPrivateReportPreviewPostSave,
      betaFeedbackIntelligenceSurfaceOnRecordReady: betaFeedbackIntelligenceSurfaceOnRecordReady,
      betaFeedbackIntelligenceSurfacePostSave: betaFeedbackIntelligenceSurfacePostSave,
      helpedTrackingPrompt: helpedTrackingPrompt,
      showHelpedTracking: showHelpedTracking,
      showReturnCheckPayoff: showReturnCheckPayoff,
      showArchiveSummaryOnRecord: showArchiveSummaryOnRecord,
      confirmedRepeatChangeNoticeOnRecord: confirmedRepeatChangeNoticeOnRecord,
      lowEvidenceGuidance: lowEvidenceGuidance,
      quietSignalCandidate: quietSignalCandidate,
      showQuietSignalOnRecord: showQuietSignalOnRecord,
      showLowEvidenceGuidanceOnRecord: showLowEvidenceGuidanceOnRecord,
      dailyArchiveMemoryCandidate: dailyArchiveMemoryCandidate,
      firstProofLoopActive: firstProofLoopActive,
      showDailyArchiveMemory: showDailyArchiveMemory,
      showReturningWatchTargetFocusedUi: showReturningWatchTargetFocusedUi,
      recordReadyShowsWatchTargetOnly: recordReadyShowsWatchTargetOnly,
      recordReadySuppressStreakPressure: recordReadySuppressStreakPressure,
      betaTestScriptCardCandidate: betaTestScriptCardCandidate,
      showBetaTestScriptCard: showBetaTestScriptCard,
      daysSinceLastEntry: daysSinceLastEntry,
      showReturnedAfterDelayRecovery: showReturnedAfterDelayRecovery,
      nextBestActionCandidate: nextBestActionCandidate,
      showNextBestActionOnRecord: showNextBestActionOnRecord,
      postSaveReturnHandoffCandidate: postSaveReturnHandoffCandidate,
      returnTomorrowCuePostSave: returnTomorrowCuePostSave,
      postSaveDegradedForReturnCue: postSaveDegradedForReturnCue,
      comeBackTomorrowV2PostSaveWatch: comeBackTomorrowV2PostSaveWatch,
      showComeBackTomorrowV2PostSave: showComeBackTomorrowV2PostSave,
      showPostSaveCuriosityHook: showPostSaveCuriosityHook,
      betaFeedbackCapturePostSavePreAudit: betaFeedbackCapturePostSavePreAudit,
      showBetaFeedbackCapturePostSave: showBetaFeedbackCapturePostSave,
      betaFeedbackCapturePostSaveResult: betaFeedbackCapturePostSaveResult,
      postSaveProofFloorRescueInput: postSaveProofFloorRescueInput,
      blocksProByProofFloorOnPostSave: blocksProByProofFloorOnPostSave,
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
      showDegradedTranscriptFocusedPostSave: showDegradedTranscriptFocusedPostSave,
      suppressDegradedTranscriptPostSaveCompetitors: suppressDegradedTranscriptPostSaveCompetitors,
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