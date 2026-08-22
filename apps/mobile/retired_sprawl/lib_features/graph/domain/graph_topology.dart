import 'dart:ui';

/// Lightweight graph node loaded without journal payloads or node payload_json.
class GraphNodeRecord {
  const GraphNodeRecord({
    required this.id,
    required this.entryId,
    required this.kind,
    required this.label,
  });

  final String id;
  final String entryId;
  final String kind;
  final String label;

  factory GraphNodeRecord.fromRow(Map<String, Object?> row) {
    return GraphNodeRecord(
      id: row['id'] as String? ?? '',
      entryId: row['entry_id'] as String? ?? '',
      kind: row['kind'] as String? ?? '',
      label: row['label'] as String? ?? '',
    );
  }
}

/// Directed edge between graph nodes (never materializes transcript text).
class GraphLinkRecord {
  const GraphLinkRecord({
    required this.fromNodeId,
    required this.toNodeId,
    required this.relation,
    required this.weight,
  });

  final String fromNodeId;
  final String toNodeId;
  final String relation;
  final double weight;
}

/// Topology bundle consumed by [GraphCanvas].
class GraphTopology {
  const GraphTopology({
    required this.nodes,
    required this.links,
    this.seedEntryId,
  });

  final List<GraphNodeRecord> nodes;
  final List<GraphLinkRecord> links;
  final String? seedEntryId;

  GraphNodeRecord? nodeById(String id) {
    for (final node in nodes) {
      if (node.id == id) return node;
    }
    return null;
  }
}

/// Mutable simulation node with layout state.
class GraphLayoutNode {
  GraphLayoutNode({
    required this.record,
    required this.position,
    this.velocity = Offset.zero,
    this.mass = 1,
  });

  final GraphNodeRecord record;
  Offset position;
  Offset velocity;
  double mass;

  String get id => record.id;
}

/// Edge reference for the force simulation.
class GraphLayoutLink {
  const GraphLayoutLink({
    required this.fromId,
    required this.toId,
    this.restLength = 120,
    this.stiffness = 0.04,
  });

  final String fromId;
  final String toId;
  final double restLength;
  final double stiffness;
}
