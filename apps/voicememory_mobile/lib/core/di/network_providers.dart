import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import '../../core/network/http_transport.dart';
import '../../core/network/session_cookie_source.dart';
import '../../data/network/auth_api_client.dart';
import '../../data/network/http_auth_api_client.dart';
import '../../data/network/http_sync_api_client.dart';
import '../../data/network/sync_api_client.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/sync_repository.dart';
import '../../storage/secure_storage.dart';
import '../../storage/session_cookie_store.dart';

final secureStorageProvider = Provider<SecureStorageService>(
  (ref) => throw UnimplementedError('Override secureStorageProvider at bootstrap'),
);

final sessionCookieStoreProvider = Provider<SessionCookieStore>(
  (ref) => throw UnimplementedError('Override sessionCookieStoreProvider at bootstrap'),
);

final sessionCookieSourceProvider = Provider<SessionCookieSource>(
  (ref) => throw UnimplementedError('Override sessionCookieSourceProvider at bootstrap'),
);

final httpClientProvider = Provider<http.Client>(
  (ref) => http.Client(),
);

final apiBaseUrlProvider = Provider<String>(
  (ref) => AppConfig.apiBaseUrl,
);

final httpTransportProvider = Provider<HttpTransport>((ref) {
  final transport = HttpTransport(
    client: ref.watch(httpClientProvider),
    baseUrl: ref.watch(apiBaseUrlProvider),
    sessionCookies: ref.watch(sessionCookieSourceProvider),
  );
  ref.onDispose(transport.dispose);
  return transport;
});

final authApiClientProvider = Provider<AuthApiClient>(
  (ref) => HttpAuthApiClient(ref.watch(httpTransportProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => throw UnimplementedError('Override authRepositoryProvider at bootstrap'),
);

/// Account-scoped sync repository — rebound on namespace switches.
class SyncRepositoryHolder {
  SyncRepository? value;
}

final syncRepositoryHolderProvider = Provider<SyncRepositoryHolder>(
  (ref) => SyncRepositoryHolder(),
);

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  final repository = ref.watch(syncRepositoryHolderProvider).value;
  if (repository == null) {
    throw StateError('SyncRepository has not been bound yet');
  }
  return repository;
});

final syncApiClientProvider = Provider<SyncApiClient>(
  (ref) => HttpSyncApiClient(ref.watch(httpTransportProvider)),
);

/// Builds a [ProviderContainer] with network/auth dependencies for app bootstrap.
ProviderContainer createNetworkProviderContainer({
  required SecureStorageService secureStorage,
  required SessionCookieStore sessionCookieStore,
  required SessionCookieSource sessionCookieSource,
  required AuthRepository authRepository,
  http.Client? httpClient,
  String? apiBaseUrl,
}) {
  return ProviderContainer(
    overrides: [
      secureStorageProvider.overrideWithValue(secureStorage),
      sessionCookieStoreProvider.overrideWithValue(sessionCookieStore),
      sessionCookieSourceProvider.overrideWithValue(sessionCookieSource),
      authRepositoryProvider.overrideWithValue(authRepository),
      if (httpClient != null)
        httpClientProvider.overrideWithValue(httpClient),
      if (apiBaseUrl != null) apiBaseUrlProvider.overrideWithValue(apiBaseUrl),
    ],
  );
}

AuthRepository createAuthRepository({
  required AuthApiClient api,
  required SessionCookieSource sessionCookies,
  required SecureStorageService secure,
}) {
  return AuthRepository(
    api: api,
    sessionCookies: sessionCookies,
    secure: secure,
  );
}
