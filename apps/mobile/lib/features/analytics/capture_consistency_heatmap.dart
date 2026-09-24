import 'dart:async';

import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/analytics/capture_consistency.dart';
import 'package:archiveme_mobile/features/analytics/contribution_calendar.dart';
import 'package:archiveme_mobile/features/analytics/timeline_day_stats.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// GitHub-style grid of how many moments were saved each day.
class CaptureConsistencyHeatmap extends StatefulWidget {
  const CaptureConsistencyHeatmap({super.key, this.loadCounts, this.today});

  /// When omitted, counts are read from the open local database.
  final Future<Map<String, int>> Function()? loadCounts;

  final DateTime? today;

  @override
  State<CaptureConsistencyHeatmap> createState() =>
      _CaptureConsistencyHeatmapState();
}

class _CaptureConsistencyHeatmapState extends State<CaptureConsistencyHeatmap> {
  Map<String, int> _counts = const {};
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final counts = await (widget.loadCounts ?? _loadFromDatabase)();
      if (!mounted) return;
      setState(() => _counts = counts);
    } on Object catch (error, stackTrace) {
      AppLogger.debug(
        'Capture consistency counts skipped',
        name: 'capture_consistency',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(widget.today ?? DateTime.now());
    final layout = ContributionCalendarLayout(today: today, weekCount: 53);
    final streak = captureStreak(_counts, today);
    final selected = _selectedDay;
    final selectedCount = selected == null
        ? 0
        : (_counts[dayKey(selected)] ?? 0);
    return Column(
      key: const Key('capture_consistency_heatmap'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Capture consistency',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTokens.neutral900,
          ),
        ),
        const SizedBox(height: AppTokens.spacing1),
        Text(
          streak == 0
              ? 'Save a moment to start a streak.'
              : _streakLabel(streak),
          key: const Key('capture_consistency_streak'),
          style: const TextStyle(color: AppTokens.neutral600),
        ),
        const SizedBox(height: AppTokens.spacing3),
        SizedBox(
          height: layout.height,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: ContributionCalendar(
              key: const Key('capture_consistency_calendar'),
              days: _days(_counts),
              today: today,
              selectedDay: selected,
              onDayTap: (day) {
                setState(() {
                  final next = dateOnly(day);
                  _selectedDay = _selectedDay == next ? null : next;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: AppTokens.spacing2),
        const _VolumeLegend(),
        if (selected != null) ...[
          const SizedBox(height: AppTokens.spacing2),
          Text(
            _dayCaption(selected, selectedCount),
            key: const Key('capture_consistency_day'),
          ),
        ],
      ],
    );
  }
}

Future<Map<String, int>> _loadFromDatabase() {
  return CaptureConsistencyStore.dailyCounts(
    AppServices.instance.sqliteDatabase.database,
  );
}

Map<String, DayStats> _days(Map<String, int> counts) {
  return {
    for (final entry in counts.entries)
      if (entry.value > 0)
        entry.key: DayStats(
          day: DateTime.parse(entry.key),
          count: entry.value,
          meanSentiment: 0,
          entryIds: const [],
        ),
  };
}

String _streakLabel(int streak) =>
    streak == 1 ? '1 day in a row' : '$streak days in a row';

String _dayCaption(DateTime day, int count) {
  final moments = count == 1 ? 'moment' : 'moments';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '$count $moments on ${day.day} ${months[day.month - 1]}';
}

class _VolumeLegend extends StatelessWidget {
  const _VolumeLegend();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Text(
          'Fewer',
          style: TextStyle(fontSize: 12, color: AppTokens.neutral500),
        ),
        SizedBox(width: 6),
        _Swatch(color: AppTokens.neutral200),
        _Swatch(color: AppTokens.primary200),
        _Swatch(color: AppTokens.primary400),
        _Swatch(color: AppTokens.primary600),
        _Swatch(color: AppTokens.primary800),
        SizedBox(width: 6),
        Text(
          'More',
          style: TextStyle(fontSize: 12, color: AppTokens.neutral500),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 3),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
        child: const SizedBox(width: 12, height: 12),
      ),
    );
  }
}
