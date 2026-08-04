import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/recording_service.dart';
import '../auth/guest_first_auth.dart';
import '../features/live_audio/application/live_audio_focus_gateway.dart';
import '../features/live_audio/application/live_voice_capture_service.dart';
import '../features/transcription_queue/transcription_job.dart';
import '../features/transcription_queue/transcription_ledger.dart';
import '../features/transcription_queue/transcription_timeline_snapshot.dart';
import '../features/explainable_conclusion/explainability_history_store.dart';
import '../features/time_machine/temporal_graph_history_store.dart';
import '../features/sync/encrypted_sync_engine.dart';
import '../features/p2p_mesh/mesh_discovery_service.dart';
import '../features/p2p_mesh/mesh_controller.dart';
import '../features/p2p_mesh/mesh_models.dart';
import '../features/p2p_mesh/mesh_trust_store.dart';
import '../features/p2p_mesh/sync/mesh_sync_engine.dart';
import '../features/p2p_mesh/vault_share/shared_vault_branch_store.dart';
import '../features/p2p_mesh/ui/mesh_ui_models.dart';
import '../features/hivemind/hivemind_mesh_router.dart';
import '../features/hivemind/hivemind_models.dart';
import '../features/spatial_nexus/spatial_nexus_service.dart';
import '../features/apex_profiler/apex_profiler_service.dart';
import '../features/catalyst_engine/catalyst_store.dart';
import '../features/sandbox_enclave/sandbox_enclave_service.dart';
import '../features/codex_press/codex_publication_service.dart';
import '../features/connectors/healthkit_connector.dart';
import '../features/cloud_relay_sync/cloud_relay_sync_engine.dart';
import '../features/morning_briefing/morning_briefing_models.dart';
import '../features/morning_briefing/morning_briefing_service.dart';
import '../features/widgets/memory_graph_widget_models.dart';
import '../features/widgets/memory_graph_widget_service.dart';
import '../features/widgets/share_extension_service.dart';
import '../features/connectors/spotify_connector.dart';
import '../features/semantic_clusters/semantic_cluster_engine.dart';
import '../features/semantic_clusters/semantic_cluster_store.dart';
import 'security/sync_identity_service.dart';
import '../subscriptions/domain/subscription_models.dart';
import '../subscriptions/domain/subscription_repository.dart';
import '../core/llm/llama_model_manager.dart';
import '../core/llm/llama_model_state.dart';
import '../core/llm/native/llama_inference_session.dart';
import '../core/graph/personal_knowledge_graph_store.dart';
import '../features/archive_semantic_search/archive_semantic_search_engine.dart';
import '../features/archive_semantic_search/semantic_index_store.dart';
import '../storage/journal_store.dart';
import '../storage/mobile_prefs_store.dart';
import '../features/ai_engines/on_device_extraction_engine.dart';
import 'ai/ai_cost_telemetry.dart';
import 'ai/hybrid_ai_router.dart';
import 'ai/local_semantic_store.dart';
import 'feature_discovery/feature_discovery_service.dart';
import 'app_services.dart';
import 'ambient_metadata_collector.dart';
import 'auth_service.dart';
import 'capture_pipeline_service.dart';
import 'journal_service.dart';

/// Incremental Riverpod adapters over the existing initialized service graph.
///
/// Tests can override any leaf dependency without rebuilding [AppServices].
final appServicesProvider = Provider<AppServices>(
  (ref) => AppServices.instance,
);

final apexProfilerServiceProvider = Provider<ApexProfilerService?>(
  (ref) => ref.watch(appServicesProvider).apexProfilerService,
);

final apexTelemetryProvider = StreamProvider<ApexTelemetrySnapshot>((ref) {
  final service = ref.watch(apexProfilerServiceProvider);
  if (service == null) return const Stream.empty();
  return service.telemetry;
});

final catalystStoreProvider = Provider<CatalystStore?>(
  (ref) => ref.watch(appServicesProvider).catalystStore,
);

final catalystStateProvider = StreamProvider<CatalystState>((ref) async* {
  final store = ref.watch(catalystStoreProvider);
  if (store == null) return;
  yield await store.read();
  yield* store.changes;
});

final sandboxEnclaveServiceProvider = Provider<SandboxEnclaveService?>(
  (ref) => ref.watch(appServicesProvider).sandboxEnclaveService,
);

final codexPublicationServiceProvider = Provider<CodexPublicationService?>(
  (ref) => ref.watch(appServicesProvider).codexPublicationService,
);

