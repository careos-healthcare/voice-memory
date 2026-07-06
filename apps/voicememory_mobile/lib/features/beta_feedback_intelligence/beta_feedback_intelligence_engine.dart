import '../../models/journal_entry.dart';
import '../../services/app_services.dart';
import '../beta/archive_beta_mission_gate.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../pro_evidence_value/pro_evidence_value_engine.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import '../repeat_return_check/repeat_return_check_store.dart';
import 'beta_feedback_intelligence_copy.dart';
import 'beta_feedback_intelligence_model.dart';
import 'beta_feedback_intelligence_store.dart';

/// Visibility, summary, and milestone sync for beta feedback intelligence.
abstract final class BetaFeedbackIntelligenceEngine {
  BetaFeedbackIntelligenceEngine._();

  static BetaFeedbackIntelligenceContext buildContext({
    required BetaFeedbackIntelligenceSurface surface,
    required int entryCount,
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
    bool isZeroEntryState = false,
    bool isRecordingState = false,
    bool isDegradedTranscriptState = false,
    bool isPostSaveDegradedState = false,
    bool firstProofTruthQuestionActive = false,
    bool whatChangedQuestionActive = false,
    bool firstProofPayoffVisible = false,
    bool proEvidenceSheetOpenedThisSession = false,
  }) {
    final state = BetaFeedbackIntelligenceStore.cached;
    final firstProofPayoffSeen = firstProofPayoffVisible ||
        ProEvidenceValueEngine.firstProofPayoffSeenForEntries(entries);
    return BetaFeedbackIntelligenceContext(
      surface: surface,
      entryCount: entryCount,
      betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
      submittedForSession: BetaFeedbackIntelligenceStore.isSubmittedForSession(),
      firstProofPayoffSeen: firstProofPayoffSeen,
      proEvidenceSheetOpenedThisSession:
          proEvidenceSheetOpenedThisSession ||
              state.hasOpenedProEvidenceSheet ||
              BetaFeedbackIntelligenceStore.sessionProEvidenceSheetOpened,
      isZeroEntryState: isZeroEntryState,
      isRecordingState: isRecordingState,
      isDegradedTranscriptState: isDegradedTranscriptState,
      isPostSaveDegradedState: isPostSaveDegradedState,
      firstProofTruthQuestionActive: firstProofTruthQuestionActive,
      whatChangedQuestionActive: whatChangedQuestionActive,
      patternReviewInboxHasActiveItems:
          ProEvidenceValueEngine.patternReviewInboxHasActiveItems(
        entries: entries,
        returnChecks: returnChecks,
      ),
    );
  }

  static bool shouldShowCard(BetaFeedbackIntelligenceContext context) {
    if (!context.betaMissionEnabled) return false;
    if (_isBlocked(context)) return false;
    return switch (context.surface) {
      BetaFeedbackIntelligenceSurface.testingArchiveMe => true,
      BetaFeedbackIntelligenceSurface.settingsBeta =>
        context.firstProofPayoffSeen,
      BetaFeedbackIntelligenceSurface.afterProEvidenceSheet =>
        context.proEvidenceSheetOpenedThisSession,
      BetaFeedbackIntelligenceSurface.afterFirstProofPayoff =>
        context.firstProofPayoffSeen,
    };
  }

  static bool _isBlocked(BetaFeedbackIntelligenceContext context) {
    if (context.submittedForSession) return true;
    if (context.entryCount <= 0 || context.isZeroEntryState) return true;
    if (context.isRecordingState) return true;
    if (context.isDegradedTranscriptState) return true;
    if (context.isPostSaveDegradedState) return true;
    if (context.firstProofTruthQuestionActive) return true;
    if (context.whatChangedQuestionActive) return true;
    if (context.patternReviewInboxHasActiveItems) return true;
    return false;
  }

