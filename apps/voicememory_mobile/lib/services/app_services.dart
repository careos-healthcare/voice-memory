import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../api/api_client.dart';
import '../audio/recording_service.dart';
import '../billing/value_moment_paywall.dart';
import '../storage/capture_token_cache.dart';
import '../storage/device_id.dart';
import '../storage/entitlement_cache.dart';
import '../storage/journal_store.dart';
import '../storage/mobile_prefs_store.dart';
import '../storage/secure_storage.dart';
import '../storage/session_cookie_store.dart';
import '../auth/guest_first_auth.dart';
import '../features/native_push/native_push_service.dart';
import '../features/native_push/native_push_verification.dart';
import '../features/offline_sync/offline_sync_journey_store.dart';
import '../features/memory_resurfacing/memory_resurfacing_service.dart';
import '../features/belief_evolution/belief_evolution_service.dart';
import '../features/archive_agreement/archive_agreement_service.dart';
import '../push/fcm_service.dart';
import '../config/app_config.dart';
import '../config/trial_mode.dart';
import 'auth_service.dart';
import '../billing/billing_service.dart';
import '../billing/revenuecat_service.dart';
import 'capture_attest_service.dart';
import 'capture_pipeline_service.dart';
import 'journal_service.dart';
import 'sync_service.dart';
import 'product_analytics.dart';

class AppServices {
  AppServices._();

  static AppServices? _instance;
  static bool _initialized = false;

  late final ApiClient api;
  late final DeviceIdStore deviceIds;
  late final SecureStorageService secureStorage;
  late final SessionCookieStore sessionCookies;
  late final CaptureTokenCache tokenCache;
  late final CaptureAttestService attest;
  late final JournalStore journalStore;
  late final MobilePrefsStore prefs;
  late final EntitlementCache entitlementCache;
  late final CapturePipelineService pipeline;
  late final RecordingService recording;
  late final JournalService journal;
  late final AuthService auth;
  late final BillingService billing;
  late final SyncService sync;
  late final ValueMomentPaywallLogic paywall;
  late final NativePushVerificationStore nativePushStore;
  late final FcmService fcm;
  late final NativePushService nativePush;
  late final OfflineSyncJourneyStore offlineSyncJourney;
  late final MemoryResurfacingService memoryResurfacing;
  late final BeliefEvolutionService beliefEvolution;
  late final ArchiveAgreementService archiveAgreement;

  String get nativePushPlatform => Platform.isIOS ? 'ios' : 'android';

  static bool get isInitialized => _initialized;

  static AppServices get instance {
    final i = _instance;
    if (i == null || !_initialized) {
      throw StateError('Call AppServices.initialize() first');
    }
    return i;
  }

  static Future<void> initialize() async {
    if (_initialized) return;
    if (TrialMode.enabled) {
      await _initializeForTrial();
      return;
    }
    final s = AppServices._();
    final dir = await getApplicationDocumentsDirectory();
    final base = dir.path;

    s.secureStorage = SecureStorageService();
    s.sessionCookies = SessionCookieStore(s.secureStorage);
    s.api = ApiClient();
    await s.sessionCookies.read().then((cookie) {
      if (cookie != null) s.api.setSessionCookie(cookie);
    });

    s.deviceIds = DeviceIdStore();
    s.tokenCache = CaptureTokenCache();
    s.attest = CaptureAttestService(
      api: s.api,
      deviceIds: s.deviceIds,
      tokenCache: s.tokenCache,
    );
    s.journalStore = await JournalStore.open('$base/journal_entries.json');
    s.prefs = await MobilePrefsStore.open('$base/mobile_prefs.json');
    s.entitlementCache = await EntitlementCache.open('$base/entitlements.json');
    s.pipeline = CapturePipelineService(
      api: s.api,
      attest: s.attest,
      journalStore: s.journalStore,
    );
    s.recording = RecordingService();
    s.journal = JournalService(s.journalStore);
    s.auth = AuthService(s.api, s.secureStorage, s.sessionCookies);
    s.auth.onSignedIn = () => GuestFirstAuth(
          s.prefs,
          attest: s.attest,
          sync: s.sync,
        ).registerDeviceAfterSignIn();
    await s.auth.loadPersistedSession();
    await GuestFirstAuth(s.prefs).markGuestModeStartedIfNeeded(
      isSignedIn: s.auth.currentSession != null,
    );
    await RevenueCatService.instance.initialize();
    s.billing = BillingService(
      s.api,
      s.entitlementCache,
      RevenueCatService.instance,
    );
    s.billing.startListening();
    s.nativePushStore = NativePushVerificationStore(s.prefs);
    s.fcm = FcmService(
      store: s.nativePushStore,
      getDeviceId: () => s.deviceIds.getOrCreate(),
      registerToken: ({required deviceId, required platform, required fcmToken}) =>
          s.api.registerPushDevice(
            deviceId: deviceId,
            platform: platform,
            fcmToken: fcmToken,
          ),
      sendTestPush: ({required deviceId, required targetRoute}) =>
          s.api.sendInternalTestPush(
            deviceId: deviceId,
            targetRoute: targetRoute,
            debugToken: AppConfig.internalDebugToken,
          ),
    );
    s.nativePush = NativePushService(s.fcm);
    // FirebaseMessaging is only used inside FcmService.initialize() after Firebase.initializeApp.
    await s.fcm.initialize();
    await ProductAnalytics.initialize();
    s.offlineSyncJourney = OfflineSyncJourneyStore(s.prefs);
    s.memoryResurfacing = MemoryResurfacingService.fromPrefs(s.prefs);
    s.beliefEvolution = BeliefEvolutionService.fromPrefs(s.prefs);
    s.archiveAgreement = ArchiveAgreementService.fromPrefs(s.prefs);
    s.sync = SyncService(s.api, s.journalStore, s.prefs);
    s.paywall = ValueMomentPaywallLogic(s.prefs);
    _instance = s;
    _initialized = true;
  }

