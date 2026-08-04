import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../audio/recording_service.dart';
import '../billing/billing_platform.dart';
import '../billing/value_moment_paywall.dart';
import '../features/archive_semantic_search/archive_semantic_search_engine.dart';
import '../features/archive_semantic_search/semantic_index_store.dart';
import '../features/capture_api_retry/capture_api_retry_queue.dart';
import '../features/explainable_conclusion/explainability_history_store.dart';
import '../features/offline_sync/offline_sync_journey_store.dart';
import '../features/performance/capture_performance_tracker.dart';
import '../features/remote_transcription/remote_transcription_disclosure.dart';
import '../features/theme_system/theme_engine.dart';
import '../features/transcription_queue/transcription_ledger.dart';
import '../features/transcription_queue/transcription_queue_executor.dart';
import '../features/transcription_queue/transcription_queue_foreground_coordinator.dart';
import '../features/transcription_queue/transcription_work_scheduler.dart';
import '../features/voice_capture/transcription/on_device_transcription_engine.dart';
import '../features/voice_capture/transcription/transcription_connectivity.dart';
import '../storage/app_storage_paths.dart';
import '../storage/capture_token_cache.dart';
import '../storage/device_id.dart';
import '../storage/entitlement_cache.dart';
import '../storage/encrypted_json_storage.dart';
import '../security/private_data_service.dart';
import '../storage/journal_store.dart';
import '../storage/mobile_prefs_store.dart';
import '../storage/secure_storage.dart';
import '../storage/session_cookie_store.dart';
import '../subscriptions/data/subscription_data_sources.dart';
import '../subscriptions/domain/subscription_repository.dart';
import 'auth_service.dart';
import 'capture_attest_service.dart';
import 'capture_pipeline_service.dart';
import 'composition/v1_composition.dart';
import 'composition/v1_composition_config.dart';
import 'journal_service.dart';
import 'privacy/audio_vault_service.dart';
import 'security/biometric_vault_service.dart';
import 'subscription_service.dart';
import 'sync_service.dart';

/// Compatibility facade over the focused, typed V1 composition.
///
/// New code should depend on [composition] modules. Leaf getters remain while
/// V1 call sites migrate, but no service is owned or constructed by this class.
final class AppServices {
  AppServices._(this.composition, {this._testRuntimeRoot});

  final V1Composition composition;
  Directory? _testRuntimeRoot;

  static AppServices? _instance;
  static Future<void>? _initializing;
  static final StreamController<int> _restoreRevisions =
      StreamController<int>.broadcast(sync: true);
  static int _restoreRevision = 0;

  static bool get isInitialized => _instance != null;
  static Stream<int> get restoreRevisions => _restoreRevisions.stream;
  static int get restoreRevision => _restoreRevision;

  static AppServices get instance =>
      _instance ?? (throw StateError('Call AppServices.initialize() first'));

  @visibleForTesting
  Directory? get testRuntimeRoot => _testRuntimeRoot;

  static Future<void> initialize({bool backgroundWorker = false}) {
    if (_instance != null) return Future<void>.value();
    final inFlight = _initializing;
    if (inFlight != null) return inFlight;
    final future = _initializeProduction(backgroundWorker: backgroundWorker);
    _initializing = future;
    return future.whenComplete(() => _initializing = null);
  }

  static Future<void> _initializeProduction({
    bool backgroundWorker = false,
  }) async {
    final base = await _resolveDocumentsBasePath();
    final graph = await V1Composition.create(
      V1CompositionConfig.production(basePath: base),
    );
    final services = AppServices._(graph);
    _instance = services;
    try {
      await graph.startForegroundOwnership();
      // A capture interrupted by a crash or a kill leaves plaintext audio in
      // the temp directory. Sweeping it at launch is what stops it outliving
      // the session it belonged to. Foreground only: a background worker
      // shares the same directory, and only the foreground knows the full set
      // of live captures.
      if (!backgroundWorker) {
        unawaited(
          TempRecordingCleanup.purgeStaleOnStartup(
            journalStore: services.journalStore,
            // Best effort by design. A device that refuses the delete must
            // still reach a usable app rather than fail to launch.
          ).catchError((Object _) {}),
        );
      }
      unawaited(services.drainCaptureApiRetryQueue());
      unawaited(graph.recording.pipeline.prepareOfflineTranscription());
    } on Object {
      _instance = null;
      await graph.dispose();
      rethrow;
    }
  }

