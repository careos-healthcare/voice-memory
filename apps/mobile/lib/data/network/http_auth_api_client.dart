import 'package:archiveme_mobile/api/models/auth_dto.dart';
import 'package:archiveme_mobile/core/network/api_failure_mapper.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/http_transport.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/core/network/voice_memory_api_routes.dart';
import 'package:archiveme_mobile/data/network/auth_api_client.dart';
import 'package:archiveme_mobile/models/session.dart';

class HttpAuthApiClient implements AuthApiClient {
  HttpAuthApiClient(this._transport);

  final HttpTransport _transport;

  @override
  Future<ApiResult<void>> sendAuthCode(
    String email, {
    NetworkCancelToken? cancelToken,
  }) async {
    final responseResult = await _transport.post(
      VoiceMemoryApiRoutes.authSendCode.path,
      body: {'email': email.trim()},
      cancelToken: cancelToken,
    );
    return responseResult.when(
      success: _transport.decodeEnvelopeOk,
      onFailure: ApiFailureResult.new,
    );
  }

  @override
  Future<ApiResult<AuthVerifyPayload>> verifyAuthCode({
    required String email,
    required String code,
    NetworkCancelToken? cancelToken,
  }) async {
    final responseResult = await _transport.post(
      VoiceMemoryApiRoutes.authVerify.path,
      body: {'email': email.trim(), 'code': code.trim()},
      cancelToken: cancelToken,
    );
    return responseResult.when(
      success: (response) => _transport.decodeEnvelope(
        response,
        parseData: AuthVerifyDataDto.fromJson,
        toDomain: (data) => AuthVerifyPayload(
          session: data.session.toDomain(),
          sessionCookie: extractSessionCookie(response),
        ),
        missingDataMessage: 'No session in response',
      ),
      onFailure: ApiFailureResult.new,
    );
  }

  @override
  Future<ApiResult<UserSession?>> getSession({
    NetworkCancelToken? cancelToken,
  }) async {
    if (_transport.tryUri(VoiceMemoryApiRoutes.authSession.path) == null) {
      return const ApiSuccess(null);
    }
    final responseResult = await _transport.get(
      VoiceMemoryApiRoutes.authSession.path,
      cancelToken: cancelToken,
    );
    return responseResult.when(
      success: (response) {
        if (response.statusCode == 401) {
          return const ApiSuccess(null);
        }
        if (response.statusCode >= 500) {
          return ApiFailureResult(ApiFailureMapper.fromResponse(response));
        }
        return _transport.decodeNullableEnvelope(
          response,
          parseData: AuthSessionDataDto.fromJson,
          toDomain: (data) => data.toDomain(),
        );
      },
      onFailure: ApiFailureResult.new,
    );
  }

  @override
  Future<ApiResult<void>> signOut({NetworkCancelToken? cancelToken}) async {
    final responseResult = await _transport.post(
      VoiceMemoryApiRoutes.authSignOut.path,
      cancelToken: cancelToken,
    );
    return responseResult.when(
      success: (response) {
        if (response.statusCode == 401 ||
            (response.statusCode >= 200 && response.statusCode < 300)) {
          return const ApiSuccess(null);
        }
        return ApiFailureResult(ApiFailureMapper.fromResponse(response));
      },
      onFailure: ApiFailureResult.new,
    );
  }
}
