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
import '../features/journal/infrastructure/journal_save_interceptor_pipeline.dart';
import '../features/curiosity_loop/application/curiosity_hook_journal_store.dart';
import '../features/curiosity_loop/infrastructure/clinical_telemetry_encrypted_storage.dart';
import '../features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import '../features/curiosity_loop/domain/models/curiosity_hook.dart';
import '../features/curiosity_loop/repositories/clinical_trajectory_history_store.dart';
import '../features/curiosity_loop/repositories/cognitive_baseline_store.dart';
import '../features/curiosity_loop/repositories/curiosity_hook_repository.dart';
import '../storage/encrypted_json_storage.dart';
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
import '../features/live_audio/application/live_audio_session_coordinator.dart';
import '../features/live_audio/application/live_voice_capture_service.dart';
import '../features/live_audio/application/offline_vault_recovery_service.dart';
import '../features/live_audio/application/live_voice_recovery_gateway.dart';
import '../features/live_audio/infrastructure/live_audio_session_api_client.dart';
import '../features/live_audio/infrastructure/local_audio_vault.dart';
import '../features/live_audio/infrastructure/network_connectivity_source.dart';
import '../features/live_audio/infrastructure/offline_vault_recovery_store.dart';
import '../features/live_audio/presentation/controllers/live_audio_session_controller.dart';
import 'auth_service.dart';
import '../billing/billing_service.dart';
import '../billing/revenuecat_service.dart';
import 'capture_attest_service.dart';
import 'capture_pipeline_service.dart';
import 'journal_ownership_guard.dart';
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
  LiveVoiceCaptureService? _liveVoiceCapture;
  late final OfflineVaultRecoveryStore offlineVaultRecoveryStore;
  late final OfflineVaultRecoveryService offlineVaultRecovery;
  late final LifecycleNetworkConnectivitySource liveVoiceConnectivity;
  late final LiveVoiceRecoveryGateway liveVoiceRecoveryGateway;
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
  late EncryptedJsonStorage clinicalTelemetryEncryptedStorage;

  String get nativePushPlatform => Platform.isIOS ? 'ios' : 'android';

  LiveVoiceCaptureService get liveVoiceCapture {
    final existing = _liveVoiceCapture;
    if (existing != null) return existing;
    final created = LiveVoiceCaptureService(
      controller: LiveAudioSessionController(
        LiveAudioSessionCoordinator(
          sessionApi: ApiLiveAudioSessionClient(api),
          attest: attest,
        ),
      ),
      pipeline: pipeline,
      recoveryStore: offlineVaultRecoveryStore,
    );
    _liveVoiceCapture = created;
    return created;
  }

  /// Encrypted EWMA baseline store for curiosity loop telemetry.
  CognitiveBaselineStore getBaselineStore() =>
      LocalCognitiveBaselineStore.instance();

  /// Encrypted trajectory history store for hook-response telemetry.
  ClinicalTrajectoryHistoryStore getTrajectoryStore() =>
      LocalClinicalTrajectoryHistoryStore.instance();

  /// Resolves current biomarkers for a hook from its source journal entry.
  Future<CognitiveBiomarkers?> getCurrentMetrics(CuriosityHook hook) async {
    final sourceEntryId = hook.sourceEntryId?.trim();
    final targetEntryId = sourceEntryId != null && sourceEntryId.isNotEmpty
        ? sourceEntryId
        : hook.entryId;
    final entry = await journal.getEntry(targetEntryId);
    return entry?.biomarkers;
  }

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
    s.offlineVaultRecoveryStore = OfflineVaultRecoveryStore();
    s.offlineVaultRecovery = OfflineVaultRecoveryService(
      store: s.offlineVaultRecoveryStore,
      api: s.api,
      attest: s.attest,
      pipeline: s.pipeline,
    );
    s.liveVoiceConnectivity = LifecycleNetworkConnectivitySource();
    s.liveVoiceRecoveryGateway = LiveVoiceRecoveryGateway(
      vault: LocalAudioVault(),
      apiClient: s.api,
      connectivity: s.liveVoiceConnectivity,
      recoveryStore: s.offlineVaultRecoveryStore,
      recoveryService: s.offlineVaultRecovery,
    );
    s.recording = RecordingService();
    s.journal = JournalService(s.journalStore);
    s.auth = AuthService(s.api, s.secureStorage, s.sessionCookies);
    await s.auth.loadPersistedSession();
    final resumedSession = s.auth.currentSession;
    if (resumedSession != null) {
      await _reconcileJournalOwnership(s, resumedSession.userId);
    }
    await GuestFirstAuth(
      s.prefs,
    ).markGuestModeStartedIfNeeded(isSignedIn: s.auth.currentSession != null);
    await RevenueCatService.instance.initialize();
    if (resumedSession != null) {
      // P0 fix — RevenueCat was never told which account is active, so a
      // returning signed-in user's entitlements were evaluated against
      // whatever anonymous RevenueCat app-user-id the SDK generated locally,
      // not their real account. Align the two on every cold start.
      await RevenueCatService.instance.logIn(resumedSession.userId);
    }
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
    s.clinicalTelemetryEncryptedStorage =
        await ClinicalTelemetryEncryptedStorage.forSecureStorage(
      s.secureStorage,
    );

    Future<void> resetEntitlementsForAuthChange() async {
      await s.billing.resetCachedEntitlementsForAuthChange();
    }

    s.auth.onSignedOut = () async {
      // Local reflections stay on-device after sign-out by design, but stop
      // stamping any newly-created (guest) entries with the outgoing
      // account's id so they aren't mistakenly claimed by it later.
      s.journalStore.setActiveOwnerKey(null);
      // P0 fix — RevenueCat login/logout was never connected to account
      // lifecycle. Without this, entitlements for the outgoing account keep
      // being reported to the RevenueCat SDK (and could leak to whichever
      // account signs in next) instead of reverting to an anonymous user.
      await RevenueCatService.instance.logOut();
      await resetEntitlementsForAuthChange();
    };
    s.auth.onSignedIn = () async {
      final userId = s.auth.currentSession?.userId;
      if (userId != null) {
        await _reconcileJournalOwnership(s, userId);
        // P0 fix — see onSignedOut: identify RevenueCat as this account
        // *before* refreshing entitlements below, so the refresh reflects
        // this user's real purchase history rather than an anonymous id.
        await RevenueCatService.instance.logIn(userId);
      }
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
    _configureJournalSaveInterceptors(s);
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
    s.offlineVaultRecoveryStore = OfflineVaultRecoveryStore();
    s.offlineVaultRecovery = OfflineVaultRecoveryService(
      store: s.offlineVaultRecoveryStore,
      api: s.api,
      attest: s.attest,
      pipeline: s.pipeline,
    );
    s.liveVoiceConnectivity = LifecycleNetworkConnectivitySource();
    s.liveVoiceRecoveryGateway = LiveVoiceRecoveryGateway(
      vault: LocalAudioVault(),
      apiClient: s.api,
      connectivity: s.liveVoiceConnectivity,
      recoveryStore: s.offlineVaultRecoveryStore,
      recoveryService: s.offlineVaultRecovery,
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
    s.clinicalTelemetryEncryptedStorage =
        ClinicalTelemetryEncryptedStorage.forTest();
    s.sync = SyncService(s.api, s.journalStore, s.prefs);
    s.paywall = ValueMomentPaywallLogic(s.prefs);
    await s.prefs.setOnboardingCompleted(true);
    _instance = s;
    _initialized = true;
    _configureJournalSaveInterceptors(s);
  }

  /// P0 fix — cross-account archive leakage. See [JournalOwnershipGuard].
  /// Runs whenever an account becomes active on this device (fresh sign-in
  /// or a persisted session resumed at startup) so a shared/reused device
  /// never uploads one account's local-only entries under another
  /// account's session.
  static Future<void> _reconcileJournalOwnership(
    AppServices s,
    String userId,
  ) async {
    if (userId.isEmpty) return;
    const guard = JournalOwnershipGuard();
    final storedOwnerKey = await s.prefs.readString(
      JournalOwnershipGuard.ownerKeyPrefsKey,
    );
    final migrationPending =
        await s.prefs.readBool(JournalOwnershipGuard.migrationPendingPrefsKey) ??
        false;
    final result = guard.reconcile(
      storedOwnerKey: storedOwnerKey,
      migrationPending: migrationPending,
      signedInUserId: userId,
    );
    if (result.ownerKey != null) {
      await s.prefs.writeString(
        JournalOwnershipGuard.ownerKeyPrefsKey,
        result.ownerKey!,
      );
    }
    await s.prefs.writeBool(
      JournalOwnershipGuard.migrationPendingPrefsKey,
      result.migrationPending,
    );
    s.journalStore.setActiveOwnerKey(userId);
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

  /// Where a relative store path handed to [resetForTest] actually lands.
  ///
  /// `flutter test` runs with the package root as its working directory, so a
  /// suite asking for `journal.json` writes into the checkout and leaves the
  /// file behind — hundreds of stray `*_journal.json` and `*_prefs.json`
  /// artifacts accumulated this way. Rebasing relative paths onto a temporary
  /// directory keeps that pollution out of the repository without every suite
  /// having to remember to build a temp path itself.
  ///
  /// Absolute paths pass through untouched: a test that deliberately built one
  /// may also read it back, and silently relocating it would break that.
  static Directory? _testStorageRoot;

  static String _sandboxedTestPath(String candidate) {
    // Only POSIX absolute paths need recognising here; this runs under the
    // Dart test host, never on a device.
    if (candidate.startsWith('/')) return candidate;
    final root =
        _testStorageRoot ??= Directory.systemTemp.createTempSync(
          'archiveme_test_storage_',
        );
    return '${root.path}/$candidate';
  }

  static Future<void> resetForTest({
    required String journalPath,
    String? prefsPath,
    ApiClient? api,
    bool skipRevenueCat = false,
    RecordingService? recording,
  }) async {
    _initialized = false;
    final resolvedJournalPath = _sandboxedTestPath(journalPath);
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
    final file = File(resolvedJournalPath);
    if (await file.exists()) await file.delete();
    final encryptedFile = File(
      JournalStore.encryptedPathFor(resolvedJournalPath),
    );
    if (await encryptedFile.exists()) await encryptedFile.delete();
    s.journalStore = await JournalStore.open(
      resolvedJournalPath,
      encryptAtRest: false,
    );
    s.prefs = await MobilePrefsStore.open(
      prefsPath == null
          ? '${file.parent.path}/test_prefs.json'
          : _sandboxedTestPath(prefsPath),
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
    s.clinicalTelemetryEncryptedStorage =
        ClinicalTelemetryEncryptedStorage.forTest();
    _instance = s;
    _initialized = true;
    _configureJournalSaveInterceptors(s);
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

  static void _configureJournalSaveInterceptors(AppServices services) {
    final hookRepository = LocalCuriosityHookRepository.instance();
    final baselineStore = LocalCognitiveBaselineStore.instance();
    final trajectoryHistoryStore = LocalClinicalTrajectoryHistoryStore.instance();
    services.journalStore.configureSaveInterceptorPipeline(
      JournalSaveInterceptorPipeline.clinicalDefaults(
        hookRepository: hookRepository,
        journalStore: JournalStoreCuriosityHookJournalStore(services.journalStore),
        baselineStore: baselineStore,
        trajectoryHistoryStore: trajectoryHistoryStore,
      ),
    );
  }
}
