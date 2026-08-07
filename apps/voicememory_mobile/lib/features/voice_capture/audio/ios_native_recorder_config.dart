import 'package:flutter/foundation.dart';

import '../microphone_permission_environment.dart';

/// Native iOS capture file format for physical-device debugging.
enum IosRecordingFormat { wav, aac }

/// Feature flags for native iOS AVAudioRecorder capture on physical devices.
abstract class IosNativeRecorderConfig {
  IosNativeRecorderConfig._();

  static const _nativeEnvKey = 'ARCHIVEME_USE_NATIVE_IOS_RECORDER';
  static const _formatEnvKey = 'ARCHIVEME_IOS_RECORDING_FORMAT';

  /// Defaults to true unless explicitly disabled via dart-define.
  static bool get enabled {
    return const bool.fromEnvironment(_nativeEnvKey, defaultValue: true);
  }

  static IosRecordingFormat? get formatOverride {
    const fromEnv = String.fromEnvironment(_formatEnvKey, defaultValue: '');
    switch (fromEnv.toLowerCase()) {
      case 'wav':
        return IosRecordingFormat.wav;
      case 'aac':
      case 'm4a':
        return IosRecordingFormat.aac;
      default:
        return null;
    }
  }

  /// Physical iPad debug defaults to WAV when native recorder is enabled.
  static Future<IosRecordingFormat> recordingFormatForDevice({
    Future<bool> Function()? isPhysicalDevice,
    bool? debugMode,
  }) async {
    final override = formatOverride;
    if (override != null) return override;

    final isDebug = debugMode ?? kDebugMode;
    final isPhysical = isPhysicalDevice != null
        ? await isPhysicalDevice()
        : await MicrophonePermissionEnvironment.isIosPhysicalDevice();
    if (enabled && isDebug && isPhysical) {
      return IosRecordingFormat.wav;
    }
    return IosRecordingFormat.aac;
  }

  static String fileExtensionFor(IosRecordingFormat format) {
    switch (format) {
      case IosRecordingFormat.wav:
        return 'wav';
      case IosRecordingFormat.aac:
        return 'm4a';
    }
  }

  static String channelFormatValue(IosRecordingFormat format) {
    switch (format) {
      case IosRecordingFormat.wav:
        return 'wav';
      case IosRecordingFormat.aac:
        return 'aac';
    }
  }
}
