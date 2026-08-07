import '../beta_decision/beta_decision_model.dart';
import 'beta_improvement_model.dart';
import 'beta_improvement_recommendation_gate.dart';
import 'proof_to_pro_path_model.dart';

/// Safe combined proof-clarity then Pro-packaging path — no stacked cards.
abstract final class ProofToProPathEngine {
  ProofToProPathEngine._();

  static const minEntryCount = 3;
  static const proofToProOverride = 'proofToPro';

  static bool isProofToProOverride() {
    const raw = String.fromEnvironment(
      BetaImprovementRecommendationGate.buildDefineKey,
      defaultValue: '',
    );
    return raw == proofToProOverride;
  }

  static bool allowsProofEmotionalClarity({
    List<BetaTesterOutcome>? outcomesOverride,
  }) {
    if (isProofToProOverride()) return true;
    final branch = BetaImprovementRecommendationGate.activeBranch(
      outcomesOverride: outcomesOverride,
    );
    return branch == BetaImprovementBranch.proofEmotionalClarity ||
        branch == BetaImprovementBranch.proPackaging;
  }

  static bool allowsProPackaging({List<BetaTesterOutcome>? outcomesOverride}) {
    if (isProofToProOverride()) return true;
    return BetaImprovementRecommendationGate.isBranchActive(
      BetaImprovementBranch.proPackaging,
      outcomesOverride: outcomesOverride,
    );
  }

  static bool _hasMeaningfulProof({
    required int entryCount,
    required bool hasMeaningfulProof,
  }) => hasMeaningfulProof || entryCount >= minEntryCount;

  static bool _proofClarityShowable({
    required int entryCount,
    required bool hasMeaningfulProof,
    required bool proofClarityRenderable,
    List<BetaTesterOutcome>? outcomesOverride,
  }) {
    if (entryCount == 0) return false;
    if (!allowsProofEmotionalClarity(outcomesOverride: outcomesOverride)) {
      return false;
    }
    if (!_hasMeaningfulProof(
      entryCount: entryCount,
      hasMeaningfulProof: hasMeaningfulProof,
    )) {
      return false;
    }

    if (isProofToProOverride()) {
      return entryCount >= minEntryCount;
    }

    if (BetaImprovementRecommendationGate.isBranchActive(
      BetaImprovementBranch.proofEmotionalClarity,
      outcomesOverride: outcomesOverride,
    )) {
      return BetaImprovementRecommendationGate.shouldApplyBranch(
        branch: BetaImprovementBranch.proofEmotionalClarity,
        entryCount: entryCount,
        hasMeaningfulProof: hasMeaningfulProof || entryCount >= minEntryCount,
        outcomesOverride: outcomesOverride,
      );
    }

    if (BetaImprovementRecommendationGate.isBranchActive(
      BetaImprovementBranch.proPackaging,
      outcomesOverride: outcomesOverride,
    )) {
      return BetaImprovementRecommendationGate.shouldApplyBranch(
        branch: BetaImprovementBranch.proPackaging,
        entryCount: entryCount,
        hasMeaningfulProof: hasMeaningfulProof,
        outcomesOverride: outcomesOverride,
      );
    }

    return proofClarityRenderable;
  }

  static bool _proPackagingApplies({
    required int entryCount,
    required bool hasMeaningfulProof,
    List<BetaTesterOutcome>? outcomesOverride,
  }) {
    if (isProofToProOverride()) {
      return entryCount >= minEntryCount &&
          _hasMeaningfulProof(
            entryCount: entryCount,
            hasMeaningfulProof: hasMeaningfulProof,
          );
    }
    return BetaImprovementRecommendationGate.shouldApplyBranch(
      branch: BetaImprovementBranch.proPackaging,
      entryCount: entryCount,
      hasMeaningfulProof: hasMeaningfulProof,
      outcomesOverride: outcomesOverride,
    );
  }

  static ProofToProPathModel build({
    required int entryCount,
    required bool hasMeaningfulProof,
    bool proofClarityRenderable = false,
    bool firstProofPayoffVisible = false,
    List<BetaTesterOutcome>? outcomesOverride,
  }) {
    if (entryCount == 0) {
      return ProofToProPathModel.hidden.copyWith(
        reason: 'Empty first-run — proof before Pro',
      );
    }

    final meaningful = _hasMeaningfulProof(
      entryCount: entryCount,
      hasMeaningfulProof: hasMeaningfulProof,
    );
    final showClarity = _proofClarityShowable(
      entryCount: entryCount,
      hasMeaningfulProof: hasMeaningfulProof,
      proofClarityRenderable: proofClarityRenderable,
      outcomesOverride: outcomesOverride,
    );

    final showProBridge =
        meaningful &&
        showClarity &&
        allowsProPackaging(outcomesOverride: outcomesOverride) &&
        _proPackagingApplies(
          entryCount: entryCount,
          hasMeaningfulProof: hasMeaningfulProof,
          outcomesOverride: outcomesOverride,
        );

    final showPaywallCopy = allowsProPackaging(
      outcomesOverride: outcomesOverride,
    );

    final suppressStandalone =
        showProBridge && showClarity && firstProofPayoffVisible;

    return ProofToProPathModel(
      showProofEmotionalClarity: showClarity,
      showProPackagingBridge: showProBridge,
      showProPackagingPaywallCopy: showPaywallCopy,
      suppressStandaloneProBridgeCard: suppressStandalone,
      reason: _reason(
        showClarity: showClarity,
        showProBridge: showProBridge,
        meaningful: meaningful,
      ),
    );
  }

  static bool shouldShowProofEmotionalClarity({
    required int entryCount,
    required bool hasMeaningfulProof,
    bool proofClarityRenderable = false,
    List<BetaTesterOutcome>? outcomesOverride,
  }) => build(
    entryCount: entryCount,
    hasMeaningfulProof: hasMeaningfulProof,
    proofClarityRenderable: proofClarityRenderable,
    outcomesOverride: outcomesOverride,
  ).showProofEmotionalClarity;

  static bool shouldShowProPackagingBridge({
    required int entryCount,
    required bool hasMeaningfulProof,
    bool proofClarityRenderable = false,
    List<BetaTesterOutcome>? outcomesOverride,
  }) => build(
    entryCount: entryCount,
    hasMeaningfulProof: hasMeaningfulProof,
    proofClarityRenderable: proofClarityRenderable,
    outcomesOverride: outcomesOverride,
  ).showProPackagingBridge;

  static bool shouldSuppressStandaloneProBridgeCard({
    required int entryCount,
    required bool hasMeaningfulProof,
    required bool firstProofPayoffVisible,
    bool proofClarityRenderable = false,
    List<BetaTesterOutcome>? outcomesOverride,
  }) => build(
    entryCount: entryCount,
    hasMeaningfulProof: hasMeaningfulProof,
    proofClarityRenderable: proofClarityRenderable,
    firstProofPayoffVisible: firstProofPayoffVisible,
    outcomesOverride: outcomesOverride,
  ).suppressStandaloneProBridgeCard;

  static String _reason({
    required bool showClarity,
    required bool showProBridge,
    required bool meaningful,
  }) {
    if (!meaningful) return 'Waiting for meaningful proof';
    if (showClarity && showProBridge) {
      return isProofToProOverride()
          ? 'proofToPro override — clarity then quiet Pro bridge'
          : 'Proof clarity shown — quiet Pro bridge after meaningful proof';
    }
    if (showClarity)
      return 'Proof clarity first — Pro bridge gated until packaging branch';
    return 'Proof-to-Pro path inactive';
  }
}
