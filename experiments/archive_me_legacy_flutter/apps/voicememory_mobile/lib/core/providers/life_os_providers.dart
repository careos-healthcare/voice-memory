import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/app_services_providers.dart';
import '../../services/app_services.dart';
import '../../services/life_os_graph_builder.dart';
import '../../features/cold_start/cold_start_engine.dart';
import '../../features/semantic_clusters/semantic_cluster.dart';
import '../archive_intelligence/archive_intelligence_engine.dart';
import '../engines/ai_time_machine_engine.dart';
import '../engines/evidence_coaching_engine.dart';
import '../engines/goal_evidence_engine.dart';
import '../engines/life_chapters_engine.dart';
import '../engines/life_story_engine.dart';
import '../engines/long_term_predictor_engine.dart';
import '../engines/relationship_memory_engine.dart';
import '../graph/personal_knowledge_graph.dart';
import '../graph/unified_graph_projection_engine.dart';
import '../life_story/life_story_synthesis_engine.dart';
import '../llm/on_device_extractor.dart';
import '../search/local_vector_search_engine.dart';

/// Local semantic extraction stays injectable so tests and future native
/// quantized-model adapters do not leak state across provider containers.
final onDeviceExtractorProvider = Provider<OnDeviceSemanticExtractor>((ref) {
  if (!AppServices.isInitialized) return const OnDeviceSemanticExtractor();
  ref.watch(llamaKnowledgeGraphRevisionProvider);
  final candidate = AppServices.instance.llamaInferenceSession;
  final session = candidate != null && candidate.isReady ? candidate : null;
  return OnDeviceSemanticExtractor(
    asyncDriver: session == null ? null : LlamaSessionSemanticDriver(session),
  );
});

final personalKnowledgeGraphEngineProvider =
    Provider<PersonalKnowledgeGraphEngine>(
      (ref) => PersonalKnowledgeGraphEngine(
        extractor: ref.watch(onDeviceExtractorProvider),
      ),
    );

/// Loads the encrypted materialized graph and reconciles only journal deltas.
///
/// The provider has no network dependency and can be overridden directly in tests.
final knowledgeGraphProvider =
    FutureProvider.autoDispose<PersonalKnowledgeGraph>((ref) async {
      ref.watch(llamaKnowledgeGraphRevisionProvider);
      final journalSnapshot = ref.watch(journalEntriesStreamProvider);
      final entries =
          journalSnapshot.value ??
          await ref.watch(journalServiceProvider).loadAll();
      final store = ref.watch(personalKnowledgeGraphStoreProvider);
      final base = await store.reconcile(entries);
      final insights = const ArchiveIntelligenceEngine().buildInsights(
        entries: entries,
      );
      var unified = const UnifiedGraphProjectionEngine().project(
        base: base,
        entries: entries,
        archiveInsights: insights.allInsights,
      );
      final manualGraph = await ref
          .watch(localSemanticStoreProvider)
          .manualGraph();
      unified = _mergeOverlayGraph(unified, manualGraph);
      final externalGraph = await ref
          .watch(localSemanticStoreProvider)
          .externalGraph();
      unified = _mergeOverlayGraph(unified, externalGraph);
      if (entries.length == 1) {
        final seedStore = ColdStartSeedStore(ref.watch(prefsProvider));
        if (await seedStore.load() != null) {
          unified = ColdStartEngine(
            seedStore: seedStore,
            graphStore: store,
          ).connectFirstEntry(unified, entries.single);
        }
      }
      unified = await ref
          .watch(localSemanticStoreProvider)
          .applyGraphConstraints(unified);
      unified = _canonicalGraphOrder(unified);
      await store.save(unified);
      return unified;
    });

/// Reactive encrypted semantic clusters for Life OS surfaces.
final semanticClustersProvider =
    StreamProvider.autoDispose<List<SemanticCluster>>((ref) async* {
      final store = ref.watch(semanticClusterStoreProvider);
      final revisions = store.revisions;
      yield await store.list();
      await for (final _ in revisions) {
        yield await store.list();
      }
    });

PersonalKnowledgeGraph _mergeOverlayGraph(
  PersonalKnowledgeGraph graph,
  PersonalKnowledgeGraph manual,
) {
  final nodes = {for (final node in graph.nodes) node.id: node};
  nodes.addEntries(manual.nodes.map((node) => MapEntry(node.id, node)));
  final edges = {for (final edge in graph.edges) edge.id: edge};
  edges.addEntries(manual.edges.map((edge) => MapEntry(edge.id, edge)));
  return PersonalKnowledgeGraph(
    schemaVersion: graph.schemaVersion,
    nodes: nodes.values,
    edges: edges.values,
    trajectories: graph.trajectories,
    materialization: graph.materialization,
  );
}

