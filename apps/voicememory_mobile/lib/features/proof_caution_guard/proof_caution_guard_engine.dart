import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_quality.dart';
import '../correction_memory/correction_memory_model.dart';
import '../evidence_anchors/evidence_anchor_model.dart';
import '../evidence_weighting/evidence_weighting_model.dart';
import '../pattern_match_quality/pattern_match_quality_model.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_copy.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'proof_caution_guard_analytics.dart';
import 'proof_caution_guard_copy.dart';
import 'proof_caution_guard_model.dart';

/// Rolls back over-cautious watch-only/emerging levels when anchors and repeat
/// quality are good — display only, no threshold changes.
abstract final class ProofCautionGuardEngine {
  ProofCautionGuardEngine._();

  static const watchOnlyMinEntryCount = 3;
  static const emergingMinEntryCount = 4;

  static const _qualifyingChangeAnchorTypes = <EvidenceAnchorType>{
    EvidenceAnchorType.change,
    EvidenceAnchorType.softening,
    EvidenceAnchorType.strengthening,
    EvidenceAnchorType.helped,
  };

  static ProofConfidenceCalibrationResult guard({
    required ProofConfidenceCalibrationResult calibration,
    required PatternMatchQualityResult matchQuality,
    required bool hasSafeAnchor,
    required bool hasConfirmedRepeat,
    required bool isDegraded,
    required bool userMarkedNotRelevant,
    CorrectionMemorySnapshot? correction,
    EvidenceAnchorExtractionResult? anchorExtraction,
    EvidenceWeightingResult? evidenceWeighting,
    bool trackAnalytics = false,
  }) {
    final guardResult = apply(
      calibration: calibration,
      matchQuality: matchQuality,
      hasSafeAnchor: hasSafeAnchor,
      hasConfirmedRepeat: hasConfirmedRepeat,
      isDegraded: isDegraded,
      userMarkedNotRelevant: userMarkedNotRelevant,
      correction: correction,
      anchorExtraction: anchorExtraction,
      evidenceWeighting: evidenceWeighting,
      trackAnalytics: trackAnalytics,
    );
    return guardResult.calibration;
  }

  static ProofCautionGuardResult apply({
    required ProofConfidenceCalibrationResult calibration,
    required PatternMatchQualityResult matchQuality,
    required bool hasSafeAnchor,
    required bool hasConfirmedRepeat,
    required bool isDegraded,
    required bool userMarkedNotRelevant,
    CorrectionMemorySnapshot? correction,
    EvidenceAnchorExtractionResult? anchorExtraction,
    EvidenceWeightingResult? evidenceWeighting,
    bool trackAnalytics = false,
  }) {
    if (!calibration.shouldCalibrate) {
      return ProofCautionGuardResult(
        calibration: calibration,
        applied: false,
        originalLevel: calibration.level,
        adjustedLevel: calibration.level,
      );
    }

    final originalLevel = calibration.level;
    if (!_isRollbackCandidate(originalLevel)) {
      return ProofCautionGuardResult(
        calibration: calibration,
        applied: false,
        originalLevel: originalLevel,
        adjustedLevel: originalLevel,
      );
    }

    final blockedReason = _blockedReason(
      matchQuality: matchQuality,
      hasSafeAnchor: hasSafeAnchor,
      isDegraded: isDegraded,
      userMarkedNotRelevant: userMarkedNotRelevant,
      correction: correction,
      hasFreshReturn: calibration.hasFreshReturn,
    );

    if (blockedReason != null) {
      if (trackAnalytics && _shouldTrackBlocked(originalLevel, matchQuality)) {
        ProofCautionGuardAnalytics.blocked(
          entryCount: calibration.entryCount,
          source: calibration.source,
          originalLevel: originalLevel,
          blockedReason: blockedReason,
        );
      }
      return ProofCautionGuardResult(
        calibration: calibration,
        applied: false,
        originalLevel: originalLevel,
        adjustedLevel: originalLevel,
        blockedReason: blockedReason,
      );
    }

    final upgrade = _resolveUpgrade(
      originalLevel: originalLevel,
      entryCount: calibration.entryCount,
      hasSafeAnchor: hasSafeAnchor,
      hasConfirmedRepeat: hasConfirmedRepeat,
      matchQuality: matchQuality,
      anchorExtraction: anchorExtraction,
      evidenceWeighting: evidenceWeighting,
      correction: correction,
    );

    if (upgrade == null) {
      return ProofCautionGuardResult(
        calibration: calibration,
        applied: false,
        originalLevel: originalLevel,
        adjustedLevel: originalLevel,
      );
    }

    final adjusted = _calibrationWithLevel(
      calibration: calibration,
      level: upgrade.$1,
      useGuardCopy: upgrade.$2,
    );

    if (trackAnalytics) {
      ProofCautionGuardAnalytics.applied(
        entryCount: calibration.entryCount,
        source: calibration.source,
        originalLevel: originalLevel,
        adjustedLevel: upgrade.$1,
        reason: upgrade.$3,
      );
    }

    return ProofCautionGuardResult(
      calibration: adjusted,
      applied: true,
      originalLevel: originalLevel,
      adjustedLevel: upgrade.$1,
      reason: upgrade.$3,
    );
  }

  static bool entriesAreDegraded(List<JournalEntry> entries) => entries.any(
    (entry) => !ArchiveEvidenceQuality.assess(entry).allowsProofSurfaces,
  );

  static bool _isRollbackCandidate(ProofConfidenceLevel level) =>
      level == ProofConfidenceLevel.watchOnly ||
      level == ProofConfidenceLevel.emerging;