  static Future<void> resetForTest({
    required String journalPath,
    String? prefsPath,
    ApiTransport? apiTransport,
    AuthApiClient? authApi,
    VoiceCaptureApiClient? voiceCaptureApi,
    JournalSyncApiClient? journalSyncApi,
    BillingApiClient? billingApi,
    SubscriptionRepository? subscriptionRepository,
    SubscriptionStoreDataSource? subscriptionStoreDataSource,
    SubscriptionRemoteDataSource? subscriptionRemoteDataSource,
    SubscriptionCacheDataSource? subscriptionCacheDataSource,
    BillingPlatform? billingPlatform,
    bool skipRevenueCat = false,
    RecordingService? recording,
    OnDeviceTranscriptionEngine? onDeviceTranscription,
    TranscriptionConnectivity transcriptionConnectivity =
        const FixedTranscriptionConnectivity(true),
    SecureStorageService? secureStorage,
  }) async {
    await disposeForTest();
    final runtimeRoot = await Directory.systemTemp.createTemp(
      'voicememory_services_${pid}_',
    );
    final journalFile = File(journalPath);
    if (await journalFile.exists()) await journalFile.delete();
    final encrypted = File(JournalStore.encryptedPathFor(journalPath));
    if (await encrypted.exists()) await encrypted.delete();
    try {
      final graph = await V1Composition.create(
        V1CompositionConfig.test(
          basePath: runtimeRoot.path,
          journalPath: journalPath,
          prefsPath: prefsPath ?? '${journalFile.parent.path}/test_prefs.json',
          apiTransport: apiTransport,
          authApi: authApi,
          voiceCaptureApi: voiceCaptureApi,
          journalSyncApi: journalSyncApi,
          billingApi: billingApi,
          subscriptionRepository: subscriptionRepository,
          subscriptionStoreDataSource: subscriptionStoreDataSource,
          subscriptionRemoteDataSource: subscriptionRemoteDataSource,
          subscriptionCacheDataSource: subscriptionCacheDataSource,
          billingPlatform: billingPlatform,
          skipBillingInitialization: skipRevenueCat,
          recording: recording,
          onDeviceTranscription: onDeviceTranscription,
          transcriptionConnectivity: transcriptionConnectivity,
          secureStorage: secureStorage,
        ),
      );
      _instance = AppServices._(graph, testRuntimeRoot: runtimeRoot);
    } on Object {
      await runtimeRoot.delete(recursive: true);
      rethrow;
    }
  }

  /// Runs the cold-start work Record does not need (analytics provider,
  /// monetization, sync, derived archive stores). Safe to call repeatedly and
  /// safe to call before [initialize] has produced an instance.
  static Future<void> activateDeferredServices() async {
    final current = _instance;
    if (current == null) return;
    await current.composition.activateDeferredServices();
  }

  static Future<void> disposeForTest() =>
      shutdownForVaultRestore(deleteTestRuntime: true);

  static Future<void> shutdownForVaultRestore({
    bool deleteTestRuntime = false,
  }) async {
    final current = _instance;
    _instance = null;
    if (current == null) return;
    final runtimeRoot = current._testRuntimeRoot;
    current._testRuntimeRoot = null;
    Object? error;
    StackTrace? stackTrace;
    try {
      await current.composition.dispose();
    } on Object catch (caught, caughtStack) {
      error = caught;
      stackTrace = caughtStack;
    }
    if (deleteTestRuntime &&
        runtimeRoot != null &&
        await runtimeRoot.exists()) {
      await runtimeRoot.delete(recursive: true);
    }
    if (error != null) Error.throwWithStackTrace(error, stackTrace!);
  }

  static void emitRestoreRevision() {
    _restoreRevision += 1;
    _restoreRevisions.add(_restoreRevision);
  }

  static Future<void> ingestSharedVaultPayload(dynamic payload) async {}

  static Future<String> _resolveDocumentsBasePath() async {
    try {
      return (await AppStoragePaths.applicationDocumentsDirectory()).path;
    } catch (error, stackTrace) {
      if (kDebugMode && Platform.isIOS) {
        debugPrint(
          'ARCHIVEME_SIMULATOR_NATIVE_ASSETS: documents path failed, '
          'using debug temp fallback: $error',
        );
        debugPrint('$stackTrace');
        return AppStoragePaths.debugSimulatorDocumentsDirectorySync(
          reason: error,
        ).path;
      }
      rethrow;
    }
  }

  Future<void> resetAccountScope(String? accountId) =>
      composition.resetAccountScope(accountId);

