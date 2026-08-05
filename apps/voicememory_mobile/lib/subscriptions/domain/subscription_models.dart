import '../../billing/archive_loop_entitlement_ids.dart';

enum SubscriptionTier { free, pro }

enum SubscriptionVerification { verified, cached, unavailable }

enum SubscriptionStateOrigin {
  local,
  cache,
  store,
  backend,
  auth,
  offline,
  unavailable,
  unknown,
}

enum SubscriptionPeriod { weekly, monthly, annual, lifetime, unknown }

enum SubscriptionAvailability { available, unavailable, notConfigured }

abstract final class SubscriptionEntitlements {
  static const String pro = ArchiveLoopEntitlementIds.archiveLoopPro;
}

class SubscriptionState {
  const SubscriptionState({
    required this.tier,
    required this.entitlementIds,
    required this.billingConnected,
    required this.origin,
    this.verifiedAt,
    this.verification = SubscriptionVerification.verified,
    this.expirationDate,
    this.willRenew,
    this.unsubscribeDetectedAt,
    this.billingIssueDetectedAt,
    this.productIdentifier,
  });

  factory SubscriptionState.free({
    SubscriptionStateOrigin origin = SubscriptionStateOrigin.local,
  }) => SubscriptionState(
    tier: SubscriptionTier.free,
    entitlementIds: const [],
    billingConnected: false,
    origin: origin,
    verification: SubscriptionVerification.unavailable,
  );

  factory SubscriptionState.fromJson(Map<String, dynamic> json) {
    final verificationName = json['verification'] as String?;
    final verification = SubscriptionVerification.values
        .where((value) => value.name == verificationName)
        .firstOrNull;
    return SubscriptionState(
      tier: json['tier'] == 'pro'
          ? SubscriptionTier.pro
          : SubscriptionTier.free,
      entitlementIds: (json['entitlements'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      billingConnected: json['billingConnected'] as bool? ?? false,
      origin: _originFromJson(json['source'] as String?),
      verifiedAt: DateTime.tryParse(json['verifiedAt'] as String? ?? ''),
      verification: verification ?? SubscriptionVerification.verified,
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
    );
  }

  static SubscriptionStateOrigin _originFromJson(String? source) {
    final canonical = SubscriptionStateOrigin.values
        .where((value) => value.name == source)
        .firstOrNull;
    if (canonical != null) return canonical;
    return switch (source) {
      'auth_required' => SubscriptionStateOrigin.auth,
      'offline_cache_restore' => SubscriptionStateOrigin.offline,
      'local_placeholder' => SubscriptionStateOrigin.local,
      'revenuecat' => SubscriptionStateOrigin.store,
      'backend_refresh_unavailable' ||
      'billing_load_unavailable' ||
      'billing_unavailable' ||
      'revenuecat_not_configured' ||
      'revenuecat_refresh_unavailable' ||
      'revenuecat_refresh_error' ||
      'revenuecat_stale' => SubscriptionStateOrigin.unavailable,
      _ => SubscriptionStateOrigin.unknown,
    };
  }

  final SubscriptionTier tier;
  final List<String> entitlementIds;
  final bool billingConnected;
  final SubscriptionStateOrigin origin;
  final DateTime? verifiedAt;
  final SubscriptionVerification verification;
  final DateTime? expirationDate;
  final bool? willRenew;
  final DateTime? unsubscribeDetectedAt;
  final DateTime? billingIssueDetectedAt;
  final String? productIdentifier;

  bool get isPro => tier == SubscriptionTier.pro;
  bool get isVerified => verification == SubscriptionVerification.verified;
  bool get canDowngrade => !isPro && isVerified;

  Map<String, dynamic> toJson() => {
    'tier': tier.name,
    'entitlements': entitlementIds,
    'billingConnected': billingConnected,
    'source': origin.name,
    'verification': verification.name,
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

  SubscriptionState copyWith({
    SubscriptionTier? tier,
    List<String>? entitlementIds,
    bool? billingConnected,
    SubscriptionStateOrigin? origin,
    DateTime? verifiedAt,
    SubscriptionVerification? verification,
    DateTime? expirationDate,
    bool? willRenew,
    DateTime? unsubscribeDetectedAt,
    DateTime? billingIssueDetectedAt,
    String? productIdentifier,
  }) => SubscriptionState(
    tier: tier ?? this.tier,
    entitlementIds: entitlementIds ?? this.entitlementIds,
    billingConnected: billingConnected ?? this.billingConnected,
    origin: origin ?? this.origin,
    verifiedAt: verifiedAt ?? this.verifiedAt,
    verification: verification ?? this.verification,
    expirationDate: expirationDate ?? this.expirationDate,
    willRenew: willRenew ?? this.willRenew,
    unsubscribeDetectedAt: unsubscribeDetectedAt ?? this.unsubscribeDetectedAt,
    billingIssueDetectedAt:
        billingIssueDetectedAt ?? this.billingIssueDetectedAt,
    productIdentifier: productIdentifier ?? this.productIdentifier,
  );
}

class SubscriptionOffer {
  const SubscriptionOffer({
    required this.id,
    required this.productIdentifier,
    required this.price,
    required this.period,
    this.title,
    this.description,
    this.hasFreeTrial = false,
    this.introductoryPrice,
    this.introductoryPeriod,
    this.introductoryCycles,
  });

  final String id;
  final String productIdentifier;
  final String price;
  final SubscriptionPeriod period;
  final String? title;
  final String? description;
  final bool hasFreeTrial;
  final String? introductoryPrice;
  final String? introductoryPeriod;
  final int? introductoryCycles;

  /// Store-supplied introductory terms only; null means no intro copy.
  String? get introductoryDisplay {
    final price = introductoryPrice?.trim();
    final period = introductoryPeriod?.trim();
    final cycles = introductoryCycles;
    if (price == null ||
        price.isEmpty ||
        period == null ||
        period.isEmpty ||
        cycles == null ||
        cycles <= 0) {
      return null;
    }
    final term = cycles == 1 ? period : '$cycles × $period';
    return hasFreeTrial ? 'Free for $term' : '$price for $term';
  }
}

class SubscriptionCheckout {
  const SubscriptionCheckout({required this.url, this.sessionId});

  final String url;
  final String? sessionId;
}

class SubscriptionDiagnostics {
  const SubscriptionDiagnostics({
    required this.availability,
    this.offersLoaded = false,
    this.offerCount = 0,
    this.lastError,
  });

  final SubscriptionAvailability availability;
  final bool offersLoaded;
  final int offerCount;
  final String? lastError;
}

enum SubscriptionPurchaseFailureKind {
  cancelled,
  temporary,
  pending,
  productUnavailable,
  verification,
  unexpected,
}

class SubscriptionPurchaseException implements Exception {
  const SubscriptionPurchaseException(this.kind, {required this.cause});

  final SubscriptionPurchaseFailureKind kind;
  final Object cause;

  bool get isCancelled => kind == SubscriptionPurchaseFailureKind.cancelled;

  @override
  String toString() => 'SubscriptionPurchaseException(${kind.name}, $cause)';
}

class SubscriptionRestoreException implements Exception {
  const SubscriptionRestoreException({required this.cause});

  final Object cause;

  @override
  String toString() => 'SubscriptionRestoreException($cause)';
}

class SubscriptionAuthRequiredException implements Exception {
  const SubscriptionAuthRequiredException();
}

class SubscriptionAccountChangedException implements Exception {
  const SubscriptionAccountChangedException();
}