PersonalKnowledgeGraph _canonicalGraphOrder(PersonalKnowledgeGraph graph) {
  final nodes = graph.nodes.toList()..sort((a, b) => a.id.compareTo(b.id));
  final edges = graph.edges.toList()..sort((a, b) => a.id.compareTo(b.id));
  final trajectories = graph.trajectories.toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  return PersonalKnowledgeGraph(
    schemaVersion: graph.schemaVersion,
    nodes: nodes,
    edges: edges,
    trajectories: trajectories,
    materialization: graph.materialization,
  );
}

/// Hybrid dense + SQLite FTS5 search built entirely from the governed graph.
///
/// The FTS index and embeddings are memory-only and are disposed with the
/// provider, so private excerpts are never written to an unencrypted sidecar.
final hybridVectorSearchProvider =
    FutureProvider.autoDispose<LocalVectorSearchEngine>((ref) async {
      final graph = await ref.watch(knowledgeGraphProvider.future);
      final engine = LocalVectorSearchEngine(graph: graph);
      ref.onDispose(engine.dispose);
      return engine;
    });

final lifeStoryProvider = FutureProvider.autoDispose<LifeStoryEngine>((
  ref,
) async {
  final graph = await ref.watch(knowledgeGraphProvider.future);
  return LifeStoryEngine(graph);
});

final aiTimeMachineProvider = FutureProvider.autoDispose<AITimeMachineEngine>((
  ref,
) async {
  final graph = await ref.watch(knowledgeGraphProvider.future);
  return AITimeMachineEngine(graph);
});

final evidenceCoachProvider =
    FutureProvider.autoDispose<EvidenceCoachingEngine>((ref) async {
      final graph = await ref.watch(knowledgeGraphProvider.future);
      return EvidenceCoachingEngine(graph);
    });

final lifeStorySynthesisProvider =
    FutureProvider.autoDispose<LifeStorySynthesisSnapshot>((ref) async {
      final graph = await ref.watch(knowledgeGraphProvider.future);
      return LifeStorySynthesisEngine(graph).synthesize();
    });

final relationshipMemoryProvider =
    FutureProvider.autoDispose<List<RelationshipMemory>>((ref) async {
      final synthesis = await ref.watch(lifeStorySynthesisProvider.future);
      return synthesis.relationships;
    });

final goalEvidenceProvider =
    FutureProvider.autoDispose<List<GoalEvidenceRecord>>((ref) async {
      final synthesis = await ref.watch(lifeStorySynthesisProvider.future);
      return synthesis.goals;
    });

final lifeChaptersProvider = FutureProvider.autoDispose<List<LifeChapter>>((
  ref,
) async {
  final synthesis = await ref.watch(lifeStorySynthesisProvider.future);
  return synthesis.chapters;
});

final longTermForecastProvider =
    FutureProvider.autoDispose<List<ConditionalTrajectoryForecast>>((
      ref,
    ) async {
      final synthesis = await ref.watch(lifeStorySynthesisProvider.future);
      return synthesis.forecasts;
    });

/// A single awaitable view model keeps the route's loading and error states safe.
final lifeOsOverviewProvider = FutureProvider.autoDispose<LifeOsOverview>((
  ref,
) async {
  final synthesis = await ref.watch(lifeStorySynthesisProvider.future);

  return LifeOsOverview(
    graph: synthesis.graph,
    story: synthesis.story,
    chapters: synthesis.chapters,
    goals: synthesis.goals,
    relationships: synthesis.relationships,
    coachingObservations: synthesis.coachingObservations,
    forecasts: synthesis.forecasts,
  );
});

class LifeOsOverview {
  const LifeOsOverview({
    required this.graph,
    required this.story,
    required this.chapters,
    required this.goals,
    required this.relationships,
    required this.coachingObservations,
    required this.forecasts,
  });

  final PersonalKnowledgeGraph graph;
  final LifeStory story;
  final List<LifeChapter> chapters;
  final List<GoalEvidenceRecord> goals;
  final List<RelationshipMemory> relationships;
  final List<EvidenceCoachingObservation> coachingObservations;
  final List<ConditionalTrajectoryForecast> forecasts;
}
