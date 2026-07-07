import '../paywall_value_sharpening/paywall_value_sharpening_copy.dart';

/// Canonical ArchiveMe Pro paywall alignment copy — display only, no billing logic.
abstract final class PaywallAlignmentCopy {
  PaywallAlignmentCopy._();

  static const headline = PaywallValueSharpeningCopy.genericHeadline;

  static const body = PaywallValueSharpeningCopy.body;

  static const secondaryReassurance =
      PaywallValueSharpeningCopy.secondaryReassurance;

  static const corePaidReason = PaywallValueSharpeningCopy.corePaidReason;

  static const benefitBullets = PaywallValueSharpeningCopy.benefitBullets;

  /// Compact bridge line — avoids repeating the full paywall body on lock cards.
  static const lockMomentPaidReason =
      'Pro keeps the full timeline — correction history, private reports, and evidence over time.';

  static const monthlyReportProReason =
      'Pro keeps the full timeline — and the longer report history.';

  static const backupBridgeBody =
      'You are building evidence over time. Pro keeps the full timeline as it grows.';

  static const backupProPreservation =
      'Pro is built around keeping the full timeline.';

  static List<String> allPaywallStrings() => [
        headline,
        body,
        secondaryReassurance,
        PaywallValueSharpeningCopy.proofConnectedLine,
        ...benefitBullets,
      ];
}
