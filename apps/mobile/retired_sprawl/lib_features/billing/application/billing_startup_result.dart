import 'package:archiveme_mobile/models/entitlement.dart';

/// Where startup billing hydration sourced entitlements.
enum BillingStartupSource {
  sqliteCache,
  jsonCache,
  revenueCat,
  offlineFallback,
}

/// Result of [BillingNotifier.initializeOnStartup].
class BillingStartupResult {
  const BillingStartupResult({
    required this.entitlements,
    required this.source,
    required this.revenueCatChecked,
    required this.revenueCatReachable,
  });

  final PremiumEntitlements entitlements;
  final BillingStartupSource source;
  final bool revenueCatChecked;
  final bool revenueCatReachable;

  bool get isPro => entitlements.isPro;
}