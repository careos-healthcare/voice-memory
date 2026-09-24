import 'package:archiveme_mobile/features/ambient_capture/ambient_capture_router.dart';
import 'package:archiveme_mobile/features/capture/capture_module_config.dart';
import 'package:archiveme_mobile/features/capture/zero_state_recorder.dart';
import 'package:flutter/services.dart';

/// Starts microphone buffering before the shell and Riverpod providers render.
abstract final class ShortcutRecordLaunch {
  ShortcutRecordLaunch._();

  static const consumeMethod = 'consumeRecordLaunch';
  static const beginMethod = 'beginAudioBuffer';
  static const releaseMethod = 'releaseAudioBuffer';

  static String? earlyBufferPath;

  /// True when a home-screen shortcut or lock-screen widget opened recording.
  static bool isRecordLaunchToken(String? token) {
    if (token == null || token.isEmpty) return false;
    if (token == 'new_voice_entry' || token == 'start_recording') return true;
    final uri = Uri.tryParse(token);
    if (uri == null) return false;
    return uri.scheme.toLowerCase() == CaptureDeepLinkUris.scheme &&
        uri.host.toLowerCase() == CaptureDeepLinkUris.recordHost;
  }

  /// Opens the native buffer, then leaves the recording route pending.
  ///
  /// Call this before [runApp] and before primary provider startup. The
  /// microphone file keeps growing while those later steps render.
  static Future<bool> beginBeforeUi({MethodChannel? channel}) async {
    final messenger =
        channel ?? const MethodChannel(ZeroStateRecorder.channelName);
    try {
      final launch = await messenger.invokeMethod<bool>(consumeMethod);
      if (launch != true) return false;
      await messenger.invokeMethod<bool>(beginMethod);
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
    AmbientCaptureRouter.go(CaptureDeepLinkUris.recordLaunchRoute);
    return true;
  }

  /// Stops the early buffer so the in-app recorder can take the microphone.
  static Future<String?> releaseEarlyBuffer({MethodChannel? channel}) async {
    final messenger =
        channel ?? const MethodChannel(ZeroStateRecorder.channelName);
    try {
      final path = await messenger.invokeMethod<String>(releaseMethod);
      if (path != null && path.isNotEmpty) earlyBufferPath = path;
      return earlyBufferPath;
    } on MissingPluginException {
      return earlyBufferPath;
    } on PlatformException {
      return earlyBufferPath;
    }
  }
}
