import 'dart:io';
import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph.dart';
import '../../core/graph/personal_knowledge_graph_store.dart';
import '../../models/journal_entry.dart';
import '../../storage/journal_store.dart';
import '../action_plans/action_plan_models.dart';
import '../action_plans/action_plan_store.dart';
import '../semantic_clusters/semantic_cluster_store.dart';
import 'burnout_detector.dart';
import 'cognitive_metrics_models.dart';

typedef ExternalCognitiveGraphLoader =
    Future<PersonalKnowledgeGraph> Function();

final class CognitiveMetricsIndex {
  CognitiveMetricsIndex._(this._database);

  final Database _database;

  static CognitiveMetricsIndex open(String path) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    final database = sqlite3.open(path)
      ..execute('PRAGMA journal_mode = WAL')
      ..execute('PRAGMA synchronous = FULL')
      ..execute('''
        CREATE TABLE IF NOT EXISTS cognitive_daily_metrics (
          day_ms INTEGER PRIMARY KEY,
          valence REAL,
          moving_7 REAL,
          moving_30 REAL,
          moving_90 REAL,
          cognitive_load REAL NOT NULL,
          semantic_velocity REAL NOT NULL,
          habit_momentum REAL NOT NULL,
          sleep_hours REAL,
          journal_count INTEGER NOT NULL,
          negative_cluster_density REAL NOT NULL,
          active_node_count INTEGER NOT NULL,
          resolved_cluster_count INTEGER NOT NULL
        )
      ''');
    return CognitiveMetricsIndex._(database);
  }

  void replace(Iterable<CognitiveMetricPoint> points) {
    _database.execute('BEGIN IMMEDIATE');
    try {
      _database.execute('DELETE FROM cognitive_daily_metrics');
      final statement = _database.prepare('''
        INSERT INTO cognitive_daily_metrics (
          day_ms, valence, moving_7, moving_30, moving_90,
          cognitive_load, semantic_velocity, habit_momentum, sleep_hours,
          journal_count, negative_cluster_density, active_node_count,
          resolved_cluster_count
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');
      try {
        for (final point in points) {
          statement.execute([
            point.day.millisecondsSinceEpoch,
            point.valence,
            point.movingAverage7,
            point.movingAverage30,
            point.movingAverage90,
            point.cognitiveLoad,
            point.semanticVelocity,
            point.habitMomentum,
            point.sleepHours,
            point.journalCount,
            point.negativeClusterDensity,
            point.activeNodeCount,
            point.resolvedClusterCount,
          ]);
        }
      } finally {
        statement.close();
      }
      _database.execute('COMMIT');
    } on Object {
      _database.execute('ROLLBACK');
      rethrow;
    }
  }

  List<CognitiveMetricPoint> query({DateTime? start}) {
    final rows = start == null
        ? _database.select(
            'SELECT * FROM cognitive_daily_metrics ORDER BY day_ms',
          )
        : _database.select(
            'SELECT * FROM cognitive_daily_metrics '
            'WHERE day_ms >= ? ORDER BY day_ms',
            [start.millisecondsSinceEpoch],
          );
    return rows.map(_pointFromRow).toList(growable: false);
  }

  void clear() => _database.execute('DELETE FROM cognitive_daily_metrics');
  void close() => _database.close();

  static CognitiveMetricPoint _pointFromRow(Row row) => CognitiveMetricPoint(
    day: DateTime.fromMillisecondsSinceEpoch(row['day_ms'] as int, isUtc: true),
    valence: (row['valence'] as num?)?.toDouble(),
    movingAverage7: (row['moving_7'] as num?)?.toDouble(),
    movingAverage30: (row['moving_30'] as num?)?.toDouble(),
    movingAverage90: (row['moving_90'] as num?)?.toDouble(),
    cognitiveLoad: (row['cognitive_load'] as num).toDouble(),
    semanticVelocity: (row['semantic_velocity'] as num).toDouble(),
    habitMomentum: (row['habit_momentum'] as num).toDouble(),
    sleepHours: (row['sleep_hours'] as num?)?.toDouble(),
    journalCount: row['journal_count'] as int,
    negativeClusterDensity: (row['negative_cluster_density'] as num).toDouble(),
    activeNodeCount: row['active_node_count'] as int,
    resolvedClusterCount: row['resolved_cluster_count'] as int,
  );
}

final class CognitiveMetricsEngine {
  CognitiveMetricsEngine({
    required this.journalStore,
    required this.graphStore,
    required this.clusterStore,
    required this.actionPlanStore,
    required this.index,
    this.externalGraphLoader,
    this.burnoutDetector = const BurnoutDetector(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final JournalStore journalStore;
  final PersonalKnowledgeGraphStore graphStore;
  final SemanticClusterStore clusterStore;
  final ActionPlanStore actionPlanStore;
  final CognitiveMetricsIndex index;
  final ExternalCognitiveGraphLoader? externalGraphLoader;
  final BurnoutDetector burnoutDetector;
  final DateTime Function() _clock;

  Future<CognitiveMetricsSnapshot> calculate(
    CognitiveTimeRange range, {
    bool refresh = true,
  }) async {
    if (refresh) await rebuild();
    final today = _day(_clock());
    final start = range.days == null
        ? null
        : today.subtract(Duration(days: range.days! - 1));
    final points = index.query(start: start);
    return CognitiveMetricsSnapshot(
      range: range,
      points: points,
      insights: LocalCognitiveInsightsSummarizer.summarize(points),
      advisory: burnoutDetector.evaluate(points),
    );
  }

  Future<void> rebuild() async {
    final entries = await journalStore.loadAll();
    final graph = await graphStore.load();
    final clusters = await clusterStore.list();
    final plans = await actionPlanStore.list();
    PersonalKnowledgeGraph external = PersonalKnowledgeGraph();
    try {
      external = await externalGraphLoader?.call() ?? external;
    } on Object {
      // Optional local connector state must not prevent the dashboard.
    }
    final nodes = [...graph.nodes, ...external.nodes];
    final today = _day(_clock());
    final dates = <DateTime>[
      ...entries.map((entry) => _day(entry.createdAt)),
      ...nodes.map((node) => _day(node.createdAt)),
      ...clusters
          .where((cluster) => cluster.updatedAt.millisecondsSinceEpoch > 0)
          .map((cluster) => _day(cluster.updatedAt)),
      ...plans.expand(
        (plan) => plan.steps.expand(
          (step) => step.completionHistory.keys
              .map(DateTime.tryParse)
              .whereType<DateTime>()
              .map(_day),
        ),
      ),
      today,
    ]..sort();
    final earliestAllowed = today.subtract(const Duration(days: 3650));
    final start = dates.first.isBefore(earliestAllowed)
        ? earliestAllowed
        : dates.first;
    final dailyEntries = <DateTime, List<JournalEntry>>{};
    for (final entry in entries) {
      dailyEntries.putIfAbsent(_day(entry.createdAt), () => []).add(entry);
    }
    final dailyValence = <double?>[];
    final days = <DateTime>[];
    for (
      var day = start;
      !day.isAfter(today);
      day = day.add(const Duration(days: 1))
    ) {
      days.add(day);
      final values = (dailyEntries[day] ?? const <JournalEntry>[])
          .map(sentimentForEntry)
          .toList();
      dailyValence.add(values.isEmpty ? null : _average(values));
    }
    final moving7 = movingAverage(dailyValence, 7);
    final moving30 = movingAverage(dailyValence, 30);
    final moving90 = movingAverage(dailyValence, 90);
    final points = <CognitiveMetricPoint>[];
    for (var index = 0; index < days.length; index++) {
      final day = days[index];
      final end = day.add(const Duration(days: 1));
      final activeNodes = nodes.where(
        (node) =>
            !node.createdAt.isAfter(day) &&
            (node.archivedAt == null || !node.archivedAt!.isBefore(end)) &&
            _isOpenLoop(node),
      );
      final visibleClusters = clusters.where(
        (cluster) => !cluster.updatedAt.isAfter(end),
      );
      final resolvedClusters = visibleClusters
          .where(
            (cluster) =>
                cluster.confidenceScore >= .75 &&
                cluster.activityVelocity <= .25,
          )
          .length;
      final activeCount = activeNodes.length;
      final cognitiveLoad =
          activeCount / max(1, activeCount + resolvedClusters * 2);
      final newConcepts = nodes
          .where(
            (node) =>
                !node.createdAt.isBefore(day) && node.createdAt.isBefore(end),
          )
          .length;
      final expanded = clusters
          .where(
            (cluster) =>
                !cluster.updatedAt.isBefore(day) &&
                cluster.updatedAt.isBefore(end),
          )
          .fold<int>(0, (sum, cluster) => sum + cluster.nodeIds.length);
      final semanticVelocity = 1 - exp(-(newConcepts + expanded / 3) / 4);
      final habitMomentum = _habitMomentum(plans, day);
      final clusterSentiments = visibleClusters
          .map(
            (cluster) =>
                sentimentForText('${cluster.title} ${cluster.summary}'),
          )
          .toList();
      final negativeDensity = clusterSentiments.isEmpty
          ? 0.0
          : clusterSentiments.where((score) => score <= -.2).length /
                clusterSentiments.length;
      points.add(
        CognitiveMetricPoint(
          day: day,
          valence: dailyValence[index],
          movingAverage7: moving7[index],
          movingAverage30: moving30[index],
          movingAverage90: moving90[index],
          cognitiveLoad: cognitiveLoad.clamp(0, 1),
          semanticVelocity: semanticVelocity.clamp(0, 1),
          habitMomentum: habitMomentum,
          sleepHours: _sleepHours(nodes, day),
          journalCount: dailyEntries[day]?.length ?? 0,
          negativeClusterDensity: negativeDensity,
          activeNodeCount: activeCount,
          resolvedClusterCount: resolvedClusters,
        ),
      );
    }
    index.replace(points);
  }

  static List<double?> movingAverage(List<double?> values, int window) {
    if (window < 1) throw ArgumentError.value(window, 'window');
    return [
      for (var index = 0; index < values.length; index++)
        _nullableAverage(
          values
              .skip(max(0, index - window + 1))
              .take(min(window, index + 1))
              .whereType<double>(),
        ),
    ];
  }

  static double sentimentForEntry(JournalEntry entry) {
    final reflection = entry.reflection;
    final text = [
      reflection.mood,
      entry.reflectionSummary,
      reflection.repeatedSignal,
      ...reflection.recurringThemes,
    ].join(' ');
    final score = sentimentForText(text);
    final intensity = reflection.emotionalIntensity.clamp(0, 10) / 10;
    return (score * (.65 + intensity * .35)).clamp(-1, 1);
  }

  static double sentimentForText(String text) {
    const positive = {
      'calm',
      'clear',
      'confident',
      'energized',
      'excited',
      'grateful',
      'happy',
      'hopeful',
      'joy',
      'proud',
      'relieved',
      'steady',
      'supported',
      'love',
      'progress',
      'good',
      'great',
    };
    const negative = {
      'angry',
      'anxious',
      'burned',
      'burnout',
      'confused',
      'depleted',
      'exhausted',
      'fear',
      'frustrated',
      'hopeless',
      'lonely',
      'overwhelmed',
      'sad',
      'stressed',
      'stuck',
      'tired',
      'worried',
      'bad',
    };
    final words = RegExp(
      r"[a-zA-Z']+",
    ).allMatches(text.toLowerCase()).map((match) => match.group(0)!);
    var positiveCount = 0;
    var negativeCount = 0;
    for (final word in words) {
      if (positive.contains(word)) positiveCount++;
      if (negative.contains(word)) negativeCount++;
    }
    final total = positiveCount + negativeCount;
    return total == 0 ? 0 : (positiveCount - negativeCount) / total;
  }

  static bool _isOpenLoop(GraphNode node) =>
      node.type == NodeType.actionItem ||
      node.type == NodeType.goal ||
      node.type == NodeType.habit ||
      node.type == NodeType.project ||
      node.type == NodeType.decision ||
      node.type == NodeType.promise;

  static double _habitMomentum(List<ActionPlan> plans, DateTime day) {
    var scheduled = 0;
    var completed = 0;
    var streakTotal = 0;
    var stepCount = 0;
    final key = canonicalActionPlanDate(day);
    for (final plan in plans.where(
      (plan) => plan.status == ActionPlanStatus.active,
    )) {
      for (final step in plan.steps) {
        if (!step.frequency.isScheduled(day)) continue;
        scheduled++;
        if (step.completionHistory[key] == true) completed++;
        streakTotal += step.streakCount;
        stepCount++;
      }
    }
    if (scheduled == 0) return 0;
    final completion = completed / scheduled;
    final streak = stepCount == 0
        ? 0.0
        : (streakTotal / stepCount / 14).clamp(0, 1);
    return (completion * .8 + streak * .2).clamp(0, 1);
  }

  static double? _sleepHours(List<GraphNode> nodes, DateTime day) {
    final sleepNodes = nodes.where(
      (node) =>
          node.externalSource == ExternalSource.appleHealth &&
          _day(node.createdAt) == day &&
          node.label.startsWith('Sleep:'),
    );
    for (final node in sleepNodes) {
      final match = RegExp(
        r'Sleep:\s*([0-9]+(?:\.[0-9]+)?)h',
      ).firstMatch(node.label);
      final value = double.tryParse(match?.group(1) ?? '');
      if (value != null) return value;
    }
    return null;
  }
}

final class LocalCognitiveInsightsSummarizer {
  const LocalCognitiveInsightsSummarizer._();

  static List<String> summarize(List<CognitiveMetricPoint> points) {
    if (points.isEmpty) {
      return const ['More local history is needed before trends can be shown.'];
    }
    final latest = points.last;
    final prior = points.length > 7 ? points[points.length - 8] : points.first;
    final insights = <String>[];
    final valenceDelta =
        (latest.movingAverage7 ?? latest.valence ?? 0) -
        (prior.movingAverage7 ?? prior.valence ?? 0);
    insights.add(
      valenceDelta.abs() < .08
          ? 'Emotional tone has been broadly steady in this range.'
          : valenceDelta > 0
          ? 'Recent emotional tone is moving in a more positive direction.'
          : 'Recent reflections carry more difficult emotional language.',
    );
    insights.add(
      latest.cognitiveLoad >= .7
          ? 'Open goals and commitments currently outweigh resolved clusters.'
          : 'The balance between open loops and resolved themes is manageable.',
    );
    insights.add(
      latest.semanticVelocity >= .55
          ? 'Concept formation is active, with new ideas joining the graph.'
          : 'Semantic growth is quiet, leaving more room for consolidation.',
    );
    if (latest.habitMomentum >= .6) {
      insights.add('Habit completion is supplying consistent momentum.');
    } else if (points.any((point) => point.habitMomentum > 0)) {
      insights.add(
        'Habit momentum has room for one intentionally small restart.',
      );
    }
    return List.unmodifiable(insights);
  }
}

DateTime _day(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

double _average(Iterable<double> values) {
  final list = values.toList();
  return list.reduce((left, right) => left + right) / list.length;
}

double? _nullableAverage(Iterable<double> values) {
  final list = values.toList();
  return list.isEmpty ? null : _average(list);
}
