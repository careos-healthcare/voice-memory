import 'package:archiveme_mobile/core/database/database_provider.dart';
import 'package:archiveme_mobile/design/locale_date_format.dart';
import 'package:archiveme_mobile/features/archive/views/on_this_day_view.dart';
import 'package:archiveme_mobile/features/history/history_browse.dart';
import 'package:archiveme_mobile/features/history/history_views.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:flutter/material.dart';

/// Month grid. Days with a saved moment show a mark, and a tap lists that day.
class CalendarView extends StatefulWidget {
  const CalendarView({
    required this.entries,
    this.now,
    this.onOpenEntry,
    super.key,
  });

  final List<JournalEntry> entries;
  final DateTime? now;
  final ValueChanged<String>? onOpenEntry;

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = widget.now ?? DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final moments = [
      for (final entry in widget.entries) historyMomentFromEntry(entry),
    ];
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              key: const Key('calendar_previous_month'),
              onPressed: () => setState(() {
                _month = DateTime(_month.year, _month.month - 1);
              }),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                LocaleDateFormat.month(context, _month),
                key: const Key('calendar_month_label'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              key: const Key('calendar_next_month'),
              onPressed: () => setState(() {
                _month = DateTime(_month.year, _month.month + 1);
              }),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Expanded(
          child: CalendarMonthView(
            month: _month,
            entries: moments,
            onDay: (day) => _openDay(day, moments),
          ),
        ),
      ],
    );
  }

  void _openDay(CalendarDaySummary day, List<HistoryMoment> moments) {
    if (day.day == 0 || day.count == 0) return;
    final dated = moments.where((entry) {
      return entry.createdAt.year == _month.year &&
          entry.createdAt.month == _month.month &&
          entry.createdAt.day == day.day;
    }).toList();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return ListView(
          key: const Key('calendar_day_entries'),
          children: [
            for (final entry in dated)
              ListTile(
                key: Key('calendar_entry_${entry.id}'),
                title: Text(
                  shortVerbatimQuote(entry.transcript, maxChars: 120),
                ),
                subtitle: Text(LocaleDateFormat.date(context, entry.createdAt)),
                onTap: widget.onOpenEntry == null
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        widget.onOpenEntry!(entry.id);
                      },
              ),
          ],
        );
      },
    );
  }
}
