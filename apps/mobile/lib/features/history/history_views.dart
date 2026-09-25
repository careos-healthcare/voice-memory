import 'package:archiveme_mobile/features/history/history_browse.dart';
import 'package:flutter/material.dart';

class OnThisDayView extends StatelessWidget {
  const OnThisDayView({required this.entries, required this.now, super.key});

  final List<HistoryMoment> entries;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final matches = OnThisDayQuery.match(entries, now);
    return ListView(
      key: const Key('on_this_day_view'),
      children: [
        if (matches.isEmpty)
          const ListTile(title: Text('Nothing from this day in earlier years.'))
        else
          for (final entry in matches)
            ListTile(
              key: Key('on_this_day_${entry.id}'),
              title: Text(entry.transcript),
              subtitle: Text('${entry.createdAt.year}'),
            ),
      ],
    );
  }
}

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
          InkWell(
            key: Key('calendar_day_${day.day}'),
            onTap: () => onDay(day),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${day.day}'),
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
