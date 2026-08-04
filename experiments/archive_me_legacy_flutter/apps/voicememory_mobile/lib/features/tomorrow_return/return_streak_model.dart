import 'tomorrow_commitment_model.dart';

/// Tracks consecutive days the user completed the return loop.
class ReturnStreak {
  const ReturnStreak({
    required this.currentStreakDays,
    required this.longestStreakDays,
    required this.completedDates,
    required this.headline,
    required this.body,
    this.lastCompletedDate,
  });

  final int currentStreakDays;
  final int longestStreakDays;
  final DateTime? lastCompletedDate;
  final List<DateTime> completedDates;
  final String headline;
  final String body;

  bool get showOnPatterns => currentStreakDays >= 2;
  bool get showOnRecordPostSave => currentStreakDays >= 2;

  Map<String, dynamic> toJson() => {
    'currentStreakDays': currentStreakDays,
    'longestStreakDays': longestStreakDays,
    'completedDates': completedDates
        .map((d) => TomorrowCommitment.dateOnly(d).toIso8601String())
        .toList(),
    'headline': headline,
    'body': body,
    if (lastCompletedDate != null)
      'lastCompletedDate': TomorrowCommitment.dateOnly(
        lastCompletedDate!,
      ).toIso8601String(),
  };

  static ReturnStreak? fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return null;
    final datesRaw = json['completedDates'];
    if (datesRaw is! List) return null;
    final dates = <DateTime>[];
    for (final item in datesRaw) {
      final parsed = DateTime.tryParse(item.toString());
      if (parsed != null) {
        dates.add(TomorrowCommitment.dateOnly(parsed));
      }
    }
    if (dates.isEmpty) return null;

    DateTime? lastCompleted;
    final lastRaw = json['lastCompletedDate']?.toString();
    if (lastRaw != null) {
      lastCompleted = DateTime.tryParse(lastRaw);
    }

    return ReturnStreak(
      currentStreakDays: (json['currentStreakDays'] as num?)?.toInt() ?? 0,
      longestStreakDays: (json['longestStreakDays'] as num?)?.toInt() ?? 0,
      lastCompletedDate: lastCompleted,
      completedDates: dates,
      headline: json['headline']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
    );
  }

  static List<DateTime> uniqueSortedDates(List<DateTime> dates) {
    final set = dates.map(TomorrowCommitment.dateOnly).toSet().toList()..sort();
    return set;
  }

  static int currentStreakFromDates(List<DateTime> dates, DateTime now) {
    final sorted = uniqueSortedDates(dates);
    if (sorted.isEmpty) return 0;
    final today = TomorrowCommitment.dateOnly(now);
    var cursor = sorted.contains(today) ? today : sorted.last;
    if (!sorted.contains(cursor)) return 0;

    var streak = 0;
    while (sorted.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static int longestStreakFromDates(List<DateTime> dates) {
    final sorted = uniqueSortedDates(dates);
    if (sorted.isEmpty) return 0;
    var best = 1;
    var run = 1;
    for (var i = 1; i < sorted.length; i++) {
      final gap = sorted[i].difference(sorted[i - 1]).inDays;
      if (gap == 1) {
        run++;
        if (run > best) best = run;
      } else {
        run = 1;
      }
    }
    return best;
  }
}
