import 'proof_repair_outcome_matrix.dart';
import 'proof_repair_playbooks_copy.dart';

/// Build 63 proof repair playbooks — interpretation only, no product changes.
abstract final class ProofRepairPlaybooks {
  ProofRepairPlaybooks._();

  static ProofRepairPlaybookPlan fromOutcome(
    ProofRepairOutcomeDecision decision,
  ) {
    final playbook = _playbookFor(decision);
    return ProofRepairPlaybookPlan(
      playbook: playbook,
      title: ProofRepairPlaybooksCopy.titleFor(playbook),
      problem: ProofRepairPlaybooksCopy.problemFor(playbook),
      action: ProofRepairPlaybooksCopy.actionFor(playbook),
      allowedChanges: ProofRepairPlaybooksCopy.allowedChangesFor(playbook),
      blockedChanges: ProofRepairPlaybooksCopy.blockedChangesFor(playbook),
      successMetric: ProofRepairPlaybooksCopy.successMetricFor(playbook),
    );
  }

  static ProofRepairPlaybook _playbookFor(
    ProofRepairOutcomeDecision decision,
  ) => switch (decision) {
    ProofRepairOutcomeDecision.insufficientData =>
      ProofRepairPlaybook.waitForMoreData,
    ProofRepairOutcomeDecision.repairProofAgain =>
      ProofRepairPlaybook.repairProofAgain,
    ProofRepairOutcomeDecision.tightenAnchorsAgain =>
      ProofRepairPlaybook.tightenAnchorsAgain,
    ProofRepairOutcomeDecision.proofStableReturnToEvidenceTrail =>
      ProofRepairPlaybook.returnToEvidenceTrail,
    ProofRepairOutcomeDecision.productionCandidate =>
      ProofRepairPlaybook.productionReadiness,
  };
}

enum ProofRepairPlaybook {
  repairProofAgain,
  tightenAnchorsAgain,
  returnToEvidenceTrail,
  waitForMoreData,
  productionReadiness,
}

class ProofRepairPlaybookPlan {
  const ProofRepairPlaybookPlan({
    required this.playbook,
    required this.title,
    required this.problem,
    required this.action,
    required this.allowedChanges,
    required this.blockedChanges,
    required this.successMetric,
  });

  final ProofRepairPlaybook playbook;
  final String title;
  final String problem;
  final String action;
  final List<String> allowedChanges;
  final List<String> blockedChanges;
  final String successMetric;
}
