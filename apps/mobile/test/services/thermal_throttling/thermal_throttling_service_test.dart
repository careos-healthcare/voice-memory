import 'package:archiveme_mobile/core/hardware/hardware_monitor_channel.dart';
import 'package:archiveme_mobile/core/hardware/resource_guard.dart';
import 'package:archiveme_mobile/services/thermal_throttling/thermal_throttling_service.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ThermalThrottlingService', () {
    test('defers embedding when battery is below 50% and not charging', () async {
      final service = ThermalThrottlingService(
        resourceGuard: ResourceGuard(
          batteryReader: _FakeBatteryReader(
            level: 35,
            state: BatteryState.discharging,
          ),
          thermalReader: _FakeThermalReader(DeviceThermalStatus.nominal),
        ),
      );

      final snapshot = await service.currentSnapshot();

      expect(snapshot.level, 35);
      expect(snapshot.isCharging, isFalse);
      expect(snapshot.shouldDeferEmbedding, isTrue);
      expect(await service.shouldDeferEmbeddingWork(), isTrue);
    });

    test('allows embedding when charging even below 50%', () async {
      final service = ThermalThrottlingService(
        resourceGuard: ResourceGuard(
          batteryReader: _FakeBatteryReader(
            level: 20,
            state: BatteryState.charging,
          ),
          thermalReader: _FakeThermalReader(DeviceThermalStatus.nominal),
        ),
      );

      final snapshot = await service.currentSnapshot();

      expect(snapshot.isCharging, isTrue);
      expect(snapshot.shouldDeferEmbedding, isFalse);
      expect(await service.shouldDeferEmbeddingWork(), isFalse);
    });

    test('allows embedding when plugged in but not actively charging', () async {
      final service = ThermalThrottlingService(
        resourceGuard: ResourceGuard(
          batteryReader: _FakeBatteryReader(
            level: 30,
            state: BatteryState.connectedNotCharging,
          ),
          thermalReader: _FakeThermalReader(DeviceThermalStatus.nominal),
        ),
      );

      expect(await service.shouldDeferEmbeddingWork(), isFalse);
    });

    test('allows embedding when battery is at or above 50%', () async {
      final service = ThermalThrottlingService(
        resourceGuard: ResourceGuard(
          batteryReader: _FakeBatteryReader(
            level: 72,
            state: BatteryState.discharging,
          ),
          thermalReader: _FakeThermalReader(DeviceThermalStatus.nominal),
        ),
      );

      expect(await service.shouldDeferEmbeddingWork(), isFalse);
    });
  });
}

final class _FakeBatteryReader implements BatteryReader {
  _FakeBatteryReader({required this.level, required this.state});

  final int level;
  final BatteryState state;

  @override
  Future<int> get batteryLevel async => level;

  @override
  Future<BatteryState> get batteryState async => state;

  @override
  Stream<BatteryState> get onBatteryStateChanged => const Stream.empty();
}

final class _FakeThermalReader implements ThermalStatusReader {
  _FakeThermalReader(this.status);

  final DeviceThermalStatus status;

  @override
  Future<DeviceThermalStatus> readThermalStatus() async => status;
}
