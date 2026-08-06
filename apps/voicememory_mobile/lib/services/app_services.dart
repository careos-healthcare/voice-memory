import 'dart:io';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../audio/recording_service.dart';
import '../billing/value_moment_paywall.dart';
import '../storage/account_namespace.dart';
import '../storage/app_storage_paths.dart';
import '../storage/capture_token_cache.dart';
import '../storage/device_id.dart';
import '../storage/entitlement_cache.dart';
import '../storage/journal_store.dart';
import '../storage/legacy_storage_migration.dart';
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
import '../security/account_session_scope.dart';
import '../features/native_push/native_push_service.dart';
import '../features/native_push/native_push_verification.dart';
import '../features/proof_admission/archive_correction_store.dart';
import '../features/proof_admission/proof_display_gate.dart';
import '../features/proof_admission/proof_scope_provider.dart';
import '../features/proof_admission/remote_processing_consent_store.dart';
import '../features/offline_sync/offline_sync_journey_store.dart';
import '../security/remote_processing_consent_gate.dart';
import '../features/encrypted_sync/sync_master_key_store.dart';
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
import '../core/config/v1_capability_registry.dart';
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
  static bool _optionalServicesInitialized = false;

  late final ApiClient api;
  late final DeviceIdStore deviceIds;
  late final SecureStorageService secureStorage;
  late final SessionCookieStore sessionCookies;
  late final CaptureTokenCache tokenCache;
  late final CaptureAttestService attest;

  // Account-scoped — physically separated per `AccountNamespace` (see
  // `activeNamespace`) and rewired wholesale by `_switchToNamespace` on
  // every sign-in/sign-out. Never `late final`: they are legitimately
  // reassigned, not just lazily initialized once.
  late JournalStore journalStore;
  late MobilePrefsStore prefs;
  late EntitlementCache entitlementCache;
  late CapturePipelineService pipeline;
  late JournalService journal;
  late BillingService billing;
  late SyncService sync;
  late RemoteProcessingConsentStore remoteProcessingConsentStore;
  late RemoteProcessingConsentGate remoteProcessingConsentGate;
  late SyncMasterKeyStore syncMasterKeyStore;
  late ValueMomentPaywallLogic paywall;
  late OfflineSyncJourneyStore offlineSyncJourney;
  late MemoryResurfacingService memoryResurfacing;
  late BeliefEvolutionService beliefEvolution;
  late ArchiveAgreementService archiveAgreement;

  // Device-global — deliberately never rewired on account switch. See the
  // reasoning next to each group below and in the final report.
  late final RecordingService recording;
  LiveVoiceCaptureService? _liveVoiceCapture;
  late final OfflineVaultRecoveryStore offlineVaultRecoveryStore;
  late final OfflineVaultRecoveryService offlineVaultRecovery;
  late final LifecycleNetworkConnectivitySource liveVoiceConnectivity;
  late final LiveVoiceRecoveryGateway liveVoiceRecoveryGateway;
  late final AuthService auth;
  late final NativePushVerificationStore nativePushStore;
  late final FcmService fcm;
  late final NativePushService nativePush;
  late EncryptedJsonStorage clinicalTelemetryEncryptedStorage;

  /// Base documents directory this device stores everything under —
  /// resolved once at startup; every namespace's directory
  /// (`accounts/<namespace.key>/...`) hangs off this same root.
  String _documentsBasePath = '';

  /// Whether `startListening()` should be (re)called on `billing` after a
  /// namespace switch — mirrors whichever construction path built this
  /// `AppServices` (production `initialize()` always listens; trial mode
  /// never does; `resetForTest` follows its `skipRevenueCat` flag).
  bool _billingListeningEnabled = false;

  late AccountNamespace _activeNamespace;

  /// Which on-device account namespace (`accounts/<namespace.key>/...`) the
  /// account-scoped fields above currently point at. Changes exactly once
  /// per sign-in/sign-out, inside `_switchToNamespace`. Other workstreams
  /// (e.g. the guest-data-migration feature) read this to know which
  /// account's data is presently active.
  AccountNamespace get activeNamespace => _activeNamespace;

  /// Base documents directory every namespace's `accounts/<key>/...`
  /// directory hangs off. Exposed read-only for features that need to
  /// reason about *other* namespaces' on-disk data than the currently
  /// active one — e.g. `AccountDataMigrationCoordinator` reading the guest
  /// namespace's journal while a different account is active.
  String get documentsBasePath => _documentsBasePath;

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
    await initializeEssential();
    await initializeOptionalServices();
  }

  /// Phase 2 — journal, prefs, pipeline, auth. Safe before V1 navigation.
  static Future<void> initializeEssential() async {
    if (_initialized) return;
    if (TrialMode.enabled) {
      await _initializeForTrial();
      return;
    }
    final s = AppServices._();
    final base = await _resolveDocumentsBasePath();
    s._documentsBasePath = base;

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
    s.recording = RecordingService();
    s.auth = AuthService(s.api, s.secureStorage, s.sessionCookies);

    await s.auth.loadPersistedSession();
    final resumedSession = s.auth.currentSession;
    final initialNamespace = resumedSession != null
        ? AccountNamespace.forUserId(resumedSession.userId)
        : AccountNamespace.guest;

    await _openNamespacedStores(
      s,
      base,
      initialNamespace,
      ownerUserId: resumedSession?.userId,
    );
    s._activeNamespace = initialNamespace;

    s.clinicalTelemetryEncryptedStorage =
        await ClinicalTelemetryEncryptedStorage.forSecureStorage(
          s.secureStorage,
        );
    _instance = s;
    _initialized = true;

    await TempRecordingCleanup.purgeStaleOnStartup(
      journalStore: s.journalStore,
    );
    await ArchiveMeDemoState.hydrateFromPrefs(s.prefs);

    if (resumedSession != null) {
      await _reconcileJournalOwnership(s, resumedSession.userId);
    }
    await GuestFirstAuth(
      s.prefs,
    ).markGuestModeStartedIfNeeded(isSignedIn: s.auth.currentSession != null);

    _wireAccountScopedServices(s);
    _registerAuthLifecycleCallbacks(s);
  }

  /// Phase 4 — billing, push, analytics, vault recovery. Must not block tabs.
  static Future<void> initializeOptionalServices() async {
    if (!_initialized) {
      throw StateError('Call AppServices.initializeEssential() first');
    }
    if (_optionalServicesInitialized) return;
    if (TrialMode.enabled) {
      _optionalServicesInitialized = true;
      return;
    }
    final s = instance;
    _optionalServicesInitialized = true;

    final resumedSession = s.auth.currentSession;
    await RevenueCatService.instance.initialize();
    if (resumedSession != null) {
      await RevenueCatService.instance.logIn(resumedSession.userId);
    }

    s._billingListeningEnabled = true;
    s.billing.startListening();

    s.offlineVaultRecoveryStore = OfflineVaultRecoveryStore();
    s.offlineVaultRecovery = OfflineVaultRecoveryService(
      store: s.offlineVaultRecoveryStore,
      api: s.api,
      attest: s.attest,
      pipeline: s.pipeline,
      consentGate: s.remoteProcessingConsentGate,
    );
    s.liveVoiceConnectivity = LifecycleNetworkConnectivitySource();
    s.liveVoiceRecoveryGateway = LiveVoiceRecoveryGateway(
      vault: LocalAudioVault(),
      connectivity: s.liveVoiceConnectivity,
      recoveryStore: s.offlineVaultRecoveryStore,
      recoveryService: s.offlineVaultRecovery,
      consentGate: s.remoteProcessingConsentGate,
    );

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
    if (V1CapabilityRegistry.notifications) {
      await s.fcm.initialize();
    }
    await ProductAnalytics.initialize();
  }

  static void _registerAuthLifecycleCallbacks(AppServices s) {
    Future<void> resetEntitlementsForAuthChange() async {
      await s.billing.resetCachedEntitlementsForAuthChange();
    }

    s.auth.onSignedOut = () async {
      await s._switchToNamespace(AccountNamespace.guest);
      s.journalStore.setActiveOwnerKey(null);
      if (_optionalServicesInitialized) {
        await RevenueCatService.instance.logOut();
      }
      await resetEntitlementsForAuthChange();
    };
    s.auth.onSignedIn = () async {
      await initializeOptionalServices();
      final userId = s.auth.currentSession?.userId;
      if (userId != null) {
        await s._switchToNamespace(
          AccountNamespace.forUserId(userId),
          ownerUserId: userId,
        );
        await _reconcileJournalOwnership(s, userId);
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
  }

  /// Trial participants: local journal + prefs only; no push, analytics, or
  /// billing. Trial mode never signs in, so it always runs in the guest
  /// namespace — but still through the same namespaced-storage path as
  /// production, so a later disabling of trial mode sees consistent files.
  static Future<void> _initializeForTrial() async {
    final s = AppServices._();
    final base = await _resolveDocumentsBasePath();
    s._documentsBasePath = base;

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
    s.recording = RecordingService(testMode: true);
    s.auth = AuthService(s.api, s.secureStorage, s.sessionCookies);

    const namespace = AccountNamespace.guest;
    await _openNamespacedStores(s, base, namespace);
    s._activeNamespace = namespace;
    s.clinicalTelemetryEncryptedStorage =
        ClinicalTelemetryEncryptedStorage.forTest();
    // See the matching comment in `initialize()`: registering early (rather
    // than at the very end) is required so `_wireAccountScopedServices`
    // below can resolve `AppServices.instance` for the curiosity-loop
    // repositories that read it directly.
    _instance = s;
    _initialized = true;

    await TempRecordingCleanup.purgeStaleOnStartup(
      journalStore: s.journalStore,
    );

    _wireAccountScopedServices(s);
    // Trial mode never calls billing.startListening() — no RevenueCat, no
    // push, no analytics — see class docs above.

    s.offlineVaultRecoveryStore = OfflineVaultRecoveryStore();
    s.offlineVaultRecovery = OfflineVaultRecoveryService(
      store: s.offlineVaultRecoveryStore,
      api: s.api,
      attest: s.attest,
      pipeline: s.pipeline,
      consentGate: s.remoteProcessingConsentGate,
    );
    s.liveVoiceConnectivity = LifecycleNetworkConnectivitySource();
    s.liveVoiceRecoveryGateway = LiveVoiceRecoveryGateway(
      vault: LocalAudioVault(),
      connectivity: s.liveVoiceConnectivity,
      recoveryStore: s.offlineVaultRecoveryStore,
      recoveryService: s.offlineVaultRecovery,
      consentGate: s.remoteProcessingConsentGate,
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
    await s.prefs.setOnboardingCompleted(true);
    // Trial mode has no onboarding UI to show the real consent prompt in
    // (see `setOnboardingCompleted(true)` just above, which skips onboarding
    // outright for the same reason), so it grants remote-processing consent
    // by the same fiat rather than leaving trial participants stuck with a
    // pipeline that can never analyze anything.
    await RemoteProcessingConsentStore(s.prefs).grant();
    _optionalServicesInitialized = true;
  }

  /// P0 fix — cross-account archive leakage. See [JournalOwnershipGuard].
  /// Runs whenever an account becomes active on this device (fresh sign-in
  /// or a persisted session resumed at startup) so a shared/reused device
  /// never uploads one account's local-only entries under another
  /// account's session. Physical per-namespace separation (see
  /// [_switchToNamespace]) is now the primary isolation mechanism; this
  /// remains as defence-in-depth on top of it.
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
        await s.prefs.readBool(
          JournalOwnershipGuard.migrationPendingPrefsKey,
        ) ??
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

  static String _journalPathFor(String base, AccountNamespace namespace) =>
      '$base/accounts/${namespace.key}/journal_entries.json';

  static String _prefsPathFor(String base, AccountNamespace namespace) =>
      '$base/accounts/${namespace.key}/mobile_prefs.json';

  static String _entitlementsPathFor(String base, AccountNamespace namespace) =>
      '$base/accounts/${namespace.key}/entitlements.json';

  /// Runs the one-time legacy relocation (see [LegacyStorageMigration]) and
  /// then opens `journalStore`/`prefs`/`entitlementCache` at [namespace]'s
  /// own directory and encryption-key alias.
  ///
  /// [ownerUserId] is the signed-in account [namespace] belongs to, when
  /// known — passed straight through to [LegacyStorageMigration] so it never
  /// relocates a *different* account's legacy-stamped entries into this
  /// namespace. Omit for the guest namespace.
  static Future<void> _openNamespacedStores(
    AppServices s,
    String base,
    AccountNamespace namespace, {
    String? ownerUserId,
  }) async {
    await LegacyStorageMigration.migrateIfNeeded(
      base: base,
      namespace: namespace,
      ownerUserId: ownerUserId,
      secureStorage: s.secureStorage,
    );
    s.journalStore = await JournalStore.open(
      _journalPathFor(base, namespace),
      secureStorage: s.secureStorage,
      keyAlias: namespace.key,
      // Under `flutter test`, there is no platform secure-storage plugin
      // backing key persistence, so the per-alias key generated for one
      // `JournalStore.open` call is never the same one a *later* call for
      // the same namespace (e.g. switching back to an account already
      // visited earlier in the same test) would generate — every call
      // would be a fresh random in-memory key. Production devices always
      // persist the real per-alias key in the keychain, so this only ever
      // takes the plaintext branch inside `flutter test`.
      encryptAtRest: !Platform.environment.containsKey('FLUTTER_TEST'),
    );
    s.prefs = await MobilePrefsStore.open(_prefsPathFor(base, namespace));
    s.entitlementCache = await EntitlementCache.open(
      _entitlementsPathFor(base, namespace),
    );
  }

  /// (Re)builds every service that is derived from `journalStore`/`prefs`/
  /// `entitlementCache` — called once at startup and again, on the freshly
  /// reopened stores, by [_switchToNamespace] on every account switch.
  static void _wireAccountScopedServices(AppServices s) {
    s.remoteProcessingConsentStore = RemoteProcessingConsentStore(s.prefs);
    s.remoteProcessingConsentGate = RemoteProcessingConsentGate(
      s.remoteProcessingConsentStore,
    );
    s.pipeline = CapturePipelineService(
      api: s.api,
      attest: s.attest,
      journalStore: s.journalStore,
      consentStore: s.remoteProcessingConsentStore,
    );
    s.journal = JournalService(s.journalStore);
    s.billing = BillingService(
      s.api,
      s.entitlementCache,
      RevenueCatService.instance,
    );
    s.offlineSyncJourney = OfflineSyncJourneyStore(s.prefs);
    s.memoryResurfacing = MemoryResurfacingService.fromPrefs(s.prefs);
    s.beliefEvolution = BeliefEvolutionService.fromPrefs(s.prefs);
    s.archiveAgreement = ArchiveAgreementService.fromPrefs(s.prefs);
    s.syncMasterKeyStore = SecureSyncMasterKeyStore(
      accountNamespace: s._activeNamespace.key,
    );
    s.sync = SyncService(
      s.api,
      s.journalStore,
      s.prefs,
      deviceIds: s.deviceIds,
      keyStore: s.syncMasterKeyStore,
    );
    s.paywall = ValueMomentPaywallLogic(s.prefs);
    // Bound to the now-stale `pipeline`/`offlineVaultRecoveryStore` pair —
    // dropped so the next access lazily rebuilds against the current ones.
    s._liveVoiceCapture = null;
    _configureJournalSaveInterceptors(s);
  }

  /// Physically switches every account-scoped field over to [target]'s own
  /// namespace: opens a fresh `journalStore`/`prefs`/`entitlementCache` at
  /// [target]'s directory/key-alias, then rebuilds everything derived from
  /// them. No-ops if [target] is already the active namespace.
  ///
  /// [journalStore], [prefs], and [entitlementCache] are simple read/write-
  /// on-demand wrappers around a [File] — none of them hold a persistent
  /// open file handle or stream across calls (confirmed by reading all
  /// three classes), so the outgoing instances need no explicit close
  /// before being dropped here.
  Future<void> _switchToNamespace(
    AccountNamespace target, {
    String? ownerUserId,
  }) async {
    if (target == _activeNamespace) return;
    final oldBilling = billing;
    final oldArchiveScope =
        AppServicesProofScopeProvider.archiveScopeForNamespace(
          _activeNamespace,
        );
    await _openNamespacedStores(
      this,
      _documentsBasePath,
      target,
      ownerUserId: ownerUserId,
    );
    AppServices._wireAccountScopedServices(this);
    oldBilling.dispose();
    if (_billingListeningEnabled) {
      billing.startListening();
    }
    _activeNamespace = target;
    AccountSessionRegistry.instance.activate(
      namespace: target,
      userId: ownerUserId,
    );
    await _reconcileProofScopedCachesForSwitch(this, oldArchiveScope);
  }

  /// Fires the proof/correction cache invalidation an account switch
  /// requires, for real: `ArchiveCorrectionStore` is re-[configure]d against
  /// [target]'s freshly-opened `prefs` (it otherwise keeps reading/writing
  /// through whichever `prefs` instance it was configured against at
  /// startup, silently stale after this point) and told to [switchArchive]
  /// to [target]'s own archive scope, which drops its in-memory corrections
  /// and reloads under the new scope. [ProofDisplayGate]'s shared admission
  /// cache is cleared outright with [ProofDisplayGate.invalidateForAccountSwitch]
  /// rather than scoped to [oldArchiveScope] alone: the *owner* scope also
  /// just changed, and an `invalidateArchive(oldArchiveScope)` call would
  /// still leave any same-archive/different-owner entries — there are none
  /// today, but the revision cache key already supports the combination —
  /// sitting stale. The cache is cheap to repopulate on next access, so
  /// clearing it outright is the safer choice.
  ///
  /// Both mechanisms (scope-keyed cache entries and an `invalidateArchive`/
  /// `invalidateAll` API) already existed before this method; what did not
  /// exist is anything that actually called them on a real account switch.
  static Future<void> _reconcileProofScopedCachesForSwitch(
    AppServices s,
    String oldArchiveScope,
  ) async {
    ArchiveCorrectionStore.instance.configure(s.prefs);
    const scopeProvider = AppServicesProofScopeProvider();
    final newArchiveScope = scopeProvider.activeArchiveScope;
    if (newArchiveScope != oldArchiveScope) {
      await ArchiveCorrectionStore.instance.switchArchive(newArchiveScope);
    }
    await ArchiveCorrectionStore.instance.ensureLoaded();
    ProofDisplayGate.invalidateForAccountSwitch();
  }

  /// Test-only entry point for [_switchToNamespace] — lets a test simulate
  /// switching to a different signed-in account (or to the guest namespace)
  /// within a single test run, without tearing down and reconstructing the
  /// whole [AppServices] singleton the way a real sign-in/out would.
  @visibleForTesting
  static Future<void> switchNamespaceForTest(
    AccountNamespace target, {
    String? ownerUserId,
  }) {
    return instance._switchToNamespace(target, ownerUserId: ownerUserId);
  }

  static Future<String> _resolveDocumentsBasePath() async {
    final dir = await AppStoragePaths.applicationDocumentsDirectory();
    return dir.path;
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
    final root = _testStorageRoot ??= Directory.systemTemp.createTempSync(
      'archiveme_test_storage_',
    );
    return '${root.path}/$candidate';
  }

  /// Resets the whole [AppServices] singleton for a fresh test.
  ///
  /// By default (no [namespace] passed) this behaves *exactly* as before
  /// per-account namespacing existed: [journalPath]/[prefsPath] are used
  /// verbatim (after test-sandboxing relative paths), matching the
  /// hundreds of existing call sites across the test suite. [namespace]
  /// is a new, purely additive parameter: when provided, `journalStore`/
  /// `prefs`/`entitlementCache` are instead opened at that namespace's own
  /// `accounts/<namespace.key>/...` directory under the same test sandbox
  /// root, so that a subsequent [switchNamespaceForTest] call switching
  /// away from and back to [namespace] round-trips through the *same*
  /// on-disk location this call used — required for a test to assert that
  /// switching back to an account restores its data.
  ///
  /// [grantRemoteProcessingConsentByDefault] (default `true`) pre-grants
  /// [RemoteProcessingConsentStore] consent for the opened namespace so the
  /// hundreds of existing tests that exercise remote analysis without
  /// setting up consent explicitly keep passing under the new
  /// default-false consent model introduced alongside this parameter. Pass
  /// `false` to test the real default (unconsented) behavior, or to test
  /// consent withdrawal from a clean, known starting state.
  static Future<void> resetForTest({
    required String journalPath,
    String? prefsPath,
    ApiClient? api,
    bool skipRevenueCat = false,
    RecordingService? recording,
    AccountNamespace? namespace,
    bool grantRemoteProcessingConsentByDefault = true,
  }) async {
    _initialized = false;
    _optionalServicesInitialized = false;
    final resolvedJournalPath = _sandboxedTestPath(journalPath);
    final s = AppServices._();
    final activeNamespace = namespace ?? AccountNamespace.guest;
    s._activeNamespace = activeNamespace;
    s._billingListeningEnabled = !skipRevenueCat;

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
    s._documentsBasePath = file.parent.path;

    final String effectiveJournalPath;
    final String effectivePrefsPath;
    final String effectiveEntitlementsPath;
    if (namespace != null) {
      final nsDir = '${s._documentsBasePath}/accounts/${namespace.key}';
      effectiveJournalPath = '$nsDir/journal_entries.json';
      effectivePrefsPath = prefsPath == null
          ? '$nsDir/mobile_prefs.json'
          : _sandboxedTestPath(prefsPath);
      effectiveEntitlementsPath = '$nsDir/entitlements.json';
    } else {
      effectiveJournalPath = resolvedJournalPath;
      effectivePrefsPath = prefsPath == null
          ? '${file.parent.path}/test_prefs.json'
          : _sandboxedTestPath(prefsPath);
      effectiveEntitlementsPath = '${file.parent.path}/test_entitlements.json';
    }

    final journalFile = File(effectiveJournalPath);
    if (await journalFile.exists()) await journalFile.delete();
    final encryptedFile = File(
      JournalStore.encryptedPathFor(effectiveJournalPath),
    );
    if (await encryptedFile.exists()) await encryptedFile.delete();
    s.journalStore = await JournalStore.open(
      effectiveJournalPath,
      encryptAtRest: false,
    );
    s.prefs = await MobilePrefsStore.open(effectivePrefsPath);
    s.entitlementCache = await EntitlementCache.open(effectiveEntitlementsPath);
    if (grantRemoteProcessingConsentByDefault) {
      await RemoteProcessingConsentStore(s.prefs).grant();
    }
    s.clinicalTelemetryEncryptedStorage =
        ClinicalTelemetryEncryptedStorage.forTest();
    // See the matching comment in `initialize()`: registering early is
    // required so `_wireAccountScopedServices` below can resolve
    // `AppServices.instance` for the curiosity-loop repositories that read
    // it directly.
    _instance = s;
    _initialized = true;

    s.recording = recording ?? RecordingService(testMode: true);
    s.auth = AuthService(s.api, s.secureStorage, s.sessionCookies);
    if (!skipRevenueCat) {
      await RevenueCatService.instance.initialize();
    }

    _wireAccountScopedServices(s);
    if (!skipRevenueCat) {
      s.billing.startListening();
    }

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
    s.offlineVaultRecoveryStore = OfflineVaultRecoveryStore();
    s.offlineVaultRecovery = OfflineVaultRecoveryService(
      store: s.offlineVaultRecoveryStore,
      api: s.api,
      attest: s.attest,
      pipeline: s.pipeline,
      consentGate: s.remoteProcessingConsentGate,
    );
    s.liveVoiceConnectivity = LifecycleNetworkConnectivitySource();
    s.liveVoiceRecoveryGateway = LiveVoiceRecoveryGateway(
      vault: LocalAudioVault(),
      connectivity: s.liveVoiceConnectivity,
      recoveryStore: s.offlineVaultRecoveryStore,
      recoveryService: s.offlineVaultRecovery,
      consentGate: s.remoteProcessingConsentGate,
    );
    await BetaFeedbackStore.resetForTest();
    await ConfirmedRepeatBetaFeedbackStore.resetPersistedState();
    await CoreValueFeedbackStore.resetPersistedState();
    ArchiveBetaMissionGate.disableForHarness();
    await ArchiveBetaMissionStore.resetPersistedState();
    await BetaTestScriptStore.resetPersistedState(AppServices.instance.prefs);
    await TesterMissionStore.resetPersistedState();
    await ConfirmedRepeatWhyMattersStore.resetPersistedState();
    await ConfirmedRepeatThoughtMapStore.resetPersistedState();
    ArchiveMeDemoState.resetPersistedState();
    await RepeatReturnCheckStore.resetPersistedState();
    await ComeBackTomorrowV2Store.resetPersistedState(s.prefs);
    await FirstProofTruthStore.resetPersistedState(s.prefs);
    await WhatChangedV2Store.resetPersistedState();
    await HelpedTrackingStore.resetPersistedState();
    PatternNameStore.resetPersistedState();
    MicrophonePermissionEnvironment.resetPersistedState();
    QuietSignalAnalytics.resetPersistedState();
    await ProEvidenceValueDismissStore.resetPersistedState();
    await ProLockMomentDismissStore.resetPersistedState();
    await MonthlyPrivateReportDismissStore.resetPersistedState();
    await ArchiveBackupBridgeDismissStore.resetPersistedState();
    await BetaFeedbackIntelligenceStore.resetPersistedState();
    _optionalServicesInitialized = !skipRevenueCat;
  }

  static void _configureJournalSaveInterceptors(AppServices services) {
    final hookRepository = LocalCuriosityHookRepository.instance();
    final baselineStore = LocalCognitiveBaselineStore.instance();
    final trajectoryHistoryStore =
        LocalClinicalTrajectoryHistoryStore.instance();
    services.journalStore.configureSaveInterceptorPipeline(
      JournalSaveInterceptorPipeline.clinicalDefaults(
        hookRepository: hookRepository,
        journalStore: JournalStoreCuriosityHookJournalStore(
          services.journalStore,
        ),
        baselineStore: baselineStore,
        trajectoryHistoryStore: trajectoryHistoryStore,
      ),
    );
  }
}
