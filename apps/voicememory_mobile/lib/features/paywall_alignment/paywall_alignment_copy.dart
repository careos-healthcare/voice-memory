/// Canonical ArchiveMe Pro paywall alignment copy — display only, no billing logic.
abstract final class PaywallAlignmentCopy {
  PaywallAlignmentCopy._();

  static const headline = 'Keep the full timeline';

  static const body =
      'Pro keeps what appeared, what returned, what you corrected, and what still matters now.';

  static const secondaryReassurance =
      'Free shows the first proof. Pro keeps the full timeline as it grows.';

  static const corePaidReason = 'Keep the full timeline.';

  static const benefitBullets = <String>[
    'Full pattern timeline',
    'Correction history',
    'Changing current weight',
    'Longer evidence trail',
    'Monthly private report',
    'Backup and continuity',
  ];

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
        ...benefitBullets,
      ];
}
