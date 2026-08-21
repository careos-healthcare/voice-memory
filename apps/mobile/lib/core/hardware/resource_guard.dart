import 'dart:async';

import 'package:archiveme_mobile/core/hardware/hardware_monitor_channel.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_model_contract.dart';
import 'package:archiveme_mobile/services/thermal_throttling/thermal_throttling_service.dart';
import 'package:archiveme_mobile/workers/local_llm/local_llm_worker_service.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';

export 'hardware_monitor_channel.dart';

/// Snapshot of battery + thermal constraints for on-device inference.
final class HardwareResourceSnapshot {
  const HardwareResourceSnapshot({
    required this.batteryLevel,
    required this.batteryState,
    required this.isCharging,
    required this.thermalStatus,
  });

  final int batteryLevel;
  final BatteryState batteryState;
  final bool isCharging;
  final DeviceThermalStatus thermalStatus;

  bool get isBatteryLowForInference =>
      batteryLevel >= 0 &&
      batteryLevel < ResourceGuard.inferenceBatteryThreshold &&
      !isCharging;

  bool get shouldDeferEmbedding =>
      batteryLevel >= 0 &&
      batteryLevel < ResourceGuard.embeddingBatteryThreshold &&
      !isCharging;
}

/// Throttle knobs applied to LLM + embedding background work.
final class InferenceExecutionProfile {
  const InferenceExecutionProfile({
    required this.canExecute,
    required this.maxTokens,
    required this.contextSize,
    required this.pauseEmbeddingTasks,
    required this.shouldQueueLlmJobs,
  });

  final bool canExecute;
  final int maxTokens;
  final int contextSize;
  final bool pauseEmbeddingTasks;
  final bool shouldQueueLlmJobs;

  static const unrestricted = InferenceExecutionProfile(
    canExecute: true,
    maxTokens: LocalLlmModelContract.sharedProductionMaxTokens,
    contextSize: LocalLlmWorkerLoadPolicy.maxContextTokens,
    pauseEmbeddingTasks: false,
    shouldQueueLlmJobs: false,
  );

  static const throttled = InferenceExecutionProfile(
    canExecute: true,
    maxTokens: 96,
    contextSize: 512,
    pauseEmbeddingTasks: true,
    shouldQueueLlmJobs: false,
  );

  static const queued = InferenceExecutionProfile(
    canExecute: false,
    maxTokens: 0,
    contextSize: LocalLlmWorkerLoadPolicy.maxContextTokens,
    pauseEmbeddingTasks: true,
    shouldQueueLlmJobs: true,
  );
}

typedef LlmBackgroundJob = Future<void> Function();

/// FIFO queue for deferred LLM jobs resumed when hardware constraints ease.
final class ResourceGuardLlmJobQueue {
  final List<LlmBackgroundJob> _pending = [];
  var _flushing = false;

  int get pendingCount => _pending.length;

  void enqueue(LlmBackgroundJob job) {
    _pending.add(job);
  }

  Future<int> flushIfAllowed(ResourceGuard guard) async {
    if (_pending.isEmpty || _flushing) return 0;
    _flushing = true;
    var flushed = 0;
    try {
      while (_pending.isNotEmpty) {
        final profile = await guard.buildInferenceProfile();
        if (profile.shouldQueueLlmJobs || !profile.canExecute) break;
        final job = _pending.removeAt(0);
        await job();
        flushed++;
      }
    } finally {
      _flushing = false;
    }
    return flushed;
  }

  @visibleForTesting
  void clear() => _pending.clear();
}

/// Monitors battery/thermal signals and gates heavy on-device inference.
final class ResourceGuard {
  ResourceGuard({
    BatteryReader? batteryReader,
    ThermalStatusReader? thermalReader,
  }) : _battery = batteryReader ?? BatteryPlusReader(),
       _thermalReader = thermalReader ?? HardwareMonitorChannel();

  static ResourceGuard? _sharedInstance;
  static ResourceGuard get shared => _sharedInstance ??= ResourceGuard();

  static const inferenceBatteryThreshold = 20;
  static const embeddingBatteryThreshold = 50;

