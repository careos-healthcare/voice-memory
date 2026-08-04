import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

final class GraphPerformanceMonitor extends ChangeNotifier {
  GraphPerformanceMonitor._();

  static final GraphPerformanceMonitor instance = GraphPerformanceMonitor._();

  double fps = 60;
  double frameTimeMs = 0;
  double vectorSearchLatencyMs = 0;
  int activeNodeCount = 0;
  int visibleNodeCount = 0;
  int visibleEdgeCount = 0;
  int estimatedMemoryBytes = 0;
  int below55FpsSamples = 0;
  bool _notificationScheduled = false;

  int get culledNodeCount =>
      (activeNodeCount - visibleNodeCount).clamp(0, activeNodeCount);

  void recordFrameTimings(List<FrameTiming> timings) {
    if (timings.isEmpty) return;
    var totalMicros = 0;
    for (final timing in timings) {
      totalMicros += timing.totalSpan.inMicroseconds;
    }
    frameTimeMs = totalMicros / timings.length / 1000;
    fps = frameTimeMs <= 0 ? 60 : (1000 / frameTimeMs).clamp(0, 120);
    estimatedMemoryBytes = ProcessInfo.currentRss;
    if (fps < 55) {
      below55FpsSamples++;
      if (kDebugMode && below55FpsSamples % 30 == 1) {
        debugPrint(
          '[GraphBenchmark] ${fps.toStringAsFixed(1)}fps, '
          '${frameTimeMs.toStringAsFixed(1)}ms, '
          '$visibleNodeCount/$activeNodeCount nodes visible, '
          '${vectorSearchLatencyMs.toStringAsFixed(2)}ms KNN',
        );
      }
    }
    _scheduleNotification();
  }

  void recordCulling({
    required int activeNodes,
    required int visibleNodes,
    required int visibleEdges,
  }) {
    if (activeNodeCount == activeNodes &&
        visibleNodeCount == visibleNodes &&
        visibleEdgeCount == visibleEdges) {
      return;
    }
    activeNodeCount = activeNodes;
    visibleNodeCount = visibleNodes;
    visibleEdgeCount = visibleEdges;
    estimatedMemoryBytes = ProcessInfo.currentRss;
    _scheduleNotification();
  }

  void recordVectorSearch(Duration elapsed) {
    vectorSearchLatencyMs = elapsed.inMicroseconds / 1000;
    _scheduleNotification();
  }

  void resetRegressions() {
    below55FpsSamples = 0;
    _scheduleNotification();
  }

  void _scheduleNotification() {
    if (_notificationScheduled) return;
    _notificationScheduled = true;
    scheduleMicrotask(() {
      _notificationScheduled = false;
      notifyListeners();
    });
  }
}
