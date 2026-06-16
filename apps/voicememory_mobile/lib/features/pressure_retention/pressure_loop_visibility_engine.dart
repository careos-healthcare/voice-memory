import 'pressure_check_in_option.dart';
import 'pressure_check_in_record.dart';
import 'pressure_loop_visibility_model.dart';

/// Computes simple, non-guilt loop-visibility metrics from local records.
class PressureLoopVisibilityEngine {
  const PressureLoopVisibilityEngine();

  PressureLoopVisibility build(
    List<PressureCheckInRecord> records, {
    DateTime? now,
  }) {
    if (records.isEmpty) return PressureLoopVisibility.empty;

    final reference = now ?? DateTime.now();
    final weekStart = reference.subtract(const Duration(days: 7));

    final week = records
        .where(
          (r) =>
              !r.createdAt.isBefore(weekStart) &&
              !r.createdAt.isAfter(reference),
        )
        .toList();

    final noticed = week.length;
    final stopped = week.where((r) => r.choseToStop).length;
    final strongest = _mostCommonOptionLabel(week);
    final streak = _streakDays(records, reference);

    return PressureLoopVisibility(
      noticedThisWeek: noticed,
      choseToStopCount: stopped,
      strongestPhrase: strongest,
      streakDays: streak,
    );
  }

  String? _mostCommonOptionLabel(List<PressureCheckInRecord> records) {
    if (records.isEmpty) return null;
    final counts = <String, int>{};
    for (final record in records) {
      final option = record.option;
      if (option == null) continue;
      counts[option.id] = (counts[option.id] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    String? topId;
    var topCount = 0;
    counts.forEach((id, count) {
      if (count > topCount) {
        topCount = count;
        topId = id;
      }
    });
    return PressureCheckInOption.fromId(topId)?.label;
  }

  int _streakDays(List<PressureCheckInRecord> records, DateTime reference) {
    final days = records
        .map(
          (r) => DateTime(r.createdAt.year, r.createdAt.month, r.createdAt.day),
        )
        .toSet();
    if (days.isEmpty) return 0;

    var cursor = DateTime(reference.year, reference.month, reference.day);
    // Allow the streak to "still count" if today has no entry yet but
    // yesterday did — never penalize a not-yet-logged today.
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    if (!days.contains(cursor)) return 0;

    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }
}
