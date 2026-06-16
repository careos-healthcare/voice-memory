/// Feature flag for native iOS AVAudioRecorder capture on physical devices.
abstract class IosNativeRecorderConfig {
  IosNativeRecorderConfig._();

  static const _envKey = 'ARCHIVEME_USE_NATIVE_IOS_RECORDER';

  /// Defaults to true unless explicitly disabled via dart-define.
  static bool get enabled {
    return const bool.fromEnvironment(_envKey, defaultValue: true);
  }
}
