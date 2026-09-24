import 'package:archiveme_mobile/features/analytics/timeline_day_stats.dart';
import 'package:archiveme_mobile/features/habits/habit_tracker_service.dart';

/// Consistency, streak, and tone for one rolling window.
class GoalVelocityWindow {
  const GoalVelocityWindow({
    required this.days,
    required this.consistency,
    required this.weeklyStreak,
    required this.perWeek,
    required this.priorPerWeek,
    required this.weeklyCounts,
    required this.recentDays,
    required this.completedSentiment,
    required this.missedSentiment,
    required this.entryIds,
  });

  final int days;
  final double consistency;
  final int weeklyStreak;
  final double perWeek;
  final double priorPerWeek;
  final List<int> weeklyCounts;
  final List<bool> recentDays;
  final double? completedSentiment;
  final double? missedSentiment;
  final List<String> entryIds;

  double get velocityDelta => perWeek - priorPerWeek;
}

/// Rolling habit math over 30-day and 90-day windows.
abstract final class GoalVelocityCalculator {
  static GoalVelocityWindow window({
    required Habit habit,
    required List<HabitLog> logs,
    required Map<DateTime, double> sentimentByDay,
    required DateTime now,
    required int days,
  }) {
    final today = dateOnly(now);
    final start = today.subtract(Duration(days: days - 1));
    final habitStart = dateOnly(habit.createdAt);
    final from = habitStart.isAfter(start) ? habitStart : start;
    final span = today.difference(from).inDays + 1;
    final inWindow = logs.where((log) {
      final day = dateOnly(log.loggedAt);
      return !day.isBefore(from) && !day.isAfter(today);
    }).toList();
    final complete = _completeDays(habit, inWindow);
    final expected = span < 1 ? 1 : span;
    final consistency = (complete.length / expected).clamp(0, 1).toDouble();
    final perWeek = span <= 0 ? 0.0 : inWindow.length / (span / 7);
    final priorStart = from.subtract(Duration(days: days));
    final priorEnd = from.subtract(const Duration(days: 1));
    final priorCount = logs.where((log) {
      final day = dateOnly(log.loggedAt);
      return !day.isBefore(priorStart) && !day.isAfter(priorEnd);
    }).length;
    final priorPerWeek = priorCount / (days / 7);
    final completedScores = <double>[];
    final missedScores = <double>[];
    for (final entry in sentimentByDay.entries) {
      final day = dateOnly(entry.key);
      if (day.isBefore(from) || day.isAfter(today)) continue;
      if (complete.contains(day)) {
        completedScores.add(entry.value);
      } else {
        missedScores.add(entry.value);
      }
    }
    return GoalVelocityWindow(
      days: days,
      consistency: consistency,
      weeklyStreak: _weeklyStreak(habit, logs, today),
      perWeek: perWeek,
      priorPerWeek: priorPerWeek,
      weeklyCounts: _weeklyCounts(inWindow, from, today),
      recentDays: [
        for (var offset = 27; offset >= 0; offset--)
          complete.contains(today.subtract(Duration(days: offset))),
      ],
      completedSentiment: _mean(completedScores),
      missedSentiment: _mean(missedScores),
      entryIds: [
        for (final log in inWindow)
          if (log.entryId != null) log.entryId!,
      ],
    );
  }

  static ({GoalVelocityWindow days30, GoalVelocityWindow days90}) report({
    required Habit habit,
    required List<HabitLog> logs,
    required Map<DateTime, double> sentimentByDay,
    required DateTime now,
  }) {
    return (
      days30: window(
        habit: habit,
        logs: logs,
        sentimentByDay: sentimentByDay,
        now: now,
        days: 30,
      ),
      days90: window(
        habit: habit,
        logs: logs,
        sentimentByDay: sentimentByDay,
        now: now,
        days: 90,
      ),
    );
  }

  /// Tone of a moment, matching the timeline heatmap.
  static double sentimentOf(String transcript) => entrySentiment(transcript);

  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static Set<DateTime> _completeDays(Habit habit, List<HabitLog> logs) {
    final counts = <DateTime, int>{};
    for (final log in logs) {
      final day = dateOnly(log.loggedAt);
      counts[day] = (counts[day] ?? 0) + 1;
    }
    if (habit.frequency == HabitFrequency.weekly) {
      return counts.keys.toSet();
    }
    return counts.entries
        .where((entry) => entry.value >= habit.targetCount)
        .map((entry) => entry.key)
        .toSet();
  }

  static int _weeklyStreak(Habit habit, List<HabitLog> logs, DateTime today) {
    var streak = 0;
    var weekStart = today.subtract(Duration(days: today.weekday - 1));
    for (var guard = 0; guard < 104; guard++) {
      final weekEnd = weekStart.add(const Duration(days: 6));
      final count = logs.where((log) {
        final day = dateOnly(log.loggedAt);
        return !day.isBefore(weekStart) && !day.isAfter(weekEnd);
      }).length;
      if (count < habit.targetCount) {
        if (guard == 0) {
          weekStart = weekStart.subtract(const Duration(days: 7));
          continue;
        }
        break;
      }
      streak += 1;
      weekStart = weekStart.subtract(const Duration(days: 7));
    }
    return streak;
  }

  static List<int> _weeklyCounts(
    List<HabitLog> logs,
    DateTime from,
    DateTime today,
  ) {
    final counts = <int>[];
    var cursor = from;
    while (!cursor.isAfter(today)) {
      final end = cursor.add(const Duration(days: 6));
      final capped = end.isAfter(today) ? today : end;
      counts.add(
        logs.where((log) {
          final day = dateOnly(log.loggedAt);
          return !day.isBefore(cursor) && !day.isAfter(capped);
        }).length,
      );
      cursor = capped.add(const Duration(days: 1));
    }
    return counts;
  }

  static double? _mean(List<double> values) {
    if (values.isEmpty) return null;
    var total = 0.0;
    for (final value in values) {
      total += value;
    }
    return total / values.length;
  }
}
