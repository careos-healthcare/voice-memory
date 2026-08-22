import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_option.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_context.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_weekly_recap_model.dart';

/// Builds a weekly pressure recap from local entries in the last 7 days.
class PressureWeeklyRecapEngine {
  const PressureWeeklyRecapEngine();

  static const emptyCopy =
      'Log one pressure moment to start your weekly recap.';

  PressureWeeklyRecap build(
    List<PressureCheckInRecord> records, {
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final weekStart = reference.subtract(const Duration(days: 7));

    final week = records
        .where(
          (r) =>
              !r.createdAt.isBefore(weekStart) &&
              !r.createdAt.isAfter(reference),
        )
        .toList();

    final count = week.length;
    if (count == 0) {
      return const PressureWeeklyRecap(
        count: 0,
        mostCommonOptionLabel: null,
        mostCommonContextLabel: null,
        choseToStopCount: 0,
        sentence: emptyCopy,
      );
    }

    final optionLabel = _mostCommonOptionLabel(week);
    final contextLabel = _mostCommonContextLabel(week);
    final stopped = week.where((r) => r.choseToStop).length;

    return PressureWeeklyRecap(
      count: count,
      mostCommonOptionLabel: optionLabel,
      mostCommonContextLabel: contextLabel,
      choseToStopCount: stopped,
      sentence: _sentence(
        count: count,
        contextLabel: contextLabel,
        optionLabel: optionLabel,
      ),
    );
  }

  String _sentence({
    required int count,
    required String? contextLabel,
    required String? optionLabel,
  }) {
    // One moment is never enough to claim where pressure shows up "most".
    if (count == 1) {
      return 'One pressure moment logged this week. A few more will show what '
          'keeps repeating.';
    }
    if (contextLabel != null) {
      return 'This week, pressure showed up most around '
          '${contextLabel.toLowerCase()}.';
    }
    if (optionLabel != null) {
      return 'This week, pressure showed up most as "$optionLabel".';
    }
    return 'This week, pressure showed up $count times.';
  }

  String? _mostCommonOptionLabel(List<PressureCheckInRecord> records) {
    final counts = <String, int>{};
    for (final record in records) {
      final option = record.option;
      if (option == null) continue;
      counts[option.id] = (counts[option.id] ?? 0) + 1;
    }
    final topId = _topKeyWithMin(counts, 1);
    return PressureCheckInOption.fromId(topId)?.label;
  }

  String? _mostCommonContextLabel(List<PressureCheckInRecord> records) {
    final counts = <String, int>{};
    for (final record in records) {
      for (final context in record.contexts) {
        counts[context.id] = (counts[context.id] ?? 0) + 1;
      }
    }
    final topId = _topKeyWithMin(counts, 1);
    return PressureContext.fromId(topId)?.label;
  }

  String? _topKeyWithMin(Map<String, int> counts, int minCount) {
    String? topKey;
    var topCount = 0;
    counts.forEach((key, count) {
      if (count > topCount) {
        topCount = count;
        topKey = key;
      }
    });
    if (topCount < minCount) return null;
    return topKey;
  }
}