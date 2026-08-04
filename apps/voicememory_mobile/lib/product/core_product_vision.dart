import 'auditable_change_positioning.dart';

/// Single source of truth for ArchiveMe's first-launch value proposition.
///
/// Every value here delegates to [AuditableChangePositioning] so the launch
/// surfaces and the store listings cannot drift apart.
abstract final class CoreProductVision {
  CoreProductVision._();

  static const valueProposition = AuditableChangePositioning.full;

  static const promise = AuditableChangePositioning.primaryPromise;

  static const category = AuditableChangePositioning.category;

  /// App Store subtitle limit: 30 characters.
  static const appStoreSubtitle = AuditableChangePositioning.appStoreSubtitle;

  /// Google Play short-description limit: 80 characters.
  static const playStoreShortDescription =
      AuditableChangePositioning.playStoreShortDescription;
}
