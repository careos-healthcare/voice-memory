import '../../api/api_client.dart';
import '../../features/remote_transcription/remote_transcription_disclosure.dart';
import '../../features/theme_system/theme_engine.dart';
import '../../storage/capture_token_cache.dart';
import '../../storage/device_id.dart';
import '../../storage/mobile_prefs_store.dart';
import '../../storage/secure_storage.dart';
import '../../storage/session_cookie_store.dart';
import '../subscription_service.dart';
import 'v1_composition_config.dart';

final class CoreServices {
  CoreServices._({
    required this.apiTransport,
    required this.authApi,
    required this.voiceCaptureApi,
    required this.journalSyncApi,
    required this.billingApi,
    required this.deviceIds,
    required this.secureStorage,
    required this.sessionCookies,
    required this.tokenCache,
    required this.prefs,
    required this.remoteTranscriptionDisclosure,
    required void Function(String archiveId) setDisclosureArchiveId,
    required this.themePreferencesStore,
    required this.subscriptionService,
  }) : // Public named parameters cannot expose private field names.
       // ignore: prefer_initializing_formals
       _setDisclosureArchiveId = setDisclosureArchiveId;

  final ApiTransport apiTransport;
  final AuthApiClient authApi;
  final VoiceCaptureApiClient voiceCaptureApi;
  final JournalSyncApiClient journalSyncApi;
  final BillingApiClient billingApi;
  final DeviceIdStore deviceIds;
  final SecureStorageService secureStorage;
  final SessionCookieStore sessionCookies;
  final CaptureTokenCache tokenCache;
  final MobilePrefsStore prefs;
  final RemoteTranscriptionDisclosureStore remoteTranscriptionDisclosure;
  final void Function(String archiveId) _setDisclosureArchiveId;
  final ThemePreferencesStore themePreferencesStore;
  final SubscriptionService subscriptionService;

  static Future<CoreServices> create(V1CompositionConfig config) async {
    final secureStorage =
        config.secureStorage ??
        (config.testMode
            ? InMemorySecureStorageService()
            : SecureStorageService());
    final sessionCookies = SessionCookieStore(secureStorage);
    final prefs = await MobilePrefsStore.open(
      config.prefsPath ?? '${config.basePath}/mobile_prefs.json',
      secureStorage: config.testMode && config.secureStorage == null
          ? null
          : secureStorage,
    );
    var activeDisclosureArchiveId = 'unscoped';
    final disclosure = RemoteTranscriptionDisclosureStore(
      () => prefs,
      archiveId: () => activeDisclosureArchiveId,
    );
    final transport =
        config.apiTransport ??
        config.authApi?.transport ??
        config.voiceCaptureApi?.transport ??
        config.journalSyncApi?.transport ??
        config.billingApi?.transport ??
        ApiTransport();
    final authApi = config.authApi ?? AuthApiClient(transport);
    final voiceApi =
        config.voiceCaptureApi ??
        VoiceCaptureApiClient(
          transport,
          remoteTranscriptionDisclosure: disclosure,
        );
    final journalApi = config.journalSyncApi ?? JournalSyncApiClient(transport);
    final billingApi = config.billingApi ?? BillingApiClient(transport);

    final cookie = await sessionCookies.read();
    if (cookie != null) transport.setSessionCookie(cookie);

    final themePreferences = ThemePreferencesStore(prefs);
    await themePreferences.initialize();
    return CoreServices._(
      apiTransport: transport,
      authApi: authApi,
      voiceCaptureApi: voiceApi,
      journalSyncApi: journalApi,
      billingApi: billingApi,
      deviceIds: DeviceIdStore(),
      secureStorage: secureStorage,
      sessionCookies: sessionCookies,
      tokenCache: CaptureTokenCache(),
      prefs: prefs,
      remoteTranscriptionDisclosure: disclosure,
      setDisclosureArchiveId: (archiveId) {
        activeDisclosureArchiveId = archiveId.trim().isEmpty
            ? 'unscoped'
            : archiveId.trim();
      },
      themePreferencesStore: themePreferences,
      subscriptionService: SubscriptionService(billingApi),
    );
  }

  void activateDisclosureArchive(String archiveId) {
    _setDisclosureArchiveId(archiveId);
  }

  void dispose() => apiTransport.dispose();
}
