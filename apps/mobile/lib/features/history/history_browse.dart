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
  });

  final String id;
  final DateTime createdAt;
  final String transcript;
  final String? mood;
  final String? place;
  final double? latitude;
  final double? longitude;
  final List<String> imagePaths;
}

/// Same month and day in earlier years. Matches
/// `strftime('%m-%d', created_at) = strftime('%m-%d', 'now')`.
abstract final class OnThisDayQuery {
  OnThisDayQuery._();

  static const sql =
      "WHERE strftime('%m-%d', created_at) = strftime('%m-%d', 'now')";

  static List<HistoryMoment> match(List<HistoryMoment> entries, DateTime now) {
    return [
      for (final entry in entries)
        if (entry.createdAt.month == now.month &&
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
  });

  final int day;
  final int count;
  final List<String> moods;
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
