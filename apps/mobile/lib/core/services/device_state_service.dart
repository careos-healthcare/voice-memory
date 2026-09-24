import 'dart:async';

import 'package:archiveme_mobile/core/hardware/hardware_monitor_channel.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Power, idle, and thermal flags that gate heavy background work.
@immutable
class DeviceConditions {
  const DeviceConditions({
    required this.isCharging,
    required this.isWifiConnected,
    this.isIdle = false,
    this.batteryLevel = 100,
    this.thermalStatus = DeviceThermalStatus.nominal,
  });

  /// Percent at or above which on-device work may run while charging.
  static const safeBatteryPercent = 20;

  final bool isCharging;
  final bool isWifiConnected;
  final bool isIdle;
  final int batteryLevel;
  final DeviceThermalStatus thermalStatus;

  /// Vector indexing and mesh sync run when the device is charging or on Wi-Fi.
  bool get hasWiFi => isWifiConnected;

  bool get allowsHeavyWork => isCharging || hasWiFi;

  /// Unknown readings (`< 0`) do not block work.
  bool get batteryIsSafe =>
      batteryLevel < 0 || batteryLevel >= safeBatteryPercent;

  /// Serious heat and above pauses coaching, storage, and transcription.
  bool get thermalAllowsWork => !thermalStatus.isHigh;

  /// Pattern synthesis and on-device transcription need a quiet, powered device.
  bool get allowsPatternAndTranscription =>
      isIdle && isCharging && batteryIsSafe && thermalAllowsWork;

  DeviceConditions copyWith({
    bool? isCharging,
    bool? isWifiConnected,
    bool? isIdle,
    int? batteryLevel,
    DeviceThermalStatus? thermalStatus,
  }) {
    return DeviceConditions(
      isCharging: isCharging ?? this.isCharging,
      isWifiConnected: isWifiConnected ?? this.isWifiConnected,
      isIdle: isIdle ?? this.isIdle,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      thermalStatus: thermalStatus ?? this.thermalStatus,
    );
  }
}

/// Latest charging and Wi-Fi readings.
abstract class DeviceStateSource {
  Future<DeviceConditions> current();

  Stream<DeviceConditions> get changes;
}

/// Test double that emits conditions without platform channels.
class ManualDeviceState implements DeviceStateSource {
  ManualDeviceState(this._current);

  DeviceConditions _current;

  final List<void Function(DeviceConditions)> _listeners = [];

  @override
  Future<DeviceConditions> current() async => _current;

  @override
  Stream<DeviceConditions> get changes {
    late StreamController<DeviceConditions> controller;
    controller = StreamController<DeviceConditions>.broadcast(
      onListen: () {
        void forward(DeviceConditions next) {
          if (!controller.isClosed) controller.add(next);
        }

        _listeners.add(forward);
        controller.onCancel = () => _listeners.remove(forward);
      },
    );
    return controller.stream;
  }

  void emit(DeviceConditions next) {
    _current = next;
    for (final listener in List<void Function(DeviceConditions)>.of(
      _listeners,
    )) {
      listener(next);
    }
  }
}

/// `battery_plus` and `connectivity_plus` readings for the scheduler.
class PlatformDeviceState implements DeviceStateSource {
  PlatformDeviceState({
    Battery? battery,
    Connectivity? connectivity,
    Future<int> Function()? readBatteryLevel,
    Future<DeviceThermalStatus> Function()? readThermalStatus,
  }) : _battery = battery ?? Battery(),
       _connectivity = connectivity ?? Connectivity(),
       _readBatteryLevel = readBatteryLevel,
       _readThermalStatus = readThermalStatus;

  final Battery _battery;
  final Connectivity _connectivity;
  final Future<int> Function()? _readBatteryLevel;
  final Future<DeviceThermalStatus> Function()? _readThermalStatus;

  @override
  Future<DeviceConditions> current() async {
    final state = await _battery.batteryState;
    final links = await _connectivity.checkConnectivity();
    final level = _readBatteryLevel != null
        ? await _readBatteryLevel!()
        : await _battery.batteryLevel;
    final thermal = _readThermalStatus != null
        ? await _readThermalStatus!()
        : await HardwareMonitorChannel().readThermalStatus();
    return DeviceConditions(
      isCharging: _isCharging(state),
      isWifiConnected: links.contains(ConnectivityResult.wifi),
      batteryLevel: level,
      thermalStatus: thermal,
    );
  }

  @override
  Stream<DeviceConditions> get changes async* {
    yield await current();
    yield* _battery.onBatteryStateChanged.asyncMap((_) => current());
  }

  static bool _isCharging(BatteryState state) {
    return state == BatteryState.charging || state == BatteryState.full;
  }
}

/// Remembers the latest device conditions for the background scheduler.
class DeviceStateService {
  DeviceStateService({DeviceStateSource? source})
    : _source = source ?? PlatformDeviceState();

  final DeviceStateSource _source;
  var _idle = false;

  DeviceConditions latest = const DeviceConditions(
    isCharging: false,
    isWifiConnected: false,
  );

  /// Marks the device idle when the app is not in the foreground.
  void setIdle(bool idle) {
    _idle = idle;
    latest = latest.copyWith(isIdle: idle);
  }

  Future<DeviceConditions> refresh() async {
    final next = await _source.current();
    latest = next.copyWith(isIdle: _idle || next.isIdle);
    return latest;
  }

  Stream<DeviceConditions> watch() async* {
    latest = await refresh();
    yield latest;
    yield* _source.changes.map((next) {
      latest = next.copyWith(isIdle: _idle || next.isIdle);
      return latest;
    });
  }
}
