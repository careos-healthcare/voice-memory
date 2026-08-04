// ignore_for_file: prefer_initializing_formals

import '../features/monetization/domain/generated/monetization_policy.g.dart';

enum BillingTier { free, pro }

enum EntitlementVerification { verified, cached, unavailable }

class PremiumEntitlements {
  // The public parameter stays `accessKind`; storage remains nullable so older
  // constructors derive the canonical plan from `tier`.
  const PremiumEntitlements({
    required this.tier,
    required this.entitlementIds,
    required this.billingConnected,
    required this.source,
    this.verifiedAt,
    this.verification = EntitlementVerification.verified,
    this.expirationDate,
    this.willRenew,
    this.unsubscribeDetectedAt,
    this.billingIssueDetectedAt,
    this.productIdentifier,
    PlanKind? accessKind,
    PolicySubscriptionState? subscriptionState,
  }) : _accessKind = accessKind,
       _subscriptionState = subscriptionState;

  final BillingTier tier;
  final List<String> entitlementIds;
  final bool billingConnected;
  final String source;
  final DateTime? verifiedAt;
  final EntitlementVerification verification;
  final DateTime? expirationDate;
  final bool? willRenew;
  final DateTime? unsubscribeDetectedAt;
  final DateTime? billingIssueDetectedAt;
  final String? productIdentifier;
  final PlanKind? _accessKind;
  final PolicySubscriptionState? _subscriptionState;

  bool get isPro => tier == BillingTier.pro;
  PlanKind get accessKind =>
      _accessKind ?? (isPro ? PlanKind.pro : PlanKind.free);
  bool get isVerified => verification == EntitlementVerification.verified;
  bool get canDowngrade => !isPro && isVerified;
  bool get isOfflineCacheFallback => source == 'offline_cache_restore';
  PolicySubscriptionState get subscriptionState {
    final explicit = _subscriptionState;
    if (explicit != null) return explicit;
    if (accessKind == PlanKind.legacyGrandfathered) {
      return PolicySubscriptionState.legacyGrandfathered;
    }
    if (verification == EntitlementVerification.unavailable) {
      return PolicySubscriptionState.unknown;
    }
    if (billingIssueDetectedAt != null) {
      return PolicySubscriptionState.billingIssue;
    }
    if (isPro) return PolicySubscriptionState.active;
    return entitlementIds.isEmpty
        ? PolicySubscriptionState.free
        : PolicySubscriptionState.revoked;
  }

  factory PremiumEntitlements.free() => const PremiumEntitlements(
    tier: BillingTier.free,
    entitlementIds: [],
    billingConnected: false,
    source: 'local_placeholder',
    verification: EntitlementVerification.unavailable,
  );

  Map<String, dynamic> toJson() => {
    'tier': tier == BillingTier.pro ? 'pro' : 'free',
    'entitlements': entitlementIds,
    'billingConnected': billingConnected,
    'source': source,
    'verification': verification.name,
    'accessKind': accessKind.name,
    'subscriptionState': subscriptionState.name,
    if (verifiedAt != null) 'verifiedAt': verifiedAt!.toUtc().toIso8601String(),
    if (expirationDate != null)
      'expirationDate': expirationDate!.toUtc().toIso8601String(),
    if (willRenew != null) 'willRenew': willRenew,
    if (unsubscribeDetectedAt != null)
      'unsubscribeDetectedAt': unsubscribeDetectedAt!.toUtc().toIso8601String(),
    if (billingIssueDetectedAt != null)
      'billingIssueDetectedAt': billingIssueDetectedAt!
          .toUtc()
          .toIso8601String(),
    if (productIdentifier != null) 'productIdentifier': productIdentifier,
  };

  factory PremiumEntitlements.fromJson(Map<String, dynamic> json) {
    final tierRaw = json['tier'] as String? ?? 'free';
    final ids = (json['entitlements'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final verificationName = json['verification'] as String?;
    final verification = EntitlementVerification.values
        .where((value) => value.name == verificationName)
        .firstOrNull;
    return PremiumEntitlements(
      tier: tierRaw == 'pro' ? BillingTier.pro : BillingTier.free,
      entitlementIds: ids,
      billingConnected: json['billingConnected'] as bool? ?? false,
      source: json['source'] as String? ?? 'unknown',
      verifiedAt: DateTime.tryParse(json['verifiedAt'] as String? ?? ''),
      // Version-one cache/backend payloads predate this field and represented
      // completed responses, so they remain verified for compatibility.
      verification: verification ?? EntitlementVerification.verified,
      expirationDate: DateTime.tryParse(
        json['expirationDate'] as String? ?? '',
      ),
      willRenew: json['willRenew'] as bool?,
      unsubscribeDetectedAt: DateTime.tryParse(
        json['unsubscribeDetectedAt'] as String? ?? '',
      ),
      billingIssueDetectedAt: DateTime.tryParse(
        json['billingIssueDetectedAt'] as String? ?? '',
      ),
      productIdentifier: json['productIdentifier'] as String?,
      subscriptionState: PolicySubscriptionState.values
          .where((value) => value.name == json['subscriptionState'])
          .firstOrNull,
      accessKind: _planKindFromJson(
        json['accessKind'],
        isPro: tierRaw == 'pro',
      ),
    );
  }

  static PlanKind _planKindFromJson(Object? raw, {required bool isPro}) {
    if (raw == 'proSubscription') return PlanKind.pro;
    return PlanKind.values.where((value) => value.name == raw).firstOrNull ??
        (isPro ? PlanKind.pro : PlanKind.free);
  }

  PremiumEntitlements copyWith({
    bool? billingConnected,
    String? source,
    DateTime? verifiedAt,
    EntitlementVerification? verification,
    DateTime? expirationDate,
    bool? willRenew,
    DateTime? unsubscribeDetectedAt,
    DateTime? billingIssueDetectedAt,
    String? productIdentifier,
    PlanKind? accessKind,
    PolicySubscriptionState? subscriptionState,
  }) => PremiumEntitlements(
    tier: tier,
    entitlementIds: entitlementIds,
    billingConnected: billingConnected ?? this.billingConnected,
    source: source ?? this.source,
    verifiedAt: verifiedAt ?? this.verifiedAt,
    verification: verification ?? this.verification,
    expirationDate: expirationDate ?? this.expirationDate,
    willRenew: willRenew ?? this.willRenew,
    unsubscribeDetectedAt: unsubscribeDetectedAt ?? this.unsubscribeDetectedAt,
    billingIssueDetectedAt:
        billingIssueDetectedAt ?? this.billingIssueDetectedAt,
    productIdentifier: productIdentifier ?? this.productIdentifier,
    accessKind: accessKind ?? this.accessKind,
    subscriptionState: subscriptionState ?? this.subscriptionState,
  );
}
