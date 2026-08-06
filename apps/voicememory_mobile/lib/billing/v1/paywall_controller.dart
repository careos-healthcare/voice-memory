import 'package:purchases_flutter/purchases_flutter.dart';

import '../../models/entitlement.dart';

/// Immutable paywall state — no side effects during [build].
class PaywallState {
  const PaywallState({
    this.loadingOfferings = true,
    this.selectedPackage,
    this.tier = BillingTier.free,
    this.purchaseInFlight = false,
    this.restoreInFlight = false,
    this.errorMessage,
    this.unavailable = false,
  });

  final bool loadingOfferings;
  final Package? selectedPackage;
  final BillingTier tier;
  final bool purchaseInFlight;
  final bool restoreInFlight;
  final String? errorMessage;
  final bool unavailable;

  bool get canPurchase =>
      !loadingOfferings &&
      !purchaseInFlight &&
      !restoreInFlight &&
      !unavailable &&
      selectedPackage != null;

  PaywallState copyWith({
    bool? loadingOfferings,
    Package? selectedPackage,
    BillingTier? tier,
    bool? purchaseInFlight,
    bool? restoreInFlight,
    String? errorMessage,
    bool? unavailable,
  }) {
    return PaywallState(
      loadingOfferings: loadingOfferings ?? this.loadingOfferings,
      selectedPackage: selectedPackage ?? this.selectedPackage,
      tier: tier ?? this.tier,
      purchaseInFlight: purchaseInFlight ?? this.purchaseInFlight,
      restoreInFlight: restoreInFlight ?? this.restoreInFlight,
      errorMessage: errorMessage ?? this.errorMessage,
      unavailable: unavailable ?? this.unavailable,
    );
  }
}

/// Side-effect boundary for paywall — offerings load, purchase, restore, and
/// entitlement refresh happen here, never during widget build.
class PaywallController {
  PaywallState _state = const PaywallState();

  PaywallState get state => _state;

  void replace(PaywallState next) {
    _state = next;
  }
}
