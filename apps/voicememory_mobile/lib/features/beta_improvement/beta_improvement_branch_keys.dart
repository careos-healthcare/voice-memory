import '../beta_decision/beta_decision_model.dart';
import 'beta_improvement_model.dart';
import 'beta_improvement_recommendation_gate.dart';
import 'proof_to_pro_path_engine.dart';

/// Canonical widget/test keys for beta improvement branch surfaces.
abstract final class BetaImprovementBranchKeys {
  BetaImprovementBranchKeys._();

  /// Key for a first-proof Pro bridge line on [FirstProofPayoffCard].
  static String firstProofBridgeLineKey({
    required int lineIndex,
    required int lineCount,
    List<BetaTesterOutcome>? outcomesOverride,
  }) {
    final prefix = _firstProofBridgePrefix(
      outcomesOverride: outcomesOverride,
    );
    if (lineCount == 1) return prefix;
    return '${prefix}_$lineIndex';
  }

  static String _firstProofBridgePrefix({
    List<BetaTesterOutcome>? outcomesOverride,
  }) {
    if (ProofToProPathEngine.isProofToProOverride()) {
      return 'pro_packaging_bridge_first_proof';
    }

    final branch = BetaImprovementRecommendationGate.activeBranch(
      outcomesOverride: outcomesOverride,
    );
    return switch (branch) {
      BetaImprovementBranch.proUtility => 'pro_utility_bridge_first_proof',
      BetaImprovementBranch.proPackaging => 'pro_packaging_bridge_first_proof',
      BetaImprovementBranch.proofEmotionalClarity =>
        'pro_packaging_bridge_first_proof',
      _ => 'pro_packaging_bridge_first_proof',
    };
  }
}
