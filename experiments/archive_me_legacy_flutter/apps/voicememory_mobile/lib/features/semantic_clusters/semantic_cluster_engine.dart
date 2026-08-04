// ignore_for_file: prefer_initializing_formals

import 'dart:isolate';
import 'dart:math' as math;

import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph.dart';
import '../../services/ai/local_semantic_store.dart';
import 'semantic_cluster.dart';

typedef SemanticClusterClock = DateTime Function();

final class SemanticClusterEngine {
  const SemanticClusterEngine({
    required LocalSemanticStore semanticStore,
    this.clock,
    this.minimumLinkWeight = 0.3,
  }) : _semanticStore = semanticStore;

  final LocalSemanticStore _semanticStore;
  final SemanticClusterClock? clock;
  final double minimumLinkWeight;

  Future<List<SemanticCluster>> build(
    PersonalKnowledgeGraph graph, {
    Iterable<SemanticCluster> storedClusters = const [],
  }) async {
    final now = (clock?.call() ?? DateTime.now()).toUtc();
    final aggregates = await _semanticStore.readAggregatedNodeVectors(
      nodeIds: graph.nodes.map((node) => node.id),
    );
    final stored = storedClusters.toList(growable: false);
    final linkWeight = minimumLinkWeight;
    return Isolate.run(
      () => _buildClusters(graph, aggregates, stored, now, linkWeight),
    );
  }

  Future<List<SemanticCluster>> cluster(
    PersonalKnowledgeGraph graph, {
    Iterable<SemanticCluster> storedClusters = const [],
  }) => build(graph, storedClusters: storedClusters);
}

List<SemanticCluster> _buildClusters(
  PersonalKnowledgeGraph graph,
  List<AggregatedNodeVector> aggregates,
  List<SemanticCluster> storedClusters,
  DateTime now,
  double minimumLinkWeight,
) {
  final activeNodes = {
    for (final node in graph.nodes)
      if (node.archivedAt == null) node.id: node,
  };
  if (activeNodes.length < 2) return const [];

  final vectors = {for (final item in aggregates) item.nodeId: item.vector};
  final adjacency = <String, Map<String, double>>{
    for (final id in activeNodes.keys) id: {},
  };
  final orderedEdges = graph.edges.toList()
    ..sort((left, right) {
      final source = left.sourceNodeId.compareTo(right.sourceNodeId);
      if (source != 0) return source;
      final target = left.targetNodeId.compareTo(right.targetNodeId);
      if (target != 0) return target;
      return left.id.compareTo(right.id);
    });
  for (final edge in orderedEdges) {
    if (edge.archivedAt != null ||
        !activeNodes.containsKey(edge.sourceNodeId) ||
        !activeNodes.containsKey(edge.targetNodeId) ||
        edge.sourceNodeId == edge.targetNodeId) {
      continue;
    }
    final leftVector = vectors[edge.sourceNodeId];
    final rightVector = vectors[edge.targetNodeId];
    final similarity = leftVector == null || rightVector == null
        ? null
        : _cosine(leftVector, rightVector);
    final topology = edge.weight.clamp(0.0, 1.0) * _edgeMultiplier(edge.type);
    if (similarity != null && similarity < 0.15 && topology < 0.85) continue;
    final semanticFactor = similarity == null
        ? 0.8
        : 0.6 + (0.4 * similarity.clamp(0.0, 1.0));
    final weight = topology * semanticFactor;
    if (weight < minimumLinkWeight) continue;
    _addWeight(adjacency, edge.sourceNodeId, edge.targetNodeId, weight);
    _addWeight(adjacency, edge.targetNodeId, edge.sourceNodeId, weight);
  }

  final linkedIds = adjacency.keys
      .where((id) => adjacency[id]!.isNotEmpty)
      .toSet();
  if (linkedIds.length < 2) return const [];

  final overrideClusters = _validOverrides(storedClusters, linkedIds);
  final reserved = overrideClusters.expand((item) => item.nodeIds).toSet();
  final remaining = linkedIds.difference(reserved);
  final groups = _communities(remaining, adjacency);
  final refinedGroups = groups
      .map((group) => _withoutOutliers(group, adjacency, vectors))
      .where((group) => group.length >= 2);
  final generated = <SemanticCluster>[
    for (final group in refinedGroups)
      _materialize(group, activeNodes, adjacency, vectors, now),
  ];

  final storedById = {for (final item in storedClusters) item.id: item};
  final result = <SemanticCluster>[
    for (final item in overrideClusters)
      _refreshOverride(item, activeNodes, adjacency, vectors, now),
    for (final item in generated)
      if (!storedById.containsKey(item.id))
        item
      else
        item.copyWith(
          title: storedById[item.id]!.title,
          summary: storedById[item.id]!.summary,
          pinned: storedById[item.id]!.pinned,
          userEdited: storedById[item.id]!.userEdited,
          updatedAt: storedById[item.id]!.updatedAt,
        ),
  ];
  result.sort((a, b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
    return a.id.compareTo(b.id);
  });
  return List.unmodifiable(result);
}

