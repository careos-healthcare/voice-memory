import '../api/api_client.dart';
import '../api/api_exceptions.dart';
import '../config/app_config.dart';
import '../models/entitlement.dart';

/// Billing — server entitlements read only; no native Stripe/IAP.
class BillingService {
  BillingService(this._api);

  final ApiClient _api;

  Future<PremiumEntitlements> loadEntitlements() async {
    if (!AppConfig.nativeBillingImplemented) {
      try {
        return await _api.getEntitlements();
      } on AuthRequiredException {
        return PremiumEntitlements.free();
      } on ApiException {
        return PremiumEntitlements.free();
      }
    }
    return _api.getEntitlements();
  }

  /// Opens web checkout in future via url_launcher — not implemented.
  Future<void> startCheckoutPlaceholder() async {
    throw NotImplementedNativeException('Stripe Checkout (use web app)');
  }
}
