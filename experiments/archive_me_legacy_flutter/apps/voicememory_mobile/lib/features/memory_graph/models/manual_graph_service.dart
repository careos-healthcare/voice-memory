import '../../../core/graph/graph_node.dart';
import '../../../core/graph/personal_knowledge_graph.dart';
import '../../../core/graph/personal_knowledge_graph_store.dart';
import '../../../services/ai/local_semantic_store.dart';
import 'manual_graph_models.dart';

class ManualGraphService {
  const ManualGraphService({
    required this.graphStore,
    required this.semanticStore,
    this.clock = DateTime.now,
  });

  final PersonalKnowledgeGraphStore graphStore;
  final LocalSemanticStore semanticStore;
  final DateTime Function() clock;

  Future<GraphNode> createNode(ManualNodeDraft draft) async {
    final label = draft.label.trim();
    if (label.isEmpty) throw ArgumentError.value(label, 'label');
    final now = clock().toUtc();
    final excerpt = draft.note?.trim().isNotEmpty == true
        ? draft.note!.trim()
        : label;
    final token = now.microsecondsSinceEpoch.toString();
    final node = GraphNode(
      id: stableGraphId('manual-node', [token, label]),
      type: _nodeType(draft.category),
      label: label,
      confidence: 1,
      origin: NodeOrigin.manual,
      mediaAttachments: draft.mediaAttachments,
      evidence: [
        GraphNodeEvidence(
          entryId: 'manual-node-$token',
          observedAt: now,
          confidence: 1,
          excerpt: excerpt,
          startUtf16: 0,
          endUtf16: excerpt.length,
        ),
      ],
    );
    await _persist(node: node);
    return node;
  }

  Future<GraphEdge> connect({
    required GraphNode source,
    required GraphNode target,
    EdgeType type = EdgeType.associatedWith,
    String? note,
  }) async {
    if (source.id == target.id) {
      throw ArgumentError('A manual connection requires two different nodes.');
    }
    final now = clock().toUtc();
    final excerpt = note?.trim().isNotEmpty == true
        ? note!.trim()
        : '${source.label} → ${target.label}';
    final edge = GraphEdge(
      id: stableGraphId('manual-edge', [source.id, target.id, type.name]),
      sourceNodeId: source.id,
      targetNodeId: target.id,
      type: type,
      isDirected: true,
      weight: 1,
      origin: NodeOrigin.manual,
      evidence: [
        GraphEdgeEvidence(
          entryId: 'manual-edge-${now.microsecondsSinceEpoch}',
          observedAt: now,
          confidence: 1,
          excerpt: excerpt,
          startUtf16: 0,
          endUtf16: excerpt.length,
        ),
      ],
    );
    await _persist(edge: edge, referencedNodes: [source, target]);
    return edge;
  }

  Future<void> _persist({
    GraphNode? node,
    GraphEdge? edge,
    List<GraphNode> referencedNodes = const [],
  }) async {
    final current = await graphStore.load();
    final manual = await semanticStore.manualGraph();
    final manualNodes = {for (final item in manual.nodes) item.id: item};
    for (final item in referencedNodes) {
      manualNodes.putIfAbsent(item.id, () => item);
    }
    if (node != null) manualNodes[node.id] = node;
    final manualEdges = {for (final item in manual.edges) item.id: item};
    if (edge != null) manualEdges[edge.id] = edge;
    final nextManual = PersonalKnowledgeGraph(
      nodes: manualNodes.values,
      edges: manualEdges.values,
    );
    await semanticStore.saveManualGraph(nextManual);

    final nodes = {for (final item in current.nodes) item.id: item};
    nodes.addAll(manualNodes);
    final edges = {for (final item in current.edges) item.id: item};
    edges.addAll(manualEdges);
    await graphStore.save(
      PersonalKnowledgeGraph(
        schemaVersion: current.schemaVersion,
        nodes: nodes.values,
        edges: edges.values,
        trajectories: current.trajectories,
        materialization: GraphMaterializationMetadata(
          processedEntryRevisions:
              current.materialization.processedEntryRevisions,
          extractorVersion: graphStore.extractorVersion,
          governanceVersion: graphStore.governanceVersion,
          governanceHash: graphStore.governanceHash,
          materializedAt: clock().toUtc(),
        ),
      ),
    );
  }

  NodeType _nodeType(ManualNodeCategory category) => switch (category) {
    ManualNodeCategory.person => NodeType.person,
    ManualNodeCategory.habit => NodeType.habit,
    ManualNodeCategory.emotion => NodeType.emotion,
    ManualNodeCategory.goal => NodeType.goal,
    ManualNodeCategory.idea => NodeType.topic,
  };
}