  static bool _shouldTrackBlocked(
    ProofConfidenceLevel level,
    PatternMatchQualityResult matchQuality,
  ) {
    if (level == ProofConfidenceLevel.watchOnly) {
      return matchQuality.entryCount >= watchOnlyMinEntryCount;
    }
    if (level == ProofConfidenceLevel.emerging) {
      return matchQuality.entryCount >= emergingMinEntryCount;
    }
    return false;
  }

  static ProofCautionGuardBlockedReason? _blockedReason({
    required PatternMatchQualityResult matchQuality,
    required bool hasSafeAnchor,
    required bool isDegraded,
    required bool userMarkedNotRelevant,
    required CorrectionMemorySnapshot? correction,
    required bool hasFreshReturn,
  }) {
    if (userMarkedNotRelevant && !hasFreshReturn) {
      return ProofCautionGuardBlockedReason.userMarkedNotRelevant;
    }
    if (!hasSafeAnchor ||
        matchQuality.weakReasons.contains(
          PatternMatchWeakReason.noSafeAnchorAvailable,
        )) {
      return ProofCautionGuardBlockedReason.noSafeAnchor;
    }
    if (matchQuality.weakReasons.contains(
      PatternMatchWeakReason.onlyGenericWordingOverlaps,
    )) {
      return ProofCautionGuardBlockedReason.genericWordingOnly;
    }
    if (matchQuality.weakReasons.contains(
      PatternMatchWeakReason.entriesTooUnrelated,
    )) {
      return ProofCautionGuardBlockedReason.entriesUnrelated;
    }
    if (isDegraded) {
      return ProofCautionGuardBlockedReason.degradedTranscript;
    }
    if (correction?.state == CorrectionMemoryState.faded &&
        correction?.returnedAfterFaded != true) {
      return ProofCautionGuardBlockedReason.correctionBackground;
    }
    return null;
  }

  static (ProofConfidenceLevel, bool, ProofCautionGuardUpgradeReason)?
  _resolveUpgrade({
    required ProofConfidenceLevel originalLevel,
    required int entryCount,
    required bool hasSafeAnchor,
    required bool hasConfirmedRepeat,
    required PatternMatchQualityResult matchQuality,
    required EvidenceAnchorExtractionResult? anchorExtraction,
    required EvidenceWeightingResult? evidenceWeighting,
    required CorrectionMemorySnapshot? correction,
  }) {
    if (originalLevel == ProofConfidenceLevel.watchOnly) {
      if (entryCount < watchOnlyMinEntryCount || !hasSafeAnchor) {
        return null;
      }
      final hasOverlapSignal =
          matchQuality.matchedDimensions.length >= 2 || hasConfirmedRepeat;
      if (!hasOverlapSignal) return null;

      if (hasConfirmedRepeat &&
          matchQuality.matchedDimensions.length >= 2 &&
          matchQuality.shouldShowAsProof) {
        return (
          ProofConfidenceLevel.useful,
          true,
          ProofCautionGuardUpgradeReason.watchOnlyRollback,
        );
      }
      return (
        ProofConfidenceLevel.emerging,
        false,
        ProofCautionGuardUpgradeReason.watchOnlyRollback,
      );
    }

    if (originalLevel == ProofConfidenceLevel.emerging) {
      if (entryCount < emergingMinEntryCount || !hasSafeAnchor) {
        return null;
      }
      if (!_hasQualifyingChangeAnchor(anchorExtraction)) return null;
      if (!_hasRecentReturn(evidenceWeighting, correction)) return null;

      return (
        ProofConfidenceLevel.useful,
        true,
        ProofCautionGuardUpgradeReason.emergingRollback,
      );
    }

    return null;
  }

  static bool _hasQualifyingChangeAnchor(
    EvidenceAnchorExtractionResult? anchorExtraction,
  ) {
    if (anchorExtraction?.hasChangeAnchor == true) return true;
    return anchorExtraction?.anchors.any(
          (anchor) => _qualifyingChangeAnchorTypes.contains(anchor.type),
        ) ==
        true;
  }

  static bool _hasRecentReturn(
    EvidenceWeightingResult? evidenceWeighting,
    CorrectionMemorySnapshot? correction,
  ) =>
      evidenceWeighting?.hasRecentEntry == true ||
      correction?.returnedAfterFaded == true;

  static ProofConfidenceCalibrationResult _calibrationWithLevel({
    required ProofConfidenceCalibrationResult calibration,
    required ProofConfidenceLevel level,
    required bool useGuardCopy,
  }) {
    assert(level != ProofConfidenceLevel.strong);

    final primaryCopy = useGuardCopy
        ? ProofCautionGuardCopy.upgradeBody
        : ProofConfidenceCalibrationCopy.primaryFor(level);
    final leadCopy =
        level == ProofConfidenceLevel.watchOnly ||
            level == ProofConfidenceLevel.corrected
        ? null
        : calibration.leadCopy;
    final displayCopy = leadCopy == null || leadCopy.trim().isEmpty
        ? primaryCopy
        : '$leadCopy $primaryCopy';

    return ProofConfidenceCalibrationResult(
      shouldCalibrate: calibration.shouldCalibrate,
      entryCount: calibration.entryCount,
      source: calibration.source,
      level: level,
      primaryCopy: primaryCopy,
      leadCopy: leadCopy,
      displayCopy: displayCopy,
      hasSafeAnchor: calibration.hasSafeAnchor,
      hasMatchQuality: calibration.hasMatchQuality,
      hasCorrection: calibration.hasCorrection,
      hasFreshReturn: calibration.hasFreshReturn,
    );
  }
}
