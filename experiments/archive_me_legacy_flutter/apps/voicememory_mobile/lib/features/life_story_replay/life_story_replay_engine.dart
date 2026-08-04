import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph_store.dart';
import '../life_simulator/life_simulator_models.dart';
import '../life_simulator/life_simulator_store.dart';
import '../semantic_clusters/semantic_cluster_store.dart';
import 'life_story_models.dart';

final class LifeStoryReplayIndex {
  LifeStoryReplayIndex._(this._database);

  final Database _database;

  static LifeStoryReplayIndex open(String path) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    final database = sqlite3.open(path)
      ..execute('PRAGMA journal_mode = WAL')
      ..execute('PRAGMA synchronous = FULL')
      ..execute('''
        CREATE TABLE IF NOT EXISTS life_story_points (
          id TEXT PRIMARY KEY,
          kind TEXT NOT NULL,
          occurred_at INTEGER NOT NULL,
          significance REAL NOT NULL,
          sentiment REAL NOT NULL,
          node_ids TEXT NOT NULL,
          cluster_ids TEXT NOT NULL,
          projected INTEGER NOT NULL
        )
      ''')
      ..execute(
        'CREATE INDEX IF NOT EXISTS life_story_points_time '
        'ON life_story_points(occurred_at, id)',
      );
    return LifeStoryReplayIndex._(database);
  }

  void replace(Iterable<LifeStoryPoint> points) {
    _database.execute('BEGIN IMMEDIATE');
    try {
      _database.execute('DELETE FROM life_story_points');
      final insert = _database.prepare('''
        INSERT INTO life_story_points (
          id, kind, occurred_at, significance, sentiment,
          node_ids, cluster_ids, projected
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''');
      try {
        for (final point in points) {
          insert.execute([
            point.id,
            point.kind.name,
            point.timestamp.millisecondsSinceEpoch,
            point.significance,
            point.sentiment,
            jsonEncode(point.nodeIds),
            jsonEncode(point.clusterIds),
            point.projected ? 1 : 0,
          ]);
        }
      } finally {
        insert.close();
      }
      _database.execute('COMMIT');
    } on Object {
      _database.execute('ROLLBACK');
      rethrow;
    }
  }

  List<LifeStoryPoint> chronological() => _database
      .select(
        'SELECT * FROM life_story_points ORDER BY occurred_at ASC, id ASC',
      )
      .map(
        (row) => LifeStoryPoint(
          id: row['id'] as String,
          kind: LifeStoryPointKind.values.byName(row['kind'] as String),
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            row['occurred_at'] as int,
            isUtc: true,
          ),
          significance: row['significance'] as num,
          sentiment: row['sentiment'] as num,
          nodeIds: (jsonDecode(row['node_ids'] as String) as List)
              .whereType<String>(),
          clusterIds: (jsonDecode(row['cluster_ids'] as String) as List)
              .whereType<String>(),
          projected: row['projected'] == 1,
        ),
      )
      .toList(growable: false);

  void clear() => _database.execute('DELETE FROM life_story_points');
  void close() => _database.close();
}

