import 'package:archiveme_mobile/features/health/apple_health_platform.dart';
import 'package:archiveme_mobile/features/health/state_of_mind_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Asks HealthKit for State of Mind access.
///
/// The system sheet is this method only. Reading or writing a sample does
/// not call it.
abstract final class HealthFactory {
  HealthFactory._();

  @visibleForTesting
  static Future<bool> Function({required bool update})? debugRequest;

  static Future<bool> requestAuthorization({bool update = false}) async {
    final override = debugRequest;
    if (override != null) return override(update: update);
    if (!AppleHealthPlatform.isIos) return false;
    try {
      final granted = await StateOfMindReader.channel.invokeMethod<bool>(
        'requestAuthorization',
        {'share': true, 'update': update},
      );
      return granted ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
