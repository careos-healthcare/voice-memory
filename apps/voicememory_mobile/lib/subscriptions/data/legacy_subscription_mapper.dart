import '../../features/monetization/domain/generated/monetization_policy.g.dart';
import '../../models/entitlement.dart';
import '../domain/subscription_models.dart';

abstract final class LegacySubscriptionMapper {
  static String get legacyProEntitlementId =>
      MonetizationPolicy.acceptedLegacyEntitlementAliases.single;

  static SubscriptionState fromEntitlements(PremiumEntitlements value) {
    final entitlementIds = value.entitlementIds
        .map(
          (id) =>
              MonetizationPolicy.acceptedLegacyEntitlementAliases.contains(id)
              ? SubscriptionEntitlements.pro
              : id,
        )
        .toSet()
        .toList(growable: false);
    return SubscriptionState(
      tier: value.isPro ? SubscriptionTier.pro : SubscriptionTier.free,
      entitlementIds: entitlementIds,
      billingConnected: value.billingConnected,
      origin: _originFromSource(value.source),
      verifiedAt: value.verifiedAt,
      verification: switch (value.verification) {
        EntitlementVerification.verified => SubscriptionVerification.verified,
        EntitlementVerification.cached => SubscriptionVerification.cached,
        EntitlementVerification.unavailable =>
          SubscriptionVerification.unavailable,
      },
      expirationDate: value.expirationDate,
      willRenew: value.willRenew,
      unsubscribeDetectedAt: value.unsubscribeDetectedAt,
      billingIssueDetectedAt: value.billingIssueDetectedAt,
      productIdentifier: value.productIdentifier,
      accessKind: value.accessKind,
      subscriptionState: value.subscriptionState,
    );
  }

  static PremiumEntitlements toEntitlements(SubscriptionState value) {
    return PremiumEntitlements(
      tier: value.isPro ? BillingTier.pro : BillingTier.free,
      entitlementIds: value.entitlementIds,
      billingConnected: value.billingConnected,
      source: _sourceFromOrigin(value.origin),
      verifiedAt: value.verifiedAt,
      verification: switch (value.verification) {
        SubscriptionVerification.verified => EntitlementVerification.verified,
        SubscriptionVerification.cached => EntitlementVerification.cached,
        SubscriptionVerification.unavailable =>
          EntitlementVerification.unavailable,
      },
      expirationDate: value.expirationDate,
      willRenew: value.willRenew,
      unsubscribeDetectedAt: value.unsubscribeDetectedAt,
      billingIssueDetectedAt: value.billingIssueDetectedAt,
      productIdentifier: value.productIdentifier,
      accessKind: value.accessKind,
      subscriptionState: value.subscriptionState,
    );
  }

  static SubscriptionStateOrigin _originFromSource(String source) {
    return switch (source) {
      'revenuecat' => SubscriptionStateOrigin.store,
      'backend' => SubscriptionStateOrigin.backend,
      'auth_required' => SubscriptionStateOrigin.auth,
      'offline_cache_restore' => SubscriptionStateOrigin.offline,
      'local_placeholder' => SubscriptionStateOrigin.local,
      'cache' || 'test-cache' => SubscriptionStateOrigin.cache,
      'backend_refresh_unavailable' ||
      'billing_load_unavailable' ||
      'revenuecat_not_configured' ||
      'revenuecat_refresh_unavailable' ||
      'revenuecat_refresh_error' ||
      'revenuecat_stale' => SubscriptionStateOrigin.unavailable,
      _ => SubscriptionStateOrigin.unknown,
    };
  }

  static String _sourceFromOrigin(SubscriptionStateOrigin origin) {
    return switch (origin) {
      SubscriptionStateOrigin.local => 'local_placeholder',
      SubscriptionStateOrigin.cache => 'cache',
      SubscriptionStateOrigin.store => 'store',
      SubscriptionStateOrigin.backend => 'backend',
      SubscriptionStateOrigin.auth => 'auth_required',
      SubscriptionStateOrigin.offline => 'offline_cache_restore',
      SubscriptionStateOrigin.unavailable => 'billing_unavailable',
      SubscriptionStateOrigin.unknown => 'unknown',
    };
  }
}
