import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Resolves on-device storage paths with a debug iOS simulator fallback.
///
/// On iOS 26+ simulators, [path_provider_foundation] can crash during
/// [getApplicationDocumentsDirectory] before the first frame. Physical devices
/// and release builds always use the real platform directories.
abstract class AppStoragePaths {
  AppStoragePaths._();

  static const String simulatorFallbackLog =
      'ARCHIVEME_SIMULATOR_NATIVE_ASSETS: path_provider unavailable, using debug temp fallback';

  static bool? _simulatorFallbackUsed;
  static bool? _forceSimulatorFallback;

  /// Whether startup used the debug simulator documents fallback.
  static bool get usedSimulatorFallback => _simulatorFallbackUsed ?? false;

  /// Defer [AppServices.initialize] until after the first frame on debug iOS simulators.
  static Future<bool> shouldDeferLocalStorageUntilFirstFrame() async {
    if (kReleaseMode || kIsWeb || !Platform.isIOS) return false;
    return looksLikeIosSimulatorEnvironment() ||
        !(await _isPhysicalIosDevice());
  }

  /// Call before resolving storage paths when [shouldDeferLocalStorageUntilFirstFrame] is true.
  static Future<void> configureFromDeviceInfo() async {
    if (kReleaseMode || kIsWeb || !Platform.isIOS) {
      _forceSimulatorFallback = false;
      return;
    }
    if (looksLikeIosSimulatorEnvironment()) {
      _forceSimulatorFallback = true;
      return;
    }
    _forceSimulatorFallback = !(await _isPhysicalIosDevice());
  }

  static Future<bool> _isPhysicalIosDevice() async {
    final info = await DeviceInfoPlugin().deviceInfo;
    return switch (info) {
      IosDeviceInfo ios => ios.isPhysicalDevice,
      _ => true,
    };
  }

  static bool _shouldUseSimulatorFallback() {
    if (kReleaseMode || kIsWeb || !Platform.isIOS) return false;
    return _forceSimulatorFallback ?? looksLikeIosSimulatorEnvironment();
  }

  /// Heuristic iOS simulator detection without calling native device_info plugins.
  static bool isIosDebugSimulator() =>
      kDebugMode && looksLikeIosSimulatorEnvironment();

  @visibleForTesting
  static bool looksLikeIosSimulatorEnvironment({
    Map<String, String>? environment,
    bool isIos = true,
  }) {
    if (!isIos) return false;
    final env = environment ?? Platform.environment;
    final home = env['HOME'] ?? '';
    if (home.contains('CoreSimulator')) return true;
    if (env.containsKey('SIMULATOR_DEVICE_NAME')) return true;
    if (env.containsKey('SIMULATOR_UDID')) return true;
    if (env.containsKey('SIMULATOR_RUNTIME_VERSION')) return true;
    return false;
  }

  static Future<Directory> applicationDocumentsDirectory() async {
    if (kReleaseMode) {
      return getApplicationDocumentsDirectory();
    }
    if (_shouldUseSimulatorFallback()) {
      return debugSimulatorDocumentsDirectorySync();
    }
    try {
      return await getApplicationDocumentsDirectory();
    } catch (e) {
      if (kDebugMode && Platform.isIOS) {
        return debugSimulatorDocumentsDirectorySync(reason: e);
      }
      rethrow;
    }
  }

  static Future<Directory> temporaryDirectory() async {
    if (kReleaseMode) {
      return getTemporaryDirectory();
    }
    if (_shouldUseSimulatorFallback()) {
      return debugSimulatorTemporaryDirectorySync();
    }
    try {
      return await getTemporaryDirectory();
    } catch (e) {
      if (kDebugMode && Platform.isIOS) {
        return debugSimulatorTemporaryDirectorySync(reason: e);
      }
      rethrow;
    }
  }

  @visibleForTesting
  static Directory debugSimulatorDocumentsDirectorySync({
    Directory? systemTemp,
    void Function(String message)? log,
    Object? reason,
  }) {
    _simulatorFallbackUsed = true;
    final logger = log ?? debugPrint;
    logger(simulatorFallbackLog);
    if (reason != null) {
      logger('ARCHIVEME_SIMULATOR_NATIVE_ASSETS: reason=$reason');
    }
    final base = systemTemp ?? Directory.systemTemp;
    final dir = Directory('${base.path}/archiveme_sim_docs');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  @visibleForTesting
  static Directory debugSimulatorTemporaryDirectorySync({
    Directory? systemTemp,
    void Function(String message)? log,
    Object? reason,
  }) {
    _simulatorFallbackUsed = true;
    final logger = log ?? debugPrint;
    logger(simulatorFallbackLog);
    if (reason != null) {
      logger('ARCHIVEME_SIMULATOR_NATIVE_ASSETS: reason=$reason');
    }
    final base = systemTemp ?? Directory.systemTemp;
    final dir = Directory('${base.path}/archiveme_sim_tmp');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }
}
