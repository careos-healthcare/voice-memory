import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../../features/memory_graph/performance/graph_performance_monitor.dart';
import '../../shared/ui/glassmorphic_container.dart';

enum ApexQualityTier { full, balanced, constrained, survival }

final class FramePerformanceSnapshot {
  const FramePerformanceSnapshot({
    required this.fps,
    required this.averageFrameMs,
    required this.p95FrameMs,
    required this.averageBuildMs,
    required this.p95BuildMs,
    required this.averageRasterMs,
    required this.p95RasterMs,
    required this.jankRatio,
    required this.droppedFrameStreak,
    required this.processRssBytes,
    required this.vectorLatencyMs,
    required this.reason,
    required this.qualityTier,
    required this.sampleCount,
  });

  final double fps;
  final double averageFrameMs;
  final double p95FrameMs;
  final double averageBuildMs;
  final double p95BuildMs;
  final double averageRasterMs;
  final double p95RasterMs;
  final double jankRatio;
  final int droppedFrameStreak;
  final int processRssBytes;
  final double? vectorLatencyMs;
  final String reason;
  final ApexQualityTier qualityTier;
  final int sampleCount;

  double get spatialParticleFraction => switch (qualityTier) {
    ApexQualityTier.full => 1,
    ApexQualityTier.balanced => .75,
    ApexQualityTier.constrained => .45,
    ApexQualityTier.survival => .25,
  };

  int get spatialSimulationStride => switch (qualityTier) {
    ApexQualityTier.full => 1,
    ApexQualityTier.balanced => 2,
    ApexQualityTier.constrained => 3,
    ApexQualityTier.survival => 5,
  };
}

final class FramePerformanceTracker extends ChangeNotifier {
  FramePerformanceTracker({
    this.degradeAfterSamples = 8,
    this.recoverAfterSamples = 120,
    this.targetFps = 55,
    this.windowSize = 120,
    GraphPerformanceMonitor? graphMonitor,
  }) : _graphMonitor = graphMonitor ?? GraphPerformanceMonitor.instance;

  static FramePerformanceTracker? installed;

  final int degradeAfterSamples;
  final int recoverAfterSamples;
  final double targetFps;
  final int windowSize;
  final GraphPerformanceMonitor _graphMonitor;
  final Queue<_FrameSample> _frames = Queue<_FrameSample>();
  final Queue<double> _vectorLatencies = Queue<double>();
  ApexQualityTier _quality = ApexQualityTier.full;
  int _slowSamples = 0;
  int _healthySamples = 0;
  int _droppedFrameStreak = 0;
  String _reason = 'Frame budget healthy';
  bool _thermalPressure = false;
  bool _batteryLow = false;
  double _lastGraphVectorLatency = -1;
  bool _tracking = false;

  ApexQualityTier get qualityTier => _quality;
  FramePerformanceSnapshot get snapshot => _snapshot();

  void start() {
    if (_tracking) return;
    _tracking = true;
    _graphMonitor.addListener(_recordGraphTelemetry);
    SchedulerBinding.instance.addTimingsCallback(recordFrameTimings);
  }

  void stop() {
    if (!_tracking) return;
    _tracking = false;
    _graphMonitor.removeListener(_recordGraphTelemetry);
    SchedulerBinding.instance.removeTimingsCallback(recordFrameTimings);
  }

  void _recordGraphTelemetry() {
    final latency = _graphMonitor.vectorSearchLatencyMs;
    if (latency == _lastGraphVectorLatency) return;
    _lastGraphVectorLatency = latency;
    if (latency >= 0) {
      recordVectorLatency(Duration(microseconds: (latency * 1000).round()));
    }
  }

