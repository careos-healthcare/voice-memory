/// QA-safe RevenueCat state — never shown verbatim in consumer UI.
class RevenueCatDiagnostics {
  const RevenueCatDiagnostics({
    required this.revenueCatConfigured,
    required this.apiKeyMissing,
    required this.offeringsLoaded,
    required this.offeringCount,
    required this.packageCount,
    this.requestedOfferingId,
    this.currentOfferingId,
    this.productIdentifiers = const [],
    this.lastRevenueCatError,
  });

  factory RevenueCatDiagnostics.initial() => const RevenueCatDiagnostics(
        revenueCatConfigured: false,
        apiKeyMissing: true,
        offeringsLoaded: false,
        offeringCount: 0,
        packageCount: 0,
      );

  final bool revenueCatConfigured;
  final bool apiKeyMissing;
  final bool offeringsLoaded;
  final int offeringCount;
  final int packageCount;
  final String? requestedOfferingId;
  final String? currentOfferingId;
  final List<String> productIdentifiers;
  final String? lastRevenueCatError;

  RevenueCatDiagnostics copyWith({
    bool? revenueCatConfigured,
    bool? apiKeyMissing,
    bool? offeringsLoaded,
    int? offeringCount,
    int? packageCount,
    String? requestedOfferingId,
    String? currentOfferingId,
    List<String>? productIdentifiers,
    String? lastRevenueCatError,
    bool clearError = false,
  }) {
    return RevenueCatDiagnostics(
      revenueCatConfigured: revenueCatConfigured ?? this.revenueCatConfigured,
      apiKeyMissing: apiKeyMissing ?? this.apiKeyMissing,
      offeringsLoaded: offeringsLoaded ?? this.offeringsLoaded,
      offeringCount: offeringCount ?? this.offeringCount,
      packageCount: packageCount ?? this.packageCount,
      requestedOfferingId: requestedOfferingId ?? this.requestedOfferingId,
      currentOfferingId: currentOfferingId ?? this.currentOfferingId,
      productIdentifiers: productIdentifiers ?? this.productIdentifiers,
      lastRevenueCatError:
          clearError ? null : (lastRevenueCatError ?? this.lastRevenueCatError),
    );
  }

  Map<String, Object?> toJson() => {
        'revenueCatConfigured': revenueCatConfigured,
        'apiKeyMissing': apiKeyMissing,
        'offeringsLoaded': offeringsLoaded,
        'offeringCount': offeringCount,
        'packageCount': packageCount,
        'requestedOfferingId': requestedOfferingId,
        'currentOfferingId': currentOfferingId,
        'productIdentifiers': productIdentifiers,
        'lastRevenueCatError': lastRevenueCatError,
      };
}