  Future<void> drainCaptureApiRetryQueue() async {
    try {
      await captureApiRetryQueue.drain();
    } on Object catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Capture API retry drain failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  Future<void> wipeQueuedAudioData() async {
    transcriptionQueueExecutor.pause();
    try {
      await transcriptionLedger.wipeAll();
      await captureApiRetryQueue.clear();
    } finally {
      transcriptionQueueExecutor.resume();
    }
  }

  Future<void> wipeLocalDerivedAiData() => Future.wait([
    archiveSemanticIndexStore.clear(),
    explainabilityHistoryStore.clear(),
  ]);

  Future<void> onForegroundUnlocked() async {}
  Future<void> onBackgroundLocked() async {}
  Future<void> drainEncryptedGraphSyncQueue() async {}
  Future<void> reconcileLlamaStartup() async {}
  Future<bool> authorizeGoogleDriveGraphSyncInteractively() async => false;
  Future<void> destroySanctuaryKeysAfterWipe() async {}
  Future<dynamic> readyLlamaInferenceSession() async => null;
  Future<void> wipeLocalLlamaModel() async {}

  /// Content-free capture latency instrumentation. Raw timings stay in memory;
  /// only a coarse band is ever reported.
  CapturePerformanceTracker get capturePerformance =>
      CapturePerformanceTracker.instance;

  ApiTransport get apiTransport => composition.core.apiTransport;
  AuthApiClient get authApi => composition.core.authApi;
  VoiceCaptureApiClient get voiceCaptureApi => composition.core.voiceCaptureApi;
  JournalSyncApiClient get journalSyncApi => composition.core.journalSyncApi;
  BillingApiClient get billingApi => composition.core.billingApi;
  DeviceIdStore get deviceIds => composition.core.deviceIds;
  SecureStorageService get secureStorage => composition.core.secureStorage;
  SessionCookieStore get sessionCookies => composition.core.sessionCookies;
  CaptureTokenCache get tokenCache => composition.core.tokenCache;
  MobilePrefsStore get prefs => composition.core.prefs;
  RemoteTranscriptionDisclosureStore get remoteTranscriptionDisclosure =>
      composition.core.remoteTranscriptionDisclosure;
  ThemePreferencesStore get themePreferencesStore =>
      composition.core.themePreferencesStore;
  SubscriptionService get subscriptionService =>
      composition.core.subscriptionService;
  BiometricVaultService? get biometricVault =>
      composition.privacy.biometricVault;
  AudioVaultService get journalAudioVault => composition.privacy.audioVault;
  EncryptedJsonStorage get clinicalTelemetryEncryptedStorage =>
      composition.privacy.clinicalTelemetryEncryptedStorage;
  JournalStore get journalStore => composition.archive.journalStore;
  JournalService get journal => composition.archive.journal;
  SemanticIndexStore get archiveSemanticIndexStore =>
      composition.archive.archiveSemanticIndexStore;
  ArchiveSemanticSearchEngine get archiveSemanticSearch =>
      composition.archive.archiveSemanticSearch;
  ExplainabilityHistoryStore get explainabilityHistoryStore =>
      composition.archive.explainabilityHistoryStore;
  CaptureAttestService get attest => composition.recording.attest;
  CapturePipelineService get pipeline => composition.recording.pipeline;
  OnDeviceTranscriptionEngine get onDeviceTranscription =>
      composition.recording.onDeviceTranscription;
  CaptureApiRetryQueue get captureApiRetryQueue =>
      composition.recording.captureApiRetryQueue;
  TranscriptionWorkScheduler get transcriptionWorkScheduler =>
      composition.recording.transcriptionWorkScheduler;
  TranscriptionLedger get transcriptionLedger =>
      composition.recording.transcriptionLedger;
  TranscriptionQueueExecutor get transcriptionQueueExecutor =>
      composition.recording.transcriptionQueueExecutor;
  TranscriptionQueueForegroundCoordinator
  get transcriptionQueueForegroundCoordinator =>
      composition.recording.transcriptionQueueForegroundCoordinator;
  RecordingService get recording => composition.recording.recording;
  AuthService get auth => composition.account.auth;
  EntitlementCache get entitlementCache =>
      composition.monetization.entitlementCache;
  BillingPlatform get billingPlatform =>
      composition.monetization.billingPlatform;
  SubscriptionStoreDataSource get subscriptionStoreDataSource =>
      composition.monetization.subscriptionStoreDataSource;
  SubscriptionRemoteDataSource get subscriptionRemoteDataSource =>
      composition.monetization.subscriptionRemoteDataSource;
  SubscriptionCacheDataSource get subscriptionCacheDataSource =>
      composition.monetization.subscriptionCacheDataSource;
  SubscriptionRepository get subscriptionRepository =>
      composition.monetization.subscriptionRepository;
  ValueMomentPaywallLogic get paywall => composition.monetization.paywall;
  SyncService get sync => composition.sync.sync;
  OfflineSyncJourneyStore get offlineSyncJourney =>
      composition.sync.offlineSyncJourney;
}
