import 'package:archiveme_mobile/features/export/book_exporter.dart';
import 'package:archiveme_mobile/features/history/history_browse.dart';
import 'package:archiveme_mobile/features/history/history_views.dart';
import 'package:archiveme_mobile/features/map/entry_map.dart';
import 'package:archiveme_mobile/features/map/entry_map_view.dart';
import 'package:flutter/material.dart';

class HistoryHub extends StatefulWidget {
  const HistoryHub({required this.entries, super.key});

  final List<HistoryMoment> entries;

  @override
  State<HistoryHub> createState() => _HistoryHubState();
}

class _HistoryHubState extends State<HistoryHub> {
  var _index = 0;
  CalendarDaySummary? _day;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Column(
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final (index, label) in const [
                (0, 'On This Day'),
                (1, 'Calendar'),
                (2, 'Map'),
                (3, 'Export Printable Journal'),
              ])
                ChoiceChip(
                  key: Key('history_tab_$label'),
                  label: Text(label),
                  selected: _index == index,
                  onSelected: (_) => setState(() => _index = index),
                ),
            ],
          ),
          Expanded(child: _body(now)),
        ],
      ),
    );
  }

  Widget _body(DateTime now) {
    switch (_index) {
      case 1:
        return Column(
          children: [
            Expanded(
              child: CalendarMonthView(
                month: DateTime(now.year, now.month),
                entries: widget.entries,
                onDay: (day) => setState(() => _day = day),
              ),
            ),
            if (_day != null)
              Text(
                '${_day!.count} moments',
                key: const Key('calendar_day_summary'),
              ),
          ],
        );
      case 2:
        final pins = EntryMapClusters.cluster(widget.entries);
        return EntryMapView(
          pins: pins,
          onPin: (pin) {
            showModalBottomSheet<void>(
              context: context,
              builder: (context) => ListTile(
                key: const Key('map_place_card'),
                title: Text(pin.label),
                subtitle: const Text('Add a place to any moment'),
              ),
            );
          },
        );
      case 3:
        return Center(
          child: FilledButton(
            key: const Key('export_printable_journal'),
            onPressed: () async {
              await BookExporter.render(
                entries: widget.entries,
                start: DateTime(now.year, 1, 1),
                end: DateTime(now.year, 12, 31),
              );
            },
            child: const Text('Export Printable Journal'),
          ),
        );
      default:
        return OnThisDayView(entries: widget.entries, now: now);
    }
  }
}
