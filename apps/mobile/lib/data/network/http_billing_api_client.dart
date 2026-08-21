import 'package:archiveme_mobile/api/models/billing_dto.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_failure_mapper.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/http_transport.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/core/network/voice_memory_api_routes.dart';
import 'package:archiveme_mobile/data/network/billing_api_client.dart';
import 'package:archiveme_mobile/models/checkout_session.dart';
import 'package:archiveme_mobile/models/entitlement.dart';

class HttpBillingApiClient implements BillingApiClient {
  HttpBillingApiClient(this._transport);

  final HttpTransport _transport;

  @override
  Future<ApiResult<PremiumEntitlements>> getEntitlements({
    NetworkCancelToken? cancelToken,
  }) async {
    if (_transport.tryUri(VoiceMemoryApiRoutes.billingEntitlements.path) == null) {
      return ApiSuccess(PremiumEntitlements.free());
    }
    final responseResult = await _transport.get(
      VoiceMemoryApiRoutes.billingEntitlements.path,
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
        return _transport.decodeEnvelope(
          response,
          parseData: BillingEntitlementsDataDto.fromJson,
          toDomain: (dto) => PremiumEntitlements.fromJson(dto.toJson()),
          missingDataMessage: 'Entitlements payload missing',
        );
      },
      onFailure: ApiFailureResult.new,
    );
  }

  @override
  Future<ApiResult<CheckoutSession>> createCheckoutSession({
    NetworkCancelToken? cancelToken,
  }) async {
    final responseResult = await _transport.post(
      VoiceMemoryApiRoutes.billingCheckout.path,
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
        return _transport.decodeEnvelope(
          response,
          parseData: BillingCheckoutDataDto.fromJson,
          toDomain: _mapCheckout,
          missingDataMessage: 'Checkout payload missing',
        );
      },
      onFailure: ApiFailureResult.new,
    );
  }

  CheckoutSession _mapCheckout(BillingCheckoutDataDto dto) {
    if (dto.url.isEmpty) {
      throw const FormatException('Checkout URL missing');
    }
    return CheckoutSession(url: dto.url, sessionId: dto.sessionId);
  }
}
