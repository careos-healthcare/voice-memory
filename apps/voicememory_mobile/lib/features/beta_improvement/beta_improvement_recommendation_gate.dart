import '../beta_decision/beta_decision_engine.dart';
import '../beta_decision/beta_decision_model.dart';
import '../beta_decision/beta_tester_outcome_store.dart';
import 'beta_improvement_model.dart';
import 'proof_to_pro_path_engine.dart';

/// Resolves which beta improvement branch is active — one at a time.
abstract final class BetaImprovementRecommendationGate {
  BetaImprovementRecommendationGate._();

  static const buildDefineKey = 'ARCHIVEME_BETA_IMPROVEMENT_BRANCH';

  static BetaImprovementBranch activeBranch({
    List<BetaTesterOutcome>? outcomesOverride,
  }) {
    final fromDefine = _branchFromDefine();
    if (fromDefine != null) return fromDefine;

    final outcomes = outcomesOverride ?? BetaTesterOutcomeStore.allOutcomes;
    if (outcomes.isEmpty) return BetaImprovementBranch.none;

    final result = BetaDecisionEngine.build(outcomes: outcomes);
    return _mapRecommendation(
      result.primaryRecommendation,
      expansionAllowed: result.expansionAllowed,
    );
  }

  static bool isBranchActive(
    BetaImprovementBranch branch, {
    List<BetaTesterOutcome>? outcomesOverride,
  }) => activeBranch(outcomesOverride: outcomesOverride) == branch;

  static bool evidenceAllowsBranch({
    required BetaImprovementBranch branch,
    required int entryCount,
    required bool hasMeaningfulProof,
    bool expansionAllowed = false,
  }) => switch (branch) {
    BetaImprovementBranch.recordOnboardingCopy => entryCount <= 1,
    BetaImprovementBranch.captureFriction => entryCount == 0,
    BetaImprovementBranch.returnReason => entryCount >= 1 && entryCount <= 2,
    BetaImprovementBranch.proofEmotionalClarity => entryCount >= 3,
    BetaImprovementBranch.proPackaging => hasMeaningfulProof,
    BetaImprovementBranch.proUtility => hasMeaningfulProof && expansionAllowed,
    BetaImprovementBranch.none => false,
  };

  static bool shouldApplyBranch({
    required BetaImprovementBranch branch,
    required int entryCount,
    required bool hasMeaningfulProof,
    List<BetaTesterOutcome>? outcomesOverride,
  }) {
    if (!isBranchActive(branch, outcomesOverride: outcomesOverride)) {
      return false;
    }
    final outcomes = outcomesOverride ?? BetaTesterOutcomeStore.allOutcomes;
    final expansionAllowed = outcomes.isEmpty
        ? false
        : BetaDecisionEngine.build(outcomes: outcomes).expansionAllowed;
    return evidenceAllowsBranch(
      branch: branch,
      entryCount: entryCount,
      hasMeaningfulProof: hasMeaningfulProof,
      expansionAllowed: expansionAllowed,
    );
  }

  static BetaImprovementBranch? _branchFromDefine() {
    const raw = String.fromEnvironment(buildDefineKey, defaultValue: '');
    if (raw.isEmpty) return null;
    return switch (raw) {
      'recordOnboardingCopy' => BetaImprovementBranch.recordOnboardingCopy,
      'captureFriction' => BetaImprovementBranch.captureFriction,
      'returnReason' => BetaImprovementBranch.returnReason,
      'proofEmotionalClarity' => BetaImprovementBranch.proofEmotionalClarity,
      'proPackaging' => BetaImprovementBranch.proPackaging,
      'proUtility' => BetaImprovementBranch.proUtility,
      'none' => BetaImprovementBranch.none,
      _ => null,
    };
  }

  static BetaImprovementBranch _mapRecommendation(
    BetaNextBuildRecommendation recommendation, {
    required bool expansionAllowed,
  }) => switch (recommendation) {
    BetaNextBuildRecommendation.fixRecordOnboardingCopy =>
      BetaImprovementBranch.recordOnboardingCopy,
    BetaNextBuildRecommendation.fixCaptureFriction =>
      BetaImprovementBranch.captureFriction,
    BetaNextBuildRecommendation.addReturnReason =>
      BetaImprovementBranch.returnReason,
    BetaNextBuildRecommendation.improveProofEmotionalClarity =>
      BetaImprovementBranch.proofEmotionalClarity,
    BetaNextBuildRecommendation.sharpenProPackaging =>
      BetaImprovementBranch.proPackaging,
    BetaNextBuildRecommendation.expandProUtility =>
      expansionAllowed
          ? BetaImprovementBranch.proUtility
          : BetaImprovementBranch.none,
    BetaNextBuildRecommendation.holdDoNotExpand ||
    BetaNextBuildRecommendation.insufficientData ||
    BetaNextBuildRecommendation.noFailingBranch => BetaImprovementBranch.none,
  };

  static String branchLabel(BetaImprovementBranch branch) {
    if (ProofToProPathEngine.isProofToProOverride()) {
      return 'Proof-to-Pro path (paired)';
    }
    return switch (branch) {
      BetaImprovementBranch.recordOnboardingCopy =>
        'Record/onboarding copy fix',
      BetaImprovementBranch.captureFriction => 'Capture friction fix',
      BetaImprovementBranch.returnReason => 'Return reminder plan',
      BetaImprovementBranch.proofEmotionalClarity => 'Proof emotional clarity',
      BetaImprovementBranch.proPackaging => 'Pro packaging',
      BetaImprovementBranch.proUtility => 'Pro utility preview',
      BetaImprovementBranch.none => 'None (baseline V1)',
    };
  }
}
