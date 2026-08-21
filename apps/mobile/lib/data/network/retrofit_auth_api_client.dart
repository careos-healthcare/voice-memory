import 'package:archiveme_mobile/api/adapters/api_envelope_adapter.dart';
import 'package:archiveme_mobile/api/dio/retrofit_api_executor.dart';
import 'package:archiveme_mobile/api/dio/session_cookie_capture.dart';
import 'package:archiveme_mobile/api/retrofit/voice_memory_auth_api.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/auth_api_client.dart';
import 'package:archiveme_mobile/models/session.dart';

/// Auth REST boundary backed by Dio + Retrofit.
class RetrofitAuthApiClient implements AuthApiClient {
  RetrofitAuthApiClient(
    this._api, {
    SessionCookieCapture? sessionCookieCapture,
  }) : _sessionCookieCapture = sessionCookieCapture ?? SessionCookieCapture();

  final VoiceMemoryAuthApi _api;
  final SessionCookieCapture _sessionCookieCapture;

  @override
  Future<ApiResult<void>> sendAuthCode(
    String email, {
    NetworkCancelToken? cancelToken,
  }) async {
    if (!RetrofitApiExecutor.isBackendConfigured) {
      return const ApiFailureResult(ApiFailureBackendNotConfigured());
    }
    return RetrofitApiExecutor.run(() async {
      final response = await _api.sendCode({'email': email.trim()});
      return response.toVoidDomainResult().when(
        success: (_) => null,
        onFailure: (failure) => throw failure,
      );
    }, cancelToken: cancelToken);
  }

  @override
  Future<ApiResult<AuthVerifyPayload>> verifyAuthCode({
    required String email,
    required String code,
    NetworkCancelToken? cancelToken,
  }) async {
    if (!RetrofitApiExecutor.isBackendConfigured) {
      return const ApiFailureResult(ApiFailureBackendNotConfigured());
    }
    return RetrofitApiExecutor.run(() async {
      _sessionCookieCapture.clear();
      final response = await _api.verify({
        'email': email.trim(),
        'code': code.trim(),
      });
      return response.envelope
          .toDomainResult(
            map: (data) => AuthVerifyPayload(
              session: data.session.toDomain(),
              sessionCookie: _sessionCookieCapture.lastSetCookie,
            ),
            missingDataMessage: 'No session in response',
          )
          .when(
            success: (value) => value,
            onFailure: (failure) => throw failure,
          );
    }, cancelToken: cancelToken);
  }

  @override
  Future<ApiResult<UserSession?>> getSession({
    NetworkCancelToken? cancelToken,
  }) async {
    if (!RetrofitApiExecutor.isBackendConfigured) {
      return const ApiSuccess(null);
    }
    return RetrofitApiExecutor.run(() async {
      final response = await _api.getSession();
      return response.envelope
          .toNullableDomainResult(map: (data) => data.toDomain())
          .when(
            success: (value) => value,
            onFailure: (failure) => throw failure,
          );
    }, cancelToken: cancelToken);
  }

  @override
  Future<ApiResult<void>> signOut({NetworkCancelToken? cancelToken}) async {
    if (!RetrofitApiExecutor.isBackendConfigured) {
      return const ApiSuccess(null);
    }
    return RetrofitApiExecutor.run(() async {
      final response = await _api.signOut();
      if (response.error?.code == 'AUTH_REQUIRED') {
        return null;
      }
      return response.toVoidDomainResult().when(
        success: (_) => null,
        onFailure: (failure) {
          if (failure is ApiFailureAuthRequired) {
            return null;
          }
          throw failure;
        },
      );
    }, cancelToken: cancelToken);
  }
}
