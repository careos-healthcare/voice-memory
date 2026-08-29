import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/audio/recording_service.dart';
import 'package:archiveme_mobile/auth/guest_first_auth.dart';
import 'package:archiveme_mobile/billing/billing_service.dart';
import 'package:archiveme_mobile/billing/revenuecat_service.dart';
import 'package:archiveme_mobile/billing/value_moment_paywall.dart';
import 'package:archiveme_mobile/core/config/v1_billing_capability.dart';
import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/config/archive_me_demo_state.dart';
import 'package:archiveme_mobile/core/config/excluded_native_capability_cleanup.dart';
import 'package:archiveme_mobile/config/trial_mode.dart';
import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/core/di/app_provider_container.dart';
import 'package:archiveme_mobile/core/di/archive_feed_providers.dart';
import 'package:archiveme_mobile/core/di/storage_providers.dart';
import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/archive/v1/archive_feed_pagination_provider.dart';
import 'package:archiveme_mobile/core/di/network_providers.dart';
import 'package:archiveme_mobile/core/network/voice_memory_api_client_bundle.dart';
import 'package:archiveme_mobile/features/capture/capture_module_config.dart';
import 'package:archiveme_mobile/features/capture/providers/capture_module_providers.dart';
import 'package:archiveme_mobile/core/network/http_transport.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/core/network/session_cookie_source.dart';
import 'package:archiveme_mobile/core/user/user_settings_store.dart';
import 'package:archiveme_mobile/data/network/http_sync_api_client.dart';
import 'package:archiveme_mobile/data/repositories/account_repository.dart';
import 'package:archiveme_mobile/data/repositories/sync_repository.dart';
import 'package:archiveme_mobile/features/archive_agreement/archive_agreement_service.dart';
import 'package:archiveme_mobile/features/activation/archive_insight_feedback.dart';
import 'package:archiveme_mobile/features/archive_backup_bridge/archive_backup_bridge_dismiss_store.dart';
import 'package:archiveme_mobile/features/auth/application/auth_session_notifier.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_evolution_service.dart';
import 'package:archiveme_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:archiveme_mobile/features/beta/archive_beta_mission_store.dart';
import 'package:archiveme_mobile/features/beta/confirmed_repeat_beta_feedback_store.dart';
import 'package:archiveme_mobile/features/beta/core_value_feedback_store.dart';
import 'package:archiveme_mobile/features/beta/tester_mission_store.dart';
import 'package:archiveme_mobile/features/beta_feedback/beta_feedback_store.dart';
import 'package:archiveme_mobile/features/beta_feedback_intelligence/beta_feedback_intelligence_store.dart';
import 'package:archiveme_mobile/features/beta_test_script/beta_test_script_store.dart';
import 'package:archiveme_mobile/features/billing/application/billing_notifier.dart';
import 'package:archiveme_mobile/features/come_back_tomorrow/come_back_tomorrow_v2_store.dart';
import 'package:archiveme_mobile/features/curiosity_loop/application/curiosity_hook_journal_store.dart';
import 'package:archiveme_mobile/features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import 'package:archiveme_mobile/features/curiosity_loop/domain/models/curiosity_hook.dart';
import 'package:archiveme_mobile/features/curiosity_loop/infrastructure/clinical_telemetry_encrypted_storage.dart';
import 'package:archiveme_mobile/features/curiosity_loop/repositories/clinical_trajectory_history_store.dart';
import 'package:archiveme_mobile/features/curiosity_loop/repositories/cognitive_baseline_store.dart';
import 'package:archiveme_mobile/features/curiosity_loop/repositories/curiosity_hook_repository.dart';
import 'package:archiveme_mobile/features/early_archive/confirmed_repeat_thought_map_store.dart';
import 'package:archiveme_mobile/features/early_archive/confirmed_repeat_why_matters_store.dart';
import 'package:archiveme_mobile/features/encrypted_sync/encrypted_journal_sync_coordinator.dart';
import 'package:archiveme_mobile/storage/drift/journal_database.dart';
import 'package:archiveme_mobile/sync/sync_engine.dart';
import 'package:archiveme_mobile/sync/sync_outbox_background_service.dart';
import 'package:archiveme_mobile/features/weekly_synthesis/background/background_task_account_registry.dart';
import 'package:archiveme_mobile/features/weekly_synthesis/background/weekly_synthesis_workmanager.dart';
import 'package:archiveme_mobile/sync/cloud_backup.dart';
import 'package:archiveme_mobile/sync/sqlite_vault/sqlite_vault.dart';
import 'package:archiveme_mobile/features/first_proof_truth/first_proof_truth_store.dart';
import 'package:archiveme_mobile/features/helped_tracking/helped_tracking_store.dart';
import 'package:archiveme_mobile/features/journal/domain/interceptors/journal_save_interceptor.dart';
import 'package:archiveme_mobile/features/journal/infrastructure/journal_save_interceptor_pipeline.dart';
import 'package:archiveme_mobile/features/live_audio/application/live_audio_session_coordinator.dart';
import 'package:archiveme_mobile/features/live_audio/application/live_voice_capture_service.dart';
import 'package:archiveme_mobile/features/live_audio/application/live_voice_recovery_gateway.dart';
import 'package:archiveme_mobile/features/live_audio/application/offline_vault_recovery_service.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/live_audio_session_api_client.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/local_audio_vault.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/connectivity_aware_network_source.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/network_connectivity_source.dart';
import 'package:archiveme_mobile/features/sync/application/background_sync_notifier.dart';
import 'package:archiveme_mobile/features/sync/application/network_connectivity_notifier.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/offline_vault_recovery_store.dart';
import 'package:archiveme_mobile/features/live_audio/presentation/controllers/live_audio_session_controller.dart';
import 'package:archiveme_mobile/features/memory_resurfacing/memory_resurfacing_service.dart';
import 'package:archiveme_mobile/features/monthly_private_report/monthly_private_report_dismiss_store.dart';
import 'package:archiveme_mobile/features/native_push/native_push_service.dart';
import 'package:archiveme_mobile/features/native_push/native_push_verification.dart';
import 'package:archiveme_mobile/features/offline_sync/offline_sync_journey_store.dart';
import 'package:archiveme_mobile/features/pattern_naming/pattern_name_store.dart';
import 'package:archiveme_mobile/features/pro_evidence_value/pro_evidence_value_dismiss_store.dart';
import 'package:archiveme_mobile/features/pro_lock_moment/pro_lock_moment_dismiss_store.dart';
import 'package:archiveme_mobile/features/proof_admission/archive_correction_store.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_service.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_display_gate.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_scope_provider.dart';
import 'package:archiveme_mobile/features/quick_capture/quick_capture_outbox_store.dart';
import 'package:archiveme_mobile/features/quick_capture/quick_capture_shared_storage.dart';
import 'package:archiveme_mobile/features/quick_capture/quick_capture_widget_bridge.dart';
import 'package:archiveme_mobile/features/quick_capture/quick_capture_widget_service.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/features/quiet_signal/quiet_signal_analytics.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_store.dart';
import 'package:archiveme_mobile/features/sync/application/sync_notifier.dart';
import 'package:archiveme_mobile/features/voice_capture/microphone_permission_environment.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/provisional_transcript_reconciler.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale_store.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_middleware.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_proof_analyzer.dart';
import 'package:archiveme_mobile/services/sync/background_sync_queue_gateway.dart';
import 'package:archiveme_mobile/services/sync/background_sync_queue_worker.dart';
import 'package:archiveme_mobile/services/sync/deferred_proof_admission_reconciler.dart';
import 'package:archiveme_mobile/features/journal/infrastructure/journal_fact_ledger_citation_interceptor.dart';
import 'package:archiveme_mobile/services/sync/journal_save_sync_enqueue_interceptor.dart';
import 'package:archiveme_mobile/features/coach/local_rag/local_coach_conversation_service.dart';
import 'package:archiveme_mobile/features/insights/rag/local_routine_rag_engine.dart';
import 'package:archiveme_mobile/features/insights/trend_analysis/trend_analysis_report_store.dart';
import 'package:archiveme_mobile/features/insights/trend_analysis/trend_analysis_service.dart';
import 'package:archiveme_mobile/features/search/journal_reflection_embedding_interceptor.dart';
import 'package:archiveme_mobile/features/search/reflection_embedding_index_worker.dart';
import 'package:archiveme_mobile/workers/embedding/embedding_index_worker_service.dart';
import 'package:archiveme_mobile/workers/local_llm/local_llm_worker_service.dart';
import 'package:archiveme_mobile/workers/speech_to_text/speech_to_text_worker_service.dart';
import 'package:archiveme_mobile/features/search/reflection_embedding_repository.dart';
import 'package:archiveme_mobile/features/watch/watch_audio_ingest_service.dart';
import 'package:archiveme_mobile/features/watch/watch_audio_ingest_store.dart';
import 'package:archiveme_mobile/features/watch_companion/watch_connectivity_service.dart';
import 'package:archiveme_mobile/features/what_changed/what_changed_v2_store.dart';
import 'package:archiveme_mobile/push/fcm_service.dart';
import 'package:archiveme_mobile/security/account_session_scope.dart';
import 'package:archiveme_mobile/security/sqlite/secure_sqlite_lock_service.dart';
import 'package:archiveme_mobile/security/sqlite/sqlite_encryption_key_store.dart';
import 'package:archiveme_mobile/security/private_data_service.dart';
import 'package:archiveme_mobile/security/remote_processing_consent_gate.dart';
import 'package:archiveme_mobile/features/clinical_sandbox/gates/clinical_consent_gate.dart';
import 'package:archiveme_mobile/features/clinical_sandbox/runtime/clinical_sandbox_runtime.dart';
import 'package:archiveme_mobile/features/clinical_sandbox/stores/clinical_consent_store.dart';
import 'package:archiveme_mobile/features/relationships/user_relationship_repository.dart';
import 'package:archiveme_mobile/services/api_service.dart';
import 'package:archiveme_mobile/services/auth_service.dart';
import 'package:archiveme_mobile/services/capture_attest_service.dart';
import 'package:archiveme_mobile/services/capture_pipeline_service.dart';
import 'package:archiveme_mobile/services/journal_ownership_guard.dart';
import 'package:archiveme_mobile/services/journal_service.dart';
import 'package:archiveme_mobile/services/automated_graph/automated_graph_index_worker.dart';
import 'package:archiveme_mobile/services/automated_graph/automated_graph_service.dart';
import 'package:archiveme_mobile/services/automated_graph/journal_automated_graph_interceptor.dart';
import 'package:archiveme_mobile/services/audio_structuring/audio_structuring_service.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_bootstrap.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_service.dart';
import 'package:archiveme_mobile/services/local_llm/model_download_service.dart';
import 'package:archiveme_mobile/services/ai/ai_service.dart';
import 'package:archiveme_mobile/services/ai/ai_service_bootstrap.dart';
import 'package:archiveme_mobile/services/offline_tts/offline_tts_bootstrap.dart';
import 'package:archiveme_mobile/services/offline_tts/offline_tts_service.dart';
import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_tracker.dart';
import 'package:archiveme_mobile/features/beta_analytics/product_analytics_consent_store.dart';
import 'package:archiveme_mobile/services/product_analytics.dart';
import 'package:archiveme_mobile/core/hardware/resource_guard.dart';
import 'package:archiveme_mobile/services/thermal_throttling/thermal_throttling_service.dart';
import 'package:archiveme_mobile/services/sync_service.dart';
import 'package:archiveme_mobile/storage/sqlite/embedding_deferred_queue_store.dart';
import 'package:archiveme_mobile/storage/account_namespace.dart';
import 'package:archiveme_mobile/storage/app_storage_paths.dart';
import 'package:archiveme_mobile/storage/capture_token_cache.dart';
import 'package:archiveme_mobile/storage/device_id.dart';
import 'package:archiveme_mobile/storage/encrypted_json_storage.dart';
import 'package:archiveme_mobile/storage/entitlement_cache.dart';
import 'package:archiveme_mobile/storage/in_memory_secure_storage.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/legacy_storage_migration.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:archiveme_mobile/storage/personal_content_encrypted_storage.dart';
import 'package:archiveme_mobile/storage/secure_storage.dart';
import 'package:archiveme_mobile/storage/session_cookie_store.dart';
import 'package:archiveme_mobile/features/reflections/local_ai_pipeline.dart';
import 'package:archiveme_mobile/features/vision/image_embedding_service.dart';
import 'package:archiveme_mobile/features/vision/local_visual_projection_inference.dart';
import 'package:archiveme_mobile/storage/isolate/local_database_worker_service.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/image_attachment_embedding_repository.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:http/http.dart' as http;

