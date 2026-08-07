import '../../core/network/api_result.dart';
import '../../models/session.dart';

/// Auth REST boundary — implemented with [HttpTransport].
abstract class AuthApiClient {
  Future<ApiResult<void>> sendAuthCode(String email);

  Future<ApiResult<AuthVerifyPayload>> verifyAuthCode({
    required String email,
    required String code,
  });

  Future<ApiResult<UserSession?>> getSession();

  Future<ApiResult<void>> signOut();
}

class AuthVerifyPayload {
  const AuthVerifyPayload({required this.session, this.sessionCookie});

  final UserSession session;
  final String? sessionCookie;
}
