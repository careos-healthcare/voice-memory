import 'dart:ui';

/// Role of a node in a citation connection graph.
enum EvidenceGraphNodeKind { message, evidence }

/// One node in an evidence connection graph.
class EvidenceGraphNode {
  const EvidenceGraphNode({
    required this.id,
    required this.label,
    required this.kind,
    required this.position,
    this.subtitle,
    this.entryId,
    this.excerpt,
    this.dateLabel,
    this.available = true,
  });

  final String id;
  final String label;
  final String? subtitle;
  final EvidenceGraphNodeKind kind;
  final Offset position;
  final String? entryId;
  final String? excerpt;
  final String? dateLabel;

  /// False when the cited entry could not be loaded (deleted or lookup fail).
  final bool available;

  bool get isNavigable => available && entryId != null && entryId!.isNotEmpty;
}

/// Directed link between two [EvidenceGraphNode]s.
class EvidenceGraphEdge {
  const EvidenceGraphEdge({required this.fromId, required this.toId});

  final String fromId;
  final String toId;
}

/// Layout-ready graph of a reply and the moments it cites.
class EvidenceConnectionGraph {
  const EvidenceConnectionGraph({
    required this.nodes,
    required this.edges,
    required this.canvasSize,
    required this.messageNodeId,
  });

  final List<EvidenceGraphNode> nodes;
  final List<EvidenceGraphEdge> edges;
  final Size canvasSize;
  final String messageNodeId;

  EvidenceGraphNode? nodeById(String id) {
    for (final node in nodes) {
      if (node.id == id) return node;
    }
    return null;
  }
}