class AppServices {
  AppServices._();

  static AppServices? _instance;
  static bool _initialized = false;
  static bool _optionalServicesInitialized = false;

  late final DeviceIdStore deviceIds;
  late final SecureStorageService secureStorage;
  late final SessionCookieStore sessionCookies;
  late final SessionCookieSource sessionCookieSource;
  late final HttpTransport httpTransport;
  late final CaptureTokenCache tokenCache;
  late final CaptureAttestService attest;

  // Account-scoped — physically separated per `AccountNamespace` (see
  // `activeNamespace`) and rewired wholesale by `_switchToNamespace` on
  // every sign-in/sign-out. Never `late final`: they are legitimately
  // reassigned, not just lazily initialized once.
  late JournalStore journalStore;
  late MobilePrefsStore prefs;
  late EntitlementCache entitlementCache;
  late AppSqliteDatabase sqliteDatabase;
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
  late UserSettingsStore userSettings;
  late ClinicalConsentStore clinicalConsentStore;

  // Device-global — deliberately never rewired on account switch. See the
  // reasoning next to each group below and in the final report.
  late final RecordingService recording;
  LiveVoiceCaptureService? _liveVoiceCapture;
  OfflineTtsService? _offlineTts;
  Future<OfflineTtsService?>? _offlineTtsFuture;
  LocalLlmService? _localLlm;
  Future<LocalLlmService?>? _localLlmFuture;
  AIService? _aiService;
  Future<AIService?>? _aiServiceFuture;
  ModelDownloadService? _modelDownloadService;
  AudioStructuringService? _audioStructuring;
  Future<AudioStructuringService?>? _audioStructuringFuture;
  late final OfflineVaultRecoveryStore offlineVaultRecoveryStore;
  late final OfflineVaultRecoveryService offlineVaultRecovery;
  late final ConnectivityAwareNetworkSource liveVoiceConnectivity;
  late final LiveVoiceRecoveryGateway liveVoiceRecoveryGateway;
  BackgroundSyncQueueWorker? _backgroundSyncQueueWorker;
  BackgroundSyncQueueGateway? _backgroundSyncQueueGateway;
  QuickCaptureWidgetService? _quickCaptureWidgetService;
  ReflectionEmbeddingIndexWorker? _reflectionEmbeddingIndexWorker;
  AutomatedGraphIndexWorker? _automatedGraphIndexWorker;
  ThermalThrottlingService? _thermalThrottlingService;
  ResourceGuard? _resourceGuard;
  LocalRoutineRagEngine? _routineRagEngine;
  Future<LocalRoutineRagEngine>? _routineRagEngineFuture;
  TrendAnalysisService? _trendAnalysisService;
  Future<TrendAnalysisService>? _trendAnalysisServiceFuture;
  LocalCoachConversationService? _localCoachConversationService;
  Future<LocalCoachConversationService>? _localCoachConversationServiceFuture;
  late SecureSqliteLockService secureSqliteLock;
  late SqliteEncryptionKeyStore sqliteEncryptionKeyStore;
  late final AuthService auth;
  late final NativePushVerificationStore nativePushStore;
  late final FcmService fcm;
  late final NativePushService nativePush;
  WatchConnectivityService? _watchConnectivity;
  WatchAudioIngestService? _watchAudioIngest;
  late EncryptedJsonStorage clinicalTelemetryEncryptedStorage;
  late EncryptedJsonStorage personalContentEncryptedStorage;

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

