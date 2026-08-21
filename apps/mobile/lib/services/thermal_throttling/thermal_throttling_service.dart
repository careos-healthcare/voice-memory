import 'package:archiveme_mobile/core/hardware/resource_guard.dart';
import 'package:battery_plus/battery_plus.dart';

/// Snapshot of battery constraints relevant to deferring heavy background work.
final class BatteryResourceSnapshot {
  const BatteryResourceSnapshot({
    required this.level,
    required this.state,
    required this.isCharging,
    required this.shouldDeferEmbedding,
  });

  final int level;
  final BatteryState state;
  final bool isCharging;
  final bool shouldDeferEmbedding;
}

/// Minimal battery surface used by [ResourceGuard].
abstract interface class BatteryReader {
  Future<int> get batteryLevel;

  Future<BatteryState> get batteryState;

  Stream<BatteryState> get onBatteryStateChanged;
}

/// [BatteryReader] backed by [battery_plus].
final class BatteryPlusReader implements BatteryReader {
  BatteryPlusReader([Battery? battery]) : _battery = battery ?? Battery();

  final Battery _battery;

  @override
  Future<int> get batteryLevel => _battery.batteryLevel;

  @override
  Future<BatteryState> get batteryState => _battery.batteryState;

  @override
  Stream<BatteryState> get onBatteryStateChanged =>
      _battery.onBatteryStateChanged;
}

/// Backward-compatible facade over [ResourceGuard] for embedding deferral.
final class ThermalThrottlingService {
  ThermalThrottlingService({ResourceGuard? resourceGuard})
    : _guard = resourceGuard ?? ResourceGuard.shared;

  final ResourceGuard _guard;

  static int get deferBelowBatteryLevel =>
      ResourceGuard.embeddingBatteryThreshold;

  /// When true (tests only), forces embedding deferral without querying the platform.
  bool? get debugForceDeferEmbedding => _guard.debugForceDeferEmbedding;

  set debugForceDeferEmbedding(bool? value) {
    _guard.debugForceDeferEmbedding = value;
  }

  ResourceGuard get resourceGuard => _guard;

  Future<BatteryResourceSnapshot> currentSnapshot() async {
    final snapshot = await _guard.currentSnapshot();
    return BatteryResourceSnapshot(
      level: snapshot.batteryLevel,
      state: snapshot.batteryState,
      isCharging: snapshot.isCharging,
      shouldDeferEmbedding: snapshot.shouldDeferEmbedding,
    );
  }

  Future<bool> shouldDeferEmbeddingWork() => _guard.shouldDeferEmbeddingWork();

  void startMonitoring({required Future<void> Function() onPowerAvailable}) {
    _guard.startMonitoring(onConditionsNormalized: onPowerAvailable);
  }

  void dispose() {
    // Monitoring lifecycle is owned by [ResourceGuard.shared] in [AppServices].
  }
}
