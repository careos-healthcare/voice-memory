import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../../services/ai/sqlite_vec_vector_store.dart';
import '../../services/analytics/ffi_safety_monitor.dart';
import '../../services/analytics/frame_performance_tracker.dart';
import '../../storage/encrypted_json_file_store.dart';
import '../../storage/private_data_encryption_key_store.dart';
import '../neural_sculptor/lora_adapter_trainer.dart';

enum ApexBenchmarkStatus {
  idle,
  running,
  completed,
  cancelled,
  blocked,
  failed,
}

final class ApexBenchmarkResult {
  const ApexBenchmarkResult({
    required this.status,
    required this.startedAt,
    required this.finishedAt,
    required this.scenarios,
    required this.skippedScenarios,
    required this.rssDeltaBytes,
    required this.batteryDeltaPercent,
    required this.report,
    this.message,
  });

  final ApexBenchmarkStatus status;
  final DateTime startedAt;
  final DateTime finishedAt;
  final Map<String, int> scenarios;
  final Map<String, String> skippedScenarios;
  final int rssDeltaBytes;
  final int? batteryDeltaPercent;
  final File? report;
  final String? message;
}

final class ApexBenchmarkCancellation {
  ApexBenchmarkCancellation({
    required Duration timeout,
    required this.isForeground,
  }) : _deadline = DateTime.now().add(timeout),
       assert(timeout >= Duration.zero);

  final DateTime _deadline;
  final bool Function() isForeground;
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
  void throwIfCancelled() {
    if (_cancelled) throw const ApexBenchmarkCancelled();
    if (!isForeground()) throw const ApexBenchmarkCancelled();
    if (DateTime.now().isAfter(_deadline)) {
      throw const ApexBenchmarkDeadlineExceeded();
    }
  }
}

final class ApexBenchmarkCancelled implements Exception {
  const ApexBenchmarkCancelled();
}

final class ApexBenchmarkDeadlineExceeded implements Exception {
  const ApexBenchmarkDeadlineExceeded();
}

final class ApexAuditWriter {
  const ApexAuditWriter({required this.directory, required this.keyStore});

  final Directory directory;
  final PrivateDataEncryptionKeyStore keyStore;

  Future<File> write(Map<String, Object?> report) async {
    await directory.create(recursive: true);
    final file = File('${directory.path}/apex_latest.apex-audit');
    final store = EncryptedJsonFileStore(file: file, keyStore: keyStore);
    await store.writeJson(report);
    return file;
  }

  Future<void> clear() async {
    if (!await directory.exists()) return;
    await for (final entity in directory.list()) {
      if (entity is File && entity.path.endsWith('.apex-audit')) {
        await entity.delete();
      } else if (entity is File &&
          (entity.path.endsWith('.apex-audit.tmp') ||
              entity.path.endsWith('.apex-audit.previous'))) {
        await entity.delete();
      }
    }
  }
}

