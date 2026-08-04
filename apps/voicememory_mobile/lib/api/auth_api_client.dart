import '../models/session.dart';
import 'api_exceptions.dart';
import 'api_transport.dart';

class AuthApiClient {
  AuthApiClient(this.transport);

  final ApiTransport transport;

  String? get sessionCookie => transport.sessionCookie;

  void setSessionCookie(String? cookie) => transport.setSessionCookie(cookie);

  Future<void> sendAuthCode(String email) async {
    await transport.postJson(
      '/api/auth/send-code',
      body: {'email': email.trim()},
    );
  }

  Future<UserSession> verifyAuthCode({
    required String email,
    required String code,
  }) async {
    final response = await transport.postJson(
      '/api/auth/verify',
      body: {'email': email.trim(), 'code': code.trim()},
    );
    final cookie = transport.extractSessionCookie(response);
    if (cookie != null) transport.setSessionCookie(cookie);
    final body = transport.decodeJson(response);
    final session = body['session'] as Map<String, dynamic>?;
    if (session == null) {
      throw ApiException(
        'No session in response',
        statusCode: response.statusCode,
      );
    }
    return UserSession.fromJson(session);
  }

  Future<UserSession?> getSession() async {
    final uri = transport.tryUri('/api/auth/session');
    if (uri == null) return null;
    final response = await transport.get(
      '/api/auth/session',
      acceptedStatusCodes: const {401},
    );
    if (response.statusCode == 401) return null;
    final body = transport.decodeJson(response);
    final session = body['session'];
    if (session == null) return null;
    return UserSession.fromJson(session as Map<String, dynamic>);
  }

  Future<void> signOut() async {
    await transport.postJson(
      '/api/auth/signout',
      acceptedStatusCodes: const {401},
    );
    transport.setSessionCookie(null);
  }

  Future<void> deleteAccount() async {
    await transport.postJson(
      '/api/account/delete',
      body: const {'confirm': true},
    );
    transport.setSessionCookie(null);
  }

  Future<void> registerPushDevice({
    required String deviceId,
    required String platform,
    required String fcmToken,
  }) async {
    await transport.postJson(
      '/api/push/register',
      body: {'deviceId': deviceId, 'platform': platform, 'fcmToken': fcmToken},
    );
  }

  Future<Map<String, dynamic>> sendInternalTestPush({
    required String deviceId,
    required String targetRoute,
    String? debugToken,
  }) async {
    final headers = Map<String, String>.from(transport.jsonHeaders);
    if (debugToken != null && debugToken.isNotEmpty) {
      headers['x-vm-debug-token'] = debugToken;
    }
    final response = await transport.postJson(
      '/api/internal/send-test-push',
      headers: headers,
      body: {'deviceId': deviceId, 'targetRoute': targetRoute},
    );
    return transport.decodeJson(response);
  }
}
