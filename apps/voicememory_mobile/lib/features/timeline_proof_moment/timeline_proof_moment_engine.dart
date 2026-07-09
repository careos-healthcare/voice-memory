import '../../models/journal_entry.dart';
import '../archive_timeline_spine/archive_timeline_spine_engine.dart';
import '../archive_timeline_spine/archive_timeline_spine_model.dart';
import '../correction_memory/correction_memory_engine.dart';
import '../evidence_anchors/evidence_anchor_model.dart';
import '../pattern_match_quality/pattern_match_quality_model.dart';
import '../evidence_anchors/evidence_anchor_copy.dart';
import '../evidence_anchors/evidence_anchor_engine.dart';
import '../evidence_weighting/evidence_weighting_engine.dart';
import '../pattern_match_quality/pattern_match_quality_engine.dart';
import '../beta_proof_feedback/beta_proof_feedback_model.dart';
import '../beta_proof_feedback/beta_proof_feedback_store.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_analytics.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_engine.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_model.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import '../revenue_lift_experiment_v2/revenue_lift_experiment_v2_engine.dart';
import 'timeline_proof_moment_copy.dart';
import 'timeline_proof_moment_model.dart';

/// Compresses archive timeline spine into one concise proof moment.
abstract final class TimelineProofMomentEngine {
  TimelineProofMomentEngine._();

  static const minMeaningfulSpineRows = 2;

  static TimelineProofMomentResult? build({
    required List<JournalEntry> entries,
    required bool beliefSurfaceVisible,
    required String source,
    bool compact = false,
    DateTime? now,
  }) {
    final spine = ArchiveTimelineSpineEngine.build(
      entries: entries,
      beliefSurfaceVisible: beliefSurfaceVisible,
      source: source,
      now: now,
    );
    return buildFromSpine(
      spine: spine,
      entries: entries,
      source: source,
      compact: compact,
      now: now,
    );
  }

  static TimelineProofMomentResult? buildFromSpine({
    required ArchiveTimelineSpineResult? spine,
    required List<JournalEntry> entries,
    required String source,
    bool compact = false,
    DateTime? now,
  }) {
    if (spine == null || !spine.shouldShow) return null;
    if (spine.rowCount < minMeaningfulSpineRows) return null;

    final correction = CorrectionMemoryEngine.snapshotFor(
      entries: entries,
      now: now,
    );
    final anchorExtraction = EvidenceAnchorEngine.build(
      entries: entries,
      beliefSurfaceVisible: spine.hasConfirmedRepeat || spine.hasCorrection,
      source: source,
      now: now,
    );
    final anchorByType = {
      for (final anchor in anchorExtraction.anchors) anchor.type: anchor,
    };
    final rows = <TimelineProofMomentRow>[
      TimelineProofMomentRow(
        label: TimelineProofMomentCopy.firstSeenRow,
        detail: anchorExtraction.hasSafeAnchor
            ? null
            : EvidenceAnchorCopy.fallbackSummary,
      ),
      if (spine.hasConfirmedRepeat)
        TimelineProofMomentRow(
          label: TimelineProofMomentCopy.returnedRow,
          detail: anchorByType[EvidenceAnchorType.repeat]?.safeSummary ??
              (spine.evidenceAnchors.isNotEmpty
                  ? spine.evidenceAnchors.first
                  : null),
          anchorType: anchorByType[EvidenceAnchorType.repeat]?.type ??
              EvidenceAnchorType.repeat,
        ),
      if (spine.hasCorrection && correction != null)
        TimelineProofMomentRow(
          label: TimelineProofMomentCopy.correctedRowFor(
            TimelineProofMomentCopy.correctionLabelFor(
              state: correction.state,
              returnedAfterFaded: correction.returnedAfterFaded,
            ),
          ),
          detail: anchorByType[EvidenceAnchorType.corrected]?.safeSummary ??
              anchorByType[EvidenceAnchorType.freshReturn]?.safeSummary,
          anchorType: correction.returnedAfterFaded
              ? EvidenceAnchorType.freshReturn
              : EvidenceAnchorType.corrected,
        ),
      TimelineProofMomentRow(
        label: TimelineProofMomentCopy.currentWeightRow,
        detail: anchorByType[EvidenceAnchorType.current]?.safeSummary ??
            anchorByType[EvidenceAnchorType.fading]?.safeSummary,
        anchorType: anchorByType[EvidenceAnchorType.current]?.type ??
            anchorByType[EvidenceAnchorType.fading]?.type,
      ),
    ];

    final patternMatchQuality = spine.patternMatchQuality;
    final evidenceWeighting = EvidenceWeightingEngine.build(
      entries: entries,
      beliefSurfaceVisible: spine.hasConfirmedRepeat || spine.hasCorrection,
      now: now,
    );
    final calibrationFeedback =
        BetaProofFeedbackStore.recordFor(
          BetaProofFeedbackSurface.timelineProofMoment,
        ).feedbackType;
    final proofConfidenceCalibration = ProofConfidenceCalibrationEngine.build(
      entries: entries,
      beliefSurfaceVisible: spine.hasConfirmedRepeat || spine.hasCorrection,
      source: source,
      patternMatchQuality: patternMatchQuality,
      anchorExtraction: anchorExtraction,
      evidenceWeighting: evidenceWeighting,
      correction: correction,
      calibrationFeedback: calibrationFeedback,
      now: now,
      trackAnalytics: true,
    );

    final sharpenedPayoff = RevenueLiftExperimentV2Engine.proofPayoffCopyFor(
      level: proofConfidenceCalibration.level,
    );

    final shouldShow = ProofConfidenceCalibrationEngine.shouldShowUsefulProofSurface(
      calibration: proofConfidenceCalibration,
      hasSafeAnchor: anchorExtraction.hasSafeAnchor,
    );

    return TimelineProofMomentResult(
      shouldShow: shouldShow,
      entryCount: spine.entryCount,
      source: source,
      hasConfirmedRepeat: spine.hasConfirmedRepeat,
      hasCorrection: spine.hasCorrection,
      currentWeight: spine.currentWeight,
      rowCount: rows.length,
      title: sharpenedPayoff?.title ??
          _titleFor(proofConfidenceCalibration, compact: compact),
      body: sharpenedPayoff?.body ?? proofConfidenceCalibration.displayCopy,
      rows: rows,
      currentWeightLine:
          TimelineProofMomentCopy.currentWeightLineFor(spine.currentWeight),
      footer: TimelineProofMomentCopy.footer,
      differentiationLine: TimelineProofMomentCopy.differentiationLine,
      proLine: TimelineProofMomentCopy.proLine,
      compact: compact,
      evidenceAnchors: anchorExtraction.safeSummaries,
      hasSafeAnchor: anchorExtraction.hasSafeAnchor,
      usesFallbackEvidenceLine: anchorExtraction.usesFallback,
      patternMatchQuality: patternMatchQuality,
      proofConfidenceCalibration: proofConfidenceCalibration,
    );
  }

