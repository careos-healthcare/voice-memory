import 'package:archiveme_mobile/billing/revenuecat_service.dart';
import 'package:archiveme_mobile/billing/store_billing_port.dart';
import 'package:archiveme_mobile/core/network/http_transport.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/core/network/session_cookie_source.dart';
import 'package:archiveme_mobile/core/network/voice_memory_api_client_bundle.dart';
import 'package:archiveme_mobile/core/network/voice_memory_api_config.dart';
import 'package:archiveme_mobile/data/network/account_api_client.dart';
import 'package:archiveme_mobile/data/network/archive_synthesis_api_client.dart';
import 'package:archiveme_mobile/data/network/auth_api_client.dart';
import 'package:archiveme_mobile/data/network/billing_api_client.dart';
import 'package:archiveme_mobile/data/network/capture_api_client.dart';
import 'package:archiveme_mobile/data/network/caregiver_consent_api_client.dart';
import 'package:archiveme_mobile/data/network/coach_consent_api_client.dart';
import 'package:archiveme_mobile/data/network/live_audio_api_client.dart';
import 'package:archiveme_mobile/data/network/push_api_client.dart';
import 'package:archiveme_mobile/data/network/sync_api_client.dart';
import 'package:archiveme_mobile/data/network/user_relationship_api_client.dart';
import 'package:archiveme_mobile/data/repositories/account_repository.dart';
import 'package:archiveme_mobile/data/repositories/archive_synthesis_repository.dart';
import 'package:archiveme_mobile/data/repositories/auth_repository.dart';
import 'package:archiveme_mobile/data/repositories/billing_repository.dart';
import 'package:archiveme_mobile/data/repositories/capture_repository.dart';
import 'package:archiveme_mobile/data/repositories/live_audio_repository.dart';
import 'package:archiveme_mobile/data/repositories/sync_repository.dart';
import 'package:archiveme_mobile/features/evidence_method/evidence_insight_client.dart';
import 'package:archiveme_mobile/services/api_service.dart';
import 'package:archiveme_mobile/storage/entitlement_cache.dart';
import 'package:archiveme_mobile/storage/secure_storage.dart';
import 'package:archiveme_mobile/storage/session_cookie_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod/misc.dart' show Override;

final secureStorageProvider = Provider<SecureStorageService>(
  (ref) =>
      throw UnimplementedError('Override secureStorageProvider at bootstrap'),
);

final sessionCookieStoreProvider = Provider<SessionCookieStore>(
  (ref) => throw UnimplementedError(
    'Override sessionCookieStoreProvider at bootstrap',
  ),
);

final sessionCookieSourceProvider = Provider<SessionCookieSource>(
  (ref) => throw UnimplementedError(
    'Override sessionCookieSourceProvider at bootstrap',
  ),
);

final httpClientProvider = Provider<http.Client>((ref) => http.Client());

/// Resolved `VOICE_MEMORY_API_BASE_URL` — must be overridden at bootstrap via
/// [createNetworkProviderContainer] after [AppConfig.initApiResolution].
final voiceMemoryApiBaseUrlProvider = Provider<String>(
  (ref) => throw UnimplementedError(
    'Override voiceMemoryApiBaseUrlProvider at bootstrap with '
    'VOICE_MEMORY_API_BASE_URL',
  ),
);

/// Alias kept for existing call sites — delegates to [voiceMemoryApiBaseUrlProvider].
final apiBaseUrlProvider = Provider<String>(
  (ref) => ref.watch(voiceMemoryApiBaseUrlProvider),
);

final voiceMemoryApiConfigProvider = Provider<VoiceMemoryApiConfig>(
  (ref) => VoiceMemoryApiConfig(baseUrl: ref.watch(voiceMemoryApiBaseUrlProvider)),
);

final networkRequestScopeProvider = Provider<NetworkRequestScope>((ref) {
  final scope = NetworkRequestScope();
  ref.onDispose(scope.cancelAll);
  return scope;
});

final httpTransportProvider = Provider<HttpTransport>((ref) {
  final transport = HttpTransport(
    client: ref.watch(httpClientProvider),
    baseUrl: ref.watch(voiceMemoryApiBaseUrlProvider),
    sessionCookies: ref.watch(sessionCookieSourceProvider),
  );
  ref.onDispose(transport.dispose);
  return transport;
});

