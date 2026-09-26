import 'dart:io';

import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:flutter/services.dart';

/// Dart gate for the surfaces that ship with the widget extension:
/// Home Screen, Lock Screen, Siri, Control Center, Action Button, and Live Activity.
/// Watch capture stays behind [V1CapabilityRegistry.watchCompanion].
abstract final class NativeQuickCapture {
  NativeQuickCapture._();

  static const channelName = 'archive_me/native_quick_capture';
  static const _channel = MethodChannel(channelName);

  static bool autostartRequested(Map<String, String> params) =>
      V1CapabilityRegistry.nativeQuickCapture && params['autostart'] == '1';

  static bool textEntryRequested(Map<String, String> params) =>
      autostartRequested(params) && params['input'] == 'text';

  static bool stopRequested(Map<String, String> params) =>
      V1CapabilityRegistry.nativeQuickCapture && params['stop'] == '1';

  static Future<void> recordingStarted() async {
    if (!V1CapabilityRegistry.nativeQuickCapture || !Platform.isIOS) return;
    await _channel.invokeMethod<void>('liveActivityStart');
  }

  static Future<void> recordingStopped() async {
    if (!V1CapabilityRegistry.nativeQuickCapture || !Platform.isIOS) return;
    await _channel.invokeMethod<void>('liveActivityStop');
  }
}