  static String _titleFor(
    ProofConfidenceCalibrationResult calibration, {
    required bool compact,
  }) {
    if (compact) return TimelineProofMomentCopy.compactTitle;
    return switch (calibration.level) {
      ProofConfidenceLevel.strong ||
      ProofConfidenceLevel.useful ||
      ProofConfidenceLevel.freshReturn =>
        TimelineProofMomentCopy.title,
      _ => TimelineProofMomentCopy.compactTitle,
    };
  }

  static bool shouldShow({
    required TimelineProofMomentResult? result,
    required bool isDegradedTranscriptState,
    required bool isPostSaveDegradedState,
    required bool firstProofPayoffVisible,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
    required bool isRecording,
    bool allowDuringFirstProofPayoff = false,
  }) {
    if (result == null || !result.shouldShow) return false;
    if (isRecording) return false;
    if (isDegradedTranscriptState) return false;
    if (isPostSaveDegradedState) return false;
    if (whatChangedQuestionActive) return false;
    if (patternReviewInboxHasActiveItems) return false;
    if (firstProofPayoffVisible && !allowDuringFirstProofPayoff) return false;
    return true;
  }

  static bool shouldShowOnPatterns({
    required TimelineProofMomentResult? result,
    required bool timelineSpineVisible,
    required bool isDegradedTranscriptState,
    required bool isPostSaveDegradedState,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) =>
      timelineSpineVisible &&
      shouldShow(
        result: result,
        isDegradedTranscriptState: isDegradedTranscriptState,
        isPostSaveDegradedState: isPostSaveDegradedState,
        firstProofPayoffVisible: false,
        whatChangedQuestionActive: whatChangedQuestionActive,
        patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
        isRecording: false,
      );

  static bool shouldShowOnRecordReady({
    required TimelineProofMomentResult? result,
    required bool isDegradedTranscriptState,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) {
    if (result == null || !result.hasConfirmedRepeat) return false;
    return shouldShow(
      result: result,
      isDegradedTranscriptState: isDegradedTranscriptState,
      isPostSaveDegradedState: false,
      firstProofPayoffVisible: false,
      whatChangedQuestionActive: whatChangedQuestionActive,
      patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
      isRecording: false,
    );
  }

  static bool shouldShowOnFirstProofPayoffPostSave({
    required TimelineProofMomentResult? result,
    required bool showFirstProofPayoff,
    required bool isDegradedPostSave,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) =>
      showFirstProofPayoff &&
      shouldShow(
        result: result,
        isDegradedTranscriptState: isDegradedPostSave,
        isPostSaveDegradedState: isDegradedPostSave,
        firstProofPayoffVisible: true,
        whatChangedQuestionActive: whatChangedQuestionActive,
        patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
        isRecording: false,
        allowDuringFirstProofPayoff: true,
      );

  static bool patternReviewInboxHasActiveItems({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
  }) =>
      ArchiveTimelineSpineEngine.patternReviewInboxHasActiveItems(
        entries: entries,
        returnChecks: returnChecks,
      );
}