final voiceMemoryApiClientBundleProvider = Provider<VoiceMemoryApiClientBundle>(
  (ref) {
    final bundle = VoiceMemoryApiClientBundle.fromTransport(
      ref.watch(httpTransportProvider),
      sessionCookies: ref.watch(sessionCookieSourceProvider),
    );
    ref.onDispose(bundle.dispose);
    return bundle;
  },
);

final authApiClientProvider = Provider<AuthApiClient>(
  (ref) => ref.watch(voiceMemoryApiClientBundleProvider).auth,
);

final syncApiClientProvider = Provider<SyncApiClient>(
  (ref) => ref.watch(voiceMemoryApiClientBundleProvider).sync,
);

final billingApiClientProvider = Provider<BillingApiClient>(
  (ref) => ref.watch(voiceMemoryApiClientBundleProvider).billing,
);

final captureApiClientProvider = Provider<CaptureApiClient>(
  (ref) => ref.watch(voiceMemoryApiClientBundleProvider).capture,
);

final archiveSynthesisApiClientProvider = Provider<ArchiveSynthesisApiClient>(
  (ref) => ref.watch(voiceMemoryApiClientBundleProvider).archiveSynthesis,
);

final accountApiClientProvider = Provider<AccountApiClient>(
  (ref) => ref.watch(voiceMemoryApiClientBundleProvider).account,
);

final pushApiClientProvider = Provider<PushApiClient>(
  (ref) => ref.watch(voiceMemoryApiClientBundleProvider).push,
);

final liveAudioApiClientProvider = Provider<LiveAudioApiClient>(
  (ref) => ref.watch(voiceMemoryApiClientBundleProvider).liveAudio,
);

final coachConsentApiClientProvider = Provider<CoachConsentApiClient>(
  (ref) => ref.watch(voiceMemoryApiClientBundleProvider).coachConsent,
);

final caregiverConsentApiClientProvider = Provider<CaregiverConsentApiClient>(
  (ref) => ref.watch(voiceMemoryApiClientBundleProvider).caregiverConsent,
);

final userRelationshipApiClientProvider = Provider<UserRelationshipApiClient>(
  (ref) => ref.watch(voiceMemoryApiClientBundleProvider).userRelationships,
);

final insightsApiServiceProvider = Provider<ApiService>(
  (ref) => ref.watch(voiceMemoryApiClientBundleProvider).insights,
);

final evidenceInsightClientProvider = Provider<EvidenceInsightClient>(
  (ref) => ref.watch(voiceMemoryApiClientBundleProvider).evidenceInsights,
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) =>
      throw UnimplementedError('Override authRepositoryProvider at bootstrap'),
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

final archiveSynthesisRepositoryProvider = Provider<ArchiveSynthesisRepository>(
  (ref) => ArchiveSynthesisRepository(
    api: ref.watch(archiveSynthesisApiClientProvider),
    requestScope: ref.watch(networkRequestScopeProvider),
  ),
);

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(
    api: ref.watch(accountApiClientProvider),
    sessionCookies: ref.watch(sessionCookieSourceProvider),
    requestScope: ref.watch(networkRequestScopeProvider),
  ),
);

final liveAudioRepositoryProvider = Provider<LiveAudioRepository>(
  (ref) => LiveAudioRepository(
    api: ref.watch(liveAudioApiClientProvider),
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
  NetworkRequestScope? requestScope,
  http.Client? httpClient,
  String? apiBaseUrl,
  StoreBillingPort? storeBilling,
  List<Override>? networkOverrides,
}) {
  return ProviderContainer(
    overrides: [
      secureStorageProvider.overrideWithValue(secureStorage),
      sessionCookieStoreProvider.overrideWithValue(sessionCookieStore),
      sessionCookieSourceProvider.overrideWithValue(sessionCookieSource),
      authRepositoryProvider.overrideWithValue(authRepository),
      if (requestScope != null)
        networkRequestScopeProvider.overrideWithValue(requestScope),
      if (httpClient != null) httpClientProvider.overrideWithValue(httpClient),
      if (apiBaseUrl != null)
        voiceMemoryApiBaseUrlProvider.overrideWithValue(apiBaseUrl),
      if (storeBilling != null)
        storeBillingPortProvider.overrideWithValue(storeBilling),
      ...?networkOverrides,
    ],
  );
}

AuthRepository createAuthRepository({
  required AuthApiClient api,
  required SessionCookieSource sessionCookies,
  required SecureStorageService secure,
  required NetworkRequestScope requestScope,
}) {
  return AuthRepository(
    api: api,
    sessionCookies: sessionCookies,
    secure: secure,
    requestScope: requestScope,
  );
}