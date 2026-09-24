import 'package:archiveme_mobile/features/monetization/revenuecat_constants.dart';

/// Central RevenueCat / ArchiveMe loop-map Pro entitlement identifiers.
abstract class ArchiveLoopEntitlementIds {
  ArchiveLoopEntitlementIds._();

  /// Primary entitlement id for ArchiveMe loop-map Pro in RevenueCat.
  static const String archiveLoopPro = RevenueCatConstants.archiveLoopPro;

  /// Legacy RevenueCat entitlement id still honored for existing subscribers.
  static const String revenueCatLegacyPro = RevenueCatConstants.pro;

  /// Per-seat professional coach dashboard entitlement in RevenueCat.
  static const professionalCoachPerSeat = String.fromEnvironment(
    'REVENUECAT_COACH_SEAT_ENTITLEMENT_ID',
    defaultValue: 'professional_coach_per_seat',
  );

  /// Entitlement ids checked when mapping RevenueCat customer info to Pro access.
  static const List<String> revenueCatEntitlementIds = [
    archiveLoopPro,
    revenueCatLegacyPro,
  ];

  /// Preferred id for purchase/restore success logs.
  static const String logEntitlementId = archiveLoopPro;
}
