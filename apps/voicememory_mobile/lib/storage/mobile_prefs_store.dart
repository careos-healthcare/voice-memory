import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/sync/journal_sync_conflict_resolver.dart';
import 'secure_storage.dart';

/// App preferences backed by platform secure storage in production.
///
/// [file] is retained only as a one-time plaintext migration source and as an
/// explicitly selected test backend. Production callers inject
/// [SecureStorageService], causing the legacy file to be securely migrated and
/// deleted.
class MobilePrefsStore {
  MobilePrefsStore({required this.file, this._secureStorage});

  final File file;
  final SecureStorageService? _secureStorage;
  static const storageKey = 'mobile_prefs_json_v1';
  static const journalSyncManifestKey = 'journalSyncManifestV1';

  /// Serializes read-modify-write sequences so concurrent updates (including
  /// fire-and-forget metric writes) cannot lose updates or corrupt the file.
  Future<void> _mutex = Future<void>.value();

  Future<void> _update(void Function(Map<String, dynamic>) mutate) {
    final completer = Completer<void>();
    final previous = _mutex;
    _mutex = completer.future;
    return previous.then((_) async {
      try {
        final data = await _read();
        mutate(data);
        await _write(data);
      } finally {
        completer.complete();
      }
    });
  }

  static Future<MobilePrefsStore> open(
    String filePath, {
    SecureStorageService? secureStorage,
  }) async {
    final file = File(filePath);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }

    final store = MobilePrefsStore(file: file, secureStorage: secureStorage);
    if (secureStorage != null) {
      final existing = await secureStorage.read(storageKey);
      if (existing == null) {
        final legacyRaw = await file.exists()
            ? await file.readAsString()
            : '{}';
        final normalized = legacyRaw.trim().isEmpty ? '{}' : legacyRaw;
        // Validate before migration so corrupt plaintext is never copied into
        // the platform keychain/encrypted preferences backend.
        jsonDecode(normalized) as Map<String, dynamic>;
        await secureStorage.write(storageKey, normalized);
      }
      if (await file.exists()) {
        await file.delete();
      }
      return store;
    }

    if (!await file.exists()) {
      await file.writeAsString('{}');
    }
    return store;
  }

  Future<Map<String, dynamic>> _read() async {
    final raw = _secureStorage == null
        ? await file.readAsString()
        : (await _secureStorage.read(storageKey) ?? '{}');
    if (raw.trim().isEmpty) return {};
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> _write(Map<String, dynamic> data) async {
    final encoded = jsonEncode(data);
    final secureStorage = _secureStorage;
    if (secureStorage != null) {
      await secureStorage.write(storageKey, encoded);
      return;
    }

    // Write to a temp file then rename so readers never see a partial file.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(encoded, flush: true);
    await tmp.rename(file.path);
  }

  Future<Map<String, dynamic>?> readMap(String key) async {
    final data = await _read();
    final raw = data[key];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    await _update((data) => data[key] = value);
  }

  /// Atomically reads the map at [key], transforms it, and writes it back as a
  /// single critical section so concurrent updates cannot lose changes.
  Future<Map<String, dynamic>> updateMap(
    String key,
    Map<String, dynamic> Function(Map<String, dynamic>? current) transform,
  ) async {
    late Map<String, dynamic> result;
    await _update((data) {
      final raw = data[key];
      Map<String, dynamic>? current;
      if (raw is Map<String, dynamic>) {
        current = raw;
      } else if (raw is Map) {
        current = Map<String, dynamic>.from(raw);
      }
      result = transform(current);
      data[key] = result;
    });
    return result;
  }

  Future<bool> get onboardingCompleted async =>
      (await _read())['onboardingCompleted'] == true;

  Future<void> setOnboardingCompleted(bool value) async {
    await _update((data) => data['onboardingCompleted'] = value);
  }

  Future<bool?> readBool(String key) async {
    final v = (await _read())[key];
    if (v is bool) return v;
    return null;
  }

  Future<void> writeBool(String key, bool value) async {
    await _update((data) => data[key] = value);
  }

  Future<String?> get lastSyncAt async =>
      (await _read())['lastSyncAt'] as String?;

  Future<void> setLastSyncAt(DateTime? at) async {
    await _update((data) => data['lastSyncAt'] = at?.toIso8601String());
  }

  Future<JournalSyncManifest?> get journalSyncManifest async {
    final raw = (await _read())[journalSyncManifestKey];
    if (raw is! Map) return null;
    return JournalSyncManifest.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<void> setJournalSyncManifest(JournalSyncManifest manifest) async {
    await _update((data) => data[journalSyncManifestKey] = manifest.toJson());
  }

  Future<Map<String, dynamic>?> get discoverBaseline async {
    final raw = (await _read())['discoverBaseline'];
    if (raw is Map<String, dynamic>) return raw;
    return null;
  }

  Future<void> setDiscoverBaseline(Map<String, dynamic> baseline) async {
    await _update((data) => data['discoverBaseline'] = baseline);
  }

  Future<Map<String, dynamic>> valueMomentState() async {
    final raw = (await _read())['valueMoment'];
    if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
    return {};
  }

  Future<void> setValueMomentState(Map<String, dynamic> state) async {
    await _update((data) => data['valueMoment'] = state);
  }

  Future<Map<String, String>> blindSpotReactions() async {
    final raw = (await _read())['blindSpotReactions'];
    if (raw is! Map) return {};
    return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
  }

  Future<void> saveBlindSpotReaction(String reviewId, String reaction) async {
    await _update((data) {
      final raw = data['blindSpotReactions'];
      final reactions = <String, String>{};
      if (raw is Map) {
        raw.forEach((k, v) => reactions[k.toString()] = v.toString());
      }
      reactions[reviewId] = reaction;
      data['blindSpotReactions'] = reactions;
    });
  }

  Future<List<Map<String, dynamic>>> theoryNotifications() async {
    final raw = (await _read())['theoryNotifications'];
    if (raw is! List) return [];
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> setTheoryNotifications(List<Map<String, dynamic>> items) async {
    await _update((data) => data['theoryNotifications'] = items);
  }

  Future<String?> readString(String key) async {
    final v = (await _read())[key];
    return v is String ? v : null;
  }

  Future<void> writeString(String key, String value) async {
    await _update((data) => data[key] = value);
  }

  Future<Map<String, dynamic>?> readJsonMap(String key) async {
    final v = (await _read())[key];
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  Future<void> writeJsonMap(String key, Map<String, dynamic> value) async {
    await _update((data) => data[key] = value);
  }

  /// Atomically removes [key] from the preferences payload.
  Future<void> remove(String key) async {
    await _update((data) => data.remove(key));
  }
}
