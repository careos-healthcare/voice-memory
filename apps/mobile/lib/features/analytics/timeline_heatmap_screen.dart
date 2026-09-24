import 'package:archiveme_mobile/features/analytics/contribution_calendar.dart';
import 'package:archiveme_mobile/features/analytics/interactive_map_view.dart';
import 'package:archiveme_mobile/features/analytics/timeline_day_stats.dart';
import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Calendar and map of saved moments, with the list filtered by a tap.
class TimelineHeatmapScreen extends StatefulWidget {
  const TimelineHeatmapScreen({
    required this.entries,
    this.today,
    this.showMapTiles = true,
    super.key,
  });

  final List<TimelineMapEntry> entries;
  final DateTime? today;
  final bool showMapTiles;

  @override
  State<TimelineHeatmapScreen> createState() => _TimelineHeatmapScreenState();
}

class _TimelineHeatmapScreenState extends State<TimelineHeatmapScreen> {
  _TimelinePane _pane = _TimelinePane.calendar;
  TimelineSelection _selection = TimelineSelection.none;

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(widget.today ?? DateTime.now());
    final index = TimelineHeatmapIndex.fromEntries(widget.entries);
    final visible = index.matching(_selection);
    return Scaffold(
      key: const Key('timeline_heatmap_screen'),
      backgroundColor: const Color(0xFFF8F6F1),
      appBar: AppBar(
        title: const Text('Timeline'),
        backgroundColor: const Color(0xFFF8F6F1),
        foregroundColor: AppTokens.neutral900,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.spacing4),
        children: [
          SegmentedButton<_TimelinePane>(
            segments: const [
              ButtonSegment(
                value: _TimelinePane.calendar,
                label: Text('Calendar'),
                icon: Icon(Icons.grid_view),
              ),
              ButtonSegment(
                value: _TimelinePane.map,
                label: Text('Map'),
                icon: Icon(Icons.map_outlined),
              ),
            ],
            selected: {_pane},
            onSelectionChanged: (next) {
              setState(() => _pane = next.first);
            },
          ),
          const SizedBox(height: AppTokens.spacing4),
          if (_pane == _TimelinePane.calendar)
            SizedBox(
              height: ContributionCalendarLayout(today: today).height,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: ContributionCalendar(
                  key: const Key('timeline_contribution_calendar'),
                  days: index.days,
                  today: today,
                  selectedDay: _selection.day,
                  onDayTap: (day) {
                    setState(() {
                      final already = _selection.day == dateOnly(day);
                      _selection = already
                          ? TimelineSelection.none
                          : TimelineSelection(day: dateOnly(day));
                    });
                  },
                ),
              ),
            )
          else
            InteractiveMapView(
              clusters: index.clusters,
              selectedClusterId: _selection.clusterId,
              showTiles: widget.showMapTiles,
              onClusterTap: (cluster) {
                setState(() {
                  final already = _selection.clusterId == cluster.id;
                  _selection = already
                      ? TimelineSelection.none
                      : TimelineSelection(clusterId: cluster.id);
                });
              },
            ),
          const SizedBox(height: AppTokens.spacing4),
          Text(
            _heading(_selection, visible.length),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTokens.neutral900,
            ),
          ),
          const SizedBox(height: AppTokens.spacing2),
          if (visible.isEmpty)
            const Text(
              'No moments for this selection.',
              key: Key('timeline_filtered_empty'),
            )
          else
            for (final entry in visible)
              ListTile(
                key: Key('timeline_filtered_entry_${entry.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(entry.preview.isEmpty ? 'Moment' : entry.preview),
                subtitle: Text(_dateLabel(entry.createdAt)),
              ),
        ],
      ),
    );
  }
}

enum _TimelinePane { calendar, map }

String _heading(TimelineSelection selection, int count) {
  final moments = count == 1 ? 'moment' : 'moments';
  if (selection.day != null) {
    return '$count $moments on ${_dateLabel(selection.day!)}';
  }
  if (selection.clusterId != null) {
    return '$count $moments near this place';
  }
  return '$count $moments';
}

String _dateLabel(DateTime value) {
  final day = dateOnly(value);
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
  return '${day.day} ${months[day.month - 1]}';
}
