import 'package:flutter/services.dart';

/// Platform bridge for Quick Capture widgets and home-screen shortcuts.
abstract class QuickCaptureWidgetBridge {
  Future<bool> isAvailable();

  /// Reads captures the extension wrote into App Group / shared storage.
  Future<List<Map<String, dynamic>>> readPendingCaptures();

  /// Removes processed captures from shared storage.
  Future<void> acknowledgeCaptureIds(List<String> captureIds);

  Future<void> updateWidgetSnapshot(Map<String, String> payload);

  Future<void> clearWidgetSnapshot();

  /// Deep-link route captured when the widget opened the host app.
  Future<String> consumePendingLaunchRoute();
}

class NoOpQuickCaptureWidgetBridge implements QuickCaptureWidgetBridge {
  const NoOpQuickCaptureWidgetBridge();

  @override
  Future<void> acknowledgeCaptureIds(List<String> captureIds) async {}

  @override
  Future<String> consumePendingLaunchRoute() async => '';

  @override
  Future<void> clearWidgetSnapshot() async {}

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<List<Map<String, dynamic>>> readPendingCaptures() async => const [];

  @override
  Future<void> updateWidgetSnapshot(Map<String, String> payload) async {}
}

/// Method channel bridge — fails softly when native code is unavailable.
class MethodChannelQuickCaptureWidgetBridge implements QuickCaptureWidgetBridge {
  MethodChannelQuickCaptureWidgetBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('archive_me/quick_capture_widget');

  final MethodChannel _channel;

  @override
  Future<bool> isAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'isQuickCaptureWidgetAvailable',
      );
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } catch (_, stackTrace) { // ignore: silent_catch_audit — widget extension best-effort
      return false;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> readPendingCaptures() async {
    try {
      final result = await _channel.invokeMethod<List<Object?>>(
        'readPendingQuickCaptures',
      );
      if (result == null) return const [];
      return result
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    } catch (_, stackTrace) { // ignore: silent_catch_audit — widget extension best-effort
      return const [];
    }
  }

  @override
  Future<void> acknowledgeCaptureIds(List<String> captureIds) async {
    if (captureIds.isEmpty) return;
    try {
      await _channel.invokeMethod<void>(
        'acknowledgeQuickCaptures',
        {'captureIds': captureIds},
      );
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    } catch (_, stackTrace) { // ignore: silent_catch_audit — widget extension best-effort
      return;
    }
  }

  @override
  Future<void> updateWidgetSnapshot(Map<String, String> payload) async {
    try {
      await _channel.invokeMethod<void>(
        'updateQuickCaptureWidget',
        payload,
      );
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    } catch (_, stackTrace) { // ignore: silent_catch_audit — widget extension best-effort
      return;
    }
  }

  @override
  Future<void> clearWidgetSnapshot() async {
    try {
      await _channel.invokeMethod<void>('clearQuickCaptureWidget');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    } catch (_, stackTrace) { // ignore: silent_catch_audit — widget extension best-effort
      return;
    }
  }

  @override
  Future<String> consumePendingLaunchRoute() async {
    try {
      final result = await _channel.invokeMethod<String>(
        'consumePendingQuickCaptureRoute',
      );
      return result?.trim() ?? '';
    } on MissingPluginException {
      return '';
    } on PlatformException {
      return '';
    } catch (_, stackTrace) { // ignore: silent_catch_audit — widget extension best-effort
      return '';
    }
  }
}