final sandboxEnclaveSnapshotProvider = StreamProvider<SandboxEnclaveSnapshot>((
  ref,
) async* {
  final service = ref.watch(sandboxEnclaveServiceProvider);
  if (service == null) return;
  yield service.current;
  yield* service.changes;
});

final morningBriefingServiceProvider = Provider<MorningBriefingService?>(
  (ref) => ref.watch(appServicesProvider).morningBriefingService,
);

final morningBriefingProvider = StreamProvider<MorningBriefing?>((ref) async* {
  final service = ref.watch(morningBriefingServiceProvider);
  if (service == null) return;
  yield await service.store.latest();
  yield* service.store.changes;
});

final shareExtensionServiceProvider = Provider<ShareExtensionService?>(
  (ref) => ref.watch(appServicesProvider).shareExtensionService,
);

final memoryGraphWidgetServiceProvider = Provider<MemoryGraphWidgetService?>(
  (ref) => ref.watch(appServicesProvider).memoryGraphWidgetService,
);

final memoryGraphWidgetStatusProvider =
    FutureProvider<MemoryGraphWidgetStatus?>((ref) async {
      return ref.watch(memoryGraphWidgetServiceProvider)?.status();
    });

final vaultRestoreRevisionProvider = StreamProvider<int>((ref) async* {
  yield AppServices.restoreRevision;
  yield* AppServices.restoreRevisions;
});

final featureDiscoveryServiceProvider = Provider<FeatureDiscoveryService>(
  (ref) => FeatureDiscoveryService(prefs: ref.watch(prefsProvider)),
);

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>(
  (ref) => ref.watch(appServicesProvider).subscriptionRepository,
);

/// Emits cached domain state first, then the merged store/backend result.
final entitlementProvider = StreamProvider<SubscriptionState>((ref) async* {
  final repository = ref.watch(subscriptionRepositoryProvider);
  final cached = await repository.loadCachedState() ?? SubscriptionState.free();
  yield cached;

  final refreshed = await repository.refresh(force: true);
  yield refreshed;
  yield* repository.watchState().skip(1);
});

final llamaModelManagerProvider = Provider<LlamaModelManager?>(
  (ref) => AppServices.isInitialized
      ? ref.watch(appServicesProvider).llamaModelManager
      : null,
);

final llamaModelStateProvider = StreamProvider<LlamaModelState>((ref) async* {
  final manager = ref.watch(llamaModelManagerProvider);
  if (manager == null) return;
  yield manager.state;
  yield* manager.states;
});

final llamaModelActionsProvider = Provider<LlamaModelActions>(
  (ref) => LlamaModelActions(ref.watch(llamaModelManagerProvider)),
);

/// Resolves only a foreground-unlocked, warmed session; null means fallback.
final llamaInferenceSessionProvider = FutureProvider<LlamaInferenceSession?>((
  ref,
) async {
  if (!AppServices.isInitialized) {
    return null;
  }
  final session = await ref
      .watch(appServicesProvider)
      .readyLlamaInferenceSession();
  return session is LlamaInferenceSession ? session : null;
});

/// Emits only semantic availability/removal transitions, never progress ticks.
final llamaKnowledgeGraphRevisionProvider = StreamProvider<int>((ref) {
  if (!AppServices.isInitialized) return const Stream<int>.empty();
  return ref.watch(appServicesProvider).llamaGraphRevisions;
});

final class LlamaModelActions {
  const LlamaModelActions(this._manager);

  final LlamaModelManager? _manager;

  Future<void> optIn() => _run((manager) => manager.optIn());
  Future<void> pause() => _run((manager) => manager.pause());
  Future<void> resume() => _run((manager) => manager.resume());
  Future<void> cancel() => _run((manager) => manager.cancel());
  Future<void> remove() => _run((manager) => manager.remove());
  Future<void> optOut() => _run((manager) => manager.optOut());

  Future<void> _run(
    Future<void> Function(LlamaModelManager manager) action,
  ) async {
    final manager = _manager;
    if (manager == null) {
      throw StateError('The on-device model is unavailable in this runtime.');
    }
    await manager.initialize();
    await action(manager);
  }
}

final journalStoreProvider = Provider<JournalStore>((ref) {
  ref.watch(vaultRestoreRevisionProvider);
  return ref.watch(appServicesProvider).journalStore;
});

