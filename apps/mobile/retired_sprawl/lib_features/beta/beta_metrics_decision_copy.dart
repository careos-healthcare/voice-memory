/// Copy for the internal beta metrics decision card — developer diagnostics only.
abstract final class BetaMetricsDecisionCopy {
  BetaMetricsDecisionCopy._();

  static const cardTitle = 'Beta metrics decision';

  static const statusReady = 'Ready';

  static const statusBelowTarget = 'Below target';

  static const statusCheckManually = 'Check manually';

  static const statusNotEnoughData = 'Not enough data';

  static const likelyIssue = 'Likely issue';

  static const noDecisionYet = 'No decision yet';

  static const summaryNotEnoughData = 'Not enough tester data yet';

  static const summaryFirstScreen = 'First screen is the bottleneck';

  static const summaryReturnLoop = 'Return loop is the bottleneck';

  static const summaryFirstProof = 'First proof activation is the bottleneck';

  static const summaryEvidence = 'Evidence specificity is the bottleneck';

  static const summaryRetention = 'Retention value is the bottleneck';

  static const summaryMonetisation = 'Monetisation value is the bottleneck';

  static const summaryHealthy = 'Early beta signal looks healthy';

  static const rowFirstSave = 'First save';

  static const rowSecondSave = 'Second save';

  static const rowFirstProof = 'First proof';

  static const rowSpecificProof = 'Specific proof';

  static const rowWouldContinue = 'Would continue';

  static const rowWouldPay = 'Would pay';

  static const fixFirstUse = 'First-use / capture copy';

  static const fixReturnHandoff = 'Post-save handoff / reminders';

  static const fixActivationJourney = '1→2→3 journey';

  static const fixEvidence = 'Extraction / chips / proof copy';

  static const fixRetention = 'Timeline / report / weekly loop';

  static const fixMonetisation = 'Pro boundary / full archive value';

  static const coreValueQuestion =
      'Did ArchiveMe show something repeating in your own words that was worth tracking?';

  static const coreValueFeedbackLabel = 'Core value feedback';

  static const problemFirstScreen = 'First screen problem';

  static const problemReturn = 'Return problem';

  static const problemActivation = 'Activation problem';

  static const problemEvidence = 'Evidence problem';

  static const problemRetention = 'Retention problem';

  static const problemMonetisation = 'Monetisation problem';

  static String valueLabel(int current, int total) => '$current / $total';

  static String targetLabel(int target, int total) => '$target / $total';
}
