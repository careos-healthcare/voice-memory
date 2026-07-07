import '../../models/journal_entry.dart';
import '../correction_memory/correction_memory_engine.dart';
import '../archive_evidence/archive_evidence_quality_gate.dart';
import '../current_relevance/current_relevance_engine.dart';
import '../current_relevance/current_relevance_model.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../evidence_weighting/evidence_weighting_engine.dart';
import '../evidence_weighting/evidence_weighting_model.dart';
import '../pattern_match_quality/pattern_match_quality_engine.dart';
import '../pattern_match_quality/pattern_match_quality_model.dart';
import '../beta_proof_feedback/beta_proof_feedback_model.dart';
import '../beta_proof_feedback/beta_proof_feedback_store.dart';
import '../current_relevance/current_relevance_store.dart';
import '../not_relevant_recovery/not_relevant_recovery_engine.dart';
import '../pro_evidence_value/pro_evidence_value_engine.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import 'present_day_relevance_copy.dart';
import 'present_day_relevance_model.dart';

/// Builds present-day relevance from existing signals only — no new interpretation.
abstract final class PresentDayRelevanceEngine {
  PresentDayRelevanceEngine._();

  static const minEntryCount = 3;

  static PresentDayRelevanceResult? build({
    required List<JournalEntry> entries,
    required bool beliefSurfaceVisible,
    required String source,
    DateTime? now,
    EvidenceWeightingResult? evidenceWeighting,
    BetaProofFeedbackType? calibrationFeedback,
  }) {
    if (entries.length < minEntryCount) return null;

    final hasConfirmedRepeat =
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries);
    if (!hasConfirmedRepeat && !beliefSurfaceVisible) return null;
    if (!_passesEvidenceQuality(entries)) return null;

    final currentRelevance = CurrentRelevanceEngine.build(
      entries: entries,
      beliefSurfaceVisible: beliefSurfaceVisible,
    );
    final weighting = evidenceWeighting ??
        EvidenceWeightingEngine.build(
          entries: entries,
          beliefSurfaceVisible: beliefSurfaceVisible,
          now: now,
        );
    final correction = CorrectionMemoryEngine.snapshotFor(
      entries: entries,
      now: now,
    );
    final relevanceState = _applyAnchorCalibrationToState(
      state: CorrectionMemoryEngine.presentDayStateFor(
        correction: correction,
        fallback: _resolveState(
          currentRelevance: currentRelevance,
          evidenceWeighting: weighting,
        ),
      ),
      calibrationFeedback: calibrationFeedback ??
          _resolveCalibrationFeedback(entries: entries),
      hasFreshReturn: correction?.returnedAfterFaded == true,
    );
    final patternMatchQuality = weighting?.patternMatchQuality ??
        PatternMatchQualityEngine.build(
          entries: entries,
          beliefSurfaceVisible: beliefSurfaceVisible,
          source: source,
          now: now,
          evidenceWeighting: weighting,
          correction: correction,
        );
    final adjustedState = _applyPatternQualityToState(
      state: relevanceState,
      evidenceWeighting: weighting,
      entries: entries,
      beliefSurfaceVisible: beliefSurfaceVisible,
      now: now,
    );
    final stateBody = CorrectionMemoryEngine.presentDayStateBodyFor(
      correction: correction,
      state: adjustedState,
      fallback: PresentDayRelevanceCopy.stateBodyFor(adjustedState),
    );