final personalKnowledgeGraphStoreProvider =
    Provider<PersonalKnowledgeGraphStore>((ref) {
      ref.watch(vaultRestoreRevisionProvider);
      return ref.watch(appServicesProvider).personalKnowledgeGraphStore;
    });

final temporalGraphHistoryStoreProvider = Provider<TemporalGraphHistoryStore>(
  (ref) => ref.watch(appServicesProvider).temporalGraphHistoryStore,
);

final syncIdentityServiceProvider = Provider<SyncIdentityService?>(
  (ref) => ref.watch(appServicesProvider).syncIdentity,
);

final encryptedSyncEngineProvider = Provider<EncryptedSyncEngine?>(
  (ref) => ref.watch(appServicesProvider).e2eeSyncEngine,
);

final cloudRelaySyncEngineProvider = Provider<CloudRelaySyncEngine?>(
  (ref) => ref.watch(appServicesProvider).cloudRelaySyncEngine,
);

final meshDiscoveryServiceProvider = Provider<MeshDiscoveryService?>(
  (ref) => ref.watch(appServicesProvider).meshDiscoveryService,
);

final meshSyncEngineProvider = Provider<MeshSyncEngine?>(
  (ref) => ref.watch(appServicesProvider).meshSyncEngine,
);

final meshControllerProvider = Provider<MeshController?>(
  (ref) => ref.watch(appServicesProvider).meshController,
);

final hivemindRouterProvider = Provider<HivemindMeshRouter?>(
  (ref) => ref.watch(appServicesProvider).hivemindMeshRouter,
);

final spatialNexusServiceProvider = Provider<SpatialNexusService?>(
  (ref) => ref.watch(appServicesProvider).spatialNexusService,
);

final hivemindPeersProvider = StreamProvider<List<HivemindPeerState>>((
  ref,
) async* {
  final router = ref.watch(hivemindRouterProvider);
  if (router == null) {
    yield const [];
    return;
  }
  yield router.currentPeers;
  yield* router.peers;
});

final meshPeerViewsProvider = StreamProvider<List<MeshPeerViewState>>((
  ref,
) async* {
  final controller = ref.watch(meshControllerProvider);
  if (controller == null) {
    yield const [];
    return;
  }
  yield controller.currentViews;
  yield* controller.views;
});

final meshTrustStoreProvider = Provider<MeshTrustStore?>(
  (ref) => ref.watch(appServicesProvider).meshTrustStore,
);

final sharedVaultBranchStoreProvider = Provider<SharedVaultBranchStore?>((ref) {
  ref.watch(vaultRestoreRevisionProvider);
  return ref.watch(appServicesProvider).sharedVaultBranchStore;
});

final meshDiscoveryStateProvider = StreamProvider<MeshDiscoveryState>((
  ref,
) async* {
  final service = ref.watch(meshDiscoveryServiceProvider);
  if (service == null) {
    yield MeshDiscoveryState.stopped;
    return;
  }
  yield service.state;
  yield* service.states;
});

final nearbyMeshPeersProvider = StreamProvider<List<MeshPeer>>((ref) async* {
  final service = ref.watch(meshDiscoveryServiceProvider);
  if (service == null) {
    yield const [];
    return;
  }
  yield service.nearbyPeers;
  yield* service.peers;
});

final trustedMeshPeersProvider = StreamProvider<List<TrustedMeshPeer>>((
  ref,
) async* {
  final store = ref.watch(meshTrustStoreProvider);
  if (store == null) {
    yield const [];
    return;
  }
  yield await store.list();
  yield* store.changes;
});

final healthKitConnectorProvider = Provider<HealthKitConnector?>(
  (ref) => AppServices.instance.healthKitConnector,
);

final spotifyConnectorProvider = Provider<SpotifyConnector?>(
  (ref) => AppServices.instance.spotifyConnector,
);

final encryptedSyncStateProvider = StreamProvider<EncryptedSyncState>((
  ref,
) async* {
  final engine = ref.watch(encryptedSyncEngineProvider);
  if (engine == null) {
    yield EncryptedSyncState.disabled;
    return;
  }
  yield engine.state;
  yield* engine.states;
});

final archiveSemanticIndexStoreProvider = Provider<SemanticIndexStore>(
  (ref) => ref.watch(appServicesProvider).archiveSemanticIndexStore,
);

final archiveSemanticSearchProvider = Provider<ArchiveSemanticSearchEngine>(
  (ref) => ref.watch(appServicesProvider).archiveSemanticSearch,
);

