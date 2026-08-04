import '../../models/journal_entry.dart';
import '../correction_memory/correction_memory_engine.dart';
import '../correction_memory/correction_memory_model.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../evidence_anchors/evidence_anchor_engine.dart';
import '../evidence_anchors/evidence_anchor_model.dart';
import '../evidence_weighting/evidence_weighting_model.dart';
import '../not_relevant_recovery/not_relevant_recovery_engine.dart';
import '../pattern_match_quality/pattern_match_quality_engine.dart';
import '../pattern_match_quality/pattern_match_quality_model.dart';
import '../anchor_calibration/anchor_calibration_engine.dart';
import '../anchor_calibration/anchor_calibration_copy.dart';
import '../anchor_calibration/anchor_calibration_model.dart';
import '../beta_proof_feedback/beta_proof_feedback_model.dart';
import '../proof_caution_guard/proof_caution_guard_engine.dart';
import '../current_relevance/current_relevance_store.dart';
import '../proof_relevance_repair/proof_relevance_repair_engine.dart';
import 'proof_confidence_calibration_analytics.dart';
import 'proof_confidence_calibration_copy.dart';
import 'proof_confidence_calibration_model.dart';

/// Calibrates proof copy to evidence strength from existing safe signals only.
abstract final class ProofConfidenceCalibrationEngine {
  ProofConfidenceCalibrationEngine._();

  static const minEntryCount = 2;

  static ProofConfidenceCalibrationResult build({
    required List<JournalEntry> entries,
    required bool beliefSurfaceVisible,
    required String source,
    List<String> beliefEvidencePhrases = const [],
    PatternMatchQualityResult? patternMatchQuality,
    EvidenceAnchorExtractionResult? anchorExtraction,
    EvidenceWeightingResult? evidenceWeighting,
    CorrectionMemorySnapshot? correction,
    BetaProofFeedbackType? calibrationFeedback,
    DateTime? now,
    bool trackAnalytics = false,
  }) {
    if (entries.length < minEntryCount) {
      return ProofConfidenceCalibrationResult.hidden(
        source: source,
        entryCount: entries.length,
      );
    }

    final correctionSnapshot =
        correction ??
        (entries.length >= 3
            ? CorrectionMemoryEngine.snapshotFor(entries: entries, now: now)
            : null);
    final matchQuality =
        patternMatchQuality ??
        PatternMatchQualityEngine.build(
          entries: entries,
          beliefSurfaceVisible: beliefSurfaceVisible,
          source: source,
          beliefEvidencePhrases: beliefEvidencePhrases,
          now: now,
          evidenceWeighting: evidenceWeighting,
          correction: correctionSnapshot,
        );
    final resolvedAnchorExtraction =
        anchorExtraction ??
        (entries.length >= 3
            ? EvidenceAnchorEngine.build(
                entries: entries,
                beliefSurfaceVisible: beliefSurfaceVisible,
                source: source,
                beliefEvidencePhrases: beliefEvidencePhrases,
                now: now,
              )
            : null);
    final hasSafeAnchor = resolvedAnchorExtraction?.hasSafeAnchor ?? false;
    final anchorCalibration = resolvedAnchorExtraction == null
        ? null
        : AnchorCalibrationEngine.apply(
            extraction: resolvedAnchorExtraction,
            feedbackType: calibrationFeedback,
            hasChangeDelta: _hasChangeDelta(
              entries: entries,
              anchorExtraction: resolvedAnchorExtraction,
              evidenceWeighting: evidenceWeighting,
              correction: correctionSnapshot,
            ),
            hasFreshReturn: correctionSnapshot?.returnedAfterFaded == true,
            correction: correctionSnapshot,
            source: source,
            trackAnalytics: trackAnalytics,
          );
    final resolvedAnchors =
        anchorCalibration?.extraction ?? resolvedAnchorExtraction;
    final resolvedHasSafeAnchor =
        resolvedAnchors?.hasSafeAnchor ?? hasSafeAnchor;
    final hasCorrection = correctionSnapshot != null;
    final hasFreshReturn = correctionSnapshot?.returnedAfterFaded == true;
    final userMarkedNotRelevant = _userMarkedNotRelevant(
      entries: entries,
      matchQuality: matchQuality,
    );
    final hasChangeDelta = _hasChangeDelta(
      entries: entries,
      anchorExtraction: resolvedAnchors,
      evidenceWeighting: evidenceWeighting,
      correction: correctionSnapshot,
    );
    final hasHelpedSoftened = _hasHelpedSoftened(
      matchQuality: matchQuality,
      anchorExtraction: resolvedAnchors,
      evidenceWeighting: evidenceWeighting,
    );

    var level = _resolveLevel(
      matchQuality: matchQuality,
      hasSafeAnchor: resolvedHasSafeAnchor,
      hasFreshReturn: hasFreshReturn,
      userMarkedNotRelevant: userMarkedNotRelevant,
    );
    level = _applyAnchorCalibrationLevel(
      level: level,
      calibration: anchorCalibration,
      hasFreshReturn: hasFreshReturn,
    );
    final primaryCopy = anchorCalibration?.useChangeTrackingCopy == true
        ? AnchorCalibrationCopy.changeTrackingBody
        : ProofConfidenceCalibrationCopy.primaryFor(level);
    final leadCopy = _resolveLeadCopy(
      hasChangeDelta: hasChangeDelta,
      hasHelpedSoftened: hasHelpedSoftened,
      level: level,
    );
    final displayCopy = ProofRelevanceRepairEngine.composeDisplayCopy(
      level: level,
      behaviorPhrase: resolvedAnchors?.safeSummaries.isNotEmpty == true
          ? resolvedAnchors!.safeSummaries.first
          : null,
      hasSafeAnchor: resolvedHasSafeAnchor,
      leadCopy: leadCopy,
      primaryCopy: primaryCopy,
    );

    final result = ProofConfidenceCalibrationResult(
      shouldCalibrate: true,
      entryCount: entries.length,
      source: source,
      level: level,
      primaryCopy: primaryCopy,
      leadCopy: leadCopy,
      displayCopy: displayCopy,
      hasSafeAnchor: resolvedHasSafeAnchor,
      hasMatchQuality: matchQuality.shouldResolve,
      hasCorrection: hasCorrection,
      hasFreshReturn: hasFreshReturn,
    );

    final guarded = ProofCautionGuardEngine.guard(
      calibration: result,
      matchQuality: matchQuality,
      hasSafeAnchor: resolvedHasSafeAnchor,
      hasConfirmedRepeat: EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
        entries,
      ),
      isDegraded: ProofCautionGuardEngine.entriesAreDegraded(entries),
      userMarkedNotRelevant: userMarkedNotRelevant,
      correction: correctionSnapshot,
      anchorExtraction: resolvedAnchorExtraction,
      evidenceWeighting: evidenceWeighting,
      trackAnalytics: trackAnalytics,
    );
    final protected = _applyNegativeFeedbackProtection(
      calibration: guarded,
      calibrationFeedback: calibrationFeedback,
      hasFreshReturn: hasFreshReturn,
    );

