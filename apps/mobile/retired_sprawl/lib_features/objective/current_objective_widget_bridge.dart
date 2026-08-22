import 'package:flutter/services.dart';

/// Platform bridge for Today\u2019s Check home-screen widgets.
abstract class CurrentObjectiveWidgetBridge {
  Future<bool> isAvailable();

  Future<void> update(Map<String, String> payload);

  Future<void> clear();

  /// Route from a widget tap, if the platform captured one on launch.
  Future<String> consumePendingWidgetRoute();
}

/// No-op bridge for tests and unsupported platforms.
class NoOpCurrentObjectiveWidgetBridge implements CurrentObjectiveWidgetBridge {
  const NoOpCurrentObjectiveWidgetBridge();

  @override
  Future<void> clear() async {}

  @override
  Future<String> consumePendingWidgetRoute() async => '';

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<void> update(Map<String, String> payload) async {}
}

/// Method channel bridge — fails softly when native code is unavailable.
class MethodChannelCurrentObjectiveWidgetBridge
    implements CurrentObjectiveWidgetBridge {
  MethodChannelCurrentObjectiveWidgetBridge({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('archive_me/current_objective_widget');

  final MethodChannel _channel;

  @override
  Future<bool> isAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'isCurrentObjectiveWidgetAvailable',
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
  Future<void> update(Map<String, String> payload) async {
    try {
      await _channel.invokeMethod<void>(
        'updateCurrentObjectiveWidget',
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
  Future<void> clear() async {
    try {
      await _channel.invokeMethod<void>('clearCurrentObjectiveWidget');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    } catch (_, stackTrace) { // ignore: silent_catch_audit — widget extension best-effort
      return;
    }
  }

  @override
  Future<String> consumePendingWidgetRoute() async {
    try {
      final result = await _channel.invokeMethod<String>(
        'consumePendingWidgetRoute',
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