List<SemanticCluster> _validOverrides(
  Iterable<SemanticCluster> stored,
  Set<String> linkedIds,
) {
  final candidates =
      stored
          .where((item) => item.userEdited && item.nodeIds.length >= 2)
          .toList()
        ..sort((a, b) {
          final updated = b.updatedAt.compareTo(a.updatedAt);
          return updated != 0 ? updated : a.id.compareTo(b.id);
        });
  final used = <String>{};
  final result = <SemanticCluster>[];
  for (final item in candidates) {
    final ids = item.nodeIds.where(linkedIds.contains).toSet();
    if (ids.length < 2 || ids.any(used.contains)) continue;
    used.addAll(ids);
    result.add(item.copyWith(nodeIds: ids));
  }
  return result;
}

List<Set<String>> _communities(
  Set<String> ids,
  Map<String, Map<String, double>> adjacency,
) {
  final ordered = ids.toList()..sort();
  var labels = {for (final id in ordered) id: id};
  for (var pass = 0; pass < 24; pass++) {
    var changed = false;
    for (final id in ordered) {
      final neighbors =
          adjacency[id]!.entries
              .where((entry) => ids.contains(entry.key))
              .toList()
            ..sort((left, right) => left.key.compareTo(right.key));
      if (neighbors.isEmpty) continue;
      final scores = <String, double>{};
      var degree = 0.0;
      for (final neighbor in neighbors) {
        degree += neighbor.value;
        final label = labels[neighbor.key]!;
        scores[label] = (scores[label] ?? 0) + neighbor.value;
      }
      scores[labels[id]!] = (scores[labels[id]!] ?? 0) + (degree * 0.2);
      final ranked = scores.entries.toList()
        ..sort((a, b) {
          final score = b.value.compareTo(a.value);
          return score != 0 ? score : a.key.compareTo(b.key);
        });
      if (ranked.first.key != labels[id]) {
        labels[id] = ranked.first.key;
        changed = true;
      }
    }
    if (!changed) break;
  }
  final grouped = <String, Set<String>>{};
  for (final id in ordered) {
    grouped.putIfAbsent(labels[id]!, () => {}).add(id);
  }
  return grouped.values.where((group) => group.length >= 2).toList()..sort(
    (a, b) => (a.toList()..sort()).first.compareTo((b.toList()..sort()).first),
  );
}

Set<String> _withoutOutliers(
  Set<String> group,
  Map<String, Map<String, double>> adjacency,
  Map<String, List<double>> vectors,
) {
  if (group.length < 3) return group;
  final ordered = group.toList()..sort();
  final retained = <String>{};
  for (final id in ordered) {
    final vector = vectors[id];
    if (vector == null) {
      retained.add(id);
      continue;
    }
    var semanticTotal = 0.0;
    var semanticSamples = 0;
    var strongLinks = 0;
    for (final otherId in ordered) {
      if (otherId == id) continue;
      final other = vectors[otherId];
      if (other != null) {
        semanticTotal += _cosine(vector, other);
        semanticSamples++;
      }
      if ((adjacency[id]![otherId] ?? 0) >= 0.6) strongLinks++;
    }
    final semanticMean = semanticSamples == 0
        ? 1.0
        : semanticTotal / semanticSamples;
    if (semanticSamples >= 2 && semanticMean < 0.1 && strongLinks < 2) {
      continue;
    }
    retained.add(id);
  }
  return retained;
}

SemanticCluster _refreshOverride(
  SemanticCluster override,
  Map<String, GraphNode> nodes,
  Map<String, Map<String, double>> adjacency,
  Map<String, List<double>> vectors,
  DateTime now,
) {
  final calculated = _materialize(
    override.nodeIds.toSet(),
    nodes,
    adjacency,
    vectors,
    now,
  );
  return calculated.copyWith(
    id: override.id,
    title: override.title,
    category: override.category,
    summary: override.summary,
    pinned: override.pinned,
    updatedAt: override.updatedAt,
    userEdited: true,
  );
}

