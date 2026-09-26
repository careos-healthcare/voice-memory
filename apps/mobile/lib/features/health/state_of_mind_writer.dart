import 'dart:convert';

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

  /// Sample UUIDs Thoughtprint wrote, keyed by entry id, so a cleared mood
  /// can delete that sample and no other.
  static const sampleIdsKey = 'health_state_of_mind_sample_ids';

  @visibleForTesting
  static final Map<String, String> sampleIds = {};

  static Future<bool> writeJournalMood(String mood, {String? entryId}) async {
    if (!AppleHealthPlatform.isIos) return false;
    final trimmed = mood.trim();
    if (trimmed.isEmpty) {
      if (entryId != null) return deleteJournalMood(entryId);
      return false;
    }
    if (!StateOfMindWriteMap.table.containsKey(trimmed.toLowerCase())) {
      return false;
    }
    if (!await _enabled()) return false;
    final override = debugWrite;
    if (override != null) {
      await override(trimmed);
      return true;
    }
    try {
      final saved = await StateOfMindReader.channel.invokeMethod<String>(
        'writeStateOfMind',
        {
          'mood': trimmed,
          'label': StateOfMindWriteMap.label(trimmed),
          'valence': StateOfMindWriteMap.valence(trimmed),
        },
      );
      final id = saved?.trim() ?? '';
      if (id.isEmpty) return false;
      if (entryId != null) await _remember(entryId, id);
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> deleteJournalMood(String entryId) async {
    if (!AppleHealthPlatform.isIos) return false;
    final id = await _take(entryId);
    if (id == null || id.isEmpty) return false;
    try {
      final deleted = await StateOfMindReader.channel.invokeMethod<bool>(
        'deleteStateOfMind',
        {'uuid': id},
      );
      if (deleted != true) {
        await _remember(entryId, id);
        return false;
      }
      return true;
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

  static Future<void> _remember(String entryId, String sampleId) async {
    await _loadIds();
    sampleIds[entryId] = sampleId;
    await _saveIds();
  }

  static Future<String?> _take(String entryId) async {
    await _loadIds();
    final id = sampleIds.remove(entryId);
    await _saveIds();
    return id;
  }

  static Future<void> _loadIds() async {
    if (!AppServices.isInitialized) return;
    final raw = await AppServices.instance.prefs.readString(sampleIdsKey);
    if (raw == null || raw.isEmpty) return;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return;
    for (final entry in decoded.entries) {
      sampleIds['${entry.key}'] = '${entry.value}';
    }
  }

  static Future<void> _saveIds() async {
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeString(
      sampleIdsKey,
      jsonEncode(sampleIds),
    );
  }
}

/// Journal mood words to HealthKit momentary-emotion labels and valence.
///
/// | Thoughtprint | HKStateOfMind.Label | valence |
/// | Calm         | calm                 |  0.4    |
/// | Grounded     | calm                 |  0.4    |
/// | Anxious      | anxious              | -0.5    |
/// | Energetic    | excited              |  0.7    |
/// | Reflective   | peaceful             |  0.3    |
/// | Low          | sad                  | -0.6    |
abstract final class StateOfMindWriteMap {
  StateOfMindWriteMap._();

  static const table = <String, (String, double)>{
    'calm': ('calm', 0.4),
    'grounded': ('calm', 0.4),
    'anxious': ('anxious', -0.5),
    'energetic': ('excited', 0.7),
    'reflective': ('peaceful', 0.3),
    'low': ('sad', -0.6),
  };

  static String label(String mood) => table[mood.trim().toLowerCase()]!.$1;

  static double valence(String mood) => table[mood.trim().toLowerCase()]!.$2;
}