final class ApexBenchmarkRunner {
  ApexBenchmarkRunner({
    required this.hardwareProbe,
    required this.auditWriter,
    required this.isForeground,
    this.ffiMonitor,
    this.frameTracker,
    this.maximumDuration = const Duration(minutes: 2),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const minimumBatteryPercent = 30;

  final NeuralHardwareProbe hardwareProbe;
  final ApexAuditWriter auditWriter;
  final bool Function() isForeground;
  final FFISafetyMonitor? ffiMonitor;
  final FramePerformanceTracker? frameTracker;
  final Duration maximumDuration;
  final DateTime Function() _clock;
  final StreamController<double> _progress = StreamController.broadcast();
  ApexBenchmarkCancellation? _activeCancellation;
  ApexBenchmarkStatus _status = ApexBenchmarkStatus.idle;

  Stream<double> get progress => _progress.stream;
  ApexBenchmarkStatus get status => _status;

  void cancel() => _activeCancellation?.cancel();

  Future<ApexBenchmarkResult> run({required bool ownerAuthorized}) async {
    final startedAt = _clock().toUtc();
    if (!ownerAuthorized) {
      return _blocked(startedAt, 'Owner authorization is required.');
    }
    if (!isForeground()) {
      return _blocked(startedAt, 'Benchmarks run only in the foreground.');
    }
    if (_status == ApexBenchmarkStatus.running) {
      throw StateError('An Apex benchmark is already running.');
    }
    final hardware = await hardwareProbe.current();
    if (hardware.batteryPercent < minimumBatteryPercent &&
        !hardware.isCharging) {
      return _blocked(startedAt, 'Battery must be at least 30%.');
    }
    if (hardware.thermalState == NeuralThermalState.serious ||
        hardware.thermalState == NeuralThermalState.critical) {
      return _blocked(startedAt, 'Device thermal pressure is elevated.');
    }

    final cancellation = ApexBenchmarkCancellation(
      timeout: maximumDuration,
      isForeground: isForeground,
    );
    _activeCancellation = cancellation;
    _status = ApexBenchmarkStatus.running;
    final rssBefore = ProcessInfo.currentRss;
    final scenarios = <String, int>{};
    final skippedScenarios = <String, String>{};
    final temp = await Directory.systemTemp.createTemp('apex-benchmark-');
    try {
      scenarios['graph_10000_us'] = await _time(
        () => _graphScenario(cancellation),
      );
      await _guardHardware(cancellation);
      _progress.add(.2);
      final sqliteElapsed = await _sqliteVecScenario(
        temp,
        cancellation,
        skippedScenarios,
      );
      if (sqliteElapsed != null) {
        scenarios['sqlite_vec_knn_us'] = sqliteElapsed;
      }
      await _guardHardware(cancellation);
      _progress.add(.4);
      scenarios['muse_vector_sweep_us'] = await _time(
        () => _museScenario(cancellation),
      );
      await _guardHardware(cancellation);
      _progress.add(.6);
      scenarios['crdt_merge_us'] = await _time(
        () => _crdtScenario(cancellation),
      );
      await _guardHardware(cancellation);
      _progress.add(.8);
      final churnElapsed = await _nativeLifecycleScenario(
        cancellation,
        skippedScenarios,
      );
      if (churnElapsed != null) {
        scenarios['app_owned_native_lifecycle_us'] = churnElapsed;
      }
      _progress.add(1);
      final finishedHardware = await hardwareProbe.current();
      final finishedAt = _clock().toUtc();
      final rssDelta = ProcessInfo.currentRss - rssBefore;
      final report = await auditWriter.write({
        'schema': 'archive-me.apex-audit',
        'version': 1,
        'startedAt': startedAt.toIso8601String(),
        'finishedAt': finishedAt.toIso8601String(),
        'isolatedTemporaryStore': true,
        'realArchiveMutated': false,
        'scenariosMicroseconds': scenarios,
        'skippedScenarios': skippedScenarios,
        'operationCounts': {
          'graphNodes': 10000,
          'vectorQueries': scenarios.containsKey('sqlite_vec_knn_us') ? 32 : 0,
          'museVectors': 10000,
          'crdtNodes': 10000,
          'nativeLifecycleIterations':
              scenarios.containsKey('app_owned_native_lifecycle_us') ? 1000 : 0,
        },
        'latencySummaryMicroseconds': _latencySummary(scenarios.values),
        'frames': _frameReport(),
        'telemetry': {
          'processRssDeltaBytes': rssDelta,
          'processRssSemantics': 'sampled_process_delta',
          'batteryDeltaPercent':
              hardware.batteryPercent - finishedHardware.batteryPercent,
          'batterySemantics': 'coarse_platform_sample',
          'cpuUtilization': 'unavailable',
          'gpuUtilization': 'unavailable',
        },
      });
      _status = ApexBenchmarkStatus.completed;
      return ApexBenchmarkResult(
        status: _status,
        startedAt: startedAt,
        finishedAt: finishedAt,
        scenarios: Map.unmodifiable(scenarios),
        skippedScenarios: Map.unmodifiable(skippedScenarios),
        rssDeltaBytes: rssDelta,
        batteryDeltaPercent:
            hardware.batteryPercent - finishedHardware.batteryPercent,
        report: report,
      );
    } on ApexBenchmarkCancelled {
      _status = ApexBenchmarkStatus.cancelled;
      return ApexBenchmarkResult(
        status: _status,
        startedAt: startedAt,
        finishedAt: _clock().toUtc(),
        scenarios: Map.unmodifiable(scenarios),
        skippedScenarios: Map.unmodifiable(skippedScenarios),
        rssDeltaBytes: ProcessInfo.currentRss - rssBefore,
        batteryDeltaPercent: null,
        report: null,
        message: 'Cancelled by owner.',
      );
    } on ApexBenchmarkDeadlineExceeded {
      _status = ApexBenchmarkStatus.failed;
      return ApexBenchmarkResult(
        status: _status,
        startedAt: startedAt,
        finishedAt: _clock().toUtc(),
        scenarios: Map.unmodifiable(scenarios),
        skippedScenarios: Map.unmodifiable(skippedScenarios),
        rssDeltaBytes: ProcessInfo.currentRss - rssBefore,
        batteryDeltaPercent: null,
        report: null,
        message: 'Benchmark deadline exceeded.',
      );
    } on Object catch (error) {
      _status = ApexBenchmarkStatus.failed;
      return ApexBenchmarkResult(
        status: _status,
        startedAt: startedAt,
        finishedAt: _clock().toUtc(),
        scenarios: Map.unmodifiable(scenarios),
        skippedScenarios: Map.unmodifiable(skippedScenarios),
        rssDeltaBytes: ProcessInfo.currentRss - rssBefore,
        batteryDeltaPercent: null,
        report: null,
        message: _redactReason('$error', temp),
      );
    } finally {
      _activeCancellation = null;
      if (await temp.exists()) await temp.delete(recursive: true);
    }
  }

  ApexBenchmarkResult _blocked(DateTime startedAt, String message) {
    _status = ApexBenchmarkStatus.blocked;
    return ApexBenchmarkResult(
      status: _status,
      startedAt: startedAt,
      finishedAt: _clock().toUtc(),
      scenarios: const {},
      skippedScenarios: const {},
      rssDeltaBytes: 0,
      batteryDeltaPercent: null,
      report: null,
      message: message,
    );
  }

  Future<int> _time(FutureOr<void> Function() operation) async {
    final watch = Stopwatch()..start();
    await operation();
    return watch.elapsedMicroseconds;
  }

  void _graphScenario(ApexBenchmarkCancellation cancellation) {
    final positions = List<double>.generate(30000, (index) => index * .0001);
    var checksum = 0.0;
    for (var pass = 0; pass < 8; pass++) {
      cancellation.throwIfCancelled();
      for (var index = 0; index < positions.length; index += 3) {
        checksum += sin(positions[index] + pass) * cos(positions[index + 1]);
      }
    }
    if (!checksum.isFinite) throw StateError('Invalid graph result.');
  }

  Future<int?> _sqliteVecScenario(
    Directory temp,
    ApexBenchmarkCancellation cancellation,
    Map<String, String> skipped,
  ) async {
    const dimensions = 32;
    final store = await SqliteVecVectorStore.open(
      databasePath: '${temp.path}/benchmark.sqlite3',
      dimensions: dimensions,
    );
    try {
      if (!store.isAccelerated) {
        skipped['sqlite_vec_knn'] = _redactReason(
          store.unavailableReason ?? 'sqlite-vec extension unavailable',
          temp,
        );
        return null;
      }
      final records = List.generate(2000, (index) {
        if (index % 100 == 0) cancellation.throwIfCancelled();
        return SqliteVecRecord(
          entryId: 'benchmark-$index',
          embedding: Float32List.fromList(
            List.generate(
              dimensions,
              (dimension) => sin(index * .01 + dimension),
            ),
          ),
          clusterType: 'benchmark',
          updatedAt: DateTime.utc(2026),
          confidence: 1,
          nodeIds: const [],
          tags: const {'isolated'},
        );
      });
      store.replaceAll(records);
      return await _time(() {
        for (var query = 0; query < 32; query++) {
          cancellation.throwIfCancelled();
          store.search(
            Float32List.fromList(
              List.generate(
                dimensions,
                (dimension) => cos(query * .03 + dimension),
              ),
            ),
            limit: 25,
          );
        }
      });
    } finally {
      store.close();
    }
  }

  void _museScenario(ApexBenchmarkCancellation cancellation) {
    final query = Float32List.fromList(
      List.generate(64, (index) => sin(index.toDouble())),
    );
    var checksum = 0.0;
    for (var vector = 0; vector < 10000; vector++) {
      if (vector % 250 == 0) cancellation.throwIfCancelled();
      var score = 0.0;
      for (var dimension = 0; dimension < query.length; dimension++) {
        score += query[dimension] * cos(vector * .001 + dimension);
      }
      checksum += score;
    }
    if (!checksum.isFinite) throw StateError('Invalid Muse vector result.');
  }

  void _crdtScenario(ApexBenchmarkCancellation cancellation) {
    final left = <String, (int, int)>{};
    final right = <String, (int, int)>{};
    for (var index = 0; index < 10000; index++) {
      left['node-$index'] = (index, 1);
      right['node-$index'] = (index + (index.isEven ? 1 : 0), 2);
    }
    for (final entry in right.entries) {
      if (left.length % 500 == 0) cancellation.throwIfCancelled();
      final current = left[entry.key];
      if (current == null || entry.value.$1 >= current.$1) {
        left[entry.key] = entry.value;
      }
    }
  }

  Future<int?> _nativeLifecycleScenario(
    ApexBenchmarkCancellation cancellation,
    Map<String, String> skipped,
  ) async {
    final monitor = ffiMonitor;
    if (monitor == null) {
      skipped['app_owned_native_lifecycle'] =
          'FFI safety monitor unavailable in this runtime.';
      return null;
    }
    final baseline = monitor.snapshot.byKind[FFIResourceKind.llamaOutput] ?? 0;
    return _time(() {
      for (var index = 0; index < 1000; index++) {
        if (index % 100 == 0) cancellation.throwIfCancelled();
        final lease = monitor.acquire(
          FFIResourceKind.llamaOutput,
          owner: 'apex-isolated-churn',
          estimatedBytes: 256,
        );
        lease.ensureActive();
        lease.release();
      }
      final after = monitor.snapshot.byKind[FFIResourceKind.llamaOutput] ?? 0;
      if (after != baseline) {
        throw StateError('App-owned lifecycle churn did not balance.');
      }
    });
  }

  Future<void> _guardHardware(ApexBenchmarkCancellation cancellation) async {
    cancellation.throwIfCancelled();
    final hardware = await hardwareProbe.current();
    if (!isForeground() ||
        hardware.thermalState == NeuralThermalState.serious ||
        hardware.thermalState == NeuralThermalState.critical ||
        (hardware.batteryPercent < minimumBatteryPercent &&
            !hardware.isCharging)) {
      cancellation.cancel();
      cancellation.throwIfCancelled();
    }
  }

  Map<String, Object?> _frameReport() {
    final frames = frameTracker?.snapshot;
    if (frames == null) {
      return const {'available': false, 'reason': 'Frame tracker unavailable'};
    }
    return {
      'available': true,
      'sampleCount': frames.sampleCount,
      'averageFrameMs': frames.averageFrameMs,
      'p95FrameMs': frames.p95FrameMs,
      'averageBuildMs': frames.averageBuildMs,
      'p95BuildMs': frames.p95BuildMs,
      'averageRasterMs': frames.averageRasterMs,
      'p95RasterMs': frames.p95RasterMs,
      'qualityTier': frames.qualityTier.name,
    };
  }

  static Map<String, int> _latencySummary(Iterable<int> values) {
    final sorted = values.toList()..sort();
    if (sorted.isEmpty) return const {};
    return {
      'p50': sorted[((sorted.length - 1) * .5).round()],
      'p95': sorted[((sorted.length - 1) * .95).round()],
    };
  }

  static String _redactReason(String value, Directory temp) => value
      .replaceAll(temp.path, '<temporary>')
      .replaceAll(RegExp(r'[/\\][^\s:]+'), '<path>')
      .replaceAll(RegExp(r'0x[0-9a-fA-F]+'), '<address>');

  Future<void> dispose() async {
    cancel();
    await _progress.close();
  }
}
