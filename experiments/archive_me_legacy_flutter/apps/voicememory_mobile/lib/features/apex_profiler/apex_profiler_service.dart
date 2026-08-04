import 'dart:async';

import '../../services/analytics/apex_native_guard_probe.dart';
import '../../services/analytics/ffi_safety_monitor.dart';
import '../../services/analytics/frame_performance_tracker.dart';
import '../neural_sculptor/lora_adapter_trainer.dart';
import 'apex_benchmark_runner.dart';

final class ApexTelemetrySnapshot {
  const ApexTelemetrySnapshot({
    required this.ffi,
    required this.frames,
    required this.nativeGuard,
    required this.sqliteCacheBytes,
    required this.cpuPercent,
    required this.gpuPercent,
  });

  final FFISafetySnapshot ffi;
  final FramePerformanceSnapshot frames;
  final ApexNativeGuardSnapshot nativeGuard;
  final int? sqliteCacheBytes;
  final double? cpuPercent;
  final double? gpuPercent;
}

final class ApexProfilerService {
  ApexProfilerService({
    required this.ffiMonitor,
    required this.frameTracker,
    required this.benchmarkRunner,
    ApexNativeGuardProbe? nativeGuardProbe,
  }) : nativeGuardProbe =
           nativeGuardProbe ?? const UnsupportedApexNativeGuardProbe();

  final FFISafetyMonitor ffiMonitor;
  final FramePerformanceTracker frameTracker;
  final ApexBenchmarkRunner benchmarkRunner;
  final ApexNativeGuardProbe nativeGuardProbe;
  final StreamController<ApexTelemetrySnapshot> _telemetry =
      StreamController.broadcast();
  Timer? _timer;
  int _systemSampleTicks = 0;
  bool _systemSampleRunning = false;

  Stream<ApexTelemetrySnapshot> get telemetry => _telemetry.stream;
  ApexTelemetrySnapshot get current => ApexTelemetrySnapshot(
    ffi: ffiMonitor.snapshot,
    frames: frameTracker.snapshot,
    nativeGuard: _nativeGuardSnapshot(),
    // sqlite3 does not expose a reliable process-wide cache counter here.
    sqliteCacheBytes: null,
    // Platform APIs are capability-gated; never present RSS deltas as CPU/GPU.
    cpuPercent: null,
    gpuPercent: null,
  );

  ApexNativeGuardSnapshot _nativeGuardSnapshot() {
    try {
      return nativeGuardProbe.snapshot();
    } on Object catch (error) {
      return ApexNativeGuardSnapshot.unavailable(
        'Native guard query failed: $error',
      );
    }
  }

  void start() {
    frameTracker.start();
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_telemetry.isClosed) _telemetry.add(current);
      unawaited(ffiMonitor.checkPressure());
      if (++_systemSampleTicks % 15 == 0) {
        unawaited(_sampleSystemPressure());
      }
    });
    unawaited(_sampleSystemPressure());
    _telemetry.add(current);
  }

  Future<void> _sampleSystemPressure() async {
    if (_systemSampleRunning) return;
    _systemSampleRunning = true;
    try {
      final hardware = await benchmarkRunner.hardwareProbe.current();
      frameTracker.applySystemPressure(
        thermal:
            hardware.thermalState == NeuralThermalState.serious ||
            hardware.thermalState == NeuralThermalState.critical,
        batteryLow: hardware.batteryPercent < 20 && !hardware.isCharging,
      );
    } on Object {
      // Hardware state remains capability-gated when the platform probe fails.
    } finally {
      _systemSampleRunning = false;
    }
  }

  void pause() {
    benchmarkRunner.cancel();
    frameTracker.stop();
    _timer?.cancel();
    _timer = null;
  }

  Future<void> clear() => benchmarkRunner.auditWriter.clear();

  Future<void> dispose() async {
    pause();
    await benchmarkRunner.dispose();
    await ffiMonitor.dispose();
    frameTracker.dispose();
    await _telemetry.close();
  }
}
