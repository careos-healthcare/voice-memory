import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:thermal/thermal.dart';

enum OffloadPolicyState {
  forceOffload('force_offload'),
  preferLocal('prefer_local'),
  loadBalance('load_balance'),
  haltCompute('halt_compute');

  const OffloadPolicyState(this.wireName);
  final String wireName;
}

enum OffloadThermalState {
  nominal,
  fair,
  serious,
  critical,
  unavailable;

  bool get mustHalt =>
      this == OffloadThermalState.serious ||
      this == OffloadThermalState.critical;
}

enum BatteryTrajectory { charging, stable, draining, low, critical, unknown }

enum AnchorPingState { unavailable, healthy, degraded }

final class OffloadPolicySnapshot {
  const OffloadPolicySnapshot({
    required this.policy,
    required this.thermal,
    required this.batteryPercent,
    required this.batteryTrajectory,
    required this.isCharging,
    required this.isWifiConnected,
    required this.anchorPingState,
    required this.anchorPing,
    required this.updatedAt,
  });

  factory OffloadPolicySnapshot.initial() => OffloadPolicySnapshot(
    policy: OffloadPolicyState.preferLocal,
    thermal: OffloadThermalState.unavailable,
    batteryPercent: -1,
    batteryTrajectory: BatteryTrajectory.unknown,
    isCharging: false,
    isWifiConnected: false,
    anchorPingState: AnchorPingState.unavailable,
    anchorPing: null,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  final OffloadPolicyState policy;
  final OffloadThermalState thermal;
  final int batteryPercent;
  final BatteryTrajectory batteryTrajectory;
  final bool isCharging;
  final bool isWifiConnected;
  final AnchorPingState anchorPingState;
  final Duration? anchorPing;
  final DateTime updatedAt;

  bool get anchorAvailable => anchorPingState != AnchorPingState.unavailable;
}

final class OffloadPolicyEngine {
  OffloadPolicyEngine._platform({
    Battery? battery,
    Connectivity? connectivity,
    Thermal? thermal,
    DateTime Function()? clock,
  }) : _battery = battery ?? Battery(),
       _connectivity = connectivity ?? Connectivity(),
       _thermal = thermal ?? Thermal(),
       _clock = clock ?? DateTime.now,
       _platformEnabled = true;

  OffloadPolicyEngine.forTesting({
    OffloadPolicySnapshot? initial,
    DateTime Function()? clock,
  }) : _battery = null,
       _connectivity = null,
       _thermal = null,
       _clock = clock ?? DateTime.now,
       _platformEnabled = false,
       _current = initial ?? OffloadPolicySnapshot.initial();

  static final OffloadPolicyEngine instance = OffloadPolicyEngine._platform();

  final Battery? _battery;
  final Connectivity? _connectivity;
  final Thermal? _thermal;
  final DateTime Function() _clock;
  final bool _platformEnabled;
  final StreamController<OffloadPolicySnapshot> _snapshots =
      StreamController<OffloadPolicySnapshot>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final List<(DateTime, int)> _batteryHistory = [];
  OffloadPolicySnapshot _current = OffloadPolicySnapshot.initial();
  Timer? _batteryPoll;
  bool _initialized = false;

