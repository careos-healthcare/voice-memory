import '../../models/checkout_session.dart';
import '../../core/network/api_failure.dart';
import '../../core/network/api_failure_mapper.dart';
import '../../core/network/api_result.dart';
import '../../core/network/http_transport.dart';
import '../../core/network/network_cancel_token.dart';
import '../../models/entitlement.dart';
import 'billing_api_client.dart';

class HttpBillingApiClient implements BillingApiClient {
  HttpBillingApiClient(this._transport);

  final HttpTransport _transport;

  @override
  Future<ApiResult<PremiumEntitlements>> getEntitlements({
    NetworkCancelToken? cancelToken,
  }) async {
    if (_transport.tryUri('/api/billing/entitlements') == null) {
      return ApiSuccess(PremiumEntitlements.free());
    }
    final responseResult = await _transport.get(
      '/api/billing/entitlements',
      cancelToken: cancelToken,
    );
    return responseResult.when(
      success: (response) {
        if (response.statusCode == 401) {
          return const ApiFailureResult(ApiFailureAuthRequired());
        }
        if (response.statusCode == 503) {
          return ApiSuccess(PremiumEntitlements.free());
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return ApiSuccess(PremiumEntitlements.free());
        }
        return _transport.decodeSuccess(response, PremiumEntitlements.fromJson);
      },
      onFailure: ApiFailureResult.new,
    );
  }

  @override
  Future<ApiResult<CheckoutSession>> createCheckoutSession({
    NetworkCancelToken? cancelToken,
  }) async {
    final responseResult = await _transport.post(
      '/api/billing/checkout',
      cancelToken: cancelToken,
    );
    return responseResult.when(
      success: (response) {
        if (response.statusCode == 401) {
          return const ApiFailureResult(ApiFailureAuthRequired());
        }
        if (response.statusCode == 503) {
          return const ApiFailureResult(ApiFailureBillingUnavailable());
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return ApiFailureResult(ApiFailureMapper.fromResponse(response));
        }
        return _transport.decodeSuccess(response, (body) {
          final url = body['url'] as String?;
          if (url == null || url.isEmpty) {
            throw FormatException('Checkout URL missing');
          }
          return CheckoutSession(
            url: url,
            sessionId: body['sessionId'] as String?,
          );
        });
      },
      onFailure: ApiFailureResult.new,
    );
  }
}
