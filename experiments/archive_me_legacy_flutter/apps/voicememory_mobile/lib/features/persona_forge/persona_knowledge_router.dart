import 'dart:collection';

import '../../core/graph/personal_knowledge_graph.dart';
import '../../services/ai/local_semantic_store.dart';
import '../cognitive_council/council_persona.dart';
import '../semantic_clusters/semantic_cluster.dart';
import '../semantic_clusters/semantic_cluster_store.dart';

typedef PersonaClusterLoader = Future<List<SemanticCluster>> Function();
typedef PersonaScopedSearch =
    Future<List<LocalSemanticHit>> Function(
      String query, {
      required Set<String> allowedNodeIds,
      required int limit,
    });

final class PersonaKnowledgeContext {
  PersonaKnowledgeContext({
    required Iterable<Map<String, Object?>> clusters,
    required Iterable<Map<String, Object?>> nodes,
    required Iterable<String> semanticEntryIds,
  }) : clusters = List.unmodifiable(clusters),
       nodes = List.unmodifiable(nodes),
       semanticEntryIds = List.unmodifiable(semanticEntryIds);

  final List<Map<String, Object?>> clusters;
  final List<Map<String, Object?>> nodes;
  final List<String> semanticEntryIds;

  Map<String, Object> toJson() => {
    'clusters': clusters,
    'nodes': nodes,
    'semanticEntryIds': semanticEntryIds,
  };
}

final class PersonaInvocationRequest {
  PersonaInvocationRequest({
    required this.personaId,
    required this.systemPrompt,
    required this.userMessage,
    required this.temperature,
    required this.context,
  });

  static const nonRetentionHeaders = <String, String>{
    'Cache-Control': 'no-store, max-age=0',
    'Pragma': 'no-cache',
    'X-Data-Retention': 'none',
  };

  final String personaId;
  final String systemPrompt;
  final String userMessage;
  final double temperature;
  final PersonaKnowledgeContext context;

  Map<String, Object> toJson() => {
    'personaId': personaId,
    'systemPrompt': systemPrompt,
    'userMessage': userMessage,
    'temperature': temperature,
    'context': context.toJson(),
    'store': false,
  };
}

/// Builds a fail-closed context boundary for custom Council personas.
///
/// Retrieval delegates to [LocalSemanticStore], which uses
/// `SqliteVecVectorStore` when available. Only node IDs belonging to explicitly
/// granted semantic clusters can leave this router.
final class PersonaKnowledgeRouter {
  PersonaKnowledgeRouter({
    required LocalSemanticStore semanticStore,
    required SemanticClusterStore clusterStore,
    required Future<PersonalKnowledgeGraph> Function() graphLoader,
    PersonaClusterLoader? clusterLoader,
    PersonaScopedSearch? semanticSearch,
  }) : // Public named parameters cannot initialize private fields directly.
       // ignore: prefer_initializing_formals
       _semanticStore = semanticStore,
       _clusterLoader = clusterLoader ?? clusterStore.list,
       // ignore: prefer_initializing_formals
       _semanticSearch = semanticSearch,
       // ignore: prefer_initializing_formals
       _graphLoader = graphLoader;

  final LocalSemanticStore _semanticStore;
  final PersonaClusterLoader _clusterLoader;
  final PersonaScopedSearch? _semanticSearch;
  final Future<PersonalKnowledgeGraph> Function() _graphLoader;

  Future<PersonaInvocationRequest> buildInvocation({
    required CouncilPersona persona,
    required String userMessage,
    String localeTag = 'en',
    int limit = 16,
  }) async {
    final message = userMessage.trim();
    if (message.isEmpty || message.length > 12000) {
      throw ArgumentError.value(
        userMessage,
        'userMessage',
        'must be 1-12000 characters',
      );
    }
    final context = await scopedContext(
      persona: persona,
      query: message,
      limit: limit,
    );
    return PersonaInvocationRequest(
      personaId: persona.id,
      systemPrompt: persona.promptForLocale(localeTag),
      userMessage: message,
      temperature: persona.temperature,
      context: context,
    );
  }

  Future<PersonaKnowledgeContext> scopedContext({
    required CouncilPersona persona,
    required String query,
    int limit = 16,
  }) async {
    if (persona.restrictedClusterIds.isEmpty) {
      return PersonaKnowledgeContext(
        clusters: const [],
        nodes: const [],
        semanticEntryIds: const [],
      );
    }
    final allClusters = await _clusterLoader();
    final selected = allClusters
        .where((cluster) => persona.restrictedClusterIds.contains(cluster.id))
        .toList();
    if (selected.length != persona.restrictedClusterIds.length) {
      throw StateError('A persona references a missing semantic cluster.');
    }
    selected.sort((left, right) => left.id.compareTo(right.id));
    final allowedNodeIds = selected.expand((item) => item.nodeIds).toSet();
    final boundedLimit = limit.clamp(1, 50);
    final hits =
        await (_semanticSearch?.call(
              query,
              allowedNodeIds: allowedNodeIds,
              limit: boundedLimit,
            ) ??
            _semanticStore.search(
              query,
              allowedNodeIds: allowedNodeIds,
              limit: boundedLimit,
            ));
    final matchedNodeIds = hits.expand((item) => item.nodeIds).toSet();
    final graph = await _graphLoader();
    final nodes =
        graph.nodes
            .where(
              (node) =>
                  allowedNodeIds.contains(node.id) &&
                  matchedNodeIds.contains(node.id),
            )
            .map(
              (node) => <String, Object?>{
                'id': node.id,
                'type': node.type.name,
                'label': node.label,
                'confidence': node.confidence,
                'createdAt': node.createdAt.toIso8601String(),
              },
            )
            .toList()
          ..sort(
            (left, right) =>
                (left['id']! as String).compareTo(right['id']! as String),
          );
    return PersonaKnowledgeContext(
      clusters: selected.map(_clusterJson),
      nodes: nodes,
      semanticEntryIds: SplayTreeSet<String>.from(
        hits.map((item) => item.entryId),
      ),
    );
  }

  static Map<String, Object?> _clusterJson(SemanticCluster cluster) => {
    'id': cluster.id,
    'title': cluster.title,
    'category': cluster.category.wireName,
    'summary': cluster.summary,
    'nodeIds': cluster.nodeIds,
  };
}
