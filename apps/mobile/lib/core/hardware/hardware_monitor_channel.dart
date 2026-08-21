import 'package:flutter/services.dart';

/// Native thermal status surfaced by platform method channels.
enum DeviceThermalStatus {
  unknown,
  nominal,
  fair,
  moderate,
  serious,
  severe,
  critical;

  bool get indicatesThrottling {
    return switch (this) {
      DeviceThermalStatus.fair ||
      DeviceThermalStatus.moderate ||
      DeviceThermalStatus.serious ||
      DeviceThermalStatus.severe ||
      DeviceThermalStatus.critical => true,
      _ => false,
    };
  }

  bool get isCritical {
    return switch (this) {
      DeviceThermalStatus.severe ||
      DeviceThermalStatus.critical => true,
      _ => false,
    };
  }

  static DeviceThermalStatus parse(String? raw) {
    return switch (raw?.toLowerCase()) {
      'nominal' => DeviceThermalStatus.nominal,
      'fair' || 'light' => DeviceThermalStatus.fair,
      'moderate' => DeviceThermalStatus.moderate,
      'serious' => DeviceThermalStatus.serious,
      'severe' => DeviceThermalStatus.severe,
      'critical' || 'emergency' || 'shutdown' => DeviceThermalStatus.critical,
      _ => DeviceThermalStatus.unknown,
    };
  }
}

/// Reads device thermal state from Android/iOS native channels.
abstract interface class ThermalStatusReader {
  Future<DeviceThermalStatus> readThermalStatus();
}

final class HardwareMonitorChannel implements ThermalStatusReader {
  HardwareMonitorChannel({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'archive_me/hardware_monitor';

  final MethodChannel _channel;

  @override
  Future<DeviceThermalStatus> readThermalStatus() async {
    try {
      final raw = await _channel.invokeMethod<String>('getThermalStatus');
      return DeviceThermalStatus.parse(raw);
    } on Object {
      return DeviceThermalStatus.unknown;
    }
  }
}
