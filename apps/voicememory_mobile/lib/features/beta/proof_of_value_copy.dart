/// Copy for the proof of value diagnostics card — developer only.
abstract final class ProofOfValueCopy {
  ProofOfValueCopy._();

  static const cardTitle = 'Proof of value';

  static const primaryQuestion =
      'Did ArchiveMe show something repeating in their own words that they wanted to keep tracking?';

  static const summaryNotEnoughEvidence = 'Not enough tester evidence yet';

  static const summaryActivationNotProven = 'Activation is not proven yet';

  static const summaryFirstProofNotProven = 'First proof is not proven yet';

  static const summarySpecificityNotProven = 'Specificity is not proven yet';

  static const summaryRetentionNotProven = 'Retention intent is not proven yet';

  static const summaryPaymentNotProven = 'Payment intent is not proven yet';

  static const summaryEmerging = 'Proof of value is emerging';

  static const summaryStrong = 'Strong early proof of value';

  static const statusProven = 'Proven';

  static const statusNotProven = 'Not proven';

  static const statusWarning = 'Warning';

  static const statusCheckManually = 'Check manually';

  static const statusNotEnoughData = 'Not enough data';

  static const recommendationRunMoreTesters = 'Run more testers.';

  static const recommendationFixFirstUse = 'Fix first-use clarity.';

  static const recommendationFixReturnLoop = 'Fix return loop.';

  static const recommendationFixFirstProof = 'Fix first proof activation.';

  static const recommendationFixEvidence = 'Fix evidence specificity.';

  static const recommendationStrengthenRetention = 'Strengthen retention value.';

  static const recommendationStrengthenPro = 'Strengthen Pro value.';

  static const recommendationWidenBeta = 'Widen beta.';

  static const rowFirstSave = 'First save';

  static const rowSecondSave = 'Second save';

  static const rowFirstProof = 'First proof';

  static const rowCoreValueYes = 'Core value yes';

  static const rowFeltGeneric = 'Felt generic';

  static const rowWouldKeepUsing = 'Would keep using';

  static const rowWouldPay = 'Would pay';

  static const rowReturnCheck = 'Return check';

  static const questionFirstSave = 'Did testers start?';

  static const questionSecondSave = 'Did testers return?';

  static const questionFirstProof = 'Did testers reach the aha moment?';

  static const questionCoreValueYes =
      'Did it show something worth tracking?';

  static const questionFeltGeneric = 'Did proof feel generic?';

  static const questionWouldKeepUsing = 'Would they keep tracking it?';

  static const questionWouldPay = 'Would anyone pay?';

  static const questionReturnCheck = 'Did they understand change tracking?';

  static const localAnswerPrefix = 'Local answer';

  static const noManualCountYet = 'Check manually';

  static String valueLabel(int current, int total) => '$current / $total';

  static String targetLabel(int target, int total) => '$target / $total';

  static String localAnswerLabel(String answer) => '$localAnswerPrefix: $answer';
}
