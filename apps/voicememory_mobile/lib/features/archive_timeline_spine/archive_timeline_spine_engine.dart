import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_evidence/archive_evidence_quality_gate.dart';
import '../correction_memory/correction_memory_engine.dart';
import '../correction_memory/correction_memory_model.dart';
import '../current_relevance/current_relevance_engine.dart';
import '../current_relevance/current_relevance_model.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../evidence_weighting/evidence_weighting_engine.dart';
import '../evidence_weighting/evidence_weighting_model.dart';
import '../present_day_relevance/present_day_relevance_engine.dart';
import '../present_day_relevance/present_day_relevance_model.dart';
import '../pro_evidence_value/pro_evidence_value_engine.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import 'archive_timeline_spine_copy.dart';
import 'archive_timeline_spine_model.dart';

/// Composes existing archive signals into one timeline spine — no new proof logic.
abstract final class ArchiveTimelineSpineEngine {
  ArchiveTimelineSpineEngine._();

  static const minEntryCount = 3;

  static ArchiveTimelineSpineResult? build({
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

    final eligibleCount = ArchiveEvidenceGuard.eligibleEntries(entries).length;
    if (eligibleCount < 1) return null;

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
    final presentDayRelevance = PresentDayRelevanceEngine.build(
      entries: entries,
      beliefSurfaceVisible: beliefSurfaceVisible,
      source: source,
      now: now,
    );

    final stillCurrent = _isStillCurrent(
      currentRelevance: currentRelevance,
      correction: correction,
      presentDayState: presentDayRelevance?.relevanceState,
    );
    final weightChanged = _hasWeightChanged(
      correction: correction,
      evidenceWeighting: evidenceWeighting,
      presentDayState: presentDayRelevance?.relevanceState,
    );
    final needsFreshProof = _needsFreshProof(
      evidenceWeighting: evidenceWeighting,
      hasConfirmedRepeat: hasConfirmedRepeat,
    );
    final hasCorrection = correction != null;

    final rows = <ArchiveTimelineSpineRow>[
      if (eligibleCount >= 1)
        _row(ArchiveTimelineSpineRowId.firstSeen),
      if (hasConfirmedRepeat) _row(ArchiveTimelineSpineRowId.returned),
      if (stillCurrent) _row(ArchiveTimelineSpineRowId.stillCurrent),
      if (hasCorrection) _row(ArchiveTimelineSpineRowId.correctedByYou),
      if (weightChanged) _row(ArchiveTimelineSpineRowId.weightChanged),
      if (needsFreshProof) _row(ArchiveTimelineSpineRowId.needsFreshProof),
    ];

    if (rows.isEmpty) return null;

    final currentWeight = _resolveCurrentWeight(
      correction: correction,
      presentDayState: presentDayRelevance?.relevanceState,
      evidenceWeighting: evidenceWeighting,
      hasConfirmedRepeat: hasConfirmedRepeat,
      needsFreshProof: needsFreshProof,
    );

    return ArchiveTimelineSpineResult(
      shouldShow: true,
      entryCount: entries.length,
      source: source,
      hasConfirmedRepeat: hasConfirmedRepeat,
      hasCorrection: hasCorrection,
      currentWeight: currentWeight,
      rows: rows,
      title: ArchiveTimelineSpineCopy.title,
      subtitle: ArchiveTimelineSpineCopy.subtitle,
      explanation: ArchiveTimelineSpineCopy.explanation,
      currentWeightLabel:
          ArchiveTimelineSpineCopy.currentWeightLabelFor(currentWeight),
      footer: ArchiveTimelineSpineCopy.footer,
      differentiationLine: ArchiveTimelineSpineCopy.differentiationLine,
      proBridgeCopy: ArchiveTimelineSpineCopy.proBridgeCopy,
    );
  }

  static bool shouldShow({
    required ArchiveTimelineSpineResult? result,
    required bool isDegradedTranscriptState,
    required bool isPostSaveDegradedState,
    required bool firstProofPayoffVisible,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
    required bool isRecording,
  }) {
    if (result == null || !result.shouldShow) return false;
    if (isRecording) return false;
    if (isDegradedTranscriptState) return false;
    if (isPostSaveDegradedState) return false;
    if (firstProofPayoffVisible) return false;
    if (whatChangedQuestionActive) return false;
    if (patternReviewInboxHasActiveItems) return false;
    return true;
  }

  static bool shouldShowOnPatterns({
    required ArchiveTimelineSpineResult? result,
    required bool isDegradedTranscriptState,
    required bool isPostSaveDegradedState,
    required bool firstProofPayoffVisible,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) =>
      shouldShow(
        result: result,
        isDegradedTranscriptState: isDegradedTranscriptState,
        isPostSaveDegradedState: isPostSaveDegradedState,
        firstProofPayoffVisible: firstProofPayoffVisible,
        whatChangedQuestionActive: whatChangedQuestionActive,
        patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
        isRecording: false,
      );

  static bool shouldShowOnRecordReady({
    required ArchiveTimelineSpineResult? result,
    required bool isDegradedTranscriptState,
    required bool isPostSaveDegradedState,
    required bool firstProofPayoffVisible,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) =>
      shouldShow(
        result: result,
        isDegradedTranscriptState: isDegradedTranscriptState,
        isPostSaveDegradedState: isPostSaveDegradedState,
        firstProofPayoffVisible: firstProofPayoffVisible,
        whatChangedQuestionActive: whatChangedQuestionActive,
        patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
        isRecording: false,
      );

  static bool suppressLegacyEducationCards({
    required ArchiveTimelineSpineResult? result,
    required bool visible,
  }) =>
      visible && result != null && result.shouldShow;

  static bool patternReviewInboxHasActiveItems({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
  }) =>
      ProEvidenceValueEngine.patternReviewInboxHasActiveItems(
        entries: entries,
        returnChecks: returnChecks,
      );

  static ArchiveTimelineSpineRow _row(ArchiveTimelineSpineRowId id) =>
      ArchiveTimelineSpineRow(
        id: id,
        label: ArchiveTimelineSpineCopy.labelFor(id),
        detail: ArchiveTimelineSpineCopy.detailFor(id),
      );

  static bool _isStillCurrent({
    required CurrentRelevanceState? currentRelevance,
    required CorrectionMemorySnapshot? correction,
    required PresentDayRelevanceState? presentDayState,
  }) {
    if (correction?.returnedAfterFaded == true) return true;
    if (correction?.state == CorrectionMemoryState.stillCurrent ||
        correction?.state == CorrectionMemoryState.partlyCurrent) {
      return true;
    }

    final answer = currentRelevance?.answer;
    if (answer == CurrentRelevanceAnswer.yes ||
        answer == CurrentRelevanceAnswer.little) {
      return true;
    }

    return presentDayState == PresentDayRelevanceState.current ||
        presentDayState == PresentDayRelevanceState.softened;
  }

  static bool _hasWeightChanged({
    required CorrectionMemorySnapshot? correction,
    required EvidenceWeightingResult? evidenceWeighting,
    required PresentDayRelevanceState? presentDayState,
  }) {
    if (correction?.returnedAfterFaded == true ||
        correction?.state == CorrectionMemoryState.partlyCurrent) {
      return true;
    }

    if (presentDayState == PresentDayRelevanceState.softened ||
        presentDayState == PresentDayRelevanceState.fading) {
      return true;
    }

    if (evidenceWeighting == null) return false;

    if (evidenceWeighting.hasSofteningSignal ||
        evidenceWeighting.hasQuietSignal) {
      return true;
    }

    for (final state in evidenceWeighting.displayStates) {
      if (state == EvidenceWeightState.fading ||
          state == EvidenceWeightState.softened ||
          state == EvidenceWeightState.oldSignal ||
          state == EvidenceWeightState.needsFreshProof) {
        return true;
      }
    }

    return false;
  }

  static bool _needsFreshProof({
    required EvidenceWeightingResult? evidenceWeighting,
    required bool hasConfirmedRepeat,
  }) {
    if (evidenceWeighting == null) return false;
    if (evidenceWeighting.primaryState == EvidenceWeightState.needsFreshProof) {
      return true;
    }
    return hasConfirmedRepeat &&
        evidenceWeighting.hasOlderEntry &&
        !evidenceWeighting.hasRecentEntry;
  }

  static ArchiveTimelineSpineCurrentWeight _resolveCurrentWeight({
    required CorrectionMemorySnapshot? correction,
    required PresentDayRelevanceState? presentDayState,
    required EvidenceWeightingResult? evidenceWeighting,
    required bool hasConfirmedRepeat,
    required bool needsFreshProof,
  }) {
    if (needsFreshProof) {
      return ArchiveTimelineSpineCurrentWeight.needsFreshProof;
    }
    if (correction != null && !correction.returnedAfterFaded) {
      return ArchiveTimelineSpineCurrentWeight.corrected;
    }
    if (presentDayState == PresentDayRelevanceState.fading ||
        evidenceWeighting?.hasQuietSignal == true ||
        evidenceWeighting?.primaryState == EvidenceWeightState.oldSignal ||
        evidenceWeighting?.displayStates
                .contains(EvidenceWeightState.fading) ==
            true) {
      return ArchiveTimelineSpineCurrentWeight.fading;
    }
    if (presentDayState == PresentDayRelevanceState.current &&
        hasConfirmedRepeat &&
        evidenceWeighting?.hasRecentEntry == true) {
      return ArchiveTimelineSpineCurrentWeight.strong;
    }
    return ArchiveTimelineSpineCurrentWeight.light;
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