  OffloadPolicySnapshot get current => _current;
  Stream<OffloadPolicySnapshot> get snapshots => _snapshots.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (!_platformEnabled) return;
    final battery = _battery!;
    final connectivity = _connectivity!;
    final thermal = _thermal!;
    _subscriptions.add(
      battery.onBatteryStateChanged.listen(
        (state) => unawaited(_sampleBattery(state)),
        onError: (_) {},
      ),
    );
    _subscriptions.add(
      connectivity.onConnectivityChanged.listen(
        updateConnectivity,
        onError: (_) => updateConnectivity(const [ConnectivityResult.none]),
      ),
    );
    _subscriptions.add(
      thermal.onThermalStatusChanged.listen(
        updateThermalStatus,
        onError: (_) => updateThermal(OffloadThermalState.unavailable),
      ),
    );
    try {
      await _sampleBattery(await battery.batteryState);
    } on MissingPluginException {
      updateBattery(level: -1, state: BatteryState.unknown);
    } on PlatformException {
      updateBattery(level: -1, state: BatteryState.unknown);
    }
    try {
      updateConnectivity(await connectivity.checkConnectivity());
    } on Object {
      updateConnectivity(const [ConnectivityResult.none]);
    }
    try {
      updateThermalStatus(await thermal.thermalStatus);
    } on Object {
      updateThermal(OffloadThermalState.unavailable);
    }
    _batteryPoll = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(_sampleBattery()),
    );
  }

  Future<void> _sampleBattery([BatteryState? knownState]) async {
    final battery = _battery;
    if (battery == null) return;
    try {
      updateBattery(
        level: await battery.batteryLevel,
        state: knownState ?? await battery.batteryState,
      );
    } on Object {
      updateBattery(level: -1, state: BatteryState.unknown);
    }
  }

  void updateBattery({required int level, required BatteryState state}) {
    final now = _clock().toUtc();
    final bounded = level < 0 ? -1 : level.clamp(0, 100);
    if (bounded >= 0) {
      _batteryHistory.add((now, bounded));
      _batteryHistory.removeWhere(
        (sample) => now.difference(sample.$1) > const Duration(minutes: 15),
      );
    }
    final charging =
        state == BatteryState.charging || state == BatteryState.full;
    _replace(
      batteryPercent: bounded,
      isCharging: charging,
      batteryTrajectory: _trajectory(bounded, charging),
    );
  }

  void updateThermalStatus(ThermalStatus status) {
    updateThermal(switch (status) {
      ThermalStatus.none => OffloadThermalState.nominal,
      ThermalStatus.light || ThermalStatus.moderate => OffloadThermalState.fair,
      // iOS serious and Android SEVERE both map to `severe`.
      ThermalStatus.severe => OffloadThermalState.serious,
      ThermalStatus.critical ||
      ThermalStatus.emergency ||
      ThermalStatus.shutdown => OffloadThermalState.critical,
    });
  }

  void updateThermal(OffloadThermalState state) {
    _replace(thermal: state);
  }

  void updateConnectivity(List<ConnectivityResult> values) {
    _replace(isWifiConnected: values.contains(ConnectivityResult.wifi));
  }

  void updateAnchorPing(Duration? ping, {required bool connected}) {
    final state = !connected || ping == null
        ? AnchorPingState.unavailable
        : ping <= const Duration(milliseconds: 150)
        ? AnchorPingState.healthy
        : AnchorPingState.degraded;
    _replace(anchorPing: ping, anchorPingState: state);
  }

  BatteryTrajectory _trajectory(int level, bool charging) {
    if (charging) return BatteryTrajectory.charging;
    if (level < 0) return BatteryTrajectory.unknown;
    if (level <= 10) return BatteryTrajectory.critical;
    if (level <= 25) return BatteryTrajectory.low;
    if (_batteryHistory.length >= 2 &&
        _batteryHistory.last.$2 < _batteryHistory.first.$2) {
      return BatteryTrajectory.draining;
    }
    return BatteryTrajectory.stable;
  }

  OffloadPolicyState _decide({
    required OffloadThermalState thermal,
    required int batteryPercent,
    required BatteryTrajectory trajectory,
    required bool charging,
    required bool wifi,
    required AnchorPingState anchor,
  }) {
    if (thermal.mustHalt) return OffloadPolicyState.haltCompute;
    final healthyAnchor = wifi && anchor == AnchorPingState.healthy;
    if (!charging && batteryPercent >= 0 && batteryPercent <= 10) {
      return healthyAnchor
          ? OffloadPolicyState.forceOffload
          : OffloadPolicyState.haltCompute;
    }
    if (healthyAnchor &&
        (thermal == OffloadThermalState.fair ||
            trajectory == BatteryTrajectory.low ||
            trajectory == BatteryTrajectory.draining)) {
      return OffloadPolicyState.forceOffload;
    }
    if (healthyAnchor) return OffloadPolicyState.loadBalance;
    return OffloadPolicyState.preferLocal;
  }

  void _replace({
    OffloadThermalState? thermal,
    int? batteryPercent,
    BatteryTrajectory? batteryTrajectory,
    bool? isCharging,
    bool? isWifiConnected,
    AnchorPingState? anchorPingState,
    Duration? anchorPing,
  }) {
    final nextThermal = thermal ?? _current.thermal;
    final nextBattery = batteryPercent ?? _current.batteryPercent;
    final nextTrajectory = batteryTrajectory ?? _current.batteryTrajectory;
    final nextCharging = isCharging ?? _current.isCharging;
    final nextWifi = isWifiConnected ?? _current.isWifiConnected;
    final nextAnchor = anchorPingState ?? _current.anchorPingState;
    final nextPing = anchorPingState == AnchorPingState.unavailable
        ? null
        : anchorPing ?? _current.anchorPing;
    _current = OffloadPolicySnapshot(
      policy: _decide(
        thermal: nextThermal,
        batteryPercent: nextBattery,
        trajectory: nextTrajectory,
        charging: nextCharging,
        wifi: nextWifi,
        anchor: nextAnchor,
      ),
      thermal: nextThermal,
      batteryPercent: nextBattery,
      batteryTrajectory: nextTrajectory,
      isCharging: nextCharging,
      isWifiConnected: nextWifi,
      anchorPingState: nextAnchor,
      anchorPing: nextPing,
      updatedAt: _clock().toUtc(),
    );
    _snapshots.add(_current);
  }

  Future<void> stop() async {
    _batteryPoll?.cancel();
    _batteryPoll = null;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _initialized = false;
  }

  Future<void> dispose() async {
    await stop();
    await _snapshots.close();
  }
}
