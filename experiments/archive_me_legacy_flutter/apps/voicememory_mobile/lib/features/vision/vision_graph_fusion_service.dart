import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph.dart';
import '../../core/graph/personal_knowledge_graph_store.dart';
import '../../services/ai/local_semantic_store.dart';
import '../media/media_attachment.dart';
import 'vision_extraction_models.dart';

class VisionGraphFusionResult {
  const VisionGraphFusionResult({
    required this.sourceNodeId,
    required this.nodeIds,
    required this.edgeIds,
  });

  final String sourceNodeId;
  final List<String> nodeIds;
  final List<String> edgeIds;
}

class VisionGraphFusionService {
  const VisionGraphFusionService({
    required PersonalKnowledgeGraphStore graphStore,
    required LocalSemanticStore semanticStore,
    this.onGraphChanged,
  }) : // Public named parameters cannot initialize private fields directly.
       // ignore: prefer_initializing_formals
       _graphStore = graphStore,
       // ignore: prefer_initializing_formals
       _semanticStore = semanticStore;

  final PersonalKnowledgeGraphStore _graphStore;
  final LocalSemanticStore _semanticStore;
  final void Function()? onGraphChanged;

  Future<VisionGraphFusionResult> fuse({
    required MediaAttachment attachment,
    required VisionExtractionResult result,
  }) async {
    final extraction = result.extraction;
    final sourceNodeId = stableGraphId('media-source', [attachment.id]);
    final nodes = <String, GraphNode>{
      sourceNodeId: GraphNode(
        id: sourceNodeId,
        type: NodeType.memory,
        label: extraction.sceneSummary,
        confidence: 1,
        origin: NodeOrigin.media,
        createdAt: attachment.createdAt,
        mediaAttachments: [attachment],
      ),
    };
    final edges = <String, GraphEdge>{};
    final entityNodeIdsByLabel = <String, List<String>>{};
    final orderedEntities = extraction.entities.toList()
      ..sort((left, right) {
        final byKind = left.kind.name.compareTo(right.kind.name);
        return byKind != 0 ? byKind : left.label.compareTo(right.label);
      });

    for (final entity in orderedEntities) {
      final normalized = normalizeGraphLabel(entity.label);
      if (normalized.isEmpty) continue;
      final entityId = stableGraphId('media-entity', [
        attachment.id,
        entity.kind.name,
        normalized,
      ]);
      nodes[entityId] = GraphNode(
        id: entityId,
        type: _nodeType(entity.kind),
        label: entity.label,
        confidence: entity.confidence,
        origin: NodeOrigin.media,
        createdAt: attachment.createdAt,
      );
      entityNodeIdsByLabel.putIfAbsent(entity.label, () => []).add(entityId);
      final edge = GraphEdge(
        sourceNodeId: sourceNodeId,
        targetNodeId: entityId,
        type: EdgeType.associatedWith,
        isDirected: false,
        weight: entity.confidence,
        origin: NodeOrigin.media,
        createdAt: attachment.createdAt,
      );
      edges[edge.id] = edge;
    }
    for (final ids in entityNodeIdsByLabel.values) {
      ids.sort();
    }

    final orderedRelationships = extraction.relationships.toList()
      ..sort((left, right) {
        final leftKey =
            '${left.source}\u001f${left.target}\u001f${left.relationship}';
        final rightKey =
            '${right.source}\u001f${right.target}\u001f${right.relationship}';
        return leftKey.compareTo(rightKey);
      });
    for (final relationship in orderedRelationships) {
      final sourceId = entityNodeIdsByLabel[relationship.source]?.firstOrNull;
      final targetId = entityNodeIdsByLabel[relationship.target]?.firstOrNull;
      if (sourceId == null || targetId == null || sourceId == targetId) {
        continue;
      }
      final edge = GraphEdge(
        id: stableGraphId('media-relation', [
          attachment.id,
          sourceId,
          targetId,
          normalizeGraphLabel(relationship.relationship),
        ]),
        sourceNodeId: sourceId,
        targetNodeId: targetId,
        type: EdgeType.associatedWith,
        isDirected: true,
        weight: relationship.confidence,
        origin: NodeOrigin.media,
        createdAt: attachment.createdAt,
      );
      edges[edge.id] = edge;
    }

    final current = await _graphStore.load();
    final mergedNodes = {for (final node in current.nodes) node.id: node}
      ..addAll(nodes);
    final mergedEdges = {for (final edge in current.edges) edge.id: edge}
      ..addAll(edges);
    final sortedNodes = mergedNodes.values.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    final sortedEdges = mergedEdges.values.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    await _graphStore.save(
      PersonalKnowledgeGraph(
        schemaVersion: current.schemaVersion,
        nodes: sortedNodes,
        edges: sortedEdges,
        trajectories: current.trajectories,
        materialization: current.materialization,
        clock: current.clock,
      ),
    );

    final nodeIds = nodes.keys.toList()..sort();
    await _semanticStore.upsertMediaMemory(
      sourceNodeId: sourceNodeId,
      searchableText: [
        extraction.sceneSummary,
        ...extraction.visibleText,
        ...extraction.entities.map((entity) => entity.label),
      ].join('\n'),
      nodeIds: nodeIds,
      tags: {
        ...result.local.tags,
        'origin:media',
        ...extraction.entities.map((entity) => 'vision:${entity.kind.name}'),
      },
    );
    onGraphChanged?.call();
    final edgeIds = edges.keys.toList()..sort();
    return VisionGraphFusionResult(
      sourceNodeId: sourceNodeId,
      nodeIds: nodeIds,
      edgeIds: edgeIds,
    );
  }

  static NodeType _nodeType(VisionEntityKind kind) => switch (kind) {
    VisionEntityKind.person => NodeType.person,
    VisionEntityKind.place => NodeType.place,
    VisionEntityKind.object => NodeType.object,
    VisionEntityKind.text => NodeType.text,
  };
}
