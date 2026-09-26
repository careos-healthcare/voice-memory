import 'package:archiveme_mobile/features/history/history_browse.dart';
import 'package:flutter/material.dart';

class CalendarMonthView extends StatelessWidget {
  const CalendarMonthView({
    required this.month,
    required this.entries,
    required this.onDay,
    super.key,
  });

  final DateTime month;
  final List<HistoryMoment> entries;
  final ValueChanged<CalendarDaySummary> onDay;

  @override
  Widget build(BuildContext context) {
    final days = CalendarMonth.days(month: month, entries: entries);
    return GridView.count(
      key: const Key('calendar_month_view'),
      crossAxisCount: 7,
      children: [
        for (final day in days)
          if (day.day == 0)
            const SizedBox.shrink()
          else
            InkWell(
              key: Key('calendar_day_${day.day}'),
              onTap: () => onDay(day),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${day.day}'),
                  if (day.count > 0)
                    Container(
                      key: Key('calendar_mark_${day.day}'),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  if (day.count > 0)
                    Text(
                      '${day.count}',
                      key: Key('calendar_count_${day.day}'),
                    ),
                  if (day.moods.isNotEmpty)
                    Text(day.moods.first, key: Key('calendar_mood_${day.day}')),
                ],
              ),
            ),
      ],
    );
  }
}