  /// Trial participants: local journal + prefs only; no push, analytics, or billing.
  static Future<void> _initializeForTrial() async {
    final s = AppServices._();
    final dir = await getApplicationDocumentsDirectory();
    final base = dir.path;

    s.secureStorage = SecureStorageService();
    s.sessionCookies = SessionCookieStore(s.secureStorage);
    s.api = ApiClient();
    s.deviceIds = DeviceIdStore();
    s.tokenCache = CaptureTokenCache();
    s.attest = CaptureAttestService(
      api: s.api,
      deviceIds: s.deviceIds,
      tokenCache: s.tokenCache,
    );
    s.journalStore = await JournalStore.open('$base/journal_entries.json');
    s.prefs = await MobilePrefsStore.open('$base/mobile_prefs.json');
    s.entitlementCache = await EntitlementCache.open('$base/entitlements.json');
    s.pipeline = CapturePipelineService(
      api: s.api,
      attest: s.attest,
      journalStore: s.journalStore,
    );
    s.recording = RecordingService(testMode: true);
    s.journal = JournalService(s.journalStore);
    s.auth = AuthService(s.api, s.secureStorage, s.sessionCookies);
    s.billing = BillingService(
      s.api,
      s.entitlementCache,
      RevenueCatService.instance,
    );
    s.nativePushStore = NativePushVerificationStore(s.prefs);
    s.fcm = FcmService(
      store: s.nativePushStore,
      getDeviceId: () => s.deviceIds.getOrCreate(),
      registerToken: ({required deviceId, required platform, required fcmToken}) async => {},
      sendTestPush: ({required deviceId, required targetRoute}) async => {},
    );
    s.nativePush = NativePushService(s.fcm);
    s.offlineSyncJourney = OfflineSyncJourneyStore(s.prefs);
    s.memoryResurfacing = MemoryResurfacingService.fromPrefs(s.prefs);
    s.beliefEvolution = BeliefEvolutionService.fromPrefs(s.prefs);
    s.archiveAgreement = ArchiveAgreementService.fromPrefs(s.prefs);
    s.sync = SyncService(s.api, s.journalStore, s.prefs);
    s.paywall = ValueMomentPaywallLogic(s.prefs);
    await s.prefs.setOnboardingCompleted(true);
    _instance = s;
    _initialized = true;
  }

  static Future<void> resetForTest({
    required String journalPath,
    String? prefsPath,
    ApiClient? api,
    bool skipRevenueCat = false,
  }) async {
    _initialized = false;
    final s = AppServices._();
    s.secureStorage = SecureStorageService();
    s.sessionCookies = SessionCookieStore(s.secureStorage);
    s.api = api ?? ApiClient();
    s.deviceIds = DeviceIdStore();
    s.tokenCache = CaptureTokenCache();
    s.attest = CaptureAttestService(
      api: s.api,
      deviceIds: s.deviceIds,
      tokenCache: s.tokenCache,
    );
    final file = File(journalPath);
    if (await file.exists()) await file.delete();
    s.journalStore = await JournalStore.open(journalPath);
    s.prefs = await MobilePrefsStore.open(
      prefsPath ?? '${file.parent.path}/test_prefs.json',
    );
    s.entitlementCache = await EntitlementCache.open(
      '${file.parent.path}/test_entitlements.json',
    );
    s.pipeline = CapturePipelineService(
      api: s.api,
      attest: s.attest,
      journalStore: s.journalStore,
    );
    s.recording = RecordingService(testMode: true);
    s.journal = JournalService(s.journalStore);
    s.auth = AuthService(s.api, s.secureStorage, s.sessionCookies);
    if (!skipRevenueCat) {
      await RevenueCatService.instance.initialize();
    }
    s.billing = BillingService(
      s.api,
      s.entitlementCache,
      RevenueCatService.instance,
    );
    if (!skipRevenueCat) {
      s.billing.startListening();
    }
    s.sync = SyncService(s.api, s.journalStore, s.prefs);
    s.paywall = ValueMomentPaywallLogic(s.prefs);
    s.nativePushStore = NativePushVerificationStore(s.prefs);
    s.fcm = FcmService(
      store: s.nativePushStore,
      getDeviceId: () => s.deviceIds.getOrCreate(),
      registerToken: ({required deviceId, required platform, required fcmToken}) =>
          s.api.registerPushDevice(
            deviceId: deviceId,
            platform: platform,
            fcmToken: fcmToken,
          ),
      sendTestPush: ({required deviceId, required targetRoute}) =>
          s.api.sendInternalTestPush(
            deviceId: deviceId,
            targetRoute: targetRoute,
            debugToken: AppConfig.internalDebugToken,
          ),
    );
    s.nativePush = NativePushService(s.fcm);
    s.offlineSyncJourney = OfflineSyncJourneyStore(s.prefs);
    s.memoryResurfacing = MemoryResurfacingService.fromPrefs(s.prefs);
    s.beliefEvolution = BeliefEvolutionService.fromPrefs(s.prefs);
    s.archiveAgreement = ArchiveAgreementService.fromPrefs(s.prefs);
    _instance = s;
    _initialized = true;
  }
}
