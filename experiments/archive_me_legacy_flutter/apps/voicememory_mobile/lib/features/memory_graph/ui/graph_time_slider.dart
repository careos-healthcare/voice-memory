import 'package:flutter/material.dart';

class GraphTimeSlider extends StatelessWidget {
  const GraphTimeSlider({
    super.key,
    required this.start,
    required this.end,
    required this.selected,
    required this.onChanged,
    required this.onReset,
  });

  final DateTime start;
  final DateTime end;
  final DateTime selected;
  final ValueChanged<DateTime> onChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final totalDays = end.difference(start).inDays.clamp(1, 36500);
    final selectedDays = selected.difference(start).inDays.clamp(0, totalDays);
    final label =
        '${selected.year}-${selected.month.toString().padLeft(2, '0')}';
    return Material(
      key: const Key('graph_time_slider'),
      elevation: 8,
      borderRadius: BorderRadius.circular(18),
      color: Theme.of(context).colorScheme.surface.withValues(alpha: .94),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
        child: Row(
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            Expanded(
              child: Semantics(
                slider: true,
                label: 'Memory Graph time',
                value: label,
                child: Slider(
                  key: const Key('graph_time_slider_control'),
                  min: 0,
                  max: totalDays.toDouble(),
                  divisions: totalDays.clamp(1, 200),
                  value: selectedDays.toDouble(),
                  onChanged: (value) =>
                      onChanged(start.add(Duration(days: value.round()))),
                ),
              ),
            ),
            IconButton(
              key: const Key('graph_time_slider_reset'),
              tooltip: 'Show all time',
              onPressed: onReset,
              icon: const Icon(Icons.all_inclusive),
            ),
          ],
        ),
      ),
    );
  }
}
