/// Central RevenueCat / ArchiveMe loop-map Pro entitlement identifiers.
abstract class ArchiveLoopEntitlementIds {
  ArchiveLoopEntitlementIds._();

  /// Primary entitlement id for ArchiveMe loop-map Pro in RevenueCat.
  static const archiveLoopPro = 'archive_loop_pro';

  /// Legacy RevenueCat entitlement id still honored for existing subscribers.
  static const revenueCatLegacyPro = 'pro';

  /// Entitlement ids checked when mapping RevenueCat customer info to Pro access.
  static const revenueCatEntitlementIds = [archiveLoopPro, revenueCatLegacyPro];

  /// Preferred id for purchase/restore success logs.
  static const logEntitlementId = archiveLoopPro;
}
