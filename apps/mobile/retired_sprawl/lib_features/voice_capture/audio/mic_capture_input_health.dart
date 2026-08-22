import 'package:archiveme_mobile/features/voice_capture/audio/audio_diag_log.dart';

/// Diagnostics and user-facing guidance for native iOS capture input routes.
abstract class MicCaptureInputHealth {
  MicCaptureInputHealth._();

  static const builtInPortType = 'builtinmic';

  static bool isBuiltInMic({String? portType, String? portName}) {
    final type = portType?.toLowerCase().trim() ?? '';
    if (type == builtInPortType || type.contains('builtin')) {
      return true;
    }
    final name = portName?.toLowerCase().trim() ?? '';
    return name.contains('ipad microphone') || name == 'ipad microphone';
  }

  static bool isBluetoothOrHeadset({String? portType}) {
    final type = portType?.toLowerCase().trim() ?? '';
    return type.contains('bluetooth') || type == 'headsetmic';
  }

  static bool shouldShowBuiltInSilentGuidance({
    required bool likelySilent,
    String? portType,
    String? portName,
  }) => likelySilent && isBuiltInMic(portType: portType, portName: portName);

  static String? recommendation({
    required bool likelySilent,
    String? portType,
    String? portName,
  }) {
    if (shouldShowBuiltInSilentGuidance(
      likelySilent: likelySilent,
      portType: portType,
      portName: portName,
    )) {
      return 'bluetooth_or_type';
    }
    return null;
  }

  static String selectedLabel({String? portName, String? portType}) {
    final name = portName?.trim();
    final type = portType?.trim();
    if (name != null && name.isNotEmpty && type != null && type.isNotEmpty) {
      return '$name:$type';
    }
    if (name != null && name.isNotEmpty) return name;
    if (type != null && type.isNotEmpty) return type;
    return 'unknown';
  }

  /// Short debug label for post-save UI — e.g. "AirPods" or "iPad Microphone".
  static String? debugInputLabel({String? portName, String? portType}) {
    final name = portName?.trim() ?? '';
    final lowerName = name.toLowerCase();
    if (isBluetoothOrHeadset(portType: portType)) {
      if (lowerName.contains('airpods')) return 'AirPods';
      if (name.isNotEmpty) return name;
      return 'Bluetooth headset';
    }
    if (isBuiltInMic(portType: portType, portName: portName)) {
      return 'iPad Microphone';
    }
    if (name.isNotEmpty) return name;
    return null;
  }

  static void log({
    required bool likelySilent,
    String? portName,
    String? portType,
  }) {
    final selected = selectedLabel(portName: portName, portType: portType);
    final rec = recommendation(
      likelySilent: likelySilent,
      portType: portType,
      portName: portName,
    );
    AudioDiagLog.micInputHealth(
      selected: selected,
      likelySilent: likelySilent,
      recommendation: rec ?? 'none',
    );
  }
}