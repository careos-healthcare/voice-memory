import 'package:archiveme_mobile/features/history/history_browse.dart';
import 'package:flutter/material.dart';

/// One month of days, shaded by how much was recorded that day.
class CalendarMonthView extends StatelessWidget {
  const CalendarMonthView({
    required this.month,
    required this.entries,
    required this.onDay,
    this.compact = false,
    this.volumeCeiling,
    this.dayKeyPrefix = 'calendar_day_',
    super.key,
  });

  final DateTime month;
  final List<HistoryMoment> entries;
  final ValueChanged<CalendarDaySummary> onDay;
  final bool compact;
  final int? volumeCeiling;
  final String dayKeyPrefix;

  @override
  Widget build(BuildContext context) {
    final days = CalendarMonth.days(month: month, entries: entries);
    final ceiling =
        volumeCeiling ??
        CalendarHeatmap.ceiling(
          entries,
          year: month.year,
          month: month.month,
        );
    final primary = Theme.of(context).colorScheme.primary;
    return GridView.builder(
      key: Key(compact ? 'calendar_month_${month.month}' : 'calendar_month_view'),
      shrinkWrap: compact,
      physics: compact
          ? const NeverScrollableScrollPhysics()
          : const ClampingScrollPhysics(),
      padding: EdgeInsets.zero,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisExtent: compact ? 16 : 88,
        ),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        if (day.day == 0) return const SizedBox.shrink();
        final tier = CalendarHeatmap.tier(day.volume, ceiling);
        final shade = CalendarHeatmap.shade(primary, tier);
        final onShade = tier >= 3;
        return InkWell(
          key: Key('$dayKeyPrefix${day.day}'),
          onTap: () => onDay(day),
          child: Ink(
            key: Key(
              compact
                  ? 'calendar_heat_${month.month}_${day.day}'
                  : 'calendar_heat_${day.day}',
            ),
            decoration: BoxDecoration(
              color: shade,
              borderRadius: BorderRadius.circular(compact ? 2 : 6),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: compact ? 8 : 14,
                    color: onShade ? Colors.white : null,
                  ),
                ),
                if (!compact && day.count > 0)
                  Container(
                    key: Key('calendar_mark_${day.day}'),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: onShade
                          ? Colors.white
                          : Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                if (!compact && day.count > 0)
                  Text(
                    '${day.count}',
                    key: Key('calendar_count_${day.day}'),
                    style: TextStyle(color: onShade ? Colors.white : null),
                  ),
                if (!compact && day.moods.isNotEmpty)
                  Text(
                    day.moods.first,
                    key: Key('calendar_mood_${day.day}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: onShade ? Colors.white : null,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
