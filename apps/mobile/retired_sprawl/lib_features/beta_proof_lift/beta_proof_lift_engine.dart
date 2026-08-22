import 'package:archiveme_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:archiveme_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:archiveme_mobile/features/beta_proof_feedback/beta_proof_feedback_store.dart';
import 'package:archiveme_mobile/features/beta_proof_lift/beta_proof_lift_copy.dart';
import 'package:archiveme_mobile/features/beta_proof_lift/beta_proof_lift_model.dart';
import 'package:archiveme_mobile/features/correction_memory/correction_memory_engine.dart';
import 'package:archiveme_mobile/features/correction_memory/correction_memory_model.dart';
import 'package:archiveme_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:archiveme_mobile/features/evidence_anchors/evidence_anchor_engine.dart';
import 'package:archiveme_mobile/features/evidence_anchors/evidence_anchor_model.dart';
import 'package:archiveme_mobile/features/evidence_weighting/evidence_weighting_engine.dart';
import 'package:archiveme_mobile/features/evidence_weighting/evidence_weighting_model.dart';
import 'package:archiveme_mobile/features/pattern_match_quality/pattern_match_quality_engine.dart';
import 'package:archiveme_mobile/features/present_day_relevance/present_day_relevance_engine.dart';
import 'package:archiveme_mobile/features/present_day_relevance/present_day_relevance_model.dart';
import 'package:archiveme_mobile/features/proof_confidence_calibration/proof_confidence_calibration_copy.dart';
import 'package:archiveme_mobile/features/proof_confidence_calibration/proof_confidence_calibration_engine.dart';
import 'package:archiveme_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:archiveme_mobile/features/proof_quality_response/proof_quality_response_engine.dart';
import 'package:archiveme_mobile/features/proof_quality_response/proof_quality_response_model.dart';
import 'package:archiveme_mobile/features/revenue_lift_experiment_v2/revenue_lift_experiment_v2_engine.dart';
import 'package:archiveme_mobile/features/timeline_proof_moment/timeline_proof_moment_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Builds sharper proof explanations from existing safe signals only.
abstract final class BetaProofLiftEngine {
  BetaProofLiftEngine._();

  static BetaProofLiftResult build({
    required List<JournalEntry> entries,
    required BetaProofLiftSurface surface,
    required String source,
    required bool beliefSurfaceVisible,
    List<String> beliefEvidencePhrases = const [],
    TimelineProofMomentResult? timelineProof,
    DateTime? now,
  }) {
    final anchorExtraction = EvidenceAnchorEngine.build(
      entries: entries,
      beliefSurfaceVisible: beliefSurfaceVisible,
      source: source,
      beliefEvidencePhrases: beliefEvidencePhrases,
      now: now,
    );
    final evidenceWeighting = EvidenceWeightingEngine.build(
      entries: entries,
      beliefSurfaceVisible: beliefSurfaceVisible,
      now: now,
    );
    final presentDay = PresentDayRelevanceEngine.build(
      entries: entries,
      beliefSurfaceVisible: beliefSurfaceVisible,
      source: source,
      now: now,
    );
    final correction = CorrectionMemoryEngine.snapshotFor(
      entries: entries,
      now: now,
    );
    final patternMatchQuality =
        evidenceWeighting?.patternMatchQuality ??
        PatternMatchQualityEngine.build(
          entries: entries,
          beliefSurfaceVisible: beliefSurfaceVisible,
          source: source,
          beliefEvidencePhrases: beliefEvidencePhrases,
          now: now,
          evidenceWeighting: evidenceWeighting,
          correction: correction,
        );
    final calibrationFeedback = BetaProofFeedbackStore.recordFor(
      betaSurfaceFor(surface),
    ).feedbackType;
    final proofConfidenceCalibration = ProofConfidenceCalibrationEngine.build(
      entries: entries,
      beliefSurfaceVisible: beliefSurfaceVisible,
      source: source,
      patternMatchQuality: patternMatchQuality,
      anchorExtraction: anchorExtraction,
      evidenceWeighting: evidenceWeighting,
      correction: correction,
      calibrationFeedback: calibrationFeedback,
      now: now,
      trackAnalytics: true,
    );

    final hasSafeAnchor = proofConfidenceCalibration.hasSafeAnchor;
    final hasCorrection = correction != null;
    final hasCurrentRelevance = presentDay != null;
    final deltaRows = _resolveDeltaRows(
      anchorExtraction: anchorExtraction,
      evidenceWeighting: evidenceWeighting,
      presentDay: presentDay,
      correction: correction,
      timelineProof: timelineProof,
      hasConfirmedRepeat: EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
        entries,
      ),
    );

