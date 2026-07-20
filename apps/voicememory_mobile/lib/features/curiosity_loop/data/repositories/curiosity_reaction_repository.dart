import 'package:flutter/foundation.dart';

import '../../../../services/app_services.dart';
import '../../../../storage/mobile_prefs_store.dart';
import '../models/curiosity_reaction_record.dart';

/// Persistence boundary for yesterday snapshot reaction history.
abstract interface class CuriosityReactionRepository {
  Future<void> logReaction(CuriosityReactionRecord record);

  Future<List<CuriosityReactionRecord>> getReactionsInWindow({
    required DateTime start,
    required DateTime end,
  });
}

/// Local-only reaction log backed by prefs with an in-memory cache.
class LocalCuriosityReactionRepository implements CuriosityReactionRepository {
  LocalCuriosityReactionRepository(this._prefs);

  static const prefsKey = 'curiosityReactions_v1';

  final MobilePrefsStore _prefs;

  static List<CuriosityReactionRecord> _cached = const [];
  static bool _loaded = false;

  static List<CuriosityReactionRecord> get cached =>
      List.unmodifiable(_cached);

  static LocalCuriosityReactionRepository instance() =>
      LocalCuriosityReactionRepository(AppServices.instance.prefs);

  static LocalCuriosityReactionRepository forPrefs(MobilePrefsStore prefs) =>
      LocalCuriosityReactionRepository(prefs);

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    _cached = await instance().loadAll();
    _loaded = true;
  }

  Future<List<CuriosityReactionRecord>> loadAll() async {
    final raw = await _prefs.readJsonMap(prefsKey);
    if (raw == null || raw.isEmpty) return const [];
    final recordsRaw = raw['reactions'];
    if (recordsRaw is! List) return const [];
    final records = recordsRaw
        .whereType<Map>()
        .map(
          (entry) => CuriosityReactionRecord.fromJson(
            Map<String, dynamic>.from(entry),
          ),
        )
        .whereType<CuriosityReactionRecord>()
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _cached = records;
    _loaded = true;
    return records;
  }

  @override
  Future<void> logReaction(CuriosityReactionRecord record) async {
    if (record.id.isEmpty || record.hookId.isEmpty) return;
    final records = [
      record,
      for (final existing in await loadAll())
        if (existing.id != record.id) existing,
    ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    await _persist(records);
  }

  @override
  Future<List<CuriosityReactionRecord>> getReactionsInWindow({
    required DateTime start,
    required DateTime end,
  }) async {
    final records = await loadAll();
    return _recordsInWindow(records, start: start, end: end);
  }

  Future<void> _persist(List<CuriosityReactionRecord> records) async {
    await _prefs.writeJsonMap(prefsKey, {
      'reactions': records.map((record) => record.toJson()).toList(),
    });
    _cached = records;
    _loaded = true;
  }

  @visibleForTesting
  static Future<void> resetForTest(MobilePrefsStore? prefs) async {
    _cached = const [];
    _loaded = false;
    if (prefs == null) return;
    await prefs.writeJsonMap(prefsKey, {});
  }
}

List<CuriosityReactionRecord> _recordsInWindow(
  List<CuriosityReactionRecord> records, {
  required DateTime start,
  required DateTime end,
}) {
  final windowStart = start.toUtc();
  final windowEnd = end.toUtc();
  if (windowStart.isAfter(windowEnd)) return const [];

  return [
    for (final record in records)
      if (!_isTimestampBefore(record.timestamp, windowStart) &&
          !_isTimestampAfter(record.timestamp, windowEnd))
        record,
  ];
}

bool _isTimestampBefore(DateTime value, DateTime boundary) {
  return value.toUtc().isBefore(boundary);
}

bool _isTimestampAfter(DateTime value, DateTime boundary) {
  return value.toUtc().isAfter(boundary);
}

/// In-memory reaction store for lightweight unit tests.
@visibleForTesting
class InMemoryCuriosityReactionRepository implements CuriosityReactionRepository {
  InMemoryCuriosityReactionRepository([List<CuriosityReactionRecord>? seed])
      : _records = [...?seed];

  final List<CuriosityReactionRecord> _records;

  List<CuriosityReactionRecord> get records => List.unmodifiable(_records);

  @override
  Future<void> logReaction(CuriosityReactionRecord record) async {
    if (record.id.isEmpty || record.hookId.isEmpty) return;
    _records.removeWhere((existing) => existing.id == record.id);
    _records.add(record);
    _records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  @override
  Future<List<CuriosityReactionRecord>> getReactionsInWindow({
    required DateTime start,
    required DateTime end,
  }) async {
    return _recordsInWindow(_records, start: start, end: end);
  }
}