  final BatteryReader _battery;
  final ThermalStatusReader _thermalReader;
  final ResourceGuardLlmJobQueue llmJobQueue = ResourceGuardLlmJobQueue();

  StreamSubscription<BatteryState>? _batterySubscription;
  Timer? _thermalPollTimer;

  /// Test override for forced deferral without querying platform APIs.
  bool? debugForceDeferEmbedding;
  DeviceThermalStatus? debugThermalStatus;

  Future<HardwareResourceSnapshot> currentSnapshot() async {
    final level = await _readBatteryLevel();
    final state = await _readBatteryState();
    final isCharging = _isExternalPower(state);
    final thermal = await _readThermalStatus();
    return HardwareResourceSnapshot(
      batteryLevel: level,
      batteryState: state,
      isCharging: isCharging,
      thermalStatus: thermal,
    );
  }

  Future<InferenceExecutionProfile> buildInferenceProfile() async {
    final snapshot = await currentSnapshot();

    if (snapshot.thermalStatus.isCritical ||
        snapshot.isBatteryLowForInference) {
      return InferenceExecutionProfile.queued;
    }

    if (snapshot.thermalStatus.indicatesThrottling ||
        snapshot.shouldDeferEmbedding) {
      return InferenceExecutionProfile.throttled;
    }

    return InferenceExecutionProfile.unrestricted;
  }

  /// Returns true when LLM inference may run now (possibly throttled).
  Future<bool> canExecuteInference() async {
    final profile = await buildInferenceProfile();
    return profile.canExecute && !profile.shouldQueueLlmJobs;
  }

  Future<bool> shouldDeferEmbeddingWork() async {
    final forced = debugForceDeferEmbedding;
    if (forced != null) return forced;

    final snapshot = await currentSnapshot();
    final profile = await buildInferenceProfile();
    return snapshot.shouldDeferEmbedding || profile.pauseEmbeddingTasks;
  }

  /// Enqueues LLM work when constraints require deferral.
  Future<void> runOrQueueLlmJob(LlmBackgroundJob job) async {
    final profile = await buildInferenceProfile();
    if (profile.shouldQueueLlmJobs) {
      llmJobQueue.enqueue(job);
      return;
    }
    await job();
  }

  void startMonitoring({
    required Future<void> Function() onConditionsNormalized,
    Duration thermalPollInterval = const Duration(seconds: 30),
  }) {
    _batterySubscription?.cancel();
    _batterySubscription = _battery.onBatteryStateChanged.listen((_) async {
      await _maybeResume(onConditionsNormalized);
    });

    _thermalPollTimer?.cancel();
    _thermalPollTimer = Timer.periodic(thermalPollInterval, (_) async {
      await _maybeResume(onConditionsNormalized);
    });
  }

  Future<void> _maybeResume(
    Future<void> Function() onConditionsNormalized,
  ) async {
    final profile = await buildInferenceProfile();
    final deferEmbedding = await shouldDeferEmbeddingWork();

    if (profile.shouldQueueLlmJobs && deferEmbedding) return;

    if (!deferEmbedding) {
      await onConditionsNormalized();
    }
    if (!profile.shouldQueueLlmJobs) {
      await llmJobQueue.flushIfAllowed(this);
    }
  }

  void dispose() {
    _batterySubscription?.cancel();
    _batterySubscription = null;
    _thermalPollTimer?.cancel();
    _thermalPollTimer = null;
  }

  Future<int> _readBatteryLevel() async {
    try {
      return await _battery.batteryLevel;
    } on Object {
      return -1;
    }
  }

  Future<BatteryState> _readBatteryState() async {
    try {
      return await _battery.batteryState;
    } on Object {
      return BatteryState.unknown;
    }
  }

  Future<DeviceThermalStatus> _readThermalStatus() async {
    final debug = debugThermalStatus;
    if (debug != null) return debug;
    return _thermalReader.readThermalStatus();
  }

  static bool _isExternalPower(BatteryState state) {
    return state == BatteryState.charging ||
        state == BatteryState.full ||
        state == BatteryState.connectedNotCharging;
  }
}