SemanticCluster _materialize(
  Set<String> ids,
  Map<String, GraphNode> nodes,
  Map<String, Map<String, double>> adjacency,
  Map<String, List<double>> vectors,
  DateTime now,
) {
  final ordered = ids.toList()..sort();
  final category = _category(ordered.map((id) => nodes[id]!.type));
  final labels = ordered.map((id) => nodes[id]!.label).toList()
    ..sort((a, b) {
      final folded = a.toLowerCase().compareTo(b.toLowerCase());
      return folded != 0 ? folded : a.compareTo(b);
    });
  final recent = ordered.where((id) {
    final date = nodes[id]!.createdAt;
    return !date.isBefore(now.subtract(const Duration(days: 30))) &&
        !date.isAfter(now);
  }).length;
  return SemanticCluster(
    id: stableGraphId('semantic-cluster', ordered),
    title: _title(category, labels),
    category: category,
    nodeIds: ordered,
    activityVelocity: recent / ordered.length,
    confidenceScore: _cohesion(ordered, adjacency, vectors),
    summary: labels.take(3).join(' · '),
    updatedAt: now,
  );
}

SemanticClusterCategory _category(Iterable<NodeType> types) {
  final scores = <SemanticClusterCategory, int>{};
  for (final type in types) {
    final category = switch (type) {
      NodeType.project ||
      NodeType.goal ||
      NodeType.actionItem ||
      NodeType.promise ||
      NodeType.decision ||
      NodeType.outcome => SemanticClusterCategory.project,
      NodeType.person ||
      NodeType.interaction => SemanticClusterCategory.peopleNetwork,
      NodeType.habit => SemanticClusterCategory.habitCluster,
      NodeType.belief ||
      NodeType.fear ||
      NodeType.identityShift => SemanticClusterCategory.belief,
      _ => SemanticClusterCategory.theme,
    };
    scores[category] = (scores[category] ?? 0) + 1;
  }
  final ranked = scores.entries.toList()
    ..sort((a, b) {
      final count = b.value.compareTo(a.value);
      if (count != 0) return count;
      return a.key.index.compareTo(b.key.index);
    });
  return ranked.first.key;
}

String _title(SemanticClusterCategory category, List<String> labels) {
  final prefix = switch (category) {
    SemanticClusterCategory.theme => 'Theme',
    SemanticClusterCategory.project => 'Project',
    SemanticClusterCategory.peopleNetwork => 'People',
    SemanticClusterCategory.habitCluster => 'Habits',
    SemanticClusterCategory.belief => 'Beliefs',
  };
  return '$prefix: ${labels.take(2).join(' & ')}';
}

double _cohesion(
  List<String> ids,
  Map<String, Map<String, double>> adjacency,
  Map<String, List<double>> vectors,
) {
  var total = 0.0;
  var pairs = 0;
  for (var left = 0; left < ids.length; left++) {
    for (var right = left + 1; right < ids.length; right++) {
      final graphWeight = adjacency[ids[left]]![ids[right]] ?? 0;
      final leftVector = vectors[ids[left]];
      final rightVector = vectors[ids[right]];
      final semantic = leftVector == null || rightVector == null
          ? graphWeight
          : _cosine(leftVector, rightVector).clamp(0.0, 1.0);
      total += (graphWeight * 0.65) + (semantic * 0.35);
      pairs++;
    }
  }
  return pairs == 0 ? 0 : (total / pairs).clamp(0.0, 1.0);
}

void _addWeight(
  Map<String, Map<String, double>> adjacency,
  String source,
  String target,
  double weight,
) {
  adjacency[source]![target] = math.min(
    1,
    (adjacency[source]![target] ?? 0) + weight,
  );
}

double _edgeMultiplier(EdgeType type) => switch (type) {
  EdgeType.mentionedWith => 0.8,
  EdgeType.contradictsBelief => 0.75,
  _ => 1,
};

double _cosine(List<double> left, List<double> right) {
  if (left.length != right.length || left.isEmpty) return 0;
  var dot = 0.0;
  var leftNorm = 0.0;
  var rightNorm = 0.0;
  for (var index = 0; index < left.length; index++) {
    dot += left[index] * right[index];
    leftNorm += left[index] * left[index];
    rightNorm += right[index] * right[index];
  }
  final denominator = math.sqrt(leftNorm) * math.sqrt(rightNorm);
  return denominator == 0 ? 0 : dot / denominator;
}