  /// Absolute path to the active account's drift SQLite file.
  String get activeSqliteFilePath =>
      _sqlitePathFor(_documentsBasePath, _activeNamespace);

  /// Base documents directory every namespace's `accounts/<key>/...`
  /// directory hangs off. Exposed read-only for features that need to
  /// reason about *other* namespaces' on-disk data than the currently
  /// active one — e.g. `AccountDataMigrationCoordinator` reading the guest
  /// namespace's journal while a different account is active.
  String get documentsBasePath => _documentsBasePath;

  String get nativePushPlatform => Platform.isIOS ? 'ios' : 'android';

  AccountRepository get accountRepository =>
      appProviderContainer.read(accountRepositoryProvider);

  ApiService get apiService => ApiService(httpTransport);

  UserRelationshipRepository get userRelationshipRepository =>
      UserRelationshipRepository(sqliteDatabase);

  /// Rebinds journal save interceptors after clinical consent changes.
  void refreshClinicalSandboxInterceptors() {
    _configureJournalSaveInterceptors(this);
  }

  LiveVoiceCaptureService get liveVoiceCapture {
    if (!V1CapabilityRegistry.liveVoice) {
      throw StateError('Live voice is disabled for the focused V1 release');
    }
    final existing = _liveVoiceCapture;
    if (existing != null) return existing;
    final created = LiveVoiceCaptureService(
      controller: LiveAudioSessionController(
        LiveAudioSessionCoordinator(
          sessionApi: RepositoryLiveAudioSessionClient(
            appProviderContainer.read(liveAudioRepositoryProvider),
          ),
          attest: attest,
        ),
      ),
      pipeline: pipeline,
      recoveryStore: offlineVaultRecoveryStore,
    );
    _liveVoiceCapture = created;
    return created;
  }

  /// Lazily loads the device-global offline TTS voice when bundled or sideloaded
  /// model files are present. Returns null when no voice package is available.
  Future<OfflineTtsService?> resolveOfflineTts() {
    final cached = _offlineTts;
    if (cached != null) {
      return Future.value(cached);
    }

    final pending = _offlineTtsFuture;
    if (pending != null) {
      return pending;
    }

    final future =
        OfflineTtsBootstrap.tryCreate(
          documentsBasePath: _documentsBasePath,
        ).then((service) {
          _offlineTts = service;
          return service;
        });
    _offlineTtsFuture = future;
    return future;
  }

  /// Resolves a lazily loaded [AudioStructuringService] that shares the same
  /// GGUF weights as [resolveLocalLlm].
  Future<AudioStructuringService?> resolveAudioStructuring() {
    final cached = _audioStructuring;
    if (cached != null) {
      return Future.value(cached);
    }

    final pending = _audioStructuringFuture;
    if (pending != null) {
      return pending;
    }

    final future = resolveLocalLlm().then((llm) {
      if (llm == null) {
        return null;
      }
      final service = AudioStructuringService(localLlm: llm);
      _audioStructuring = service;
      return service;
    });
    _audioStructuringFuture = future;
    return future;
  }

  /// Drops cached local LLM handles when the app backgrounds.
  static void releaseLocalLlmMemoryForBackground() {
    final services = _instance;
    if (services == null) return;

    services._localLlm = null;
    services._localLlmFuture = null;
    services._audioStructuring = null;
    services._audioStructuringFuture = null;
  }

  /// Remote GGUF download + progress stream (device-global).
  ModelDownloadService get modelDownloadService =>
      _modelDownloadService ??= ModelDownloadService();

  /// Lazily loads a Q4_K_M GGUF via llama.cpp when a downloaded or sideloaded
  /// model is present. Returns null when no model package is available.
  Future<LocalLlmService?> resolveLocalLlm() {
    final cached = _localLlm;
    if (cached != null) {
      return Future.value(cached);
    }

    final pending = _localLlmFuture;
    if (pending != null) {
      return pending;
    }

    final future = modelDownloadService
        .ensureModelDownloaded()
        .then(
          (modelPath) => LocalLlmBootstrap.tryCreate(
            modelDownloadService: modelDownloadService,
            documentsBasePath: _documentsBasePath,
            modelPathOverride: modelPath,
          ),
        )
        .then((service) {
          _localLlm = service;
          return service;
        });
    _localLlmFuture = future;
    return future;
  }

  /// Lazily bootstraps flutter_gemma (LiteRT-LM + moonshine STT) when available.
  Future<AIService?> resolveAIService() {
    final cached = _aiService;
    if (cached != null) {
      return Future.value(cached);
    }

    final pending = _aiServiceFuture;
    if (pending != null) {
      return pending;
    }

    final future =
        AiServiceBootstrap.tryCreate(
          resourceGuard: _resourceGuard,
        ).then((service) {
          _aiService = service;
          return service;
        });
    _aiServiceFuture = future;
    return future;
  }

