import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CanvasTimeMachineSlider extends StatefulWidget {
  const CanvasTimeMachineSlider({
    super.key,
    required this.start,
    required this.end,
    required this.selected,
    required this.onChanged,
    this.markers = const [],
  });

  final DateTime start;
  final DateTime end;
  final DateTime selected;
  final ValueChanged<DateTime> onChanged;
  final List<DateTime> markers;

  @override
  State<CanvasTimeMachineSlider> createState() =>
      _CanvasTimeMachineSliderState();
}

class _CanvasTimeMachineSliderState extends State<CanvasTimeMachineSlider> {
  DateTime? _last;

  void _changed(double value) {
    final target = widget.start.toUtc().add(Duration(days: value.round()));
    final previous = _last ?? widget.selected.toUtc();
    if (target.year != previous.year) {
      unawaited(HapticFeedback.heavyImpact());
    } else if (target.month != previous.month) {
      unawaited(HapticFeedback.mediumImpact());
    } else if (target.day != previous.day) {
      unawaited(HapticFeedback.selectionClick());
    }
    _last = target;
    widget.onChanged(target);
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.start.toUtc();
    final end = widget.end.toUtc();
    final totalDays = end.difference(start).inDays.clamp(1, 36500);
    final selectedDays = widget.selected
        .toUtc()
        .difference(start)
        .inDays
        .clamp(0, totalDays);
    final label =
        '${widget.selected.year}-${widget.selected.month.toString().padLeft(2, '0')}-${widget.selected.day.toString().padLeft(2, '0')}';
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          key: const Key('canvas-time-machine-slider'),
          color: Theme.of(context).colorScheme.surface.withValues(alpha: .82),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Memory Graph · $label',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const Spacer(),
                    const Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('History Mode'),
                    ),
                  ],
                ),
                SizedBox(
                  height: 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _TimelineMarkerPainter(
                            start: start,
                            totalDays: totalDays,
                            markers: widget.markers,
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                        ),
                      ),
                      Semantics(
                        slider: true,
                        label: 'Canvas Time Machine date',
                        value: label,
                        child: Slider(
                          key: const Key('canvas-time-machine-control'),
                          min: 0,
                          max: totalDays.toDouble(),
                          divisions: totalDays.clamp(1, 500),
                          value: selectedDays.toDouble(),
                          onChanged: _changed,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineMarkerPainter extends CustomPainter {
  const _TimelineMarkerPainter({
    required this.start,
    required this.totalDays,
    required this.markers,
    required this.color,
  });

  final DateTime start;
  final int totalDays;
  final List<DateTime> markers;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: .75)
      ..strokeWidth = 2;
    for (final marker in markers) {
      final day = marker.toUtc().difference(start).inDays;
      if (day < 0 || day > totalDays) continue;
      final x = 24 + (size.width - 48) * (day / totalDays);
      canvas.drawLine(Offset(x, 3), Offset(x, 10), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TimelineMarkerPainter oldDelegate) =>
      start != oldDelegate.start ||
      totalDays != oldDelegate.totalDays ||
      markers != oldDelegate.markers ||
      color != oldDelegate.color;
}
