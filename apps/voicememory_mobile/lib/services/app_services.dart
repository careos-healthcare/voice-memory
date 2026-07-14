import 'dart:io';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../audio/recording_service.dart';
import '../billing/value_moment_paywall.dart';
import '../storage/app_storage_paths.dart';
import '../storage/capture_token_cache.dart';
import '../storage/device_id.dart';
import '../storage/entitlement_cache.dart';
import '../storage/journal_store.dart';
import '../storage/mobile_prefs_store.dart';
import '../storage/secure_storage.dart';
import '../storage/session_cookie_store.dart';
import '../auth/guest_first_auth.dart';
import '../security/private_data_service.dart';
import '../features/native_push/native_push_service.dart';
import '../features/native_push/native_push_verification.dart';
import '../features/offline_sync/offline_sync_journey_store.dart';
import '../features/memory_resurfacing/memory_resurfacing_service.dart';
import '../features/belief_evolution/belief_evolution_service.dart';
import '../features/archive_agreement/archive_agreement_service.dart';
import '../features/beta_feedback/beta_feedback_store.dart';
import '../features/early_archive/confirmed_repeat_why_matters_store.dart';
import '../features/early_archive/confirmed_repeat_thought_map_store.dart';
import '../features/beta/archive_beta_mission_gate.dart';
import '../features/beta/archive_beta_mission_store.dart';
import '../features/beta_test_script/beta_test_script_store.dart';
import '../features/beta/tester_mission_store.dart';
import '../features/beta/confirmed_repeat_beta_feedback_store.dart';
import '../features/beta/core_value_feedback_store.dart';
import '../features/repeat_return_check/repeat_return_check_store.dart';
import '../features/come_back_tomorrow/come_back_tomorrow_v2_store.dart';
import '../features/first_proof_truth/first_proof_truth_store.dart';
import '../features/helped_tracking/helped_tracking_store.dart';
import '../features/pattern_naming/pattern_name_store.dart';
import '../features/pro_evidence_value/pro_evidence_value_dismiss_store.dart';
import '../features/pro_lock_moment/pro_lock_moment_dismiss_store.dart';
import '../features/monthly_private_report/monthly_private_report_dismiss_store.dart';
import '../features/archive_backup_bridge/archive_backup_bridge_dismiss_store.dart';
import '../features/beta_feedback_intelligence/beta_feedback_intelligence_store.dart';
import '../features/quiet_signal/quiet_signal_analytics.dart';
import '../features/voice_capture/microphone_permission_environment.dart';
import '../features/what_changed/what_changed_v2_store.dart';
import '../push/fcm_service.dart';
import '../config/app_config.dart';
import '../config/archive_me_demo_state.dart';
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
    final base = await _resolveDocumentsBasePath();

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
    await TempRecordingCleanup.purgeStaleOnStartup(
      journalStore: s.journalStore,
    );
    s.prefs = await MobilePrefsStore.open('$base/mobile_prefs.json');
    await ArchiveMeDemoState.hydrateFromPrefs(s.prefs);
    s.entitlementCache = await EntitlementCache.open('$base/entitlements.json');
    s.pipeline = CapturePipelineService(
      api: s.api,
      attest: s.attest,
      journalStore: s.journalStore,
    );
    s.recording = RecordingService();
    s.journal = JournalService(s.journalStore);
    s.auth = AuthService(s.api, s.secureStorage, s.sessionCookies);
    await s.auth.loadPersistedSession();
    await GuestFirstAuth(
      s.prefs,
    ).markGuestModeStartedIfNeeded(isSignedIn: s.auth.currentSession != null);
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
      registerToken:
          ({required deviceId, required platform, required fcmToken}) =>
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

    Future<void> resetEntitlementsForAuthChange() async {
      await s.billing.resetCachedEntitlementsForAuthChange();
    }

    s.auth.onSignedOut = resetEntitlementsForAuthChange;
    s.auth.onSignedIn = () async {
      await resetEntitlementsForAuthChange();
      await s.billing.loadEntitlements(forceRefresh: true);
      await GuestFirstAuth(
        s.prefs,
        attest: s.attest,
        sync: s.sync,
      ).registerDeviceAfterSignIn();
    };

    _instance = s;
    _initialized = true;
  }

  /// Trial participants: local journal + prefs only; no push, analytics, or billing.
  static Future<void> _initializeForTrial() async {
    final s = AppServices._();
    final base = await _resolveDocumentsBasePath();

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
    await TempRecordingCleanup.purgeStaleOnStartup(
      journalStore: s.journalStore,
    );
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
      registerToken:
          ({required deviceId, required platform, required fcmToken}) async =>
              {},
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

  static Future<String> _resolveDocumentsBasePath() async {
    try {
      final dir = await AppStoragePaths.applicationDocumentsDirectory();
      return dir.path;
    } catch (e, st) {
      if (kDebugMode && Platform.isIOS) {
        debugPrint(
          'ARCHIVEME_SIMULATOR_NATIVE_ASSETS: documents path failed, '
          'using debug temp fallback: $e',
        );
        debugPrint('$st');
        return AppStoragePaths.debugSimulatorDocumentsDirectorySync(
          reason: e,
        ).path;
      }
      rethrow;
    }
  }

  static Future<void> resetForTest({
    required String journalPath,
    String? prefsPath,
    ApiClient? api,
    bool skipRevenueCat = false,
    RecordingService? recording,
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
    final encryptedFile = File(JournalStore.encryptedPathFor(journalPath));
    if (await encryptedFile.exists()) await encryptedFile.delete();
    s.journalStore = await JournalStore.open(
      journalPath,
      encryptAtRest: false,
    );
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
    s.recording = recording ?? RecordingService(testMode: true);
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
      registerToken:
          ({required deviceId, required platform, required fcmToken}) =>
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
    await BetaFeedbackStore.resetForTest();
    await ConfirmedRepeatBetaFeedbackStore.resetForTest();
    await CoreValueFeedbackStore.resetForTest();
    ArchiveBetaMissionGate.enabledOverride = false;
    await ArchiveBetaMissionStore.resetForTest();
    await BetaTestScriptStore.resetForTest(AppServices.instance.prefs);
    await TesterMissionStore.resetForTest();
    await ConfirmedRepeatWhyMattersStore.resetForTest();
    await ConfirmedRepeatThoughtMapStore.resetForTest();
    ArchiveMeDemoState.resetForTest();
    await RepeatReturnCheckStore.resetForTest();
    await ComeBackTomorrowV2Store.resetForTest(s.prefs);
    await FirstProofTruthStore.resetForTest(s.prefs);
    await WhatChangedV2Store.resetForTest();
    await HelpedTrackingStore.resetForTest();
    PatternNameStore.resetForTest();
    MicrophonePermissionEnvironment.resetForTest();
    QuietSignalAnalytics.resetForTest();
    await ProEvidenceValueDismissStore.resetForTest();
    await ProLockMomentDismissStore.resetForTest();
    await MonthlyPrivateReportDismissStore.resetForTest();
    await ArchiveBackupBridgeDismissStore.resetForTest();
    await BetaFeedbackIntelligenceStore.resetForTest();
  }
}
