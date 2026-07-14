import '../beta_decision/beta_decision_model.dart';
import 'beta_improvement_model.dart';
import 'beta_improvement_recommendation_gate.dart';
import 'pro_packaging_boundary_model.dart';
import 'pro_packaging_copy_fix.dart';

/// Applies gated Pro packaging copy when the proPackaging branch is active.
abstract final class ProPackagingBranchEngine {
  ProPackagingBranchEngine._();

  static bool isBranchRecommended({
    List<BetaTesterOutcome>? outcomesOverride,
  }) =>
      BetaImprovementRecommendationGate.isBranchActive(
        BetaImprovementBranch.proPackaging,
        outcomesOverride: outcomesOverride,
      );

  static bool shouldShowBridge({
    required int entryCount,
    required bool hasMeaningfulProof,
    List<BetaTesterOutcome>? outcomesOverride,
  }) =>
      BetaImprovementRecommendationGate.shouldApplyBranch(
        branch: BetaImprovementBranch.proPackaging,
        entryCount: entryCount,
        hasMeaningfulProof: hasMeaningfulProof,
        outcomesOverride: outcomesOverride,
      );

  static String? bridgeTitle({
    required int entryCount,
    required bool hasMeaningfulProof,
    List<BetaTesterOutcome>? outcomesOverride,
  }) {
    if (!shouldShowBridge(
      entryCount: entryCount,
      hasMeaningfulProof: hasMeaningfulProof,
      outcomesOverride: outcomesOverride,
    )) {
      return null;
    }
    return ProPackagingCopyFix.headline;
  }

  static String? bridgeBody({
    required int entryCount,
    required bool hasMeaningfulProof,
    List<BetaTesterOutcome>? outcomesOverride,
  }) {
    if (!shouldShowBridge(
      entryCount: entryCount,
      hasMeaningfulProof: hasMeaningfulProof,
      outcomesOverride: outcomesOverride,
    )) {
      return null;
    }
    return '${ProPackagingCopyFix.freeLine} ${ProPackagingCopyFix.proPromise} '
        '${ProPackagingCopyFix.proofBridge}';
  }

  static List<String> firstProofBridgeLines({
    required int entryCount,
    required bool hasMeaningfulProof,
    List<BetaTesterOutcome>? outcomesOverride,
  }) {
    if (!shouldShowBridge(
      entryCount: entryCount,
      hasMeaningfulProof: hasMeaningfulProof,
      outcomesOverride: outcomesOverride,
    )) {
      return const [];
    }
    return [
      ProPackagingCopyFix.proofBridge,
      '${ProPackagingCopyFix.freeLine} ${ProPackagingCopyFix.proPromise}',
    ];
  }

  static String? paywallHeadline({List<BetaTesterOutcome>? outcomesOverride}) {
    if (!isBranchRecommended(outcomesOverride: outcomesOverride)) {
      return null;
    }
    return ProPackagingCopyFix.headline;
  }

  static String? paywallSubheadline({
    List<BetaTesterOutcome>? outcomesOverride,
  }) {
    if (!isBranchRecommended(outcomesOverride: outcomesOverride)) {
      return null;
    }
    return ProPackagingCopyFix.proValue;
  }

  static List<String>? paywallBullets({
    List<BetaTesterOutcome>? outcomesOverride,
  }) {
    if (!isBranchRecommended(outcomesOverride: outcomesOverride)) {
      return null;
    }
    return ProPackagingCopyFix.longerTrailBullets;
  }

  static ProPackagingBoundary boundary() => ProPackagingCopyFix.boundary();
}