final class LifeStoryReplayEngine {
  LifeStoryReplayEngine({
    required this.graphStore,
    required this.clusterStore,
    required this.simulatorStore,
    required this.index,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final PersonalKnowledgeGraphStore graphStore;
  final SemanticClusterStore clusterStore;
  final LifeSimulatorStore simulatorStore;
  final LifeStoryReplayIndex index;
  final DateTime Function() _clock;

  Future<LifeStoryTimeline> generate() async {
    final graph = await graphStore.load();
    final clusters = await clusterStore.list();
    final scenarios = await simulatorStore.list();
    final points = <LifeStoryPoint>[];
    final sentimentByNode = <String, List<double>>{};
    final edgeCountByNode = <String, int>{};
    for (final edge in graph.edges) {
      edgeCountByNode[edge.sourceNodeId] =
          (edgeCountByNode[edge.sourceNodeId] ?? 0) + 1;
      edgeCountByNode[edge.targetNodeId] =
          (edgeCountByNode[edge.targetNodeId] ?? 0) + 1;
      final sentiment = edge.emotionalValenceScore ?? 0;
      sentimentByNode.putIfAbsent(edge.sourceNodeId, () => []).add(sentiment);
      sentimentByNode.putIfAbsent(edge.targetNodeId, () => []).add(sentiment);
      points.add(
        LifeStoryPoint(
          id: 'edge-${edge.id}',
          kind: LifeStoryPointKind.relationship,
          timestamp: edge.interactionDate ?? edge.createdAt,
          significance: max(edge.weight, edge.intensity ?? 0),
          sentiment: sentiment,
          nodeIds: [edge.sourceNodeId, edge.targetNodeId],
        ),
      );
    }
    for (final node in graph.nodes) {
      final sentiments = sentimentByNode[node.id] ?? const [];
      final sentiment = sentiments.isEmpty
          ? 0.0
          : sentiments.reduce((left, right) => left + right) /
                sentiments.length;
      final identityShift = node.type == NodeType.identityShift;
      points.add(
        LifeStoryPoint(
          id: 'node-${node.id}',
          kind: identityShift
              ? LifeStoryPointKind.identityShift
              : LifeStoryPointKind.node,
          timestamp: node.createdAt,
          significance: identityShift
              ? 1
              : (node.confidence * .7 +
                    min(edgeCountByNode[node.id] ?? 0, 6) / 20),
          sentiment: sentiment,
          nodeIds: [node.id],
        ),
      );
    }
    for (final cluster in clusters) {
      if (cluster.updatedAt.millisecondsSinceEpoch <= 0) continue;
      points.add(
        LifeStoryPoint(
          id: 'cluster-${cluster.id}',
          kind: LifeStoryPointKind.semanticCluster,
          timestamp: cluster.updatedAt,
          significance:
              cluster.confidenceScore * .55 +
              cluster.activityVelocity * .3 +
              min(cluster.nodeIds.length, 10) / 70,
          sentiment: 0,
          nodeIds: cluster.nodeIds,
          clusterIds: [cluster.id],
        ),
      );
    }
    final trajectories = <String, SimulationTrajectory>{};
    for (final scenario in scenarios) {
      trajectories[scenario.continueTrajectory.id] =
          scenario.continueTrajectory;
      trajectories[scenario.alternativeTrajectory.id] =
          scenario.alternativeTrajectory;
    }
    for (final trajectory in trajectories.values) {
      for (final milestone in trajectory.milestones) {
        final nodeIds = trajectory.target.kind == SimulationTargetKind.graphNode
            ? [trajectory.target.referenceId, ...milestone.affectedNodeIds]
            : milestone.affectedNodeIds;
        final clusterIds =
            trajectory.target.kind == SimulationTargetKind.semanticCluster
            ? [trajectory.target.referenceId]
            : const <String>[];
        points.add(
          LifeStoryPoint(
            id: 'simulation-${trajectory.id}-${milestone.days}',
            kind: LifeStoryPointKind.simulationMilestone,
            timestamp: trajectory.generatedAt.add(
              Duration(days: milestone.days),
            ),
            significance:
                milestone.projectedConfidence * .7 +
                milestone.stressImpactScore.abs() * .3,
            sentiment: -milestone.stressImpactScore,
            nodeIds: nodeIds,
            clusterIds: clusterIds,
            projected: true,
          ),
        );
      }
    }

    index.replace(points);
    final chronological = index.chronological();
    final chapters = segmentChapters(chronological);
    return LifeStoryTimeline(
      id: 'life-story-${_clock().toUtc().millisecondsSinceEpoch}',
      points: chronological,
      chapters: chapters,
      generatedAt: _clock(),
    );
  }

  List<LifeStoryChapter> segmentChapters(List<LifeStoryPoint> sortedPoints) {
    if (sortedPoints.isEmpty) return const [];
    final segments = <List<LifeStoryPoint>>[];
    var current = <LifeStoryPoint>[];
    for (final point in sortedPoints) {
      final previous = current.lastOrNull;
      final gap = previous == null
          ? Duration.zero
          : point.timestamp.difference(previous.timestamp);
      final boundary =
          current.length >= 3 &&
          (gap >= const Duration(days: 120) ||
              point.kind == LifeStoryPointKind.identityShift ||
              (point.significance >= .92 && current.length >= 5) ||
              current.length >= 12);
      if (boundary) {
        segments.add(current);
        current = <LifeStoryPoint>[];
      }
      current.add(point);
    }
    if (current.isNotEmpty) segments.add(current);
    return [
      for (var index = 0; index < segments.length; index++)
        LifeStoryChapter(
          id: 'chapter-${index + 1}',
          title: _chapterTitle(segments[index], index, segments.length),
          ordinal: index,
          start: segments[index].first.timestamp,
          end: segments[index].last.timestamp,
          points: segments[index],
        ),
    ];
  }

  String _chapterTitle(List<LifeStoryPoint> points, int index, int count) {
    if (index == 0) return 'Genesis';
    if (points.any((point) => point.kind == LifeStoryPointKind.identityShift)) {
      return 'The Great Pivot';
    }
    if (index == count - 1 &&
        points.any(
          (point) => point.kind == LifeStoryPointKind.simulationMilestone,
        )) {
      return 'The Horizon Ahead';
    }
    final density = points.expand((point) => point.nodeIds).toSet().length;
    if (density >= 7) return 'Expansion & Convergence';
    const titles = [
      'Emergence',
      'Acceleration',
      'Reorientation',
      'Integration',
    ];
    return titles[(index - 1) % titles.length];
  }
}
