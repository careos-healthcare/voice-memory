import 'package:archiveme_mobile/features/proof_protection/proof_repair_playbooks.dart';

/// Build 63 proof repair playbook copy — interpretation only, no product changes.
abstract final class ProofRepairPlaybooksCopy {
  ProofRepairPlaybooksCopy._();

  static String titleFor(ProofRepairPlaybook playbook) => switch (playbook) {
    ProofRepairPlaybook.repairProofAgain => repairProofAgainTitle,
    ProofRepairPlaybook.tightenAnchorsAgain => tightenAnchorsAgainTitle,
    ProofRepairPlaybook.returnToEvidenceTrail => returnToEvidenceTrailTitle,
    ProofRepairPlaybook.waitForMoreData => waitForMoreDataTitle,
    ProofRepairPlaybook.productionReadiness => productionReadinessTitle,
  };

  static String problemFor(ProofRepairPlaybook playbook) => switch (playbook) {
    ProofRepairPlaybook.repairProofAgain => repairProofAgainProblem,
    ProofRepairPlaybook.tightenAnchorsAgain => tightenAnchorsAgainProblem,
    ProofRepairPlaybook.returnToEvidenceTrail => returnToEvidenceTrailProblem,
    ProofRepairPlaybook.waitForMoreData => waitForMoreDataProblem,
    ProofRepairPlaybook.productionReadiness => productionReadinessProblem,
  };

  static String actionFor(ProofRepairPlaybook playbook) => switch (playbook) {
    ProofRepairPlaybook.repairProofAgain => repairProofAgainAction,
    ProofRepairPlaybook.tightenAnchorsAgain => tightenAnchorsAgainAction,
    ProofRepairPlaybook.returnToEvidenceTrail => returnToEvidenceTrailAction,
    ProofRepairPlaybook.waitForMoreData => waitForMoreDataAction,
    ProofRepairPlaybook.productionReadiness => productionReadinessAction,
  };

  static List<String> allowedChangesFor(ProofRepairPlaybook playbook) =>
      switch (playbook) {
        ProofRepairPlaybook.repairProofAgain => repairProofAgainAllowed,
        ProofRepairPlaybook.tightenAnchorsAgain => tightenAnchorsAgainAllowed,
        ProofRepairPlaybook.returnToEvidenceTrail =>
          returnToEvidenceTrailAllowed,
        ProofRepairPlaybook.waitForMoreData => waitForMoreDataAllowed,
        ProofRepairPlaybook.productionReadiness => productionReadinessAllowed,
      };

  static List<String> blockedChangesFor(ProofRepairPlaybook playbook) =>
      switch (playbook) {
        ProofRepairPlaybook.repairProofAgain => repairProofAgainBlocked,
        ProofRepairPlaybook.tightenAnchorsAgain => tightenAnchorsAgainBlocked,
        ProofRepairPlaybook.returnToEvidenceTrail =>
          returnToEvidenceTrailBlocked,
        ProofRepairPlaybook.waitForMoreData => waitForMoreDataBlocked,
        ProofRepairPlaybook.productionReadiness => productionReadinessBlocked,
      };

  static String successMetricFor(
    ProofRepairPlaybook playbook,
  ) => switch (playbook) {
    ProofRepairPlaybook.repairProofAgain => repairProofAgainSuccessMetric,
    ProofRepairPlaybook.tightenAnchorsAgain => tightenAnchorsAgainSuccessMetric,
    ProofRepairPlaybook.returnToEvidenceTrail =>
      returnToEvidenceTrailSuccessMetric,
    ProofRepairPlaybook.waitForMoreData => waitForMoreDataSuccessMetric,
    ProofRepairPlaybook.productionReadiness => productionReadinessSuccessMetric,
  };

