import 'dart:io';

import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/storage/app_storage_paths.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Runtime environment for microphone permission policy (simulator vs physical iOS).
abstract class MicrophonePermissionEnvironment {
  MicrophonePermissionEnvironment._();

  static const String micDiagLogPrefix = 'ARCHIVEME_MIC_DIAG:';

  static bool? _iosSimulatorOverride;
  static bool _forceIosPhysicalForTest = false;
  static bool _physicalMismatchWarningLogged = false;

  /// True when iOS Settings/recorder likely has mic access but permission_handler
  /// is stale — skip [Permission.microphone.request] and allow capture with validation.
  static Future<bool> shouldSkipPermissionRequest({
    required PermissionStatus status,
    required bool hasRecorder,
  }) async {
    if (status.isGranted || !hasRecorder) return false;
    return isIosPhysicalDevice();
  }

  /// Physical iOS: trust recorder when permission_handler disagrees.
  static Future<bool> allowPhysicalRecorderMismatch({
    required PermissionStatus status,
    required bool hasRecorder,
  }) async {
    if (!hasRecorder || status.isGranted) return false;
    return isIosPhysicalDevice();
  }

  static void logPhysicalMismatchWarning({required PermissionStatus status}) {
    if (_physicalMismatchWarningLogged) return;
    _physicalMismatchWarningLogged = true;
    AppLogger.debug(
      'ARCHIVEME_MIC_PERMISSION_MISMATCH physical_ios=true '
      'permission_handler=$status recorder=true '
      'action=allow_record_with_audio_validation',
    );
  }

  /// True on iOS Simulator (not physical device).
  static Future<bool> isIosSimulator() async {
    final override = _iosSimulatorOverride;
    if (override != null) return override;
    if (kIsWeb || !Platform.isIOS) return false;
    if (AppStoragePaths.isIosDebugSimulator()) return true;
    final info = await DeviceInfoPlugin().deviceInfo;
    return switch (info) {
      final IosDeviceInfo ios => !ios.isPhysicalDevice,
      _ => false,
    };
  }

  static Future<bool> isIosPhysicalDevice() async {
    if (_forceIosPhysicalForTest) return true;
    if (kIsWeb || !Platform.isIOS) return false;
    return !(await isIosSimulator());
  }

  static Future<String> platformLabel() async {
    if (_forceIosPhysicalForTest) return 'ios_physical';
    if (kIsWeb) return 'web';
    if (Platform.isIOS) {
      return (await isIosSimulator()) ? 'ios_simulator' : 'ios_physical';
    }
    if (Platform.isAndroid) return 'android';
    return Platform.operatingSystem;
  }

  static void logMicDiag({
    required PermissionStatus permissionHandler,
    required bool recordHasPermission,
    required String platform,
  }) {
    AppLogger.debug(
      '$micDiagLogPrefix permission_handler=$permissionHandler '
      'record_has_permission=$recordHasPermission '
      'has_recorder=$recordHasPermission '
      'platform=$platform',
    );
  }

  static void logMicDiagMismatch({
    required PermissionStatus permissionHandler,
    required String platform,
  }) {
    AppLogger.debug(
      'ARCHIVEME_MIC_DIAG_MISMATCH: permission_handler=$permissionHandler '
      'record_has_permission=true platform=$platform action=prefer_recorder',
    );
  }

  /// Simulator-only: prefer [record.hasPermission] when permission_handler disagrees.
  static Future<bool> preferRecorderOnPlatformMismatch({
    required PermissionStatus status,
    required bool hasRecorder,
  }) async {
    if (!hasRecorder || status.isGranted) return false;
    return isIosSimulator();
  }

  static void resetPersistedState() {
    _iosSimulatorOverride = null;
    _forceIosPhysicalForTest = false;
    _physicalMismatchWarningLogged = false;
  }

  @visibleForTesting
  static void resetForTest() => resetPersistedState();

  @visibleForTesting
  static void setIosPhysicalForTest(bool value) {
    _forceIosPhysicalForTest = value;
  }

  @visibleForTesting
  static void setIosSimulatorForTest(bool? value) {
    _iosSimulatorOverride = value;
  }
}