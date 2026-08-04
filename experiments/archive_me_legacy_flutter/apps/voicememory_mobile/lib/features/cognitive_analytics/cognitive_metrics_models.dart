import 'dart:collection';

enum CognitiveTimeRange {
  week(7, 'Week'),
  month(30, 'Month'),
  year(365, 'Year'),
  allTime(null, 'All-Time');

  const CognitiveTimeRange(this.days, this.label);
  final int? days;
  final String label;
}

final class CognitiveMetricPoint {
  const CognitiveMetricPoint({
    required this.day,
    required this.valence,
    required this.movingAverage7,
    required this.movingAverage30,
    required this.movingAverage90,
    required this.cognitiveLoad,
    required this.semanticVelocity,
    required this.habitMomentum,
    required this.sleepHours,
    required this.journalCount,
    required this.negativeClusterDensity,
    required this.activeNodeCount,
    required this.resolvedClusterCount,
  });

  final DateTime day;
  final double? valence;
  final double? movingAverage7;
  final double? movingAverage30;
  final double? movingAverage90;
  final double cognitiveLoad;
  final double semanticVelocity;
  final double habitMomentum;
  final double? sleepHours;
  final int journalCount;
  final double negativeClusterDensity;
  final int activeNodeCount;
  final int resolvedClusterCount;
}

enum BurnoutRiskLevel { none, watch, elevated }

final class BurnoutAdvisory {
  const BurnoutAdvisory({
    required this.level,
    required this.title,
    required this.message,
    required this.reasons,
  });

  final BurnoutRiskLevel level;
  final String title;
  final String message;
  final List<String> reasons;
}

final class CognitiveMetricsSnapshot {
  CognitiveMetricsSnapshot({
    required this.range,
    required Iterable<CognitiveMetricPoint> points,
    required Iterable<String> insights,
    this.advisory,
  }) : points = UnmodifiableListView(points),
       insights = UnmodifiableListView(insights);

  final CognitiveTimeRange range;
  final List<CognitiveMetricPoint> points;
  final List<String> insights;
  final BurnoutAdvisory? advisory;

  CognitiveMetricPoint? get latest => points.lastOrNull;
}
