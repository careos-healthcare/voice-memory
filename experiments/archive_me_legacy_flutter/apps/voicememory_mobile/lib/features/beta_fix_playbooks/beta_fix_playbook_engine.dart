import '../beta/archive_beta_mission_gate.dart';
import '../beta_validation_decision_matrix/beta_validation_decision_matrix_engine.dart';
import '../beta_validation_decision_matrix/beta_validation_decision_matrix_model.dart';
import '../revenue_readiness/revenue_readiness_dashboard_v2_model.dart';
import 'beta_fix_playbook_copy.dart';
import 'beta_fix_playbook_model.dart';

/// Inactive beta repair playbooks — guidance for validation outcomes only.
abstract final class BetaFixPlaybookEngine {
  BetaFixPlaybookEngine._();

  static bool shouldShow({required bool betaMissionEnabled}) =>
      betaMissionEnabled && ArchiveBetaMissionGate.isEnabled;

  static bool hasPlaybook(BetaValidationDecisionOutcome outcome) =>
      outcome != BetaValidationDecisionOutcome.insufficientData;

  static BetaFixPlaybookResult buildForOutcome(
    BetaValidationDecisionOutcome outcome,
  ) {
    if (!hasPlaybook(outcome)) {
      return BetaFixPlaybookResult.hidden;
    }
    return BetaFixPlaybookResult(
      outcome: outcome,
      title: BetaFixPlaybookCopy.titleFor(outcome),
      diagnosis: BetaFixPlaybookCopy.diagnosisFor(outcome),
      fixPlan: BetaFixPlaybookCopy.fixPlanFor(outcome),
      doNotDo: BetaFixPlaybookCopy.doNotDoFor(outcome),
      shouldShow: true,
    );
  }

  static BetaFixPlaybookResult fromValidationResult(
    BetaValidationDecisionMatrixResult result,
  ) => buildForOutcome(result.outcome);

  static BetaFixPlaybookResult fromRevenueInput(
    RevenueReadinessDashboardV2Input input,
  ) => fromValidationResult(
    BetaValidationDecisionMatrixEngine.fromRevenueInput(input),
  );
}