  static const repairProofAgainTitle = 'Repair proof again';
  static const repairProofAgainProblem =
      'Useful proof is still below target. ArchiveMe is not yet giving enough '
      'users a useful proof moment.';
  static const repairProofAgainAction =
      'Improve proof usefulness only. Keep Pro, pricing, and timeline work blocked.';
  static const repairProofAgainAllowed = [
    'Improve proof evidence selection',
    'Improve confirmed-repeat detection',
    'Improve safe-anchor selection',
    'Improve weak-proof fallback',
    'Improve proof copy only when it reduces overclaiming',
  ];
  static const repairProofAgainBlocked = [
    'Pro card changes',
    'Pricing changes',
    'Paywall changes',
    'Evidence trail card changes',
    'New features',
  ];
  static const repairProofAgainSuccessMetric =
      'Useful proof reaches target without increasing Too vague / Not relevant.';

  static const tightenAnchorsAgainTitle = 'Tighten anchors again';
  static const tightenAnchorsAgainProblem =
      'Too many users are marking proof as too vague or not relevant.';
  static const tightenAnchorsAgainAction =
      'Make anchors stricter. Show fewer proof surfaces unless the evidence is specific.';
  static const tightenAnchorsAgainAllowed = [
    'Reject generic anchors',
    'Reject system-like anchors',
    'Require stronger phrase specificity',
    'Require stronger match quality',
    'Downgrade weak anchors to watchOnly',
  ];
  static const tightenAnchorsAgainBlocked = [
    'Lowering proof thresholds',
    'Showing more proof to compensate',
    'Pro card changes',
    'Pricing changes',
    'Timeline changes',
  ];
  static const tightenAnchorsAgainSuccessMetric =
      'Too vague / Not relevant falls below threshold while useful proof remains acceptable.';

  static const returnToEvidenceTrailTitle = 'Return to evidence-trail clarity';
  static const returnToEvidenceTrailProblem =
      'Proof is stable enough. The next risk is whether users understand the longer '
      'Pro evidence trail.';
  static const returnToEvidenceTrailAction =
      'Resume evidence-trail clarity / Pro understanding test. Do not change proof unless it regresses.';
  static const returnToEvidenceTrailAllowed = [
    'Evidence trail clarity copy',
    'Pro explanation copy',
    'Pro understanding measurement',
    'Paywall CTA measurement',
  ];
  static const returnToEvidenceTrailBlocked = [
    'Proof engine changes',
    'Anchor changes',
    'Pricing changes',
    'New product features',
  ];
  static const returnToEvidenceTrailSuccessMetric =
      'Evidence trail clear and understands Pro reach target while useful proof stays stable.';

  static const waitForMoreDataTitle = 'Keep testing Build 63';
  static const waitForMoreDataProblem = 'There is not enough tester data.';
  static const waitForMoreDataAction =
      'Do not change the app. Collect more tester results.';
  static const waitForMoreDataAllowed = ['None'];
  static const waitForMoreDataBlocked = [
    'Product changes',
    'Proof changes',
    'Pro changes',
    'Pricing changes',
  ];
  static const waitForMoreDataSuccessMetric =
      'At least 20 testers complete the flow.';

  static const productionReadinessTitle = 'Move to production readiness';
  static const productionReadinessProblem = 'Proof and value signals pass.';
  static const productionReadinessAction =
      'Freeze product scope and finish App Store readiness.';
  static const productionReadinessAllowed = [
    'Store metadata',
    'Screenshots',
    'Privacy policy',
    'Support URL',
    'RevenueCat verification',
    'Restore purchase verification',
    'Secrets rotation',
  ];
  static const productionReadinessBlocked = [
    'Product features',
    'Proof changes',
    'Pro changes',
    'Pricing changes',
  ];
  static const productionReadinessSuccessMetric =
      'ProductionCandidateChecklist returns readyForSubmission.';

  static Iterable<String> allVisibleStrings() sync* {
    for (final playbook in ProofRepairPlaybook.values) {
      yield titleFor(playbook);
      yield problemFor(playbook);
      yield actionFor(playbook);
      yield successMetricFor(playbook);
      yield* allowedChangesFor(playbook);
      yield* blockedChangesFor(playbook);
    }
  }
}