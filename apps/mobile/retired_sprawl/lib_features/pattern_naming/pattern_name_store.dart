import 'dart:async';

import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/sensitive_prefs_encrypted_blob.dart';
import 'package:flutter/foundation.dart';

/// Local display-only pattern name preferences — keyed by grounded phrase.
abstract final class PatternNameStore {
  PatternNameStore._();

  static const _prefsKey = 'pattern_name_preferences_v1';
  static const _secureCustomNamesKey = 'secure_pattern_custom_names_v1';
  static const _legacyRenamedField = 'renamed';
  static const maxCustomNameLength = 80;

  static final Set<String> _confirmedKeys = <String>{};
  static final Map<String, String> _customNames = <String, String>{};

  static bool _loaded = false;
  static bool _migrationComplete = false;
  static Future<void> _persistChain = Future<void>.value();

  static bool isResolved(String patternKey) {
    if (patternKey.isEmpty) return true;
    return _confirmedKeys.contains(patternKey) ||
        _customNames.containsKey(patternKey);
  }

  static bool hasCustomName(String patternKey) =>
      patternKey.isNotEmpty && _customNames.containsKey(patternKey);

  static Future<void> confirm(String patternKey) async {
    if (patternKey.isEmpty) return;
    _confirmedKeys.add(patternKey);
    await _persistAll();
  }

  static Future<void> setCustomName(String patternKey, String name) async {
    if (patternKey.isEmpty) return;
    final normalized = normalizeCustomName(name);
    if (normalized == null) return;
    _customNames[patternKey] = normalized;
    _confirmedKeys.add(patternKey);
    await _persistAll();
  }

  static String? getCustomName(String patternKey) {
    if (patternKey.isEmpty) return null;
    return _customNames[patternKey];
  }

  static String displayLabel({
    required String patternKey,
    required String groundedPhrase,
  }) => _customNames[patternKey] ?? groundedPhrase;

  static String? sanitizeCustomName(String raw) => normalizeCustomName(raw);

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

  static Map<String, dynamic> metadataToJson() => {
    'confirmed': _confirmedKeys.toList()..sort(),
  };

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    await _runMigrationIfNeeded();
    final raw = await AppServices.instance.prefs.readMap(_prefsKey);
    if (raw != null) {
      applyLoaded(
        confirmed: (raw['confirmed'] as List<dynamic>? ?? []).whereType<String>(),
      );
    }
    _customNames
      ..clear()
      ..addAll(await _customNamesBlob().readStringMap());
    _loaded = true;
  }

  static Future<void> _runMigrationIfNeeded() async {
    if (_migrationComplete || !AppServices.isInitialized) return;
    await _customNamesBlob().migrateLegacyStringMapField(
      legacyPrefsKey: _prefsKey,
      legacyFieldName: _legacyRenamedField,
    );
    _migrationComplete = true;
  }

  static Future<void> clearAll() async {
    _confirmedKeys.clear();
    _customNames.clear();
    _loaded = true;
    _migrationComplete = true;
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeMap(_prefsKey, {});
    await _customNamesBlob().clear();
  }

  static Future<void> _persistAll() async {
    if (!AppServices.isInitialized) return;
    final completer = Completer<void>();
    final previous = _persistChain;
    _persistChain = completer.future;
    await previous;
    try {
      await AppServices.instance.prefs.writeMap(_prefsKey, metadataToJson());
      await _customNamesBlob().writeStringMap(
        Map<String, String>.from(_customNames),
      );
    } finally {
      completer.complete();
    }
  }

  static SensitivePrefsEncryptedBlob _customNamesBlob() {
    return SensitivePrefsEncryptedBlob(
      prefs: AppServices.instance.prefs,
      encryptedStorage: AppServices.instance.personalContentEncryptedStorage,
      securePrefsKey: _secureCustomNamesKey,
      payloadRootKey: 'renamed',
    );
  }

  static void resetPersistedState() {
    _confirmedKeys.clear();
    _customNames.clear();
    _loaded = false;
    _migrationComplete = false;
    _persistChain = Future<void>.value();
  }

  @visibleForTesting
  static Future<void> flushForTest() => _persistChain;

  @visibleForTesting
  static Future<void> resetForTest() async {
    await flushForTest();
    resetPersistedState();
  }
}
