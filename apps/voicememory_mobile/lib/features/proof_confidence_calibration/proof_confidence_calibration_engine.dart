import '../../models/journal_entry.dart';
import '../correction_memory/correction_memory_engine.dart';
import '../correction_memory/correction_memory_model.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../evidence_anchors/evidence_anchor_model.dart';
import '../evidence_weighting/evidence_weighting_model.dart';
import '../not_relevant_recovery/not_relevant_recovery_engine.dart';
import '../pattern_match_quality/pattern_match_quality_engine.dart';
import '../pattern_match_quality/pattern_match_quality_model.dart';
import '../current_relevance/current_relevance_store.dart';
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
    DateTime? now,
    bool trackAnalytics = false,
  }) {
    if (entries.length < minEntryCount) {
      return ProofConfidenceCalibrationResult.hidden(
        source: source,
        entryCount: entries.length,
      );
    }

    final correctionSnapshot = correction ??
        (entries.length >= 3
            ? CorrectionMemoryEngine.snapshotFor(
                entries: entries,
                now: now,
              )
            : null);
    final matchQuality = patternMatchQuality ??
        PatternMatchQualityEngine.build(
          entries: entries,
          beliefSurfaceVisible: beliefSurfaceVisible,
          source: source,
          beliefEvidencePhrases: beliefEvidencePhrases,
          now: now,
          evidenceWeighting: evidenceWeighting,
          correction: correctionSnapshot,
        );
    final hasSafeAnchor = anchorExtraction?.hasSafeAnchor ?? false;
    final hasCorrection = correctionSnapshot != null;
    final hasFreshReturn = correctionSnapshot?.returnedAfterFaded == true;
    final userMarkedNotRelevant = _userMarkedNotRelevant(
      entries: entries,
      matchQuality: matchQuality,
    );
    final hasChangeDelta = _hasChangeDelta(
      entries: entries,
      anchorExtraction: anchorExtraction,
      evidenceWeighting: evidenceWeighting,
      correction: correctionSnapshot,
    );
    final hasHelpedSoftened = _hasHelpedSoftened(
      matchQuality: matchQuality,
      anchorExtraction: anchorExtraction,
      evidenceWeighting: evidenceWeighting,
    );

    final level = _resolveLevel(
      matchQuality: matchQuality,
      hasSafeAnchor: hasSafeAnchor,
      hasFreshReturn: hasFreshReturn,
      userMarkedNotRelevant: userMarkedNotRelevant,
    );
    final primaryCopy = ProofConfidenceCalibrationCopy.primaryFor(level);
    final leadCopy = _resolveLeadCopy(
      hasChangeDelta: hasChangeDelta,
      hasHelpedSoftened: hasHelpedSoftened,
      level: level,
    );
    final displayCopy = _composeDisplayCopy(
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
      hasSafeAnchor: hasSafeAnchor,
      hasMatchQuality: matchQuality.shouldResolve,
      hasCorrection: hasCorrection,
      hasFreshReturn: hasFreshReturn,
    );

    if (trackAnalytics) {
      ProofConfidenceCalibrationAnalytics.calibrated(result: result);
    }

    return result;
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

    if (!hasSafeAnchor && bandLevel == ProofConfidenceLevel.strong) {
      bandLevel = ProofConfidenceLevel.useful;
    }
    if (!hasSafeAnchor &&
        bandLevel == ProofConfidenceLevel.useful &&
        matchQuality.weakReasons
            .contains(PatternMatchWeakReason.noSafeAnchorAvailable)) {
      bandLevel = ProofConfidenceLevel.emerging;
    }

    return bandLevel;
  }

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

  static String _composeDisplayCopy({
    required String? leadCopy,
    required String primaryCopy,
  }) {
    if (leadCopy == null || leadCopy.trim().isEmpty) {
      return primaryCopy;
    }
    return '$leadCopy $primaryCopy';
  }

  static bool _userMarkedNotRelevant({
    required List<JournalEntry> entries,
    required PatternMatchQualityResult matchQuality,
  }) {
    if (matchQuality.weakReasons
        .contains(PatternMatchWeakReason.userMarkedNotRelevant)) {
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
    if (matchQuality.matchedDimensions
        .contains(PatternMatchDimension.sameHelpfulAction)) {
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
