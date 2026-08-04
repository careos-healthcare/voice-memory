import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph.dart';
import '../../core/graph/personal_knowledge_graph_store.dart';
import '../../features/sync/e2ee_sync_models.dart';
import '../../features/sync/encrypted_sync_engine.dart';
import '../../services/ai/local_semantic_store.dart';

class ExternalGraphService {
  const ExternalGraphService({
    required this.graphStore,
    required this.semanticStore,
    this.syncEngine,
    this.onGraphChanged,
  });

  final PersonalKnowledgeGraphStore graphStore;
  final LocalSemanticStore semanticStore;
  final EncryptedSyncEngine? syncEngine;
  final void Function()? onGraphChanged;

  Future<PersonalKnowledgeGraph> upsert(PersonalKnowledgeGraph incoming) async {
    final external = await semanticStore.externalGraph();
    final nodes = {for (final node in external.nodes) node.id: node}
      ..addEntries(
        incoming.nodes
            .where((node) => node.origin == NodeOrigin.external)
            .map((node) => MapEntry(node.id, node)),
      );
    final edges = {for (final edge in external.edges) edge.id: edge}
      ..addEntries(
        incoming.edges
            .where((edge) => edge.origin == NodeOrigin.external)
            .map((edge) => MapEntry(edge.id, edge)),
      );
    final nextExternal = PersonalKnowledgeGraph(
      nodes: nodes.values,
      edges: edges.values,
    );
    await semanticStore.saveExternalGraph(nextExternal);

    final sync = syncEngine;
    if (sync != null && await sync.identity.isEnabled) {
      for (final node in incoming.nodes) {
        await sync.record(
          entityKind: CrdtEntityKind.node,
          entityId: node.id,
          mutation: CrdtMutation.upsert,
          payload: node.toJson(),
        );
      }
      for (final edge in incoming.edges) {
        await sync.record(
          entityKind: CrdtEntityKind.edge,
          entityId: edge.id,
          mutation: CrdtMutation.upsert,
          payload: edge.toJson(),
        );
      }
    }

    final current = await graphStore.load();
    final allNodes = {for (final node in current.nodes) node.id: node}
      ..addAll(nodes);
    final allEdges = {for (final edge in current.edges) edge.id: edge}
      ..addAll(edges);
    final merged = PersonalKnowledgeGraph(
      schemaVersion: current.schemaVersion,
      nodes: allNodes.values,
      edges: allEdges.values,
      trajectories: current.trajectories,
      materialization: current.materialization,
    );
    await graphStore.save(merged);
    onGraphChanged?.call();
    return nextExternal;
  }
}
