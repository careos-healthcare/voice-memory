import 'package:archiveme_mobile/design/locale_date_format.dart';
import 'package:archiveme_mobile/features/archive/views/calendar_month_view.dart';
import 'package:archiveme_mobile/features/archive/views/calendar_year_view.dart';
import 'package:archiveme_mobile/features/archive/views/on_this_day_view.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/widgets/archive/archive_entry_card.dart';
import 'package:flutter/material.dart';

enum CalendarScale { month, year }

/// Month or year calendar. Days are shaded by recording volume, never by a streak.
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
  var _scale = CalendarScale.month;

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
    final yearMode = _scale == CalendarScale.year;
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              key: const Key('calendar_previous_month'),
              onPressed: () => setState(() {
                _month = yearMode
                    ? DateTime(_month.year - 1, _month.month)
                    : DateTime(_month.year, _month.month - 1);
              }),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                yearMode
                    ? '${_month.year}'
                    : LocaleDateFormat.month(context, _month),
                key: const Key('calendar_month_label'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              key: const Key('calendar_next_month'),
              onPressed: () => setState(() {
                _month = yearMode
                    ? DateTime(_month.year + 1, _month.month)
                    : DateTime(_month.year, _month.month + 1);
              }),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SegmentedButton<CalendarScale>(
            key: const Key('calendar_scale_toggle'),
            segments: const [
              ButtonSegment(
                value: CalendarScale.month,
                label: Text('Month'),
              ),
              ButtonSegment(
                value: CalendarScale.year,
                label: Text('Year'),
              ),
            ],
            selected: {_scale},
            onSelectionChanged: (next) => setState(() => _scale = next.first),
          ),
        ),
        Expanded(
          child: yearMode
              ? CalendarYearView(
                  year: _month.year,
                  entries: moments,
                  onMonth: (month) => setState(() {
                    _month = DateTime(month.year, month.month);
                    _scale = CalendarScale.month;
                  }),
                  onDay: (month, day) => _openDay(
                    DateTime(month.year, month.month, day.day),
                  ),
                )
              : CalendarMonthView(
                  month: _month,
                  entries: moments,
                  onDay: (day) {
                    if (day.day == 0) return;
                    _openDay(DateTime(_month.year, _month.month, day.day));
                  },
                ),
        ),
      ],
    );
  }

  void _openDay(DateTime date) {
    final dated = widget.entries.where((entry) {
      return entry.createdAt.year == date.year &&
          entry.createdAt.month == date.month &&
          entry.createdAt.day == date.day;
    }).toList();
    if (dated.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.55,
            child: ListView(
              key: const Key('calendar_day_entries'),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                for (final entry in dated)
                  ArchiveEntryCard(
                    key: Key('calendar_entry_${entry.id}'),
                    entry: entry,
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onOpenEntry?.call(entry.id);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
