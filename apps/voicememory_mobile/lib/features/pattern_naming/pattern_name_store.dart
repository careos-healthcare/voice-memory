import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';

/// Local display-only pattern name preferences — keyed by grounded phrase.
abstract final class PatternNameStore {
  PatternNameStore._();

  static const _prefsKey = 'pattern_name_preferences_v1';
  static const maxCustomNameLength = 80;

  static final Set<String> _confirmedKeys = <String>{};
  static final Map<String, String> _customNames = <String, String>{};

  static bool isResolved(String patternKey) {
    if (patternKey.isEmpty) return true;
    return _confirmedKeys.contains(patternKey) ||
        _customNames.containsKey(patternKey);
  }

  static bool hasCustomName(String patternKey) =>
      patternKey.isNotEmpty && _customNames.containsKey(patternKey);

  static void confirm(String patternKey) {
    if (patternKey.isEmpty) return;
    _confirmedKeys.add(patternKey);
    _persist();
  }

  static void setCustomName(String patternKey, String name) {
    if (patternKey.isEmpty) return;
    final normalized = normalizeCustomName(name);
    if (normalized == null) return;
    _customNames[patternKey] = normalized;
    _confirmedKeys.add(patternKey);
    _persist();
  }

  static String? getCustomName(String patternKey) {
    if (patternKey.isEmpty) return null;
    return _customNames[patternKey];
  }

  static String displayLabel({
    required String patternKey,
    required String groundedPhrase,
  }) =>
      _customNames[patternKey] ?? groundedPhrase;

  @visibleForTesting
  static String? normalizeCustomName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length <= maxCustomNameLength) return trimmed;
    return trimmed.substring(0, maxCustomNameLength).trimRight();
  }

  static void applyLoaded({
    Iterable<String>? confirmed,
    Map<String, String>? renamed,
  }) {
    _confirmedKeys
      ..clear()
      ..addAll(confirmed ?? const []);
    _customNames
      ..clear()
      ..addAll(renamed ?? const {});
  }

  static Map<String, dynamic> toJson() => {
        'confirmed': _confirmedKeys.toList()..sort(),
        'renamed': Map<String, String>.from(_customNames),
      };

  static Future<void> ensureLoaded() async {
    if (!AppServices.isInitialized) return;
    final raw = await AppServices.instance.prefs.readMap(_prefsKey);
    if (raw == null) return;
    final renamedRaw = raw['renamed'];
    final renamed = renamedRaw is Map
        ? renamedRaw.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          )
        : null;
    applyLoaded(
      confirmed: (raw['confirmed'] as List<dynamic>? ?? []).whereType<String>(),
      renamed: renamed,
    );
  }

  static Future<void> clearAll() async {
    _confirmedKeys.clear();
    _customNames.clear();
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeMap(_prefsKey, {});
  }

  static void _persist() {
    if (!AppServices.isInitialized) return;
    // ignore: discarded_futures
    AppServices.instance.prefs.writeMap(_prefsKey, toJson());
  }

  @visibleForTesting
  static void resetForTest() {
    _confirmedKeys.clear();
    _customNames.clear();
  }
}