  void recordFrameTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _recordFrame(
        total: timing.totalSpan,
        build: timing.buildDuration,
        raster: timing.rasterDuration,
      );
    }
  }

  @visibleForTesting
  void recordFrameDuration(Duration duration) => _recordFrame(
    total: duration,
    build: Duration.zero,
    raster: Duration.zero,
  );

  void recordVectorLatency(Duration duration) {
    _vectorLatencies.addLast(duration.inMicroseconds / 1000);
    while (_vectorLatencies.length > windowSize) {
      _vectorLatencies.removeFirst();
    }
    notifyListeners();
  }

  void _recordFrame({
    required Duration total,
    required Duration build,
    required Duration raster,
  }) {
    final millis = total.inMicroseconds / 1000;
    _frames.addLast(
      _FrameSample(
        totalMs: millis,
        buildMs: build.inMicroseconds / 1000,
        rasterMs: raster.inMicroseconds / 1000,
      ),
    );
    while (_frames.length > windowSize) {
      _frames.removeFirst();
    }
    final fps = millis <= 0 ? 120 : 1000 / millis;
    if (fps < targetFps) {
      _slowSamples++;
      _droppedFrameStreak++;
      _healthySamples = 0;
      if (_slowSamples >= degradeAfterSamples) {
        _degrade('Sustained sub-${targetFps.toStringAsFixed(0)} FPS');
        _slowSamples = 0;
      }
    } else if (fps >= 58) {
      _healthySamples++;
      _slowSamples = 0;
      _droppedFrameStreak = 0;
      if (_healthySamples >= recoverAfterSamples) {
        _recover();
        _healthySamples = 0;
      }
    }
    notifyListeners();
  }

  void applySystemPressure({required bool thermal, required bool batteryLow}) {
    _thermalPressure = thermal;
    _batteryLow = batteryLow;
    if (thermal || batteryLow) {
      final target = thermal
          ? ApexQualityTier.survival
          : ApexQualityTier.constrained;
      _reason = thermal
          ? 'Platform thermal pressure'
          : 'Low battery protection';
      if (_quality.index < target.index) {
        _quality = target;
        _syncGlassQuality();
      }
      notifyListeners();
    } else {
      _reason = 'System pressure cleared; awaiting sustained recovery';
      notifyListeners();
    }
  }

  void _degrade(String reason) {
    if (_quality != ApexQualityTier.survival) {
      _quality = ApexQualityTier.values[_quality.index + 1];
      _reason = reason;
      _syncGlassQuality();
    }
  }

  void _recover() {
    final minimumTier = _thermalPressure
        ? ApexQualityTier.survival
        : _batteryLow
        ? ApexQualityTier.constrained
        : ApexQualityTier.full;
    if (_quality.index <= minimumTier.index) return;
    if (_quality != ApexQualityTier.full) {
      _quality = ApexQualityTier.values[_quality.index - 1];
      _reason = _quality == ApexQualityTier.full
          ? 'Frame budget healthy'
          : 'Recovering after sustained healthy frames';
      _syncGlassQuality();
    }
  }

  void _syncGlassQuality() {
    GlassQualityGovernor.maximum = switch (_quality) {
      ApexQualityTier.full => GlassRenderQuality.full,
      ApexQualityTier.balanced => GlassRenderQuality.reduced,
      ApexQualityTier.constrained ||
      ApexQualityTier.survival => GlassRenderQuality.off,
    };
  }

  FramePerformanceSnapshot _snapshot() {
    if (_frames.isEmpty) {
      return FramePerformanceSnapshot(
        fps: 60,
        averageFrameMs: 0,
        p95FrameMs: 0,
        averageBuildMs: 0,
        p95BuildMs: 0,
        averageRasterMs: 0,
        p95RasterMs: 0,
        jankRatio: 0,
        droppedFrameStreak: _droppedFrameStreak,
        processRssBytes: ProcessInfo.currentRss,
        vectorLatencyMs: _average(_vectorLatencies),
        reason: _reason,
        qualityTier: _quality,
        sampleCount: 0,
      );
    }
    final total = _frames.map((frame) => frame.totalMs).toList()..sort();
    final build = _frames.map((frame) => frame.buildMs).toList()..sort();
    final raster = _frames.map((frame) => frame.rasterMs).toList()..sort();
    final average = _average(total)!;
    return FramePerformanceSnapshot(
      fps: average <= 0 ? 120 : (1000 / average).clamp(0, 120),
      averageFrameMs: average,
      p95FrameMs: _p95(total),
      averageBuildMs: _average(build)!,
      p95BuildMs: _p95(build),
      averageRasterMs: _average(raster)!,
      p95RasterMs: _p95(raster),
      jankRatio:
          total.where((millis) => millis > 1000 / targetFps).length /
          total.length,
      droppedFrameStreak: _droppedFrameStreak,
      processRssBytes: ProcessInfo.currentRss,
      vectorLatencyMs: _average(_vectorLatencies),
      reason: _reason,
      qualityTier: _quality,
      sampleCount: total.length,
    );
  }

  static double? _average(Iterable<double> values) {
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  static double _p95(List<double> sorted) =>
      sorted[((sorted.length - 1) * .95).round()];

  @override
  void dispose() {
    stop();
    if (identical(installed, this)) installed = null;
    GlassQualityGovernor.maximum = GlassRenderQuality.full;
    super.dispose();
  }
}

final class _FrameSample {
  const _FrameSample({
    required this.totalMs,
    required this.buildMs,
    required this.rasterMs,
  });

  final double totalMs;
  final double buildMs;
  final double rasterMs;
}
