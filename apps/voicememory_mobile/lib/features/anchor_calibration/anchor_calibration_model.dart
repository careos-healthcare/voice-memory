import '../beta_proof_feedback/beta_proof_feedback_model.dart';
import '../evidence_anchors/evidence_anchor_model.dart';

enum AnchorCalibrationAction {
  preferSpecificAnchors,
  downgradeFallbackOnly,
  requireChangeDelta,
  useChangeTrackingCopy,
  downgradeCurrentRelevance,
  requireFreshReturnForStrong,
  strengthenSimilarAnchors,
  rerankAnchors,
}

extension AnchorCalibrationActionAnalytics on AnchorCalibrationAction {
  String get analyticsValue => switch (this) {
    AnchorCalibrationAction.preferSpecificAnchors => 'prefer_specific_anchors',
    AnchorCalibrationAction.downgradeFallbackOnly => 'downgrade_fallback_only',
    AnchorCalibrationAction.requireChangeDelta => 'require_change_delta',
    AnchorCalibrationAction.useChangeTrackingCopy => 'use_change_tracking_copy',
    AnchorCalibrationAction.downgradeCurrentRelevance =>
      'downgrade_current_relevance',
    AnchorCalibrationAction.requireFreshReturnForStrong =>
      'require_fresh_return_for_strong',
    AnchorCalibrationAction.strengthenSimilarAnchors =>
      'strengthen_similar_anchors',
    AnchorCalibrationAction.rerankAnchors => 'rerank_anchors',
  };
}

class AnchorCalibrationResult {
  const AnchorCalibrationResult({
    required this.extraction,
    required this.applied,
    required this.actions,
    this.feedbackType,
    this.oldAnchorType,
    this.newAnchorType,
    this.forceWatchOnly = false,
    this.useChangeTrackingCopy = false,
    this.downgradeCurrentRelevance = false,
    this.suppressStrongSurfacing = false,
    this.strengthenSimilarAnchors = false,
  });

  final EvidenceAnchorExtractionResult extraction;
  final bool applied;
  final List<AnchorCalibrationAction> actions;
  final BetaProofFeedbackType? feedbackType;
  final EvidenceAnchorType? oldAnchorType;
  final EvidenceAnchorType? newAnchorType;
  final bool forceWatchOnly;
  final bool useChangeTrackingCopy;
  final bool downgradeCurrentRelevance;
  final bool suppressStrongSurfacing;
  final bool strengthenSimilarAnchors;
}
