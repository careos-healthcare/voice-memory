import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/models/checkout_session.dart';
import 'package:archiveme_mobile/models/entitlement.dart';

/// Billing HTTP boundary — returns [ApiResult] instead of throwing.
abstract interface class BillingApiClient {
  Future<ApiResult<PremiumEntitlements>> getEntitlements({
    NetworkCancelToken? cancelToken,
  });

  Future<ApiResult<CheckoutSession>> createCheckoutSession({
    NetworkCancelToken? cancelToken,
  });
}