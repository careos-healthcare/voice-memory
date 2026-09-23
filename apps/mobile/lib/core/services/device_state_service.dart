import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Power and network flags that gate heavy background work.
@immutable
class DeviceConditions {
  const DeviceConditions({
    required this.isCharging,
    required this.isWifiConnected,
  });

  final bool isCharging;
  final bool isWifiConnected;

  /// Vector indexing and mesh sync run when the device is charging or on Wi-Fi.
  bool get hasWiFi => isWifiConnected;

  bool get allowsHeavyWork => isCharging || hasWiFi;
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
  PlatformDeviceState({Battery? battery, Connectivity? connectivity})
    : _battery = battery ?? Battery(),
      _connectivity = connectivity ?? Connectivity();

  final Battery _battery;
  final Connectivity _connectivity;

  @override
  Future<DeviceConditions> current() async {
    final state = await _battery.batteryState;
    final links = await _connectivity.checkConnectivity();
    return DeviceConditions(
      isCharging: _isCharging(state),
      isWifiConnected: links.contains(ConnectivityResult.wifi),
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

  DeviceConditions latest = const DeviceConditions(
    isCharging: false,
    isWifiConnected: false,
  );

  Future<DeviceConditions> refresh() async => latest = await _source.current();

  Stream<DeviceConditions> watch() async* {
    latest = await refresh();
    yield latest;
    yield* _source.changes.map((next) {
      latest = next;
      return next;
    });
  }
}
