import 'package:archiveme_mobile/api/adapters/api_envelope_adapter.dart';
import 'package:archiveme_mobile/api/dio/retrofit_api_executor.dart';
import 'package:archiveme_mobile/api/models/billing_dto.dart';
import 'package:archiveme_mobile/api/retrofit/voice_memory_billing_api.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/billing_api_client.dart';
import 'package:archiveme_mobile/models/checkout_session.dart';
import 'package:archiveme_mobile/models/entitlement.dart';

/// Billing REST boundary backed by Dio + Retrofit.
class RetrofitBillingApiClient implements BillingApiClient {
  RetrofitBillingApiClient(this._api);

  final VoiceMemoryBillingApi _api;

  @override
  Future<ApiResult<PremiumEntitlements>> getEntitlements({
    NetworkCancelToken? cancelToken,
  }) async {
    if (!RetrofitApiExecutor.isBackendConfigured) {
      return ApiSuccess(PremiumEntitlements.free());
    }
    return RetrofitApiExecutor.run(() async {
      final response = await _api.getEntitlements();
      if (response.error?.code == 'AUTH_REQUIRED') {
        throw const ApiFailureAuthRequired();
      }
      if (response.error?.code == 'BILLING_DISABLED') {
        return PremiumEntitlements.free();
      }
      return response.envelope
          .toDomainResult(
            map: _mapEntitlements,
            missingDataMessage: 'Entitlements payload missing',
          )
          .when(
            success: (value) => value,
            onFailure: (failure) {
              if (failure is ApiFailureAuthRequired) {
                throw failure;
              }
              return PremiumEntitlements.free();
            },
          );
    }, cancelToken: cancelToken);
  }

  @override
  Future<ApiResult<CheckoutSession>> createCheckoutSession({
    NetworkCancelToken? cancelToken,
  }) async {
    if (!RetrofitApiExecutor.isBackendConfigured) {
      return const ApiFailureResult(ApiFailureBackendNotConfigured());
    }
    return RetrofitApiExecutor.run(() async {
      final response = await _api.createCheckout();
      if (response.error?.code == 'AUTH_REQUIRED') {
        throw const ApiFailureAuthRequired();
      }
      if (response.error?.code == 'BILLING_DISABLED') {
        throw const ApiFailureBillingUnavailable();
      }
      return response.envelope
          .toDomainResult(
            map: _mapCheckout,
            missingDataMessage: 'Checkout payload missing',
          )
          .when(
            success: (value) => value,
            onFailure: (failure) => throw failure,
          );
    }, cancelToken: cancelToken);
  }

  PremiumEntitlements _mapEntitlements(BillingEntitlementsDataDto dto) {
    return PremiumEntitlements.fromJson(dto.toJson());
  }

  CheckoutSession _mapCheckout(BillingCheckoutDataDto dto) {
    if (dto.url.isEmpty) {
      throw const FormatException('Checkout URL missing');
    }
    return CheckoutSession(url: dto.url, sessionId: dto.sessionId);
  }
}