final onDeviceExtractionEngineProvider = Provider<OnDeviceExtractionEngine>(
  (ref) => ref.watch(appServicesProvider).onDeviceExtractionEngine,
);

final localSemanticStoreProvider = Provider<LocalSemanticStore>((ref) {
  ref.watch(vaultRestoreRevisionProvider);
  return ref.watch(appServicesProvider).localSemanticStore;
});

final semanticClusterStoreProvider = Provider<SemanticClusterStore>((ref) {
  ref.watch(vaultRestoreRevisionProvider);
  return ref.watch(appServicesProvider).semanticClusterStore;
});

final semanticClusterEngineProvider = Provider<SemanticClusterEngine>(
  (ref) => ref.watch(appServicesProvider).semanticClusterEngine,
);

final aiCostTelemetryProvider = Provider<AiCostTelemetry>(
  (ref) => ref.watch(appServicesProvider).aiCostTelemetry,
);

final hybridAiRouterProvider = Provider<HybridAiRouter>(
  (ref) => ref.watch(appServicesProvider).hybridAiRouter,
);

final explainabilityHistoryStoreProvider = Provider<ExplainabilityHistoryStore>(
  (ref) => ref.watch(appServicesProvider).explainabilityHistoryStore,
);

final transcriptionLedgerProvider = Provider<TranscriptionLedger>(
  (ref) => ref.watch(appServicesProvider).transcriptionLedger,
);

final journalEntriesStreamProvider = StreamProvider(
  (ref) => ref.watch(journalStoreProvider).watchAll(),
);

final transcriptionJobsStreamProvider = StreamProvider(
  (ref) => ref.watch(transcriptionLedgerProvider).watchJobs,
);

final transcriptionTimelineProvider =
    Provider<AsyncValue<TranscriptionTimelineSnapshot>>((ref) {
      final journal = ref.watch(journalEntriesStreamProvider);
      final jobs = ref.watch(transcriptionJobsStreamProvider);
      if (journal.hasError) {
        return AsyncError(journal.error!, journal.stackTrace!);
      }
      if (jobs.hasError) return AsyncError(jobs.error!, jobs.stackTrace!);
      final entries = journal.value;
      final allJobs = jobs.value;
      if (entries == null || allJobs == null) {
        return const AsyncLoading();
      }
      final pending =
          allJobs
              .where(
                (job) =>
                    job.status != TranscriptionJobStatus.completed &&
                    job.status != TranscriptionJobStatus.cancelled,
              )
              .toList(growable: false)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return AsyncData(
        TranscriptionTimelineSnapshot(
          entries: List.unmodifiable(entries),
          pendingJobs: List.unmodifiable(pending),
        ),
      );
    });

final journalServiceProvider = Provider<JournalService>(
  (ref) => ref.watch(appServicesProvider).journal,
);

final prefsProvider = Provider<MobilePrefsStore>(
  (ref) => ref.watch(appServicesProvider).prefs,
);

final authServiceProvider = Provider<AuthService>(
  (ref) => ref.watch(appServicesProvider).auth,
);

final recordingServiceProvider = Provider<RecordingService>(
  (ref) => ref.watch(appServicesProvider).recording,
);

final capturePipelineProvider = Provider<CapturePipelineService>(
  (ref) => ref.watch(appServicesProvider).pipeline,
);

final liveVoiceCaptureProvider = Provider<LiveVoiceCaptureService>(
  (ref) => ref.watch(appServicesProvider).liveVoiceCapture,
);

final liveAudioFocusGatewayProvider = Provider<LiveAudioFocusGateway>(
  (ref) => LiveAudioFocusGateway(
    captureService: ref.watch(liveVoiceCaptureProvider),
  ),
);

final ambientContextServiceProvider = Provider<AmbientContextService>(
  (ref) => AmbientContextService(),
);

final guestFirstAuthProvider = Provider<GuestFirstAuth>(
  (ref) => GuestFirstAuth(ref.watch(prefsProvider)),
);

typedef AppLifecycleListenerFactory =
    AppLifecycleListener Function({
      required void Function(AppLifecycleState state) onStateChange,
    });

final appLifecycleListenerFactoryProvider =
    Provider<AppLifecycleListenerFactory>(
      (ref) =>
          ({required onStateChange}) =>
              AppLifecycleListener(onStateChange: onStateChange),
    );