  /// Local RAG engine for morning/evening journal prompts — rebuilt per namespace.
  Future<LocalRoutineRagEngine> get routineRagEngine {
    final cached = _routineRagEngine;
    if (cached != null) return Future.value(cached);

    final pending = _routineRagEngineFuture;
    if (pending != null) return pending;

    final future =
        LocalRoutineRagEngine.create(
          journalRepository: JournalSqliteRepository(sqliteDatabase),
          embeddingRepository: ReflectionEmbeddingRepository(sqliteDatabase),
        ).then((engine) {
          _routineRagEngine = engine;
          return engine;
        });
    _routineRagEngineFuture = future;
    return future;
  }

  /// Background weekly trend analysis over drift reflections + local ONNX.
  Future<TrendAnalysisService> get trendAnalysisService {
    final cached = _trendAnalysisService;
    if (cached != null) return Future.value(cached);

    final pending = _trendAnalysisServiceFuture;
    if (pending != null) return pending;

    final future =
        TrendAnalysisService.create(
          journalDatabase: AppDatabase.fromSqflite(sqliteDatabase.database),
          reportStore: TrendAnalysisReportStore(prefs),
        ).then((service) {
          _trendAnalysisService = service;
          return service;
        });
    _trendAnalysisServiceFuture = future;
    return future;
  }

  /// Offline RAG coach — local vector retrieval + ONNX conversational follow-ups.
  Future<LocalCoachConversationService> get localCoachConversationService {
    final cached = _localCoachConversationService;
    if (cached != null) return Future.value(cached);

    final pending = _localCoachConversationServiceFuture;
    if (pending != null) return pending;

    final future =
        LocalCoachConversationService.create(
          journalRepository: JournalSqliteRepository(sqliteDatabase),
          embeddingRepository: ReflectionEmbeddingRepository(sqliteDatabase),
        ).then((service) {
          _localCoachConversationService = service;
          return service;
        });
    _localCoachConversationServiceFuture = future;
    return future;
  }

  /// E2E encrypted drift export/import for personal iCloud / Google Drive folders.
  EncryptedCloudBackupService get encryptedCloudBackupService =>
      EncryptedCloudBackupService.fromAppServices(this);

  /// Silent AES-GCM SQLite vault sync to a private iCloud ubiquity container.
  EncryptedSqliteVaultSyncPipeline get sqliteVaultSyncPipeline =>
      EncryptedSqliteVaultSyncPipeline(
        sqliteFilePath: activeSqliteFilePath,
        accountNamespace: activeNamespace,
        openDatabase: sqliteDatabase.database,
        closeDatabase: () => sqliteDatabase.close(),
        reopenDatabase: () => reopenSqliteDatabase(),
        keyStore: SecureSqliteVaultKeyStore(
          accountNamespace: activeNamespace.key,
        ),
        cloudTransport: ICloudSqliteVaultTransport(),
      );

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

  WatchConnectivityService? get watchConnectivity => _watchConnectivity;

  WatchAudioIngestService? get watchAudioIngest => _watchAudioIngest;

  QuickCaptureWidgetService? get quickCaptureWidgetService =>
      _quickCaptureWidgetService;

  /// Ingests widget / shortcut captures and runs the background pipeline.
  Future<void> processQuickCaptureWidgetQueue() async {
    final service = _quickCaptureWidgetService;
    if (service == null) return;
    try {
      await service.ingestAndProcessBackgroundQueue();
    } on Object catch (error, stackTrace) {
      assert(() {
        // ignore: avoid_print
        print('QuickCaptureWidgetService failed: $error\n$stackTrace');
        return true;
      }());
    }
  }

  static AppServices get instance {
    final i = _instance;
    if (i == null || !_initialized) {
      throw StateError('Call AppServices.initialize() first');
    }
    return i;
  }

  /// Disposes background workers and closes sqlite for widget-test teardown.
  static Future<void> shutdownForTest() async {
    final previous = _instance;
    if (previous == null) return;
    await previous._shutdownForTest();
  }

  /// Cancels pending debounced background flushes so they cannot fire after a
  /// test completes and run against a database the next test is about to close
  /// (`database_closed` "after the test had completed"). Only cancels timers —
  /// it does NOT close the database, dispose the workers, or await in-flight
  /// network work (which can hang), so it is safe to call from a global tearDown
  /// even for suites that initialize [AppServices] once in setUpAll. A flush
  /// that is already running is handled defensively inside each worker, which
  /// treats a mid-flight `database_closed` as an expected shutdown race.
  static void quiesceBackgroundWorkersForTest() {
    final s = _instance;
    if (s == null) return;
    s._backgroundSyncQueueWorker?.quiesceForTest();
    s._reflectionEmbeddingIndexWorker?.quiesceForTest();
    s._automatedGraphIndexWorker?.quiesceForTest();
  }

