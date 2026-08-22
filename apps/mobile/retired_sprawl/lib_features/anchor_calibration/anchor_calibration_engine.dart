import 'package:archiveme_mobile/features/anchor_calibration/anchor_calibration_analytics.dart';
import 'package:archiveme_mobile/features/anchor_calibration/anchor_calibration_model.dart';
import 'package:archiveme_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:archiveme_mobile/features/correction_memory/correction_memory_model.dart';
import 'package:archiveme_mobile/features/evidence_anchors/evidence_anchor_copy.dart';
import 'package:archiveme_mobile/features/evidence_anchors/evidence_anchor_model.dart';

/// Applies feedback-aware anchor ranking and proof-surface calibration.
abstract final class AnchorCalibrationEngine {
  AnchorCalibrationEngine._();

  static const maxAnchors = 3;

  static const typePriority = <EvidenceAnchorType, int>{
    EvidenceAnchorType.freshReturn: 100,
    EvidenceAnchorType.corrected: 95,
    EvidenceAnchorType.helped: 90,
    EvidenceAnchorType.softening: 85,
    EvidenceAnchorType.strengthening: 84,
    EvidenceAnchorType.change: 83,
    EvidenceAnchorType.avoided: 82,
    EvidenceAnchorType.current: 75,
    EvidenceAnchorType.repeat: 50,
    EvidenceAnchorType.fading: 40,
    EvidenceAnchorType.unknown: 0,
  };

  static const _tooVaguePreferredTypes = <EvidenceAnchorType>{
    EvidenceAnchorType.freshReturn,
    EvidenceAnchorType.corrected,
    EvidenceAnchorType.helped,
    EvidenceAnchorType.softening,
    EvidenceAnchorType.strengthening,
    EvidenceAnchorType.change,
  };

  static const _usefulBoostTypes = <EvidenceAnchorType>{
    EvidenceAnchorType.freshReturn,
    EvidenceAnchorType.current,
    EvidenceAnchorType.repeat,
  };

  static EvidenceAnchorExtractionResult applyExtraction({
    required EvidenceAnchorExtractionResult extraction,
    required String source, BetaProofFeedbackType? feedbackType,
    bool hasChangeDelta = false,
    bool hasFreshReturn = false,
    CorrectionMemorySnapshot? correction,
    bool trackAnalytics = false,
  }) => apply(
    extraction: extraction,
    feedbackType: feedbackType,
    hasChangeDelta: hasChangeDelta,
    hasFreshReturn: hasFreshReturn,
    correction: correction,
    source: source,
    trackAnalytics: trackAnalytics,
  ).extraction;

