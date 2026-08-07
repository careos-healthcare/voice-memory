import '../../api/api_client.dart' show CheckoutSession;
import '../../core/network/api_result.dart';
import '../../core/network/network_cancel_token.dart';
import '../../models/entitlement.dart';

/// Billing HTTP boundary — returns [ApiResult] instead of throwing.
abstract interface class BillingApiClient {
  Future<ApiResult<PremiumEntitlements>> getEntitlements({
    NetworkCancelToken? cancelToken,
  });

  Future<ApiResult<CheckoutSession>> createCheckoutSession({
    NetworkCancelToken? cancelToken,
  });
}
