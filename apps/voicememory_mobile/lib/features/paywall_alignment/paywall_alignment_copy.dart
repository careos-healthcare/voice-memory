import '../../product/auditable_change_positioning.dart';
import '../paywall_value_sharpening/paywall_value_sharpening_copy.dart';

/// Canonical ArchiveMe Pro paywall alignment copy — display only, no billing logic.
abstract final class PaywallAlignmentCopy {
  PaywallAlignmentCopy._();

  static const headline = PaywallValueSharpeningCopy.genericHeadline;

  /// The category the paywall is selling more of — shown above [headline].
  static const positioningCategory = AuditableChangePositioning.category;

  /// The promise the paywall extends — shown under [headline].
  static const positioningLine = AuditableChangePositioning.primaryPromise;

  static const body = PaywallValueSharpeningCopy.body;

  static const secondaryReassurance =
      PaywallValueSharpeningCopy.secondaryReassurance;

  static const corePaidReason = PaywallValueSharpeningCopy.corePaidReason;

  static const benefitBullets = PaywallValueSharpeningCopy.benefitBullets;

  /// Compact bridge line — avoids repeating the full paywall body on lock cards.
  static const lockMomentPaidReason =
      'Pro generates new comparisons as more moments are added.';

  static const monthlyReportProReason =
      'Pro generates new periodic reviews from supporting evidence.';

  static const backupBridgeBody =
      'Your recordings stay yours. Pro generates new comparisons and deeper archive analysis.';

  static const backupProPreservation =
      'Pro is built around ongoing analysis, not access to your recordings.';

  static List<String> allPaywallStrings() => [
    positioningCategory,
    headline,
    positioningLine,
    body,
    secondaryReassurance,
    PaywallValueSharpeningCopy.proofConnectedLine,
    ...benefitBullets,
  ];
}
