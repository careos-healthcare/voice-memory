import 'capacity_beta_signal_models.dart';

/// Copy for local capacity beta signal dashboard — cautious beta language.
abstract final class CapacityBetaSignalCopy {
  CapacityBetaSignalCopy._();

  static const route = '/capacity-beta-signals';

  static const screenTitle = 'Capacity beta signals';
  static const subtitle =
      'Local activation and fit signals only. No private entries are shown.';

  static const emptyBody =
      'No capacity wedge signals yet. Save yes moments in the capacity loop first.';

  static const activationSectionTitle = 'Activation';
  static const fitSectionTitle = 'Fit';
  static const evidenceSectionTitle = 'Evidence depth';
  static const returnSectionTitle = 'Return signal';
  static const paymentSectionTitle = 'Payment signal';
  static const verdictSectionTitle = 'Local beta verdict';

  static const savedYesMomentsLabel = 'Saved yes moments';
  static const activationReachedLabel = 'Activation reached';
  static const loopFitResponseLabel = 'Loop fit response';
  static const pullReasonRecordsLabel = 'Pull reason records';
  static const outcomeRecordsLabel = 'Outcome records';
  static const laterCostRecordsLabel = 'Later-cost records';
  static const weeklyReviewAvailableLabel = 'Weekly review available';
  static const boundarySelectedLabel = 'Boundary response selected';
  static const boundaryCopiedLabel = 'Boundary response copied';
  static const proInterestSeenLabel = 'Pro interest seen/tapped';
  static const paymentSignalLabel = 'Payment signal';
  static const openCapacityLoopButton = 'Open capacity loop';

  static const yesLabel = 'yes';
  static const noLabel = 'no';
  static const notAnsweredLabel = 'not answered';
  static const skippedLabel = 'skipped';
  static const paymentNotTrackedLabel = 'Payment signal not tracked yet';

  static const cardTitle = 'Capacity beta signals';
  static const cardBody = 'Review local activation and fit signals.';
  static const openDashboardButton = 'Open capacity beta signals';
  static const copySummaryButton = 'Copy signal summary';
  static const summaryCopied = 'Capacity beta signal summary copied';

  static const supportTitle = 'Capacity beta signals';
  static const supportSubtitle =
      'Review local capacity wedge activation, fit, and return signals.';
  static const openFromSupportButton = openDashboardButton;

  static const betaInviteLinkButton = openDashboardButton;

  static const verdictStrong = 'Strong local signal';
  static const verdictPromising = 'Promising local signal';
  static const verdictWeak = 'Weak activation signal';
  static const verdictUnclear = 'Unclear signal';

  static const verdictDisclaimer =
      'Local counts only. This is not proof of payment intent or wedge fit.';

  static String savedYesMomentsValue(int count, int target) => '$count/$target';

  static String activationReachedValue(bool reached) =>
      reached ? yesLabel : noLabel;

  static String yesNo(bool value) => value ? yesLabel : noLabel;

  static String verdictLabelFor(CapacityBetaSignalVerdict verdict) =>
      switch (verdict) {
        CapacityBetaSignalVerdict.strong => verdictStrong,
        CapacityBetaSignalVerdict.promising => verdictPromising,
        CapacityBetaSignalVerdict.weak => verdictWeak,
        CapacityBetaSignalVerdict.unclear => verdictUnclear,
      };

  static List<String> allVisibleStrings() => [
        screenTitle,
        subtitle,
        emptyBody,
        activationSectionTitle,
        fitSectionTitle,
        evidenceSectionTitle,
        returnSectionTitle,
        paymentSectionTitle,
        verdictSectionTitle,
        savedYesMomentsLabel,
        activationReachedLabel,
        loopFitResponseLabel,
        pullReasonRecordsLabel,
        outcomeRecordsLabel,
        laterCostRecordsLabel,
        weeklyReviewAvailableLabel,
        boundarySelectedLabel,
        boundaryCopiedLabel,
        proInterestSeenLabel,
        paymentSignalLabel,
        openCapacityLoopButton,
        cardTitle,
        cardBody,
        openDashboardButton,
        copySummaryButton,
        summaryCopied,
        supportTitle,
        supportSubtitle,
        verdictStrong,
        verdictPromising,
        verdictWeak,
        verdictUnclear,
        verdictDisclaimer,
        paymentNotTrackedLabel,
        notAnsweredLabel,
        skippedLabel,
      ];
}
