import 'dart:convert';

import 'package:archiveme_mobile/core/execution/isolate_compute_job.dart';
import 'package:archiveme_mobile/models/daily_check_in.dart';

/// One historical confidence step, dated so it can line up with a check-in.
final class BeliefChangeDelta {
  const BeliefChangeDelta({
    required this.dateString,
    required this.delta,
  });

  final String dateString;
  final int delta;
}

/// A private, on-device note about a habit and nearby shift size.
final class HabitBeliefInsight {
  const HabitBeliefInsight({
    required this.habit,
    required this.averageDelta,
    required this.sampleCount,
  });

  final String habit;
  final double averageDelta;
  final int sampleCount;

  String get summary {
    final signed = averageDelta >= 0
        ? '+${averageDelta.toStringAsFixed(1)}'
        : averageDelta.toStringAsFixed(1);
    return 'On days with $habit, shifts averaged $signed.';
  }
}

/// Compares daily habit pills with historical shift deltas on a background
/// isolate. Nothing leaves the device.
abstract final class CheckInBeliefCorrelationAnalyzer {
  CheckInBeliefCorrelationAnalyzer._();

  static const minimumSamples = 2;

  static List<BeliefChangeDelta> deltasFromConfidences(
    List<({String recordedAt, int confidence})> versions,
  ) {
    if (versions.length < 2) return const [];
    final deltas = <BeliefChangeDelta>[];
    for (var index = 1; index < versions.length; index++) {
      final current = versions[index];
      final previous = versions[index - 1];
      final parsed = DateTime.tryParse(current.recordedAt);
      if (parsed == null) continue;
      final utc = parsed.toUtc();
      final month = utc.month.toString().padLeft(2, '0');
      final day = utc.day.toString().padLeft(2, '0');
      deltas.add(
        BeliefChangeDelta(
          dateString: '${utc.year}-$month-$day',
          delta: current.confidence - previous.confidence,
        ),
      );
    }
    return deltas;
  }

  static Future<List<HabitBeliefInsight>> analyze({
    required List<DailyCheckIn> checkIns,
    required List<BeliefChangeDelta> deltas,
  }) async {
    final payload = <String, Object?>{
      'checkIns': [
        for (final checkIn in checkIns)
          <String, Object?>{
            'date': checkIn.dateString,
            'habits': _habitsOf(checkIn.habitsJson),
          },
      ],
      'deltas': [
        for (final delta in deltas)
          <String, Object?>{'date': delta.dateString, 'delta': delta.delta},
      ],
    };
    final rows =
        await IsolateComputeJob.run<
          Map<String, Object?>,
          List<Map<String, Object?>>
        >(
          label: 'check_in_belief_correlation',
          payload: payload,
          computeFn: correlateCheckInsWithBeliefDeltas,
        );
    return [
      for (final row in rows)
        HabitBeliefInsight(
          habit: row['habit']! as String,
          averageDelta: (row['averageDelta']! as num).toDouble(),
          sampleCount: row['sampleCount']! as int,
        ),
    ];
  }

  static List<String> _habitsOf(String habitsJson) {
    final decoded = jsonDecode(habitsJson);
    if (decoded is! List) return const [];
    return [
      for (final item in decoded)
        if (item is String && item.isNotEmpty) item,
    ];
  }
}

/// Top-level so IsolateComputeJob can send it to a background isolate.
List<Map<String, Object?>> correlateCheckInsWithBeliefDeltas(
  Map<String, Object?> payload,
) {
  final checkIns = payload['checkIns'];
  final deltas = payload['deltas'];
  if (checkIns is! List || deltas is! List) return const [];

  final deltaByDate = <String, int>{};
  for (final raw in deltas) {
    if (raw is! Map) continue;
    final date = raw['date'];
    final delta = raw['delta'];
    if (date is String && delta is int) {
      deltaByDate[date] = delta;
    }
  }

  final totals = <String, int>{};
  final counts = <String, int>{};
  for (final raw in checkIns) {
    if (raw is! Map) continue;
    final date = raw['date'];
    final habits = raw['habits'];
    if (date is! String || habits is! List) continue;
    final delta = deltaByDate[date];
    if (delta == null) continue;
    for (final habit in habits) {
      if (habit is! String || habit.isEmpty) continue;
      totals[habit] = (totals[habit] ?? 0) + delta;
      counts[habit] = (counts[habit] ?? 0) + 1;
    }
  }

  final insights = <Map<String, Object?>>[];
  final habits = totals.keys.toList()..sort();
  for (final habit in habits) {
    final count = counts[habit] ?? 0;
    if (count < CheckInBeliefCorrelationAnalyzer.minimumSamples) continue;
    insights.add({
      'habit': habit,
      'averageDelta': (totals[habit] ?? 0) / count,
      'sampleCount': count,
    });
  }
  return insights;
}
