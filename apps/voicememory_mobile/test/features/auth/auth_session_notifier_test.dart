import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_exceptions.dart';
import 'package:voicememory_mobile/core/di/network_providers.dart';
import 'package:voicememory_mobile/core/network/api_failure.dart';
import 'package:voicememory_mobile/core/network/session_cookie_source.dart';
import 'package:voicememory_mobile/data/repositories/auth_repository.dart';
import 'package:voicememory_mobile/features/auth/application/auth_session_notifier.dart';
import 'package:voicememory_mobile/features/auth/application/auth_session_state.dart';
import 'package:voicememory_mobile/models/session.dart';
import 'package:voicememory_mobile/storage/secure_storage.dart';
import 'package:voicememory_mobile/storage/session_cookie_store.dart';

import '../../helpers/fake_auth_api_client.dart';

class _MemorySecure extends SecureStorageService {
  final Map<String, String> values = {};

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> delete(String key) async => values.remove(key);
}

void main() {
  late FakeAuthApiClient fakeApi;
  late AuthRepository repository;
  late ProviderContainer container;
  late AuthSessionNotifier notifier;

  setUp(() {
    final secure = _MemorySecure();
    final cookies = SessionCookieSource(SessionCookieStore(secure));
    fakeApi = FakeAuthApiClient();
    repository = AuthRepository(
      api: fakeApi,
      sessionCookies: cookies,
      secure: secure,
    );
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    notifier = container.read(authSessionProvider.notifier);
  });

  tearDown(() {
    container.dispose();
  });

  test('verifyAuthCode updates immutable signed-in state', () async {
    final session = await notifier.verifyAuthCode(
      email: 'person@example.com',
      code: '123456',
    );
    expect(session.userId, 'u1');
    expect(container.read(authSessionProvider).phase, AuthPhase.signedIn);
    expect(container.read(authSessionProvider).session?.email, 'person@example.com');
  });

  test('signOut clears session and records server failure', () async {
    fakeApi.verifyError = const ApiFailureOffline();
    await expectLater(
      notifier.verifyAuthCode(email: 'a@b.com', code: '1'),
      throwsA(isA<NetworkOfflineException>()),
    );

    fakeApi.verifyError = null;
    await notifier.verifyAuthCode(email: 'a@b.com', code: '1');
    fakeApi.signOutError = const ApiFailureOffline('server unreachable');

    await notifier.signOut();

    final state = container.read(authSessionProvider);
    expect(state.session, isNull);
    expect(state.phase, AuthPhase.signedOut);
    expect(state.signOutServerFailed, isTrue);
    expect(state.lastFailure, isA<ApiFailureOffline>());
  });
}
