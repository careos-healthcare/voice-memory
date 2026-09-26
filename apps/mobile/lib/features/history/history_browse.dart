import 'package:flutter/material.dart';

class HistoryMoment {
  const HistoryMoment({
    required this.id,
    required this.createdAt,
    required this.transcript,
    this.mood,
    this.place,
    this.latitude,
    this.longitude,
    this.imagePaths = const [],
    this.audioPath,
    this.durationSeconds = 0,
  });

  final String id;
  final DateTime createdAt;
  final String transcript;
  final String? mood;
  final String? place;
  final double? latitude;
  final double? longitude;
  final List<String> imagePaths;
  final String? audioPath;
  final int durationSeconds;

  /// Recording length in minutes. An entry without audio does not shade a day.
  int get volume {
    if (durationSeconds <= 0) return 0;
    return (durationSeconds + 59) ~/ 60;
  }
}

/// Same month and day in earlier years. Matches
/// `strftime('%m-%d', created_at) = strftime('%m-%d', 'now')`.
abstract final class OnThisDayQuery {
  OnThisDayQuery._();

  /// Same month and day in earlier years, skipping memories hidden from this view.
  static const sql =
      "WHERE strftime('%m-%d', created_at) = strftime('%m-%d', 'now') "
      'AND is_silenced_from_on_this_day = 0';

  static List<HistoryMoment> match(
    List<HistoryMoment> entries,
    DateTime now, {
    Set<String> silencedIds = const {},
  }) {
    return [
      for (final entry in entries)
        if (!silencedIds.contains(entry.id) &&
            entry.createdAt.month == now.month &&
            entry.createdAt.day == now.day &&
            entry.createdAt.year < now.year)
          entry,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}

class CalendarDaySummary {
  const CalendarDaySummary({
    required this.day,
    required this.count,
    required this.moods,
    this.volume = 0,
  });

  final int day;
  final int count;
  final List<String> moods;
  final int volume;
}

/// Four shades of the primary color. An empty day stays unshaded.
abstract final class CalendarHeatmap {
  CalendarHeatmap._();

  static const opacities = <double>[0.2, 0.45, 0.7, 1];

  static int tier(int volume, int ceiling) {
    if (volume <= 0 || ceiling <= 0) return 0;
    final ratio = volume / ceiling;
    if (ratio <= 0.25) return 1;
    if (ratio <= 0.5) return 2;
    if (ratio <= 0.75) return 3;
    return 4;
  }

  static Color shade(Color primary, int tier) {
    if (tier <= 0 || tier > opacities.length) return const Color(0x00000000);
    return primary.withValues(alpha: opacities[tier - 1]);
  }

  static int ceiling(
    List<HistoryMoment> entries, {
    int? year,
    int? month,
  }) {
    final totals = <int, int>{};
    for (final entry in entries) {
      if (year != null && entry.createdAt.year != year) continue;
      if (month != null && entry.createdAt.month != month) continue;
      final key = entry.createdAt.month * 100 + entry.createdAt.day;
      totals[key] = (totals[key] ?? 0) + entry.volume;
    }
    var max = 0;
    for (final value in totals.values) {
      if (value > max) max = value;
    }
    return max;
  }
}

abstract final class CalendarMonth {
  CalendarMonth._();

  static List<CalendarDaySummary> days({
    required DateTime month,
    required List<HistoryMoment> entries,
  }) {
    final length = DateTime(month.year, month.month + 1, 0).day;
    final leading = DateTime(month.year, month.month, 1).weekday % 7;
    return [
      for (var blank = 0; blank < leading; blank++)
        const CalendarDaySummary(day: 0, count: 0, moods: []),
      for (var day = 1; day <= length; day++)
        CalendarDaySummary(
          day: day,
          count: entries
              .where(
                (entry) =>
                    entry.createdAt.year == month.year &&
                    entry.createdAt.month == month.month &&
                    entry.createdAt.day == day,
              )
              .length,
          volume: entries
              .where(
                (entry) =>
                    entry.createdAt.year == month.year &&
                    entry.createdAt.month == month.month &&
                    entry.createdAt.day == day,
              )
              .fold(0, (sum, entry) => sum + entry.volume),
          moods: [
            for (final entry in entries)
              if (entry.createdAt.year == month.year &&
                  entry.createdAt.month == month.month &&
                  entry.createdAt.day == day &&
                  (entry.mood?.trim().isNotEmpty ?? false))
                entry.mood!.trim(),
          ],
        ),
    ];
  }
}