    if (trackAnalytics) {
      ProofConfidenceCalibrationAnalytics.calibrated(result: protected);
    }

    return protected;
  }

  static ProofConfidenceCalibrationResult _applyNegativeFeedbackProtection({
    required ProofConfidenceCalibrationResult calibration,
    required BetaProofFeedbackType? calibrationFeedback,
    required bool hasFreshReturn,
  }) {
    if (calibrationFeedback == BetaProofFeedbackType.tooVague &&
        !hasFreshReturn) {
      return ProofConfidenceCalibrationResult(
        shouldCalibrate: calibration.shouldCalibrate,
        entryCount: calibration.entryCount,
        source: calibration.source,
        level: ProofConfidenceLevel.watchOnly,
        primaryCopy: ProofConfidenceCalibrationCopy.watchOnly,
        displayCopy: ProofConfidenceCalibrationCopy.watchOnly,
        hasSafeAnchor: calibration.hasSafeAnchor,
        hasMatchQuality: calibration.hasMatchQuality,
        hasCorrection: calibration.hasCorrection,
        hasFreshReturn: calibration.hasFreshReturn,
      );
    }
    return calibration;
  }

  static ProofConfidenceLevel _applyAnchorCalibrationLevel({
    required ProofConfidenceLevel level,
    required AnchorCalibrationResult? calibration,
    required bool hasFreshReturn,
  }) {
    if (calibration == null) return level;
    if (hasFreshReturn) return level;
    if (calibration.forceWatchOnly &&
        level != ProofConfidenceLevel.freshReturn &&
        level != ProofConfidenceLevel.corrected) {
      return ProofConfidenceLevel.watchOnly;
    }
    if (calibration.suppressStrongSurfacing &&
        level == ProofConfidenceLevel.strong) {
      return ProofConfidenceLevel.useful;
    }
    if (calibration.useChangeTrackingCopy &&
        (level == ProofConfidenceLevel.strong ||
            level == ProofConfidenceLevel.useful)) {
      return ProofConfidenceLevel.emerging;
    }
    return level;
  }

  static ProofConfidenceLevel _resolveLevel({
    required PatternMatchQualityResult matchQuality,
    required bool hasSafeAnchor,
    required bool hasFreshReturn,
    required bool userMarkedNotRelevant,
  }) {
    if (hasFreshReturn) {
      return ProofConfidenceLevel.freshReturn;
    }
    if (userMarkedNotRelevant && !hasFreshReturn) {
      return ProofConfidenceLevel.corrected;
    }
    if (matchQuality.shouldShowAsWatchOnly ||
        matchQuality.confidenceBand == PatternMatchConfidenceBand.weak) {
      return ProofConfidenceLevel.watchOnly;
    }

    var bandLevel = switch (matchQuality.confidenceBand) {
      PatternMatchConfidenceBand.emerging => ProofConfidenceLevel.emerging,
      PatternMatchConfidenceBand.solid => ProofConfidenceLevel.useful,
      PatternMatchConfidenceBand.strong => ProofConfidenceLevel.strong,
      PatternMatchConfidenceBand.weak => ProofConfidenceLevel.watchOnly,
    };

    if (!hasSafeAnchor) {
      if (matchQuality.weakReasons.contains(
            PatternMatchWeakReason.noSafeAnchorAvailable,
          ) ||
          matchQuality.weakReasons.contains(
            PatternMatchWeakReason.onlyGenericWordingOverlaps,
          )) {
        return ProofConfidenceLevel.watchOnly;
      }
      if (bandLevel == ProofConfidenceLevel.strong ||
          bandLevel == ProofConfidenceLevel.useful) {
        bandLevel = ProofConfidenceLevel.emerging;
      }
    }

    return bandLevel;
  }

  /// Proof protection v2 — useful/strong surfaces need a safe anchor.
  static bool shouldShowUsefulProofSurface({
    required ProofConfidenceCalibrationResult calibration,
    required bool hasSafeAnchor,
  }) => hasSafeAnchor && calibration.isProofLevel && !calibration.isWatchOnly;

  static String? _resolveLeadCopy({
    required bool hasChangeDelta,
    required bool hasHelpedSoftened,
    required ProofConfidenceLevel level,
  }) {
    if (level == ProofConfidenceLevel.watchOnly ||
        level == ProofConfidenceLevel.corrected) {
      return null;
    }
    if (hasChangeDelta) {
      return ProofConfidenceCalibrationCopy.changeDeltaLead;
    }
    if (hasHelpedSoftened) {
      return ProofConfidenceCalibrationCopy.helpedSoftenedLead;
    }
    return null;
  }

  static bool _userMarkedNotRelevant({
    required List<JournalEntry> entries,
    required PatternMatchQualityResult matchQuality,
  }) {
    if (matchQuality.weakReasons.contains(
      PatternMatchWeakReason.userMarkedNotRelevant,
    )) {
      return true;
    }
    final proofKey = CurrentRelevanceStore.proofKeyFor(entries);
    return proofKey.isNotEmpty &&
        NotRelevantRecoveryEngine.hasNotRelevantTrigger(proofKey: proofKey);
  }

  static bool _hasChangeDelta({
    required List<JournalEntry> entries,
    required EvidenceAnchorExtractionResult? anchorExtraction,
    required EvidenceWeightingResult? evidenceWeighting,
    required CorrectionMemorySnapshot? correction,
  }) {
    if (correction?.returnedAfterFaded == true) return true;
    if (evidenceWeighting?.hasSofteningSignal == true) return true;
    if (anchorExtraction?.hasChangeAnchor == true) return true;
    if (EarlyFirstSignalEngine.buildChangeNotice(entries: entries) != null) {
      return true;
    }
    return false;
  }

  static bool _hasHelpedSoftened({
    required PatternMatchQualityResult matchQuality,
    required EvidenceAnchorExtractionResult? anchorExtraction,
    required EvidenceWeightingResult? evidenceWeighting,
  }) {
    if (evidenceWeighting?.hasSofteningSignal == true) return true;
    if (matchQuality.matchedDimensions.contains(
      PatternMatchDimension.sameHelpfulAction,
    )) {
      return true;
    }
    if (anchorExtraction?.anchors.any(
          (anchor) =>
              anchor.type == EvidenceAnchorType.helped ||
              anchor.type == EvidenceAnchorType.softening,
        ) ==
        true) {
      return true;
    }
    return false;
  }
}
