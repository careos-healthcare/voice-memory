import 'package:archiveme_mobile/features/paywall_value_sharpening/paywall_value_sharpening_copy.dart';

/// Canonical ArchiveMe Pro paywall alignment copy — display only, no billing logic.
abstract final class PaywallAlignmentCopy {
  PaywallAlignmentCopy._();

  static const String headline = PaywallValueSharpeningCopy.genericHeadline;

  static const String body = PaywallValueSharpeningCopy.body;

  static const String secondaryReassurance =
      PaywallValueSharpeningCopy.secondaryReassurance;

  static const String corePaidReason = PaywallValueSharpeningCopy.corePaidReason;

  static const List<String> benefitBullets = PaywallValueSharpeningCopy.benefitBullets;

  /// Compact bridge line — avoids repeating the full paywall body on lock cards.
  static const lockMomentPaidReason =
      'Pro keeps the longer proof trail — what returns, changes, fades, or gets corrected over time.';

  static const monthlyReportProReason =
      'Pro keeps the longer proof trail over time.';

  static const backupBridgeBody =
      'You are building evidence over time. Pro keeps the longer proof trail as moments return, change, or fade.';

  static const backupProPreservation =
      'Pro is built around keeping the longer proof trail.';

  static List<String> allPaywallStrings() => [
    headline,
    body,
    secondaryReassurance,
    PaywallValueSharpeningCopy.proofConnectedLine,
    ...benefitBullets,
  ];
}