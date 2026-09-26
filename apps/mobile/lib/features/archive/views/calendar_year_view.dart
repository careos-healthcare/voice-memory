import 'package:archiveme_mobile/features/archive/views/calendar_month_view.dart';
import 'package:archiveme_mobile/features/history/history_browse.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Twelve compact months for one year, using the same day shading as the month.
class CalendarYearView extends StatelessWidget {
  const CalendarYearView({
    required this.year,
    required this.entries,
    required this.onMonth,
    required this.onDay,
    super.key,
  });

  final int year;
  final List<HistoryMoment> entries;
  final ValueChanged<DateTime> onMonth;
  final void Function(DateTime month, CalendarDaySummary day) onDay;

  @override
  Widget build(BuildContext context) {
    final ceiling = CalendarHeatmap.ceiling(entries, year: year);
    final locale = Localizations.maybeLocaleOf(context)?.toString();
    return GridView.builder(
      key: const Key('calendar_year_view'),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.72,
        mainAxisSpacing: 12,
        crossAxisSpacing: 8,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        final month = DateTime(year, index + 1);
        final label = DateFormat.MMM(locale).format(month);
        return Column(
          children: [
            InkWell(
              key: Key('calendar_year_month_${index + 1}'),
              onTap: () => onMonth(month),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
            Expanded(
              child: CalendarMonthView(
                month: month,
                entries: entries,
                compact: true,
                volumeCeiling: ceiling,
                dayKeyPrefix: 'calendar_year_${index + 1}_day_',
                onDay: (day) => onDay(month, day),
              ),
            ),
          ],
        );
      },
    );
  }
}
