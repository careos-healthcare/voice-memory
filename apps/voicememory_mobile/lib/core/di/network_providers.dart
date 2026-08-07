import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../billing/revenuecat_service.dart';
import '../../billing/store_billing_port.dart';
import '../../config/app_config.dart';
import '../../core/network/http_transport.dart';
import '../../core/network/network_cancel_token.dart';
import '../../core/network/session_cookie_source.dart';
import '../../data/network/auth_api_client.dart';
import '../../data/network/billing_api_client.dart';
import '../../data/network/capture_api_client.dart';
import '../../data/network/http_auth_api_client.dart';
import '../../data/network/http_billing_api_client.dart';
import '../../data/network/http_capture_api_client.dart';
import '../../data/network/http_sync_api_client.dart';
import '../../data/network/sync_api_client.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/billing_repository.dart';
import '../../data/repositories/capture_repository.dart';
import '../../data/repositories/sync_repository.dart';
import '../../storage/entitlement_cache.dart';
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

final networkRequestScopeProvider = Provider<NetworkRequestScope>((ref) {
  final scope = NetworkRequestScope();
  ref.onDispose(scope.cancelAll);
  return scope;
});

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

final syncApiClientProvider = Provider<SyncApiClient>(
  (ref) => HttpSyncApiClient(ref.watch(httpTransportProvider)),
);

final billingApiClientProvider = Provider<BillingApiClient>(
  (ref) => HttpBillingApiClient(ref.watch(httpTransportProvider)),
);

final captureApiClientProvider = Provider<CaptureApiClient>(
  (ref) => HttpCaptureApiClient(ref.watch(httpTransportProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => throw UnimplementedError('Override authRepositoryProvider at bootstrap'),
);

final billingRepositoryProvider = Provider<BillingRepository>(
  (ref) => BillingRepository(
    api: ref.watch(billingApiClientProvider),
    requestScope: ref.watch(networkRequestScopeProvider),
  ),
);

final captureRepositoryProvider = Provider<CaptureRepository>(
  (ref) => CaptureRepository(
    api: ref.watch(captureApiClientProvider),
    requestScope: ref.watch(networkRequestScopeProvider),
  ),
);

final entitlementCacheHolderProvider = Provider<EntitlementCacheHolder>(
  (ref) => EntitlementCacheHolder(),
);

final entitlementCacheProvider = Provider<EntitlementCache>((ref) {
  final cache = ref.watch(entitlementCacheHolderProvider).value;
  if (cache == null) {
    throw StateError('EntitlementCache has not been bound yet');
  }
  return cache;
});

final storeBillingPortProvider = Provider<StoreBillingPort>(
  (ref) => RevenueCatService.instance,
);

/// Account-scoped entitlement cache — rebound on namespace switches.
class EntitlementCacheHolder {
  EntitlementCache? value;
}

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

/// Builds a [ProviderContainer] with network/auth/billing dependencies for bootstrap.
ProviderContainer createNetworkProviderContainer({
  required SecureStorageService secureStorage,
  required SessionCookieStore sessionCookieStore,
  required SessionCookieSource sessionCookieSource,
  required AuthRepository authRepository,
  http.Client? httpClient,
  String? apiBaseUrl,
  StoreBillingPort? storeBilling,
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
      if (storeBilling != null)
        storeBillingPortProvider.overrideWithValue(storeBilling),
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
