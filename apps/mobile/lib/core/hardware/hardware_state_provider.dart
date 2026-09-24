import 'package:archiveme_mobile/core/hardware/hardware_monitor_channel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Battery, charging, and thermal reading from `com.archiveme/hardware_monitor`.
class HardwareSnapshot {
  const HardwareSnapshot({
    required this.batteryPercent,
    required this.isCharging,
    required this.thermalStatus,
  });

  final int batteryPercent;
  final bool isCharging;
  final DeviceThermalStatus thermalStatus;

  static const relaxed = HardwareSnapshot(
    batteryPercent: 100,
    isCharging: true,
    thermalStatus: DeviceThermalStatus.nominal,
  );

  bool get shouldDeferHeavyWork => !isCharging && thermalStatus.isHigh;

  static HardwareSnapshot fromMap(Map<Object?, Object?> raw) {
    final percent = raw['batteryPercent'];
    final charging = raw['isCharging'];
    return HardwareSnapshot(
      batteryPercent: percent is int
          ? percent
          : percent is num
          ? percent.round()
          : -1,
      isCharging: charging == true,
      thermalStatus: DeviceThermalStatus.parse(
        raw['thermalStatus']?.toString(),
      ),
    );
  }
}

/// Holds sherpa and Gemma jobs until the device is charging or the user forces them.
class HeavyWorkScheduler {
  final List<Future<void> Function()> _pending = [];

  int get pendingCount => _pending.length;

  Future<T> run<T>({
    required HardwareSnapshot snapshot,
    required bool forceImmediate,
    required Future<T> Function() task,
    required T deferredValue,
  }) async {
    if (!forceImmediate && snapshot.shouldDeferHeavyWork) {
      _pending.add(() async {
        await task();
      });
      return deferredValue;
    }
    return task();
  }

  Future<int> flush(HardwareSnapshot snapshot) async {
    if (snapshot.shouldDeferHeavyWork) return 0;
    var flushed = 0;
    while (_pending.isNotEmpty) {
      final job = _pending.removeAt(0);
      await job();
      flushed++;
    }
    return flushed;
  }

  @visibleForTesting
  void clear() => _pending.clear();
}

class HardwareStateNotifier extends Notifier<HardwareSnapshot> {
  HardwareStateNotifier({
    MethodChannel? channel,
    HeavyWorkScheduler? scheduler,
  }) : _channel = channel ?? const MethodChannel(channelName),
       scheduler = scheduler ?? HeavyWorkScheduler();

  static const channelName = 'com.archiveme/hardware_monitor';

  final MethodChannel _channel;
  final HeavyWorkScheduler scheduler;

  @override
  HardwareSnapshot build() => HardwareSnapshot.relaxed;

  Future<void> refresh() async {
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getHardwareSnapshot',
      );
      if (raw == null) return;
      state = HardwareSnapshot.fromMap(raw);
      await scheduler.flush(state);
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}

final hardwareStateProvider =
    NotifierProvider<HardwareStateNotifier, HardwareSnapshot>(
      HardwareStateNotifier.new,
    );