  static Future<BetaFeedbackIntelligenceState> syncMilestones({
    required List<JournalEntry> entries,
  }) async {
    await BetaFeedbackIntelligenceStore.ensureLoaded();
    var state = BetaFeedbackIntelligenceStore.cached;
    final hasSavedFirstMoment = entries.isNotEmpty;
    final hasReachedFirstProof =
        ProEvidenceValueEngine.firstProofPayoffSeenForEntries(entries) ||
            EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries);
    final next = state.copyWith(
      hasSavedFirstMoment: hasSavedFirstMoment || state.hasSavedFirstMoment,
      hasReachedFirstProof: hasReachedFirstProof || state.hasReachedFirstProof,
    );
    if (next.hasSavedFirstMoment != state.hasSavedFirstMoment ||
        next.hasReachedFirstProof != state.hasReachedFirstProof) {
      await BetaFeedbackIntelligenceStore.save(next);
      state = next;
    }
    return state;
  }

  static BetaFeedbackIntelligenceSummary buildSummary({
    required List<JournalEntry> entries,
  }) {
    final state = BetaFeedbackIntelligenceStore.cached;
    final firstProofReached =
        state.hasReachedFirstProof ||
            ProEvidenceValueEngine.firstProofPayoffSeenForEntries(entries);
    final chatGptLabel = _chatGptLabel(state.chatGptDifferenceAnswer);
    final proValueLabel = _wouldPayLabel(state.wouldPayAnswer);
    final mainConfusionLabel =
        _mainConfusionLabel(state.mainConfusionBucket);
    final strongestMomentLabel =
        _strongestMomentLabel(state.strongestMomentBucket);
    final feedbackSubmittedLabel = state.hasSubmittedBetaFeedback
        ? BetaFeedbackIntelligenceCopy.summaryYes
        : BetaFeedbackIntelligenceCopy.summaryNo;

    final reached = <String>[];
    final stillToTest = <String>[];
    if (entries.isNotEmpty || state.hasSavedFirstMoment) {
      reached.add('First moment saved');
    } else {
      stillToTest.add('Save first moment');
    }
    if (firstProofReached) {
      reached.add('First proof reached');
    } else {
      stillToTest.add('Reach first proof');
    }
    if (state.hasSeenChatGptDifferentiation) {
      reached.add('ChatGPT difference seen');
    } else {
      stillToTest.add('See ChatGPT difference');
    }
    if (state.hasOpenedProEvidenceSheet) {
      reached.add('Pro evidence sheet opened');
    } else {
      stillToTest.add('Open Pro evidence sheet');
    }
    if (state.hasSubmittedBetaFeedback) {
      reached.add('Beta feedback submitted');
    } else {
      stillToTest.add('Submit beta feedback');
    }

    return BetaFeedbackIntelligenceSummary(
      firstProofReachedLabel: firstProofReached
          ? BetaFeedbackIntelligenceCopy.summaryYes
          : BetaFeedbackIntelligenceCopy.summaryNo,
      chatGptDifferenceLabel: chatGptLabel,
      proValueLabel: proValueLabel,
      mainConfusionLabel: mainConfusionLabel,
      strongestMomentLabel: strongestMomentLabel,
      feedbackSubmittedLabel: feedbackSubmittedLabel,
      reachedItems: reached,
      stillToTestItems: stillToTest,
      state: state,
    );
  }

  static String _chatGptLabel(BetaChatGptDifferenceAnswer? answer) {
    return switch (answer) {
      BetaChatGptDifferenceAnswer.yes =>
        BetaFeedbackIntelligenceCopy.summaryYes,
      BetaChatGptDifferenceAnswer.notSure =>
        BetaFeedbackIntelligenceCopy.summaryNotSure,
      BetaChatGptDifferenceAnswer.no => BetaFeedbackIntelligenceCopy.summaryNo,
      null => BetaFeedbackIntelligenceCopy.summaryNotYet,
    };
  }

  static String _wouldPayLabel(BetaWouldPayAnswer? answer) {
    return switch (answer) {
      BetaWouldPayAnswer.yes => BetaFeedbackIntelligenceCopy.summaryYes,
      BetaWouldPayAnswer.maybe => BetaFeedbackIntelligenceCopy.summaryMaybe,
      BetaWouldPayAnswer.no => BetaFeedbackIntelligenceCopy.summaryNo,
      null => BetaFeedbackIntelligenceCopy.summaryNotYet,
    };
  }

  static String _mainConfusionLabel(BetaMainConfusionBucket? bucket) {
    return switch (bucket) {
      BetaMainConfusionBucket.firstRecording =>
        BetaFeedbackIntelligenceCopy.confusionFirstRecording,
      BetaMainConfusionBucket.firstProof =>
        BetaFeedbackIntelligenceCopy.confusionFirstProof,
      BetaMainConfusionBucket.patterns =>
        BetaFeedbackIntelligenceCopy.confusionPatterns,
      BetaMainConfusionBucket.pro => BetaFeedbackIntelligenceCopy.confusionPro,
      BetaMainConfusionBucket.differenceFromChatGpt =>
        BetaFeedbackIntelligenceCopy.confusionDifferenceFromChatGpt,
      BetaMainConfusionBucket.nothing =>
        BetaFeedbackIntelligenceCopy.confusionNothing,
      null => BetaFeedbackIntelligenceCopy.summaryNotYet,
    };
  }

  static String _strongestMomentLabel(BetaStrongestMomentBucket? bucket) {
    return switch (bucket) {
      BetaStrongestMomentBucket.firstProof =>
        BetaFeedbackIntelligenceCopy.strongestFirstProof,
      BetaStrongestMomentBucket.whatChanged =>
        BetaFeedbackIntelligenceCopy.strongestWhatChanged,
      BetaStrongestMomentBucket.quietSignal =>
        BetaFeedbackIntelligenceCopy.strongestQuietSignal,
      BetaStrongestMomentBucket.privateReport =>
        BetaFeedbackIntelligenceCopy.strongestPrivateReport,
      BetaStrongestMomentBucket.proExplanation =>
        BetaFeedbackIntelligenceCopy.strongestProExplanation,
      BetaStrongestMomentBucket.nothingYet =>
        BetaFeedbackIntelligenceCopy.strongestNothingYet,
      null => BetaFeedbackIntelligenceCopy.summaryNotYet,
    };
  }

  static BetaFeedbackIntelligenceSurface? resolveVisibleSurface({
    required List<BetaFeedbackIntelligenceSurface> candidates,
    required int entryCount,
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
    bool isZeroEntryState = false,
    bool isRecordingState = false,
    bool isDegradedTranscriptState = false,
    bool isPostSaveDegradedState = false,
    bool firstProofTruthQuestionActive = false,
    bool whatChangedQuestionActive = false,
    bool firstProofPayoffVisible = false,
    bool proEvidenceSheetOpenedThisSession = false,
  }) {
    for (final surface in candidates) {
      final context = buildContext(
        surface: surface,
        entryCount: entryCount,
        entries: entries,
        returnChecks: returnChecks,
        isZeroEntryState: isZeroEntryState,
        isRecordingState: isRecordingState,
        isDegradedTranscriptState: isDegradedTranscriptState,
        isPostSaveDegradedState: isPostSaveDegradedState,
        firstProofTruthQuestionActive: firstProofTruthQuestionActive,
        whatChangedQuestionActive: whatChangedQuestionActive,
        firstProofPayoffVisible: firstProofPayoffVisible,
        proEvidenceSheetOpenedThisSession: proEvidenceSheetOpenedThisSession,
      );
      if (shouldShowCard(context)) return surface;
    }
    return null;
  }

  static Future<BetaFeedbackIntelligenceContext> buildContextFromJournal({
    required BetaFeedbackIntelligenceSurface surface,
    required List<JournalEntry> entries,
    bool isZeroEntryState = false,
    bool isRecordingState = false,
    bool isDegradedTranscriptState = false,
    bool isPostSaveDegradedState = false,
    bool firstProofTruthQuestionActive = false,
    bool whatChangedQuestionActive = false,
    bool firstProofPayoffVisible = false,
    bool proEvidenceSheetOpenedThisSession = false,
  }) async {
    await syncMilestones(entries: entries);
    if (AppServices.isInitialized) {
      await RepeatReturnCheckStore.ensureLoaded();
    }
    return buildContext(
      surface: surface,
      entryCount: entries.length,
      entries: entries,
      returnChecks: RepeatReturnCheckStore.cached,
      isZeroEntryState: isZeroEntryState,
      isRecordingState: isRecordingState,
      isDegradedTranscriptState: isDegradedTranscriptState,
      isPostSaveDegradedState: isPostSaveDegradedState,
      firstProofTruthQuestionActive: firstProofTruthQuestionActive,
      whatChangedQuestionActive: whatChangedQuestionActive,
      firstProofPayoffVisible: firstProofPayoffVisible,
      proEvidenceSheetOpenedThisSession: proEvidenceSheetOpenedThisSession,
    );
  }
}
