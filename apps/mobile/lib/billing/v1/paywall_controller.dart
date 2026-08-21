import 'package:archiveme_mobile/billing/v1/paywall_dependencies.dart';
import 'package:archiveme_mobile/billing/v1/paywall_offerings_loader.dart';
import 'package:archiveme_mobile/billing/v1/paywall_plan.dart';
import 'package:archiveme_mobile/models/entitlement.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Immutable paywall state — no side effects during [build].
class PaywallState {
  const PaywallState({
    this.loadingOfferings = true,
    this.offeringsReloading = false,
    this.offerings,
    this.entitlements,
    this.selectedPlan = PaywallPlan.yearly,
    this.purchaseInFlight = false,
    this.restoreInFlight = false,
    this.errorMessage,
    this.unavailable = false,
    this.billingConfigured = false,
  });

  final bool loadingOfferings;
  final bool offeringsReloading;
  final Offerings? offerings;
  final PremiumEntitlements? entitlements;
  final PaywallPlan selectedPlan;
  final bool purchaseInFlight;
  final bool restoreInFlight;
  final String? errorMessage;
  final bool unavailable;
  final bool billingConfigured;

  bool get isPro => entitlements?.isPro ?? false;

  bool get isBusy => purchaseInFlight || restoreInFlight;

  bool get hasPackages {
    final packages = offerings?.current?.availablePackages;
    return packages != null && packages.isNotEmpty;
  }

  bool get purchasePlansAvailable => billingConfigured && hasPackages;

  Package? get selectedPackage => packageFor(selectedPlan);

  Package? packageFor(PaywallPlan plan) {
    final current = offerings?.current;
    if (current == null) return null;
    for (final package in current.availablePackages) {
      if (plan == PaywallPlan.monthly &&
          package.packageType == PackageType.monthly) {
        return package;
      }
      if (plan == PaywallPlan.yearly &&
          package.packageType == PackageType.annual) {
        return package;
      }
    }
    return null;
  }

  String? priceStringFor(PaywallPlan plan) =>
      packageFor(plan)?.storeProduct.priceString;

  bool get canPurchase =>
      !loadingOfferings &&
      !offeringsReloading &&
      !purchaseInFlight &&
      !restoreInFlight &&
      !unavailable &&
      purchasePlansAvailable &&
      selectedPackage != null;

  PaywallState copyWith({
    bool? loadingOfferings,
    bool? offeringsReloading,
    Offerings? offerings,
    PremiumEntitlements? entitlements,
    PaywallPlan? selectedPlan,
    bool? purchaseInFlight,
    bool? restoreInFlight,
    String? errorMessage,
    bool? unavailable,
    bool? billingConfigured,
    bool clearError = false,
  }) {
    return PaywallState(
      loadingOfferings: loadingOfferings ?? this.loadingOfferings,
      offeringsReloading: offeringsReloading ?? this.offeringsReloading,
      offerings: offerings ?? this.offerings,
      entitlements: entitlements ?? this.entitlements,
      selectedPlan: selectedPlan ?? this.selectedPlan,
      purchaseInFlight: purchaseInFlight ?? this.purchaseInFlight,
      restoreInFlight: restoreInFlight ?? this.restoreInFlight,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      unavailable: unavailable ?? this.unavailable,
      billingConfigured: billingConfigured ?? this.billingConfigured,
    );
  }
}

/// Side-effect boundary for paywall — offerings load, purchase, restore, and
/// entitlement refresh happen here, never during widget build.
class PaywallController {
  PaywallController({required PaywallDependencies dependencies})
    : _dependencies = dependencies,
      _loader = PaywallOfferingsLoader(dependencies: dependencies);

  final PaywallDependencies _dependencies;
  final PaywallOfferingsLoader _loader;

  PaywallState _state = const PaywallState();

  PaywallState get state => _state;

  void replace(PaywallState next) {
    _state = next;
  }

  void selectPlan(PaywallPlan plan) {
    _state = _state.copyWith(selectedPlan: plan);
  }

  Future<void> loadOfferings({bool isRetry = false}) async {
    _state = _state.copyWith(
      loadingOfferings: !isRetry || _state.loadingOfferings,
      offeringsReloading: isRetry,
      clearError: !isRetry,
    );

    final result = await _loader.load(
      currentPlan: _state.selectedPlan,
      isRetry: isRetry,
    );

    _state = _state.copyWith(
      loadingOfferings: false,
      offeringsReloading: false,
      offerings: result.offerings,
      entitlements: result.entitlements,
      selectedPlan: result.selectedPlan,
      billingConfigured: result.billingConfigured,
      errorMessage: result.errorMessage,
      unavailable: result.unavailable || !result.purchasePlansAvailable,
    );
  }

  Future<PremiumEntitlements?> purchaseSelectedPackage() async {
    final package = _state.selectedPackage;
    if (package == null) return null;

    _state = _state.copyWith(purchaseInFlight: true);
    try {
      final entitlements = await _dependencies.purchasePackage(package);
      _state = _state.copyWith(
        entitlements: entitlements,
        purchaseInFlight: false,
      );
      return entitlements;
    } catch (_, stackTrace) {
      _state = _state.copyWith(purchaseInFlight: false);
      rethrow;
    }
  }

  Future<void> applyEntitlements(PremiumEntitlements entitlements) async {
    _state = _state.copyWith(entitlements: entitlements);
  }

  Future<void> beginRestore() async {
    _state = _state.copyWith(restoreInFlight: true);
  }

  Future<void> endRestore() async {
    _state = _state.copyWith(restoreInFlight: false);
  }
}