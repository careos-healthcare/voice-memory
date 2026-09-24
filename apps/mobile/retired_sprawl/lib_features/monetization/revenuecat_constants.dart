/// RevenueCat dashboard identifiers for ArchiveMe continuity.
abstract final class RevenueCatConstants {
  RevenueCatConstants._();

  /// Legacy entitlement still active for existing subscribers.
  static const pro = 'pro';

  /// Current entitlement for ArchiveMe loop-map Pro.
  static const archiveLoopPro = 'archive_loop_pro';

  static const entitlementIds = <String>[pro, archiveLoopPro];

  /// Identifier of the dashboard's current offering.
  ///
  /// Purchases still prefer `offerings.current` when this id is absent.
  static const currentOfferingId = String.fromEnvironment(
    'REVENUECAT_OFFERING_ID',
    defaultValue: 'default',
  );

  static const monthlyProductId = 'archive_loop_pro_monthly';
  static const yearlyProductId = 'archive_loop_pro_yearly';
}
