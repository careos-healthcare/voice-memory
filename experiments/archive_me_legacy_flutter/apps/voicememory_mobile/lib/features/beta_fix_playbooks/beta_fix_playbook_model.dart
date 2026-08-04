import '../beta_validation_decision_matrix/beta_validation_decision_matrix_model.dart';
import 'beta_fix_playbook_copy.dart';

class BetaFixPlaybookResult {
  const BetaFixPlaybookResult({
    required this.outcome,
    required this.title,
    required this.diagnosis,
    required this.fixPlan,
    required this.doNotDo,
    required this.shouldShow,
  });

  static const hidden = BetaFixPlaybookResult(
    outcome: BetaValidationDecisionOutcome.insufficientData,
    title: '',
    diagnosis: '',
    fixPlan: [],
    doNotDo: [],
    shouldShow: false,
  );

  final BetaValidationDecisionOutcome outcome;
  final String title;
  final String diagnosis;
  final List<String> fixPlan;
  final List<String> doNotDo;
  final bool shouldShow;

  String get playbookTitle => BetaFixPlaybookCopy.titleFor(outcome);
}
