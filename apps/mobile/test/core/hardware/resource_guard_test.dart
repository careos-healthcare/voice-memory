import 'package:archiveme_mobile/core/hardware/hardware_monitor_channel.dart';
import 'package:archiveme_mobile/core/hardware/resource_guard.dart';
import 'package:archiveme_mobile/services/thermal_throttling/thermal_throttling_service.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ResourceGuard', () {
    test('queues inference below 20% battery while unplugged', () async {
      final guard = ResourceGuard(
        batteryReader: _FakeBatteryReader(
          level: 15,
          state: BatteryState.discharging,
        ),
        thermalReader: _FakeThermalReader(DeviceThermalStatus.nominal),
      );

      final profile = await guard.buildInferenceProfile();

      expect(profile.shouldQueueLlmJobs, isTrue);
      expect(await guard.canExecuteInference(), isFalse);
    });

    test('allows inference when charging below 20%', () async {
      final guard = ResourceGuard(
        batteryReader: _FakeBatteryReader(
          level: 12,
          state: BatteryState.charging,
        ),
        thermalReader: _FakeThermalReader(DeviceThermalStatus.nominal),
      );

      expect(await guard.canExecuteInference(), isTrue);
    });

    test('throttles tokens and pauses embeddings on fair thermal status', () async {
      final guard = ResourceGuard(
        batteryReader: _FakeBatteryReader(
          level: 80,
          state: BatteryState.discharging,
        ),
        thermalReader: _FakeThermalReader(DeviceThermalStatus.fair),
      );

      final profile = await guard.buildInferenceProfile();

      expect(profile.canExecute, isTrue);
      expect(profile.maxTokens, InferenceExecutionProfile.throttled.maxTokens);
      expect(profile.pauseEmbeddingTasks, isTrue);
      expect(await guard.shouldDeferEmbeddingWork(), isTrue);
    });

    test('defers embedding below 50% battery', () async {
      final guard = ResourceGuard(
        batteryReader: _FakeBatteryReader(
          level: 35,
          state: BatteryState.discharging,
        ),
        thermalReader: _FakeThermalReader(DeviceThermalStatus.nominal),
      );

      expect(await guard.shouldDeferEmbeddingWork(), isTrue);
      final profile = await guard.buildInferenceProfile();
      expect(profile.pauseEmbeddingTasks, isTrue);
    });

    test('llm job queue resumes when constraints normalize', () async {
      final battery = _FakeBatteryReader(
        level: 12,
        state: BatteryState.discharging,
      );
      final guard = ResourceGuard(
        batteryReader: battery,
        thermalReader: _FakeThermalReader(DeviceThermalStatus.nominal),
      );

      var executed = false;
      guard.llmJobQueue.enqueue(() async {
        executed = true;
      });

      expect(await guard.llmJobQueue.flushIfAllowed(guard), 0);

      battery.state = BatteryState.charging;
      expect(await guard.llmJobQueue.flushIfAllowed(guard), 1);
      expect(executed, isTrue);
    });
  });

  group('ThermalThrottlingService facade', () {
    test('delegates embedding deferral to ResourceGuard', () async {
      final guard = ResourceGuard(
        batteryReader: _FakeBatteryReader(
          level: 35,
          state: BatteryState.discharging,
        ),
        thermalReader: _FakeThermalReader(DeviceThermalStatus.nominal),
      );
      final service = ThermalThrottlingService(resourceGuard: guard);

      expect(await service.shouldDeferEmbeddingWork(), isTrue);
    });
  });
}

final class _FakeBatteryReader implements BatteryReader {
  _FakeBatteryReader({required this.level, required this.state});

  int level;
  BatteryState state;

  @override
  Future<int> get batteryLevel async => level;

  @override
  Future<BatteryState> get batteryState async => state;

  @override
  Stream<BatteryState> get onBatteryStateChanged => const Stream.empty();
}

final class _FakeThermalReader implements ThermalStatusReader {
  _FakeThermalReader(this.status);

  DeviceThermalStatus status;

  @override
  Future<DeviceThermalStatus> readThermalStatus() async => status;
}
