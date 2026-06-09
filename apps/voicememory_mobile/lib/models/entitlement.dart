enum BillingTier { free, pro }

class PremiumEntitlements {
  const PremiumEntitlements({
    required this.tier,
    required this.entitlementIds,
    required this.billingConnected,
    required this.source,
  });

  final BillingTier tier;
  final List<String> entitlementIds;
  final bool billingConnected;
  final String source;

  bool get isPro => tier == BillingTier.pro;

  factory PremiumEntitlements.free() => const PremiumEntitlements(
        tier: BillingTier.free,
        entitlementIds: [],
        billingConnected: false,
        source: 'local_placeholder',
      );

  Map<String, dynamic> toJson() => {
        'tier': tier == BillingTier.pro ? 'pro' : 'free',
        'entitlements': entitlementIds,
        'billingConnected': billingConnected,
        'source': source,
      };

  factory PremiumEntitlements.fromJson(Map<String, dynamic> json) {
    final tierRaw = json['tier'] as String? ?? 'free';
    final ids = (json['entitlements'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    return PremiumEntitlements(
      tier: tierRaw == 'pro' ? BillingTier.pro : BillingTier.free,
      entitlementIds: ids,
      billingConnected: json['billingConnected'] as bool? ?? false,
      source: json['source'] as String? ?? 'unknown',
    );
  }
}