  static AnchorCalibrationResult apply({
    required EvidenceAnchorExtractionResult extraction,
    required String source, BetaProofFeedbackType? feedbackType,
    bool hasChangeDelta = false,
    bool hasFreshReturn = false,
    CorrectionMemorySnapshot? correction,
    bool trackAnalytics = false,
  }) {
    final oldPrimaryType = _primaryType(extraction.anchors);
    final ranked = rankAnchors(
      extraction.anchors,
      feedbackType: feedbackType,
      strengthenSimilar: feedbackType == BetaProofFeedbackType.useful,
    );
    final actions = <AnchorCalibrationAction>[
      AnchorCalibrationAction.rerankAnchors,
    ];

    var anchors = ranked;
    var forceWatchOnly = false;
    var useChangeTrackingCopy = false;
    var downgradeCurrentRelevance = false;
    var suppressStrongSurfacing = false;
    var strengthenSimilarAnchors = false;
    AnchorCalibrationAction? analyticsAction =
        AnchorCalibrationAction.rerankAnchors;

    switch (feedbackType) {
      case BetaProofFeedbackType.tooVague:
        actions.add(AnchorCalibrationAction.preferSpecificAnchors);
        anchors = _preferSpecificAnchors(anchors);
        if (anchors.isEmpty || _isFallbackOnly(anchors)) {
          actions.add(AnchorCalibrationAction.downgradeFallbackOnly);
          forceWatchOnly = true;
          analyticsAction = AnchorCalibrationAction.downgradeFallbackOnly;
          anchors = [_fallbackAnchor()];
        } else {
          analyticsAction = AnchorCalibrationAction.preferSpecificAnchors;
        }
      case BetaProofFeedbackType.alreadyKnew:
        actions.add(AnchorCalibrationAction.requireChangeDelta);
        if (!hasChangeDelta) {
          actions.add(AnchorCalibrationAction.useChangeTrackingCopy);
          useChangeTrackingCopy = true;
          analyticsAction = AnchorCalibrationAction.useChangeTrackingCopy;
        } else {
          analyticsAction = AnchorCalibrationAction.requireChangeDelta;
        }
      case BetaProofFeedbackType.notRelevant:
        actions.add(AnchorCalibrationAction.downgradeCurrentRelevance);
        downgradeCurrentRelevance = true;
        if (!hasFreshReturn) {
          actions.add(AnchorCalibrationAction.requireFreshReturnForStrong);
          suppressStrongSurfacing = true;
          anchors = _requireFreshReturnAnchor(anchors, hasFreshReturn: false);
          analyticsAction = AnchorCalibrationAction.requireFreshReturnForStrong;
        } else {
          analyticsAction = AnchorCalibrationAction.downgradeCurrentRelevance;
        }
      case BetaProofFeedbackType.useful:
        actions.add(AnchorCalibrationAction.strengthenSimilarAnchors);
        strengthenSimilarAnchors = true;
        analyticsAction = AnchorCalibrationAction.strengthenSimilarAnchors;
      case null:
        break;
    }

    if (correction?.state == CorrectionMemoryState.faded &&
        correction?.returnedAfterFaded != true &&
        feedbackType == BetaProofFeedbackType.notRelevant) {
      downgradeCurrentRelevance = true;
      suppressStrongSurfacing = true;
    }

    final selected = anchors.take(maxAnchors).toList();
    final safeSummaries = selected
        .where((anchor) => anchor.isSafeForDisplay)
        .map((anchor) => anchor.safeSummary)
        .toList();
    final hasSafeAnchor = safeSummaries.isNotEmpty && !forceWatchOnly;
    final usesFallback = !hasSafeAnchor;
    final resolvedAnchors = hasSafeAnchor ? selected : [_fallbackAnchor()];
    final newPrimaryType = _primaryType(resolvedAnchors);

    final calibrated = EvidenceAnchorExtractionResult(
      shouldExtract: extraction.shouldExtract,
      entryCount: extraction.entryCount,
      source: extraction.source,
      anchors: resolvedAnchors,
      safeSummaries: safeSummaries,
      usesFallback: usesFallback,
      hasSafeAnchor: hasSafeAnchor,
      hasRecentAnchor: selected.any((anchor) => anchor.recencyWeight >= 0.7),
      hasCorrectionAnchor: selected.any(
        (anchor) =>
            anchor.isUserCorrected ||
            anchor.type == EvidenceAnchorType.corrected ||
            anchor.type == EvidenceAnchorType.freshReturn,
      ),
      hasChangeAnchor: selected.any(
        (anchor) =>
            anchor.type == EvidenceAnchorType.change ||
            anchor.type == EvidenceAnchorType.softening ||
            anchor.type == EvidenceAnchorType.strengthening ||
            anchor.type == EvidenceAnchorType.helped ||
            anchor.type == EvidenceAnchorType.avoided,
      ),
    );

    final applied =
        feedbackType != null ||
        oldPrimaryType != newPrimaryType ||
        forceWatchOnly ||
        useChangeTrackingCopy ||
        downgradeCurrentRelevance ||
        suppressStrongSurfacing;

    if (trackAnalytics && applied) {
      AnchorCalibrationAnalytics.applied(
        entryCount: extraction.entryCount,
        source: source,
        feedbackType: feedbackType,
        oldAnchorType: oldPrimaryType,
        newAnchorType: newPrimaryType,
        calibrationAction: analyticsAction,
      );
    }

    return AnchorCalibrationResult(
      extraction: calibrated,
      applied: applied,
      actions: actions,
      feedbackType: feedbackType,
      oldAnchorType: oldPrimaryType,
      newAnchorType: newPrimaryType,
      forceWatchOnly: forceWatchOnly,
      useChangeTrackingCopy: useChangeTrackingCopy,
      downgradeCurrentRelevance: downgradeCurrentRelevance,
      suppressStrongSurfacing: suppressStrongSurfacing,
      strengthenSimilarAnchors: strengthenSimilarAnchors,
    );
  }