  Future<void> _shutdownForTest() async {
    _backgroundSyncQueueWorker?.dispose();
    _backgroundSyncQueueWorker = null;
    _reflectionEmbeddingIndexWorker?.dispose();
    _reflectionEmbeddingIndexWorker = null;
    _automatedGraphIndexWorker?.dispose();
    _automatedGraphIndexWorker = null;
    _thermalThrottlingService?.dispose();
    _thermalThrottlingService = null;
    _resourceGuard?.dispose();
    _resourceGuard = null;
    _backgroundSyncQueueGateway?.dispose();
    _backgroundSyncQueueGateway = null;
    _trendAnalysisService?.dispose();
    _trendAnalysisService = null;
    _trendAnalysisServiceFuture = null;
    if (_offlineTts != null) {
      await _offlineTts!.dispose();
      _offlineTts = null;
      _offlineTtsFuture = null;
    }
    if (_localLlm != null) {
      await _localLlm!.dispose();
      _localLlm = null;
      _localLlmFuture = null;
    }
    _audioStructuring = null;
    _audioStructuringFuture = null;
    await SpeechToTextWorkerService.instance.dispose();
    await LocalLlmWorkerService.instance.dispose();
    await _modelDownloadService?.dispose();
    _modelDownloadService = null;
    await EmbeddingIndexWorkerService.instance.dispose();
    try {
      await sqliteDatabase.close();
    } catch (e, stackTrace) {
      AppLogger.error(
        'Unhandled error caught',
        error: e,
        stackTrace: stackTrace,
      );
      // Already closed or never opened.
    }
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
    s.sessionCookieSource = SessionCookieSource(s.sessionCookies);
    await s.sessionCookieSource.hydrateFromStore();
    _configureProviderContainer(s);

    s.deviceIds = DeviceIdStore();
    s.tokenCache = CaptureTokenCache();
    s.attest = CaptureAttestService(
      captureRepository: appProviderContainer.read(captureRepositoryProvider),
      deviceIds: s.deviceIds,
      tokenCache: s.tokenCache,
    );
    s.recording = appProviderContainer.read(recordingServiceProvider.notifier);
    s.auth = AuthService(
      appProviderContainer.read(authSessionProvider.notifier),
    );

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
    await ExcludedNativeCapabilityCleanup.runIfNeeded(s.prefs);

    if (resumedSession != null) {
      await _reconcileJournalOwnership(s, resumedSession.userId);
    }
    await GuestFirstAuth(
      s.prefs,
    ).markGuestModeStartedIfNeeded(isSignedIn: s.auth.currentSession != null);

    _wireAccountScopedServices(s);
    unawaited(
      BackgroundTaskAccountRegistry.persistActiveNamespace(s._activeNamespace),
    );
    if (V1CapabilityRegistry.backgroundProcessing) {
      unawaited(WeeklySynthesisWorkScheduler.registerWeeklyTask());
    }
    unawaited(s.modelDownloadService.ensureModelDownloaded());
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
    if (!V1BillingCapability.isEnabled) {
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
      captureRepository: appProviderContainer.read(captureRepositoryProvider),
      attest: s.attest,
      pipeline: s.pipeline,
      consentGate: s.remoteProcessingConsentGate,
    );
    s.liveVoiceConnectivity = ConnectivityAwareNetworkSource()..start();
    _wireNetworkConnectivityNotifier(s);
    s.liveVoiceRecoveryGateway = LiveVoiceRecoveryGateway(
      vault: LocalAudioVault(),
      connectivity: s.liveVoiceConnectivity,
      recoveryStore: s.offlineVaultRecoveryStore,
      recoveryService: s.offlineVaultRecovery,
      consentGate: s.remoteProcessingConsentGate,
    );
    _wireBackgroundSyncQueue(s);

    s.nativePushStore = NativePushVerificationStore(s.prefs);
    s.fcm = FcmService(
      store: s.nativePushStore,
      getDeviceId: () => s.deviceIds.getOrCreate(),
      registerToken:
          ({required deviceId, required platform, required fcmToken}) async {
            final result = await appProviderContainer
                .read(pushApiClientProvider)
                .registerPushDevice(
                  deviceId: deviceId,
                  platform: platform,
                  fcmToken: fcmToken,
                );
            result.when(
              success: (_) {},
              onFailure: (failure) => throw failure.toApiException(),
            );
          },
      sendTestPush: ({required deviceId, required targetRoute}) async {
        final result = await appProviderContainer
            .read(pushApiClientProvider)
            .sendInternalTestPush(
              deviceId: deviceId,
              targetRoute: targetRoute,
              debugToken: AppConfig.internalDebugToken,
            );
        return result.when(
          success: (body) => body,
          onFailure: (failure) => throw failure.toApiException(),
        );
      },
    );
    s.nativePush = NativePushService(s.fcm);
    if (V1CapabilityRegistry.notifications) {
      await s.fcm.initialize();
    }
    if (V1CapabilityRegistry.watchCompanion) {
      s._watchAudioIngest = WatchAudioIngestService(
        store: WatchAudioIngestStore(s.prefs),
        pipeline: s.pipeline,
      );
      s._watchConnectivity = WatchConnectivityService();
    }
    await ProductAnalytics.initialize(
      consentStore: ProductAnalyticsConsentStore(s.prefs),
    );
  }

