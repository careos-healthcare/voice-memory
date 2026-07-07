import '../../models/journal_entry.dart';
import '../correction_memory/correction_memory_engine.dart';
import '../archive_evidence/archive_evidence_quality_gate.dart';
import '../current_relevance/current_relevance_engine.dart';
import '../current_relevance/current_relevance_model.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../evidence_weighting/evidence_weighting_engine.dart';
import '../evidence_weighting/evidence_weighting_model.dart';
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
    final evidenceWeighting = EvidenceWeightingEngine.build(
      entries: entries,
      beliefSurfaceVisible: beliefSurfaceVisible,
      now: now,
    );
    final correction = CorrectionMemoryEngine.snapshotFor(
      entries: entries,
      now: now,
    );
    final relevanceState = CorrectionMemoryEngine.presentDayStateFor(
      correction: correction,
      fallback: _resolveState(
        currentRelevance: currentRelevance,
        evidenceWeighting: evidenceWeighting,
      ),
    );
    final stateBody = CorrectionMemoryEngine.presentDayStateBodyFor(
      correction: correction,
      state: relevanceState,
      fallback: PresentDayRelevanceCopy.stateBodyFor(relevanceState),
    );

    return PresentDayRelevanceResult(
      shouldShow: true,
      entryCount: entries.length,
      source: source,
      hasConfirmedRepeat: hasConfirmedRepeat,
      hasBeliefSurface: beliefSurfaceVisible,
      relevanceState: relevanceState,
      title: PresentDayRelevanceCopy.title,
      body: PresentDayRelevanceCopy.primaryBody,
      stateBody: stateBody,
      footer: PresentDayRelevanceCopy.footer,
      differentiationLine: PresentDayRelevanceCopy.differentiationLine,
    );
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
