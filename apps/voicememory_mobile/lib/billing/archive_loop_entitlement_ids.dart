import '../features/monetization/domain/generated/monetization_policy.g.dart';

/// Central RevenueCat / ArchiveMe loop-map Pro entitlement identifiers.
abstract class ArchiveLoopEntitlementIds {
  ArchiveLoopEntitlementIds._();

  /// Primary entitlement id for ArchiveMe loop-map Pro in RevenueCat.
  static const archiveLoopPro = MonetizationPolicy.canonicalProEntitlementId;

  /// Legacy RevenueCat entitlement id still honored for existing subscribers.
  static String get revenueCatLegacyPro =>
      MonetizationPolicy.acceptedLegacyEntitlementAliases.single;

  /// Entitlement ids checked when mapping RevenueCat customer info to Pro access.
  static const revenueCatEntitlementIds = [
    archiveLoopPro,
    ...MonetizationPolicy.acceptedLegacyEntitlementAliases,
  ];

  /// Preferred id for purchase/restore success logs.
  static const logEntitlementId = archiveLoopPro;
}
