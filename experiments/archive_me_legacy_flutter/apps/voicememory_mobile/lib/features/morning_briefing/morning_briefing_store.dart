import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../../storage/encrypted_json_file_store.dart';
import 'morning_briefing_models.dart';

class MorningBriefingStore {
  MorningBriefingStore(this._storage);

  final EncryptedJsonFileStore _storage;
  final _changes = StreamController<MorningBriefing?>.broadcast();
  Future<void> _tail = Future.value();

  Stream<MorningBriefing?> get changes => _changes.stream;

  Future<MorningBriefing?> latest() => _serialize(() async {
    final document = await _read();
    final rows = document['briefings'];
    if (rows is! List || rows.isEmpty) return null;
    return MorningBriefing.fromJson(
      Map<String, dynamic>.from(rows.first as Map),
    );
  });

  Future<MorningBriefing?> forDay(DateTime localDay) async {
    final target = _day(localDay);
    final document = await _read();
    final rows = document['briefings'];
    if (rows is! List) return null;
    for (final raw in rows.whereType<Map>()) {
      final briefing = MorningBriefing.fromJson(Map<String, dynamic>.from(raw));
      if (_day(briefing.localDay) == target) return briefing;
    }
    return null;
  }

  Future<void> save(
    MorningBriefing briefing, {
    required Map<String, double> clusterVelocities,
  }) => _serialize(() async {
    final document = await _read();
    final existing = (document['briefings'] as List? ?? const [])
        .whereType<Map>()
        .map((raw) => MorningBriefing.fromJson(Map<String, dynamic>.from(raw)))
        .where((item) => _day(item.localDay) != _day(briefing.localDay))
        .toList();
    final briefings = [briefing, ...existing]
      ..sort((left, right) => right.localDay.compareTo(left.localDay));
    await _write({
      ...document,
      'briefings': briefings.take(14).map((item) => item.toJson()).toList(),
      'clusterVelocities': clusterVelocities,
    });
    _changes.add(briefing);
  });

  Future<Map<String, double>> clusterVelocities() async {
    final raw = (await _read())['clusterVelocities'];
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        if (entry.key is String && entry.value is num)
          entry.key as String: (entry.value as num).toDouble(),
    };
  }

  Future<void> markPresented(DateTime localDay) =>
      _updateMetadata('lastPresentedDay', _day(localDay));

  Future<bool> wasPresented(DateTime localDay) async =>
      (await _read())['lastPresentedDay'] == _day(localDay);

  Future<void> snoozeUntil(DateTime value) =>
      _updateMetadata('snoozedUntil', value.toUtc().toIso8601String());

  Future<DateTime?> snoozedUntil() async =>
      DateTime.tryParse('${(await _read())['snoozedUntil'] ?? ''}');

  Future<void> _updateMetadata(String key, String value) =>
      _serialize(() async {
        final document = await _read();
        await _write({...document, key: value});
      });

  Future<Map<String, dynamic>> _read() async {
    final raw = await _storage.readJson();
    if (raw == null) {
      return {
        'schemaVersion': 1,
        'briefings': <Object>[],
        'clusterVelocities': <String, double>{},
      };
    }
    if (raw is! Map || raw['schemaVersion'] != 1) {
      throw const FormatException('Invalid morning briefing store.');
    }
    return Map<String, dynamic>.from(raw);
  }

  Future<void> _write(Map<String, dynamic> value) =>
      _storage.writeJson({...value, 'schemaVersion': 1});

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    _tail = _tail.catchError((Object _) {}).then((_) async {
      try {
        result.complete(await operation());
      } on Object catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  Future<void> dispose() => _changes.close();
}

class EncryptedMorningBriefingAudioStorage {
  EncryptedMorningBriefingAudioStorage(this._storage);

  static const maxAudioBytes = 12 * 1024 * 1024;
  final EncryptedJsonFileStore _storage;

  Future<void> write(String briefingId, Uint8List bytes) async {
    if (briefingId.isEmpty || bytes.isEmpty || bytes.length > maxAudioBytes) {
      throw ArgumentError('Invalid morning briefing audio.');
    }
    final encoded = base64Encode(bytes);
    await _storage.writeJson({
      'schemaVersion': 1,
      'briefingId': briefingId,
      'audioBase64': encoded,
    });
  }

  Future<Uint8List?> read(String briefingId) async {
    final raw = await _storage.readJson();
    if (raw is! Map ||
        raw['schemaVersion'] != 1 ||
        raw['briefingId'] != briefingId ||
        raw['audioBase64'] is! String) {
      return null;
    }
    final bytes = base64Decode(raw['audioBase64'] as String);
    if (bytes.isEmpty || bytes.length > maxAudioBytes) {
      throw const FormatException('Invalid encrypted briefing audio.');
    }
    return Uint8List.fromList(bytes);
  }

  Future<void> clear() async {
    await _storage.writeJson(const {
      'schemaVersion': 1,
      'briefingId': null,
      'audioBase64': null,
    });
  }
}

String _day(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
