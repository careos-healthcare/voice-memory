import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Counts frames that miss the 120Hz budget (8.3ms of build plus raster).
class FrameBudgetMonitor {
  static const Duration budget = Duration(microseconds: 8333);

  int sampled = 0;
  int droppedFrames = 0;

  bool get stable => droppedFrames == 0;

  void record({required Duration build, required Duration raster}) {
    sampled++;
    if (build + raster > budget) droppedFrames++;
  }

  void reset() {
    sampled = 0;
    droppedFrames = 0;
  }
}

/// Debug badge that stays quiet while scrolling stays inside the frame budget.
class FrameBudgetOverlay extends StatefulWidget {
  const FrameBudgetOverlay({
    required this.child,
    super.key,
    this.monitor,
  });

  final Widget child;
  final FrameBudgetMonitor? monitor;

  @override
  State<FrameBudgetOverlay> createState() => _FrameBudgetOverlayState();
}

class _FrameBudgetOverlayState extends State<FrameBudgetOverlay> {
  late final FrameBudgetMonitor _monitor = widget.monitor ?? FrameBudgetMonitor();

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
    }
  }

  @override
  void dispose() {
    if (kDebugMode) {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    }
    super.dispose();
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _monitor.record(
        build: timing.buildDuration,
        raster: timing.rasterDuration,
      );
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (kDebugMode)
          Positioned(
            right: 8,
            bottom: 8,
            child: IgnorePointer(
              child: Text(
                _monitor.stable ? 'Frames stable' : 'Frames dropped',
                key: const Key('frame_budget_overlay'),
              ),
            ),
          ),
      ],
    );
  }
}
