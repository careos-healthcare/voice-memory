import '../../core/network/api_failure.dart';
import '../../core/network/api_failure_mapper.dart';
import '../../core/network/api_result.dart';
import '../../core/network/http_transport.dart';
import '../../models/session.dart';
import 'auth_api_client.dart';

class HttpAuthApiClient implements AuthApiClient {
  HttpAuthApiClient(this._transport);

  final HttpTransport _transport;

  @override
  Future<ApiResult<void>> sendAuthCode(String email) async {
    final responseResult = await _transport.post(
      '/api/auth/send-code',
      body: {'email': email.trim()},
    );
    return responseResult.when(
      success: (response) => _transport.expectSuccess(response),
      onFailure: ApiFailureResult.new,
    );
  }

  @override
  Future<ApiResult<AuthVerifyPayload>> verifyAuthCode({
    required String email,
    required String code,
  }) async {
    final responseResult = await _transport.post(
      '/api/auth/verify',
      body: {'email': email.trim(), 'code': code.trim()},
    );
    return responseResult.when(
      success: (response) {
        final success = _transport.expectSuccess(response);
        if (success case ApiFailureResult<void>(:final failure)) {
          return ApiFailureResult(failure);
        }
        final decoded = _transport.decodeSuccess(response, (body) => body);
        return decoded.when(
          success: (body) {
            final sessionJson = body['session'] as Map<String, dynamic>?;
            if (sessionJson == null) {
              return ApiFailureResult(
                ApiFailureInvalidResponse(
                  message: 'No session in response',
                  responseCode: response.statusCode,
                ),
              );
            }
            return ApiSuccess(
              AuthVerifyPayload(
                session: UserSession.fromJson(sessionJson),
                sessionCookie: extractSessionCookie(response),
              ),
            );
          },
          onFailure: ApiFailureResult.new,
        );
      },
      onFailure: ApiFailureResult.new,
    );
  }

  @override
  Future<ApiResult<UserSession?>> getSession() async {
    if (_transport.tryUri('/api/auth/session') == null) {
      return const ApiSuccess(null);
    }
    final responseResult = await _transport.get('/api/auth/session');
    return responseResult.when(
      success: (response) {
        if (response.statusCode == 401) {
          return const ApiSuccess(null);
        }
        if (response.statusCode >= 500) {
          return ApiFailureResult(ApiFailureMapper.fromResponse(response));
        }
        return _transport.decodeSuccess(response, (body) {
          final session = body['session'];
          if (session == null) return null;
          return UserSession.fromJson(session as Map<String, dynamic>);
        });
      },
      onFailure: ApiFailureResult.new,
    );
  }

  @override
  Future<ApiResult<void>> signOut() async {
    final responseResult = await _transport.post('/api/auth/signout');
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
