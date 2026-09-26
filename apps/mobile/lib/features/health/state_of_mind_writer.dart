import 'package:archiveme_mobile/core/user/user_preferences.dart';
import 'package:archiveme_mobile/features/health/apple_health_platform.dart';
import 'package:archiveme_mobile/features/health/state_of_mind_reader.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Writes a journal mood into Apple Health State of Mind.
///
/// Runs only on iOS, and only after the separate write setting is on.
/// It does not ask for permission; Settings does that when the switch is turned on.
abstract final class StateOfMindWriter {
  StateOfMindWriter._();

  @visibleForTesting
  static bool? debugWriteEnabled;

  @visibleForTesting
  static Future<void> Function(String mood)? debugWrite;

  static Future<bool> writeJournalMood(String mood) async {
    if (!AppleHealthPlatform.isIos) return false;
    final trimmed = mood.trim();
    if (trimmed.isEmpty) return false;
    if (!await _enabled()) return false;
    final override = debugWrite;
    if (override != null) {
      await override(trimmed);
      return true;
    }
    try {
      final saved = await StateOfMindReader.channel.invokeMethod<bool>(
        'writeStateOfMind',
        {'mood': trimmed},
      );
      return saved ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> _enabled() async {
    final override = debugWriteEnabled;
    if (override != null) return override;
    if (!AppServices.isInitialized) return false;
    final preferences = await UserPreferences.load(AppServices.instance.prefs);
    return preferences.isHealthMoodWriteEnabled;
  }
}
