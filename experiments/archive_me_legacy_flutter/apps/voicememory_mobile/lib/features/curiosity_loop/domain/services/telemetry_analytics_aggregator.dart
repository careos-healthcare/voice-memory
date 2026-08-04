import '../../presentation/models/telemetry_data_point.dart';
import '../models/weekly_telemetry_summary.dart';
import 'cognitive_trajectory_evaluator.dart';

export '../models/weekly_telemetry_summary.dart';

class TelemetryAnalyticsAggregator {
  const TelemetryAnalyticsAggregator();

  /// Computes historical data arrays down into distinct 7-day down-regulation metrics.
  List<WeeklyTelemetrySummary> calculateWeeklyTrends(
    List<TelemetryDataPoint> history,
  ) {
    if (history.isEmpty) return [];

    // Sort chronologically
    final sortedHistory = List<TelemetryDataPoint>.from(history)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Group items by week boundary maps
    final Map<DateTime, List<TelemetryDataPoint>> weeklyGroups = {};

    for (final point in sortedHistory) {
      final weekStart = _startOfWeek(point.date);
      weeklyGroups.putIfAbsent(weekStart, () => []).add(point);
    }

    final List<WeeklyTelemetrySummary> summaries = [];

    weeklyGroups.forEach((weekStart, points) {
      final groundedPoints = points.where((p) => p.wasGrounded).toList();

      int successfulRegulations = 0;
      for (final gp in groundedPoints) {
        // Success is defined as landing on a safe (stagnant/improving) trajectory
        if (gp.direction == CognitiveDirection.stagnant ||
            gp.direction == CognitiveDirection.recovering) {
          successfulRegulations++;
        }
      }

      final successRate = groundedPoints.isEmpty
          ? 0.0
          : (successfulRegulations / groundedPoints.length) * 100.0;

      final totalLexical = points.fold<double>(
        0.0,
        (sum, p) => sum + p.lexicalDelta,
      );
      final totalDrift = points.fold<double>(
        0.0,
        (sum, p) => sum + p.driftDelta,
      );

      summaries.add(
        WeeklyTelemetrySummary(
          weekStartDate: weekStart,
          totalObservations: points.length,
          groundedInterventionsCount: groundedPoints.length,
          downRegulationSuccessRate: successRate,
          averageLexicalDelta: totalLexical / points.length,
          averageDriftDelta: totalDrift / points.length,
        ),
      );
    });

    return summaries
      ..sort((a, b) => b.weekStartDate.compareTo(a.weekStartDate));
  }

  DateTime _startOfWeek(DateTime date) {
    // Normalize date to its preceding Monday midnight layout boundary
    final normalized = DateTime.utc(date.year, date.month, date.day);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }
}