  static List<EvidenceAnchor> rankAnchors(
    List<EvidenceAnchor> anchors, {
    BetaProofFeedbackType? feedbackType,
    bool strengthenSimilar = false,
  }) {
    final ranked = [...anchors]
      ..sort(
        (a, b) =>
            _scoreFor(
              b,
              feedbackType: feedbackType,
              strengthenSimilar: strengthenSimilar,
            ).compareTo(
              _scoreFor(
                a,
                feedbackType: feedbackType,
                strengthenSimilar: strengthenSimilar,
              ),
            ),
      );
    return ranked;
  }

  static int typeRank(EvidenceAnchorType type) => typePriority[type] ?? 0;

  static List<EvidenceAnchor> _preferSpecificAnchors(
    List<EvidenceAnchor> anchors,
  ) => anchors
      .where(
        (anchor) =>
            _tooVaguePreferredTypes.contains(anchor.type) &&
            anchor.isSafeForDisplay,
      )
      .toList();

  static List<EvidenceAnchor> _requireFreshReturnAnchor(
    List<EvidenceAnchor> anchors, {
    required bool hasFreshReturn,
  }) {
    if (hasFreshReturn) return anchors;
    return anchors
        .where(
          (anchor) =>
              anchor.type == EvidenceAnchorType.freshReturn ||
              anchor.type == EvidenceAnchorType.corrected,
        )
        .toList();
  }

  static bool _isFallbackOnly(List<EvidenceAnchor> anchors) =>
      anchors.isEmpty ||
      anchors.every(
        (anchor) =>
            anchor.type == EvidenceAnchorType.unknown ||
            !anchor.isSafeForDisplay,
      );

  static EvidenceAnchorType? _primaryType(List<EvidenceAnchor> anchors) {
    if (anchors.isEmpty) return null;
    final ranked = rankAnchors(anchors);
    return ranked.first.type;
  }

  static double _scoreFor(
    EvidenceAnchor anchor, {
    BetaProofFeedbackType? feedbackType,
    bool strengthenSimilar = false,
  }) {
    var typeScore = typePriority[anchor.type]?.toDouble() ?? 0;
    if (feedbackType == BetaProofFeedbackType.tooVague &&
        anchor.type == EvidenceAnchorType.repeat) {
      typeScore -= 20;
    }
    if (strengthenSimilar && _usefulBoostTypes.contains(anchor.type)) {
      typeScore += 8;
    }
    return typeScore +
        anchor.recencyWeight * 10 +
        anchor.strength * 5 +
        (anchor.isUserCorrected ? 5 : 0) +
        (anchor.isFreshReturn ? 3 : 0);
  }

  static EvidenceAnchor _fallbackAnchor() => EvidenceAnchor(
    id: 'anchor_fallback',
    type: EvidenceAnchorType.unknown,
    label: EvidenceAnchorType.unknown.label,
    safeSummary: EvidenceAnchorCopy.fallbackSummary,
    strength: 0.2,
    recencyWeight: 0,
    sourceCount: 0,
    isUserCorrected: false,
    isFreshReturn: false,
    isSafeForDisplay: false,
  );
}