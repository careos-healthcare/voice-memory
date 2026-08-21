import 'package:archiveme_mobile/billing/archive_loop_entitlement_ids.dart';
import 'package:archiveme_mobile/core/json/json_converters.dart';

enum BillingTier { free, pro }

class PremiumEntitlements {
  const PremiumEntitlements({
    required this.tier,
    required this.entitlementIds,
    required this.billingConnected,
    required this.source,
  });

  factory PremiumEntitlements.free() => const PremiumEntitlements(
        tier: BillingTier.free,
        entitlementIds: [],
        billingConnected: false,
        source: 'local_placeholder',
      );

  factory PremiumEntitlements.fromJson(Map<String, dynamic> json) {
    final tierRaw = JsonConverters.stringOrEmpty(json['tier']);
    if (tierRaw.isEmpty) {
      return PremiumEntitlements.free();
    }
    final source = JsonConverters.stringOrEmpty(json['source']);
    return PremiumEntitlements(
      tier: tierRaw == 'pro' ? BillingTier.pro : BillingTier.free,
      entitlementIds: JsonConverters.stringList(json['entitlements']),
      billingConnected: JsonConverters.boolOrFalse(json['billingConnected']),
      source: source.isEmpty ? 'unknown' : source,
    );
  }

  final BillingTier tier;
  final List<String> entitlementIds;
  final bool billingConnected;
  final String source;

  bool get isPro => tier == BillingTier.pro;

  bool get hasProfessionalCoachSeat => entitlementIds.contains(
        ArchiveLoopEntitlementIds.professionalCoachPerSeat,
      );

  Map<String, dynamic> toJson() => {
        'tier': tier == BillingTier.pro ? 'pro' : 'free',
        'entitlements': entitlementIds,
        'billingConnected': billingConnected,
        'source': source,
      };
}
