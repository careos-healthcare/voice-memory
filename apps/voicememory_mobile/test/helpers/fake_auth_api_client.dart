import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:voicememory_mobile/core/di/network_providers.dart';
import 'package:voicememory_mobile/core/network/network_cancel_token.dart';
import 'package:voicememory_mobile/core/network/api_failure.dart';
import 'package:voicememory_mobile/core/network/api_result.dart';
import 'package:voicememory_mobile/core/network/session_cookie_source.dart';
import 'package:voicememory_mobile/data/network/auth_api_client.dart';
import 'package:voicememory_mobile/data/repositories/auth_repository.dart';
import 'package:voicememory_mobile/features/auth/application/auth_session_notifier.dart';
import 'package:voicememory_mobile/models/session.dart';
import 'package:voicememory_mobile/services/auth_service.dart';
import 'package:voicememory_mobile/storage/secure_storage.dart';
import 'package:voicememory_mobile/storage/session_cookie_store.dart';

/// In-memory auth API fake for widget and service tests.
class FakeAuthApiClient implements AuthApiClient {
  FakeAuthApiClient();

  final List<String> sendCodeCalls = [];
  final List<String> verifyCalls = [];
  int signOutCalls = 0;
  ApiFailure? sendCodeError;
  ApiFailure? verifyError;
  ApiFailure? signOutError;

  @override
  Future<ApiResult<void>> sendAuthCode(
    String email, {
    NetworkCancelToken? cancelToken,
  }) async {
    if (sendCodeError != null) {
      return ApiFailureResult(sendCodeError!);
    }
    sendCodeCalls.add(email);
    return const ApiSuccess(null);
  }

  @override
  Future<ApiResult<AuthVerifyPayload>> verifyAuthCode({
    required String email,
    required String code,
    NetworkCancelToken? cancelToken,
  }) async {
    if (verifyError != null) {
      return ApiFailureResult(verifyError!);
    }
    verifyCalls.add('$email|$code');
    return ApiSuccess(
      AuthVerifyPayload(
        session: UserSession(userId: 'u1', email: email),
        sessionCookie: 'vm_session=test-cookie',
      ),
    );
  }

  UserSession? session;

  @override
  Future<ApiResult<UserSession?>> getSession({
    NetworkCancelToken? cancelToken,
  }) async => ApiSuccess(session);

  @override
  Future<ApiResult<void>> signOut({NetworkCancelToken? cancelToken}) async {
    signOutCalls++;
    session = null;
    if (signOutError != null) {
      return ApiFailureResult(signOutError!);
    }
    return const ApiSuccess(null);
  }
}

AuthService createTestAuthService({
  FakeAuthApiClient? api,
  SecureStorageService? secure,
  SessionCookieSource? sessionCookies,
}) {
  final secureStorage = secure ?? _MemorySecureStorage();
  final cookies =
      sessionCookies ?? SessionCookieSource(SessionCookieStore(secureStorage));
  final repository = AuthRepository(
    api: api ?? FakeAuthApiClient(),
    sessionCookies: cookies,
    secure: secureStorage,
    requestScope: NetworkRequestScope(),
  );
  final container = ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(repository)],
  );
  return createAuthServiceForTest(container: container);
}

class _MemorySecureStorage extends SecureStorageService {
  final Map<String, String> values = {};

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
