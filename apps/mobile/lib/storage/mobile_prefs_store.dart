import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Non-secret app preferences — operational metadata only.
///
/// Personal free text, transcripts, correction notes, and derived insight
/// bodies must use [PersonalContentEncryptedStorage] via
/// [SensitivePrefsEncryptedBlob] or the encrypted journal store. See
/// [MobilePrefsPolicy] and `docs/privacy/ACTIVE_BETA_DATA_MAP.md`.
class MobilePrefsStore {
  MobilePrefsStore({required this.file});

  final File file;

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

  static Future<MobilePrefsStore> open(String filePath) async {
    final file = File(filePath);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    if (!await file.exists()) {
      await file.writeAsString('{}');
    }
    return MobilePrefsStore(file: file);
  }

  Future<Map<String, dynamic>> _read() async {
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return {};
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> _write(Map<String, dynamic> data) async {
    // Write to a temp file then rename so readers never see a partial file.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
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

  Future<int?> get lastSyncSequence async {
    final raw = (await _read())['lastSyncSequence'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return null;
  }

  Future<void> setLastSyncSequence(int? sequence) async {
    await _update((data) {
      if (sequence == null) {
        data.remove('lastSyncSequence');
      } else {
        data['lastSyncSequence'] = sequence;
      }
    });
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

  /// The stored value at [key] with no shape coercion, or null when the key is
  /// absent.
  ///
  /// [readJsonMap] and [readString] both answer null for "absent" and for
  /// "present but the wrong type". A caller that has to fail closed on a
  /// corrupt blob needs to tell those apart, and this is the only read that
  /// lets it.
  Future<Object?> readRawValue(String key) async => (await _read())[key];

  Future<void> writeJsonMap(String key, Map<String, dynamic> value) async {
    await _update((data) => data[key] = value);
  }
}