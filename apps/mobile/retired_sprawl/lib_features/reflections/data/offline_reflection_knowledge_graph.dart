import 'package:archiveme_mobile/features/reflections/data/offline_reflection_knowledge_graph.dart';

/// Directed edges for the on-device reflection knowledge graph.
class ReflectionGraphEdge {
  const ReflectionGraphEdge({
    required this.fromNodeId,
    required this.toNodeId,
    required this.relation,
    this.weight = 1,
  });

  final String fromNodeId;
  final String toNodeId;

  /// e.g. `has_tension`, `suggests_action`, `mentions_theme`.
  final String relation;
  final double weight;

  Map<String, dynamic> toJson() => {
    'from': fromNodeId,
    'to': toNodeId,
    'relation': relation,
    'weight': weight,
  };
}

/// Node in the offline reflection knowledge graph.
class ReflectionGraphNode {
  const ReflectionGraphNode({
    required this.id,
    required this.kind,
    required this.label,
    this.payload = const {},
  });

  final String id;
  final String kind;
  final String label;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'label': label,
    if (payload.isNotEmpty) 'payload': payload,
  };
}

/// Local graph built from ONNX reflection extraction — anchored on [entryId].
class OfflineReflectionKnowledgeGraph {
  const OfflineReflectionKnowledgeGraph({
    required this.entryId,
    required this.nodes,
    required this.edges,
    this.tensionOrContradiction,
    this.nextSmallAction,
  });

  final String entryId;
  final List<ReflectionGraphNode> nodes;
  final List<ReflectionGraphEdge> edges;
  final String? tensionOrContradiction;
  final String? nextSmallAction;

  Map<String, dynamic> toJson() => {
    'entryId': entryId,
    if (tensionOrContradiction != null)
      'tensionOrContradiction': tensionOrContradiction,
    if (nextSmallAction != null) 'nextSmallAction': nextSmallAction,
    'nodes': nodes.map((node) => node.toJson()).toList(),
    'edges': edges.map((edge) => edge.toJson()).toList(),
  };

  static OfflineReflectionKnowledgeGraph fromReflectionFields({
    required String entryId,
    required String? tensionOrContradiction,
    required String? nextSmallAction,
    List<String> recurringThemes = const [],
  }) {
    final nodes = <ReflectionGraphNode>[
      ReflectionGraphNode(
        id: 'entry:$entryId',
        kind: 'journal_entry',
        label: entryId,
      ),
    ];
    final edges = <ReflectionGraphEdge>[];

    final tension = tensionOrContradiction?.trim();
    if (tension != null && tension.isNotEmpty) {
      final nodeId = 'tension:$entryId';
      nodes.add(
        ReflectionGraphNode(
          id: nodeId,
          kind: 'tension',
          label: tension,
          payload: {'field': 'tensionOrContradiction'},
        ),
      );
      edges.add(
        ReflectionGraphEdge(
          fromNodeId: 'entry:$entryId',
          toNodeId: nodeId,
          relation: 'has_tension',
        ),
      );
    }

    final action = nextSmallAction?.trim();
    if (action != null && action.isNotEmpty) {
      final nodeId = 'action:$entryId';
      nodes.add(
        ReflectionGraphNode(
          id: nodeId,
          kind: 'next_action',
          label: action,
          payload: {'field': 'nextSmallAction'},
        ),
      );
      edges.add(
        ReflectionGraphEdge(
          fromNodeId: 'entry:$entryId',
          toNodeId: nodeId,
          relation: 'suggests_action',
        ),
      );
    }

    for (final theme in recurringThemes) {
      final trimmed = theme.trim();
      if (trimmed.isEmpty) continue;
      final slug = trimmed.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
      final nodeId = 'theme:$slug:$entryId';
      if (!nodes.any((node) => node.id == nodeId)) {
        nodes.add(
          ReflectionGraphNode(
            id: nodeId,
            kind: 'theme',
            label: trimmed,
          ),
        );
      }
      edges.add(
        ReflectionGraphEdge(
          fromNodeId: 'entry:$entryId',
          toNodeId: nodeId,
          relation: 'mentions_theme',
          weight: 0.8,
        ),
      );
    }

    return OfflineReflectionKnowledgeGraph(
      entryId: entryId,
      nodes: nodes,
      edges: edges,
      tensionOrContradiction: tension,
      nextSmallAction: action,
    );
  }
}