  static void _registerAuthLifecycleCallbacks(AppServices s) {
    Future<void> resetEntitlementsForAuthChange() async {
      await s.billing.resetCachedEntitlementsForAuthChange();
    }

    s.auth.onSignedOut = () async {
      await s._switchToNamespace(AccountNamespace.guest);
      s.journalStore.setActiveOwnerKey(null);
      if (_optionalServicesInitialized && V1BillingCapability.isEnabled) {
        await RevenueCatService.instance.logOut();
      }
      if (V1BillingCapability.isEnabled) {
        await resetEntitlementsForAuthChange();
      }
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
        if (V1BillingCapability.isEnabled) {
          await RevenueCatService.instance.logIn(userId);
        }
      }
      if (V1BillingCapability.isEnabled) {
        await resetEntitlementsForAuthChange();
        await s.billing.loadEntitlements(forceRefresh: true);
      }
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
    s.sessionCookieSource = SessionCookieSource(s.sessionCookies);
    await s.sessionCookieSource.hydrateFromStore();
    _configureProviderContainer(s);

    s.deviceIds = DeviceIdStore();
    s.tokenCache = CaptureTokenCache();
    s.attest = CaptureAttestService(
      captureRepository: appProviderContainer.read(captureRepositoryProvider),
      deviceIds: s.deviceIds,
      tokenCache: s.tokenCache,
    );
    s.recording = RecordingService.create(testMode: true);
    s.auth = AuthService(
      appProviderContainer.read(authSessionProvider.notifier),
    );

    const namespace = AccountNamespace.guest;
    await _openNamespacedStores(s, base, namespace);
    s._activeNamespace = namespace;
    s.clinicalTelemetryEncryptedStorage =
        ClinicalTelemetryEncryptedStorage.forTest();
    s.personalContentEncryptedStorage =
        PersonalContentEncryptedStorage.forTest();
    // See the matching comment in `initialize()`: registering early (rather
    // than at the very end) is required so `_wireAccountScopedServices`
    // below can resolve `AppServices.instance` for the curiosity-loop
    // repositories that read it directly.
    _instance = s;
    _initialized = true;

    await TempRecordingCleanup.purgeStaleOnStartup(
      journalStore: s.journalStore,
    );
    await ExcludedNativeCapabilityCleanup.runIfNeeded(s.prefs);

    _wireAccountScopedServices(s);
    // Trial mode never calls billing.startListening() — no RevenueCat, no
    // push, no analytics — see class docs above.

    s.offlineVaultRecoveryStore = OfflineVaultRecoveryStore();
    s.offlineVaultRecovery = OfflineVaultRecoveryService(
      store: s.offlineVaultRecoveryStore,
      captureRepository: appProviderContainer.read(captureRepositoryProvider),
      attest: s.attest,
      pipeline: s.pipeline,
      consentGate: s.remoteProcessingConsentGate,
    );
    s.liveVoiceConnectivity = ConnectivityAwareNetworkSource()..start();
    _wireNetworkConnectivityNotifier(s);
    s.liveVoiceRecoveryGateway = LiveVoiceRecoveryGateway(
      vault: LocalAudioVault(),
      connectivity: s.liveVoiceConnectivity,
      recoveryStore: s.offlineVaultRecoveryStore,
      recoveryService: s.offlineVaultRecovery,
      consentGate: s.remoteProcessingConsentGate,
    );
    _wireBackgroundSyncQueue(s);

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

  static String _sqlitePathFor(String base, AccountNamespace namespace) =>
      '$base/accounts/${namespace.key}/archiveme.db';

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
      secureStorage: s.secureStorage,
    );
    s.sqliteEncryptionKeyStore =
        Platform.environment.containsKey('FLUTTER_TEST') || TrialMode.enabled
        ? InMemorySqliteEncryptionKeyStore()
        : SecureSqliteEncryptionKeyStore(
            secure: s.secureStorage,
            keyAlias: namespace.key,
          );
    s.secureSqliteLock = SecureSqliteLockService(
      keyStore: s.sqliteEncryptionKeyStore,
    );
    s.secureSqliteLock.bindDatabaseCloser(() async {
      await s.sqliteDatabase.close();
    });
    final sqlitePassphrase = await s.secureSqliteLock
        .bootstrapUnlockedSession();
    s.sqliteDatabase = await AppSqliteDatabase.open(
      filePath: _sqlitePathFor(base, namespace),
      password: sqlitePassphrase,
      keyAlias: namespace.key,
    );
    LocalDatabaseWorkerService.instance.configure(
      defaultKeyAlias: namespace.key,
    );
    s.personalContentEncryptedStorage =
        Platform.environment.containsKey('FLUTTER_TEST')
        ? PersonalContentEncryptedStorage.forTest()
        : await PersonalContentEncryptedStorage.forNamespace(
            secureStorage: s.secureStorage,
            keyAlias: namespace.key,
          );
  }

  /// (Re)builds every service that is derived from `journalStore`/`prefs`/
  /// `entitlementCache` — called once at startup and again, on the freshly
  /// reopened stores, by [_switchToNamespace] on every account switch.
  static void _wireAccountScopedServices(AppServices s) {
    _bindAccountScopedProviders(s);
    s.remoteProcessingConsentStore = RemoteProcessingConsentStore(s.prefs);
    BetaAnalyticsTracker.configure(s.prefs);
    s.remoteProcessingConsentGate = RemoteProcessingConsentGate(
      s.remoteProcessingConsentStore,
    );
    s.pipeline = CapturePipelineService(
      captureRepository: appProviderContainer.read(captureRepositoryProvider),
      attest: s.attest,
      journalStore: s.journalStore,
      consentStore: s.remoteProcessingConsentStore,
      proofAdmission: CanonicalProofAdmissionService(
        correctionPolicy: ArchiveCorrectionStore.instance,
      ),
      imageEmbeddingService: ImageEmbeddingService(
        inference: LocalVisualProjectionInference(),
        repository: ImageAttachmentEmbeddingRepository(s.sqliteDatabase),
        journalSqlite: JournalSqliteRepository(s.sqliteDatabase),
      ),
      localAiPipeline: LocalAiPipeline.heuristic(
        audioStructuringResolver: s.resolveAudioStructuring,
      ),
      speechLocale: SpeechLocaleStore(s.prefs).read,
    );
    s.journal = JournalService(s.journalStore);
    s.billing = BillingService(
      appProviderContainer.read(billingProvider.notifier),
    );
    s.offlineSyncJourney = OfflineSyncJourneyStore(s.prefs);
    s.memoryResurfacing = MemoryResurfacingService.fromPrefs(s.prefs);
    s.beliefEvolution = BeliefEvolutionService.fromPrefs(s.prefs);
    s.archiveAgreement = ArchiveAgreementService.fromPrefs(s.prefs);
    s.userSettings = UserSettingsStore(s.prefs);
    s.clinicalConsentStore = ClinicalConsentStore(s.prefs);
    ClinicalSandboxRuntime.bind(
      consentStore: s.clinicalConsentStore,
      consentGate: ClinicalConsentGate(s.clinicalConsentStore),
    );
    s.syncMasterKeyStore = SecureSyncMasterKeyStore(
      accountNamespace: s._activeNamespace.key,
    );
    _bindSyncRepository(s);
    s.sync = SyncService(appProviderContainer.read(syncProvider.notifier));
    s.paywall = ValueMomentPaywallLogic(s.prefs);
    // Bound to the now-stale `pipeline`/`offlineVaultRecoveryStore` pair —
    // dropped so the next access lazily rebuilds against the current ones.
    s._liveVoiceCapture = null;
    s._offlineTts = null;
    s._offlineTtsFuture = null;
    s._localLlm?.dispose();
    s._localLlm = null;
    s._localLlmFuture = null;
    s._audioStructuring = null;
    s._audioStructuringFuture = null;
    s._routineRagEngine = null;
    s._routineRagEngineFuture = null;
    s._trendAnalysisService?.dispose();
    s._trendAnalysisService = null;
    s._trendAnalysisServiceFuture = null;
    s._localCoachConversationService = null;
    s._localCoachConversationServiceFuture = null;
    _wireBackgroundSyncQueueWorker(s);
    _configureJournalSaveInterceptors(s);
    _wireQuickCaptureWidgetService(s);
    unawaited(ArchiveInsightFeedbackStore.ensureLoaded());
    unawaited(PatternNameStore.ensureLoaded());
  }

  static void _wireBackgroundSyncQueueWorker(AppServices s) {
    s._backgroundSyncQueueWorker?.dispose();
    s._reflectionEmbeddingIndexWorker?.dispose();
    s._automatedGraphIndexWorker?.dispose();

    final deps = s.pipeline.dependencies;
    final middleware = CapturePipelineMiddleware(
      deps,
      CaptureProofAnalyzer(deps),
    );
    final transcriptReconciler = ProvisionalTranscriptReconciler(
      captureRepository: appProviderContainer.read(captureRepositoryProvider),
      attest: s.attest,
      journalStore: s.journalStore,
      consentStore: s.remoteProcessingConsentStore,
    );
    final proofReconciler = DeferredProofAdmissionReconciler(
      middleware: middleware,
      journalStore: s.journalStore,
      consentStore: s.remoteProcessingConsentStore,
    );
    final reflectionEmbeddingRepository = ReflectionEmbeddingRepository(
      s.sqliteDatabase,
    );
    s._resourceGuard ??= ResourceGuard.shared;
    s._thermalThrottlingService ??= ThermalThrottlingService(
      resourceGuard: s._resourceGuard,
    );
    EmbeddingIndexWorkerService.instance.configure(
      defaultKeyAlias: s._activeNamespace.key,
      thermalThrottling: s._thermalThrottlingService,
      deferredQueue: EmbeddingDeferredQueueStore(s.sqliteDatabase.database),
    );
    s._resourceGuard!.startMonitoring(
      onConditionsNormalized: () async {
        await EmbeddingIndexWorkerService.instance.flushDeferredQueue();
      },
    );
    s._reflectionEmbeddingIndexWorker = ReflectionEmbeddingIndexWorker(
      repository: reflectionEmbeddingRepository,
      journalStore: s.journalStore,
      sqliteFilePath: s.activeSqliteFilePath,
      sqliteKeyAlias: s._activeNamespace.key,
    );
    final pipelineDeps = s.pipeline.dependencies.copyWith(
      reflectionEmbeddingIndexWorker: s._reflectionEmbeddingIndexWorker,
    );
    s.pipeline = CapturePipelineService(
      captureRepository: pipelineDeps.captureRepository,
      attest: pipelineDeps.attest,
      journalStore: pipelineDeps.journalStore,
      consentStore: pipelineDeps.consentStore,
      usageGuard: pipelineDeps.usageGuard,
      proofAdmission: pipelineDeps.proofAdmission,
      scopeProvider: pipelineDeps.scopeProvider,
      imageEmbeddingService: pipelineDeps.imageEmbeddingService,
      localAiPipeline: pipelineDeps.localAiPipeline,
      reflectionEmbeddingIndexWorker: s._reflectionEmbeddingIndexWorker,
      speechLocale: pipelineDeps.speechLocale,
    );
    final automatedGraphService = AutomatedGraphService(
      sqliteFilePath: s.activeSqliteFilePath,
      sqliteKeyAlias: s._activeNamespace.key,
    );
    s._automatedGraphIndexWorker = AutomatedGraphIndexWorker(
      graphService: automatedGraphService,
      journalStore: s.journalStore,
    );
    final outboxStore = SyncOutboxStore(
      AppDatabase.fromSqflite(s.sqliteDatabase.database),
    );
    final outboxBackgroundService = SyncOutboxBackgroundService(
      syncEngine: SyncEngine(
        syncApi: HttpSyncApiClient(s.httpTransport),
        journal: s.journalStore,
        outbox: outboxStore,
      ),
    );
    final backgroundSyncController = appProviderContainer
        .read(backgroundSyncProvider.notifier)
        .bindController();
    s._backgroundSyncQueueWorker = BackgroundSyncQueueWorker(
      journalStore: s.journalStore,
      syncService: s.sync,
      attest: s.attest,
      transcriptReconciler: transcriptReconciler,
      proofReconciler: proofReconciler,
      reflectionEmbeddingWorker: s._reflectionEmbeddingIndexWorker,
      outboxBackgroundService: outboxBackgroundService,
      syncController: backgroundSyncController,
      pendingOutboxCount: outboxBackgroundService.pendingCount,
      nextOutboxRetryAt: outboxBackgroundService.nextRetryAt,
      uploadSqliteVault: () async {
        if (!EncryptedSqliteVaultSyncPipeline.supportsICloudVault) {
          return false;
        }
        final result = await s.sqliteVaultSyncPipeline.uploadVault();
        return result is SqliteVaultUploadSuccess;
      },
      onBackgroundFlushCompleted: () {
        unawaited(
          s.trendAnalysisService.then(
            (service) => service.scheduleRefresh(),
          ),
        );
      },
    );
  }

  static void _wireNetworkConnectivityNotifier(AppServices s) {
    appProviderContainer
        .read(networkConnectivityProvider.notifier)
        .bind(s.liveVoiceConnectivity);
  }

  static void _wireBackgroundSyncQueueGateway(AppServices s) {
    s._backgroundSyncQueueGateway?.dispose();
    final worker = s._backgroundSyncQueueWorker;
    if (worker == null) return;
    s._backgroundSyncQueueGateway = BackgroundSyncQueueGateway(
      connectivity: s.liveVoiceConnectivity,
      consentStore: s.remoteProcessingConsentStore,
      worker: worker,
    );
  }

  static void _wireBackgroundSyncQueue(AppServices s) {
    _wireBackgroundSyncQueueWorker(s);
    _configureJournalSaveInterceptors(s);
    _wireBackgroundSyncQueueGateway(s);
    _wireQuickCaptureWidgetService(s);
  }

  static void _wireQuickCaptureWidgetService(AppServices s) {
    final bridge = V1CapabilityRegistry.nativeExtensions
        ? MethodChannelQuickCaptureWidgetBridge()
        : const NoOpQuickCaptureWidgetBridge();
    final sharedStorage = QuickCaptureSharedStorage(
      bridge: bridge,
      prefs: s.prefs,
    );
    final outbox = QuickCaptureOutboxStore(
      AppDatabase.fromSqflite(s.sqliteDatabase.database),
    );
    s._quickCaptureWidgetService = QuickCaptureWidgetService.create(
      sharedStorage: sharedStorage,
      outbox: outbox,
      pipeline: s.pipeline,
      backgroundSyncWorker: s._backgroundSyncQueueWorker,
      bridge: bridge,
    );
  }

  /// Reopens SQLCipher after biometric unlock from [SecureDatabaseGate].
  Future<void> reopenSqliteDatabase() async {
    final passphrase = secureSqliteLock.session.requirePassphrase();
    final path = _sqlitePathFor(_documentsBasePath, _activeNamespace);
    await sqliteDatabase.close();
    sqliteDatabase = await AppSqliteDatabase.open(
      filePath: path,
      password: passphrase,
    );
    _bindAccountScopedProviders(this);
    _wireBackgroundSyncQueueWorker(this);
    _configureJournalSaveInterceptors(this);
    _wireQuickCaptureWidgetService(this);
    unawaited(processQuickCaptureWidgetQueue());
    _routineRagEngine = null;
    _routineRagEngineFuture = null;
    _trendAnalysisService?.dispose();
    _trendAnalysisService = null;
    _trendAnalysisServiceFuture = null;
    _localCoachConversationService = null;
    _localCoachConversationServiceFuture = null;
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
    appProviderContainer.read(networkRequestScopeProvider).cancelAll();
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
    _wireBackgroundSyncQueue(this);
    oldBilling.dispose();
    if (_billingListeningEnabled) {
      billing.startListening();
    }
    _activeNamespace = target;
    unawaited(BackgroundTaskAccountRegistry.persistActiveNamespace(target));
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
    List<Override>? networkOverrides,
    SecureStorageService? secureStorage,
    bool skipRevenueCat = false,
    RecordingService? recording,
    AccountNamespace? namespace,
    bool grantRemoteProcessingConsentByDefault = true,
  }) async {
    await shutdownForTest();
    _initialized = false;
    _optionalServicesInitialized = false;
    final resolvedJournalPath = _sandboxedTestPath(journalPath);
    final s = AppServices._();
    final activeNamespace = namespace ?? AccountNamespace.guest;
    s._activeNamespace = activeNamespace;
    s._billingListeningEnabled = !skipRevenueCat;

    s.secureStorage = secureStorage ?? InMemorySecureStorageService();
    s.sessionCookies = SessionCookieStore(s.secureStorage);
    s.sessionCookieSource = SessionCookieSource(s.sessionCookies);
    await s.sessionCookieSource.hydrateFromStore();
    s.deviceIds = DeviceIdStore();
    s.tokenCache = CaptureTokenCache();

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
    s.entitlementCache = await EntitlementCache.open(
      effectiveEntitlementsPath,
      secureStorage: s.secureStorage,
    );
    final sqlitePath = namespace != null
        ? _sqlitePathFor(s._documentsBasePath, namespace)
        : '${file.parent.path}/test_archiveme.db';
    s.sqliteEncryptionKeyStore = InMemorySqliteEncryptionKeyStore();
    s.secureSqliteLock = SecureSqliteLockService(
      keyStore: s.sqliteEncryptionKeyStore,
    );
    s.secureSqliteLock.bindDatabaseCloser(() async {
      await s.sqliteDatabase.close();
    });
    final sqlitePassphrase = await s.secureSqliteLock
        .bootstrapUnlockedSession();
    s.sqliteDatabase = await AppSqliteDatabase.open(
      filePath: sqlitePath,
      password: sqlitePassphrase,
    );
    if (grantRemoteProcessingConsentByDefault) {
      await RemoteProcessingConsentStore(s.prefs).grant();
    }
    s.clinicalTelemetryEncryptedStorage =
        ClinicalTelemetryEncryptedStorage.forTest();
    s.personalContentEncryptedStorage =
        PersonalContentEncryptedStorage.forTest();
    // See the matching comment in `initialize()`: registering early is
    // required so `_wireAccountScopedServices` below can resolve
    // `AppServices.instance` for the curiosity-loop repositories that read
    // it directly.
    _instance = s;
    _initialized = true;

    _configureProviderContainer(
      s,
      networkOverrides: [
        if (recording == null)
          recordingServiceConfigProvider.overrideWithValue(
            const RecordingServiceConfig(testMode: true),
          ),
        ...?networkOverrides,
      ],
    );
    s.attest = CaptureAttestService(
      captureRepository: appProviderContainer.read(captureRepositoryProvider),
      deviceIds: s.deviceIds,
      tokenCache: s.tokenCache,
    );
    s.recording =
        recording ??
        appProviderContainer.read(recordingServiceProvider.notifier);
    s.auth = AuthService(
      appProviderContainer.read(authSessionProvider.notifier),
    );
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
          ({required deviceId, required platform, required fcmToken}) async {
            final result = await appProviderContainer
                .read(pushApiClientProvider)
                .registerPushDevice(
                  deviceId: deviceId,
                  platform: platform,
                  fcmToken: fcmToken,
                );
            result.when(
              success: (_) {},
              onFailure: (failure) => throw failure.toApiException(),
            );
          },
      sendTestPush: ({required deviceId, required targetRoute}) async {
        final result = await appProviderContainer
            .read(pushApiClientProvider)
            .sendInternalTestPush(
              deviceId: deviceId,
              targetRoute: targetRoute,
              debugToken: AppConfig.internalDebugToken,
            );
        return result.when(
          success: (body) => body,
          onFailure: (failure) => throw failure.toApiException(),
        );
      },
    );
    s.nativePush = NativePushService(s.fcm);
    s.offlineVaultRecoveryStore = OfflineVaultRecoveryStore();
    s.offlineVaultRecovery = OfflineVaultRecoveryService(
      store: s.offlineVaultRecoveryStore,
      captureRepository: appProviderContainer.read(captureRepositoryProvider),
      attest: s.attest,
      pipeline: s.pipeline,
      consentGate: s.remoteProcessingConsentGate,
    );
    s.liveVoiceConnectivity = ConnectivityAwareNetworkSource()..start();
    _wireNetworkConnectivityNotifier(s);
    s.liveVoiceRecoveryGateway = LiveVoiceRecoveryGateway(
      vault: LocalAudioVault(),
      connectivity: s.liveVoiceConnectivity,
      recoveryStore: s.offlineVaultRecoveryStore,
      recoveryService: s.offlineVaultRecovery,
      consentGate: s.remoteProcessingConsentGate,
    );
    _wireBackgroundSyncQueue(s);
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

  static void _configureProviderContainer(
    AppServices s, {
    List<Override>? networkOverrides,
  }) {
    final client = http.Client();
    final transport = HttpTransport(
      client: client,
      baseUrl: AppConfig.apiBaseUrl,
      sessionCookies: s.sessionCookieSource,
    );
    s.httpTransport = transport;
    final bundle = VoiceMemoryApiClientBundle.fromTransport(
      transport,
      sessionCookies: s.sessionCookieSource,
    );
    final requestScope = NetworkRequestScope();
    final authRepository = createAuthRepository(
      api: bundle.auth,
      sessionCookies: s.sessionCookieSource,
      secure: s.secureStorage,
      requestScope: requestScope,
    );
    bindAppProviderContainer(
      createNetworkProviderContainer(
        secureStorage: s.secureStorage,
        sessionCookieStore: s.sessionCookies,
        sessionCookieSource: s.sessionCookieSource,
        authRepository: authRepository,
        requestScope: requestScope,
        httpClient: client,
        apiBaseUrl: AppConfig.apiBaseUrl,
        networkOverrides: [
          voiceMemoryApiClientBundleProvider.overrideWithValue(bundle),
          ...?networkOverrides,
        ],
      ),
    );
  }

  static void _bindAccountScopedProviders(AppServices s) {
    appProviderContainer.read(entitlementCacheHolderProvider).value =
        s.entitlementCache;
    appProviderContainer.read(appSqliteDatabaseHolderProvider).value =
        s.sqliteDatabase;
    appProviderContainer.read(journalStoreHolderProvider).value =
        s.journalStore;
    appProviderContainer.invalidate(archiveFeedPaginationProvider);
    bindCaptureModuleRuntime(
      CaptureModuleRuntimeConfig(
        sqliteFilePath: s.activeSqliteFilePath,
        encryptionPassword: s.sqliteDatabase.encryptionPassword,
        keyAlias: s.activeNamespace.key,
      ),
    );
    appProviderContainer.invalidate(captureModuleRuntimeConfigProvider);
  }

  static void _bindSyncRepository(AppServices s) {
    final syncApi = HttpSyncApiClient(s.httpTransport);
    final outboxStore = SyncOutboxStore(
      AppDatabase.fromSqflite(s.sqliteDatabase.database),
    );
    final coordinator = EncryptedJournalSyncCoordinator(
      syncApi: syncApi,
      journal: s.journalStore,
      prefs: s.prefs,
      deviceIds: s.deviceIds,
      keyStore: s.syncMasterKeyStore,
      outboxStore: outboxStore,
    );
    appProviderContainer.read(syncRepositoryHolderProvider).value =
        SyncRepository(coordinator: coordinator, prefs: s.prefs);
  }

  static void _configureJournalSaveInterceptors(AppServices services) {
    final hookRepository = LocalCuriosityHookRepository.instance();
    final baselineStore = LocalCognitiveBaselineStore.instance();
    final trajectoryHistoryStore =
        LocalClinicalTrajectoryHistoryStore.instance();
    final leading = <JournalSaveInterceptor>[];
    final worker = services._backgroundSyncQueueWorker;
    if (worker != null) {
      leading.add(JournalSaveSyncEnqueueInterceptor(worker));
    }
    leading.add(const JournalFactLedgerCitationInterceptor());
    final reflectionWorker = services._reflectionEmbeddingIndexWorker;
    if (reflectionWorker != null) {
      leading.add(JournalReflectionEmbeddingInterceptor(reflectionWorker));
    }
    final graphWorker = services._automatedGraphIndexWorker;
    if (graphWorker != null) {
      leading.add(JournalAutomatedGraphInterceptor(graphWorker));
    }
    services.journalStore.configureSaveInterceptorPipeline(
      JournalSaveInterceptorPipeline.clinicalDefaults(
        leading: leading,
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
