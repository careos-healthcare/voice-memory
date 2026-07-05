import '../first_proof_payoff/first_proof_payoff_model.dart';

/// Visibility gates for the first proof action loop card.
abstract final class FirstProofActionLoopGates {
  FirstProofActionLoopGates._();

  static bool shouldShow({
    required bool showFirstProofPayoff,
    required FirstProofPayoff? payoff,
    required String proofKey,
    required bool hasAnsweredForProof,
  }) =>
      showFirstProofPayoff &&
      payoff != null &&
      proofKey.isNotEmpty &&
      hasAnsweredForProof;
}
