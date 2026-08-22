import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/http_transport.dart' show HttpTransport;
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/models/session.dart';

/// Auth REST boundary — implemented with [HttpTransport].
abstract class AuthApiClient {
  Future<ApiResult<void>> sendAuthCode(
    String email, {
    NetworkCancelToken? cancelToken,
  });

  Future<ApiResult<AuthVerifyPayload>> verifyAuthCode({
    required String email,
    required String code,
    NetworkCancelToken? cancelToken,
  });

  Future<ApiResult<UserSession?>> getSession({NetworkCancelToken? cancelToken});

  Future<ApiResult<void>> signOut({NetworkCancelToken? cancelToken});
}

class AuthVerifyPayload {
  const AuthVerifyPayload({required this.session, this.sessionCookie});

  final UserSession session;
  final String? sessionCookie;
}