    final sections = [
      BetaProofLiftSection(
        heading: BetaProofLiftCopy.sectionWhatRepeated,
        body: _whatRepeatedBody(
          anchorExtraction: anchorExtraction,
          proofConfidenceCalibration: proofConfidenceCalibration,
          hasConfirmedRepeat:
              EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries),
          timelineProof: timelineProof,
        ),
      ),
      BetaProofLiftSection(
        heading: BetaProofLiftCopy.sectionWhatChanged,
        body: _whatChangedBody(evidenceWeighting: evidenceWeighting),
      ),
      BetaProofLiftSection(
        heading: BetaProofLiftCopy.sectionWhyItMattersNow,
        body: _whyItMattersNowBody(presentDay: presentDay),
      ),
      const BetaProofLiftSection(
        heading: BetaProofLiftCopy.sectionYourCorrection,
        body: BetaProofLiftCopy.fallbackYourCorrection,
      ),
    ];

    final sharpenedPayoff = RevenueLiftExperimentV2Engine.proofPayoffCopyFor(
      level: proofConfidenceCalibration.level,
    );

    final shouldShow =
        ProofConfidenceCalibrationEngine.shouldShowUsefulProofSurface(
          calibration: proofConfidenceCalibration,
          hasSafeAnchor: hasSafeAnchor,
        );

    return BetaProofLiftResult(
      shouldShow: shouldShow,
      entryCount: entries.length,
      source: source,
      surface: surface,
      title: sharpenedPayoff?.title ?? BetaProofLiftCopy.title,
      body:
          sharpenedPayoff?.body ??
          (proofConfidenceCalibration.isWatchOnly
              ? ProofConfidenceCalibrationCopy.watchOnlySubtitle
              : proofConfidenceCalibration.displayCopy),
      sections: sections,
      deltaRows: deltaRows,
      hasSafeAnchor: hasSafeAnchor,
      hasDelta: deltaRows.isNotEmpty,
      hasCurrentRelevance: hasCurrentRelevance,
      hasCorrection: hasCorrection,
      patternMatchQuality: patternMatchQuality,
      proofConfidenceCalibration: proofConfidenceCalibration,
    );
  }

  static bool shouldShow({
    required BetaProofLiftResult result,
    required bool parentVisible,
    required bool timelineProofVisible,
    required bool firstProofPayoffVisible,
    required bool isRecording,
    required bool isDegradedTranscriptState,
    required bool isPostSaveDegradedState,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) {
    if (!ArchiveBetaMissionGate.isEnabled) return false;
    if (!result.shouldShow) return false;
    if (!result.hasSafeAnchor ||
        !result.proofConfidenceCalibration.isProofLevel ||
        result.proofConfidenceCalibration.isWatchOnly) {
      return false;
    }
    if (!parentVisible) return false;
    if (isRecording) return false;
    if (isDegradedTranscriptState) return false;
    if (isPostSaveDegradedState) return false;
    if (whatChangedQuestionActive) return false;
    if (patternReviewInboxHasActiveItems) return false;
    if (!_meetsEntryThreshold(
      entryCount: result.entryCount,
      firstProofPayoffVisible: firstProofPayoffVisible,
    )) {
      return false;
    }
    if (!timelineProofVisible && !firstProofPayoffVisible) return false;
    if (_hasFeedbackToday(result.surface)) return false;
    return true;
  }

  static bool shouldRender({
    required BetaProofLiftResult result,
    required ProofQualityResponseResult qualityResponse,
    required bool parentVisible,
    required bool timelineProofVisible,
    required bool firstProofPayoffVisible,
    required bool isRecording,
    required bool isDegradedTranscriptState,
    required bool isPostSaveDegradedState,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) {
    if (ProofQualityResponseEngine.shouldRender(
      result: qualityResponse,
      parentVisible: parentVisible,
      timelineProofVisible: timelineProofVisible,
      firstProofPayoffVisible: firstProofPayoffVisible,
      isRecording: isRecording,
      isDegradedTranscriptState: isDegradedTranscriptState,
      isPostSaveDegradedState: isPostSaveDegradedState,
      whatChangedQuestionActive: whatChangedQuestionActive,
      patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
    )) {
      return false;
    }
    return shouldShow(
      result: result,
      parentVisible: parentVisible,
      timelineProofVisible: timelineProofVisible,
      firstProofPayoffVisible: firstProofPayoffVisible,
      isRecording: isRecording,
      isDegradedTranscriptState: isDegradedTranscriptState,
      isPostSaveDegradedState: isPostSaveDegradedState,
      whatChangedQuestionActive: whatChangedQuestionActive,
      patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
    );
  }

  static bool coversLegacyBoost({
    required BetaProofLiftResult result,
    required bool parentVisible,
    required bool timelineProofVisible,
    required bool firstProofPayoffVisible,
    required bool isRecording,
    required bool isDegradedTranscriptState,
    required bool isPostSaveDegradedState,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) => shouldShow(
    result: result,
    parentVisible: parentVisible,
    timelineProofVisible: timelineProofVisible,
    firstProofPayoffVisible: firstProofPayoffVisible,
    isRecording: isRecording,
    isDegradedTranscriptState: isDegradedTranscriptState,
    isPostSaveDegradedState: isPostSaveDegradedState,
    whatChangedQuestionActive: whatChangedQuestionActive,
    patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
  );

  static ProofQualityResponseSurface qualitySurfaceFor(
    BetaProofLiftSurface surface,
  ) => switch (surface) {
    BetaProofLiftSurface.timelineProofMoment =>
      ProofQualityResponseSurface.timelineProofMoment,
    BetaProofLiftSurface.firstProofPayoff =>
      ProofQualityResponseSurface.firstProofPayoff,
    BetaProofLiftSurface.patterns => ProofQualityResponseSurface.patterns,
  };

  static BetaProofFeedbackSurface betaSurfaceFor(
    BetaProofLiftSurface surface,
  ) => switch (surface) {
    BetaProofLiftSurface.timelineProofMoment =>
      BetaProofFeedbackSurface.timelineProofMoment,
    BetaProofLiftSurface.firstProofPayoff =>
      BetaProofFeedbackSurface.firstProofPayoff,
    BetaProofLiftSurface.patterns =>
      BetaProofFeedbackSurface.timelineProofMoment,
  };

  static bool _meetsEntryThreshold({
    required int entryCount,
    required bool firstProofPayoffVisible,
  }) => entryCount >= 3 || firstProofPayoffVisible;

  static bool _hasFeedbackToday(BetaProofLiftSurface surface) =>
      BetaProofFeedbackStore.isAnsweredToday(betaSurfaceFor(surface));

  static String _whatRepeatedBody({
    required EvidenceAnchorExtractionResult anchorExtraction,
    required ProofConfidenceCalibrationResult proofConfidenceCalibration,
    required bool hasConfirmedRepeat,
    required TimelineProofMomentResult? timelineProof,
  }) {
    if (proofConfidenceCalibration.isWatchOnly ||
        proofConfidenceCalibration.level == ProofConfidenceLevel.corrected) {
      return proofConfidenceCalibration.primaryCopy;
    }
    if (anchorExtraction.hasSafeAnchor) {
      return anchorExtraction.safeSummaries.first;
    }
    if (timelineProof?.hasSafeAnchor == true &&
        timelineProof!.evidenceAnchors.isNotEmpty) {
      return timelineProof.evidenceAnchors.first;
    }
    if (hasConfirmedRepeat || (timelineProof?.rowCount ?? 0) >= 2) {
      return proofConfidenceCalibration.primaryCopy;
    }
    return BetaProofLiftCopy.fallbackWhatRepeated;
  }

  static String _whatChangedBody({
    required EvidenceWeightingResult? evidenceWeighting,
  }) {
    if (evidenceWeighting == null) {
      return BetaProofLiftCopy.fallbackWhatChanged;
    }
    return switch (evidenceWeighting.primaryState) {
      EvidenceWeightState.softened =>
        'ArchiveMe is watching whether this feels lighter, helped, avoided, or unchanged.',
      EvidenceWeightState.needsFreshProof =>
        'ArchiveMe is waiting for fresher evidence before treating this as current.',
      _ => BetaProofLiftCopy.fallbackWhatChanged,
    };
  }

  static String _whyItMattersNowBody({
    required PresentDayRelevanceResult? presentDay,
  }) {
    if (presentDay == null) {
      return BetaProofLiftCopy.fallbackWhyItMattersNow;
    }
    return switch (presentDay.relevanceState) {
      PresentDayRelevanceState.current =>
        'Recent evidence matters more than older evidence.',
      PresentDayRelevanceState.fading =>
        'ArchiveMe gives less weight when this has not appeared recently.',
      PresentDayRelevanceState.softened =>
        'This may still matter, but recent evidence looks lighter.',
      PresentDayRelevanceState.unclear =>
        BetaProofLiftCopy.fallbackWhyItMattersNow,
    };
  }

  static List<String> _resolveDeltaRows({
    required EvidenceAnchorExtractionResult anchorExtraction,
    required EvidenceWeightingResult? evidenceWeighting,
    required PresentDayRelevanceResult? presentDay,
    required CorrectionMemorySnapshot? correction,
    required TimelineProofMomentResult? timelineProof,
    required bool hasConfirmedRepeat,
  }) {
    final rows = <String>[];

    for (final anchor in anchorExtraction.anchors) {
      if (!anchor.isSafeForDisplay) continue;
      if (anchor.type == EvidenceAnchorType.repeat) continue;
      rows.add(anchor.safeSummary);
    }

    if (correction?.returnedAfterFaded == true ||
        timelineProof?.hasCorrection == true) {
      rows.add(BetaProofLiftCopy.deltaReturnedAfterFirstSave);
    }
    if (hasConfirmedRepeat &&
        (evidenceWeighting?.primaryState == EvidenceWeightState.repeated ||
            evidenceWeighting?.primaryState == EvidenceWeightState.fresh ||
            correction?.state == CorrectionMemoryState.stillCurrent)) {
      rows.add(BetaProofLiftCopy.deltaFeelsStronger);
    }
    if (evidenceWeighting?.hasSofteningSignal == true ||
        evidenceWeighting?.primaryState == EvidenceWeightState.softened ||
        presentDay?.relevanceState == PresentDayRelevanceState.softened) {
      rows.add(BetaProofLiftCopy.deltaFeelsLighter);
    }
    if (correction?.state == CorrectionMemoryState.partlyCurrent) {
      rows.add(BetaProofLiftCopy.deltaSomethingHelped);
    }
    if (presentDay?.relevanceState == PresentDayRelevanceState.unclear ||
        correction?.state == CorrectionMemoryState.unsure) {
      rows.add(BetaProofLiftCopy.deltaNoClearChangeYet);
    }
    if (evidenceWeighting?.primaryState ==
            EvidenceWeightState.needsFreshProof ||
        (evidenceWeighting?.hasOlderEntry == true &&
            evidenceWeighting?.hasRecentEntry == false &&
            hasConfirmedRepeat)) {
      rows.add(BetaProofLiftCopy.deltaNeedsFresherProof);
    }

    return rows.toSet().toList();
  }
}