    return PresentDayRelevanceResult(
      shouldShow: true,
      entryCount: entries.length,
      source: source,
      hasConfirmedRepeat: hasConfirmedRepeat,
      hasBeliefSurface: beliefSurfaceVisible,
      relevanceState: adjustedState,
      title: PresentDayRelevanceCopy.title,
      body: PresentDayRelevanceCopy.primaryBody,
      stateBody: stateBody,
      footer: PresentDayRelevanceCopy.footer,
      differentiationLine: PresentDayRelevanceCopy.differentiationLine,
      patternMatchQuality: patternMatchQuality,
    );
  }

  static PresentDayRelevanceState _applyPatternQualityToState({
    required PresentDayRelevanceState state,
    required EvidenceWeightingResult? evidenceWeighting,
    required List<JournalEntry> entries,
    required bool beliefSurfaceVisible,
    DateTime? now,
  }) {
    if (evidenceWeighting == null) return state;

    final patternQuality = evidenceWeighting.patternMatchQuality ??
        PatternMatchQualityEngine.build(
          entries: entries,
          beliefSurfaceVisible: beliefSurfaceVisible,
          source: 'present_day_relevance',
          now: now,
          evidenceWeighting: evidenceWeighting,
        );
    if (!patternQuality.shouldResolve) return state;
    if (patternQuality.weakReasons
        .contains(PatternMatchWeakReason.userMarkedNotRelevant)) {
      return PresentDayRelevanceState.fading;
    }
    if (patternQuality.shouldShowAsWatchOnly &&
        state == PresentDayRelevanceState.current) {
      return PresentDayRelevanceState.fading;
    }
    return state;
  }

  static PresentDayRelevanceState _applyAnchorCalibrationToState({
    required PresentDayRelevanceState state,
    required BetaProofFeedbackType? calibrationFeedback,
    required bool hasFreshReturn,
  }) {
    if (calibrationFeedback == BetaProofFeedbackType.notRelevant &&
        !hasFreshReturn) {
      return PresentDayRelevanceState.fading;
    }
    return state;
  }

  static BetaProofFeedbackType? _resolveCalibrationFeedback({
    required List<JournalEntry> entries,
  }) {
    final proofKey = CurrentRelevanceStore.proofKeyFor(entries);
    if (proofKey.isNotEmpty &&
        NotRelevantRecoveryEngine.hasNotRelevantTrigger(proofKey: proofKey)) {
      return BetaProofFeedbackType.notRelevant;
    }
    for (final surface in BetaProofFeedbackSurface.values) {
      final record = BetaProofFeedbackStore.recordFor(surface);
      if (record.answered && record.feedbackType != null) {
        return record.feedbackType;
      }
    }
    return null;
  }

  static bool shouldShow({
    required PresentDayRelevanceResult? result,
    required bool isZeroEntryState,
    required bool isFirstRecordingState,
    required bool isDegradedTranscriptState,
    required bool isPostSaveDegradedState,
    required bool firstProofPayoffVisible,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) {
    if (result == null || !result.shouldShow) return false;
    if (isZeroEntryState) return false;
    if (isFirstRecordingState) return false;
    if (isDegradedTranscriptState) return false;
    if (isPostSaveDegradedState) return false;
    if (firstProofPayoffVisible) return false;
    if (whatChangedQuestionActive) return false;
    if (patternReviewInboxHasActiveItems) return false;
    return true;
  }

  static bool shouldShowOnRecordReady({
    required PresentDayRelevanceResult? result,
    required bool isZeroEntryState,
    required bool isFirstRecordingState,
    required bool isDegradedTranscriptState,
    required bool isPostSaveDegradedState,
    required bool firstProofPayoffVisible,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) =>
      shouldShow(
        result: result,
        isZeroEntryState: isZeroEntryState,
        isFirstRecordingState: isFirstRecordingState,
        isDegradedTranscriptState: isDegradedTranscriptState,
        isPostSaveDegradedState: isPostSaveDegradedState,
        firstProofPayoffVisible: firstProofPayoffVisible,
        whatChangedQuestionActive: whatChangedQuestionActive,
        patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
      );

  static bool shouldShowOnPatterns({
    required PresentDayRelevanceResult? result,
    required bool isZeroEntryState,
    required bool isFirstRecordingState,
    required bool isDegradedTranscriptState,
    required bool isPostSaveDegradedState,
    required bool firstProofPayoffVisible,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) =>
      shouldShow(
        result: result,
        isZeroEntryState: isZeroEntryState,
        isFirstRecordingState: isFirstRecordingState,
        isDegradedTranscriptState: isDegradedTranscriptState,
        isPostSaveDegradedState: isPostSaveDegradedState,
        firstProofPayoffVisible: firstProofPayoffVisible,
        whatChangedQuestionActive: whatChangedQuestionActive,
        patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
      );

  static bool patternReviewInboxHasActiveItems({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
  }) =>
      ProEvidenceValueEngine.patternReviewInboxHasActiveItems(
        entries: entries,
        returnChecks: returnChecks,
      );

  static PresentDayRelevanceState _resolveState({
    required CurrentRelevanceState? currentRelevance,
    required EvidenceWeightingResult? evidenceWeighting,
  }) {
    final answer = currentRelevance?.answer;
    if (answer == CurrentRelevanceAnswer.notReally) {
      return PresentDayRelevanceState.fading;
    }
    if (answer == CurrentRelevanceAnswer.notSure) {
      return PresentDayRelevanceState.unclear;
    }
    if (answer == CurrentRelevanceAnswer.yes ||
        answer == CurrentRelevanceAnswer.little) {
      return PresentDayRelevanceState.current;
    }

    if (evidenceWeighting == null) {
      return PresentDayRelevanceState.unclear;
    }

    if (evidenceWeighting.hasSofteningSignal ||
        evidenceWeighting.primaryState == EvidenceWeightState.softened ||
        evidenceWeighting.secondaryStates.contains(EvidenceWeightState.softened)) {
      return PresentDayRelevanceState.softened;
    }

    if (evidenceWeighting.primaryState == EvidenceWeightState.repeated ||
        evidenceWeighting.primaryState == EvidenceWeightState.fresh ||
        (evidenceWeighting.hasRecentEntry &&
            evidenceWeighting.hasConfirmedRepeat)) {
      return PresentDayRelevanceState.current;
    }

    if (evidenceWeighting.primaryState == EvidenceWeightState.oldSignal ||
        evidenceWeighting.primaryState == EvidenceWeightState.needsFreshProof ||
        evidenceWeighting.hasQuietSignal ||
        evidenceWeighting.secondaryStates.contains(EvidenceWeightState.fading) ||
        evidenceWeighting.secondaryStates.contains(EvidenceWeightState.oldSignal) ||
        evidenceWeighting.secondaryStates
            .contains(EvidenceWeightState.needsFreshProof) ||
        (evidenceWeighting.hasOlderEntry && !evidenceWeighting.hasRecentEntry)) {
      return PresentDayRelevanceState.fading;
    }

    return PresentDayRelevanceState.unclear;
  }

  static bool _passesEvidenceQuality(List<JournalEntry> entries) {
    if (!ArchiveEvidenceQualityGate.allowsBeliefSurfaces(entries)) {
      return false;
    }
    if (ArchiveEvidenceQualityGate.showsGenericTestEvidenceFallback(entries)) {
      return false;
    }
    if (ArchiveEvidenceQualityGate.showsPendingTranscriptFallback(entries)) {
      return false;
    }
    return true;
  }
}
